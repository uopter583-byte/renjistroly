import Foundation
import XCTest
@testable import RenJistrolyEnterprise

// MARK: - Action Engine Performance Benchmarks

@MainActor
final class ActionEngineBenchmarks: PerformanceTestBase {

    private var engine = ActionEngine()

    override func thresholds() -> [String: BenchmarkThreshold] {
        [
            "actionCreate": .max(0.001),       // < 1 ms
            "actionLifecycle": .max(0.005),    // < 5 ms for full lifecycle
            "auditQuery": .max(0.002),         // < 2 ms for 1000 records
            "highConcurrency": .max(0.05),     // < 50 ms for 200 concurrent ops
            "bulkCreate": .max(0.01),          // < 10 ms for 100 creates
            "historyQuery": .max(0.001),       // < 1 ms
            "statusChangeCallback": .max(0.01),// < 10 ms with callback
        ]
    }

    // MARK: - Action creation

    func testCreateAction() {
        _ = measureBlock(name: "actionCreate", iterations: 20) {
            _ = engine.create(type: "click", preview: "Click OK button", riskLevel: .low)
        }
        assertBenchPassed("actionCreate")
    }

    func testBulkCreateActions() {
        _ = measureBlock(name: "bulkCreate", iterations: 5) {
            for i in 0 ..< 100 {
                _ = engine.create(
                    type: i % 2 == 0 ? "click" : "type",
                    preview: "Action \(i)",
                    riskLevel: EnterpriseRiskLevel(rawValue: i % 5) ?? .low
                )
            }
        }
        assertBenchPassed("bulkCreate")
    }

    // MARK: - Full action lifecycle (create -> approve -> start -> complete)

    func testFullActionLifecycle() {
        _ = measureBlock(name: "actionLifecycle", iterations: 20) {
            let record = engine.create(type: "click", preview: "Click OK", riskLevel: .low)
            _ = engine.approve(record.id)
            _ = engine.start(record.id)
            _ = engine.complete(record.id, result: "success")
        }
        assertBenchPassed("actionLifecycle")
    }

    func testFailedLifecycle() {
        _ = measureBlock(name: "failedLifecycle", iterations: 20) {
            let record = engine.create(type: "write", preview: "Write file", riskLevel: .high)
            _ = engine.approve(record.id)
            _ = engine.start(record.id)
            _ = engine.fail(record.id, reason: "Permission denied", recovery: "Check permissions")
        }
    }

    func testCancelledLifecycle() {
        _ = measureBlock(name: "cancelledLifecycle", iterations: 20) {
            let record = engine.create(type: "delete", preview: "Delete file", riskLevel: .critical)
            _ = engine.cancel(record.id)
        }
    }

    func testApprovalRejectionCycle() {
        _ = measureBlock(name: "approvalCycle", iterations: 20) {
            let record = engine.create(type: "exec", preview: "Run script", riskLevel: .high)
            _ = engine.reject(record.id, reason: "Not authorized")
        }
    }

    // MARK: - Audit trail queries

    func testAuditQuerySmall() {
        // Create a few records, then query audit trails
        for i in 0 ..< 10 {
            let r = engine.create(type: "op\(i)", preview: "Op \(i)", riskLevel: .low)
            _ = engine.approve(r.id)
            _ = engine.start(r.id)
            _ = engine.complete(r.id, result: "ok")
        }

        _ = measureBlock(name: "auditQuery", iterations: 20) {
            // Query all record IDs
            for recordID in engine.records.keys {
                _ = engine.getAuditTrail(recordID)
            }
        }
        assertBenchPassed("auditQuery")
    }

    func testAuditQueryManyRecords() {
        // Create 1000 records, then query audit trails
        var ids: [String] = []
        ids.reserveCapacity(1000)
        for i in 0 ..< 1000 {
            let r = engine.create(type: "op\(i)", preview: "Bulk \(i)", riskLevel: .low)
            ids.append(r.id)
        }

        _ = measureBlock(name: "auditQueryMany", iterations: 5) {
            for id in ids {
                _ = engine.getAuditTrail(id)
            }
        }
    }

    // MARK: - History queries

    func testHistoryQuery() {
        // Populate some history
        for i in 0 ..< 50 {
            let r = engine.create(type: "op\(i)", preview: "History \(i)", riskLevel: .low)
            _ = engine.approve(r.id)
            _ = engine.start(r.id)
            _ = engine.complete(r.id, result: "done")
        }

        _ = measureBlock(name: "historyQuery", iterations: 20) {
            _ = engine.getRecentHistory(limit: 50)
            _ = engine.getRecentHistory(limit: 10)
        }
        assertBenchPassed("historyQuery")
    }

    // MARK: - High concurrency

    func testHighConcurrencyCreate() {
        let engine = self.engine
        _ = measureBlock(name: "highConcurrency", iterations: 3) {
            DispatchQueue.concurrentPerform(iterations: 200) { i in
                let record = engine.create(
                    type: "concurrent",
                    preview: "Concurrent op \(i)",
                    riskLevel: EnterpriseRiskLevel(rawValue: i % 5) ?? .low
                )
                if i % 3 == 0 {
                    _ = engine.approve(record.id)
                } else if i % 3 == 1 {
                    _ = engine.reject(record.id, reason: "concurrent reject")
                }
            }
        }
        assertBenchPassed("highConcurrency")
    }

    func testConcurrentLifecycle() {
        // Mix of creates, status transitions, and queries
        let engine = self.engine
        _ = measureBlock(name: "concurrentLifecycle", iterations: 3) {
            DispatchQueue.concurrentPerform(iterations: 100) { i in
                let record = engine.create(
                    type: "lifecycle",
                    preview: "Cycle \(i)",
                    riskLevel: .low
                )
                _ = engine.approve(record.id)
                _ = engine.start(record.id)
                _ = engine.complete(record.id, result: "concurrent done")
                _ = engine.getRecord(record.id)
            }
        }
    }

    // MARK: - Status change callback overhead

    func testStatusChangeCallback() {
        var callCount = 0
        engine.onStatusChange = { _ in callCount += 1 }

        _ = measureBlock(name: "statusChangeCallback", iterations: 10) {
            let r = engine.create(type: "cb", preview: "Callback test", riskLevel: .low)
            _ = engine.approve(r.id)
            _ = engine.start(r.id)
            _ = engine.complete(r.id, result: "done")
        }
        assertBenchPassed("statusChangeCallback")
        XCTAssertGreaterThan(callCount, 0, "Callback should have been invoked")
    }

    // MARK: - Rollback

    func testRollbackPerformance() {
        _ = measureBlock(name: "rollbackAction", iterations: 10) {
            let r = engine.create(
                type: "write",
                preview: "Write file",
                riskLevel: .medium,
                rollbackAction: "delete the created file"
            )
            _ = engine.approve(r.id)
            _ = engine.start(r.id)
            _ = engine.complete(r.id, result: "written")
            _ = engine.rollback(r.id)
        }
    }
}
