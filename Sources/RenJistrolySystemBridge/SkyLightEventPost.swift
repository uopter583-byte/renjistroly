import CoreGraphics
import Darwin
import Foundation
import ObjectiveC

/// Bridge to SkyLight's private per-pid event-post path.
///
/// Two-layer story:
/// 1. **Post path** — `SLEventPostToPid` wraps `SLEventPostToPSN` → `CGSTickleActivityMonitor`
///    → `IOHIDPostEvent`. The public `CGEventPostToPid` skips the activity-monitor tickle,
///    so events delivered through it don't register as "live input" — which Chromium needs.
/// 2. **Authentication** — on macOS 14+, WindowServer gates synthetic keyboard events against
///    Chromium-like targets on an attached `SLSEventAuthenticationMessage`.
///
/// All symbols are resolved once at first use via `dlopen` + `dlsym`.
/// If anything fails, callers fall back to the public `CGEvent.postToPid`.
public enum SkyLightEventPost {
    // MARK: - Function-pointer typedefs

    private typealias PostToPidFn = @convention(c) (pid_t, CGEvent) -> Void
    private typealias SetAuthMessageFn = @convention(c) (CGEvent, AnyObject) -> Void
    private typealias SetIntFieldFn = @convention(c) (CGEvent, UInt32, Int64) -> Void
    private typealias SetWindowLocationFn = @convention(c) (CGEvent, CGPoint) -> Void
    private typealias FactoryMsgSendFn = @convention(c) (
        AnyObject, Selector, UnsafeMutableRawPointer, Int32, UInt32
    ) -> AnyObject?

    // Focus-without-raise SPIs
    private typealias PostEventRecordToFn = @convention(c) (
        UnsafeRawPointer, UnsafePointer<UInt8>
    ) -> Int32
    private typealias GetFrontProcessFn = @convention(c) (
        UnsafeMutableRawPointer
    ) -> Int32
    private typealias GetProcessForPIDFn = @convention(c) (
        pid_t, UnsafeMutableRawPointer
    ) -> Int32

    /// Ensure SkyLight is loaded once. All dlsym lookups use the returned handle.
    nonisolated(unsafe) private static let skyLightHandle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    }()

    /// Resolve a function pointer from a loaded image. Isolates the one unavoidable
    /// `unsafeBitCast` (dlsym necessarily returns a void*).
    private static func fnPtr<T>(_ name: String) -> T? {
        guard let p = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }
        return unsafeBitCast(p, to: T.self)
    }

    // MARK: - Cached resolved handles

    private struct Resolved {
        let postToPid: PostToPidFn
        let setAuthMessage: SetAuthMessageFn
        let msgSendFactory: FactoryMsgSendFn
        let messageClass: AnyClass
        let factorySelector: Selector
    }

    private static let resolved: Resolved? = {
        _ = skyLightHandle

        guard
            let postToPid: PostToPidFn = fnPtr("SLEventPostToPid"),
            let setAuth: SetAuthMessageFn = fnPtr("SLEventSetAuthenticationMessage"),
            let msgSend: FactoryMsgSendFn = fnPtr("objc_msgSend"),
            let messageClass = NSClassFromString("SLSEventAuthenticationMessage")
        else { return nil }

        return Resolved(
            postToPid: postToPid,
            setAuthMessage: setAuth,
            msgSendFactory: msgSend,
            messageClass: messageClass,
            factorySelector: NSSelectorFromString("messageWithEventRecord:pid:version:")
        )
    }()

    private static let setIntField: SetIntFieldFn? = {
        _ = skyLightHandle
        return fnPtr("SLEventSetIntegerValueField")
    }()

    private static let setWindowLocationFn: SetWindowLocationFn? = {
        _ = skyLightHandle
        return fnPtr("CGEventSetWindowLocation")
    }()

    // MARK: - Focus-without-raise SPIs

    private static let postEventRecordToFn: PostEventRecordToFn? = {
        _ = skyLightHandle
        return fnPtr("SLPSPostEventRecordTo")
    }()

    private static let getFrontProcessFn: GetFrontProcessFn? = {
        _ = skyLightHandle
        return fnPtr("_SLPSGetFrontProcess")
    }()

    private static let getProcessForPIDFn: GetProcessForPIDFn? = {
        _ = skyLightHandle
        return fnPtr("GetProcessForPID")
    }()

    public static var isAvailable: Bool { resolved != nil }

    // MARK: - Public API

    /// Post `event` to `pid` via `SLEventPostToPid`.
    /// `attachAuthMessage` controls SLSEventAuthenticationMessage attachment.
    /// - `true` (keyboard): Chromium accepts synthetic keyboard events as trusted input.
    /// - `false` (mouse): skips auth so the event routes through IOHIDPostEvent.
    @discardableResult
    public static func postToPid(
        _ pid: pid_t, event: CGEvent, attachAuthMessage: Bool = true
    ) -> Bool {
        guard let r = resolved else { return false }
        if attachAuthMessage {
            if let record = extractEventRecord(from: event),
               let msg = r.msgSendFactory(
                r.messageClass as AnyObject, r.factorySelector, record, pid, 0
               ) {
                r.setAuthMessage(event, msg)
            }
        }
        r.postToPid(pid, event)
        return true
    }

    /// Stamp `value` onto `event` at raw Skylight field index `field`.
    @discardableResult
    public static func setIntegerField(_ event: CGEvent, field: UInt32, value: Int64) -> Bool {
        guard let fn = setIntField else { return false }
        fn(event, field, value)
        return true
    }

    /// Stamp a window-local `point` onto `event` via private `CGEventSetWindowLocation` SPI.
    @discardableResult
    public static func setWindowLocation(_ event: CGEvent, _ point: CGPoint) -> Bool {
        guard let fn = setWindowLocationFn else { return false }
        fn(event, point)
        return true
    }

    public static var isWindowLocationAvailable: Bool { setWindowLocationFn != nil }

    /// Copy current frontmost process PSN into 8-byte buffer.
    public static func getFrontProcess(_ psnBuffer: UnsafeMutableRawPointer) -> Bool {
        guard let fn = getFrontProcessFn else { return false }
        return fn(psnBuffer) == 0
    }

    /// Resolve `pid` to its PSN, writing 8 bytes into `psnBuffer`.
    public static func getProcessPSN(forPid pid: pid_t, into psnBuffer: UnsafeMutableRawPointer) -> Bool {
        guard let fn = getProcessForPIDFn else { return false }
        return fn(pid, psnBuffer) == 0
    }

    /// Post a 248-byte synthetic event record via `SLPSPostEventRecordTo`.
    @discardableResult
    public static func postEventRecordTo(psn: UnsafeRawPointer, bytes: UnsafePointer<UInt8>) -> Bool {
        guard let fn = postEventRecordToFn else { return false }
        return fn(psn, bytes) == 0
    }

    public static var isFocusWithoutRaiseAvailable: Bool {
        getFrontProcessFn != nil && getProcessForPIDFn != nil && postEventRecordToFn != nil
    }

    // MARK: - Event-record extraction

    /// Extract embedded `SLSEventRecord *` from CGEvent. Probes offsets 24, 32, 16
    /// for resilience across OS revisions.
    private static func extractEventRecord(from event: CGEvent) -> UnsafeMutableRawPointer? {
        let base = Unmanaged.passUnretained(event).toOpaque()
        for offset in [24, 32, 16] {
            let slot = base.advanced(by: offset).assumingMemoryBound(
                to: UnsafeMutableRawPointer?.self)
            if let p = slot.pointee { return p }
        }
        return nil
    }

    // MARK: - Window helpers

    public static func windowIDs(forPid pid: pid_t) -> [CGWindowID] {
        guard let all = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]]
        else { return [] }
        return all.compactMap { info -> CGWindowID? in
            guard (info[kCGWindowOwnerPID as String] as? Int32) == pid else { return nil }
            return CGWindowID((info[kCGWindowNumber as String] as? Int) ?? 0)
        }
    }
}
