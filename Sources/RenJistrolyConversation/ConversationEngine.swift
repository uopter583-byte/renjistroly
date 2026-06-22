import Foundation
import AppKit
import os
import RenJistrolyModels
import RenJistrolyIntelligence
import RenJistrolyCapability
import RenJistrolySystemBridge

@MainActor
@Observable
public final class ConversationEngine {
    public static let shared = ConversationEngine()

    public let sessionManager: SessionManager
    public let contextCompiler: ContextCompiler
    public let voiceSessionManager: VoiceSessionManager
    public let toolExecutionService: ToolExecutionService
    public var currentDesktopContext: DesktopContext?

    private let smartRouter: SmartRouter
    private let taskRouter: TaskRouter
    let agentOrchestrator: AgentOrchestrator
    private let planExecutor: PlanExecutor
    let mcpClient: MCPClient
    let computerUseRuntime: ComputerUseRuntime
    let developerAgentStore: DeveloperAgentTaskStore
    private let safetyAuditStore: SafetyAuditStore
    let workflowMemoryStore: WorkflowMemoryStore
    let templateStore: WorkflowTemplateStore
    private let skillRegistry: AgentSkillRegistry
    let multiAgentBoard: MultiAgentTaskBoard
    let ragEngine: RAGEngine
    let desktopContextCollector: DesktopContextCollector
    let claudeCodeBridge: ClaudeCodeBridge
    private let buildErrorAnalyzer: BuildErrorAnalyzer
    let screenContextProvider: ScreenContextProvider
    let developerLoop: DeveloperLoop

    public var isProcessing: Bool = false
    public var currentResponseID: UUID?
    public private(set) var lastScreenContext: ScreenContext?
    var lastScreenContextCapturedAt: Date = .distantPast
    let screenContextTTL: TimeInterval = 5 // seconds before stale
    public private(set) var isScreenStreamActive = false
    public private(set) var cursorPosition: CGPoint = .zero
    private var screenStreamProvider: ScreenStreamProvider?
    let taskBag = TaskBag()

    // Delegated to VoiceSessionManager
    public var voiceText: String { voiceSessionManager.voiceText }
    public var voiceError: String? { voiceSessionManager.voiceError }

    // Delegated to ToolExecutionService
    public var safetyAuditRecords: [SafetyAuditRecord] { toolExecutionService.safetyAuditRecords }

    public private(set) var latestRoute: RoutedTask?
    public var agentBoardItems: [MultiAgentBoardItem] = []
    public var developerTasks: [DeveloperAgentTask] = []
    public var workflowMemories: [TaskMemory] = []
    public var skills: [AgentSkill] = []
    public var currentRecoveryProfile = RecoveryProfileSnapshot(scope: "global")
    public var lastComputerUseTrace: ComputerUseTraceSnapshot?
    public var recentAgentTimeline: [AgentTimelineEvent] = []
    public var sessionLifecycle = SessionLifecycle()
    public var claudeCodeStatus = ClaudeCodeInstallationStatus(
        executablePath: "/opt/homebrew/bin/claude",
        isInstalled: false
    )

    var lastBriefTraceEvent: ComputerUseTraceEvent?

    public init(
        sessionManager: SessionManager = SessionManager(storageURL: SessionManager.defaultStorageURL()),
        contextCompiler: ContextCompiler = ContextCompiler(),
        desktopContextCollector: DesktopContextCollector = DesktopContextCollector(),
        smartRouter: SmartRouter = SmartRouter(),
        taskRouter: TaskRouter = TaskRouter(),
        planGenerator: PlanGenerator = PlanGenerator(),
        mcpClient: MCPClient = MCPClient(),
        computerUseRuntime: ComputerUseRuntime? = nil,
        developerAgentStore: DeveloperAgentTaskStore = DeveloperAgentTaskStore(),
        safetyAuditStore: SafetyAuditStore = SafetyAuditStore(),
        workflowMemoryStore: WorkflowMemoryStore = WorkflowMemoryStore(),
        templateStore: WorkflowTemplateStore = WorkflowTemplateStore(),
        skillRegistry: AgentSkillRegistry = AgentSkillRegistry(),
        multiAgentBoard: MultiAgentTaskBoard = MultiAgentTaskBoard(),
        ragEngine: RAGEngine = RAGEngine(),
        speechRecognizer: MacOSSpeechRecognizer = MacOSSpeechRecognizer(),
        systemDictation: SystemDictationBridge = SystemDictationBridge(),
        textToSpeech: MacOSTextToSpeech = MacOSTextToSpeech(),
        claudeCodeBridge: ClaudeCodeBridge = ClaudeCodeBridge(),
        buildErrorAnalyzer: BuildErrorAnalyzer = BuildErrorAnalyzer(),
        screenContextProvider: ScreenContextProvider = ScreenContextProvider(),
        developerLoop: DeveloperLoop = DeveloperLoop()
    ) {
        self.sessionManager = sessionManager
        self.contextCompiler = contextCompiler
        self.desktopContextCollector = desktopContextCollector
        self.smartRouter = smartRouter
        self.taskRouter = taskRouter
        self.agentOrchestrator = AgentOrchestrator(smartRouter: smartRouter)
        self.mcpClient = mcpClient
        let coordinator = ComputerUseCoordinator(
            accessibility: AccessibilityContextProvider(),
            observer: ComputerUseObserver(accessibility: AccessibilityContextProvider(), screen: screenContextProvider),
            vision: VisionCUAFallback(strategy: .claudeVision, config: VisionCUAConfig(llmBackend: nil))
        )
        let runtime = computerUseRuntime ?? ComputerUseRuntime(client: mcpClient, coordinator: coordinator, screenContextProvider: screenContextProvider)
        self.computerUseRuntime = runtime

        // Wire Vision backend with Claude once SmartRouter is configured
        Task.detached { [coordinator, smartRouter] in
            if let backend = await smartRouter.getBackend(for: .anthropic) {
                await coordinator.configureVisionBackend(backend)
            }
        }

        self.developerAgentStore = developerAgentStore
        self.safetyAuditStore = safetyAuditStore
        self.workflowMemoryStore = workflowMemoryStore
        self.templateStore = templateStore
        self.skillRegistry = skillRegistry
        self.multiAgentBoard = multiAgentBoard
        self.ragEngine = ragEngine
        self.claudeCodeBridge = claudeCodeBridge
        self.buildErrorAnalyzer = buildErrorAnalyzer
        self.developerLoop = developerLoop
        self.screenContextProvider = screenContextProvider

        let toolExec = ToolExecutionService(mcpClient: mcpClient, safetyAuditStore: safetyAuditStore, screenContextProvider: screenContextProvider)
        self.toolExecutionService = toolExec
        self.voiceSessionManager = VoiceSessionManager(
            speechRecognizer: speechRecognizer,
            systemDictation: systemDictation,
            textToSpeech: textToSpeech
        )
        self.planExecutor = PlanExecutor(
            sessionManager: sessionManager,
            agentOrchestrator: agentOrchestrator,
            mcpClient: mcpClient,
            contextCompiler: contextCompiler,
            computerUseRuntime: runtime,
            toolExecutionService: toolExec,
            workflowMemoryStore: workflowMemoryStore
        )

        Task {
            await taskBag.set(key: "init", task: Task {
                await mcpClient.registerBuiltinTools()
                workflowMemories = await workflowMemoryStore.all()
                skills = await skillRegistry.all()
                await refreshClaudeCodeStatus()
                // Pre-warm claude CLI binary to reduce 10-15s cold start on first LLM call.
                // Runs `--version` which loads the binary and runtime into OS page cache
                // without incurring API costs or generating real responses.
                await prewarmClaudeCLI()
            })
        }
    }

    deinit {}

    // MARK: - API Key Configuration

    public func configureCloudAPI(provider: LLMProvider, key: String) async {
        await smartRouter.configureCloud(provider: provider, apiKey: key)
    }

    public func refreshClaudeCodeStatus() async {
        claudeCodeStatus = await claudeCodeBridge.installationStatus()
    }

    /// Run a best-effort pre-warm of the claude CLI binary by executing
    /// `claude --version`. This loads the binary, its shared libraries,
    /// and supporting runtimes into the OS page cache, significantly
    /// reducing the perceived delay on the first real invocation
    /// (from ~10-15s to ~2-3s).
    private func prewarmClaudeCLI() async {
        let claudePath = await claudeCodeBridge.configuredPath()
        guard FileManager.default.isExecutableFile(atPath: claudePath) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["--version"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                        process.terminationHandler = { _ in cont.resume() }
                        do { try process.run() } catch { cont.resume(throwing: error) }
                    }
                }
                group.addTask {
                    try await Task.sleep(for: .seconds(5))
                    process.terminate()
                    throw CancellationError()
                }
                try await group.next()
                group.cancelAll()
            }
        } catch {
            // Best-effort warmup; failure is non-fatal
        }
    }

    public func setClaudeCodePath(_ path: String, appState: AppState? = nil) async {
        await claudeCodeBridge.updatePath(path)
        let status = await claudeCodeBridge.installationStatus()
        claudeCodeStatus = status
        if let appState {
            appState.devMode.claudeCodePath = status.executablePath
        }
    }

    public func launchClaudeCodeTask(_ prompt: String, appState: AppState? = nil) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let conversationID = sessionManager.activeConversationID ?? sessionManager.createConversation().id as UUID? else {
            return
        }
        await sendDeveloperAgentTask(trimmed, conversationID: conversationID, appState: appState)
    }

    public func refreshDeveloperTasks() async {
        developerTasks = await developerAgentStore.allTasks()
    }

    public func stopDeveloperTask(_ id: UUID) async {
        await developerAgentStore.stop(id)
        await refreshDeveloperTasks()
    }

    public func retryDeveloperTask(_ id: UUID) async {
        await developerAgentStore.retry(id)
        await refreshDeveloperTasks()
        await startDeveloperTaskSyncLoop(taskID:id)
    }

    public func approveDeveloperTask(_ id: UUID) async {
        await developerAgentStore.approveAndResume(id)
        await refreshDeveloperTasks()
        await startDeveloperTaskSyncLoop(taskID:id)
    }

    // MARK: - Lifecycle Helpers

    public private(set) var currentPhase: SessionPhase = .idle

    func setPhase(_ phase: SessionPhase, reason: String = "") {
        currentPhase = phase
        _ = sessionLifecycle.transition(to: phase, reason: reason)
    }

    func publishLifecycleEvent(_ event: LifecycleEvent) async {
        await AgentEventBus.shared.publish(.lifecycle(event))
    }

    private func publishCodeEvent(_ event: CodeEvent) async {
        await AgentEventBus.shared.publish(.code(event))
    }

    // MARK: - Main Chat Flow

    public func sendMessage(_ text: String, appState: AppState? = nil, depth: Int = 0) async {
        await taskBag["init"]?.value
        guard !isProcessing else { return }
        guard depth < 3 else {
            let errorMsg = Message(role: .assistant, content: [.text("内部错误: 无法创建对话")])
            _ = sessionManager.createConversation()
            if let id = sessionManager.activeConversationID {
                sessionManager.appendMessage(errorMsg, to: id)
            }
            return
        }
        guard let conversationID = sessionManager.activeConversationID else {
            _ = sessionManager.createConversation()
            await sendMessage(text, appState: appState, depth: depth + 1)
            return
        }

        let routed = taskRouter.route(text)
        latestRoute = routed
        agentBoardItems = await multiAgentBoard.seedDefaultBoard(for: text)

        // P0: Tool-skill system integration (tool grouping + filtered tools)
        let matchedAgentSkill = await skillRegistry.match(text)
        skills = await skillRegistry.all()
        let toolSkillPrompt = await mcpClient.skillPrompt(for: routed)
        let toolSkillContext = toolSkillPrompt.isEmpty ? "" : "\n\n技能上下文:\n\(toolSkillPrompt)"

        let effectiveText: String
        if let matchedAgentSkill {
            effectiveText = """
            \(text)

            已匹配技能: \(matchedAgentSkill.name)
            技能步骤:
            \(matchedAgentSkill.steps.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n"))
            """ + toolSkillContext
        } else {
            effectiveText = text + toolSkillContext
        }
        let memoryContextParams = WorkflowMemoryStore.MemoryContext(
            domain: routed.primaryRoute.kind.rawValue
        )
        let recalledMemories = await workflowMemoryStore.recall(matching: text, context: memoryContextParams)
        let memoryContext = contextCompiler.buildWorkflowMemoryContext(memories: recalledMemories)
        let agentInputText = memoryContext.isEmpty
            ? effectiveText
            : """
            \(effectiveText)

            相关工作流记忆:
            \(memoryContext)
            """

        switch routed.primaryRoute.kind {
        case .code:
            if await handleDeterministicCodeTask(text, conversationID: conversationID, appState: appState) {
                return
            }
            if let fallback = taskRouter.continueRoute(from: routed, after: .code) {
                switch fallback.kind {
                case .desktop:
                    if await handleDeterministicDesktopTask(text, conversationID: conversationID, appState: appState) { return }
                case .fileSystem, .browser:
                    if await handleDeterministicToolTask(text, route: fallback.kind, conversationID: conversationID, appState: appState) { return }
                default: break
                }
            }
            await sendDeveloperAgentTask(agentInputText, displayText: text, conversationID: conversationID, appState: appState)
            return
        case .desktop:
            if await handleDeterministicDesktopTask(text, conversationID: conversationID, appState: appState) {
                return
            }
            if let fallback = taskRouter.continueRoute(from: routed, after: .desktop) {
                switch fallback.kind {
                case .code:
                    if await handleDeterministicCodeTask(text, conversationID: conversationID, appState: appState) { return }
                    await sendDeveloperAgentTask(agentInputText, displayText: text, conversationID: conversationID, appState: appState)
                    return
                case .fileSystem, .browser:
                    if await handleDeterministicToolTask(text, route: fallback.kind, conversationID: conversationID, appState: appState) { return }
                default: break
                }
            }
        case .fileSystem, .browser:
            if await handleDeterministicToolTask(text, route: routed.primaryRoute.kind, conversationID: conversationID, appState: appState) {
                return
            }
            if let fallback = taskRouter.continueRoute(from: routed, after: routed.primaryRoute.kind) {
                switch fallback.kind {
                case .code:
                    if await handleDeterministicCodeTask(text, conversationID: conversationID, appState: appState) { return }
                case .desktop:
                    if await handleDeterministicDesktopTask(text, conversationID: conversationID, appState: appState) { return }
                default: break
                }
            }
        case .mixed:
            let decomposed = taskRouter.decompose(text)
            if decomposed.subTasks.count > 1 {
                let userMsg = Message(role: .user, content: [.text(text)])
                sessionManager.appendMessage(userMsg, to: conversationID)
                let planText = "任务分解:\n\(decomposed.summary)"
                let planMsg = Message(id: UUID(), role: .assistant, content: [.text(planText)], timestamp: Date())
                sessionManager.updateMessage(planMsg, in: conversationID)

                // P2: Execute by parallel groups
                let groups = decomposed.executionGroups
                for group in groups {
                    if group.parallelTasks.count > 1 {
                        // Parallel execution within this group
                        await withTaskGroup(of: Void.self) { taskGroup in
                            for subTask in group.parallelTasks {
                                taskGroup.addTask {
                                    await self.sendMessage(subTask.prompt, appState: appState, depth: 1)
                                }
                            }
                        }
                    } else if let single = group.parallelTasks.first {
                        // Sequential execution
                        await sendMessage(single.prompt, appState: appState, depth: 1)
                    }
                }
                return
            }
        case .chat:
            break
        }

        let planGenerator = PlanGenerator()
        let plannerWantsPlan = await planGenerator.shouldPlan(agentInputText)
        let shouldPlan = routed.primaryRoute.kind == .mixed || plannerWantsPlan
        if shouldPlan {
            let context = await contextCompiler.compileContext()
            let tools = await mcpClient.tools(for: routed)
            if let plan = try? await planGenerator.generatePlan(
                userMessage: agentInputText,
                context: context,
                toolDefinitions: tools
            ) {
                let userMsg = Message(role: .user, content: [.text(text)])
                sessionManager.appendMessage(userMsg, to: conversationID)
                appState?.activePlan = plan
                return
            }
        }

        await handleUserMessage(
            agentInputText: agentInputText,
            displayText: text,
            conversationID: conversationID,
            appState: appState,
            routed: routed,
            recalledMemories: recalledMemories,
            originalText: text
        )
    }


    // MARK: - Voice (delegated)

    public func startVoiceInput(appState: AppState) async {
        _ = sessionLifecycle.transition(to: .listening, reason: "语音输入开始")
        await voiceSessionManager.startVoiceInput(appState: appState)
    }

    public func stopVoiceInput(appState: AppState) {
        voiceSessionManager.stopVoiceInput(appState: appState)
        if !isProcessing { _ = sessionLifecycle.transition(to: .idle, reason: "语音输入结束") }
    }

    public func cancelVoiceInput(appState: AppState) {
        voiceSessionManager.cancelVoiceInput(appState: appState)
    }

    public func finishVoiceInput(appState: AppState) -> String {
        voiceSessionManager.finishVoiceInput(appState: appState)
    }

    public func finishVoiceInputAndSend(appState: AppState) async {
        let blockListening = isProcessing && currentPhase != .acting
        await voiceSessionManager.finishVoiceInputAndSend(
            appState: appState,
            isProcessing: blockListening,
            activePlan: appState.activePlan,
            pendingConfirmation: appState.pendingConfirmation,
            sendMessage: { [weak self] text, state in
                await self?.sendMessage(text, appState: state)
            }
        )
    }

    // MARK: - Screen Stream & Cursor

    public func toggleScreenStream(appState: AppState) async {
        if isScreenStreamActive {
            await screenStreamProvider?.stopStream()
            screenStreamProvider = nil
            isScreenStreamActive = false
            appState.isScreenStreamActive = false
            await taskBag["cursor"]?.cancel()
            await taskBag.set(key: "cursor", task: nil)
        } else {
            let provider = ScreenStreamProvider()
            screenStreamProvider = provider
            do {
                try await provider.startStream(fps: 4, excludeOwnWindows: true)
                isScreenStreamActive = true
                appState.isScreenStreamActive = true
                // Start cursor tracking alongside the stream
                appState.cursorPosition = CursorController.currentPosition
                await taskBag.set(key: "cursor", task: Task { [weak self] in
                    while !Task.isCancelled {
                        let pos = CursorController.currentPosition
                        await MainActor.run {
                            self?.cursorPosition = pos
                            appState.cursorPosition = pos != .zero ? pos : nil
                        }
                        try? await Task.sleep(nanoseconds: 200_000_000)
                    }
                })
            } catch {
                appState.isScreenStreamActive = false
                self.screenStreamProvider = nil
                await taskBag["cursor"]?.cancel()
                await taskBag.set(key: "cursor", task: nil)
            }
        }
    }

    public func refreshCursorPosition(appState: AppState) {
        let pos = CursorController.currentPosition
        cursorPosition = pos
        appState.cursorPosition = pos != .zero ? pos : nil
    }

    public func stopVoiceOutput(appState: AppState) {
        voiceSessionManager.stopVoiceOutput(appState: appState)
    }

    // MARK: - Quick Actions

    public func quickAction(_ action: QuickAction) async throws -> String {
        switch action {
        case .openApp(let name):
            let result = try await mcpClient.execute(ToolCallRequest(
                id: UUID().uuidString,
                name: "open_app",
                arguments: ["app_name": name]
            ))
            return result.output

        case .systemInfo:
            let result = try await mcpClient.execute(ToolCallRequest(
                id: UUID().uuidString,
                name: "system_info",
                arguments: ["info_type": "all"]
            ))
            return result.output

        case .gitStatus(let path):
            let result = try await mcpClient.execute(ToolCallRequest(
                id: UUID().uuidString,
                name: "git_status",
                arguments: ["repo_path": path]
            ))
            return result.output

        case .shell(let command, let cwd):
            var args = ["command": command]
            if let cwd { args["cwd"] = cwd }
            let result = try await mcpClient.execute(ToolCallRequest(
                id: UUID().uuidString,
                name: "shell_command",
                arguments: args
            ))
            return result.output
        case .swiftBuild(let path):
            var args: [String: String] = [:]
            if let path { args["project_path"] = path }
            let result = try await mcpClient.execute(ToolCallRequest(
                id: UUID().uuidString,
                name: "swift_build",
                arguments: args
            ))
            return result.output
        case .swiftTest(let path):
            var args: [String: String] = [:]
            if let path { args["project_path"] = path }
            let result = try await mcpClient.execute(ToolCallRequest(
                id: UUID().uuidString,
                name: "swift_test",
                arguments: args
            ))
            return result.output
        case .analyzeBuildErrors:
            return await analyzeBuildErrors(appState: nil)
        case .analyzeTestFailures:
            return await analyzeTestFailures(appState: nil)
        }
    }

    public func indexProject(at path: String) async throws {
        try await ragEngine.indexProject(at: path)
    }

    // MARK: - Scenarios

    public func polishSelectedText(appState: AppState?) async -> String {
        let bridge = AccessibilityBridge()
        guard let selected = try? await bridge.getSelectedText(), !selected.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "没有选中文字。请先选中要润色的文字。"
        }

        let context = await contextCompiler.compileContext()
        let prompt = """
        润色以下文字，使其更简洁流畅。只返回润色后的文字，不要解释。

        原文:
        \(selected)
        """

        do {
            let result = try await smartRouter.chatWithFallback(
                messages: [Message(role: .user, content: [.text(prompt)])],
                tools: nil,
                delegate: nil,
                context: context
            )
            let polished = result.message.textContent.trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                try await bridge.pressKey("a", modifiers: ["command"])
                try? await Task.sleep(for: .milliseconds(100))
                try await bridge.typeText(polished)
                appState?.devMode.lastBuildResult = nil
                return "已润色并替换。"
            } catch {
                return "润色完成，但替换失败: \(error.localizedDescription)\n\n润色结果:\n\(polished)"
            }
        } catch {
            return "润色失败: \(error.localizedDescription)"
        }
    }

    public func explainSelectedText(appState: AppState?) async -> String {
        let bridge = AccessibilityBridge()
        guard let selected = try? await bridge.getSelectedText(), !selected.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "没有选中文字。请先选中要解释的内容。"
        }

        let context = await contextCompiler.compileContext()
        let prompt = """
        解释以下内容。如果是代码，说明逻辑和作用。如果是文字，简要解释含义。用中文。

        \(selected)
        """

        do {
            let result = try await smartRouter.chatWithFallback(
                messages: [Message(role: .user, content: [.text(prompt)])],
                tools: nil,
                delegate: nil,
                context: context
            )
            return result.message.textContent
        } catch {
            return "解释失败: \(error.localizedDescription)"
        }
    }

    public func readScreenContent(appState: AppState?) async -> String {
        let bridge = AccessibilityBridge()
        var lines: [String] = []
        let screen = await screenContextProvider.captureCurrentScreen(includeImageData: true)
        lastScreenContext = screen
        lastScreenContextCapturedAt = Date()

        if let bundleID = try? await bridge.getFocusedAppBundleID() {
            lines.append("前台应用: \(bundleID)")
        }
        if let windowTitle = try? await bridge.getFocusedWindowTitle() {
            lines.append("当前窗口: \(windowTitle)")
        }
        if let role = try? await bridge.getElementRole() {
            lines.append("焦点控件: \(role)")
        }
        if let value = try? await bridge.getFocusedValue(), !value.isEmpty {
            lines.append("焦点内容: \(value.prefix(300))")
        }
        if let selected = try? await bridge.getSelectedText(), !selected.isEmpty {
            lines.append("选中文字: \(selected.prefix(500))")
        }
        let ocrText = screen.recognizedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !ocrText.isEmpty {
            lines.append("\n屏幕 OCR:")
            lines.append(String(ocrText.prefix(1800)))
        } else {
            lines.append("\n屏幕读取状态: \(screen.displayDescription)")
            if !screen.visibleWindows.isEmpty {
                lines.append("\n可见窗口:")
                for window in screen.visibleWindows.prefix(8) {
                    let title = window.windowTitle.flatMap { $0.isEmpty ? nil : " - \($0)" } ?? ""
                    lines.append("- \(window.ownerName)\(title)")
                }
            }
        }
        if let tree = try? await bridge.getUIElementTree(maxDepth: 3), !tree.isEmpty {
            lines.append("\nUI 结构:")
            for node in tree.prefix(12) {
                let indent = String(repeating: "  ", count: min(node.depth, 3))
                let title = node.title.map { " \"\($0)\"" } ?? ""
                lines.append("  \(indent)\(node.role)\(title)")
            }
        }
        return lines.joined(separator: "\n")
    }


    /// Build a system prompt hint from a ComputerUsePlan — provides reference steps for known command patterns.

    // MARK: - Developer Mode

    public func buildProject(appState: AppState?) async -> BuildResult {
        let projectPath = appState?.devMode.projectPath ?? contextCompiler.currentContext?.rootPath
        let cwd = projectPath ?? FileManager.default.currentDirectoryPath

        await publishCodeEvent(.buildStarted(target: cwd))
        let result: BuildResult
        do {
            let response = try await mcpClient.execute(ToolCallRequest(
                id: UUID().uuidString,
                name: "swift_build",
                arguments: ["project_path": cwd]
            ), policy: .permissive)
            let success = !response.isError
            let diagnostics = XcodeDriver.parseBuildDiagnostics(from: response.output)
            let errors = diagnostics.filter { $0.severity == .error }
            let warnings = diagnostics.filter { $0.severity == .warning }
            result = BuildResult(
                success: success,
                errors: errors,
                warnings: warnings,
                durationSeconds: 0,
                rawOutput: response.output
            )
            await publishCodeEvent(.buildCompleted(exitCode: response.isError ? 1 : 0, errorCount: errors.count, warningCount: warnings.count))
            if !success {
                await publishCodeEvent(.buildFailed(stderr: response.output))
            }
        } catch {
            result = BuildResult(
                success: false,
                errors: [BuildDiagnostic(message: error.localizedDescription, severity: .error)],
                rawOutput: error.localizedDescription
            )
            await publishCodeEvent(.buildFailed(stderr: error.localizedDescription))
        }
        appState?.devMode.lastBuildResult = result
        return result
    }

    public func runTests(appState: AppState?) async -> TestResult {
        let projectPath = appState?.devMode.projectPath ?? contextCompiler.currentContext?.rootPath
        let cwd = projectPath ?? FileManager.default.currentDirectoryPath

        await publishCodeEvent(.testStarted(filter: nil))
        let result: TestResult
        do {
            let response = try await mcpClient.execute(ToolCallRequest(
                id: UUID().uuidString,
                name: "swift_test",
                arguments: ["project_path": cwd]
            ), policy: .permissive)
            let success = !response.isError
            let failures = success ? [] : [TestFailure(testName: "测试套件", message: response.output)]
            result = TestResult(
                success: success,
                failures: failures,
                rawOutput: response.output
            )
            await publishCodeEvent(.testCompleted(passed: success ? 1 : 0, failed: success ? 0 : 1, duration: 0))
        } catch {
            result = TestResult(
                success: false,
                failures: [TestFailure(testName: "执行失败", message: error.localizedDescription)],
                rawOutput: error.localizedDescription
            )
            await publishCodeEvent(.testFailed(name: "执行失败", message: error.localizedDescription))
        }
        appState?.devMode.lastTestResult = result
        return result
    }

    public func analyzeBuildErrors(appState: AppState?) async -> String {
        guard let buildResult = appState?.devMode.lastBuildResult else {
            return "没有构建结果可分析。请先运行构建。"
        }
        guard !buildResult.success else {
            return "构建成功，无需分析。"
        }
        do {
            return try await buildErrorAnalyzer.analyze(
                buildResult: buildResult,
                projectPath: appState?.devMode.projectPath
            )
        } catch {
            return "分析失败: \(error.localizedDescription)"
        }
    }

    public func analyzeTestFailures(appState: AppState?) async -> String {
        guard let testResult = appState?.devMode.lastTestResult else {
            return "没有测试结果可分析。请先运行测试。"
        }
        guard !testResult.success else {
            return "测试全部通过，无需分析。"
        }
        do {
            return try await buildErrorAnalyzer.analyze(
                testResult: testResult,
                projectPath: appState?.devMode.projectPath
            )
        } catch {
            return "分析失败: \(error.localizedDescription)"
        }
    }

    // MARK: - Tool Safety (delegated)

    public func policyFor(_ appState: AppState?) -> ToolExecutionPolicy {
        appState?.toolExecutionPolicy ?? .default
    }

    func executeWithAudit(_ request: ToolCallRequest, appState: AppState?) async -> ToolCallResult {
        (try? await toolExecutionService.executeWithAudit(request, appState: appState))
            ?? ToolCallResult(id: request.id, output: "执行失败", isError: true)
    }

    public func requestConfirmation(assessment: ToolRiskAssessment, appState: AppState?) async -> Bool {
        await toolExecutionService.requestConfirmation(assessment: assessment, appState: appState)
    }

    public func resolveConfirmation(approved: Bool, appState: AppState?) {
        toolExecutionService.resolveConfirmation(approved: approved, appState: appState)
    }

    // MARK: - ComputerUse Step Retry / Force Approve

    public func retryComputerUseStep(stepID: String, appState: AppState?) async {
        guard let trace = lastComputerUseTrace,
              let step = trace.run.steps.first(where: { $0.action.toolCall.id == stepID }) else { return }
        setPhase(.recovering, reason: "重试步骤: \(step.action.toolCall.name)")
        _ = await computerUseRuntime.run(
            actions: [step.action],
            policy: appState?.toolExecutionPolicy ?? .default,
            recoveryScoreByStrategy: currentRecoveryProfile.strategies.reduce(into: [:]) {
                $0[$1.strategy] = $1.successRate
            },
            onStepVoiceFeedback: { [weak self] text in
                guard let self, let appState else { return }
                await self.voiceSessionManager.speakIfNeeded(text, appState: appState)
            }
        )
        setPhase(.idle, reason: "重试完成")
    }

    public func approveComputerUseStep(stepID: String) {
        guard let trace = lastComputerUseTrace,
              let step = trace.run.steps.first(where: { $0.action.toolCall.id == stepID }),
              !step.verified else { return }
        var updatedSteps = trace.run.steps
        if let idx = updatedSteps.firstIndex(where: { $0.action.toolCall.id == stepID }) {
            let approved = step
            var withApproval = approved
            withApproval = ComputerUseStepResult(
                action: approved.action,
                beforeState: approved.beforeState,
                toolResult: approved.toolResult,
                afterState: approved.afterState,
                stateDelta: approved.stateDelta,
                verified: true,
                verificationEvidence: approved.verificationEvidence + ["手动批准"]
            )
            updatedSteps[idx] = withApproval
        }
        let updatedRun = ComputerUseRunResult(
            startedAt: trace.run.startedAt,
            finishedAt: trace.run.finishedAt,
            steps: updatedSteps
        )
        lastComputerUseTrace = ComputerUseTraceSnapshot(
            phase: trace.phase,
            taskText: trace.taskText,
            routeLabel: trace.routeLabel,
            browserPageState: trace.browserPageState,
            run: updatedRun,
            events: trace.events
        )
    }

    // MARK: - Plan Execution (delegated)

    public func approvePlan(appState: AppState?) async {
        await planExecutor.approvePlan(appState: appState)
    }

    public func cancelPlan(appState: AppState?) {
        planExecutor.cancelPlan(appState: appState)
    }

    // MARK: - Workflow Memory

    private func classifyFailure(_ reason: String) -> FailureCategory {
        let lower = reason.lowercased()
        if lower.contains("timeout") || lower.contains("超时") { return .timeout }
        if lower.contains("permission") || lower.contains("denied") || lower.contains("权限") { return .permissionDenied }
        if lower.contains("not found") || lower.contains("找不到") || lower.contains("不存在") { return .elementNotFound }
        if lower.contains("network") || lower.contains("网络") { return .networkError }
        if lower.contains("build") || lower.contains("编译") || lower.contains("linker") { return .buildError }
        if lower.contains("test") || lower.contains("测试") { return .testFailure }
        if lower.contains("unresponsive") || lower.contains("未响应") || lower.contains("not responding") { return .appUnresponsive }
        return .unknown
    }

    func remember(
        task: String,
        steps: [String],
        success: Bool,
        failureReason: String? = nil,
        learnedWorkflow: String? = nil,
        domain: String? = nil,
        appName: String? = nil,
        projectPath: String? = nil,
        tags: [String] = []
    ) async {
        let category: FailureCategory? = if let reason = failureReason { classifyFailure(reason) } else { nil }
        await workflowMemoryStore.remember(
            task: task,
            steps: steps,
            success: success,
            failureReason: failureReason,
            failureCategory: category,
            learnedWorkflow: learnedWorkflow ?? (success ? steps.joined(separator: " -> ") : nil),
            domain: domain ?? latestRoute?.primaryRoute.kind.rawValue,
            appName: appName,
            projectPath: projectPath ?? currentDesktopContext?.projectContext?.rootPath,
            tags: tags
        )
        if success, steps.count >= 2 {
            let name = String(task.prefix(32))
            _ = await skillRegistry.learn(
                name: name,
                description: "从成功任务自动沉淀的工作流",
                triggerPhrases: [name],
                steps: steps
            )
        }
        workflowMemories = await workflowMemoryStore.all()
        skills = await skillRegistry.all()
    }

    func formatComputerUseRun(_ run: ComputerUseRunResult) -> String {
        var lines = ["Computer Use 执行\(run.succeeded ? "完成" : "未完成"):"]
        for (index, step) in run.steps.enumerated() {
            let status = step.toolResult.isError ? "失败" : (step.verified ? "已验证" : "未验证")
            lines.append("\(index + 1). \(step.action.toolCall.name) - \(status)")
            if !step.toolResult.output.isEmpty {
                lines.append(String(step.toolResult.output.prefix(800)))
            }
            if let stateDelta = step.stateDelta {
                lines.append("变化: \(stateDelta.summary)")
            }
            if !step.verificationEvidence.isEmpty {
                lines.append("证明: \(step.verificationEvidence.joined(separator: "；"))")
            }
            if let recoverySummary = step.recoverySummary, !recoverySummary.isEmpty {
                lines.append("恢复: \(recoverySummary)")
            }
        }
        return lines.joined(separator: "\n")
    }

    func fetchBrowserPageState(for action: ComputerUseAction) async -> BrowserPageState? {
        guard let browserApp = inferredBrowserApp(for: action) else { return nil }
        let request = ToolCallRequest(
            id: UUID().uuidString,
            name: "get_browser_state",
            arguments: ["app": browserApp]
        )
        guard let result = try? await mcpClient.execute(request, policy: .permissive),
              !result.isError,
              let data = result.output.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(BrowserPageState.self, from: data)
    }

    func fetchFinderState() async -> FinderWindowState? {
        let request = ToolCallRequest(
            id: UUID().uuidString,
            name: "get_finder_state",
            arguments: [:]
        )
        guard let result = try? await mcpClient.executeLowRisk(request),
              !result.isError,
              let data = result.output.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(FinderWindowState.self, from: data)
    }

    private func inferredBrowserApp(for action: ComputerUseAction) -> String? {
        if let app = action.verificationGoal?.expectedApp {
            if app.localizedCaseInsensitiveContains("chrome") {
                return "Chrome"
            }
            if app.localizedCaseInsensitiveContains("safari") {
                return "Safari"
            }
        }

        switch action.toolCall.name {
        case "open_url", "safari_search", "get_browser_state":
            return "Safari"
        default:
            return nil
        }
    }

    func extractAppName(from text: String) -> String? {
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.localizedName }
        let lowerText = text.lowercased()

        // 1. Exact substring match against running apps (case-insensitive)
        if let exact = runningApps.first(where: { lowerText.contains($0.lowercased()) }) {
            return exact
        }
        if let exact = runningApps.first(where: { $0.lowercased().contains(lowerText) }) {
            return exact
        }

        // 2. Acronym match: "vs code" → "Visual Studio Code"
        let words = lowerText.split(separator: " ")
        if words.count >= 2 {
            if let acronym = runningApps.first(where: { app in
                let appWords = app.split(separator: " ")
                return appWords.count >= words.count
                    && zip(words, appWords).allSatisfy { w, aw in
                        aw.lowercased().hasPrefix(w.lowercased())
                    }
            }) {
                return acronym
            }
        }

        // 3. Character overlap ratio (Dice-like) for fuzzy match
        let bestRunning = runningApps.max(by: { a, b in
            Self.charOverlap(lowerText, a.lowercased()) < Self.charOverlap(lowerText, b.lowercased())
        })
        if let best = bestRunning, Self.charOverlap(lowerText, best.lowercased()) > 0.45 {
            return best
        }

        // 4. Chinese name mapping fallback
        let cnMap: [String: String] = [
            "访达": "Finder", "终端": "Terminal", "系统设置": "System Settings",
            "微信": "WeChat", "邮件": "Mail", "日历": "Calendar",
            "备忘录": "Notes", "提醒": "Reminders", "音乐": "Music",
            "照片": "Photos", "信息": "Messages", "预览": "Preview",
            "计算器": "Calculator", "词典": "Dictionary",
        ]
        for (cn, en) in cnMap {
            if lowerText.contains(cn) { return en }
        }

        // 5. Known English names
        let knownApps = ["Safari", "Finder", "Terminal", "Xcode", "System Settings", "WeChat"]
        if let known = knownApps.first(where: { lowerText.contains($0.lowercased()) }) {
            return known
        }

        // 6. Marker-based extraction: "打开 X", "启动 Y", "open Z"
        let markers = ["打开", "启动", "open", "切换到", "switch to", "激活", "activate"]
        for marker in markers where lowerText.contains(marker.lowercased()) {
            if let range = text.range(of: marker, options: .caseInsensitive) {
                let candidate = text[range.upperBound...]
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                if !candidate.isEmpty {
                    // Try fuzzy match this candidate against running apps first
                    let candidateLower = candidate.lowercased()
                    if let match = runningApps.first(where: { $0.lowercased().contains(candidateLower) }) {
                        return match
                    }
                    let best = runningApps.max(by: { a, b in
                        Self.charOverlap(candidateLower, a.lowercased()) < Self.charOverlap(candidateLower, b.lowercased())
                    })
                    if let best, Self.charOverlap(candidateLower, best.lowercased()) > 0.3 {
                        return best
                    }
                    // If it's a known CLI/dev tool (not a desktop app), return nil
                    // so the flow falls through to code/developer handlers
                    if Self.isCLITool(candidateLower) { return nil }
                    return candidate
                }
            }
        }

        return nil
    }

    private static let cliTools: Set<String> = [
        "claude code", "claudecode", "claude",
        "git", "npm", "pnpm", "yarn", "bun",
        "swift", "xcodebuild", "swiftc",
        "python", "python3", "node",
        "docker", "brew", "pod", "carthage",
        "make", "cmake", "gcc", "rustc", "cargo",
        "ssh", "scp", "curl", "wget",
    ]

    private static func isCLITool(_ name: String) -> Bool {
        cliTools.contains(name) || cliTools.contains(where: { name.contains($0) })
    }

    private static func charOverlap(_ a: String, _ b: String) -> Double {
        let setA = Set(a.filter { !$0.isWhitespace })
        let setB = Set(b.filter { !$0.isWhitespace })
        guard !setA.isEmpty, !setB.isEmpty else { return 0 }
        let intersection = setA.intersection(setB)
        return Double(intersection.count) / Double(max(setA.count, setB.count))
    }

    func extractURL(from text: String) -> URL? {
        let pieces = text.split(separator: " ").map(String.init)
        for piece in pieces {
            if let url = URL(string: piece), url.scheme?.hasPrefix("http") == true {
                return url
            }
        }
        return nil
    }

    func extractTerminalCommand(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let markers = [
            "在终端运行",
            "终端运行",
            "运行命令",
            "执行命令",
            "run command",
        ]

        for marker in markers {
            if let range = trimmed.range(of: marker, options: [.caseInsensitive]) {
                let command = trimmed[range.upperBound...]
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                if !command.isEmpty {
                    return command
                }
            }
        }

        let lower = trimmed.lowercased()
        let commandPrefixes = ["git ", "swift ", "npm ", "pnpm ", "yarn ", "python ", "python3 ", "node ", "ls ", "pwd"]
        if commandPrefixes.contains(where: { lower.hasPrefix($0) }) {
            return trimmed
        }

        return nil
    }

    func extractWebSearchQuery(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let markers = ["搜索网页", "搜索", "查一下", "搜一下", "search for", "search "]

        for marker in markers {
            if let range = trimmed.range(of: marker, options: [.caseInsensitive]) {
                let query = trimmed[range.upperBound...]
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                if !query.isEmpty {
                    return query
                }
            }
        }
        return nil
    }

    func extractFinderSearchQuery(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let markers = ["查找文件", "搜索文件", "找文件", "find file", "search file"]

        for marker in markers {
            if let range = trimmed.range(of: marker, options: [.caseInsensitive]) {
                let query = trimmed[range.upperBound...]
                    .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
                if !query.isEmpty {
                    return query
                }
            }
        }
        return nil
    }
}

// MARK: - Quick Actions

public enum QuickAction: Sendable {
    case openApp(String)
    case systemInfo
    case gitStatus(path: String)
    case shell(command: String, cwd: String?)
    case swiftBuild(path: String?)
    case swiftTest(path: String?)
    case analyzeBuildErrors
    case analyzeTestFailures
}
