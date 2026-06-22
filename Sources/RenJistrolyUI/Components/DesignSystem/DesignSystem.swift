import SwiftUI

// MARK: - Design Tokens

public enum DS {
    public enum Spacing {
        /// 2pt — micro
        public static let micro: CGFloat = 2
        /// 4pt — xxs
        public static let xxs: CGFloat = 4
        /// 8pt — xs
        public static let xs: CGFloat = 8
        /// 12pt — sm
        public static let sm: CGFloat = 12
        /// 16pt — md
        public static let md: CGFloat = 16
        /// 20pt — lg
        public static let lg: CGFloat = 20
        /// 24pt — xl
        public static let xl: CGFloat = 24
        /// 32pt — xxl
        public static let xxl: CGFloat = 32
    }

    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 14
        public static let xl: CGFloat = 20
    }

    public enum Animation {
        public static let fast: Double = 0.15
        public static let normal: Double = 0.25
        public static let slow: Double = 0.35
    }
}

// MARK: - DividerLine

public struct DividerLine: View {
    let color: Color

    public init(color: Color = .borderSubtle) {
        self.color = color
    }

    public var body: some View {
        color.frame(height: 1)
    }
}

// MARK: - Card

public struct Card<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(DS.Spacing.sm)
            .background(Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .elevation(Elevation.z1)
    }
}

// MARK: - LabeledRow

public struct LabeledRow: View {
    let label: String
    let value: String
    let valueColor: Color?

    public init(label: String, value: String, valueColor: Color? = nil) {
        self.label = label
        self.value = value
        self.valueColor = valueColor
    }

    public var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(label)
                .font(.system(size: Typography.Size.caption))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: Typography.Size.small, weight: .medium))
                .foregroundColor(valueColor ?? .textPrimary)
        }
    }
}

// MARK: - Glass Panel

public struct GlassPanel<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}

// MARK: - Accent Button

public struct AccentButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    public init(title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs + 2)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
}

// MARK: - Toolbar Icon Button

public struct IconButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    public init(icon: String, label: String, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

// MARK: - Status Dot

public struct StatusDot: View {
    let color: Color
    let pulsing: Bool

    public init(color: Color, pulsing: Bool = false) {
        self.color = color
        self.pulsing = pulsing
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .scaleEffect(pulsing ? 1.3 : 1.0)
            .opacity(pulsing ? 0.7 : 1.0)
            .animation(
                pulsing ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                value: pulsing
            )
    }
}

// MARK: - Section Header

public struct SectionHeader: View {
    let title: String
    let icon: String

    public init(title: String, icon: String) {
        self.title = title
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
        }
    }
}

// MARK: - Badge

public struct Badge: View {
    let text: String
    let color: Color

    public init(text: String, color: Color = .secondary) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(color.opacity(0.9))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}
