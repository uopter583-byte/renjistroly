import AppKit
import Foundation

/// Coordinates visual feedback overlays for AI-driven tool execution.
/// Thin @MainActor wrapper around CursorOverlayController with an enabled/disabled toggle.
@MainActor
public final class VisualizerCoordinator {
    public static let shared = VisualizerCoordinator()

    private let overlay = CursorOverlayController.shared
    private var _enabled = true

    private init() {}

    public var isEnabled: Bool { _enabled }

    public func setEnabled(_ enabled: Bool) {
        _enabled = enabled
        if !enabled { overlay.dismissAll() }
    }

    // MARK: - Notification API

    public func notifyClick(at point: CGPoint, label: String? = nil) {
        guard _enabled else { return }
        overlay.showRipple(at: point, label: label)
    }

    public func notifyRightClick(at point: CGPoint) {
        guard _enabled else { return }
        overlay.showRipple(at: point, color: .systemOrange, label: "Right Click")
    }

    public func notifyDoubleClick(at point: CGPoint) {
        guard _enabled else { return }
        overlay.showRipple(at: point, color: .systemPurple, label: "Double Click")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.overlay.showRipple(at: point, color: .systemPurple)
        }
    }

    public func notifyType(text: String) {
        guard _enabled else { return }
        let preview = text.count > 30 ? String(text.prefix(30)) + "…" : text
        guard let screen = NSScreen.main else { return }
        overlay.showLabel(at: CGPoint(x: screen.frame.midX, y: screen.frame.midY - 80),
                          text: "Typing: \(preview)")
    }

    public func notifyScroll(direction: String, amount: Double) {
        guard _enabled else { return }
        guard let screen = NSScreen.main,
              let dir = ScrollDirection(rawValue: direction) else { return }
        overlay.showScrollArrow(at: CGPoint(x: screen.frame.midX, y: screen.frame.midY),
                                direction: dir)
    }

    public func notifyDrag(from: CGPoint, to: CGPoint) {
        guard _enabled else { return }
        overlay.showDragTrail(from: from, to: to)
    }

    public func notifyScreenshot() {
        guard _enabled else { return }
        overlay.showFlash()
    }

    public func notifyHotkey(key: String, modifiers: [String]) {
        guard _enabled else { return }
        overlay.showHotkey(key: key, modifiers: modifiers)
    }

    public func notifyMenu(path: String) {
        guard _enabled else { return }
        overlay.showMenuBreadcrumb(path: path)
    }
}
