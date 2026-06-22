import SwiftUI

// MARK: - Typography Scale

public enum Typography {

    // MARK: Sizes

    public enum Size {
        /// 9pt — micro labels, badges
        public static let micro: CGFloat = 9
        /// 10pt — captions
        public static let caption: CGFloat = 10
        /// 11pt — secondary info
        public static let small: CGFloat = 11
        /// 12pt — body text
        public static let body: CGFloat = 12
        /// 13pt — default system
        public static let base: CGFloat = 13
        /// 14pt — body emphasis
        public static let bodyLarge: CGFloat = 14
        /// 18pt — section titles
        public static let title: CGFloat = 18
        /// 40pt — hero/empty state
        public static let hero: CGFloat = 40
    }

    // MARK: Convenience

    /// Monospaced font for code/OCR
    public static func mono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }

    /// Regular weight
    public static func regular(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }

    /// Medium weight
    public static func medium(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium)
    }

    /// Semibold weight
    public static func semibold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// Bold weight
    public static func bold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }
}

// MARK: - Capsule Pill

public struct Pill: ViewModifier {
    let color: Color
    let fill: Bool

    public func body(content: Content) -> some View {
        content
            .font(.system(size: Typography.Size.small, weight: .medium))
            .foregroundColor(fill ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(fill ? color : color.opacity(0.12))
            .clipShape(Capsule())
    }
}

extension View {
    public func pill(_ color: Color = Color.accentColor, fill: Bool = false) -> some View {
        modifier(Pill(color: color, fill: fill))
    }
}

// MARK: - Caption Style

public struct Caption: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(.system(size: Typography.Size.caption))
            .foregroundColor(.textSecondary)
    }
}

extension View {
    public func captionStyle() -> some View {
        modifier(Caption())
    }
}
