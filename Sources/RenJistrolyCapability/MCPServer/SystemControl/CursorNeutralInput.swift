import AppKit
import Foundation
import RenJistrolySystemBridge

/// Cursor-neutral input dispatch.
///
/// Strategy for all click-like operations:
///   Level 1 → AX element hit-test + kAXPressAction (zero cursor movement)
///   Level 2 → CGEventPostToPid / SkyLight SPI (background, cursor-neutral)
///   Level 3 → CGEvent cghidEventTap (moves cursor, last resort)
///
/// Drag uses a subset:
///   Level 1 → (no AX equivalent exists for drag)
///   Level 2 → CGEventPostToPid / SkyLight SPI (background, cursor-neutral)
///   Level 3 → CGEvent cghidEventTap (moves cursor, last resort)
enum CursorNeutralInput {
    static func targetPid(app appName: String?) -> pid_t? {
        if let appName = appName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !appName.isEmpty {
            let needle = appName.lowercased()
            return NSWorkspace.shared.runningApplications.first { app in
                app.bundleIdentifier?.lowercased() == needle ||
                    app.localizedName?.lowercased() == needle ||
                    app.localizedName?.lowercased().contains(needle) == true
            }?.processIdentifier
        }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    /// Click at screen point.
    /// Delegates to `AccessibilityContextProvider` which implements:
    ///   Level 1: AX hit-test → kAXPressAction (zero cursor movement)
    ///   Level 2: postToPid / SkyLight SPI (background, cursor-neutral)
    ///   Level 3: cghidEventTap (moves cursor, last resort)
    static func click(
        at point: CGPoint,
        clickCount: Int = 1,
        button: AccessibilityContextProvider.MouseButton = .left,
        app: String? = nil
    ) async -> Bool {
        await AccessibilityContextProvider().click(
            at: point,
            clickCount: clickCount,
            button: button,
            toPid: targetPid(app: app)
        )
    }

    /// Drag from start to end.
    /// No AX equivalent exists for drag, so the strategy is:
    ///   Level 2: postToPid when PID available (background, cursor-neutral)
    ///   Level 3: cghidEventTap (moves cursor, last resort)
    static func drag(from start: CGPoint, to end: CGPoint, app: String? = nil) async -> Bool {
        await AccessibilityContextProvider().drag(
            from: start,
            to: end,
            toPid: targetPid(app: app)
        )
    }
}
