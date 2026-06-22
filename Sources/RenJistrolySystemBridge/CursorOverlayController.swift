import AppKit
import Foundation

// MARK: - Overlay Types

public enum ScrollDirection: String, Sendable {
    case up, down, left, right
}

/// Software cursor overlay rendered via transparent NSPanels.
/// Shows visual indicators when clicks/actions are performed without moving the physical cursor.
@MainActor
public final class CursorOverlayController {
    public static let shared = CursorOverlayController()

    private var activePanels: [NSPanel] = []
    private let maxPanels = 5

    private init() {}

    // MARK: - Public API

    public func showRipple(at point: CGPoint, color: NSColor = .systemBlue, label: String? = nil) {
        let size = NSSize(width: 80, height: 80)
        let panel = makePanel(frame: NSRect(
            x: point.x - size.width / 2, y: point.y - size.height / 2,
            width: size.width, height: size.height
        ))
        panel.contentView = RippleOverlayView(color: color, label: label)
        showPanel(panel, duration: 0.6)
    }

    public func showFlash() {
        guard let screen = NSScreen.main else { return }
        let panel = makePanel(frame: screen.frame)
        panel.contentView = FlashOverlayView()
        showPanel(panel, duration: 0.3)
    }

    public func showScrollArrow(at point: CGPoint, direction: ScrollDirection) {
        let size = NSSize(width: 40, height: 40)
        let panel = makePanel(frame: NSRect(
            x: point.x - size.width / 2, y: point.y - size.height / 2,
            width: size.width, height: size.height
        ))
        panel.contentView = ScrollArrowOverlayView(direction: direction)
        showPanel(panel, duration: 0.5)
    }

    public func showDragTrail(from: CGPoint, to: CGPoint) {
        let pad: CGFloat = 20
        let fx = min(from.x, to.x) - pad, fy = min(from.y, to.y) - pad
        let fw = abs(to.x - from.x) + pad * 2, fh = abs(to.y - from.y) + pad * 2
        let panel = makePanel(frame: NSRect(x: fx, y: fy, width: max(fw, 40), height: max(fh, 40)))
        panel.contentView = DragTrailOverlayView(from: CGPoint(x: from.x - fx, y: from.y - fy),
                                                  to: CGPoint(x: to.x - fx, y: to.y - fy))
        showPanel(panel, duration: 0.8)
    }

    public func showLabel(at point: CGPoint, text: String) {
        let textSize = text.size(withAttributes: [.font: NSFont.systemFont(ofSize: 12)])
        let w = textSize.width + 24, h = textSize.height + 16
        let panel = makePanel(frame: NSRect(
            x: point.x - w / 2, y: point.y + 10,
            width: max(w, 30), height: max(h, 24)
        ))
        panel.contentView = LabelOverlayView(text: text)
        showPanel(panel, duration: 1.5)
    }

    public func showHotkey(key: String, modifiers: [String]) {
        let modStr = modifiers.joined(separator: " + ")
        let displayStr = modStr.isEmpty ? key.uppercased() : "\(modStr) + \(key.uppercased())"
        guard let screen = NSScreen.main else { return }
        showLabel(at: CGPoint(x: screen.frame.midX, y: screen.frame.midY + 100), text: displayStr)
    }

    public func showMenuBreadcrumb(path: String) {
        guard let screen = NSScreen.main else { return }
        showLabel(at: CGPoint(x: screen.frame.midX, y: screen.frame.minY + 80), text: path)
    }

    public func dismissAll() {
        for panel in activePanels {
            panel.orderOut(nil)
        }
        activePanels.removeAll()
    }

    // MARK: - Panel Management

    private func makePanel(frame: NSRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = true
        return panel
    }

    private func showPanel(_ panel: NSPanel, duration: TimeInterval) {
        if activePanels.count >= maxPanels {
            activePanels.first?.orderOut(nil)
            activePanels.removeFirst()
        }
        activePanels.append(panel)
        panel.orderFrontRegardless()
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            panel.orderOut(nil)
            self?.activePanels.removeAll { $0 === panel }
        }
    }
}

// MARK: - Ripple Overlay

private final class RippleOverlayView: NSView {
    private let color: NSColor
    private let label: String?
    private var didAnimate = false

    init(color: NSColor, label: String?) {
        self.color = color
        self.label = label
        super.init(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !didAnimate else { return }
        didAnimate = true
        guard let layer else { return }

        let r: CGFloat = 30
        let outerRing = CAShapeLayer()
        outerRing.path = CGPath(ellipseIn: CGRect(x: bounds.midX - r, y: bounds.midY - r, width: r * 2, height: r * 2), transform: nil)
        outerRing.strokeColor = color.withAlphaComponent(0.8).cgColor
        outerRing.fillColor = nil
        outerRing.lineWidth = 2.5
        layer.addSublayer(outerRing)

        let dot = CAShapeLayer()
        dot.path = CGPath(ellipseIn: CGRect(x: bounds.midX - 3, y: bounds.midY - 3, width: 6, height: 6), transform: nil)
        dot.fillColor = color.withAlphaComponent(0.4).cgColor
        layer.addSublayer(dot)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.2; scale.toValue = 1.0; scale.duration = 0.5
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0; fade.toValue = 0.0; fade.duration = 0.5
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let group = CAAnimationGroup()
        group.animations = [scale, fade]; group.duration = 0.5
        outerRing.add(group, forKey: "ripple")

        let dotFade = CABasicAnimation(keyPath: "opacity")
        dotFade.fromValue = 1.0; dotFade.toValue = 0.0; dotFade.duration = 0.4
        dotFade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        dot.add(dotFade, forKey: "fade")

        if let labelText = label {
            let textLayer = CATextLayer()
            textLayer.string = labelText
            textLayer.fontSize = 11
            textLayer.foregroundColor = color.withAlphaComponent(0.9).cgColor
            textLayer.alignmentMode = .center
            textLayer.contentsScale = window?.backingScaleFactor ?? 2
            let labelSize = (labelText as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)])
            let lw = labelSize.width + 12, lh = labelSize.height + 6
            textLayer.frame = CGRect(x: bounds.midX - lw / 2, y: bounds.midY + r + 6, width: lw, height: lh)
            layer.addSublayer(textLayer)
        }
    }
}

// MARK: - Flash Overlay

private final class FlashOverlayView: NSView {
    private var didAnimate = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !didAnimate else { return }
        didAnimate = true
        guard let layer else { return }
        layer.backgroundColor = NSColor.white.cgColor
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 0.6; anim.toValue = 0.0; anim.duration = 0.25
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(anim, forKey: "flash")
    }
}

// MARK: - Scroll Arrow Overlay

private final class ScrollArrowOverlayView: NSView {
    private let direction: ScrollDirection
    private var didAnimate = false

    init(direction: ScrollDirection) {
        self.direction = direction
        super.init(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !didAnimate else { return }
        didAnimate = true
        guard let layer else { return }

        let arrow = CAShapeLayer()
        arrow.path = makeArrowPath()
        arrow.strokeColor = NSColor.systemBlue.cgColor
        arrow.fillColor = nil
        arrow.lineWidth = 2.5
        arrow.lineCap = .round
        arrow.lineJoin = .round
        layer.addSublayer(arrow)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0; fade.toValue = 1; fade.duration = 0.2
        arrow.add(fade, forKey: "fadeIn")
    }

    private func makeArrowPath() -> CGPath {
        let path = CGMutablePath()
        let cx = bounds.midX, cy = bounds.midY
        let len: CGFloat = 12
        switch direction {
        case .up:
            path.move(to: CGPoint(x: cx, y: cy + len))
            path.addLine(to: CGPoint(x: cx - len * 0.6, y: cy))
            path.move(to: CGPoint(x: cx, y: cy + len))
            path.addLine(to: CGPoint(x: cx + len * 0.6, y: cy))
        case .down:
            path.move(to: CGPoint(x: cx, y: cy - len))
            path.addLine(to: CGPoint(x: cx - len * 0.6, y: cy))
            path.move(to: CGPoint(x: cx, y: cy - len))
            path.addLine(to: CGPoint(x: cx + len * 0.6, y: cy))
        case .left:
            path.move(to: CGPoint(x: cx - len, y: cy))
            path.addLine(to: CGPoint(x: cx, y: cy + len * 0.6))
            path.move(to: CGPoint(x: cx - len, y: cy))
            path.addLine(to: CGPoint(x: cx, y: cy - len * 0.6))
        case .right:
            path.move(to: CGPoint(x: cx + len, y: cy))
            path.addLine(to: CGPoint(x: cx, y: cy + len * 0.6))
            path.move(to: CGPoint(x: cx + len, y: cy))
            path.addLine(to: CGPoint(x: cx, y: cy - len * 0.6))
        }
        return path
    }
}

// MARK: - Drag Trail Overlay

private final class DragTrailOverlayView: NSView {
    private let fromPoint: CGPoint
    private let toPoint: CGPoint
    private var didAnimate = false

    init(from: CGPoint, to: CGPoint) {
        self.fromPoint = from
        self.toPoint = to
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !didAnimate else { return }
        didAnimate = true
        guard let layer else { return }

        let lineLayer = CAShapeLayer()
        let linePath = CGMutablePath()
        linePath.move(to: fromPoint)
        linePath.addLine(to: toPoint)
        lineLayer.path = linePath
        lineLayer.strokeColor = NSColor.systemBlue.withAlphaComponent(0.6).cgColor
        lineLayer.fillColor = nil
        lineLayer.lineWidth = 2
        lineLayer.lineDashPattern = [6, 4]
        lineLayer.lineCap = .round
        layer.addSublayer(lineLayer)

        let draw = CABasicAnimation(keyPath: "strokeEnd")
        draw.fromValue = 0; draw.toValue = 1; draw.duration = 0.4
        draw.timingFunction = CAMediaTimingFunction(name: .easeOut)
        lineLayer.add(draw, forKey: "drawLine")

        let startDot = CAShapeLayer()
        startDot.path = CGPath(ellipseIn: CGRect(x: fromPoint.x - 3, y: fromPoint.y - 3, width: 6, height: 6), transform: nil)
        startDot.fillColor = NSColor.systemBlue.withAlphaComponent(0.8).cgColor
        layer.addSublayer(startDot)
    }
}

// MARK: - Label Overlay

private final class LabelOverlayView: NSView {
    private let text: String
    private var didAnimate = false

    init(text: String) {
        self.text = text
        let textSize = text.size(withAttributes: [.font: NSFont.systemFont(ofSize: 12)])
        super.init(frame: NSRect(x: 0, y: 0, width: max(textSize.width + 24, 30), height: max(textSize.height + 16, 24)))
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !didAnimate else { return }
        didAnimate = true
        guard let layer else { return }

        let bg = CAShapeLayer()
        bg.path = CGPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerWidth: 6, cornerHeight: 6, transform: nil)
        bg.fillColor = NSColor.black.withAlphaComponent(0.7).cgColor
        layer.addSublayer(bg)

        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.fontSize = 12
        textLayer.foregroundColor = NSColor.white.cgColor
        textLayer.alignmentMode = .center
        textLayer.contentsScale = window?.backingScaleFactor ?? 2
        textLayer.frame = bounds
        layer.addSublayer(textLayer)

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0; fade.toValue = 1; fade.duration = 0.15
        layer.add(fade, forKey: "fadeIn")
    }
}
