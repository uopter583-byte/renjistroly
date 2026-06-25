import RenJistrolyIntelligence
import RenJistrolyModels
import RenJistrolyConversation
import SwiftUI

public struct AssistantRootView: View {
    @ObservedObject private var controller: AssistantSessionController
    @Environment(AppState.self) private var appState
    @Environment(ConversationEngine.self) private var engine

    @State private var inputText = ""
    @State private var showsSidebar = true
    @State private var showsContext = true
    @State private var showQuitConfirmation = false
    @State private var showPermissions = false
    @State private var showSettings = false
    @State private var showFoundation = false
    @FocusState private var inputFocused: Bool

    private let minSidebarWidth: CGFloat = 200
    private let maxSidebarWidth: CGFloat = 300
    private let minContextWidth: CGFloat = 220
    private let maxContextWidth: CGFloat = 340

    public init(controller: AssistantSessionController) {
        self.controller = controller
    }

    public var body: some View {
        HSplitView {
            // Left: Sidebar
            if showsSidebar {
                ConversationSidebar()
                    .frame(minWidth: minSidebarWidth, maxWidth: maxSidebarWidth)
                    .layoutPriority(0)
            }

            // Center: Chat
            chatArea
                .frame(minWidth: 400)
                .layoutPriority(1)

            // Right: Context Panel
            if showsContext {
                rightPanel
                    .frame(minWidth: minContextWidth, maxWidth: maxContextWidth)
                    .layoutPriority(0)
            }
        }
        .frame(minWidth: 720, minHeight: 460)
        .task {
            controller.refreshPermissions()
            await controller.refreshContext(includeScreenImage: false)
            try? await Task.sleep(nanoseconds: 800_000_000)
            controller.refreshPermissions()
        }
        .sheet(isPresented: $showPermissions) {
            PermissionsView(controller: controller)
                .frame(minWidth: 560, minHeight: 420)
        }
        .sheet(isPresented: $showSettings) {
            SettingsPanel(controller: controller) {
                showSettings = false
            }
                .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $showFoundation) {
            FoundationCenterView(controller: controller)
                .frame(minWidth: 620, minHeight: 480)
        }
        .confirmationDialog(
            RenJistrolyStrings.text("assistantConfirmAction"),
            isPresented: Binding(
                get: { controller.pendingAction != nil },
                set: { if !$0 { controller.cancelPendingAction() } }
            ),
            presenting: controller.pendingAction
        ) { _ in
            Button(RenJistrolyStrings.text("assistantExecute")) { controller.confirmPendingAction() }
            Button(RenJistrolyStrings.text("assistantCancel"), role: .cancel) { controller.cancelPendingAction() }
        } message: { action in
            Text(action.humanPreview)
        }
        .alert(RenJistrolyStrings.text("assistantQuitTitle"), isPresented: $showQuitConfirmation) {
            Button(RenJistrolyStrings.text("assistantCancel"), role: .cancel) {}
            Button(RenJistrolyStrings.text("assistantQuit"), role: .destructive) { NSApplication.shared.terminate(nil) }
        } message: {
            Text(RenJistrolyStrings.text("assistantQuitMessage"))
        }
    }

    // MARK: - Chat Area

    private var chatArea: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar

            Divider().opacity(0.3)

            // Messages
            messageList

            Divider().opacity(0.3)

            // Input
            ModernInputBar(text: $inputText, isFocused: $inputFocused) {
                submit()
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    private var topBar: some View {
        HStack(spacing: 6) {
            // Toggle sidebar
            IconButton(icon: "sidebar.left", label: RenJistrolyStrings.text("assistantSidebar")) {
                withAnimation(.easeInOut(duration: DS.Animation.fast)) { showsSidebar.toggle() }
            }

            StatusDot(
                color: statusColor,
                pulsing: engine.isProcessing || appState.voiceState.isCapturingAudio
            )

            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .contentTransition(.numericText())

            Spacer()

            // Conversation controls
            if appState.voiceState.isCapturingAudio {
                HStack(spacing: 3) {
                    Image(systemName: "waveform")
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                    Text(appState.voiceState == .listening ? RenJistrolyStrings.text("assistantListening") : RenJistrolyStrings.text("assistantTranscribing"))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.08))
                .clipShape(Capsule())
            }

            // Provider badge
            providerBadge

            // Toolbar
            IconButton(icon: "plus.bubble", label: RenJistrolyStrings.text("assistantNewConversation")) {
                _ = engine.sessionManager.createConversation()
                inputText = ""
            }

            IconButton(icon: "arrow.clockwise", label: RenJistrolyStrings.text("assistantRefreshContext")) {
                Task {
                    controller.refreshPermissions()
                    await controller.refreshContext(includeScreenImage: false)
                }
            }

            IconButton(icon: "text.viewfinder", label: RenJistrolyStrings.text("assistantReadScreen")) {
                Task { await controller.readCurrentScreen() }
            }

            IconButton(icon: "lock.shield", label: RenJistrolyStrings.text("assistantPermissions")) {
                showPermissions = true
            }

            IconButton(icon: "square.stack.3d.up", label: RenJistrolyStrings.text("assistantBaseCenter")) {
                showFoundation = true
            }

            IconButton(icon: "gearshape", label: RenJistrolyStrings.text("assistantSettings")) {
                showSettings = true
            }

            // Toggle context
            IconButton(icon: "sidebar.right", label: RenJistrolyStrings.text("assistantContextPanel")) {
                withAnimation(.easeInOut(duration: DS.Animation.fast)) { showsContext.toggle() }
            }

            // Quit
            IconButton(icon: "power", label: RenJistrolyStrings.text("assistantExit")) {
                showQuitConfirmation = true
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    private var providerBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: appState.activeProvider.isLocal ? "cpu" : "cloud")
                .font(.system(size: 9))
            Text(appState.activeProvider.displayName)
                .font(.system(size: 9))
        }
        .padding(.horizontal, 6)
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
                LazyVStack(alignment: .leading, spacing: 8) {
                    if appState.activePlan != nil {
                        PlanCard()
                            .padding(.horizontal, DS.Spacing.sm)
                    }

                    if displayMessages.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(displayMessages.enumerated()), id: \.element.id) { index, msg in
                            ModernMessageBubble(
                                message: msg,
                                isLast: index == displayMessages.count - 1
                            )
                            .id(msg.id)
                            .padding(.horizontal, DS.Spacing.md)
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.sm)
            }
            .onChange(of: engine.sessionManager.activeConversation?.messages.count ?? 0) { oldCount, newCount in
                guard newCount > oldCount, let last = displayMessages.last?.id else { return }
                withAnimation { proxy.scrollTo(last, anchor: .bottom) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer(minLength: 80)
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.accentFaint)
            Text("RenJistroly")
                .font(Typography.semibold(Typography.Size.title))
                .foregroundColor(.textPrimary)
            Text(RenJistrolyStrings.text("assistantInputPlaceholder"))
                .font(.system(size: Typography.Size.body))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            Spacer(minLength: 80)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Context header
            SectionHeader(title: RenJistrolyStrings.text("assistantContextSection"), icon: "gauge.with.dots.needle.33percent")
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.top, DS.Spacing.xs)

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    contextSection(RenJistrolyStrings.text("assistantCurrentApp"), icon: "app.badge") {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(controller.context.app?.appName ?? RenJistrolyStrings.text("assistantUnknown"))
                                .font(.system(size: 12, weight: .medium))
                            Text(controller.context.app?.windowTitle ?? RenJistrolyStrings.text("assistantNoWindowTitle"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }

                    contextSection(RenJistrolyStrings.text("assistantContextRunningApps"), icon: "square.grid.2x2") {
                        ForEach(controller.context.runningApps.prefix(8)) { app in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(app.isFrontmost ? Color.blue : Color.clear)
                                    .frame(width: 4, height: 4)
                                Text(app.appName)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                            }
                        }
                        if controller.context.runningApps.isEmpty {
                            Text(RenJistrolyStrings.text("assistantLoading"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    contextSection(RenJistrolyStrings.text("assistantContextFocusedElement"), icon: "cursorarrow") {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(RenJistrolyStrings.text("assistantContextRole") + ": " + (controller.context.focusedElement?.role ?? "-"))
                            Text(RenJistrolyStrings.text("assistantContextTitle") + ": " + (controller.context.focusedElement?.title ?? "-"))
                            if let selected = controller.context.focusedElement?.selectedText, !selected.isEmpty {
                                Text(RenJistrolyStrings.text("assistantContextSelected") + ": " + selected)
                                    .lineLimit(4)
                            }
                        }
                        .font(.system(size: 10))
                    }

                    contextSection(RenJistrolyStrings.text("assistantPermissions"), icon: "lock.shield") {
                        VStack(alignment: .leading, spacing: 2) {
                            permissionRow(RenJistrolyStrings.text("assistantPermissionAccessibility"), appState.isPermissionGranted.accessibility)
                            permissionRow(RenJistrolyStrings.text("assistantPermissionMicrophone"), appState.isPermissionGranted.microphone)
                            permissionRow(RenJistrolyStrings.text("assistantPermissionScreenRecording"), appState.isPermissionGranted.screenRecording)
                        }
                    }

                    if let ocr = controller.context.screen?.recognizedText, !ocr.isEmpty {
                        contextSection("OCR", icon: "text.viewfinder") {
                            Text(ocr)
                                .font(.system(size: 9, design: .monospaced))
                                .lineLimit(8)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.sm)
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
        .background(Color.surfaceSidebar)
    }

    private func contextSection(_ title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: title, icon: icon)
            content()
                .padding(.leading, 16)
                .padding(.vertical, 4)
        }
    }

    private func permissionRow(_ label: String, _ granted: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 8))
                .foregroundColor(granted ? .green : .red)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(granted ? .primary : .secondary)
        }
    }

    // MARK: - Status

    private var statusText: String {
        if appState.voiceState == .listening { return RenJistrolyStrings.text("assistantListeningStatus") }
        if appState.voiceState == .lockedListening { return RenJistrolyStrings.text("assistantLockedListening") }
        if appState.voiceState == .transcribing { return RenJistrolyStrings.text("assistantTranscribing") }
        if appState.voiceState == .speaking { return RenJistrolyStrings.text("assistantSpeaking") }
        if engine.isProcessing {
            if appState.activePlan?.status == .executing { return RenJistrolyStrings.text("assistantExecutingPlan") }
            return RenJistrolyStrings.text("assistantProcessing")
        }
        if let plan = appState.activePlan {
            switch plan.status {
            case .pendingApproval: return RenJistrolyStrings.text("assistantAwaitingApproval")
            case .executing: return RenJistrolyStrings.text("assistantExecutingPlan")
            case .completed: return RenJistrolyStrings.text("assistantPlanCompleted")
            case .failed: return RenJistrolyStrings.text("assistantPlanFailed")
            default: break
            }
        }
        return RenJistrolyStrings.text("assistantReady")
    }

    private var statusColor: Color {
        if appState.voiceState.isCapturingAudio { return .blue }
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

    // MARK: - Actions

    private func submit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        Task { await engine.sendMessage(text, appState: appState) }
    }
}
