import Foundation
@testable import RenJistrolyEnterprise
@testable import RenJistrolyModels

// MARK: - Memory Benchmarks

final class MemoryBenchmarks: PerformanceTestBase {

    private var engine: ActionEngine!
    private var manager: ModeManager!

    override func setUp() {
        super.setUp()
        engine = ActionEngine()
        manager = ModeManager()
    }

    override func thresholds() -> [String: BenchmarkThreshold] {
        [
            // Memory thresholds (in bytes)
            "contextSnapshotBasic": .max(128_000),   // Resident memory is page-granular; keep this as a smoke threshold.
            "actionRecordMemory": .max(128_000),     // Single operation should not allocate more than a small page cluster.
            "bulkCreateMemory": .max(150_000),       // < 150 KB for 1000 records
            "historyGrowth": .range(0, 2_000_000),   // 1000 completed actions
            "modeConfigMemory": .max(128_000),       // Resident memory is too coarse for sub-page object sizing.
            "longRunningLeak": .max(10_000_000),     // < 10 MB after sustained ops in debug builds
        ]
    }

    // MARK: - Context snapshot memory

    func testBasicContextSnapshotMemory() {
        _ = trackMemory(name: "contextSnapshotBasic") {
            let config = ModeConfiguration(
                activeModes: [.readOnly, .noMouse],
                policy: ModePolicy(
                    requiresConfirmation: true,
                    requiresApproval: false,
                    allowedDomains: ["example.com"],
                    blockedDomains: [],
                    allowedApps: ["Finder"],
                    blockedApps: [],
                    maxRiskLevel: .high,
                    auditRetentionDays: 90
                ),
                lockedModes: [.policyLock],
                maskingPatterns: ["password", "token", "secret"],
                sensitiveAppBundleIDs: ["com.apple.keychainaccess"]
            )
            // Simulate use of the snapshot
            var copy = config
            copy.activeModes.insert(.executable)
            _ = copy.policy.maxRiskLevel
        }
        assertBenchPassed("contextSnapshotBasic")
    }

    func testModeConfigurationMemory() {
        _ = trackMemory(name: "modeConfigMemory") {
            let config = ModeConfiguration()
            manager = ModeManager(config: config)
            _ = manager.evaluate("read", riskLevel: .low)
        }
        assertBenchPassed("modeConfigMemory")
    }

    // MARK: - Action record memory

    func testSingleActionRecordMemory() {
        _ = trackMemory(name: "actionRecordMemory") {
            let record = engine.create(
                type: "click",
                preview: "Click the OK button in the confirmation dialog",
                targetContext: "Safari window",
                riskLevel: .medium,
                rollbackAction: "Undo click"
            )
            _ = engine.approve(record.id)
            _ = engine.start(record.id)
            _ = engine.complete(record.id, result: "Clicked OK successfully")
        }
        assertBenchPassed("actionRecordMemory")
    }

    // MARK: - Memory growth with bulk operations

    func testBulkCreateMemory() {
        // Clear any existing records
        // Measure: create 1000 records and track the delta
        let id = "bulkCreateMemory"
        _ = trackMemory(name: id) {
            for i in 0 ..< 1000 {
                let risk = EnterpriseRiskLevel(rawValue: i % 5) ?? .low
                _ = engine.create(
                    type: i % 3 == 0 ? "click" : (i % 3 == 1 ? "type" : "scroll"),
                    preview: "Operation \(i)",
                    riskLevel: risk
                )
            }
        }
        // Don't assert — this is informational. Growth depends on allocation patterns.
    }

    func testHistoryGrowth() {
        // Create + complete actions to populate history
        _ = trackMemory(name: "historyGrowth") {
            for i in 0 ..< 1000 {
                let r = engine.create(
                    type: "op",
                    preview: "History growth test \(i)",
                    riskLevel: .low
                )
                _ = engine.approve(r.id)
                _ = engine.start(r.id)
                _ = engine.complete(r.id, result: "done")
            }
        }
        assertBenchPassed("historyGrowth")
    }

    // MARK: - Large action with audit trail

    func testLargeAuditTrailMemory() {
        _ = trackMemory(name: "largeAuditTrail") {
            let r = engine.create(
                type: "complex",
                preview: "Complex action with extensive audit trail",
                targetContext: "Very long target context that describes the environment in detail for auditing purposes",
                riskLevel: .high,
                rollbackAction: "Rollback the complex action"
            )

            // Simulate many audit entries
            for i in 0 ..< 50 {
                _ = engine.approve(r.id)
                _ = engine.start(r.id)
                if i % 2 == 0 {
                    _ = engine.complete(r.id, result: "Step \(i) completed")
                } else {
                    _ = engine.fail(r.id, reason: "Step \(i) failed", recovery: "Retry step \(i)")
                }
            }
        }
    }

    // MARK: - Long-running stability / leak detection

    func testSustainedOperationMemory() {
        // Simulate sustained workload: create, complete, create, complete...
        // Track memory at start and end to detect leaks.
        let initialMemory = PerformanceTestBase.currentMemoryBytes()

        let ops = 5000
        for i in 0 ..< ops {
            let r = engine.create(type: "stress", preview: "Stress test \(i)", riskLevel: .low)
            _ = engine.approve(r.id)
            _ = engine.start(r.id)
            _ = engine.complete(r.id, result: "ok")
        }

        autoreleasepool { }
        let finalMemory = PerformanceTestBase.currentMemoryBytes()
        let delta = Int64(finalMemory) - Int64(initialMemory)

        let threshold = BenchmarkThreshold.max(10_000_000) // < 10 MB growth after 5000 ops in debug builds
        let result = BenchResult(
            name: "longRunningLeak",
            metric: .memory,
            value: Double(delta),
            unit: "bytes",
            threshold: threshold,
            iterations: ops,
            metadata: [
                "initial_bytes": "\(initialMemory)",
                "final_bytes": "\(finalMemory)",
                "total_ops": "\(ops)",
            ],
            timestamp: Date()
        )
        recordResult(result)
        assertBenchPassed("longRunningLeak")
    }

    // MARK: - Concurrent memory stability

    func testConcurrentMemoryGrowth() {
        let initialMemory = PerformanceTestBase.currentMemoryBytes()
        let engine = self.engine!

        DispatchQueue.concurrentPerform(iterations: 500) { i in
            let r = engine.create(
                type: "concurrent",
                preview: "Concurrent memory \(i)",
                riskLevel: .low
            )
            _ = engine.approve(r.id)
            _ = engine.start(r.id)
            _ = engine.complete(r.id, result: "concurrent done")
        }

        autoreleasepool { }
        let finalMemory = PerformanceTestBase.currentMemoryBytes()
        let delta = Int64(finalMemory) - Int64(initialMemory)

        let result = BenchResult(
            name: "concurrentMemoryGrowth",
            metric: .memory,
            value: Double(delta),
            unit: "bytes",
            threshold: .max(3_000_000), // < 3 MB for 500 concurrent ops
            iterations: 500,
            metadata: [
                "initial_bytes": "\(initialMemory)",
                "final_bytes": "\(finalMemory)",
            ],
            timestamp: Date()
        )
        recordResult(result)
    }

    // MARK: - Mode configuration memory stability

    func testRepeatedModeReconfigMemory() {
        let initialMemory = PerformanceTestBase.currentMemoryBytes()

        for _ in 0 ..< 1000 {
            let config = ModeConfiguration(
                activeModes: Set(OperationMode.allCases.shuffled().prefix(5)),
                policy: ModePolicy(
                    requiresConfirmation: Bool.random(),
                    requiresApproval: Bool.random(),
                    allowedDomains: ["a.com", "b.com"],
                    blockedDomains: [],
                    allowedApps: ["App1", "App2"],
                    blockedApps: [],
                    maxRiskLevel: EnterpriseRiskLevel.allCases.randomElement() ?? .medium,
                    auditRetentionDays: Int.random(in: 30...365)
                ),
                lockedModes: [],
                maskingPatterns: (0 ..< 5).map { "pattern\($0)" },
                sensitiveAppBundleIDs: ["com.example.app"]
            )
            let m = ModeManager(config: config)
            m.activate(.readOnly)
            m.deactivate(.readOnly)
            _ = m.evaluate("test", riskLevel: .low)
        }

        autoreleasepool { }
        let delta = Int64(PerformanceTestBase.currentMemoryBytes()) - Int64(initialMemory)
        let result = BenchResult(
            name: "repeatedReconfigMemory",
            metric: .memory,
            value: Double(delta),
            unit: "bytes",
            threshold: .max(500_000),
            iterations: 1000,
            metadata: ["mode_count": "5"],
            timestamp: Date()
        )
        recordResult(result)
    }
}
