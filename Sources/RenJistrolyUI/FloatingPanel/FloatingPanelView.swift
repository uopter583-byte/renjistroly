import SwiftUI
import RenJistrolyModels
import RenJistrolyConversation
import RenJistrolyIntelligence

public struct FloatingPanelView: View {
    @Environment(ConversationEngine.self) private var engine
    @Environment(AppState.self) private var appState

    @State private var inputText: String = ""
    @State private var showQuitConfirmation = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider().opacity(0.2)

            messageList

            Divider().opacity(0.2)

            inputSection
        }
        .frame(minWidth: 360, maxWidth: 480)
        .frame(height: 600)
        .overlay {
            if appState.pendingConfirmation != nil {
                confirmationOverlay
            }
        }
        .alert("退出 RenJistroly", isPresented: $showQuitConfirmation) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) { NSApplication.shared.terminate(nil) }
        } message: {
            Text("确定要退出 RenJistroly 吗？")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 6) {
            StatusDot(color: statusColor, pulsing: isProcessing || isVoiceActive)

            VStack(alignment: .leading, spacing: 1) {
                Text("RenJistroly")
                    .font(.system(size: 12, weight: .semibold))
                Text(statusText)
                    .font(.system(size: 10))
                    .foregroundColor(statusColor)
                    .contentTransition(.numericText())
            }

            Spacer()

            if isVoiceActive {
                VoiceWaveformView(isActive: true, voiceState: appState.voiceState)
                    .frame(width: 48)
            }

            providerBadge

            Menu {
                Menu("显示模式") {
                    Button("紧凑") { appState.mode = .compact }
                    Button("展开") { appState.mode = .expanded }
                    Button("沉浸") { appState.mode = .immersive }
                }
                Divider()
                Button("设置...") {
                    NSApp.sendAction(Selector(("showSettingsWindow")), to: nil, from: nil)
                }
                Divider()
                if appState.devMode.isEnabled {
                    Button { Task { await engine.buildProject(appState: appState) } } label: {
                        Label("构建", systemImage: "hammer")
                    }
                    Button { Task { await engine.runTests(appState: appState) } } label: {
                        Label("测试", systemImage: "checklist")
                    }
                    Divider()
                }
                Button("新建对话") {
                    _ = engine.sessionManager.createConversation()
                    inputText = ""
                }
                Button("清除历史") {
                    if let id = engine.sessionManager.activeConversationID {
                        engine.sessionManager.deleteConversation(id)
                    }
                    _ = engine.sessionManager.createConversation()
                    inputText = ""
                }
                Divider()
                Button("退出", role: .destructive) { showQuitConfirmation = true }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 22)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var providerBadge: some View {
        HStack(spacing: 2) {
            Image(systemName: appState.activeProvider.isLocal ? "cpu" : "cloud")
                .font(.system(size: 8))
            Text(appState.activeProvider.displayName)
                .font(.system(size: 8))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(appState.activeProvider.isLocal ? Color.statusGreenDim : Color.statusBlueDim)
        )
    }

    // MARK: - Messages

    private var messageList: some View {
        let displayMessages = engine.sessionManager.activeConversation?.messages.filter { $0.role != .system } ?? []
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if appState.activePlan != nil {
                        PlanCard()
                            .padding(.horizontal, 10)
                    }

                    if displayMessages.isEmpty {
                        emptyHint
                    } else {
                        ForEach(Array(displayMessages.enumerated()), id: \.element.id) { index, msg in
                            ModernMessageBubble(message: msg, isLast: index == displayMessages.count - 1)
                                .id(msg.id)
                                .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: engine.sessionManager.activeConversation?.messages.count ?? 0) { oldCount, newCount in
                guard newCount > oldCount, let last = displayMessages.last?.id else { return }
                withAnimation { proxy.scrollTo(last, anchor: .bottom) }
            }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: DS.Spacing.xs) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: Typography.Size.hero))
                .foregroundColor(.accentFaint)
            Text("开始对话")
                .font(.system(size: Typography.Size.body))
                .foregroundColor(.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(spacing: 0) {
            if appState.voiceState == .failed, let error = engine.voiceError {
                voiceErrorBar(error)
            }

            HStack(alignment: .bottom, spacing: 6) {
                voiceButton

                TextField("输入消息...", text: $inputText, axis: .vertical)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .onSubmit {
                        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        send(text)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.surfaceInput)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                sendButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            bottomBar
        }
        .background(.ultraThinMaterial)
    }

    private var voiceButton: some View {
        let controller = AssistantSessionController.shared
        return VoiceButton(
            onStart: {
                Task {
                    guard await controller.requestMicrophonePermission() else { return }
                    controller.startListening()
                }
            },
            onFinish: {
                controller.stopListening()
            },
            onToggle: {
                Task {
                    guard await controller.requestMicrophonePermission() else { return }
                    controller.toggleConversationMode()
                }
            }
        )
        .help("按住录音 / 连续对话")
    }

    private var sendButton: some View {
        Button {
            if engine.isProcessing {
                // Processing — stop button does nothing during processing
            } else {
                let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                send(text)
            }
        } label: {
            Image(systemName: engine.isProcessing ? "stop.circle.fill" : "arrow.up.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(canSend ? .accentColor : .secondary.opacity(0.4))
        }
        .buttonStyle(.plain)
        .disabled(!canSend && !engine.isProcessing)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            if let projectType = engine.contextCompiler.currentContext?.projectType {
                Badge(text: projectType.rawValue)
            }

            scenarioActions

            if appState.devMode.isEnabled {
                devActions
            }

            Spacer()

            HStack(spacing: 4) {
                if isVoiceActive {
                    Badge(text: "聆听中", color: .blue)
                } else {
                    Text("按住🎤说话 · 点按🎤+实时对话")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                if isProcessing {
                    HStack(spacing: 3) {
                        ProgressView()
                            .scaleEffect(0.35)
                        Text("思考中...")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    private var scenarioActions: some View {
        HStack(spacing: 4) {
            IconButton(icon: "wand.and.stars", label: "润色") {
                Task { await runScenario(.polish) }
            }
            IconButton(icon: "text.bubble", label: "解释") {
                Task { await runScenario(.explain) }
            }
            IconButton(icon: "eye", label: "读屏") {
                Task { await runScenario(.readScreen) }
            }
        }
    }

    private var devActions: some View {
        HStack(spacing: 4) {
            IconButton(icon: "hammer", label: "构建") {
                Task { await engine.buildProject(appState: appState) }
            }
            IconButton(icon: "checklist", label: "测试") {
                Task { await engine.runTests(appState: appState) }
            }
        }
    }

    private func voiceErrorBar(_ error: String) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: Typography.Size.caption))
                .foregroundColor(.statusOrange)
            Text(error)
                .font(.system(size: Typography.Size.small))
                .foregroundColor(.textSecondary)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, DS.Spacing.xxs)
        .background(Color.statusOrangeDim)
    }

    // MARK: - Confirmation Overlay

    private var confirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { engine.resolveConfirmation(approved: false, appState: appState) }

            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)

                Text("确认操作")
                    .font(.system(size: 14, weight: .semibold))

                if let c = appState.pendingConfirmation {
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent("工具") { Text(c.toolName).font(.system(size: 12, weight: .medium)) }
                        LabeledContent("风险") {
                            Text(c.riskLevel.rawValue)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(c.riskLevel == .high ? .red : .orange)
                        }
                        Text(c.summary)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 12) {
                    Button("取消") { engine.resolveConfirmation(approved: false, appState: appState) }
                        .buttonStyle(.plain)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 14)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Button("批准") { engine.resolveConfirmation(approved: true, appState: appState) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }
            .padding(20)
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.windowBackgroundColor))
                    .shadow(color: .black.opacity(0.15), radius: 16)
            )
        }
    }

    // MARK: - Status

    private var statusText: String {
        if isVoiceActive {
            switch appState.voiceState {
            case .listening: return "正在听..."
            case .lockedListening: return "持续监听..."
            case .transcribing: return "转写中..."
            case .speaking: return "朗读中..."
            default: break
            }
        }
        if isProcessing {
            if appState.activePlan?.status == .executing { return "执行计划..." }
            return "处理中..."
        }
        if let plan = appState.activePlan {
            switch plan.status {
            case .pendingApproval: return "等待批准"
            case .executing: return "执行计划..."
            case .completed: return "计划完成"
            case .failed: return "计划失败"
            case .drafting: return "生成计划..."
            default: break
            }
        }
        return "就绪"
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
            case .failed: return .red
            case .completed: return .green
            default: return .blue
            }
        }
        return .green
    }

    private var isProcessing: Bool { engine.isProcessing }

    private var isVoiceActive: Bool {
        appState.voiceState == .failed || appState.voiceState.isCapturingAudio || appState.voiceState == .speaking
    }

    // MARK: - Actions

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

    private func send(_ text: String) {
        inputText = ""
        Task { await engine.sendMessage(text, appState: appState) }
    }

    private func toggleVoice() {
        let controller = AssistantSessionController.shared
        switch appState.voiceState {
        case .idle, .failed:
            Task {
                guard await controller.requestMicrophonePermission() else { return }
                try? await Task.sleep(for: .milliseconds(120))
                controller.toggleListening()
            }
        case .listening, .lockedListening, .transcribing:
            controller.toggleListening()
        default:
            controller.stopSpeaking()
        }
    }

}
