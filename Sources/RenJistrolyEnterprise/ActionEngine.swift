import Foundation
import os
import RenJistrolyModels

// MARK: - Action Status

public enum ActionStatus: String, Sendable, Codable {
    case pending
    case approved
    case rejected
    case executing
    case completed
    case failed
    case cancelled
    case rolledBack
}

// MARK: - Action Record (526-535)

public struct ActionRecord: Identifiable, Sendable, Codable {
    public let id: String
    public let type: String
    public let preview: String
    public let targetContext: String
    public let riskLevel: EnterpriseRiskLevel
    public var status: ActionStatus
    public var result: String?
    public var verificationEvidence: String?
    public var failureReason: String?
    public var recoverySuggestion: String?
    public var rollbackAction: String?
    public var auditTrail: [AuditEntry]
    public let createdAt: Date
    public var completedAt: Date?
    public var cancelledAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case preview
        case targetContext
        case riskLevel
        case status
        case result
        case verificationEvidence
        case failureReason
        case recoverySuggestion
        case rollbackAction
        case auditTrail
        case createdAt
        case completedAt
        case cancelledAt
    }

    public init(
        id: String = UUID().uuidString,
        type: String,
        preview: String,
        targetContext: String = "",
        riskLevel: EnterpriseRiskLevel = .low,
        status: ActionStatus = .pending,
        result: String? = nil,
        verificationEvidence: String? = nil,
        failureReason: String? = nil,
        recoverySuggestion: String? = nil,
        rollbackAction: String? = nil,
        auditTrail: [AuditEntry] = [],
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        cancelledAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.preview = preview
        self.targetContext = targetContext
        self.riskLevel = riskLevel
        self.status = status
        self.result = result
        self.verificationEvidence = verificationEvidence
        self.failureReason = failureReason
        self.recoverySuggestion = recoverySuggestion
        self.rollbackAction = rollbackAction
        self.auditTrail = auditTrail
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.cancelledAt = cancelledAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.type = try container.decode(String.self, forKey: .type)
        self.preview = try container.decode(String.self, forKey: .preview)
        self.targetContext = try container.decodeIfPresent(String.self, forKey: .targetContext) ?? ""
        self.riskLevel = try container.decodeIfPresent(EnterpriseRiskLevel.self, forKey: .riskLevel) ?? .low
        self.status = try container.decodeIfPresent(ActionStatus.self, forKey: .status) ?? .pending
        self.result = try container.decodeIfPresent(String.self, forKey: .result)
        self.verificationEvidence = try container.decodeIfPresent(String.self, forKey: .verificationEvidence)
        self.failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
        self.recoverySuggestion = try container.decodeIfPresent(String.self, forKey: .recoverySuggestion)
        self.rollbackAction = try container.decodeIfPresent(String.self, forKey: .rollbackAction)
        self.auditTrail = try container.decodeIfPresent([AuditEntry].self, forKey: .auditTrail) ?? []
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        self.cancelledAt = try container.decodeIfPresent(Date.self, forKey: .cancelledAt)
    }
}

// MARK: - Audit Entry

public struct AuditEntry: Identifiable, Sendable, Codable, Equatable {
    public let id: String
    public let timestamp: Date
    public let event: String
    public let detail: String

    public init(id: String = UUID().uuidString, timestamp: Date = Date(), event: String, detail: String = "") {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.detail = detail
    }
}

// MARK: - Action Risk Level

public enum EnterpriseRiskLevel: Int, CaseIterable, Identifiable, Sendable, Codable, Comparable {
    case trivial = 0
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .trivial: "无风险"
        case .low: "低风险"
        case .medium: "中风险"
        case .high: "高风险"
        case .critical: "严重风险"
        }
    }

    public static func < (lhs: EnterpriseRiskLevel, rhs: EnterpriseRiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Action Engine (526-535 lifecycle)

private struct ActionEngineState {
    var records: [String: ActionRecord] = [:]
    var history: [ActionRecord] = []
}

public final class ActionEngine: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: ActionEngineState())
    public var onStatusChange: ((ActionRecord) -> Void)?

    public var records: [String: ActionRecord] {
        lock.withLock { $0.records }
    }

    public var history: [ActionRecord] {
        lock.withLock { $0.history }
    }

    public init() {}

    public func create(
        type: String,
        preview: String,
        targetContext: String = "",
        riskLevel: EnterpriseRiskLevel = .low,
        rollbackAction: String? = nil
    ) -> ActionRecord {
        let record = ActionRecord(
            type: type,
            preview: preview,
            targetContext: targetContext,
            riskLevel: riskLevel,
            rollbackAction: rollbackAction,
            auditTrail: [AuditEntry(event: "created", detail: "Action \(type) created")]
        )
        lock.withLock { $0.records[record.id] = record }
        return record
    }

    @discardableResult
    public func approve(_ id: String) -> Bool {
        lock.withLock { state in
            guard var record = state.records[id], record.status == .pending else { return false }
            record.status = .approved
            record.auditTrail.append(AuditEntry(event: "approved", detail: "Action approved"))
            state.records[id] = record
            notify(record)
            return true
        }
    }

    @discardableResult
    public func reject(_ id: String, reason: String = "") -> Bool {
        lock.withLock { state in
            guard var record = state.records[id], record.status == .pending else { return false }
            record.status = .rejected
            record.auditTrail.append(AuditEntry(event: "rejected", detail: reason))
            state.records[id] = record
            notify(record)
            return true
        }
    }

    @discardableResult
    public func start(_ id: String) -> Bool {
        lock.withLock { state in
            guard var record = state.records[id], record.status == .approved || record.status == .pending else { return false }
            record.status = .executing
            record.auditTrail.append(AuditEntry(event: "started", detail: "Execution began"))
            state.records[id] = record
            notify(record)
            return true
        }
    }

    @discardableResult
    public func complete(_ id: String, result: String, evidence: String = "") -> Bool {
        lock.withLock { state in
            guard var record = state.records[id], record.status == .executing else { return false }
            record.status = .completed
            record.result = result
            record.verificationEvidence = evidence
            record.completedAt = Date()
            record.auditTrail.append(AuditEntry(event: "completed", detail: result))
            state.records[id] = record
            state.history.append(record)
            notify(record)
            return true
        }
    }

    @discardableResult
    public func fail(_ id: String, reason: String, recovery: String = "") -> Bool {
        lock.withLock { state in
            guard var record = state.records[id], record.status == .executing else { return false }
            record.status = .failed
            record.failureReason = reason
            record.recoverySuggestion = recovery
            record.auditTrail.append(AuditEntry(event: "failed", detail: reason))
            state.records[id] = record
            state.history.append(record)
            notify(record)
            return true
        }
    }

    @discardableResult
    public func cancel(_ id: String) -> Bool {
        lock.withLock { state in
            guard var record = state.records[id], record.status == .pending || record.status == .executing else { return false }
            record.status = .cancelled
            record.cancelledAt = Date()
            record.auditTrail.append(AuditEntry(event: "cancelled", detail: "Action cancelled"))
            state.records[id] = record
            notify(record)
            return true
        }
    }

    public func rollback(_ id: String) -> String? {
        lock.withLock { state in
            guard var record = state.records[id], let rollback = record.rollbackAction,
                  record.status == .executing || record.status == .failed || record.status == .completed else { return nil }
            record.status = .rolledBack
            record.auditTrail.append(AuditEntry(event: "rolledBack", detail: rollback))
            state.records[id] = record
            notify(record)
            return rollback
        }
    }

    public func getRecord(_ id: String) -> ActionRecord? {
        lock.withLock { state in state.records[id] }
    }

    public func getRecentHistory(limit: Int = 50) -> [ActionRecord] {
        lock.withLock { state in Array(state.history.suffix(limit)) }
    }

    public func getAuditTrail(_ id: String) -> [AuditEntry] {
        lock.withLock { state in state.records[id]?.auditTrail ?? [] }
    }

    private func notify(_ record: ActionRecord) {
        onStatusChange?(record)
    }
}
