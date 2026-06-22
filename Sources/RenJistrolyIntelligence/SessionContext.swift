import AppKit
import Foundation
import os
import RenJistrolyModels
import RenJistrolySystemBridge
import RenJistrolyCapability

// MARK: - Session Context Management

extension AssistantSessionController {

    func startDialogWatcher() {
        dialogWatchTask = Task { [weak self] in
            guard let self else { return }
            for await event in await self.axNotificationObserver.events {
                guard !Task.isCancelled else { break }
                let isDialog = event.name == kAXSheetCreatedNotification ||
                    event.name == kAXDrawerCreatedNotification ||
                    event.name == kAXFocusedWindowChangedNotification
                if isDialog {
                    let state = ActiveDialogState(
                        appName: event.appName ?? "unknown",
                        title: event.name,
                        role: event.name,
                        detectedAt: event.timestamp
                    )
                    await MainActor.run {
                        self.activeDialogs.insert(state, at: 0)
                        if self.activeDialogs.count > self.maxActiveDialogs {
                            self.activeDialogs = Array(self.activeDialogs.prefix(self.maxActiveDialogs))
                        }
                    }
                }
            }
        }
    }

    public func clearContext() {
        Task {
            await contextStore.clear()
            await refreshContextCount()
        }
    }

    /// Mutate voiceState with struct replacement so didSet fires and appState syncs.
    func updateVoiceState(_ mutate: (inout VoiceSessionState) -> Void) {
        var st = voiceState
        mutate(&st)
        voiceState = st
    }

    func syncAppStateFromVoiceState() {
        guard let appState else { return }
        if voiceState.isListening {
            appState.voiceState = .listening
        } else if voiceState.isSpeaking {
            appState.voiceState = .speaking
        } else if voiceState.isThinking {
            appState.voiceState = .processing
        } else {
            appState.voiceState = .idle
        }
    }

    func syncActiveProvider() {
        let provider: LLMProvider = switch providerPreference {
        case .claudeCode: .claudeCodeCLI
        case .deepSeek: .deepseek
        case .qwen: .custom
        case .moonshot: .custom
        case .localEndpoint, .localFirst: .localMLX
        case .appleNative: .custom
        case .cloudRealtime: .anthropic
        }
        guard let appState else { return }
        if appState.activeProvider != provider {
            appState.activeProvider = provider
        }
    }

    func refreshContextCount() async {
        contextExchangeCount = await contextStore.exchangeCount
    }

    // MARK: - Permission Management

    public func refreshPermissions() {
        Task {
            permissions = await permissionCenter.checkAll()
            await MainActor.run {
                syncAppStateFromPermissions(permissions)
            }
            await refreshFullAccessCapabilities()
        }
    }

    public func request(_ kind: PermissionKind) {
        Task {
            _ = await permissionCenter.request(kind)
            permissions = await permissionCenter.checkAll()
            await MainActor.run {
                syncAppStateFromPermissions(permissions)
            }
            await refreshFullAccessCapabilities()
        }
    }

    public func requestScreenRecordingForReading() {
        Task {
            _ = await permissionCenter.request(.screenRecording)
            await MainActor.run {
                permissionCenter.openSettings(for: .screenRecording)
            }
            permissions = await permissionCenter.checkAll()
            await MainActor.run {
                syncAppStateFromPermissions(permissions)
            }
            await refreshFullAccessCapabilities()
        }
    }

    public func readCurrentScreen() async {
        voiceState.latestAssistantText = "正在读取屏幕..."
        _ = await permissionCenter.request(.screenRecording)
        permissions = await permissionCenter.checkAll()
        await MainActor.run {
            syncAppStateFromPermissions(permissions)
        }
        await refreshContext(includeScreenImage: true)
        forceScreenContextUntil = Date().addingTimeInterval(120)
        voiceState.latestAssistantText = screenReadingSummary()
        await refreshFullAccessCapabilities()
    }

    public func requestAllPermissions() {
        Task {
            for kind in PermissionKind.allCases {
                _ = await permissionCenter.request(kind)
            }
            permissions = await permissionCenter.checkAll()
            await MainActor.run {
                syncAppStateFromPermissions(permissions)
            }
        }
    }

    public func openSettings(for kind: PermissionKind) {
        Task { @MainActor in
            permissionCenter.openSettings(for: kind)
        }
    }

    public func openNativeAccessibilitySetting(_ kind: NativeAccessibilityFeatureKind) {
        guard let url = URL(string: kind.settingURLString) else { return }
        NSWorkspace.shared.open(url)
        foundationMessage = "已打开系统设置：\(kind.title)"
    }

    // MARK: - Foundation State

    public func refreshFoundationState() async {
        recentDiagnostics = await diagnosticsCenter.recent()
        recentFeedback = await feedbackCenter.recent()
        userMemories = await memoryStore.all()
        upgradePlans = await upgradeRecoveryCenter.latestPlans()
        terminalTasks = await terminalTaskStore.all()
        await refreshFullAccessCapabilities()
        let hasBaseBackup = FileManager.default.fileExists(atPath: "\(NSHomeDirectory())/Applications/RenJistroly Base.app")
        foundationLayers = await foundationHealthCenter.snapshots(
            permissions: permissions,
            fullAccessCapabilities: fullAccessCapabilities,
            provider: providerPreference.title,
            hasBaseBackup: hasBaseBackup,
            lastDiagnostic: recentDiagnostics.first,
            isConversationMode: voiceState.isConversationMode,
            evidence: foundationEvidence()
        )
        scenarioAuditReport = scenarioAuditEngine.audit(
            permissions: permissions,
            fullAccessCapabilities: fullAccessCapabilities,
            evidence: foundationEvidence(),
            diagnostics: recentDiagnostics,
            terminalTasks: terminalTasks,
            providerHealth: providerHealth
        )
    }

    private func foundationEvidence() -> FoundationCapabilityEvidence {
        let runningOrDone = terminalTasks.contains { task in
            task.status == .running || task.status == .succeeded || task.status == .failed
        }
        let axTargets = lastComputerUseObservation?.targets.filter { $0.kind == .accessibilityElement }.count ?? 0
        let totalTargets = lastComputerUseObservation?.targets.count ?? 0
        let verified = lastComputerUseResult?.stepResults.contains(where: { $0.verified }) == true
            || lastActionResult?.success == true && lastComputerUsePlan?.action?.kind == .openApplication
        return FoundationCapabilityEvidence(
            terminalTaskCount: terminalTasks.count,
            hasRunningOrCompletedTerminalTask: runningOrDone,
            lastObservationTargetCount: totalTargets,
            lastObservationAccessibilityTargetCount: axTargets,
            lastActionWasVerified: verified,
            memoryCount: userMemories.count,
            providerHealthCount: providerHealth.count
        )
    }

    private func refreshFullAccessCapabilities() async {
        let kind = providerKind(for: providerPreference)
        let endpoint = endpoint(for: kind)
        let hasKey = endpoint.apiKeyEnvironmentVariable.isEmpty
            || providerKeys[endpoint.apiKeyEnvironmentVariable]?.isEmpty == false
            || OpenAIAPIKeyStore.load(account: endpoint.apiKeyEnvironmentVariable)?.isEmpty == false
            || kind == .localOpenAICompatible
        fullAccessCapabilities = await permissionCenter.fullAccessCapabilities(
            permissions: permissions,
            hasModelCredential: hasKey,
            providerName: providerPreference.title,
            installedAppPath: installedAppPath
        )
    }

    public func createBaseVersionBackup() {
        Task {
            foundationMessage = await upgradeRecoveryCenter.ensureBaseBackup()
            await refreshFoundationState()
        }
    }

    public func restoreBaseVersion() {
        Task {
            foundationMessage = await upgradeRecoveryCenter.restoreBaseVersion()
            await refreshFoundationState()
        }
    }

    public func createSelfOptimizationPlan(reason: String? = nil) {
        Task {
            let plan = await upgradeRecoveryCenter.createPlan(reason: reason ?? lastUserText)
            foundationMessage = "已生成升级计划：\(plan.title)"
            await refreshFoundationState()
        }
    }

    public func reportCurrentProblem(_ complaint: String? = nil) {
        Task {
            let text = complaint.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 } ?? lastUserText
            let diagnostic = recentDiagnostics.first
            let report = await feedbackCenter.createReport(complaint: text, diagnosticID: diagnostic?.id)
            foundationMessage = "已记录反馈：\(report.category.title)。\(report.proposedFix)"
            _ = await upgradeRecoveryCenter.createPlan(reason: "用户反馈：\(text)")
            await refreshFoundationState()
        }
    }

    // MARK: - Context Refresh

    public func refreshContext(includeScreenImage: Bool) async {
        async let app = accessibility.readFrontmostApp()
        async let runningApps = accessibility.readRunningApps()
        async let element = accessibility.readFocusedElement()
        async let screen = screenContext.captureCurrentScreen(includeImageData: includeScreenImage)
        var ctx = await AssistantContext(app: app, runningApps: runningApps, focusedElement: element, screen: screen)
        // Attach cursor position
        let cursorPos = CursorController.currentPosition
        if cursorPos != .zero {
            ctx.screen?.cursorPosition = cursorPos
        }
        if includeScreenImage, let screen = ctx.screen {
            let didFail = screen.displayDescription.localizedCaseInsensitiveContains("Screen OCR failed")
                || screen.displayDescription.localizedCaseInsensitiveContains("permission")
            appState?.isPermissionGranted.screenRecording = !didFail
        }
        // Attach recently detected dialogs (fresh within last 3 seconds)
        let now = Date()
        ctx.activeDialogs = activeDialogs.filter { now.timeIntervalSince($0.detectedAt) < 3.0 }
        context = ctx
    }

    // MARK: - Error Handling

    /// Convert raw system errors into user-facing Chinese messages.
    static func readableError(_ error: Error, prefix: String = "错误") -> String {
        let desc = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        if desc.contains("connect to the server") || desc.contains("kLSRErrorDomain") || desc.contains("Could not connect") {
            return "\(prefix)：语音识别服务不可用，请检查「系统设置 > 隐私与安全性 > 语音识别」已开启。"
        }
        if desc.contains("No speech detected") || desc.contains("no speech") {
            return "\(prefix)：未检测到语音，请靠近麦克风说话。"
        }
        if desc.contains("cancelled") {
            return "已取消。"
        }
        return "\(prefix)：\(desc)"
    }

    // MARK: - Speech Validation

    func isValidSpeechContent(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }
        let significant = trimmed.filter { $0.isLetter || $0.isNumber }
        guard significant.count >= 2 else { return false }
        let chars = Array(significant)
        if Set(chars).count == 1 && chars.count > 3 { return false }
        var run = 1
        for i in 1..<chars.count {
            if chars[i] == chars[i-1] { run += 1 } else { run = 1 }
            if run > 4 { return false }
        }
        if chars.count > 3 {
            let freq = Dictionary(chars.map { ($0, 1) }, uniquingKeysWith: +)
            if let maxCount = freq.values.max(),
               Double(maxCount) / Double(chars.count) > 0.7 {
                return false
            }
        }
        return true
    }

    // MARK: - Verification & Matching

    func verify(step: ComputerUseStep, result: ActionResult, observation: ComputerUseObservation) -> Bool {
        guard result.success else { return false }
        switch step.action.kind {
        case .openApplication:
            guard let name = step.action.payload["name"] else { return result.success }
            return observation.frontmostApp.map { app in
                matchesApp(name, app.appName) || matchesApp(name, app.bundleIdentifier ?? "")
            } ?? false
        case .insertText, .setFocusedText, .setElementText:
            guard let text = step.action.payload["text"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty
            else { return result.success }
            return observationContainsText(text, observation: observation)
        case .clickElement:
            return result.success
        case .focusWeChatMessageInput:
            let frontmostIsWeChat = observation.frontmostApp.map { app in
                matchesApp("微信", app.appName) || matchesApp("微信", app.bundleIdentifier ?? "")
            } ?? false
            let hasEditable = observation.targets.contains { target in
                target.kind == .accessibilityElement
                    && (target.role?.localizedCaseInsensitiveContains("Text") == true
                        || target.role == "AXTextArea"
                        || target.role == "AXTextField")
            }
            return frontmostIsWeChat && hasEditable
        case .pressShortcut:
            return result.success
        default:
            return true
        }
    }

    private func observationContainsText(_ text: String, observation: ComputerUseObservation) -> Bool {
        let needle = normalizedContent(text)
        guard !needle.isEmpty else { return true }
        let haystacks = [
            observation.focusedElement?.value,
            observation.focusedElement?.selectedText,
            observation.ocrText
        ] + observation.targets.flatMap { target in
            [target.label, target.valuePreview]
        }
        return haystacks.compactMap { $0 }.contains { candidate in
            normalizedContent(candidate).contains(needle)
        }
    }

    private func normalizedContent(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchesApp(_ query: String, _ candidate: String) -> Bool {
        let q = query.lowercased().replacingOccurrences(of: " ", with: "")
        let c = candidate.lowercased().replacingOccurrences(of: " ", with: "")
        if q == "微信", c.contains("wechat") || c.contains("xinwechat") || candidate == "微信" {
            return true
        }
        return !q.isEmpty && !c.isEmpty && (q == c || q.contains(c) || c.contains(q))
    }

    func shouldSpeakAfterAction(_ action: MacAction) -> Bool {
        switch action.kind {
        case .openApplication:
            false
        default:
            true
        }
    }

    // MARK: - Text Classification

    func isComplaint(_ text: String) -> Bool {
        let keywords = ["不行", "没反应", "失败", "打不开", "无法", "太慢", "不好用", "错误", "有问题", "不对", "越修越烂", "烂"]
        return keywords.contains { text.contains($0) }
    }

    func looksLikeComputerUse(_ text: String) -> Bool {
        let keywords = ["打开", "切换", "切到", "回到", "进入", "点击", "点一下", "输入", "粘贴", "复制", "回车", "窗口", "程序", "app", "应用", "微信", "终端"]
        return keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    func looksLikeUnplannedComputerAction(_ text: String) -> Bool {
        let actionKeywords = ["打开", "切换", "切到", "回到", "进入", "点击", "点一下", "输入", "粘贴", "复制", "回车", "关闭", "最小化", "发送", "发给"]
        return actionKeywords.contains { text.localizedCaseInsensitiveContains($0) }
    }

    func looksLikeTerminalCommand(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespaces)
        let commands = ["cd ", "ls ", "cat ", "grep ", "find ", "git ", "curl ", "npm ", "brew ", "swift ", "echo ", "rm ", "mkdir ", "touch ", "cp ", "mv ", "ps ", "kill ", "sudo ", "open ", "python", "node ", "go ", "cargo ", "pip ", "docker ", "make ", "./", "chmod ", "head ", "tail ", "source ", "export ", "which "]
        return commands.contains { lower.hasPrefix($0) }
    }

    // MARK: - Diagnostics

    func recordDiagnostic(
        userText: String,
        assistantText: String,
        parsedAction: String? = nil,
        actionResult: String? = nil,
        error: String? = nil,
        startedAt: Date
    ) async {
        let snapshot = makeDiagnostic(
            userText: userText,
            assistantText: assistantText,
            parsedAction: parsedAction,
            actionResult: actionResult,
            error: error,
            startedAt: startedAt
        )
        await diagnosticsCenter.record(snapshot)
        await refreshFoundationState()
    }

    func makeDiagnostic(
        userText: String,
        assistantText: String,
        parsedAction: String?,
        actionResult: String? = nil,
        error: String?,
        startedAt: Date
    ) -> AssistantDiagnosticSnapshot {
        AssistantDiagnosticSnapshot(
            userText: userText,
            assistantText: assistantText,
            provider: providerPreference.title,
            frontmostApp: context.app?.appName,
            windowTitle: context.app?.windowTitle,
            focusedRole: context.focusedElement?.role,
            screenSummary: context.screen?.displayDescription,
            parsedAction: parsedAction,
            actionResult: actionResult ?? lastActionResult?.message,
            permissions: Dictionary(uniqueKeysWithValues: permissions.map { ($0.kind.title, $0.status.label) }),
            error: error,
            latencyMilliseconds: Int(Date().timeIntervalSince(startedAt) * 1000)
        )
    }

    // MARK: - Built-in Commands

    func handleBuiltInCommand(_ text: String) -> Bool {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower == "开启转发" || lower == "打开转发" || lower == "开启 gate" || lower == "enable gate" {
            gateEnabled = false
            voiceState.latestAssistantText = "Gate 是实验转发链路，不能通过普通对话命令开启。请在实验设置中显式启用；日常请求会走本地/Provider 安全链路。"
            return true
        }
        if lower == "关闭转发" || lower == "停止转发" || lower == "关闭 gate" || lower == "disable gate" {
            gateEnabled = false
            voiceState.latestAssistantText = "Gate 转发已关闭，恢复本地处理。"
            return true
        }
        if lower == "停止朗读" || lower == "别说了" || lower == "闭嘴" || lower == "stop" {
            Task { await tts?.stop() }
            voiceState.isSpeaking = false
            voiceState.latestAssistantText = "已停止朗读。"
            return true
        }
        return false
    }

    // MARK: - Conversation Restart

    func scheduleConversationRestartIfNeeded() {
        guard voiceState.isConversationMode else { return }
        conversationRestartTask?.cancel()
        conversationRestartTask = Task { [weak self] in
            for _ in 0..<5 {
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard let self else { return }
                let ready = await MainActor.run {
                    guard self.voiceState.isConversationMode else { return false }
                    guard !self.voiceState.isListening, !self.voiceState.isSpeaking, !self.voiceState.isThinking else { return false }
                    return true
                }
                if ready {
                    await MainActor.run { self.startListening(clearAssistantText: false) }
                    return
                }
            }
        }
    }

    // MARK: - Screen Context Helpers

    private func asksAboutScreen(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let keywords = [
            "屏幕", "当前", "界面", "窗口", "这个页面", "上面", "看到", "看见", "读一下", "解释一下", "截图", "画面",
            "看看", "帮我看", "你看", "能不能看到", "能看到", "可以看到", "看这个", "kan", "kankan"
        ]
        return keywords.contains { normalized.contains($0) }
    }

    func shouldIncludeScreenContext(for userText: String) -> Bool {
        if asksAboutScreen(userText) {
            return true
        }

        if let until = forceScreenContextUntil {
            if Date() <= until {
                return true
            }
            forceScreenContextUntil = nil
        }

        let rememberedScreenText = context.screen?.recognizedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !rememberedScreenText.isEmpty
    }

    private func screenReadingSummary() -> String {
        guard let screen = context.screen else {
            return "还没有读到屏幕上下文。"
        }

        var lines: [String] = ["已读取当前屏幕。"]
        if let app = context.app {
            lines.append("前台 App：\(app.appName)")
            if let title = app.windowTitle, !title.isEmpty {
                lines.append("当前窗口：\(title)")
            }
        }

        let ocrText = screen.recognizedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !ocrText.isEmpty {
            lines.append("\nOCR 文字：")
            lines.append(String(ocrText.prefix(1800)))
            return lines.joined(separator: "\n")
        }

        if !screen.visibleWindows.isEmpty {
            lines.append("\n可见窗口：")
            for window in screen.visibleWindows.prefix(8) {
                let title = window.windowTitle.map { " - \($0)" } ?? ""
                lines.append("- \(window.ownerName)\(title)")
            }
        }

        if screen.displayDescription.localizedCaseInsensitiveContains("permission") ||
            screen.displayDescription.contains("未授权") ||
            screen.displayDescription.localizedCaseInsensitiveContains("not granted") {
            lines.append("\n没有拿到屏幕录制权限。请在系统设置 > 隐私与安全性 > 屏幕录制里启用 RenJistroly，授权后重启 App。")
        } else {
            lines.append("\n没有识别到可读文字，但已有可见窗口和焦点控件信息可供回答。")
        }
        return lines.joined(separator: "\n")
    }
}
