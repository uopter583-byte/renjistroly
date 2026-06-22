import CoreGraphics
import Foundation

/// Read and control the mouse cursor position.
///
/// Uses `CGEvent` to read the current cursor location and to post
/// synthetic mouse-move / click events via the HID event tap.
public enum CursorController {

    /// Current cursor position in the global (main display) coordinate space.
    public static var currentPosition: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    /// Move the cursor to an absolute screen position.
    /// Posts a single `.mouseMoved` event.
    public static func move(to point: CGPoint) {
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        )
        event?.post(tap: .cghidEventTap)
    }

    /// Smoothly animate the cursor from its current position to `end` in `steps` increments.
    /// Useful for visual feedback so the user can see where the cursor is going.
    public static func smoothMove(to end: CGPoint, steps: Int = 20) {
        let start = currentPosition
        for i in 1 ... steps {
            let t = Double(i) / Double(steps)
            let p = CGPoint(
                x: start.x + (end.x - start.x) * t,
                y: start.y + (end.y - start.y) * t
            )
            let event = CGEvent(
                mouseEventSource: nil,
                mouseType: .mouseMoved,
                mouseCursorPosition: p,
                mouseButton: .left
            )
            event?.post(tap: .cghidEventTap)
            usleep(8_000) // ~8 ms per step → ~160 ms total
        }
    }

    // MARK: - Clicks

    public static func click(at point: CGPoint, button: CGMouseButton = .left) {
        let downType: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
        let upType: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp

        let down = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: button)
        let up = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: button)

        down?.post(tap: .cghidEventTap)
        usleep(10_000)
        up?.post(tap: .cghidEventTap)
    }

    public static func doubleClick(at point: CGPoint) {
        click(at: point)
        usleep(50_000)
        click(at: point)
    }

    public static func rightClick(at point: CGPoint) {
        click(at: point, button: .right)
    }

    // MARK: - Drag

    public static func drag(from start: CGPoint, to end: CGPoint, steps: Int = 20) {
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left)
        down?.post(tap: .cghidEventTap)

        for i in 1 ... steps {
            let t = Double(i) / Double(steps)
            let p = CGPoint(
                x: start.x + (end.x - start.x) * t,
                y: start.y + (end.y - start.y) * t
            )
            let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: p, mouseButton: .left)
            drag?.post(tap: .cghidEventTap)
            usleep(8_000)
        }

        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left)
        up?.post(tap: .cghidEventTap)
    }
}
