import ApplicationServices
import Foundation

/// Utilities for waiting until the accessibility tree stabilizes
/// after an input action.
///
/// After posting a click or keypress to a backgrounded app, the target's
/// AX tree may take 1-3 runloop turns to reflect the new state. Reading
/// immediately can return stale values — especially for Chromium, where
/// the renderer-side AX pipeline runs asynchronously on the compositor
/// thread.
///
/// Two mechanisms:
/// - `withRunLoopPump`: spin the main runloop for `ms` to flush pending
///   AX notifications.
/// - `waitForElementReady`: poll a specific element until it reports a
///   non-empty value for a given attribute, up to `timeoutMs`.
public enum AXSettling {

    /// Spin the main runloop for `milliseconds` to let pending AX
    /// notifications and attribute-change callbacks drain.
    ///
    /// Chromium needs ~8-16 ms after a click for the renderer-side AX
    /// tree to commit. Native AppKit targets usually need less, but
    /// 10 ms is a safe floor. For heavyweight DOM mutations (React
    /// virtual-DOM reconciliation), 50-100 ms may be needed.
    ///
    /// Call this after `AXUIElementPerformAction` or after posting a
    /// pid-routed CGEvent and before reading the target's AX state.
    public static func withRunLoopPump(milliseconds: UInt64) async {
        let ns = milliseconds * 1_000_000
        try? await Task.sleep(nanoseconds: ns)
    }

    /// Default post-action settle time (10 ms). Covers the common case
    /// of a single click/keypress on a native AppKit or Chromium target.
    public static func settle() async {
        await withRunLoopPump(milliseconds: 10)
    }

    /// Longer settle for heavyweight actions (form submission, page
    /// navigation, React reconciliation).
    public static func settleDeep() async {
        await withRunLoopPump(milliseconds: 80)
    }

    /// Poll `element` for `attribute` until it returns a non-nil,
    /// non-empty value, up to `timeoutMs`. Returns the value on success,
    /// nil on timeout.
    ///
    /// Useful for waiting on a search result, a new window title, or a
    /// status label to materialize after submitting a command.
    public static func waitForElementReady(
        _ element: AXUIElement,
        attribute: String,
        timeoutMs: Int = 500
    ) async -> String? {
        let deadline = ContinuousClock.now + .milliseconds(timeoutMs)
        while ContinuousClock.now < deadline {
            if let value = readString(element, attribute), !value.isEmpty {
                return value
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return readString(element, attribute)
    }

    /// Poll `element` until a child with `targetRole` appears, up to
    /// `timeoutMs`. Returns the first matching child or nil on timeout.
    public static func waitForChildWithRole(
        _ element: AXUIElement,
        role targetRole: String,
        timeoutMs: Int = 500
    ) async -> AXUIElement? {
        let deadline = ContinuousClock.now + .milliseconds(timeoutMs)
        while ContinuousClock.now < deadline {
            if let child = findChild(withRole: targetRole, in: element) {
                return child
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return findChild(withRole: targetRole, in: element)
    }

    // MARK: - Helpers

    private static func readString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    private static func findChild(withRole role: String, in element: AXUIElement) -> AXUIElement? {
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXChildren" as CFString, &children) == .success,
              let raw = children as? [AXUIElement] // toll-free bridged
        else { return nil }
        for child in raw {
            if readString(child, "AXRole") == role { return child }
        }
        return nil
    }
}
