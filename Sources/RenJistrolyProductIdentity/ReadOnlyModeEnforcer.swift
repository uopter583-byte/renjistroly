import Foundation
import RenJistrolyModels

/// 只读模式强制 — 安全模式下禁止所有写操作
@MainActor @Observable
public final class ReadOnlyModeEnforcer {
    public static let shared = ReadOnlyModeEnforcer()

    public enum Level: Int, Sendable, Comparable {
        case disabled = 0
        case warning = 1
        case strict = 2

        public static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public var title: String {
            switch self {
            case .disabled: "禁用"
            case .warning: "警告"
            case .strict: "严格"
            }
        }
    }

    public var level: Level = .disabled

    private let writeActions: Set<MacActionKind> = [
        .insertText, .setFocusedText, .clickElement, .setElementText,
        .clickAt, .doubleClickAt, .rightClickAt, .scroll, .drag,
        .closeWindow, .minimizeWindow,
        .deleteFile, .runShellCommand, .sendMessage,
        .openTerminalCommand,
    ]

    public func evaluate(_ action: MacAction) -> PolicyDecision {
        guard writeActions.contains(action.kind) else { return .allow }

        switch level {
        case .disabled:
            return .allow
        case .warning:
            return .requireConfirmation("只读模式：\(action.humanPreview)")
        case .strict:
            return .deny("只读模式禁止写操作：\(action.humanPreview)")
        }
    }

    public func isReadOnly(_ kind: MacActionKind) -> Bool {
        !writeActions.contains(kind)
    }
}
