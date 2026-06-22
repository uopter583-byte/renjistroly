import ApplicationServices
import Foundation

/// Selects the right input delivery strategy for a target app.
///
/// Key difference between the three click strategies:
///
/// | Strategy | Targets | Cursor | Chromium | AX |
/// |----------|---------|--------|----------|----|
/// | `axAction` | AX-addressable elements | neutral | yes | yes |
/// | `chromiumStyle` | Chromium/Electron bg | neutral | yes | no  |
/// | `basicBackground` | Native AppKit bg | neutral | partial | no |
/// | `foregroundHID` | Frontmost only | moves | yes | no  |
///
/// General principle: prefer `axAction` when the target element has
/// an AX address; fall back to `chromiumStyle` for Chromium background
/// pixel clicks; use `basicBackground` for native AppKit background;
/// use `foregroundHID` only when the target is already frontmost.
// @unchecked Sendable: enum wraps non-Sendable AXUIElement; used only within InputStrategySelector
public enum InputStrategy: @unchecked Sendable {
    /// Dispatch via AXUIElementPerformAction (AXPress, AXShowMenu, etc.).
    /// Pure RPC — works on backgrounded/hidden windows, no cursor movement.
    case axAction(element: AXUIElement)

    /// NSEvent-bridged CGEvent with FocusWithoutRaise + off-screen primer.
    /// Optimized for Chromium/Electron background targets.
    case chromiumStyle(point: CGPoint)

    /// Dual-post via SkyLight SPI + CGEvent.postToPid. Works for
    /// native AppKit background targets but may be filtered by Chromium.
    case basicBackground(point: CGPoint)

    /// CGEvent.post(tap: .cghidEventTap) — system HID stream.
    /// Moves the real cursor. Only use when target is already frontmost.
    case foregroundHID(point: CGPoint)
}

// MARK: - Strategy selection

public struct InputStrategySelector: Sendable {

    /// Known Chromium/Electron bundle identifier prefixes.
    /// These apps need the NSEvent bridge + primer click recipe.
    private static let chromiumBundles: Set<String> = [
        "com.google.Chrome",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        "org.chromium.Chromium",
        "com.github.electron",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "com.microsoft.VSCode",
        "com.spotify.client",
        "com.notion.id",
        "com.figma.Desktop",
        "com.github.atom",
        "md.obsidian",
        "com.logseq.logseq",
        "org.telegram.desktop",
    ]

    /// True when `bundleID` is a known Chromium/Electron app that needs
    /// the auth-signed click recipe.
    public static func isChromium(_ bundleID: String?) -> Bool {
        guard let bid = bundleID else { return false }
        return chromiumBundles.contains(bid)
            || bid.hasPrefix("com.microsoft.VSCode")
            || bid.hasPrefix("com.github.Electron")
    }

    /// Pick the best input strategy for background click delivery.
    ///
    /// - When `element` is non-nil and has AXPress: use `axAction`
    /// - Otherwise, for Chromium targets: use `chromiumStyle`
    /// - Otherwise: use `basicBackground`
    public static func selectClickStrategy(
        point: CGPoint,
        element: AXUIElement?,
        bundleID: String?
    ) -> InputStrategy {
        if let el = element, supportsAXPress(el) {
            return .axAction(element: el)
        }
        if isChromium(bundleID) {
            return .chromiumStyle(point: point)
        }
        return .basicBackground(point: point)
    }

    /// Check whether an AX element supports the AXPress action.
    private static func supportsAXPress(_ element: AXUIElement) -> Bool {
        var actions: CFArray?
        let result = AXUIElementCopyActionNames(element, &actions)
        guard result == .success,
              let names = actions as? [String]
        else { return false }
        return names.contains("AXPress")
    }
}
