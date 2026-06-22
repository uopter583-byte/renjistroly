import AppKit
import ApplicationServices
import Foundation
import OSLog

/// Observe AX notifications from the focused application.
///
/// Watches for events that RenJistroly would otherwise miss:
/// - Focused window changed (dialogs, sheets, save panels)
/// - Application activated / deactivated
/// - Menu opened / closed
/// - Window miniaturized / deminiaturized
///
/// Usage:
/// ```swift
/// let observer = AXNotificationObserver()
/// for await event in await observer.events {
///     // handle AXNotificationEvent
/// }
/// ```
public actor AXNotificationObserver {

    public struct AXNotificationEvent: Sendable {
        public let name: String
        public let appPID: pid_t
        public let appName: String?
        public let timestamp: Date
    }

    private var currentObserver: (observer: AXObserver, pid: pid_t)?
    private var _eventContinuation: AsyncStream<AXNotificationEvent>.Continuation?
    private var isObserving = false
    private var workspaceTask: Task<Void, Never>?
    // Keeps self alive while any AXObserver refcon is active.
    private var observerRetain: Unmanaged<AXNotificationObserver>?
    private let osLog = OSLog(subsystem: "com.renjistroly", category: "AXObserver")

    // Notifications we subscribe to on the focused app element.
    private static let watchedNotifications: [String] = [
        kAXFocusedWindowChangedNotification,
        kAXFocusedUIElementChangedNotification,
        kAXApplicationActivatedNotification,
        kAXApplicationDeactivatedNotification,
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
        kAXWindowMiniaturizedNotification,
        kAXWindowDeminiaturizedNotification,
        kAXTitleChangedNotification,
        kAXDrawerCreatedNotification,
        kAXSheetCreatedNotification,
    ]

    /// Async stream of AX notification events.
    /// Subscribe before calling `startObserving()` to avoid missing events.
    public private(set) lazy var events: AsyncStream<AXNotificationEvent> = {
        AsyncStream { [weak self] cont in
            Task { [weak self] in
                await self?.configureContinuation(cont)
            }
        }
    }()

    private func configureContinuation(_ cont: AsyncStream<AXNotificationEvent>.Continuation) {
        _eventContinuation = cont
    }

    public init() {}

    /// Start listening for AX notifications from the currently focused application.
    /// Automatically follows when the user switches to a different app.
    public func startObserving() async {
        guard !isObserving else { return }
        isObserving = true

        // Register observer on the currently focused app
        await registerForCurrentApp()

        // Follow app switches via NSWorkspace (this doesn't need AX)
        workspaceTask = Task { [weak self] in
            let center = NSWorkspace.shared.notificationCenter
            let name = NSWorkspace.didActivateApplicationNotification
            for await notification in center.notifications(named: name) {
                guard let self else { return }
                let pid = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier ?? 0
                let appName = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.localizedName
                await self.handleAppSwitch(pid: pid, appName: appName)
            }
        }

        os_log("[AXObserver] 开始监听", log: self.osLog)
    }

    /// Stop observing.
    public func stopObserving() {
        guard isObserving else { return }
        isObserving = false
        workspaceTask?.cancel()
        workspaceTask = nil
        _eventContinuation?.finish()
        _eventContinuation = nil
        observerRetain?.release()
        observerRetain = nil
        currentObserver = nil
        os_log("[AXObserver] 停止监听", log: osLog)
    }

    // MARK: - Private

    private func registerForCurrentApp() async {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let pid = frontApp.processIdentifier
        register(pid: pid, appName: frontApp.localizedName)
    }

    private func handleAppSwitch(pid: pid_t, appName: String?) {
        guard isObserving, pid > 0 else { return }
        register(pid: pid, appName: appName)
    }

    private func register(pid: pid_t, appName: String?) {
        let appElement = AXUIElementCreateApplication(pid)

        // Unregister old observer with its own pid's element
        if let (oldObserver, oldPID) = currentObserver {
            let oldElement = AXUIElementCreateApplication(oldPID)
            for notif in Self.watchedNotifications {
                AXObserverRemoveNotification(oldObserver, oldElement, notif as CFString)
            }
        }

        var newObserver: AXObserver?
        let callback: AXObserverCallback = { observer, element, notificationName, refcon in
            let name = notificationName as String
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            var appName: String? = nil
            if let app = NSRunningApplication(processIdentifier: pid) {
                appName = app.localizedName
            }
            let event = AXNotificationEvent(
                name: name,
                appPID: pid,
                appName: appName,
                timestamp: Date()
            )
            // Post event via the refcon pointer
            if let refcon {
                let observer = Unmanaged<AXNotificationObserver>.fromOpaque(refcon).takeUnretainedValue()
                Task { await observer.postEvent(event) }
            }
        }

        let result = AXObserverCreate(pid, callback, &newObserver)
        guard result == .success, let newObserver else {
            os_log("[AXObserver] 创建观察器失败: %d", log: osLog, result.rawValue)
            return
        }

        // Balance retain from previous observer registration
        observerRetain?.release()
        observerRetain = Unmanaged.passRetained(self)

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .commonModes)

        // Register each notification
        let selfPtr = observerRetain!.toOpaque()
        for notif in Self.watchedNotifications {
            let regResult = AXObserverAddNotification(newObserver, appElement, notif as CFString, selfPtr)
            // Some apps don't support all notifications — that's fine
            if regResult != .success && regResult.rawValue != -25206 /* kAXErrorNotRegistered */ {
                os_log("[AXObserver] 注册通知 %@ 失败: %d", log: osLog, notif, regResult.rawValue)
            }
        }

        currentObserver = (newObserver, pid)
    }

    private func postEvent(_ event: AXNotificationEvent) {
        _eventContinuation?.yield(event)
    }
}
