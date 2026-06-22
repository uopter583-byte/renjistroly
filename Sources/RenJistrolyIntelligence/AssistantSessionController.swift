import AppKit
import AVFoundation
import Foundation
import os
import Speech
import RenJistrolyModels
import RenJistrolySystemBridge
import RenJistrolyCapability

private let voiceLog = OSLog(subsystem: "com.renjistroly", category: "voice")

public enum ClaudeCodeLoginGuide {
    public static let command = "claude /login"
    public static let help = "Claude Code 需要先登录。请在终端运行 `claude /login`，登录完成后回到 RenJistroly 重试。"
}

@MainActor
public final class AssistantSessionController: ObservableObject {
    public static let shared = AssistantSessionController()
    public let eventBus = AgentEventBus.shared

    @Published public internal(set) var voiceState = VoiceSessionState() {
        didSet { syncAppStateFromVoiceState() }
    }
    public var appState: AppState? {
        didSet {
            if appState != nil { syncActiveProvider() }
        }
    }
    @Published public internal(set) var permissions: [PermissionSnapshot] = []
    @Published public internal(set) var context = AssistantContext()
    @Published public internal(set) var pendingAction: MacAction?
    @Published public internal(set) var lastActionResult: ActionResult?
    @Published public internal(set) var lastUserText = ""
    @Published public internal(set) var foundationLayers: [FoundationLayerSnapshot] = []
    @Published public internal(set) var fullAccessCapabilities: [FullAccessCapabilitySnapshot] = []
    @Published public internal(set) var recentDiagnostics: [AssistantDiagnosticSnapshot] = []
    @Published public internal(set) var recentFeedback: [FeedbackReport] = []
    @Published public internal(set) var userMemories: [UserOperationMemory] = []
    @Published public internal(set) var upgradePlans: [UpgradePlan] = []
    @Published public internal(set) var providerHealth: [ProviderHealthSnapshot] = []
    @Published public internal(set) var scenarioAuditReport = ScenarioAuditReport(items: [])
    @Published public internal(set) var nativeAccessibilityFeatures = NativeAccessibilityFeatureCatalog.all
    @Published public internal(set) var foundationMessage = ""
    @Published public internal(set) var lastComputerUseObservation: ComputerUseObservation?
    @Published public internal(set) var lastComputerUsePlan: ComputerUsePlan?
    @Published public internal(set) var lastComputerUseResult: ComputerUseRunOutcome?
    @Published public internal(set) var computerUseCoordinatorStatus: String?
    @Published public internal(set) var terminalTasks: [TerminalTaskRecord] = []
    @Published public var providerPreference: ProviderPreference = .claudeCode {
        didSet {
            if !providerPreference.isImplemented {
                providerPreference = .deepSeek
                UserDefaults.standard.set(providerPreference.rawValue, forKey: "providerPreference")
                return
            }
            UserDefaults.standard.set(providerPreference.rawValue, forKey: "providerPreference")
            syncActiveProvider()
        }
    }
    @Published public var providerKeys: [String: String] = [:]
    @Published public var providerModels: [ProviderKind: String] = [:]
    @Published public var providerBaseURLs: [ProviderKind: String] = [:]
    @Published public var speechRateMultiplier: Double = 1.9 {
        didSet {
            UserDefaults.standard.set(speechRateMultiplier, forKey: "speechRateMultiplier")
        }
    }
    @Published public var hotkeyPreset: HotkeyPreset = .controlOptionSpace {
        didSet {
            UserDefaults.standard.set(hotkeyPreset.rawValue, forKey: "hotkeyPreset")
            NotificationCenter.default.post(name: .macVoiceHotkeyDidChange, object: nil)
        }
    }
    @Published public var voiceSubmitMode: VoiceSubmitMode = .manual {
        didSet {
            UserDefaults.standard.set(voiceSubmitMode.rawValue, forKey: "voiceSubmitMode")
        }
    }
    @Published public var autoSubmitSilenceSeconds: Double = 3.0 {
        didSet {
            UserDefaults.standard.set(autoSubmitSilenceSeconds, forKey: "autoSubmitSilenceSeconds")
        }
    }

    /// 语音对话完成后回调 (用户文本, 助手回复)，供外部保存到主对话
    public var onMessagePair: (@Sendable (String, String) -> Void)?

    let permissionCenter = PermissionCenter()
    private let speechTranscriber = NativeSpeechTranscriber()
    let screenContext = ScreenContextProvider()
    let accessibility = AccessibilityContextProvider()
    private let actionPolicy = ActionPolicy()
    private let quickResponder = LocalQuickResponder()
    private let localActionParser = LocalActionParser()
    private let computerUsePlanner = ComputerUsePlanner()
    private let modelActionPlanner = ModelActionPlanner()
    let appInstructionLibrary = AppInstructionLibrary()
    let foundationStore = FoundationStore()
    lazy var diagnosticsCenter = FoundationDiagnosticsCenter(store: foundationStore)
    lazy var feedbackCenter = FeedbackCenter(store: foundationStore)
    lazy var memoryStore = UserOperationMemoryStore(store: foundationStore)
    lazy var upgradeRecoveryCenter = UpgradeRecoveryCenter(store: foundationStore)
    lazy var terminalTaskStore = TerminalTaskStore(store: foundationStore)
    let foundationHealthCenter = FoundationHealthCenter()
    let scenarioAuditEngine = ScenarioAuditEngine()
    private lazy var actionExecutor = ActionExecutor(accessibility: accessibility)
    private lazy var computerUseObserver = ComputerUseObserver(accessibility: accessibility, screen: screenContext)
    private lazy var computerUseCoordinator = ComputerUseCoordinator(
        accessibility: accessibility,
        observer: computerUseObserver,
        vision: VisionCUAFallback()
    )
    lazy var axNotificationObserver = AXNotificationObserver()
    private lazy var screenStreamProvider = ScreenStreamProvider()

    private var realtime: (any RealtimeSession)?
    private var chat: (any ChatProvider)?
    var tts: (any TTSProvider)?
    var listenTask: Task<Void, Never>?
    var speechAutoSendTask: Task<Void, Never>?
    var conversationRestartTask: Task<Void, Never>?
    var lastRecognizedSpeech = ""
    var submittedSpeechText = ""
    var forceScreenContextUntil: Date?
    lazy var claudeCodeBackend = ClaudeCodeCLIBackend()
    let contextStore = ContextStore()

    @Published public internal(set) var contextExchangeCount = 0
    @Published public internal(set) var currentTrace: InteractionTrace?
    @Published public internal(set) var recentTraces: [TraceLatencySummary] = []
    @Published public internal(set) var activeDialogs: [ActiveDialogState] = []
    private var _activeTrace: InteractionTrace?
    var dialogWatchTask: Task<Void, Never>?
    let maxActiveDialogs = 5

    /// Global kill switch for Gate feature. When false (default), the entire Gate
    /// relay is disabled regardless of user settings. UI must render controls as
    /// disabled/"实验" when this is false.
    public static let gateGlobalKillSwitch: Bool = false

    func syncAppStateFromPermissions(_ snapshots: [PermissionSnapshot]) {
        guard let appState else { return }
        for snapshot in snapshots {
            let granted = snapshot.status.isGranted
            switch snapshot.kind {
            case .microphone:
                appState.isPermissionGranted.microphone = granted
            case .speechRecognition:
                appState.isPermissionGranted.speechRecognition = granted
            case .screenRecording:
                if snapshot.status != .unknown {
                    appState.isPermissionGranted.screenRecording = granted
                }
            case .accessibility:
                appState.isPermissionGranted.accessibility = granted
            case .automation:
                appState.isPermissionGranted.appleEvents = granted
            case .fileSystem, .shellExecution, .network, .apiCredentials, .stableIdentity:
                continue
            }
        }
    }

    private var _isSettingGateEnabled = false

    @Published public var gateEnabled: Bool = false {
        didSet {
            guard !_isSettingGateEnabled else { return }
            _isSettingGateEnabled = true
            defer { _isSettingGateEnabled = false }

            if Self.gateGlobalKillSwitch {
                let wasEnabled = oldValue
                gateEnabled = false
                if wasEnabled {
                    gateReplyTask?.cancel()
                    gateReplyTask = nil
                    gateTimeoutTask?.cancel()
                    gateTimeoutTask = nil
                    gateProbeTask?.cancel()
                    gateProbeTask = nil
                    pendingGateSpeech = nil
                    gateIsConnected = false
                }
                return
            }

            UserDefaults.standard.set(gateEnabled, forKey: "gateEnabled")
            Task { await eventBus.publish(.voice(.gateToggled(gateEnabled))) }
            if gateEnabled {
                gateIsConnected = true
                startGateReplyLoop()
                probeGate()
            } else {
                gateReplyTask?.cancel()
                gateReplyTask = nil
                gateTimeoutTask?.cancel()
                gateTimeoutTask = nil
                gateProbeTask?.cancel()
                gateProbeTask = nil
                pendingGateSpeech = nil
                gateIsConnected = false
            }
        }
    }
    var gateReplyTask: Task<Void, Never>?
    var gateTimeoutTask: Task<Void, Never>?
    var pendingGateSpeech: String?
    var gateProbeTask: Task<Void, Never>?
    public let gateDir = "/tmp/renjistroly"
    var speechFilePath: String { "\(gateDir)/speech_in.txt" }
    var replyFilePath: String { "\(gateDir)/reply_out.txt" }
    /// Probe timeout for gate connectivity check. Reduced from 2s to 500ms
    /// to minimize perceived delay before each input.
    static let gateProbeTimeoutNanos: UInt64 = 500_000_000
    var gateIsConnected: Bool = false
    var gateConfig: GateConfiguration = .default

    public init() {
        loadProviderSettings()
        loadGateSetting()
        Task { await refreshFoundationState() }
        Task { await refreshContextCount() }
        Task { await axNotificationObserver.startObserving() }
        startDialogWatcher()
        // Pre-warm claude binary and runtime in background. Uses --version
        // to avoid any API call cost while still loading the binary into
        // the OS page cache so the first real invocation starts faster.
        Task { await prewarmClaudeCLI() }
    }

    /// Warm the claude CLI binary and its runtime dependencies into the OS page
    /// cache by running `claude --version`. This reduces the 10-15s cold start
    /// delay on the first real LLM call (claude binary, libraries, and Python
    /// runtime get pre-loaded).
    private func prewarmClaudeCLI() async {
        guard FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/claude") else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/claude")
        process.arguments = ["--version"]
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            // Silently ignore warmup failures — this is best-effort
        }
    }



    private func startTrace() {
        _activeTrace = InteractionTrace()
        currentTrace = _activeTrace
    }

    private func trace(_ kind: TraceEventKind, detail: String = "") {
        _activeTrace?.append(kind, detail: detail)
        currentTrace = _activeTrace
        Task { await publishTraceToEventBus(kind, detail: detail) }
    }

    private func publishTraceToEventBus(_ kind: TraceEventKind, detail: String) async {
        switch kind {
        case .inputStarted:
            break // already published via voice(.listeningStarted)
        case .speechPartial:
            break // already published via voice(.transcriptPartial)
        case .speechFinal:
            await eventBus.publish(.voice(.transcriptFinal(detail)))
        case .contextObserved:
            await eventBus.publish(.lifecycle(.contextObserved(detail: detail)))
        case .routeSelected:
            await eventBus.publish(.lifecycle(.routeSelected(provider: detail, confidence: 1.0)))
        case .modelFirstToken:
            await eventBus.publish(.lifecycle(.modelFirstToken))
        case .toolStarted:
            await eventBus.publish(.lifecycle(.actingStarted(action: detail, tool: detail)))
        case .verifyDone:
            await eventBus.publish(.lifecycle(.verifyingCompleted(action: detail, passed: detail.hasPrefix("pass"))))
        case .ttsStarted:
            break // already published via voice(.ttsStarted)
        case .turnComplete:
            let duration = _activeTrace?.totalDuration
            await eventBus.publish(.lifecycle(.turnCompleted(duration: duration)))
        case .turnFailed:
            await eventBus.publish(.lifecycle(.turnFailed(error: detail)))
        }
    }

    private func finishTrace(failed: Bool = false) {
        _activeTrace?.append(failed ? .turnFailed : .turnComplete)
        let duration = _activeTrace?.totalDuration
        Task {
            if failed {
                await eventBus.publish(.lifecycle(.turnFailed(error: nil)))
            } else {
                await eventBus.publish(.lifecycle(.turnCompleted(duration: duration)))
            }
        }
        if let trace = _activeTrace {
            let summary = TraceLatencySummary(from: trace)
            recentTraces.insert(summary, at: 0)
            if recentTraces.count > 50 { recentTraces = Array(recentTraces.prefix(50)) }
        }
        currentTrace = _activeTrace
    }



    public var installedAppPath: String {
        "\(NSHomeDirectory())/Applications/RenJistroly.app"
    }

    public func restartInstalledApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", installedAppPath]
        try? process.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }

    /// Request mic permission from the main actor before creating background Tasks,
    /// because AVCaptureDevice.requestAccess() may not show the system dialog properly
    /// when called from a detached background context.
    public func requestMicrophonePermission() async -> Bool {
        let status = MicrophoneAuthorizationRequester.authorizationStatus()
        os_log("[requestMicrophonePermission] status=%{public}@", log: voiceLog, type: .info, "\(status)")
        if status == .authorized {
            syncAppStateFromPermissions([PermissionSnapshot(kind: .microphone, status: .granted)])
            return true
        }
        if status == .denied {
            syncAppStateFromPermissions([PermissionSnapshot(kind: .microphone, status: .denied)])
            await MainActor.run { voiceState.latestAssistantText = "需要麦克风权限才能录入语音，请在「系统设置 > 隐私与安全性 > 麦克风」中授权。" }
            return false
        }
        let granted = await MicrophoneAuthorizationRequester.requestAccess()
        os_log("[requestMicrophonePermission] request result=%{public}@", log: voiceLog, type: .info, granted ? "granted" : "denied")
        syncAppStateFromPermissions([PermissionSnapshot(kind: .microphone, status: granted ? .granted : .denied)])
        return granted
    }

    public func toggleListening() {
        voiceState.isListening ? stopListening() : startListening()
    }

    public func toggleConversationMode() {
        voiceState.isConversationMode ? stopConversationMode() : startConversationMode()
    }

    public func startConversationMode() {
        guard !voiceState.isConversationMode else { return }
        voiceState.isConversationMode = true
        voiceSubmitMode = .automatic
        if autoSubmitSilenceSeconds < 1.2 {
            autoSubmitSilenceSeconds = 1.6
        }
        voiceState.latestAssistantText = "实时对话已开启。说完停顿一下，我会自动回答。"
        Task { await eventBus.publish(.voice(.conversationModeToggled(true))) }
        startListening(clearAssistantText: false)
    }

    public func stopConversationMode() {
        var st = voiceState
        st.isConversationMode = false
        voiceState = st
        conversationRestartTask?.cancel()
        conversationRestartTask = nil
        stopListening(shouldSubmit: false)
        Task { await eventBus.publish(.voice(.conversationModeToggled(false))) }
        Task { await tts?.stop() }
        st = voiceState
        st.isSpeaking = false
        st.isThinking = false
        st.latestAssistantText = "实时对话已停止。"
        voiceState = st
    }

    public func startListening() {
        startListening(clearAssistantText: true)
    }

    func startListening(clearAssistantText: Bool) {
        guard !voiceState.isListening else {
            os_log("[startListening] already listening, ignoring", log: voiceLog, type: .debug)
            return
        }
        os_log("[startListening] clearAssistantText=%{public}@", log: voiceLog, type: .info, clearAssistantText ? "true" : "false")

        if voiceState.isSpeaking {
            Task { await tts?.stop() }
            voiceState.isSpeaking = false
        }

        // Set visual state immediately so the mic icon changes.
        // Replace the entire struct so didSet fires and syncs appState.
        var st = voiceState
        st.isListening = true
        st.isThinking = false
        st.latestTranscript = ""
        voiceState = st
        Task { await eventBus.publish(.voice(.listeningStarted)) }
        if clearAssistantText {
            voiceState.latestAssistantText = ""
        }
        lastRecognizedSpeech = ""
        submittedSpeechText = ""

        listenTask = Task { [weak self] in
            guard let self else { return }
            os_log("[startListening] listenTask started", log: voiceLog, type: .info)

            // Step 1: Check/request microphone permission
            let micStatus = MicrophoneAuthorizationRequester.authorizationStatus()
            os_log("[startListening] mic status=%{public}@", log: voiceLog, type: .info, "\(micStatus)")
            if micStatus != .authorized {
                let micGranted = await MicrophoneAuthorizationRequester.requestAccess()
                guard micGranted else {
                    os_log("[startListening] mic permission denied", log: voiceLog, type: .error)
                    await MainActor.run {
                        self.updateVoiceState { s in
                            s.latestAssistantText = "需要麦克风权限才能录入语音。"
                            s.isListening = false
                        }
                    }
                    return
                }
            }

            // Step 2: Check/request speech recognition permission
            let srStatus = SFSpeechRecognizer.authorizationStatus()
            os_log("[startListening] sr status=%d", log: voiceLog, type: .info, srStatus.rawValue)
            if srStatus != .authorized {
                let srGranted = await SpeechAuthorizationRequester.requestAuthorized()
                guard srGranted else {
                    os_log("[startListening] speech permission denied", log: voiceLog, type: .error)
                    await MainActor.run {
                        self.updateVoiceState { s in
                            s.latestAssistantText = "需要语音识别权限才能把语音转成文字。"
                            s.isListening = false
                        }
                    }
                    return
                }
            }

            // Step 3: Refresh permission display
            self.permissions = await self.permissionCenter.checkAll()
            await MainActor.run {
                self.syncAppStateFromPermissions(self.permissions)
            }
            os_log("[startListening] permissions refreshed, mic=%{public}@ speech=%{public}@",
                   log: voiceLog, type: .info,
                   self.permissions.first { $0.kind == .microphone }?.status.label ?? "?",
                   self.permissions.first { $0.kind == .speechRecognition }?.status.label ?? "?")

            // Step 4: Start speech transcriber
            os_log("[startListening] calling speechTranscriber.start()", log: voiceLog, type: .info)
            let transcripts: AsyncStream<TranscriptEvent>
            do {
                transcripts = try self.speechTranscriber.start()
            } catch {
                os_log("[startListening] speechTranscriber.start() threw: %{public}@", log: voiceLog, type: .error, error.localizedDescription)
                await MainActor.run {
                    self.voiceState.latestAssistantText = Self.readableError(error, prefix: "启动监听失败")
                    self.voiceState.isListening = false
                }
                return
            }
            os_log("[startListening] speechTranscriber.start() returned stream", log: voiceLog, type: .info)

            // Step 5: Process transcription events
            var lastFinal = ""
            var speechStarted = false
            var eventCount = 0
            for await event in transcripts {
                eventCount += 1
                if Task.isCancelled { break }
                os_log("[startListening] event #%d: %{public}@", log: voiceLog, type: .debug, eventCount, String(describing: event))
                switch event {
                case .partial(let text):
                    self.voiceState.latestTranscript = text
                    self.lastRecognizedSpeech = text
                    if !speechStarted {
                        speechStarted = true
                        await eventBus.publish(.voice(.speechStarted))
                    }
                    await eventBus.publish(.voice(.transcriptPartial(text)))
                    if self.voiceSubmitMode == .automatic {
                        self.scheduleSpeechAutoSend(text)
                    }
                case .final(let text):
                    self.voiceState.latestTranscript = text
                    self.lastRecognizedSpeech = text
                    lastFinal = text
                    if speechStarted {
                        await eventBus.publish(.voice(.speechEnded))
                    }
                    if self.voiceSubmitMode == .automatic {
                        self.scheduleSpeechAutoSend(text, delayNanoseconds: 200_000_000)
                    }
                case .failed(let message):
                    os_log("[startListening] event failed: %{public}@", log: voiceLog, type: .error, message)
                    self.voiceState.latestAssistantText = message
                }
            }

            // Step 6: Cleanup
            os_log("[startListening] stream ended, eventCount=%d", log: voiceLog, type: .info, eventCount)
            self.speechTranscriber.stop()
            self.voiceState.isListening = false
            let textToSend = lastFinal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? self.lastRecognizedSpeech : lastFinal
            self.submitRecognizedSpeech(textToSend)
        }
    }

    public func stopListening() {
        stopListening(shouldSubmit: true)
    }

    private func stopListening(shouldSubmit: Bool) {
        let textToSend = lastRecognizedSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
        speechAutoSendTask?.cancel()
        speechAutoSendTask = nil
        speechTranscriber.stop()
        var st = voiceState
        st.isListening = false
        voiceState = st
        listenTask?.cancel()
        listenTask = nil
        if voiceState.isSpeaking {
            Task { await tts?.stop() }
            voiceState.isSpeaking = false
        }
        Task { await eventBus.publish(.voice(.listeningStopped)) }
        Task {
            await realtime?.disconnect()
            if shouldSubmit {
                submitRecognizedSpeech(textToSend)
            }
        }
    }

    public func sendText(_ text: String) {
        Task {
            await handleUserText(text)
        }
    }

    public func stopSpeaking() {
        Task {
            await tts?.stop()
            await eventBus.publish(.voice(.ttsInterrupted))
        }
    }

    func speak(_ text: String) async {
        do {
            voiceState.isSpeaking = true
            await eventBus.publish(.voice(.ttsStarted(text)))
            try await tts?.speak(text)
            await eventBus.publish(.voice(.ttsCompleted))
        } catch {
            lastActionResult = ActionResult(actionID: UUID(), success: false, message: "朗读失败：\(error.localizedDescription)")
        }
        voiceState.isSpeaking = false
        scheduleConversationRestartIfNeeded()
    }

    public func copyAssistantReply() {
        let text = voiceState.latestAssistantText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        copyToPasteboard(text, message: "已复制回复。")
    }

    public func copyTranscript() {
        let text = voiceState.latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        copyToPasteboard(text, message: "已复制语音转写。")
    }

    public func copyClaudeCodeLoginCommand() {
        copyToPasteboard(ClaudeCodeLoginGuide.command, message: "已复制 Claude Code 登录命令。")
        voiceState.latestAssistantText = ClaudeCodeLoginGuide.help
    }

    public func openTerminalForClaudeCodeLogin() {
        copyClaudeCodeLoginCommand()
        let candidates = [
            "/System/Applications/Utilities/Terminal.app",
            "/Applications/Utilities/Terminal.app"
        ]
        if let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }

    private func copyToPasteboard(_ text: String, message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        lastActionResult = ActionResult(actionID: UUID(), success: true, message: message)
    }

    public func insertAssistantReplyAtCursor() {
        let text = voiceState.latestAssistantText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        insertTextAtCursor(text, preview: "把助手回复插入当前光标位置。")
    }

    public func insertTranscriptAtCursor() {
        let text = voiceState.latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        insertTextAtCursor(text, preview: "把语音转写插入当前光标位置。")
    }

    private func insertTextAtCursor(_ text: String, preview: String) {
        let action = MacAction(
            kind: .insertText,
            payload: ["text": text],
            riskLevel: .reversibleInput,
            humanPreview: preview
        )
        propose(action)
    }

    public func resendLastUserText() {
        let text = lastUserText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sendText(text)
    }



    public func observeComputerUse() {
        Task {
            let observation = await computerUseObserver.observe(includeOCR: true, skipOwnWindows: true)
            lastComputerUseObservation = observation
            foundationMessage = "已观察到 \(observation.runningApps.count) 个运行中 App、\(observation.visibleWindows.count) 个可见窗口、\(observation.targets.count) 个目标。"
            await refreshContext(includeScreenImage: true)
        }
    }

    public func createTerminalTask(name: String, command: String, workingDirectory: String? = nil) {
        Task {
            let cwd: String
            if let dir = workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines), !dir.isEmpty {
                cwd = dir
            } else {
                cwd = "\(NSHomeDirectory())/RenJistroly"
            }
            let task = await terminalTaskStore.create(name: name, command: command, workingDirectory: cwd)
            let started = await terminalTaskStore.start(id: task.id)
            terminalTasks = await terminalTaskStore.all()
            let success = started?.status == .running
            let message = started?.lastMessage ?? "终端任务启动失败。"
            lastActionResult = ActionResult(actionID: task.id, success: success, message: message)
            foundationMessage = success ? "终端任务已启动：\(task.name)" : "终端任务启动失败：\(message)"
        }
    }

    public func refreshTerminalTasks() {
        Task {
            await terminalTaskStore.refreshStatuses()
            terminalTasks = await terminalTaskStore.all()
            foundationMessage = "终端任务状态已刷新。"
            await refreshFoundationState()
        }
    }

    public func stopTerminalTask(id: UUID) {
        Task {
            let task = await terminalTaskStore.stop(id: id)
            terminalTasks = await terminalTaskStore.all()
            foundationMessage = task.map { "已停止终端任务：\($0.name)" } ?? "未找到终端任务。"
            await refreshFoundationState()
        }
    }

    public func restartTerminalTask(id: UUID) {
        Task {
            let task = await terminalTaskStore.restart(id: id)
            terminalTasks = await terminalTaskStore.all()
            foundationMessage = task.map { "已重启终端任务：\($0.name)" } ?? "未找到终端任务。"
            await refreshFoundationState()
        }
    }

    public func openTerminalTaskLog(id: UUID) {
        guard let task = terminalTasks.first(where: { $0.id == id }),
              let path = task.logPath
        else {
            foundationMessage = "没有找到任务日志。"
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func scheduleSpeechAutoSend(_ text: String, delayNanoseconds: UInt64? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        speechAutoSendTask?.cancel()
        let delay = delayNanoseconds ?? UInt64(max(0.3, autoSubmitSilenceSeconds) * 1_000_000_000)
        speechAutoSendTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self else { return }
            await MainActor.run {
                guard self.voiceState.isListening else { return }
                guard self.lastRecognizedSpeech.trimmingCharacters(in: .whitespacesAndNewlines) == trimmed else { return }
                self.voiceState.isListening = false
                self.listenTask?.cancel()
                self.listenTask = nil
                self.speechTranscriber.stop()
                self.submitRecognizedSpeech(trimmed)
            }
        }
    }


    private func submitRecognizedSpeech(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != submittedSpeechText else { return }
        guard isValidSpeechContent(trimmed) else {
            voiceState.latestTranscript = ""
            return
        }
        submittedSpeechText = trimmed
        sendText(trimmed)
    }

    private func handleUserText(_ text: String) async {
        let startedAt = Date()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            scheduleConversationRestartIfNeeded()
            return
        }
        lastUserText = trimmed
        voiceState.latestTranscript = trimmed

        if handleBuiltInCommand(trimmed) {
            scheduleConversationRestartIfNeeded()
            return
        }

        voiceState.isThinking = true
        defer { voiceState.isThinking = false }

        startTrace()
        trace(.inputStarted)
        trace(.speechFinal, detail: trimmed.count < 60 ? trimmed : String(trimmed.prefix(57)) + "...")

        if gateEnabled {
            if gateIsConnected {
                if !gateConfig.allowAutoTerminalInput && looksLikeTerminalCommand(trimmed) {
                    voiceState.latestAssistantText = "Gate 未自动转发终端命令，使用本地处理..."
                } else {
                    trace(.routeSelected, detail: "gateRelay")
                    writeToSpeechFile(trimmed)
                    voiceState.latestAssistantText = "已通过 Gate 转发..."
                    voiceState.latestTranscript = ""
                    pendingGateSpeech = trimmed
                    gateTimeoutTask?.cancel()
                    gateTimeoutTask = Task { [weak self] in
                        try? await Task.sleep(for: .seconds(Int64(self?.gateConfig.timeoutSeconds ?? 3.0)))
                        guard let self else { return }
                        await MainActor.run {
                            guard self.pendingGateSpeech != nil else { return }
                            self.voiceState.latestAssistantText = "Gate 无响应（\(Int(gateConfig.timeoutSeconds))s），切回本地处理..."
                            self.gateIsConnected = false
                            let fallback = self.pendingGateSpeech ?? ""
                            self.pendingGateSpeech = nil
                            Task { await self.handleUserText(fallback) }
                        }
                    }
                    finishTrace()
                    scheduleConversationRestartIfNeeded()
                    return
                }
            } else {
                // Gate is enabled but no relay process is listening — fall through to local processing
                voiceState.latestAssistantText = "Gate 已开启，但未检测到外部中继进程，使用本地处理..."
                gateTimeoutTask?.cancel()
                gateTimeoutTask = nil
                pendingGateSpeech = nil
            }
        }

        if isComplaint(trimmed) {
            let diagnostic = makeDiagnostic(
                userText: trimmed,
                assistantText: voiceState.latestAssistantText,
                parsedAction: nil,
                error: nil,
                startedAt: startedAt
            )
            await diagnosticsCenter.record(diagnostic)
            let report = await feedbackCenter.createReport(complaint: trimmed, diagnosticID: diagnostic.id)
            _ = await upgradeRecoveryCenter.createPlan(reason: "用户反馈：\(trimmed)")
            foundationMessage = "已记录反馈：\(report.category.title)。继续处理当前请求。"
            await refreshFoundationState()
        }

        // Claude Code 模式下始终包含屏幕上下文，以便模型能基于真实界面操作
        let includeScreenContext = providerPreference == .claudeCode || shouldIncludeScreenContext(for: trimmed)
        let observation = await computerUseObserver.observe(includeOCR: includeScreenContext || looksLikeComputerUse(trimmed))
        lastComputerUseObservation = observation
        trace(.contextObserved, detail: "OCR:\(includeScreenContext ? "on" : "off") visible:\(observation.visibleWindows.count)")
        if let plan = computerUsePlanner.plan(userText: trimmed, observation: observation),
           plan.action != nil || !plan.steps.isEmpty {
            trace(.routeSelected, detail: "computerUse:\(plan.intent.rawValue)")
            lastComputerUsePlan = plan
            let preview = plan.action?.humanPreview ?? plan.steps.map { $0.action.humanPreview }.joined(separator: " -> ")
            await memoryStore.remember(key: trimmed, value: preview, category: "localAction", confidence: 0.75)
            await performComputerUsePlan(plan, userText: trimmed, startedAt: startedAt, beforeObservation: observation)
            return
        }

        if let localReply = quickResponder.reply(to: trimmed) {
            trace(.routeSelected, detail: "localQuickReply")
            voiceState.latestAssistantText = localReply
            let router = ProviderRouter(preference: providerPreference, speechRateMultiplier: speechRateMultiplier)
            tts = router.ttsProvider()
            await speak(localReply)
            await recordDiagnostic(userText: trimmed, assistantText: localReply, startedAt: startedAt)
            finishTrace()
            return
        }

        if looksLikeUnplannedComputerAction(trimmed) {
            trace(.routeSelected, detail: "modelActionPlan")
            voiceState.latestAssistantText = "正在用 \(providerPreference.title) 解析动作，本地执行..."
            do {
                if let modelPlan = try await requestModelActionPlan(userText: trimmed, observation: observation) {
                    lastComputerUsePlan = modelPlan
                    await performComputerUsePlan(modelPlan, userText: trimmed, startedAt: startedAt, beforeObservation: observation)
                } else {
                    let reply = "我识别到这是电脑操作请求，但模型没有返回可执行 JSON 计划，所以不会假装已经执行。"
                    voiceState.latestAssistantText = reply
                    await recordDiagnostic(userText: trimmed, assistantText: reply, error: "No model action plan", startedAt: startedAt)
                    scheduleConversationRestartIfNeeded()
                }
            } catch {
                let reply = Self.readableError(error, prefix: "动作解析失败")
                voiceState.latestAssistantText = reply
                await recordDiagnostic(userText: trimmed, assistantText: reply, error: error.localizedDescription, startedAt: startedAt)
                scheduleConversationRestartIfNeeded()
            }
            return
        }

        voiceState.latestAssistantText = "正在请求 \(providerPreference.title)..."
        await refreshContext(includeScreenImage: includeScreenContext)
        trace(.routeSelected, detail: providerPreference == .claudeCode ? "claudeCode" : "chat/\(providerPreference.title)")
        let router = ProviderRouter(preference: providerPreference, speechRateMultiplier: speechRateMultiplier)
        do {
            let fullText = try await requestChatText(
                userText: trimmed,
                maxTokens: voiceState.isConversationMode ? 512 : 1024
            )
            if !fullText.isEmpty {
                trace(.ttsStarted)
                tts = router.ttsProvider()
                let trimmedFullText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedFullText.isEmpty {
                    onMessagePair?(trimmed, trimmedFullText)
                }
                await speak(trimmedFullText)
                await recordDiagnostic(userText: trimmed, assistantText: trimmedFullText, startedAt: startedAt)
                finishTrace()
            } else {
                await recordDiagnostic(userText: trimmed, assistantText: voiceState.latestAssistantText, error: "Provider empty response", startedAt: startedAt)
                finishTrace(failed: true)
                scheduleConversationRestartIfNeeded()
            }
        } catch {
            voiceState.latestAssistantText = Self.readableError(error, prefix: "请求失败")
            await recordDiagnostic(userText: trimmed, assistantText: voiceState.latestAssistantText, error: error.localizedDescription, startedAt: startedAt)
            finishTrace(failed: true)
            scheduleConversationRestartIfNeeded()
        }
    }

    private func requestModelActionPlan(userText: String, observation: ComputerUseObservation) async throws -> ComputerUsePlan? {
        let kind = providerKind(for: providerPreference)
        let endpoint = endpoint(for: kind)
        let provider = OpenAICompatibleChatProvider(endpoint: endpoint, apiKey: providerKeys[endpoint.apiKeyEnvironmentVariable])
        chat = provider
        let request = ChatRequest(
            model: endpoint.model,
            messages: [
                ChatMessage(role: "system", content: modelActionPlanner.prompt(userText: userText, observation: observation)),
                ChatMessage(role: "user", content: userText)
            ],
            temperature: 0,
            maxTokens: 450
        )
        let response = try await provider.complete(request)
        providerHealth.removeAll { $0.kind == kind }
        providerHealth.insert(ProviderHealthSnapshot(kind: kind, status: .ok, detail: "动作解析请求成功。"), at: 0)
        return modelActionPlanner.parse(response.text, userText: userText)
    }

    private func requestChatText(userText: String, maxTokens: Int) async throws -> String {
        if providerPreference == .claudeCode {
            guard await claudeCodeBackend.isAvailable else {
                let error = ChatProviderError.transport("Claude Code CLI 未安装。请运行：brew install claude-code")
                return await requestFallbackChatText(
                    after: .appleNative,
                    primaryError: error,
                    userText: userText,
                    maxTokens: maxTokens
                )
            }
            do {
                return try await requestChatTextWithClaudeCode(userText: userText, maxTokens: maxTokens)
            } catch {
                return await requestFallbackChatText(
                    after: .appleNative,
                    primaryError: error,
                    userText: userText,
                    maxTokens: maxTokens
                )
            }
        }

        let primaryKind = providerKind(for: providerPreference)
        do {
            return try await requestChatText(kind: primaryKind, userText: userText, maxTokens: maxTokens)
        } catch {
            return await requestFallbackChatText(
                after: primaryKind,
                primaryError: error,
                userText: userText,
                maxTokens: maxTokens
            )
        }
    }

    private func requestFallbackChatText(
        after primaryKind: ProviderKind,
        primaryError: Error,
        userText: String,
        maxTokens: Int
    ) async -> String {
        providerHealth.removeAll { $0.kind == primaryKind }
        providerHealth.insert(
            ProviderHealthSnapshot(kind: primaryKind, status: .failing, detail: Self.readableError(primaryError, prefix: "Provider 失败")),
            at: 0
        )

        if primaryKind != .localOpenAICompatible {
            let localEndpoint = endpoint(for: .localOpenAICompatible)
            if localEndpoint.baseURL != nil {
                voiceState.latestAssistantText = "主 Provider 不可用，尝试本地 OpenAI-Compatible 端点..."
                do {
                    return try await requestChatText(kind: .localOpenAICompatible, userText: userText, maxTokens: maxTokens)
                } catch {
                    providerHealth.removeAll { $0.kind == .localOpenAICompatible }
                    providerHealth.insert(
                        ProviderHealthSnapshot(kind: .localOpenAICompatible, status: .failing, detail: Self.readableError(error, prefix: "本地端点失败")),
                        at: 0
                    )
                    return await degradedLocalReply(userText: userText, primaryError: primaryError, localError: error)
                }
            }
        }

        return await degradedLocalReply(userText: userText, primaryError: primaryError, localError: nil)
    }

    private func degradedLocalReply(userText: String, primaryError: Error, localError: Error?) async -> String {
        providerHealth.removeAll { $0.kind == .appleNative }
        providerHealth.insert(
            ProviderHealthSnapshot(kind: .appleNative, status: .warning, detail: "已进入本地降级模式。云端或本地模型暂不可用，但本地读屏、控件观察和安全动作仍可继续。"),
            at: 0
        )

        var lines: [String] = [
            "当前模型通道不可用，我已切到本地降级模式。",
            "你的请求：\(userText)",
            "主要失败原因：\(Self.readableError(primaryError, prefix: "Provider"))"
        ]
        if let localError {
            lines.append("本地端点也不可用：\(Self.readableError(localError, prefix: "Local"))")
        }

        if let app = context.app {
            var appLine = "当前前台 App：\(app.appName)"
            if let title = app.windowTitle, !title.isEmpty {
                appLine += "，窗口：\(title)"
            }
            lines.append(appLine)
        }

        if let focused = context.focusedElement {
            let role = focused.role ?? "未知控件"
            let title = focused.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            lines.append(title.isEmpty ? "当前焦点控件：\(role)" : "当前焦点控件：\(role)，\(title)")
        }

        let ocr = context.screen?.recognizedText?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? lastComputerUseObservation?.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let ocr, !ocr.isEmpty {
            lines.append("屏幕 OCR 摘要：\(String(ocr.prefix(600)))")
        } else if let observation = lastComputerUseObservation, !observation.visibleWindows.isEmpty {
            let windows = observation.visibleWindows.prefix(5).map { window in
                let title = window.windowTitle.map { " - \($0)" } ?? ""
                return "\(window.ownerName)\(title)"
            }.joined(separator: "；")
            lines.append("可见窗口：\(windows)")
        }

        lines.append("可继续使用的本地能力：读取屏幕、观察控件、打开/切换 App、点击、输入、粘贴、运行已允许的本地命令。需要大模型推理的部分会在网络或本地模型恢复后继续。")

        let reply = lines.joined(separator: "\n")
        await contextStore.appendExchange(user: userText, assistant: reply)
        await refreshContextCount()
        return reply
    }

    private func requestChatText(kind: ProviderKind, userText: String, maxTokens: Int) async throws -> String {
        let endpoint = endpoint(for: kind)
        let provider = OpenAICompatibleChatProvider(endpoint: endpoint, apiKey: providerKeys[endpoint.apiKeyEnvironmentVariable])
        chat = provider

        var messages: [ChatMessage] = [
            ChatMessage(role: "system", content: ChineseAssistantPrompts.system),
            ChatMessage(role: "system", content: conversationPrompt()),
            ChatMessage(role: "system", content: contextPrompt(for: context, userText: userText)),
        ]
        // Only include last few exchanges for token efficiency
        for entry in await contextStore.recentContext() {
            messages.append(ChatMessage(role: entry.role, content: entry.content))
        }
        messages.append(ChatMessage(role: "user", content: userText))

        let request = ChatRequest(
            model: endpoint.model,
            messages: messages,
            temperature: 0.2,
            maxTokens: maxTokens
        )
        var fullText = ""
        voiceState.latestAssistantText = ""
        if let stream = try await chat?.stream(request) {
            for try await delta in stream {
                fullText += delta
                voiceState.latestAssistantText = fullText
            }
        }
        if fullText.isEmpty {
            let response = try await chat?.complete(request)
            fullText = response?.text ?? ""
            voiceState.latestAssistantText = fullText.isEmpty ? "Provider 没有返回内容。" : fullText
        }
        providerHealth.removeAll { $0.kind == kind }
        providerHealth.insert(ProviderHealthSnapshot(kind: kind, status: .ok, detail: "最近请求成功。"), at: 0)

        // Save to persistent context
        if !fullText.isEmpty, fullText != "Provider 没有返回内容。" {
            await contextStore.appendExchange(user: userText, assistant: fullText)
            await refreshContextCount()
        }

        return fullText
    }

    private func requestChatTextWithClaudeCode(userText: String, maxTokens: Int) async throws -> String {
        var messages: [Message] = [
            Message(role: .system, content: [.text(ChineseAssistantPrompts.system)]),
            Message(role: .system, content: [.text(conversationPrompt())]),
            Message(role: .system, content: [.text(contextPrompt(for: context, userText: userText))]),
        ]
        // Only include last few exchanges for token efficiency
        for entry in await contextStore.recentContext() {
            let role: MessageRole = entry.role == "assistant" ? .assistant : .user
            messages.append(Message(role: role, content: [.text(entry.content)]))
        }
        messages.append(Message(role: .user, content: [.text(userText)]))

        let config = LLMConfiguration(provider: .claudeCodeCLI, model: "claude-code", maxTokens: maxTokens, temperature: 0.2)

        // Inject ANTHROPIC_API_KEY so the claude subprocess can authenticate
        let key = providerKeys["ANTHROPIC_API_KEY"]
            ?? OpenAIAPIKeyStore.load(account: "ANTHROPIC_API_KEY")
            ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        if let key, !key.isEmpty {
            await claudeCodeBackend.setEnvironmentVariable(key: "ANTHROPIC_API_KEY", value: key)
        }

        var fullText = ""
        voiceState.latestAssistantText = ""

        let stream = try await claudeCodeBackend.chatStream(messages: messages, config: config, tools: nil, delegate: nil)
        var firstToken = true
        for await delta in stream {
            if firstToken { trace(.modelFirstToken); firstToken = false }
            fullText += delta
            voiceState.latestAssistantText = fullText
        }

        if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fullText = "Claude Code 已处理。"
            voiceState.latestAssistantText = fullText
        }

        providerHealth.removeAll { $0.kind == .appleNative }
        providerHealth.insert(ProviderHealthSnapshot(kind: .appleNative, status: .ok, detail: "Claude Code 最近请求成功。"), at: 0)

        // Save to persistent context
        await contextStore.appendExchange(user: userText, assistant: fullText)
        await refreshContextCount()

        return fullText
    }

    private func performLocalAction(_ action: MacAction, userText: String, startedAt: Date) async {
        switch actionPolicy.evaluate(action, context: context) {
        case .allow:
            trace(.toolStarted, detail: action.humanPreview)
            let result = await actionExecutor.execute(action)
            lastActionResult = result
            let reply = result.message
            voiceState.latestAssistantText = reply
            trace(.ttsStarted)
            let router = ProviderRouter(preference: providerPreference, speechRateMultiplier: speechRateMultiplier)
            tts = router.ttsProvider()
            await speak(reply)
            finishTrace(failed: !result.success)
            await recordDiagnostic(
                userText: userText,
                assistantText: reply,
                parsedAction: action.humanPreview,
                actionResult: result.message,
                error: result.success ? nil : result.message,
                startedAt: startedAt
            )
        case .requireConfirmation:
            pendingAction = action
            voiceState.latestAssistantText = "需要你确认：\(action.humanPreview)"
            finishTrace(failed: true)
            await recordDiagnostic(userText: userText, assistantText: voiceState.latestAssistantText, parsedAction: action.humanPreview, startedAt: startedAt)
            scheduleConversationRestartIfNeeded()
        case .deny(let reason), .developerModeOnly(let reason):
            lastActionResult = ActionResult(actionID: action.id, success: false, message: reason)
            voiceState.latestAssistantText = reason
            finishTrace(failed: true)
            await recordDiagnostic(userText: userText, assistantText: reason, parsedAction: action.humanPreview, error: reason, startedAt: startedAt)
            scheduleConversationRestartIfNeeded()
        }
    }

    private func performComputerUsePlan(
        _ plan: ComputerUsePlan,
        userText: String,
        startedAt: Date,
        beforeObservation: ComputerUseObservation
    ) async {
        if !plan.steps.isEmpty {
            await performComputerUseSteps(plan, userText: userText, startedAt: startedAt, beforeObservation: beforeObservation)
            return
        }
        guard let action = plan.action else { return }
        switch actionPolicy.evaluate(action, context: context) {
        case .allow:
            trace(.toolStarted, detail: action.humanPreview)
            let cuTrace = await computerUseCoordinator.execute(action)
            computerUseCoordinatorStatus = "后端: \(cuTrace.backend.rawValue) | 验证: \(cuTrace.verification.passed ? "通过" : "未通过")\(cuTrace.recovered ? " | 已从\(cuTrace.recoveryFrom?.rawValue ?? "")恢复" : "")"
            let axr = cuTrace.result
            let result = ActionResult(actionID: action.id, success: axr.success, message: axr.message)
            let after = await computerUseObserver.observe(includeOCR: false, skipOwnWindows: true)
            lastComputerUseObservation = after
            lastActionResult = result
            let verified = cuTrace.verification.passed
            trace(.verifyDone, detail: verified ? "pass" : "fail:\(cuTrace.verification.note)")
            let reply = axr.success ? "\(axr.message) \(plan.reason)" : axr.message
            lastComputerUseResult = ComputerUseRunOutcome(
                plan: plan,
                actionResult: result,
                beforeObservationID: beforeObservation.id,
                afterObservationID: after.id,
                message: reply
            )
            voiceState.latestAssistantText = reply
            if shouldSpeakAfterAction(action) {
                trace(.ttsStarted)
                let router = ProviderRouter(preference: providerPreference, speechRateMultiplier: speechRateMultiplier)
                tts = router.ttsProvider()
                await speak(reply)
            } else {
                scheduleConversationRestartIfNeeded()
            }
            await recordDiagnostic(
                userText: userText,
                assistantText: reply,
                parsedAction: action.humanPreview,
                actionResult: result.message,
                error: result.success ? nil : result.message,
                startedAt: startedAt
            )
            finishTrace(failed: !result.success)
        case .requireConfirmation:
            pendingAction = action
            lastComputerUseResult = ComputerUseRunOutcome(
                plan: plan,
                beforeObservationID: beforeObservation.id,
                message: "需要确认：\(action.humanPreview)"
            )
            voiceState.latestAssistantText = "需要你确认：\(action.humanPreview)"
            await recordDiagnostic(userText: userText, assistantText: voiceState.latestAssistantText, parsedAction: action.humanPreview, startedAt: startedAt)
            finishTrace(failed: true)
            scheduleConversationRestartIfNeeded()
        case .deny(let reason), .developerModeOnly(let reason):
            lastActionResult = ActionResult(actionID: action.id, success: false, message: reason)
            lastComputerUseResult = ComputerUseRunOutcome(
                plan: plan,
                beforeObservationID: beforeObservation.id,
                message: reason
            )
            voiceState.latestAssistantText = reason
            await recordDiagnostic(userText: userText, assistantText: reason, parsedAction: action.humanPreview, error: reason, startedAt: startedAt)
            finishTrace(failed: true)
            scheduleConversationRestartIfNeeded()
        }
    }

    private func performComputerUseSteps(
        _ plan: ComputerUsePlan,
        userText: String,
        startedAt: Date,
        beforeObservation: ComputerUseObservation
    ) async {
        let limitedSteps = Array(plan.steps.prefix(12))
        var stepResults: [ComputerUseStepOutcome] = []
        var latestObservation = beforeObservation
        var failedMessage: String?

        for step in limitedSteps {
            switch actionPolicy.evaluate(step.action, context: context) {
            case .allow:
                trace(.toolStarted, detail: step.action.humanPreview)
                let cuTrace = await computerUseCoordinator.execute(step.action)
                computerUseCoordinatorStatus = "后端: \(cuTrace.backend.rawValue) | 验证: \(cuTrace.verification.passed ? "通过" : "未通过")\(cuTrace.recovered ? " | 已从\(cuTrace.recoveryFrom?.rawValue ?? "")恢复" : "")"
                let axr = cuTrace.result
                let result = ActionResult(actionID: step.action.id, success: axr.success, message: axr.message)
                latestObservation = await computerUseObserver.observe(includeOCR: false, skipOwnWindows: true)
                lastComputerUseObservation = latestObservation
                let verified = cuTrace.verification.passed
                trace(.verifyDone, detail: verified ? "pass" : "fail:\(step.expectedState) - \(cuTrace.verification.note)")
                let note = verified ? "已达到：\(step.expectedState)" : "未确认达到：\(step.expectedState)（\(cuTrace.verification.note)）"
                stepResults.append(
                    ComputerUseStepOutcome(
                        step: step,
                        actionResult: result,
                        observationID: latestObservation.id,
                        verified: verified,
                        note: note
                    )
                )
                if !result.success || !verified {
                    failedMessage = result.success ? note : result.message
                    break
                }
            case .requireConfirmation(let reason):
                pendingAction = step.action
                failedMessage = reason
                stepResults.append(
                    ComputerUseStepOutcome(
                        step: step,
                        actionResult: ActionResult(actionID: step.action.id, success: false, message: reason),
                        observationID: latestObservation.id,
                        verified: false,
                        note: "等待用户确认"
                    )
                )
                break
            case .deny(let reason), .developerModeOnly(let reason):
                failedMessage = reason
                stepResults.append(
                    ComputerUseStepOutcome(
                        step: step,
                        actionResult: ActionResult(actionID: step.action.id, success: false, message: reason),
                        observationID: latestObservation.id,
                        verified: false,
                        note: "策略阻止"
                    )
                )
                break
            }
        }

        let completedCount = stepResults.filter(\.verified).count
        let reply: String
        if let failedMessage {
            reply = "连续操作停在第 \(stepResults.count) 步：\(failedMessage)"
        } else if plan.intent == .composeMessage {
            reply = "微信草稿已准备好。发送前需要你确认，我不会自动按发送。"
        } else {
            reply = "连续操作完成：\(completedCount)/\(limitedSteps.count) 步。"
        }
        let result = ActionResult(
            actionID: limitedSteps.last?.action.id ?? UUID(),
            success: failedMessage == nil,
            message: reply
        )
        lastActionResult = result
        lastComputerUseResult = ComputerUseRunOutcome(
            plan: plan,
            actionResult: result,
            stepResults: stepResults,
            beforeObservationID: beforeObservation.id,
            afterObservationID: latestObservation.id,
            message: reply
        )
        voiceState.latestAssistantText = reply
        if plan.intent == .composeMessage {
            scheduleConversationRestartIfNeeded()
        } else {
            trace(.ttsStarted)
            let router = ProviderRouter(preference: providerPreference, speechRateMultiplier: speechRateMultiplier)
            tts = router.ttsProvider()
            await speak(reply)
        }
        finishTrace(failed: failedMessage != nil)
        await recordDiagnostic(
            userText: userText,
            assistantText: reply,
            parsedAction: plan.steps.map { $0.action.humanPreview }.joined(separator: " -> "),
            actionResult: reply,
            error: failedMessage,
            startedAt: startedAt
        )
    }


    public func saveProviderKey(kind: ProviderKind, key: String) {
        let account = ProviderEndpoint.defaultEnvironmentVariable(for: kind)
        guard !account.isEmpty else { return }
        providerKeys[account] = key
        do {
            try OpenAIAPIKeyStore.save(key, account: account)
            voiceState.latestAssistantText = "已保存 \(kind.title) API Key。"
        } catch {
            voiceState.latestAssistantText = "保存 API Key 失败：\(error.localizedDescription)"
        }
    }

    public func updateProviderModel(kind: ProviderKind, model: String) {
        providerModels[kind] = model
        UserDefaults.standard.set(model, forKey: "provider.model.\(kind.rawValue)")
    }

    public func updateProviderBaseURL(kind: ProviderKind, baseURL: String) {
        providerBaseURLs[kind] = baseURL
        UserDefaults.standard.set(baseURL, forKey: "provider.baseURL.\(kind.rawValue)")
    }

    func providerKind(for preference: ProviderPreference) -> ProviderKind {
        switch preference {
        case .claudeCode: .deepSeek  // placeholder, never used
        case .cloudRealtime: .openAICompatibleChat
        case .deepSeek: .deepSeek
        case .qwen: .qwen
        case .moonshot: .moonshot
        case .localEndpoint, .localFirst: .localOpenAICompatible
        case .appleNative: .localOpenAICompatible
        }
    }

    func endpoint(for kind: ProviderKind) -> ProviderEndpoint {
        let configuredURL = providerBaseURLs[kind].flatMap(URL.init(string:))
        return ProviderEndpoint(
            kind: kind,
            baseURL: configuredURL,
            model: providerModels[kind] ?? kind.defaultModel
        )
    }

    private func loadProviderSettings() {
        let savedRate = UserDefaults.standard.double(forKey: "speechRateMultiplier")
        if savedRate > 0 {
            speechRateMultiplier = savedRate
        }
        if let rawHotkey = UserDefaults.standard.string(forKey: "hotkeyPreset"),
           let preset = HotkeyPreset(rawValue: rawHotkey) {
            hotkeyPreset = HotkeyPreset.selectableCases.contains(preset) ? preset : .controlOptionSpace
        }
        if let rawVoiceMode = UserDefaults.standard.string(forKey: "voiceSubmitMode"),
           let mode = VoiceSubmitMode(rawValue: rawVoiceMode) {
            voiceSubmitMode = mode
        }
        let savedSilence = UserDefaults.standard.double(forKey: "autoSubmitSilenceSeconds")
        if savedSilence > 0 {
            autoSubmitSilenceSeconds = savedSilence
        }
        if let raw = UserDefaults.standard.string(forKey: "providerPreference"),
           let preference = ProviderPreference(rawValue: raw),
           preference.isImplemented {
            providerPreference = preference
        }
        for kind in ProviderKind.allCases {
            if let model = UserDefaults.standard.string(forKey: "provider.model.\(kind.rawValue)") {
                providerModels[kind] = model
            }
            if let baseURL = UserDefaults.standard.string(forKey: "provider.baseURL.\(kind.rawValue)") {
                providerBaseURLs[kind] = baseURL
            }
        }
        Task.detached { [weak self] in
            for kind in ProviderKind.allCases {
                let account = ProviderEndpoint.defaultEnvironmentVariable(for: kind)
                guard !account.isEmpty, let key = OpenAIAPIKeyStore.load(account: account) else { continue }
                await MainActor.run { [weak self] in
                    self?.providerKeys[account] = key
                }
            }
        }
    }

    public func propose(_ action: MacAction) {
        switch actionPolicy.evaluate(action, context: context) {
        case .allow:
            Task { lastActionResult = await actionExecutor.execute(action) }
        case .requireConfirmation:
            pendingAction = action
        case .deny(let reason), .developerModeOnly(let reason):
            lastActionResult = ActionResult(actionID: action.id, success: false, message: reason)
        }
    }

    public func confirmPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        Task { lastActionResult = await actionExecutor.execute(action) }
    }

    public func cancelPendingAction() {
        pendingAction = nil
    }

    private func consumeRealtimeEvents(_ events: AsyncStream<RealtimeEvent>) async {
        for await event in events {
            switch event {
            case .sessionStarted:
                break
            case .transcriptDelta(let text):
                voiceState.latestTranscript = text
            case .assistantTextDelta(let text):
                voiceState.latestAssistantText += text
            case .assistantAudioDelta:
                break
            case .toolCallRequested(let action):
                propose(action)
            case .interrupted:
                await tts?.stop()
            case .completed:
                let text = voiceState.latestAssistantText
                await speak(text)
            case .failed(let message):
                voiceState.latestAssistantText = message
            }
        }
    }
}
