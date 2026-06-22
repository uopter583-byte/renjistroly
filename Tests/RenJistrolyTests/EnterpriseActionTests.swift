import XCTest
@testable import RenJistrolyEnterprise

final class EnterpriseRiskLevelTests: XCTestCase {
    func testEnterpriseRiskLevel_ordering() {
        XCTAssertLessThan(EnterpriseRiskLevel.trivial, EnterpriseRiskLevel.low)
        XCTAssertLessThan(EnterpriseRiskLevel.low, EnterpriseRiskLevel.medium)
        XCTAssertLessThan(EnterpriseRiskLevel.medium, EnterpriseRiskLevel.high)
        XCTAssertLessThan(EnterpriseRiskLevel.high, EnterpriseRiskLevel.critical)
    }

    func testEnterpriseRiskLevel_titles() {
        XCTAssertEqual(EnterpriseRiskLevel.trivial.title, "无风险")
        XCTAssertEqual(EnterpriseRiskLevel.low.title, "低风险")
        XCTAssertEqual(EnterpriseRiskLevel.medium.title, "中风险")
        XCTAssertEqual(EnterpriseRiskLevel.high.title, "高风险")
        XCTAssertEqual(EnterpriseRiskLevel.critical.title, "严重风险")
    }

    func testEnterpriseRiskLevel_identifiable() {
        let level = EnterpriseRiskLevel.medium
        XCTAssertEqual(level.id, 2)
    }

    func testEnterpriseRiskLevel_rawValues() {
        XCTAssertEqual(EnterpriseRiskLevel.trivial.rawValue, 0)
        XCTAssertEqual(EnterpriseRiskLevel.critical.rawValue, 4)
    }
}

final class ActionStatusTests: XCTestCase {
    func testActionStatus_rawValues() {
        XCTAssertEqual(ActionStatus.pending.rawValue, "pending")
        XCTAssertEqual(ActionStatus.approved.rawValue, "approved")
        XCTAssertEqual(ActionStatus.rejected.rawValue, "rejected")
        XCTAssertEqual(ActionStatus.executing.rawValue, "executing")
        XCTAssertEqual(ActionStatus.completed.rawValue, "completed")
        XCTAssertEqual(ActionStatus.failed.rawValue, "failed")
        XCTAssertEqual(ActionStatus.cancelled.rawValue, "cancelled")
        XCTAssertEqual(ActionStatus.rolledBack.rawValue, "rolledBack")
    }
}

final class AuditEntryTests: XCTestCase {
    func testAuditEntry_init() {
        let entry = AuditEntry(event: "created", detail: "test action")
        XCTAssertFalse(entry.id.isEmpty)
        XCTAssertEqual(entry.event, "created")
        XCTAssertEqual(entry.detail, "test action")
    }

    func testAuditEntry_equality() {
        let timestamp = Date()
        let a = AuditEntry(id: "1", timestamp: timestamp, event: "test", detail: "detail")
        let b = AuditEntry(id: "1", timestamp: timestamp, event: "test", detail: "detail")
        XCTAssertEqual(a, b)
    }

    func testAuditEntry_identifiable() {
        let entry = AuditEntry(event: "test")
        XCTAssertEqual(entry.id, entry.id)
    }
}

final class ActionRecordTests: XCTestCase {
    func testActionRecord_defaultStatus() {
        let record = ActionRecord(type: "click", preview: "click OK button")
        XCTAssertEqual(record.status, .pending)
        XCTAssertEqual(record.type, "click")
        XCTAssertEqual(record.preview, "click OK button")
    }

    func testActionRecord_fullInit() {
        let record = ActionRecord(
            type: "delete",
            preview: "delete file.txt",
            targetContext: "/tmp",
            riskLevel: .critical,
            status: .approved,
            result: "success",
            verificationEvidence: "/tmp/evidence.png",
            failureReason: nil,
            recoverySuggestion: nil,
            rollbackAction: "undo delete",
            auditTrail: [AuditEntry(event: "created", detail: "created")]
        )
        XCTAssertEqual(record.type, "delete")
        XCTAssertEqual(record.riskLevel, .critical)
        XCTAssertEqual(record.status, .approved)
        XCTAssertEqual(record.rollbackAction, "undo delete")
    }

    func testActionRecord_statusTransition() {
        var record = ActionRecord(type: "test", preview: "test")
        record.status = .completed
        record.result = "done"
        record.completedAt = Date()
        XCTAssertEqual(record.status, .completed)
        XCTAssertEqual(record.result, "done")
        XCTAssertNotNil(record.completedAt)
    }

    func testActionRecord_identifiable() {
        let record = ActionRecord(type: "test", preview: "test")
        XCTAssertEqual(record.id, record.id)
    }

    func testActionRecord_cancelledAt() {
        var record = ActionRecord(type: "test", preview: "test")
        record.status = .cancelled
        record.cancelledAt = Date()
        XCTAssertEqual(record.status, .cancelled)
        XCTAssertNotNil(record.cancelledAt)
    }

    func testActionRecord_auditTrailAppend() {
        var record = ActionRecord(type: "test", preview: "test")
        record.auditTrail.append(AuditEntry(event: "approved", detail: "by user"))
        XCTAssertEqual(record.auditTrail.count, 1)
    }
}

@MainActor
final class ActionEngineTests: XCTestCase {
    func testActionEngine_init() {
        let engine = ActionEngine()
        XCTAssertTrue(engine.records.isEmpty)
        XCTAssertTrue(engine.history.isEmpty)
    }

    func testActionEngine_create() {
        let engine = ActionEngine()
        let record = engine.create(type: "click", preview: "click save")
        XCTAssertEqual(record.status, .pending)
        XCTAssertEqual(record.auditTrail.count, 1)
        XCTAssertEqual(record.auditTrail.first?.event, "created")
    }

    func testActionEngine_createWithFullDetails() {
        let engine = ActionEngine()
        let record = engine.create(type: "delete", preview: "delete file", targetContext: "/tmp", riskLevel: .high, rollbackAction: "restore")
        XCTAssertEqual(record.riskLevel, .high)
        XCTAssertEqual(record.rollbackAction, "restore")
    }

    func testActionEngine_lifecycle() {
        let engine = ActionEngine()
        let record = engine.create(type: "click", preview: "click")
        let id = record.id

        XCTAssertTrue(engine.approve(id))
        let approved = engine.getRecord(id)
        XCTAssertEqual(approved?.status, .approved)

        XCTAssertTrue(engine.start(id))
        let started = engine.getRecord(id)
        XCTAssertEqual(started?.status, .executing)

        XCTAssertTrue(engine.complete(id, result: "done", evidence: "verified"))
        let completed = engine.getRecord(id)
        XCTAssertEqual(completed?.status, .completed)
        XCTAssertEqual(completed?.result, "done")
        XCTAssertEqual(completed?.verificationEvidence, "verified")
    }

    func testActionEngine_approve_failsWhenNotPending() {
        let engine = ActionEngine()
        let record = engine.create(type: "test", preview: "test")
        engine.approve(record.id)
        // Second approve should fail since status is now .approved
        XCTAssertFalse(engine.approve(record.id))
    }

    func testActionEngine_reject() {
        let engine = ActionEngine()
        let record = engine.create(type: "test", preview: "test")
        XCTAssertTrue(engine.reject(record.id, reason: "not needed"))
        let rejected = engine.getRecord(record.id)
        XCTAssertEqual(rejected?.status, .rejected)
    }

    func testActionEngine_reject_failsIfNotPending() {
        let engine = ActionEngine()
        let record = engine.create(type: "test", preview: "test")
        engine.approve(record.id)
        XCTAssertFalse(engine.reject(record.id))
    }

    func testActionEngine_start_failsIfPendingOnly() {
        let engine = ActionEngine()
        let record = engine.create(type: "test", preview: "test")
        // Can start from pending
        XCTAssertTrue(engine.start(record.id))
        // Cannot start again
        XCTAssertFalse(engine.start(record.id))
    }

    func testActionEngine_complete_failsIfNotExecuting() {
        let engine = ActionEngine()
        let record = engine.create(type: "test", preview: "test")
        XCTAssertFalse(engine.complete(record.id, result: "done"))
    }

    func testActionEngine_fail() {
        let engine = ActionEngine()
        let record = engine.create(type: "test", preview: "test")
        XCTAssertTrue(engine.approve(record.id))
        XCTAssertTrue(engine.start(record.id))
        XCTAssertTrue(engine.fail(record.id, reason: "crash", recovery: "retry"))
        let failed = engine.getRecord(record.id)
        XCTAssertEqual(failed?.status, .failed)
        XCTAssertEqual(failed?.failureReason, "crash")
        XCTAssertEqual(failed?.recoverySuggestion, "retry")
    }

    func testActionEngine_fail_failsIfNotExecuting() {
        let engine = ActionEngine()
        let record = engine.create(type: "test", preview: "test")
        XCTAssertFalse(engine.fail(record.id, reason: "error"))
    }

    func testActionEngine_cancel() {
        let engine = ActionEngine()
        let record = engine.create(type: "test", preview: "test")
        XCTAssertTrue(engine.cancel(record.id))
        let cancelled = engine.getRecord(record.id)
        XCTAssertEqual(cancelled?.status, .cancelled)
        XCTAssertNotNil(cancelled?.cancelledAt)
    }

    func testActionEngine_cancel_failsIfCompleted() {
        let engine = ActionEngine()
        let record = engine.create(type: "test", preview: "test")
        engine.approve(record.id)
        engine.start(record.id)
        engine.complete(record.id, result: "done")
        XCTAssertFalse(engine.cancel(record.id))
    }

    func testActionEngine_rollback() {
        let engine = ActionEngine()
        let record = engine.create(type: "test", preview: "test", rollbackAction: "undo")
        let id = record.id
        engine.approve(id)
        engine.start(id)
        let rollback = engine.rollback(id)
        XCTAssertEqual(rollback, "undo")
        let rolled = engine.getRecord(id)
        XCTAssertEqual(rolled?.status, .rolledBack)
    }

    func testActionEngine_rollback_nilWhenNoRollbackAction() {
        let engine = ActionEngine()
        let record = engine.create(type: "test", preview: "test")
        let rollback = engine.rollback(record.id)
        XCTAssertNil(rollback)
    }

    func testActionEngine_getRecord_notFound() {
        let engine = ActionEngine()
        XCTAssertNil(engine.getRecord("nonexistent"))
    }

    func testActionEngine_getRecentHistory() {
        let engine = ActionEngine()
        let r1 = engine.create(type: "a", preview: "a")
        engine.approve(r1.id)
        engine.start(r1.id)
        engine.complete(r1.id, result: "done")
        let history = engine.getRecentHistory(limit: 10)
        XCTAssertEqual(history.count, 1)
    }

    func testActionEngine_getAuditTrail() {
        let engine = ActionEngine()
        let record = engine.create(type: "test", preview: "test")
        let trail = engine.getAuditTrail(record.id)
        XCTAssertEqual(trail.count, 1)
        XCTAssertEqual(trail.first?.event, "created")
    }

    func testActionEngine_getAuditTrail_nonexistent() {
        let engine = ActionEngine()
        let trail = engine.getAuditTrail("fake")
        XCTAssertTrue(trail.isEmpty)
    }

    func testActionEngine_onStatusChange() {
        let engine = ActionEngine()
        var changedId: String?
        engine.onStatusChange = { record in
            changedId = record.id
        }
        let record = engine.create(type: "test", preview: "test")
        engine.approve(record.id)
        XCTAssertEqual(changedId, record.id)
    }
}
