import Foundation
import RenJistrolyModels

/// 高风险操作审计 — 记录所有高风险动作，支持追溯和合规
@MainActor
public final class AuditHighRiskAction {
    public static let shared = AuditHighRiskAction()

    public struct AuditRecord: Identifiable, Sendable {
        public let id: UUID
        public let action: MacAction
        public let riskLevel: ActionRiskLevel
        public let timestamp: Date
        public let context: String
        public let approved: Bool
        public let approver: String?

        public init(
            id: UUID = UUID(),
            action: MacAction,
            riskLevel: ActionRiskLevel,
            timestamp: Date = Date(),
            context: String,
            approved: Bool,
            approver: String? = nil
        ) {
            self.id = id
            self.action = action
            self.riskLevel = riskLevel
            self.timestamp = timestamp
            self.context = context
            self.approved = approved
            self.approver = approver
        }
    }

    private var auditLog: [AuditRecord] = []

    public func record(
        action: MacAction,
        context: String,
        approved: Bool,
        approver: String? = nil
    ) -> AuditRecord {
        let record = AuditRecord(
            action: action,
            riskLevel: action.riskLevel,
            context: context,
            approved: approved,
            approver: approver
        )
        auditLog.append(record)
        return record
    }

    public func recent(limit: Int = 20) -> [AuditRecord] {
        Array(auditLog.suffix(limit))
    }

    public func records(for kind: MacActionKind) -> [AuditRecord] {
        auditLog.filter { $0.action.kind == kind }
    }

    public func export() -> [AuditRecord] {
        auditLog
    }

    public func clear() {
        auditLog.removeAll()
    }
}
