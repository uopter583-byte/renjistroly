import SwiftUI

// MARK: - Semantic Color Tokens

extension Color {

    // MARK: Surface

    /// Primary window background
    public static var surfaceBackground: Color { Color(nsColor: .windowBackgroundColor) }
    /// Control/input background
    public static var surfaceInput: Color { Color(nsColor: .controlBackgroundColor) }
    /// Elevated card surface
    public static var surfaceElevated: Color { Color(nsColor: .underPageBackgroundColor) }
    /// Sidebar background tint
    public static var surfaceSidebar: Color { Color.primary.opacity(0.03) }
    /// Selected/highlighted surface
    public static var surfaceSelected: Color { Color.accentColor.opacity(0.08) }
    /// Hover surface
    public static var surfaceHover: Color { Color.primary.opacity(0.05) }
    /// Ultra-light grid or separator
    public static var surfaceGrid: Color { Color.primary.opacity(0.06) }

    // MARK: Text

    public static var textPrimary: Color { Color(nsColor: .labelColor) }
    public static var textSecondary: Color { Color(nsColor: .secondaryLabelColor) }
    public static var textTertiary: Color { Color(nsColor: .tertiaryLabelColor) }

    // MARK: Accent

    public static var accentDim: Color { Color.accentColor.opacity(0.08) }
    public static var accentFaint: Color { Color.accentColor.opacity(0.03) }
    /// Pill background for accent tags
    public static var accentPill: Color { Color.accentColor.opacity(0.12) }

    // MARK: Status

    public static var statusGreen: Color { .green }
    public static var statusGreenDim: Color { Color.green.opacity(0.12) }
    public static var statusRed: Color { .red }
    public static var statusRedDim: Color { Color.red.opacity(0.06) }
    public static var statusOrange: Color { .orange }
    public static var statusOrangeDim: Color { Color.orange.opacity(0.10) }
    public static var statusBlue: Color { .blue }
    public static var statusBlueDim: Color { Color.blue.opacity(0.08) }
    public static var statusPurple: Color { .purple }
    public static var statusPurpleDim: Color { Color.purple.opacity(0.10) }

    // MARK: Separator / Border

    public static var borderSubtle: Color { Color.primary.opacity(0.08) }
    public static var borderDefault: Color { Color(nsColor: .separatorColor) }
}

// MARK: - Elevation

public enum Elevation {
    /// None
    public static let z0: CGFloat = 0
    /// Subtle card shadow
    public static let z1: CGFloat = 1
    /// Popover/menu depth
    public static let z2: CGFloat = 3
    /// Modal/dialog depth
    public static let z3: CGFloat = 8

    /// Apply shadow for a given elevation level
    public static func shadow(_ level: CGFloat) -> some SwiftUI.ViewModifier {
        ShadowModifier(level: level)
    }
}

private struct ShadowModifier: ViewModifier {
    let level: CGFloat

    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.08 * min(level / 2, 1)), radius: level, y: level * 0.5)
    }
}

extension View {
    public func elevation(_ level: CGFloat) -> some View {
        modifier(Elevation.shadow(level))
    }
}

// MARK: - Linear Gradient Presets

public enum Gradients {
    public static let accentPrimary = LinearGradient(
        colors: [.blue, .blue.opacity(0.85)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let accentWarm = LinearGradient(
        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
