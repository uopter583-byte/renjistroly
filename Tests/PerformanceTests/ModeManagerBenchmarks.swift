import XCTest
@testable import RenJistrolyEnterprise

// MARK: - Mode Manager Performance Benchmarks

@MainActor
final class ModeManagerBenchmarks: PerformanceTestBase {

    private var manager = ModeManager()

    override func thresholds() -> [String: BenchmarkThreshold] {
        [
            // All mode operations are in-memory, should be sub-millisecond.
            "modeSwitchSingle": .max(0.001),
            "modeSwitchBulk": .max(0.02),   // 10 modes x 100 switches
            "policyCheck": .max(0.0005),
            "concurrentSafety": .max(0.05), // 100 concurrent operations
            "evaluateAction": .max(0.0005),
            "toggleAllModes": .max(0.005),
        ]
    }

    // MARK: - Single mode switch

    func testSingleModeActivateDeactivate() {
        measure(metrics: [XCTClockMetric()]) {
            manager.activate(.readOnly)
            manager.deactivate(.readOnly)
        }
    }

    func testModeSwitchLatency() {
        // Single mode switch x 1000, measure total
        let modes = OperationMode.allCases
        _ = measureBlock(name: "modeSwitchSingle", iterations: 20) {
            for mode in modes {
                manager.activate(mode)
                manager.deactivate(mode)
            }
        }
        assertBenchPassed("modeSwitchSingle")
    }

    // MARK: - Bulk mode switching (10 modes x 100 cycles)

    func testBulkModeSwitching() {
        let modes = OperationMode.allCases
        _ = measureBlock(name: "modeSwitchBulk", iterations: 3) {
            for _ in 0 ..< 100 {
                for mode in modes {
                    manager.activate(mode)
                }
                for mode in modes.reversed() {
                    manager.deactivate(mode)
                }
            }
        }
        assertBenchPassed("modeSwitchBulk")
    }

    // MARK: - Policy check latency

    func testPolicyCheckLatency() {
        // Set up a non-trivial policy
        manager.setPolicy(ModePolicy(
            requiresConfirmation: true,
            requiresApproval: false,
            allowedDomains: ["example.com", "renjistroly.com"],
            blockedDomains: ["evil.com"],
            allowedApps: ["Finder", "Safari", "Terminal"],
            blockedApps: ["DangerApp"],
            maxRiskLevel: .high,
            auditRetentionDays: 180
        ))

        _ = measureBlock(name: "policyCheck", iterations: 20) {
            for risk in EnterpriseRiskLevel.allCases {
                _ = manager.evaluate("write", riskLevel: risk)
            }
            for risk in EnterpriseRiskLevel.allCases {
                _ = manager.evaluate("click", riskLevel: risk)
            }
        }
        assertBenchPassed("policyCheck")
    }

    func testEvaluateActionLatency() {
        // Various action types against active modes
        manager.activate(.readOnly)
        manager.activate(.noMouse)
        manager.activate(.localOnly)

        _ = measureBlock(name: "evaluateAction", iterations: 20) {
            _ = manager.evaluate("write", riskLevel: .medium)
            _ = manager.evaluate("click", riskLevel: .low)
            _ = manager.evaluate("fetch", riskLevel: .trivial)
            _ = manager.evaluate("readSensitiveApp", riskLevel: .high)
            _ = manager.evaluate("delete", riskLevel: .critical)
        }
        assertBenchPassed("evaluateAction")
    }

    // MARK: - Toggle all modes

    func testToggleAllModes() {
        // Repeatedly toggle every mode variant
        let modes = OperationMode.allCases
        _ = measureBlock(name: "toggleAllModes", iterations: 10) {
            for mode in modes {
                manager.toggle(mode)
            }
            for mode in modes {
                manager.toggle(mode)
            }
        }
        assertBenchPassed("toggleAllModes")
    }

    // MARK: - Concurrent safety

    func testConcurrentModeAccess() {
        let modes = OperationMode.allCases
        let manager = self.manager

        _ = measureBlock(name: "concurrentSafety", iterations: 5) {
            DispatchQueue.concurrentPerform(iterations: 100) { i in
                let mode = modes[i % modes.count]
                if i % 2 == 0 {
                    manager.activate(mode)
                } else {
                    manager.deactivate(mode)
                }
                _ = manager.isActive(mode)
                _ = manager.evaluate("read", riskLevel: .low)
            }
        }
        assertBenchPassed("concurrentSafety")
    }

    // MARK: - Lock/unlock modes

    func testLockUnlockPerformance() {
        let modes = OperationMode.allCases
        _ = measureBlock(name: "lockUnlock", iterations: 10) {
            for mode in modes {
                manager.lock(mode)
            }
            for mode in modes {
                manager.unlock(mode)
            }
        }
    }

    // MARK: - Custom handler registration

    func testHandlerRegistrationAndInvocation() {
        _ = measureBlock(name: "handlerRegistration", iterations: 10) {
            for mode in OperationMode.allCases {
                manager.registerHandler(for: mode) { action, risk in
                    action != "danger" && risk < .critical
                }
            }
            manager.activate(.readOnly)
            _ = manager.evaluate("danger", riskLevel: .critical)
        }
    }
}
