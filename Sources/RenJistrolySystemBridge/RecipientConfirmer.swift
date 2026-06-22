import Foundation

/// 收件人确认 — 发合同前验证收件人信息
public struct RecipientConfirmer: Sendable {
    public enum ConfirmStatus: String, Sendable {
        case confirmed, mismatched, missingContact
    }

    public struct Recipient: Sendable {
        public let name: String
        public let email: String
        public let organization: String?
    }

    /// 检查目标收件人是否与预期匹配
    public func confirm(recipient: Recipient, expected: Recipient) -> ConfirmStatus {
        guard !recipient.name.trimmingCharacters(in: .whitespaces).isEmpty,
              !recipient.email.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .missingContact
        }
        let nameMatch = recipient.name.lowercased() == expected.name.lowercased()
        let emailMatch = recipient.email.lowercased() == expected.email.lowercased()
        return nameMatch && emailMatch ? .confirmed : .mismatched
    }
}
