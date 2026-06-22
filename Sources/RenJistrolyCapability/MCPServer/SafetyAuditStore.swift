import Foundation
import RenJistrolyModels

public actor SafetyAuditStore {
    private var records: [SafetyAuditRecord] = []

    public init() {}

    @discardableResult
    public func record(
        assessment: ToolRiskAssessment,
        decision: SafetyAuditRecord.Decision,
        note: String? = nil
    ) -> SafetyAuditRecord {
        let record = SafetyAuditRecord(assessment: assessment, decision: decision, note: note)
        records.append(record)
        return record
    }

    public func recent(limit: Int = 100) -> [SafetyAuditRecord] {
        Array(records.suffix(max(limit, 0))).reversed()
    }

    public func clear() {
        records.removeAll()
    }
}
