import Foundation

public enum ActionRiskLevel: Int, Sendable, Codable, Comparable {
    case readOnly = 0
    case reversibleInput = 1
    case persistentOrExternal = 2
    case destructiveOrSensitive = 3

    public static func < (lhs: ActionRiskLevel, rhs: ActionRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var title: String {
        switch self {
        case .readOnly: "只读"
        case .reversibleInput: "可撤销输入"
        case .persistentOrExternal: "持久或外部影响"
        case .destructiveOrSensitive: "破坏性或敏感"
        }
    }
}

public enum MacActionKind: Sendable, Codable, Equatable {
    case readContext
    case insertText
    case setFocusedText
    case clickElement
    case setElementText
    case pressShortcut
    case clickFocused
    case clickAt
    case doubleClickAt
    case rightClickAt
    case scroll
    case drag
    case openApplication
    case quitApplication
    case hideApplication
    case closeWindow
    case minimizeWindow
    case openURL
    case openFileOrFolder
    case openTerminalAtPath
    case openTerminalCommand
    case focusWeChatMessageInput
    case copySelectedText
    case readFocusedText
    case sendMessage
    case deleteFile
    case runShellCommand
}

public struct MacAction: Identifiable, Sendable, Codable, Equatable {
    public let id: UUID
    public let kind: MacActionKind
    public let payload: [String: String]
    public let riskLevel: ActionRiskLevel
    public let humanPreview: String

    public init(
        id: UUID = UUID(),
        kind: MacActionKind,
        payload: [String: String] = [:],
        riskLevel: ActionRiskLevel,
        humanPreview: String
    ) {
        self.id = id
        self.kind = kind
        self.payload = payload
        self.riskLevel = riskLevel
        self.humanPreview = humanPreview
    }
}

public enum PolicyDecision: Sendable, Equatable {
    case allow
    case requireConfirmation(String)
    case deny(String)
    case developerModeOnly(String)
}

public struct ActionResult: Sendable, Equatable {
    public let actionID: UUID
    public let success: Bool
    public let message: String

    public init(actionID: UUID, success: Bool, message: String) {
        self.actionID = actionID
        self.success = success
        self.message = message
    }
}
