import Foundation
import AppKit
import os
import RenJistrolyModels
import RenJistrolyIntelligence
import RenJistrolyCapability
import RenJistrolySystemBridge

// MARK: - Message Handling

extension ConversationEngine {
    static func makeUserMessagePair(displayText: String, modelText: String) -> (visible: Message, model: Message) {
        let visible = Message(role: .user, content: [.text(displayText)])
        let model = Message(
            id: visible.id,
            role: .user,
            content: [.text(modelText)],
            timestamp: visible.timestamp,
            tokenCount: visible.tokenCount
        )
        return (visible, model)
    }

    func handleUserMessage(
        agentInputText: String,
        displayText: String,
        conversationID: UUID,
        appState: AppState?,
        routed: RoutedTask,
        recalledMemories: [TaskMemory],
        originalText: String
    ) async {
        isProcessing = true
        if currentPhase == .acting {
            await computerUseRuntime.cancel()
        }
        setPhase(.thinking, reason: "开始处理消息")
        await publishLifecycleEvent(.thinkingStarted(reason: originalText.prefix(40).description))
        toolExecutionService.updatePolicy(appState?.toolExecutionPolicy ?? .default)

        let context = await contextCompiler.compileContext()
        let desktopContext = await desktopContextCollector.collect(projectContext: context)
        currentDesktopContext = desktopContext
        let ragContext = await ragEngine.buildContext(agentInputText)
        var systemPrompt = contextCompiler.compileSystemPrompt(
            context: context,
            desktopContext: desktopContext,
            workflowMemories: recalledMemories
        )

        // P0: Inject skill-specific system prompt
        let skillContextPrompt = await mcpClient.skillPrompt(for: routed)
        if !skillContextPrompt.isEmpty {
            systemPrompt += "\n\n\(skillContextPrompt)"
        }

        if let screenPrompt = await screenContextPrompt(for: agentInputText) {
            systemPrompt += "\n\n\(screenPrompt)"
        }
        let enrichedText = ragContext.isEmpty ? agentInputText : "\(agentInputText)\n\n相关代码:\n\(ragContext)"

        // Phase 3: ComputerUsePlanner — detect known command patterns and inject as reference plan
        let planner = ComputerUsePlanner()
        let currentObservation = await ComputerUseObserver(
            accessibility: AccessibilityContextProvider(),
            screen: screenContextProvider
        ).observe(includeOCR: false)
        if let plan = planner.plan(userText: agentInputText, observation: currentObservation) {
            systemPrompt += "\n\n" + buildPlanHint(plan)
        }

        let messagePair = Self.makeUserMessagePair(displayText: displayText, modelText: enrichedText)
        let userMessage = messagePair.visible
        sessionManager.appendMessage(userMessage, to: conversationID)

        var allMessages = sessionManager.activeConversation?.messages ?? []
        if let index = allMessages.lastIndex(where: { $0.id == userMessage.id }) {
            allMessages[index] = messagePair.model
        }
        if !systemPrompt.isEmpty {
            allMessages.insert(Message(role: .system, content: [.text(systemPrompt)]), at: 0)
        }

        let responseID = sessionManager.beginStreamingResponse(in: conversationID, context: context)
        currentResponseID = responseID

        // P0: Use skill-filtered tools to reduce LLM prompt noise
        let availableTools = routed.primaryRoute.kind == .mixed
            ? await mcpClient.availableTools
            : await mcpClient.tools(for: routed)

        do {
            try await buildResponse(
                allMessages: allMessages,
                context: context,
                availableTools: availableTools,
                responseID: responseID,
                conversationID: conversationID,
                appState: appState
            )
            setPhase(.responding, reason: "回复完成")
            await publishLifecycleEvent(.thinkingCompleted)
        } catch {
            await handleResponseError(
                error,
                responseID: responseID,
                conversationID: conversationID,
                appState: appState
            )
        }

        isProcessing = false
        currentResponseID = nil
        if sessionLifecycle.phase != .idle {
            setPhase(.idle, reason: "处理完成")
        }
    }

    /// LLM call with AgentOrchestrator and streaming response processing.
    private func buildResponse(
        allMessages: [Message],
        context: ProjectContext?,
        availableTools: [ToolDefinition],
        responseID: UUID,
        conversationID: UUID,
        appState: AppState?
    ) async throws {
        let response = try await agentOrchestrator.execute(
            messages: allMessages,
            context: context,
            availableTools: availableTools,
            toolExecutor: { [weak self] request in
                guard let self else {
                    return ToolCallResult(id: request.id, output: "引擎已释放", isError: true)
                }
                return try await self.toolExecutionService.executeWithAudit(request, appState: appState)
            },
            computerUseExecutor: { [weak self, computerUseRuntime] actions, app, policy in
                guard let self else {
                    return ComputerUseRunResult(startedAt: Date(), steps: [])
                }
                return await computerUseRuntime.run(
                    actions: actions,
                    app: app,
                    policy: policy,
                    onStepUpdate: { [weak self] partialRun in
                        guard let self else { return }
                        await MainActor.run {
                            self.lastComputerUseTrace = ComputerUseTraceSnapshot(
                                phase: "running",
                                taskText: "",
                                routeLabel: "agent",
                                run: partialRun
                            )
                        }
                    },
                    onTraceEvent: { _ in },
                    onStepVoiceFeedback: { [weak self] text in
                        guard let self else { return }
                        await self.voiceSessionManager.speakIfNeeded(text, appState: appState)
                    }
                )
            },
            screenshotProvider: {
                try? await ScreenCaptureBridge().captureScreen()
            },
            policy: appState?.toolExecutionPolicy ?? .default
        )

        var finalMessage = response.finalMessage
        finalMessage = Message(
            id: responseID,
            role: finalMessage.role,
            content: finalMessage.content,
            timestamp: finalMessage.timestamp,
            tokenCount: finalMessage.tokenCount
        )
        sessionManager.updateMessage(finalMessage, in: conversationID)
        sessionManager.finishStreamingResponse(messageID: responseID, in: conversationID)
        await voiceSessionManager.speakIfNeeded(finalMessage.textContent, appState: appState)

        for result in response.toolResults {
            let toolMsg = Message(role: .tool, content: [.toolResult(result)])
            sessionManager.appendMessage(toolMsg, to: conversationID)
        }
    }

    /// Handle all error types from the LLM execution flow.
    private func handleResponseError(
        _ error: Error,
        responseID: UUID,
        conversationID: UUID,
        appState: AppState?
    ) async {
        switch error {
        case let confirmation as ToolNeedsConfirmationError:
            let approved = await toolExecutionService.requestConfirmation(assessment: confirmation.assessment, appState: appState)
            guard approved else {
                toolExecutionService.recordExecution(
                    toolName: confirmation.request.name,
                    riskLevel: confirmation.assessment.riskLevel,
                    arguments: confirmation.request.arguments,
                    outcome: .rejected,
                    appState: appState
                )
                await toolExecutionService.recordSafetyAudit(assessment: confirmation.assessment, decision: .denied, note: "User rejected")
                let rejectMsg = Message(id: responseID, role: .assistant, content: [.text("已取消: \(confirmation.assessment.summary)")])
                sessionManager.updateMessage(rejectMsg, in: conversationID)
                sessionManager.finishStreamingResponse(messageID: responseID, in: conversationID)
                return
            }
            do {
                let result = try await mcpClient.executePreAssessed(confirmation.request)
                await toolExecutionService.recordSafetyAudit(assessment: confirmation.assessment, decision: .allowedOnce)
                toolExecutionService.recordExecution(
                    toolName: confirmation.request.name,
                    riskLevel: confirmation.assessment.riskLevel,
                    arguments: confirmation.request.arguments,
                    outcome: .confirmed(result.output),
                    appState: appState
                )
                let confirmedMsg = Message(id: responseID, role: .assistant, content: [.text("已完成: \(confirmation.assessment.summary)\n\n\(result.output)")])
                sessionManager.updateMessage(confirmedMsg, in: conversationID)
                sessionManager.finishStreamingResponse(messageID: responseID, in: conversationID)
                await voiceSessionManager.speakIfNeeded("已完成: \(confirmation.assessment.summary)", appState: appState)
            } catch {
                toolExecutionService.recordExecution(
                    toolName: confirmation.request.name,
                    riskLevel: confirmation.assessment.riskLevel,
                    arguments: confirmation.request.arguments,
                    outcome: .failed(error.localizedDescription),
                    appState: appState
                )
                let failMsg = Message(id: responseID, role: .assistant, content: [.text("执行失败: \(error.localizedDescription)")])
                sessionManager.updateMessage(failMsg, in: conversationID)
                sessionManager.finishStreamingResponse(messageID: responseID, in: conversationID)
            }

        case let error as AgentError:
            let msg: String = switch error {
            case .noAvailableBackend(let detail):
                if let detail { "所有 AI 后端均不可用: \(detail)" }
                else { "没有可用的 AI 后端，请检查设置。" }
            case .maxIterationsReached: "工具调用超过上限，请简化指令。"
            case .tooManyAgents: "并行任务过多，请稍后再试。"
            case .toolExecutionFailed(let detail): "工具执行失败: \(detail)"
            }
            let errorMessage = Message(id: responseID, role: .assistant, content: [.text(msg)])
            sessionManager.updateMessage(errorMessage, in: conversationID)
            sessionManager.finishStreamingResponse(messageID: responseID, in: conversationID)
            setPhase(.idle, reason: "错误结束")

        default:
            let errorMessage = Message(
                id: responseID,
                role: .assistant,
                content: [.text("抱歉，发生了错误: \(error.localizedDescription)")]
            )
            sessionManager.updateMessage(errorMessage, in: conversationID)
            sessionManager.finishStreamingResponse(messageID: responseID, in: conversationID)
            setPhase(.idle, reason: "异常结束")
        }
    }

    // MARK: - Claude Code CLI Path

    func sendDeveloperAgentTask(_ text: String, displayText: String? = nil, conversationID: UUID, appState: AppState?) async {
        isProcessing = true
        let context = await contextCompiler.compileContext()
        let task = await developerAgentStore.create(prompt: text, cwd: context.rootPath)
        await developerAgentStore.beginExternalRun(task.id)

        let userMessage = Message(role: .user, content: [.text(displayText ?? text)])
        sessionManager.appendMessage(userMessage, to: conversationID)
        let responseID = sessionManager.beginStreamingResponse(in: conversationID, context: context)
        currentResponseID = responseID

        await multiAgentBoard.update(
            agentBoardItems.first { $0.role == .code }?.id ?? UUID(),
            status: .running,
            latestLog: "Claude Code 开发闭环启动"
        )

        await startDeveloperTaskSyncLoop(taskID:task.id)

        var allOutput = ""
        var lastTokenUpdate: Date = Date()
        let loopStream = await developerLoop.run(prompt: text, cwd: context.rootPath)
        var developerLoopTimedOut = false
        let timeoutDate = Date().addingTimeInterval(300)
        for await event in loopStream {
            guard Date() < timeoutDate else {
                developerLoopTimedOut = true
                break
            }
            var line: String?
            switch event {
            case .phaseChange(let phase):
                line = Self.phaseLabel(phase)
                await multiAgentBoard.update(
                    agentBoardItems.first { $0.role == .code }?.id ?? UUID(),
                    status: .running,
                    latestLog: line ?? ""
                )
                let status = await developerLoop.currentState()
                await developerAgentStore.updateOutput(task.id, status.allOutput)
            case .token(let t):
                allOutput += t
                let now = Date()
                if now.timeIntervalSince(lastTokenUpdate) > 0.15 {
                    sessionManager.appendStreamToken(t, messageID: responseID, in: conversationID)
                    lastTokenUpdate = now
                }
            case .toolCall(let name):
                line = "\u{1F527} \(name)"
            case .toolError(let name, let error):
                line = "\u{26A0}\u{FE0F} \(name) 失败: \(error.prefix(80))"
            case .llmError(let e):
                line = "\u{274C} \(e)"
            case .buildFailed(let errors):
                line = "构建失败: \(errors.prefix(3).joined(separator: "; "))"
            case .buildSucceeded:
                line = "构建成功"
            case .testFailed(let failures):
                line = "测试失败: \(failures.prefix(3).joined(separator: "; "))"
            case .testSucceeded:
                line = "测试通过"
            case .patchApplied(let summary):
                line = "已应用补丁: \(summary.prefix(100))"
            case .verificationResult(let passed):
                line = passed ? "验证通过" : "验证未通过"
            case .loopExhausted(let reason):
                line = "开发闭环耗尽: \(reason)"
            case .completed(let summary):
                line = summary
            }
            if let line {
                sessionManager.appendStreamToken("\n\(line)\n", messageID: responseID, in: conversationID)
            }
            developerTasks = await developerAgentStore.allTasks()
            recentAgentTimeline = Self.buildRecentAgentTimeline(
                developerTasks: developerTasks,
                computerUseTrace: lastComputerUseTrace
            )
        }

        if developerLoopTimedOut {
            let timeoutMessage = "开发闭环超时（300 秒），已强制终止"
            sessionManager.appendStreamToken("\n\(timeoutMessage)\n", messageID: responseID, in: conversationID)
        }

        // Drain remaining buffered tokens
        if !allOutput.isEmpty {
            await developerAgentStore.updateOutput(task.id, allOutput)
        }

        let finalState = await developerLoop.currentState()
        let succeeded = finalState.phase == .completed
        await developerAgentStore.complete(task.id, success: succeeded, summary: allOutput)

        developerTasks = await developerAgentStore.allTasks()
        recentAgentTimeline = Self.buildRecentAgentTimeline(
            developerTasks: developerTasks,
            computerUseTrace: lastComputerUseTrace
        )
        await multiAgentBoard.update(
            agentBoardItems.first { $0.role == .code }?.id ?? UUID(),
            status: succeeded ? .completed : .failed,
            latestLog: allOutput.suffix(200).description
        )
        agentBoardItems = await multiAgentBoard.all()

        let finalText: String = {
            let trimmed = allOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? (succeeded ? "开发闭环完成" : "开发闭环未能完成") : trimmed
        }()
        let finalMessage = Message(id: responseID, role: .assistant, content: [.text(finalText)], timestamp: Date())
        sessionManager.updateMessage(finalMessage, in: conversationID)
        sessionManager.finishStreamingResponse(messageID: responseID, in: conversationID)
        await remember(task: text, steps: ["route: code", "developer loop"], success: succeeded, failureReason: succeeded ? nil : finalText)
        await voiceSessionManager.speakIfNeeded(finalText, appState: appState)

        isProcessing = false
        currentResponseID = nil
    }

    private static func phaseLabel(_ phase: DeveloperLoop.Phase) -> String {
        switch phase {
        case .planning: return "规划中..."
        case .building: return "构建中..."
        case .fixing: return "修复中..."
        case .testing: return "测试中..."
        case .verifying: return "验证中..."
        case .deploying: return "部署中..."
        case .restarting: return "重启中..."
        case .summarizing: return "汇总中..."
        case .completed: return "完成"
        case .failed: return "失败"
        }
    }

    func startDeveloperTaskSyncLoop(taskID: UUID) async {
        await taskBag["devSync"]?.cancel()
        await taskBag.set(key: "devSync", task: Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let current = await self.developerAgentStore.task(taskID)
                await self.refreshDeveloperTasks()
                self.recentAgentTimeline = Self.buildRecentAgentTimeline(
                    developerTasks: self.developerTasks,
                    computerUseTrace: self.lastComputerUseTrace
                )
                guard let current else { break }

                await self.multiAgentBoard.update(
                    self.agentBoardItems.first { $0.role == .code }?.id ?? UUID(),
                    status: current.status,
                    latestLog: current.output.suffix(200).description
                )
                self.agentBoardItems = await self.multiAgentBoard.all()

                if self.isTerminalDeveloperTaskStatus(current.status) {
                    break
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        })
    }

    private func isTerminalDeveloperTaskStatus(_ status: AgentTaskStatus) -> Bool {
        switch status {
        case .completed, .failed, .cancelled, .waitingForConfirmation, .paused:
            return true
        case .queued, .running:
            return false
        }
    }

    static func formatDeveloperTaskFinalText(_ task: DeveloperAgentTask) -> String {
        let trimmedOutput = task.output.trimmingCharacters(in: .whitespacesAndNewlines)
        var sections: [String] = []

        switch task.status {
        case .waitingForConfirmation:
            sections.append("Claude Code 任务暂停，等待确认后继续。")
            if let pending = task.pendingApprovalSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !pending.isEmpty {
                sections.append("待批准: \(pending)")
            }
        case .completed:
            if let summary = task.resultSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                sections.append(summary)
            } else if trimmedOutput.isEmpty {
                sections.append("Claude Code 开发任务已结束。")
            }
        case .failed:
            sections.append("Claude Code 任务失败。")
        case .cancelled:
            sections.append("Claude Code 任务已取消。")
        case .paused:
            sections.append("Claude Code 任务已暂停（可恢复）。")
        case .queued, .running:
            if trimmedOutput.isEmpty {
                sections.append("Claude Code 开发任务进行中。")
            }
        }

        if let buildSummary = task.buildSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !buildSummary.isEmpty {
            sections.append("构建: \(buildSummary)")
        }
        if let testSummary = task.testSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !testSummary.isEmpty {
            sections.append("测试: \(testSummary)")
        }
        if !task.changedFiles.isEmpty {
            sections.append("变更文件: \(task.changedFiles.prefix(5).joined(separator: ", "))")
        }
        if !task.commandsRun.isEmpty {
            sections.append("执行命令: \(task.commandsRun.prefix(3).joined(separator: " | "))")
        }

        if trimmedOutput.isEmpty {
            return sections.joined(separator: "\n")
        }

        if sections.isEmpty {
            return trimmedOutput
        }

        let header = sections.joined(separator: "\n")
        if header == trimmedOutput {
            return header
        }
        return "\(header)\n\n原始输出:\n\(trimmedOutput)"
    }

    static func conciseDeveloperTaskUpdate(_ task: DeveloperAgentTask, previous: DeveloperAgentTask?) -> String? {
        var lines: [String] = []

        if let pending = task.pendingApprovalSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !pending.isEmpty,
           pending != previous?.pendingApprovalSummary?.trimmingCharacters(in: .whitespacesAndNewlines) {
            lines.append("等待确认: \(pending)")
        }

        if let summary = task.resultSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !summary.isEmpty,
           summary != previous?.resultSummary?.trimmingCharacters(in: .whitespacesAndNewlines) {
            lines.append("结果摘要: \(summary)")
        }

        if let build = task.buildSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !build.isEmpty,
           build != previous?.buildSummary?.trimmingCharacters(in: .whitespacesAndNewlines) {
            lines.append("构建进展: \(build)")
        }

        if let test = task.testSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !test.isEmpty,
           test != previous?.testSummary?.trimmingCharacters(in: .whitespacesAndNewlines) {
            lines.append("测试进展: \(test)")
        }

        if task.commandsRun.count > (previous?.commandsRun.count ?? 0),
           let latestCommand = task.commandsRun.last {
            lines.append("执行命令: \(latestCommand)")
        }

        let previousChangedFiles = Set(previous?.changedFiles ?? [])
        let newChangedFiles = task.changedFiles.filter { !previousChangedFiles.contains($0) }
        if !newChangedFiles.isEmpty {
            lines.append("变更文件: \(newChangedFiles.prefix(3).joined(separator: ", "))")
        }

        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n") + "\n"
    }

    static func buildRecentAgentTimeline(
        developerTasks: [DeveloperAgentTask],
        computerUseTrace: ComputerUseTraceSnapshot?
    ) -> [AgentTimelineEvent] {
        var events = developerTasks.flatMap { task in
            task.events.map { event in
                AgentTimelineEvent(
                    id: event.id,
                    timestamp: event.timestamp,
                    source: "developer",
                    kind: event.kind,
                    summary: event.summary
                )
            }
        }

        if let computerUseTrace {
            let baseTime = computerUseTrace.run.startedAt
            events.append(contentsOf: computerUseTrace.events.enumerated().map { index, event in
                AgentTimelineEvent(
                    id: event.id,
                    timestamp: baseTime.addingTimeInterval(Double(index)),
                    source: "computer_use",
                    kind: event.phase,
                    summary: "\(event.toolName): \(event.summary)"
                )
            })

            if let browserPageState = computerUseTrace.browserPageState {
                let browserSummary = compactBrowserTimelineSummary(browserPageState)
                if !browserSummary.isEmpty {
                    events.append(AgentTimelineEvent(
                        timestamp: baseTime.addingTimeInterval(Double(computerUseTrace.events.count) + 0.25),
                        source: "computer_use",
                        kind: "browser_state",
                        summary: browserSummary
                    ))
                }
            }

            if let failedStep = computerUseTrace.run.steps.last(where: { !$0.verified || $0.toolResult.isError }) {
                if let recoverySummary = failedStep.recoverySummary, !recoverySummary.isEmpty {
                    events.append(AgentTimelineEvent(
                        timestamp: baseTime.addingTimeInterval(Double(computerUseTrace.events.count) + 0.5),
                        source: "computer_use",
                        kind: "recovery_reason",
                        summary: recoverySummary
                    ))
                } else if let failureEvidence = failedStep.verificationEvidence.first, !failureEvidence.isEmpty {
                    events.append(AgentTimelineEvent(
                        timestamp: baseTime.addingTimeInterval(Double(computerUseTrace.events.count) + 0.5),
                        source: "computer_use",
                        kind: "verify_reason",
                        summary: failureEvidence
                    ))
                }
            }
        }

        return Array(events.sorted { $0.timestamp > $1.timestamp }.prefix(12))
    }

    static func compactBrowserTimelineSummary(_ state: BrowserPageState) -> String {
        var parts: [String] = [state.browserName]
        if let host = state.host, !host.isEmpty {
            parts.append(host)
        }
        if let searchQuery = state.searchQuery, !searchQuery.isEmpty {
            parts.append("搜索: \(searchQuery)")
        } else if let tabTitle = state.tabTitle, !tabTitle.isEmpty {
            parts.append(tabTitle)
        }
        return parts.joined(separator: " \u{00B7} ")
    }

    func handleDeterministicDesktopTask(_ text: String, conversationID: UUID, appState: AppState?) async -> Bool {
        let lower = text.lowercased()
        let request: ToolCallRequest?

        if lower.contains("识别") || lower.contains("ocr") || lower.contains("文字识别") || lower.contains("屏幕上") {
            request = ToolCallRequest(id: UUID().uuidString, name: "ocr_screen", arguments: [:])
        } else if lower.contains("观察") || lower.contains("看看") || lower.contains("读取界面") {
            request = ToolCallRequest(id: UUID().uuidString, name: "get_app_state", arguments: ["depth": "5"])
        } else if let appName = extractAppName(from: text) {
            request = ToolCallRequest(id: UUID().uuidString, name: "open_app", arguments: ["app_name": appName])
        } else {
            request = nil
        }

        guard let request else { return false }
        sessionManager.appendMessage(Message(role: .user, content: [.text(text)]), to: conversationID)

        // Short-circuit for simple app activation: skip ComputerUse pipeline
        let isSimpleActivate = request.name == "open_app"
            && !lower.contains("输入") && !lower.contains("点击") && !lower.contains("滚动")

        if isSimpleActivate {
            isProcessing = true
            let result = await executeWithAudit(request, appState: appState)
            let msg = result.isError
                ? "无法激活: \(result.output)"
                : "已激活: \(request.arguments["app_name"] ?? "应用")"
            sessionManager.appendMessage(Message(role: .assistant, content: [.text(msg)]), to: conversationID)
            await remember(
                task: text,
                steps: ["route: desktop", "tool: open_app"],
                success: !result.isError,
                failureReason: result.isError ? result.output : nil
            )
            isProcessing = false
            return true
        }

        let action = ComputerUseAction(
            toolCall: request,
            verificationGoal: request.name == "open_app"
                ? Self.desktopVerificationGoal(for: request, originalText: text)
                : nil
        )
        await executeDeterministicComputerUseAction(
            action,
            routeLabel: "desktop",
            taskText: text,
            conversationID: conversationID,
            appState: appState
        )
        return true
    }

    func handleDeterministicToolTask(_ text: String, route: TaskKind, conversationID: UUID, appState: AppState?) async -> Bool {
        let context = await contextCompiler.compileContext()
        let defaultPath = context.rootPath ?? FileManager.default.currentDirectoryPath
        let request: ToolCallRequest?
        switch route {
        case .fileSystem:
            if let path = Self.extractLocalPath(from: text) {
                request = ToolCallRequest(
                    id: UUID().uuidString,
                    name: "open_path",
                    arguments: ["path": path]
                )
            } else if text.contains("列") || text.lowercased().contains("list") {
                request = ToolCallRequest(id: UUID().uuidString, name: "list_directory", arguments: ["path": defaultPath])
            } else if let query = extractFinderSearchQuery(from: text) {
                request = ToolCallRequest(
                    id: UUID().uuidString,
                    name: "finder_search",
                    arguments: ["query": query, "path": defaultPath]
                )
            } else {
                request = nil
            }
        case .browser:
            if let url = extractURL(from: text) {
                request = ToolCallRequest(id: UUID().uuidString, name: "open_url", arguments: ["url": url.absoluteString])
            } else if let query = extractWebSearchQuery(from: text) {
                request = ToolCallRequest(
                    id: UUID().uuidString,
                    name: "safari_search",
                    arguments: ["query": query]
                )
            } else {
                request = nil
            }
        default:
            request = nil
        }

        guard let request else { return false }
        sessionManager.appendMessage(Message(role: .user, content: [.text(text)]), to: conversationID)
        if route == .browser {
            let verificationGoal = Self.browserVerificationGoal(for: request)
            await executeDeterministicComputerUseAction(
                ComputerUseAction(toolCall: request, verificationGoal: verificationGoal),
                routeLabel: route.rawValue,
                taskText: text,
                conversationID: conversationID,
                appState: appState
            )
            return true
        }

        isProcessing = true
        let result = await executeWithAudit(request, appState: appState)
        let finderState = await fetchFinderState()
        let verification = Self.verifyFinderToolResult(request: request, result: result, finderState: finderState)
        sessionManager.appendMessage(Message(role: .assistant, content: [.text(verification.message)]), to: conversationID)
        await remember(
            task: text,
            steps: ["route: \(route.rawValue)", "tool: \(request.name)"] + verification.steps,
            success: verification.success,
            failureReason: verification.success ? nil : verification.failureReason,
            learnedWorkflow: verification.success
                ? (["route: \(route.rawValue)", "tool: \(request.name)"] + verification.steps).joined(separator: " -> ")
                : nil
        )
        isProcessing = false
        return true
    }

    func handleDeterministicCodeTask(_ text: String, conversationID: UUID, appState: AppState?) async -> Bool {
        let context = await contextCompiler.compileContext()
        guard let command = extractTerminalCommand(from: text) else { return false }
        let cwd = context.rootPath

        var arguments = ["command": command]
        if let cwd {
            arguments["cwd"] = cwd
        }

        let request = ToolCallRequest(
            id: UUID().uuidString,
            name: "terminal_run",
            arguments: arguments
        )

        sessionManager.appendMessage(Message(role: .user, content: [.text(text)]), to: conversationID)
        isProcessing = true
        setPhase(.acting, reason: "终端命令: \(command.prefix(20))")
        await publishLifecycleEvent(.actingStarted(action: "terminal_run", tool: "terminal_run"))
        let result = await executeWithAudit(request, appState: appState)
        let verification = Self.verifyTerminalRun(command: command, cwd: cwd, result: result)
        setPhase(.verifying, reason: "检查终端输出")
        await publishLifecycleEvent(.verifyingStarted(action: "terminal_run"))
        await publishLifecycleEvent(.verifyingCompleted(action: "terminal_run", passed: verification.success))
        sessionManager.appendMessage(
            Message(role: .assistant, content: [.text(verification.message)]),
            to: conversationID
        )
        await remember(
            task: text,
            steps: ["route: code", "tool: terminal_run"] + verification.steps,
            success: verification.success,
            failureReason: verification.success ? nil : verification.failureReason,
            learnedWorkflow: verification.success
                ? (["route: code", "tool: terminal_run"] + verification.steps).joined(separator: " -> ")
                : nil
        )
        isProcessing = false
        setPhase(.idle, reason: "命令完成")
        return true
    }

    private func executeDeterministicComputerUseAction(
        _ action: ComputerUseAction,
        routeLabel: String,
        taskText: String,
        conversationID: UUID,
        appState: AppState?
    ) async {
        isProcessing = true
        setPhase(.acting, reason: "执行: \(action.toolCall.name)")
        await publishLifecycleEvent(.actingStarted(action: taskText.prefix(30).description, tool: action.toolCall.name))
        lastBriefTraceEvent = nil
        let responseID = sessionManager.beginStreamingResponse(in: conversationID)
        let inferredAppName = action.verificationGoal?.expectedApp
        let recoveryProfile = await workflowMemoryStore.bestRecoveryStrategyProfile(
            appName: inferredAppName,
            toolName: action.toolCall.name
        )
        currentRecoveryProfile = RecoveryProfileSnapshot(
            scope: recoveryProfile.scope,
            appName: inferredAppName,
            toolName: action.toolCall.name,
            strategies: recoveryProfile.successRates
                .map { RecoveryStrategyMetric(strategy: $0.key, successRate: $0.value) }
                .sorted { lhs, rhs in
                    if lhs.successRate == rhs.successRate {
                        return lhs.strategy < rhs.strategy
                    }
                    return lhs.successRate > rhs.successRate
                }
        )
        let initialBrowserPageState = await fetchBrowserPageState(for: action)
        lastComputerUseTrace = ComputerUseTraceSnapshot(
            phase: "running",
            taskText: taskText,
            routeLabel: routeLabel,
            browserPageState: initialBrowserPageState,
            run: ComputerUseRunResult(startedAt: Date(), steps: []),
            events: []
        )
        let run = await computerUseRuntime.run(
            actions: [action],
            policy: appState?.toolExecutionPolicy ?? .default,
            recoveryScoreByStrategy: recoveryProfile.successRates,
            onStepUpdate: { [weak self] partialRun in
                guard let self else { return }
                await MainActor.run {
                    let existingEvents = self.lastComputerUseTrace?.events ?? []
                    self.lastComputerUseTrace = ComputerUseTraceSnapshot(
                        phase: "running",
                        taskText: taskText,
                        routeLabel: routeLabel,
                        browserPageState: self.lastComputerUseTrace?.browserPageState,
                        run: partialRun,
                        events: existingEvents
                    )
                }
            },
            onTraceEvent: { [weak self] event in
                guard let self else { return }
                await MainActor.run {
                    let existingRun = self.lastComputerUseTrace?.run ?? ComputerUseRunResult(startedAt: Date(), steps: [])
                    var events = self.lastComputerUseTrace?.events ?? []
                    events.append(event)
                    self.lastComputerUseTrace = ComputerUseTraceSnapshot(
                        phase: event.phase,
                        taskText: taskText,
                        routeLabel: routeLabel,
                        browserPageState: self.lastComputerUseTrace?.browserPageState,
                        run: existingRun,
                        events: Array(events.suffix(12))
                    )
                    let line = Self.conciseTraceEventLine(event, previousEvent: self.lastBriefTraceEvent)
                    self.lastBriefTraceEvent = event
                    if let line {
                        self.sessionManager.appendStreamToken(line, messageID: responseID, in: conversationID)
                    }
                }
            },
            onStepVoiceFeedback: { [weak self] text in
                guard let self, let appState else { return }
                await self.voiceSessionManager.speakIfNeeded(text, appState: appState)
            }
        )
        let finalBrowserPageState = await fetchBrowserPageState(for: action) ?? lastComputerUseTrace?.browserPageState
        lastComputerUseTrace = ComputerUseTraceSnapshot(
            phase: "completed",
            taskText: taskText,
            routeLabel: routeLabel,
            browserPageState: finalBrowserPageState,
            run: run,
            events: lastComputerUseTrace?.events ?? []
        )
        recentAgentTimeline = Self.buildRecentAgentTimeline(
            developerTasks: developerTasks,
            computerUseTrace: lastComputerUseTrace
        )
        let output = formatComputerUseRun(run)
        let briefOutput = Self.briefComputerUseResult(run)
        let finalMessage = Message(id: responseID, role: .assistant, content: [.text(briefOutput)], timestamp: Date())
        sessionManager.updateMessage(finalMessage, in: conversationID)
        sessionManager.finishStreamingResponse(messageID: responseID, in: conversationID)
        let appName = run.inferredAppName(fallback: inferredAppName)
        let contextSteps = [
            "route: \(routeLabel)",
            appName.map { "app: \($0)" },
        ].compactMap { $0 }
        await remember(
            task: taskText,
            steps: contextSteps + run.memorySteps,
            success: run.succeeded,
            failureReason: run.succeeded ? nil : output,
            learnedWorkflow: run.succeeded
                ? (contextSteps + [run.learnedWorkflowSummary ?? action.toolCall.name]).joined(separator: " -> ")
                : nil
        )
        isProcessing = false
        lastBriefTraceEvent = nil
        await publishLifecycleEvent(.actingCompleted(action: action.toolCall.name, success: run.succeeded))
        setPhase(.idle, reason: "操作完成")
    }

    public func runTemplate(_ template: WorkflowTemplate, appState: AppState?) async -> ComputerUseRunResult {
        let actions = template.toComputerUseActions()
        setPhase(.acting, reason: "执行模板: \(template.name)")
        let run = await computerUseRuntime.run(
            actions: actions,
            policy: appState?.toolExecutionPolicy ?? .default,
            recoveryScoreByStrategy: currentRecoveryProfile.strategies.reduce(into: [:]) {
                $0[$1.strategy] = $1.successRate
            },
            onStepVoiceFeedback: { [weak self] text in
                guard let self, let appState else { return }
                await self.voiceSessionManager.speakIfNeeded(text, appState: appState)
            }
        )
        await templateStore.recordUse(id: template.id)
        setPhase(.responding, reason: "模板执行完成")
        return run
    }

    static func conciseTraceEventLine(
        _ event: ComputerUseTraceEvent,
        previousEvent: ComputerUseTraceEvent?
    ) -> String? {
        if let previousEvent,
           previousEvent.phase == event.phase,
           previousEvent.stepIndex == event.stepIndex,
           previousEvent.toolName == event.toolName {
            return nil
        }

        let summary: String
        switch event.phase {
        case "observing":
            summary = "第\(event.stepIndex + 1)步先观察界面"
        case "acting":
            summary = "第\(event.stepIndex + 1)步执行 \(event.toolName)"
        case "recovering":
            summary = "第\(event.stepIndex + 1)步尝试恢复"
        case "verifying":
            summary = "第\(event.stepIndex + 1)步检查结果"
        default:
            return nil
        }
        return "\(summary)\n"
    }

    static func briefComputerUseResult(_ run: ComputerUseRunResult) -> String {
        let verifiedCount = run.steps.filter(\.verified).count
        let recoveryCount = run.steps.filter(\.recoveryAttempted).count

        if run.succeeded {
            if let firstRecovery = run.steps.compactMap(\.recoverySummary).first {
                return "已完成，共 \(verifiedCount) 步；恢复 \(recoveryCount) 次。\(firstRecovery)"
            }
            return "已完成，共 \(verifiedCount) 步。"
        }

        if let failedStep = run.steps.last {
            let label = failedStep.action.toolCall.name
            if let recoverySummary = failedStep.recoverySummary, !recoverySummary.isEmpty {
                return "未完成，停在 \(label)。\(recoverySummary)"
            }
            let failureText = failedStep.toolResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !failureText.isEmpty {
                return "未完成，停在 \(label)。\(String(failureText.prefix(120)))"
            }
            return "未完成，停在 \(label)。"
        }

        return "未完成。"
    }

    struct TerminalVerification: Sendable, Hashable {
        let success: Bool
        let summary: String
        let message: String
        let steps: [String]
        let failureReason: String?
    }

    struct FinderVerification: Sendable, Hashable {
        let success: Bool
        let summary: String
        let message: String
        let steps: [String]
        let failureReason: String?
    }

    static func verifyTerminalRun(command: String, cwd: String?, result: ToolCallResult) -> TerminalVerification {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowerCommand = trimmedCommand.lowercased()
        let lowerOutput = output.lowercased()

        if result.isError {
            let summary = "命令执行失败"
            let body = output.isEmpty ? summary : "\(summary)：\(String(output.prefix(160)))"
            return TerminalVerification(
                success: false,
                summary: summary,
                message: body,
                steps: ["verify: terminal command failed"],
                failureReason: output.isEmpty ? summary : output
            )
        }

        if lowerCommand == "pwd" || lowerCommand.hasPrefix("pwd ") {
            let verified = cwd.map { output.contains($0) } ?? !output.isEmpty
            let summary = verified ? "已确认当前目录" : "未能确认当前目录"
            return TerminalVerification(
                success: verified,
                summary: summary,
                message: "\(summary)：\(String(output.prefix(160)))",
                steps: [verified ? "verify: pwd matches cwd" : "verify: pwd missing cwd"],
                failureReason: verified ? nil : output
            )
        }

        if lowerCommand.hasPrefix("git status") {
            let verified = lowerOutput.contains("on branch")
                || lowerOutput.contains("changes not staged")
                || lowerOutput.contains("changes to be committed")
                || lowerOutput.contains("nothing to commit")
                || lowerOutput.contains("untracked files")
            let summary = verified ? "已确认 git 状态输出" : "git 状态输出不完整"
            return TerminalVerification(
                success: verified,
                summary: summary,
                message: output.isEmpty ? summary : "\(summary)\n\n\(String(output.prefix(300)))",
                steps: [verified ? "verify: git status output" : "verify: git status output missing"],
                failureReason: verified ? nil : output
            )
        }

        if lowerCommand.hasPrefix("swift test") {
            let verified = lowerOutput.contains("test run")
                || lowerOutput.contains("passed after")
                || lowerOutput.contains("executed")
            let summary = verified ? "已确认测试执行输出" : "测试命令缺少预期输出"
            return TerminalVerification(
                success: verified,
                summary: summary,
                message: output.isEmpty ? summary : "\(summary)\n\n\(String(output.prefix(300)))",
                steps: [verified ? "verify: swift test output" : "verify: swift test output missing"],
                failureReason: verified ? nil : output
            )
        }

        if lowerCommand.hasPrefix("swift build") || lowerCommand.hasPrefix("xcodebuild") {
            let verified = lowerOutput.contains("build complete")
                || lowerOutput.contains("build succeeded")
                || !output.isEmpty
            let summary = verified ? "已确认构建输出" : "构建命令缺少预期输出"
            return TerminalVerification(
                success: verified,
                summary: summary,
                message: output.isEmpty ? summary : "\(summary)\n\n\(String(output.prefix(300)))",
                steps: [verified ? "verify: build output" : "verify: build output missing"],
                failureReason: verified ? nil : output
            )
        }

        let summary = "命令已完成"
        return TerminalVerification(
            success: true,
            summary: summary,
            message: output.isEmpty ? summary : "\(summary)\n\n\(String(output.prefix(300)))",
            steps: ["verify: command completed"],
            failureReason: nil
        )
    }

    static func verifyFinderToolResult(
        request: ToolCallRequest,
        result: ToolCallResult,
        finderState: FinderWindowState? = nil
    ) -> FinderVerification {
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isError {
            let summary = request.name == "finder_search" ? "Finder 搜索失败" : "目录读取失败"
            let message = output.isEmpty ? summary : "\(summary)：\(String(output.prefix(160)))"
            return FinderVerification(
                success: false,
                summary: summary,
                message: message,
                steps: [request.name == "finder_search" ? "verify: finder search failed" : "verify: directory listing failed"],
                failureReason: output.isEmpty ? summary : output
            )
        }

        switch request.name {
        case "open_path":
            let requestedPath = request.arguments["path"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let normalizedRequestedPath = normalizePathForComparison(requestedPath) ?? requestedPath
            let stateCurrentPath = normalizePathForComparison(finderState?.currentPath)
            let selectedItems = finderState?.selectedItems.compactMap(normalizePathForComparison) ?? []
            let containsSelection = !normalizedRequestedPath.isEmpty && selectedItems.contains(normalizedRequestedPath)
            let currentPathMatchesTarget = !normalizedRequestedPath.isEmpty && stateCurrentPath == normalizedRequestedPath
            let openedParentDirectory = !normalizedRequestedPath.isEmpty
                && stateCurrentPath == normalizePathForComparison(URL(fileURLWithPath: normalizedRequestedPath).deletingLastPathComponent().path)

            var isDirectory: ObjCBool = false
            let fileExists = !normalizedRequestedPath.isEmpty
                && FileManager.default.fileExists(atPath: normalizedRequestedPath, isDirectory: &isDirectory)
            let verified = if isDirectory.boolValue {
                currentPathMatchesTarget
            } else if fileExists {
                containsSelection || openedParentDirectory
            } else {
                currentPathMatchesTarget || containsSelection || openedParentDirectory
            }

            let summary = verified ? "已确认 Finder 打开目标路径" : "Finder 未确认打开目标路径"
            var body = output.isEmpty ? requestedPath : output
            if let stateSummary = compactFinderStateSummary(finderState), !stateSummary.isEmpty {
                body = body.isEmpty ? stateSummary : "\(body)\n\n\(stateSummary)"
            }
            return FinderVerification(
                success: verified,
                summary: summary,
                message: body.isEmpty ? summary : "\(summary)\n\n\(body)",
                steps: [verified ? "verify: finder opened requested path" : "verify: finder did not open requested path"]
                    + finderStateVerificationSteps(finderState, expectedPath: requestedPath),
                failureReason: verified ? nil : (output.isEmpty ? summary : output)
            )
        case "finder_search":
            let query = request.arguments["query"]?.lowercased() ?? ""
            let lines = output.split(separator: "\n").map(String.init)
            let matches = lines.filter { $0.lowercased().contains(query) }
            let verified = !query.isEmpty && !matches.isEmpty
            let summary = verified ? "已确认 Finder 搜索结果" : "Finder 搜索未命中目标"
            var body = matches.isEmpty ? output : matches.prefix(5).joined(separator: "\n")
            if let stateSummary = compactFinderStateSummary(finderState), !stateSummary.isEmpty {
                body = body.isEmpty ? stateSummary : "\(body)\n\n\(stateSummary)"
            }
            return FinderVerification(
                success: verified,
                summary: summary,
                message: body.isEmpty ? summary : "\(summary)\n\n\(body)",
                steps: [verified ? "verify: finder search results match query" : "verify: finder search results missing query"]
                    + finderStateVerificationSteps(finderState, expectedPath: request.arguments["path"]),
                failureReason: verified ? nil : (output.isEmpty ? summary : output)
            )
        case "list_directory":
            let lines = output.split(separator: "\n").map(String.init)
            let verified = !lines.isEmpty && !output.contains("目录为空")
            let summary = verified ? "已确认目录内容" : "目录为空或未返回条目"
            var body = lines.prefix(8).joined(separator: "\n")
            if let stateSummary = compactFinderStateSummary(finderState), !stateSummary.isEmpty {
                body = body.isEmpty ? stateSummary : "\(body)\n\n\(stateSummary)"
            }
            return FinderVerification(
                success: verified,
                summary: summary,
                message: body.isEmpty ? summary : "\(summary)\n\n\(body)",
                steps: [verified ? "verify: directory contains entries" : "verify: directory returned no entries"]
                    + finderStateVerificationSteps(finderState, expectedPath: request.arguments["path"]),
                failureReason: verified ? nil : (output.isEmpty ? summary : output)
            )
        default:
            return FinderVerification(
                success: !result.isError,
                summary: "Finder 操作完成",
                message: output.isEmpty ? "Finder 操作完成" : output,
                steps: ["verify: finder tool completed"],
                failureReason: result.isError ? output : nil
            )
        }
    }

    static func compactFinderStateSummary(_ state: FinderWindowState?) -> String? {
        guard let state else { return nil }
        var lines: [String] = []
        if let currentPath = state.currentPath, !currentPath.isEmpty {
            lines.append("Finder 当前目录: \(currentPath)")
        }
        if !state.selectedItems.isEmpty {
            lines.append("Finder 已选中: \(state.selectedItems.prefix(3).joined(separator: " | "))")
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    static func finderStateVerificationSteps(_ state: FinderWindowState?, expectedPath: String?) -> [String] {
        guard let state else { return [] }
        var steps: [String] = []
        if let expectedPath {
            let normalizedExpectedPath = normalizePathForComparison(expectedPath)
            if let currentPath = state.currentPath,
               normalizePathForComparison(currentPath) == normalizedExpectedPath {
                steps.append("verify: finder current path matches request")
            }
            if state.selectedItems.map(normalizePathForComparison).contains(normalizedExpectedPath) {
                steps.append("verify: finder selection contains requested path")
            }
        }
        if !state.selectedItems.isEmpty {
            steps.append("verify: finder selection observed")
        }
        return steps
    }

    static func extractLocalPath(from text: String) -> String? {
        let pattern = #"(?:(?<=^)|(?<=[\s"'“”‘’]))(~\/[^\s"'“”‘’，。；,;]+|\/[^\s"'“”‘’，。；,;]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        let rawPath = String(text[captureRange])
        let expandedPath = (rawPath as NSString).expandingTildeInPath
        guard !expandedPath.isEmpty else { return nil }
        return expandedPath
    }

    static func normalizePathForComparison(_ path: String?) -> String? {
        guard let path, !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }

    static func browserVerificationGoal(for request: ToolCallRequest) -> VerificationGoal? {
        switch request.name {
        case "open_url":
            guard let rawURL = request.arguments["url"], let url = URL(string: rawURL) else {
                return VerificationGoal(expectedApp: "Safari")
            }
            let host = url.host?.replacingOccurrences(of: "www.", with: "")
            return VerificationGoal(
                expectedText: host,
                expectedApp: "Safari",
                expectedWindowTitle: host,
            )
        case "safari_search":
            guard let query = request.arguments["query"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !query.isEmpty else {
                return VerificationGoal(expectedApp: "Safari")
            }
            let normalizedQuery = query
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .prefix(3)
                .joined(separator: " ")
            return VerificationGoal(
                expectedText: normalizedQuery.isEmpty ? query : normalizedQuery,
                expectedApp: "Safari"
            )
        default:
            return nil
        }
    }

    static func desktopVerificationGoal(for request: ToolCallRequest, originalText: String) -> VerificationGoal? {
        guard request.name == "open_app" else { return nil }
        let appName = request.arguments["app_name"]
        let lowered = originalText.lowercased()
        let expectedWindowTitle: String?

        if lowered.contains("设置窗口") || lowered.contains("settings") {
            expectedWindowTitle = "Settings"
        } else if lowered.contains("系统设置") {
            expectedWindowTitle = "Settings"
        } else if lowered.contains("访达") || lowered.contains("finder") {
            expectedWindowTitle = "Finder"
        } else if lowered.contains("终端") || lowered.contains("terminal") {
            expectedWindowTitle = "Terminal"
        } else {
            expectedWindowTitle = nil
        }

        return VerificationGoal(
            expectedText: appName,
            expectedApp: appName,
            expectedWindowTitle: expectedWindowTitle
        )
    }

    private func sendMessageViaClaudeCode(_ text: String, conversationID: UUID, appState: AppState? = nil) async {
        isProcessing = true

        let context = await contextCompiler.compileContext()
        let desktopContext = await desktopContextCollector.collect(projectContext: context)
        currentDesktopContext = desktopContext
        let cwd = context.rootPath

        let userMessage = Message(role: .user, content: [.text(text)])
        sessionManager.appendMessage(userMessage, to: conversationID)

        let responseID = sessionManager.beginStreamingResponse(in: conversationID)
        currentResponseID = responseID

        let messages = sessionManager.activeConversation?.messages ?? []
        let recentHistory = messages.dropLast().suffix(4)
            .filter { $0.role == .user || $0.role == .assistant }
            .map { "\($0.role == .user ? "User" : "Assistant"): \($0.textContent)" }
            .joined(separator: "\n")

        let prompt: String
        if recentHistory.isEmpty {
            prompt = "\(desktopContext.promptSummary())\n\nNew instruction from user: \(text)"
        } else {
            prompt = "\(desktopContext.promptSummary())\n\nRecent conversation:\n\(recentHistory)\n\nNew instruction from user: \(text)"
        }

        let stream = await claudeCodeBridge.run(prompt: prompt, cwd: cwd)
        var fullResponse = ""

        for await chunk in stream {
            fullResponse += chunk
            sessionManager.appendStreamToken(chunk, messageID: responseID, in: conversationID)
        }

        let trimmed = fullResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        let contentText = trimmed.isEmpty ? "Claude Code 已完成" : trimmed
        let finalMessage = Message(
            id: responseID,
            role: .assistant,
            content: [.text(contentText)],
            timestamp: Date()
        )
        sessionManager.updateMessage(finalMessage, in: conversationID)
        await voiceSessionManager.speakIfNeeded(contentText, appState: appState)

        sessionManager.finishStreamingResponse(messageID: responseID, in: conversationID)
        isProcessing = false
        currentResponseID = nil
    }

    private func screenContextPrompt(for userText: String) async -> String? {
        let wantsScreen = userText.contains("屏幕") ||
            userText.contains("窗口") ||
            userText.contains("界面") ||
            userText.contains("看到") ||
            userText.contains("看见") ||
            userText.contains("当前") ||
            userText.contains("现在") ||
            userText.contains("这个") ||
            userText.contains("读") ||
            userText.contains("前台") ||
            userText.contains("在运行")

        // Check staleness — auto-refresh if needed
        let age = Date().timeIntervalSince(lastScreenContextCapturedAt)
        let isStale = age > screenContextTTL

        guard let screen = lastScreenContext else {
            // No context at all — auto-capture if user asks about screen
            if wantsScreen {
                await taskBag["screen"]?.cancel()
                await taskBag.set(key: "screen", task: Task { [weak self] in
                    _ = await self?.readScreenContent(appState: nil)
                })
                return nil // context not ready yet, skip this turn
            }
            return nil
        }

        if isStale, wantsScreen {
            await taskBag["screen"]?.cancel()
            await taskBag.set(key: "screen", task: Task { [weak self] in
                _ = await self?.readScreenContent(appState: nil)
            })
            return nil // stale context, refreshing — skip this turn
        }

        let ocrText = screen.recognizedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard wantsScreen || !ocrText.isEmpty else { return nil }

        var lines = ["## 当前屏幕上下文"]
        let freshnessLabel = isStale ? "⚠️ 缓存（\(Int(age)) 秒前采集）" : "✅ 实时（\(Int(age * 1000))ms 前采集）"
        lines.append("- 状态：\(screen.displayDescription) — \(freshnessLabel)")
        if !screen.visibleWindows.isEmpty {
            let windows = screen.visibleWindows.prefix(10).map { window in
                let title = window.windowTitle.flatMap { $0.isEmpty ? nil : " - \($0)" } ?? ""
                return "\(window.ownerName)\(title)"
            }.joined(separator: "\n")
            lines.append("- 可见窗口：\n\(windows)")
        }
        if !ocrText.isEmpty {
            lines.append("- OCR 文字：\n\(String(ocrText.prefix(2200)))")
        }
        lines.append("（基于当前屏幕数据回答，数据采集时间戳：\(screen.capturedAt)）")
        return lines.joined(separator: "\n")
    }

    /// Build a system prompt hint from a ComputerUsePlan — provides reference steps for known command patterns.
    private func buildPlanHint(_ plan: ComputerUsePlan) -> String {
        var hint = "[桌面操作参考计划]"
        hint += "\n- 检测意图: \(plan.intent.rawValue)"
        hint += "\n- 原因: \(plan.reason)"
        if !plan.steps.isEmpty {
            hint += "\n- 参考步骤:"
            for (i, step) in plan.steps.enumerated() {
                hint += "\n  \(i + 1). \(step.action.humanPreview)（预期: \(step.expectedState)）"
            }
        } else if let action = plan.action {
            hint += "\n- 建议操作: \(action.humanPreview)"
        }
        if plan.requiresConfirmation {
            hint += "\n- 本操作需用户确认"
        }
        hint += "\n注意: 以上为预检测的参考计划，请根据实际界面状态调整。"
        return hint
    }
}
