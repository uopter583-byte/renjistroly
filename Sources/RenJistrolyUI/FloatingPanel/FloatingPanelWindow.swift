import AppKit
import SwiftUI

// @unchecked Sendable: NSPanel is main-thread-only by AppKit contract.
// All access is through @MainActor context; no concurrent mutation occurs.
public final class FloatingPanelWindow: NSPanel, @unchecked Sendable {
    private var hostingView: NSHostingView<AnyView>?

    public init(content: AnyView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 600),
            styleMask: [.borderless, .nonactivatingPanel, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        animationBehavior = .utilityWindow
        hidesOnDeactivate = false
        contentMinSize = NSSize(width: 360, height: 500)

        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .withinWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        visualEffect.setContentHuggingPriority(.defaultLow, for: .horizontal)
        visualEffect.setContentHuggingPriority(.defaultLow, for: .vertical)

        let hosting = NSHostingView(rootView: content)
        hosting.frame = visualEffect.bounds
        hosting.autoresizingMask = [.width, .height]
        visualEffect.addSubview(hosting)

        contentView = visualEffect
        hostingView = hosting
        centerOnScreen()
    }

    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }

    /// Clicking the panel when another app is active should re-activate and make it key.
    /// Without this, .nonactivatingPanel blocks makeKeyAndOrderFront when the app is inactive.
    public override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow {
            NSApp.activate(ignoringOtherApps: true)
            makeKeyAndOrderFront(nil)
        }
        super.sendEvent(event)
    }

    public func updateContent(_ view: AnyView) {
        hostingView?.rootView = view
    }

    public func setSize(width: CGFloat, height: CGFloat, animated: Bool = true) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let newFrame = NSRect(
            x: screenFrame.maxX - width - 20,
            y: screenFrame.maxY - height - 20,
            width: width,
            height: height
        )
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().setFrame(newFrame, display: true)
            }
        } else {
            setFrame(newFrame, display: true)
        }
        hostingView?.frame = NSRect(x: 0, y: 0, width: width, height: height)
    }

    private func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowFrame = frame
        let x = screenFrame.maxX - windowFrame.width - 20
        let y = screenFrame.maxY - windowFrame.height - 20
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
