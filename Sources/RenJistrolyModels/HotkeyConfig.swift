import Foundation

public enum HotkeyPreset: String, CaseIterable, Identifiable, Sendable, Codable {
    case controlOptionSpace
    case optionCommandSpace
    case commandShiftSpace
    case controlSpace
    case optionSpace

    public var id: String { rawValue }

    public static var selectableCases: [HotkeyPreset] {
        [.controlOptionSpace, .optionCommandSpace, .commandShiftSpace]
    }

    public var title: String {
        switch self {
        case .controlOptionSpace: "⌃⌥Space"
        case .optionCommandSpace: "⌥⌘Space"
        case .commandShiftSpace: "⇧⌘Space"
        case .controlSpace: "⌃Space"
        case .optionSpace: "⌥Space"
        }
    }

    public var warning: String? {
        switch self {
        case .controlOptionSpace:
            nil
        case .optionCommandSpace:
            "可能与 Finder/Spotlight 搜索冲突。"
        case .commandShiftSpace:
            "少数输入法或专业软件可能占用。"
        case .controlSpace:
            "常与输入法切换冲突。"
        case .optionSpace:
            "可能影响文本输入。"
        }
    }
}

public extension Notification.Name {
    static let macVoiceHotkeyDidChange = Notification.Name("MacVoiceHotkeyDidChange")
}
