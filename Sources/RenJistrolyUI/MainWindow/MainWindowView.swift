import SwiftUI
import RenJistrolyModels
import RenJistrolyConversation
import RenJistrolyIntelligence

public struct MainWindowView: View {
    @Environment(ConversationEngine.self) private var engine
    @Environment(AppState.self) private var appState

    @State private var inputText: String = ""
    @State private var sidebarVisible: Bool = true
    @State private var searchQuery: String = ""
    @State private var inputFocusTrigger: Int = 0
    @State private var isAgentConsoleVisible: Bool = true
    @State private var isClaudeLauncherVisible: Bool = false
    @State private var claudeTaskPrompt: String = ""
    @FocusState private var isInputFocused: Bool

    public init() {}

    public var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 260, max: 350)
        } detail: {
            chatArea
        }
        .frame(minWidth: 800, minHeight: 500)
        .overlay {
            if appState.pendingConfirmation != nil {
                confirmationOverlay
            }
        }
        .onAppear {
            isInputFocused = true
        }
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    engine.resolveConfirmation(approved: false, appState: appState)
                }

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)

                Text("确认执行操作")
                    .font(.system(size: 15, weight: .semibold))

                if let c = appState.pendingConfirmation {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "wrench").font(.system(size: 11)).foregroundColor(.secondary)
                            Text("工具").font(.system(size: 11)).foregroundColor(.secondary)
                            Text(c.toolName).font(.system(size: 13, weight: .medium))
                        }

                        HStack(spacing: 4) {
                            Image(systemName: riskIcon(c.riskLevel)).font(.system(size: 11)).foregroundColor(.secondary)
                            Text("风险等级").font(.system(size: 11)).foregroundColor(.secondary)
                            Text(c.riskLevel.rawValue).font(.system(size: 13, weight: .medium)).foregroundColor(riskColor(c.riskLevel))
                        }

                        Text(c.summary)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.06))
                    .cornerRadius(8)
                }

                HStack(spacing: 16) {
                    Button {
                        engine.resolveConfirmation(approved: false, appState: appState)
                    } label: {
                        Text("取消")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)

                    Button {
                        engine.resolveConfirmation(approved: true, appState: appState)
                    } label: {
                        Text("批准执行")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
            }
            .padding(24)
            .frame(width: 340)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.2), radius: 20)
            )
        }
    }

    private func riskIcon(_ level: ToolRiskLevel) -> String {
        switch level {
        case .low: return "checkmark.shield"
        case .medium: return "shield"
        case .high: return "exclamationmark.shield"
        }
    }

    private func riskColor(_ level: ToolRiskLevel) -> Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        let conversations = filteredConversations
        return VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索对话...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(8)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(12)

            // Conversations
            List {
                Section {
                    ForEach(conversations) { conversation in
                        ConversationRow(
                            conversation: conversation,
                            isActive: conversation.id == engine.sessionManager.activeConversationID
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            engine.sessionManager.setActiveConversation(conversation.id)
                        }
                    }
                } header: {
                    Text("最近对话")
                        .font(.system(size: 11))
                }
            }
            .listStyle(.sidebar)

            // New Chat Button
            Button {
                _ = engine.sessionManager.createConversation()
                inputText = ""
                searchQuery = ""
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("新建对话")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .padding(12)
        }
        .background(Color.primary.opacity(0.02))
    }

    private var filteredConversations: [Conversation] {
        let conversations = engine.sessionManager.searchConversations(searchQuery)
        return conversations.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Chat Area

    private var chatArea: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        if appState.activePlan != nil {
                            PlanCard()
                        }

                        if isAgentConsoleVisible {
                            AgentConsoleView(
                                route: engine.latestRoute,
                                boardItems: engine.agentBoardItems,
                                developerTasks: engine.developerTasks,
                                auditRecords: engine.safetyAuditRecords,
                                memories: engine.workflowMemories,
                                skills: engine.skills,
                                recoveryProfile: engine.currentRecoveryProfile,
                                computerUseTrace: engine.lastComputerUseTrace,
                                recentAgentTimeline: engine.recentAgentTimeline,
                                onRetryDeveloperTask: { id in
                                    Task { await engine.retryDeveloperTask(id) }
                                },
                                onApproveDeveloperTask: { id in
                                    Task { await engine.approveDeveloperTask(id) }
                                },
                                onStopDeveloperTask: { id in
                                    Task { await engine.stopDeveloperTask(id) }
                                },
                                onRetryComputerUseStep: { stepID in
                                    Task { await engine.retryComputerUseStep(stepID: stepID, appState: appState) }
                                },
                                onApproveComputerUseStep: { stepID in
                                    engine.approveComputerUseStep(stepID: stepID)
                                }
                            )
                            .background(Color.primary.opacity(0.035))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        if isClaudeLauncherVisible {
                            claudeLauncherCard
                        }

                        let displayMessages = engine.sessionManager.activeConversation?.messages.filter({ $0.role != MessageRole.system }) ?? []
                        ForEach(displayMessages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: engine.sessionManager.activeConversation?.messages.count) { _, _ in
                    if let lastID = engine.sessionManager.activeConversation?.messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: engine.sessionManager.activeConversation?.messages.last?.textContent) { _, _ in
                    if let lastID = engine.sessionManager.activeConversation?.messages.last?.id {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input
            mainInputArea
        }
    }

    private var chatHeader: some View {
        HStack(spacing: 10) {
            Button {
                sidebarVisible.toggle()
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)

            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)

            if let title = engine.sessionManager.activeConversation?.title {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }

            Spacer()

            if isVoiceActive {
                VoiceWaveformView(isActive: true, voiceState: appState.voiceState)
                    .frame(width: 48)
            }

            providerBadge

            contextBadge

            Button {
                isAgentConsoleVisible.toggle()
            } label: {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help("显示/隐藏 Agent 控制台")

            Button {
                isClaudeLauncherVisible.toggle()
            } label: {
                Image(systemName: "terminal.badge.plus")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help("显示/隐藏 Claude Code 启动器")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        if isVoiceActive {
            switch appState.voiceState {
            case .listening, .lockedListening: return .blue
            case .transcribing: return .orange
            case .speaking: return .green
            case .failed: return .red
            default: break
            }
        }
        if engine.isProcessing { return .blue }
        if let plan = appState.activePlan {
            switch plan.status {
            case .completed: return .green
            case .failed: return .red
            default: return .blue
            }
        }
        if let build = appState.devMode.lastBuildResult {
            return build.success ? .green : .red
        }
        return .green
    }

    private var providerBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: appState.activeProvider.isLocal ? "cpu" : "cloud")
                .font(.system(size: 10))
            Text(appState.activeProvider.displayName)
                .font(.system(size: 10))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.secondary.opacity(0.1)))
    }

    @ViewBuilder
    private var contextBadge: some View {
        if let context = engine.contextCompiler.currentContext {
            HStack(spacing: 4) {
                if let type = context.projectType {
                    Text(type.rawValue)
                        .font(.system(size: 10))
                }
                if let branch = context.gitBranch {
                    Text(branch)
                        .font(.system(size: 10))
                }
            }
            .foregroundColor(.secondary)
        }
    }

    private var mainInputArea: some View {
        VStack(spacing: 8) {
            if appState.voiceState == .failed, let error = engine.voiceError {
                voiceErrorBar(error)
            }

            if isVoiceActive, !engine.voiceText.isEmpty {
                voiceTranscriptionBar
            }

            HStack(alignment: .bottom, spacing: 12) {
                voiceButton

                SubmitTextInput(
                    text: $inputText,
                    placeholder: "输入消息... (Enter 发送)",
                    minHeight: 24,
                    maxHeight: 132,
                    focusTrigger: inputFocusTrigger,
                    onSubmit: sendMessage
                )

                sendButton
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            HStack {
                Text("Mac 智能化助手 · 系统控制 · 代码辅助")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                scenarioQuickActions
                if appState.devMode.isEnabled {
                    devQuickActions
                }
                Spacer()
                if appState.voiceState == .idle || appState.voiceState == .failed {
                    Text("按住🎤说话 · 点按🎤+实时对话")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                if engine.isProcessing {
                    ProgressView()
                        .scaleEffect(0.6)
                }
                Text(engine.sessionLifecycle.phase.label)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(Color.primary.opacity(0.03))
    }

    private var isVoiceActive: Bool {
        appState.voiceState == .failed || appState.voiceState.isCapturingAudio || appState.voiceState == .speaking
    }

    private var voiceTranscriptionBar: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundColor(.blue)
                .font(.system(size: 12))
            Text(engine.voiceText)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.05))
    }

    private var claudeLauncherCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Claude Code", systemImage: "terminal")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Circle()
                    .fill(engine.claudeCodeStatus.isInstalled ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(engine.claudeCodeStatus.isInstalled ? "已连接" : "未检测到")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("路径")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(engine.claudeCodeStatus.executablePath)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                Spacer()
            }

            HStack {
                Text("项目")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(appState.devMode.projectPath ?? engine.contextCompiler.currentContext?.rootPath ?? "未检测到项目")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
            }

            TextField("直接给 Claude Code 一个开发任务", text: $claudeTaskPrompt, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...5)

            HStack {
                Button("刷新状态") {
                    Task { await engine.refreshClaudeCodeStatus() }
                }
                .buttonStyle(.plain)

                Spacer()

                Button("启动任务") {
                    let prompt = claudeTaskPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !prompt.isEmpty else { return }
                    claudeTaskPrompt = ""
                    Task { await engine.launchClaudeCodeTask(prompt, appState: appState) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(claudeTaskPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !engine.claudeCodeStatus.isInstalled)
            }
        }
        .padding(16)
        .background(Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func voiceErrorBar(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 12))
            Text(error)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 5)
        .background(Color.orange.opacity(0.08))
    }

    private var voiceButton: some View {
        let controller = AssistantSessionController.shared
        return VoiceButton(
            onStart: {
                inputFocusTrigger += 1
                Task {
                    guard await controller.requestMicrophonePermission() else { return }
                    controller.startListening()
                }
            },
            onFinish: {
                controller.stopListening()
            },
            onToggle: {
                controller.toggleConversationMode()
            }
        )
    }

    private var sendButton: some View {
        Button {
            sendMessage()
        } label: {
            Image(systemName: engine.isProcessing ? "stop.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 26))
                .foregroundColor(canSubmit ? .blue : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
    }

    private var canSubmit: Bool {
        if engine.isProcessing { return true }
        if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return false
    }

    private var scenarioQuickActions: some View {
        HStack(spacing: 8) {
            Button {
                Task { await runScenario(.polish) }
            } label: {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("润色选中文字")

            Button {
                Task { await runScenario(.explain) }
            } label: {
                Image(systemName: "text.bubble")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("解释选中内容")

            Button {
                Task { await runScenario(.readScreen) }
            } label: {
                Image(systemName: "eye")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("读取屏幕内容")
        }
        .foregroundColor(.secondary)
    }

    private enum ScenarioAction { case polish, explain, readScreen }

    private func runScenario(_ action: ScenarioAction) async {
        let result: String
        switch action {
        case .polish:
            result = await engine.polishSelectedText(appState: appState)
        case .explain:
            result = await engine.explainSelectedText(appState: appState)
        case .readScreen:
            result = await engine.readScreenContent(appState: appState)
        }
        if !result.isEmpty, let conversationID = engine.sessionManager.activeConversationID {
            let msg = Message(role: .assistant, content: [.text(result)])
            engine.sessionManager.appendMessage(msg, to: conversationID)
        }
    }

    private var devQuickActions: some View {
        HStack(spacing: 8) {
            Button {
                Task { await engine.buildProject(appState: appState) }
            } label: {
                Image(systemName: "hammer")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("构建项目")

            Button {
                Task { await engine.runTests(appState: appState) }
            } label: {
                Image(systemName: "checklist")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("运行测试")
        }
        .foregroundColor(.secondary)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return
        }
        inputText = ""
        Task { await engine.sendMessage(text, appState: appState) }
    }

    private func toggleVoice() {
        switch appState.voiceState {
        case .idle, .failed:
            inputFocusTrigger += 1
            Task {
                try? await Task.sleep(for: .milliseconds(120))
                await engine.startVoiceInput(appState: appState)
            }
        case .listening, .lockedListening, .transcribing, .paused:
            Task { await engine.finishVoiceInputAndSend(appState: appState) }
        case .requestingPermission:
            break
        case .processing, .speaking:
            engine.stopVoiceInput(appState: appState)
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(conversation.title)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .lineLimit(1)

            HStack {
                Text(conversation.metadata.provider?.displayName ?? "未设置")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text("·")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text(conversation.updatedAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
