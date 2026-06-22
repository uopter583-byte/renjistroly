import AppKit
import Foundation
import OSLog
import SwiftUI
import RenJistrolyModels
import RenJistrolyUI
import RenJistrolyConversation
import RenJistrolyIntelligence
import RenJistrolySystemBridge
import RenJistrolyEnterprise

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var floatingPanel: FloatingPanelWindow?
    private var settingsWindow: NSWindow?
    private var isPushToTalkActive = false
    @Published var appState = AppState()
    var engine: ConversationEngine?
    weak var assistantController: AssistantSessionController?
    private var engineForEnv: ConversationEngine { engine ?? ConversationEngine.shared }
    let updateManager = UpdateManager()
    let eventBus = AgentEventBus.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.installCrashHandler()
        checkCrashHistory()
        if isDuplicateInstance() {
            Task { await eventBus.publish(.system(.duplicateInstanceDetected)) }
            let alert = NSAlert()
            alert.messageText = "RenJistroly 已在运行"
            alert.informativeText = "检测到已有 RenJistroly 实例在运行。多个实例会导致 Gate 文件冲突。是否退出此实例？"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "退出")
            alert.addButton(withTitle: "继续运行")
            if alert.runModal() == .alertFirstButtonReturn {
                NSApplication.shared.terminate(nil)
                return
            }
        }
        preventAppNap()
        setupFloatingPanel()
        HotkeyManager.shared.registerGlobalHotkey()
        checkPermissions()
        observeSleepWake()
        _ = AssistantSessionController.shared
        HealthMonitor.shared.startPeriodicChecks()

        // Listen for external show-panel trigger (for automation/testing)
        let panelNC = DistributedNotificationCenter.default()
        panelNC.addObserver(forName: NSNotification.Name("com.renjistroly.showPanel"),
                            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showFloatingPanel()
            }
        }
        _ = panelNC // Keep reference alive
    }

    private func isDuplicateInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        return !others.isEmpty
    }

    // MARK: - Crash Recovery

    private static let crashFlagPath = NSHomeDirectory() + "/.renjistroly_crash_flag"
    private static let crashHistoryPath = NSHomeDirectory() + "/Library/Logs/RenJistroly/crash_history.json"

    static func installCrashHandler() {
        let fm = FileManager.default

        // Detect previous crash via leftover flag file
        if fm.fileExists(atPath: crashFlagPath) {
            os_log(.fault, "[RenJistroly] 检测到上次非正常退出")
            Task { await AgentEventBus.shared.publish(.system(.errorOccurred(domain: "crash", message: "上次异常退出", recoverable: true))) }

            // Record crash timestamp to history
            Self.logCrashToHistory()
        }

        // Set flag — cleared by atexit on normal exit; leftover means crash
        fm.createFile(atPath: crashFlagPath, contents: Data())
        atexit(clearCrashFlag)
    }

    private static func logCrashToHistory() {
        let fm = FileManager.default
        let logDir = (crashHistoryPath as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: logDir, withIntermediateDirectories: true)

        var entries: [CrashEntry] = []
        if let data = try? Data(contentsOf: URL(fileURLWithPath: crashHistoryPath)),
           let decoded = try? JSONDecoder().decode([CrashEntry].self, from: data) {
            entries = decoded
        }

        // Prune entries older than 5 minutes
        let cutoff = Date().addingTimeInterval(-300)
        entries = entries.filter { $0.timestamp > cutoff }

        // Add current crash
        entries.append(CrashEntry(timestamp: Date()))

        if let encoded = try? JSONEncoder().encode(entries) {
            try? encoded.write(to: URL(fileURLWithPath: crashHistoryPath), options: .atomic)
        }
    }

    private func checkCrashHistory() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: Self.crashHistoryPath)),
              let entries = try? JSONDecoder().decode([CrashEntry].self, from: data),
              entries.count >= 3 else { return }

        // Check if all entries are within 30 seconds of each other
        let sorted = entries.sorted { $0.timestamp < $1.timestamp }
        let windows = sorted.slidingWindows(of: 3)
        for window in windows {
            guard window.count == 3 else { continue }
            let first = window[window.startIndex]
            let last = window[window.index(before: window.endIndex)]
            if last.timestamp.timeIntervalSince(first.timestamp) <= 30 {
                enterSafeMode()
                return
            }
        }
    }

    private func enterSafeMode() {
        appState.isSafeMode = true
        os_log(.fault, "[RenJistroly] 检测到连续崩溃，进入安全模式")

        let alert = NSAlert()
        alert.messageText = "RenJistroly 进入安全模式"
        alert.informativeText = "检测到应用连续崩溃多次。已禁用部分自动功能（如 MCP 自动启动）。\n\n如需重置崩溃记录，请删除 ~/Library/Logs/RenJistroly/crash_history.json"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "了解")
        alert.runModal()

        Task { await AgentEventBus.shared.publish(.system(.errorOccurred(domain: "crash", message: "连续崩溃，进入安全模式", recoverable: true))) }
    }

    private func installHelperIfNeeded() {
        Task {
            await updateManager.checkHelperStatus()
            if case .notInstalled = updateManager.helperStatus {
                _ = updateManager.installHelper()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        floatingPanel?.close()
    }

    private func setupFloatingPanel() {
        let content: AnyView
        if let controller = assistantController {
            content = AnyView(CompactAssistantView(controller: controller))
        } else {
            content = AnyView(
                FloatingPanelView()
                    .environment(appState)
                    .environment(engineForEnv)
            )
        }

        let panel = FloatingPanelWindow(content: content)
        panel.orderOut(nil)
        floatingPanel = panel
    }

    func toggleFloatingPanel() {
        guard let panel = floatingPanel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFront(nil)
            panel.setSize(width: 440, height: 600)
        }
    }

    func hideFloatingPanel() {
        floatingPanel?.orderOut(nil)
    }

    /// Shows the panel without stealing focus from the current app.
    /// Text input requires the user to click on the panel first (see sendEvent in FloatingPanelWindow).
    /// Voice input works independently at the system level.
    func showFloatingPanel() {
        floatingPanel?.orderFront(nil)
        floatingPanel?.setSize(width: 440, height: 600)
    }

    func beginPushToTalk() {
        guard !isPushToTalkActive else { return }
        isPushToTalkActive = true
        showFloatingPanel()

        if let controller = assistantController {
            Task {
                guard await controller.requestMicrophonePermission() else {
                    isPushToTalkActive = false
                    return
                }
                controller.startListening()
            }
        } else {
            guard appState.voiceState.canStartListening else { return }
            Task { [engineForEnv, appState] in
                try? await Task.sleep(for: .milliseconds(120))
                await engineForEnv.startVoiceInput(appState: appState)
            }
        }
    }

    func endPushToTalk() {
        guard isPushToTalkActive else { return }
        isPushToTalkActive = false

        if let controller = assistantController {
            controller.stopListening()
        } else {
            guard appState.voiceState.canFinishListening else { return }
            engineForEnv.stopVoiceInput(appState: appState)
        }
    }

    @objc func showSettingsWindow() {
        if settingsWindow == nil {
            let content = SettingsView()
                .environment(appState)
                .environment(engineForEnv)
            let hosting = NSHostingController(rootView: content)
            let window = NSWindow(contentViewController: hosting)
            window.title = "RenJistroly 设置"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 500, height: 400))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private var appNapActivity: NSObjectProtocol?

    private func preventAppNap() {
        appNapActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled],
            reason: "RenJistroly 需要持续后台活动以保持语音和屏幕监听"
        )
        Task { await eventBus.publish(.system(.appNapPrevented)) }
    }

    private func observeSleepWake() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                Task { await self?.eventBus.publish(.system(.systemWokeFromSleep)) }
                self?.checkPermissions()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.eventBus.publish(.system(.systemWillSleep)) }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier,
                  let name = app.localizedName else { return }
            Task { await self?.eventBus.publish(.desktop(.appActivated(bundleID: bundleID, name: name))) }
            if bundleID == Bundle.main.bundleIdentifier {
                Task { @MainActor [weak self] in
                    self?.checkPermissions()
                }
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier,
                  let name = app.localizedName else { return }
            Task { await self?.eventBus.publish(.desktop(.appDeactivated(bundleID: bundleID, name: name))) }
        }
    }

    private func checkPermissions() {
        Task {
            let checks = await PermissionCenter.shared.checkSystemPermissions()
            applyPermissions(checks)
        }
    }

    static func applyPermissionChecks(_ checks: [SystemPermissionCheck], to appState: AppState) {
        for check in checks {
            let granted = check.status.isGranted
            switch check.kind {
            case .accessibility: appState.isPermissionGranted.accessibility = granted
            case .microphone: appState.isPermissionGranted.microphone = granted
            case .speechRecognition: appState.isPermissionGranted.speechRecognition = granted
            case .screenRecording:
                if check.status != .unknown {
                    appState.isPermissionGranted.screenRecording = granted
                }
            case .appleEvents: appState.isPermissionGranted.appleEvents = granted
            }
        }
    }

    private func applyPermissions(_ checks: [SystemPermissionCheck]) {
        Self.applyPermissionChecks(checks, to: appState)
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = """
        RenJistroly 需要辅助功能权限来控制您的 Mac。

        请在系统设置 > 隐私与安全性 > 辅助功能中，
        添加并启用 RenJistroly。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        if alert.runModal() == .alertFirstButtonReturn {
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Crash Entry

private struct CrashEntry: Codable {
    let timestamp: Date
}

// MARK: - At Exit Handler

/// C-compatible atexit handler to clear crash flag file.
private func clearCrashFlag() {
    try? FileManager.default.removeItem(atPath: NSHomeDirectory() + "/.renjistroly_crash_flag")
}

// MARK: - Extensions

private extension Array {
    /// Returns all sliding windows of the given size.
    func slidingWindows(of size: Int) -> [SubSequence] {
        guard size > 0 && size <= count else { return [] }
        return (0...(count - size)).map { start in
            self[start..<(start + size)]
        }
    }
}
