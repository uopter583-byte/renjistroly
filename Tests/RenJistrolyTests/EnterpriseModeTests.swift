import XCTest
@testable import RenJistrolyEnterprise

final class OperationModeTests: XCTestCase {
    func testOperationMode_allCases() {
        let modes = OperationMode.allCases
        XCTAssertTrue(modes.contains(.readOnly))
        XCTAssertTrue(modes.contains(.executable))
        XCTAssertTrue(modes.contains(.highRisk))
        XCTAssertTrue(modes.contains(.autoMask))
        XCTAssertTrue(modes.contains(.policyLock))
    }

    func testOperationMode_titles() {
        XCTAssertEqual(OperationMode.readOnly.title, "只读")
        XCTAssertEqual(OperationMode.suggest.title, "建议")
        XCTAssertEqual(OperationMode.executable.title, "可执行")
        XCTAssertEqual(OperationMode.noMouse.title, "禁止鼠标")
        XCTAssertEqual(OperationMode.localOnly.title, "本地模式")
    }

    func testOperationMode_descriptions() {
        XCTAssertTrue(OperationMode.readOnly.description.contains("拦截"))
        XCTAssertTrue(OperationMode.executable.description.contains("执行"))
        XCTAssertTrue(OperationMode.highRisk.description.contains("确认"))
    }

    func testOperationMode_identifiable() {
        for mode in OperationMode.allCases {
            XCTAssertEqual(mode.id, mode.rawValue)
        }
    }

    func testOperationMode_rawValues() {
        XCTAssertEqual(OperationMode.readOnly.rawValue, "readOnly")
        XCTAssertEqual(OperationMode.suggest.rawValue, "suggest")
    }
}

final class ModePolicyTests: XCTestCase {
    func testModePolicy_default() {
        let policy = ModePolicy.default
        XCTAssertFalse(policy.requiresConfirmation)
        XCTAssertFalse(policy.requiresApproval)
        XCTAssertTrue(policy.allowedDomains.isEmpty)
        XCTAssertEqual(policy.maxRiskLevel, .critical)
        XCTAssertEqual(policy.auditRetentionDays, 90)
    }

    func testModePolicy_locked() {
        let policy = ModePolicy.locked
        XCTAssertTrue(policy.requiresConfirmation)
        XCTAssertTrue(policy.requiresApproval)
        XCTAssertEqual(policy.maxRiskLevel, .low)
        XCTAssertEqual(policy.auditRetentionDays, 365)
    }

    func testModePolicy_custom() {
        let policy = ModePolicy(
            requiresConfirmation: true,
            requiresApproval: false,
            allowedDomains: ["example.com"],
            blockedDomains: ["bad.com"],
            allowedApps: ["Safari"],
            blockedApps: ["Terminal"],
            maxRiskLevel: .medium,
            auditRetentionDays: 180
        )
        XCTAssertTrue(policy.requiresConfirmation)
        XCTAssertEqual(policy.allowedDomains, ["example.com"])
        XCTAssertEqual(policy.blockedDomains, ["bad.com"])
        XCTAssertEqual(policy.maxRiskLevel, .medium)
    }

    func testModePolicy_equality() {
        let a = ModePolicy.default
        let b = ModePolicy.default
        XCTAssertEqual(a, b)
    }

    func testModePolicy_codable() throws {
        let policy = ModePolicy.default
        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(ModePolicy.self, from: data)
        XCTAssertEqual(policy, decoded)
    }
}

final class ModeConfigurationTests: XCTestCase {
    func testModeConfiguration_default() {
        let config = ModeConfiguration()
        XCTAssertTrue(config.activeModes.isEmpty)
        XCTAssertEqual(config.policy, .default)
        XCTAssertTrue(config.lockedModes.isEmpty)
        XCTAssertTrue(config.maskingPatterns.isEmpty)
    }

    func testModeConfiguration_custom() {
        let config = ModeConfiguration(
            activeModes: [.readOnly, .noMouse],
            policy: ModePolicy.locked,
            lockedModes: [.policyLock],
            maskingPatterns: ["password"],
            sensitiveAppBundleIDs: ["com.apple.Safari"]
        )
        XCTAssertEqual(config.activeModes, [.readOnly, .noMouse])
        XCTAssertEqual(config.policy, .locked)
        XCTAssertEqual(config.lockedModes, [.policyLock])
    }

    func testModeConfiguration_codable() throws {
        let config = ModeConfiguration(activeModes: [.readOnly])
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ModeConfiguration.self, from: data)
        XCTAssertEqual(config, decoded)
    }
}

@MainActor
final class ModeManagerTests: XCTestCase {
    func testModeManager_init() {
        let manager = ModeManager()
        XCTAssertTrue(manager.config.activeModes.isEmpty)
    }

    func testModeManager_activate() {
        let manager = ModeManager()
        manager.activate(.readOnly)
        XCTAssertTrue(manager.isActive(.readOnly))
    }

    func testModeManager_deactivate() {
        let manager = ModeManager()
        manager.activate(.readOnly)
        manager.deactivate(.readOnly)
        XCTAssertFalse(manager.isActive(.readOnly))
    }

    func testModeManager_toggle() {
        let manager = ModeManager()
        manager.toggle(.readOnly)
        XCTAssertTrue(manager.isActive(.readOnly))
        manager.toggle(.readOnly)
        XCTAssertFalse(manager.isActive(.readOnly))
    }

    func testModeManager_lockPreventsDeactivation() {
        let manager = ModeManager()
        manager.lock(.policyLock)
        XCTAssertTrue(manager.isActive(.policyLock))
        manager.deactivate(.policyLock)
        XCTAssertTrue(manager.isActive(.policyLock))
    }

    func testModeManager_lockPreventsActivationChange() {
        let manager = ModeManager()
        manager.lock(.readOnly)
        // Locked modes have their active state set during lock
        // But deactivate should still fail
        manager.deactivate(.readOnly)
        XCTAssertTrue(manager.isActive(.readOnly))
    }

    func testModeManager_unlock() {
        let manager = ModeManager()
        manager.lock(.readOnly)
        manager.unlock(.readOnly)
        manager.deactivate(.readOnly)
        XCTAssertFalse(manager.isActive(.readOnly))
    }

    func testModeManager_setPolicy() {
        let manager = ModeManager()
        manager.setPolicy(.locked)
        XCTAssertTrue(manager.config.policy.requiresConfirmation)
    }

    func testModeManager_evaluate_readOnlyBlocksWrite() {
        let manager = ModeManager()
        manager.activate(.readOnly)
        let eval = manager.evaluate("write", riskLevel: .medium)
        XCTAssertFalse(eval.allowed)
        XCTAssertEqual(eval.blockedBy, .readOnly)
    }

    func testModeManager_evaluate_readOnlyAllowsRead() {
        let manager = ModeManager()
        manager.activate(.readOnly)
        let eval = manager.evaluate("read", riskLevel: .low)
        XCTAssertTrue(eval.allowed)
        XCTAssertNil(eval.blockedBy)
    }

    func testModeManager_evaluate_suggestBlocksAll() {
        let manager = ModeManager()
        manager.activate(.suggest)
        let eval = manager.evaluate("read", riskLevel: .low)
        XCTAssertFalse(eval.allowed)
        XCTAssertEqual(eval.blockedBy, .suggest)
    }

    func testModeManager_evaluate_noMouseBlocksMouse() {
        let manager = ModeManager()
        manager.activate(.noMouse)
        let eval = manager.evaluate("click", riskLevel: .low)
        XCTAssertFalse(eval.allowed)
        XCTAssertEqual(eval.blockedBy, .noMouse)
    }

    func testModeManager_evaluate_noMouseAllowsNonMouse() {
        let manager = ModeManager()
        manager.activate(.noMouse)
        let eval = manager.evaluate("read", riskLevel: .low)
        XCTAssertTrue(eval.allowed)
    }

    func testModeManager_evaluate_localOnlyBlocksNetwork() {
        let manager = ModeManager()
        manager.activate(.localOnly)
        let eval = manager.evaluate("fetch", riskLevel: .medium)
        XCTAssertFalse(eval.allowed)
        XCTAssertEqual(eval.blockedBy, .localOnly)
    }

    func testModeManager_evaluate_highRiskRequiresConfirmation() {
        let manager = ModeManager()
        let eval = manager.evaluate("write", riskLevel: .high)
        XCTAssertTrue(eval.requiresConfirmation)
    }

    func testModeManager_evaluate_autoMaskSetsMaskingRequired() {
        let manager = ModeManager()
        manager.activate(.autoMask)
        let eval = manager.evaluate("read", riskLevel: .low)
        XCTAssertTrue(eval.maskingRequired)
    }

    func testModeManager_evaluate_auditRequired() {
        let manager = ModeManager()
        let eval = manager.evaluate("read", riskLevel: .low)
        XCTAssertTrue(eval.auditRequired)
    }

    func testModeManager_evaluate_effectiveRiskLevel() {
        let manager = ModeManager()
        var policy = ModePolicy.default
        policy.maxRiskLevel = .medium
        manager.setPolicy(policy)
        let eval = manager.evaluate("write", riskLevel: .critical)
        XCTAssertEqual(eval.effectiveRiskLevel, .medium)
    }

    func testModeManager_evaluate_highRiskBlocksWithHighRiskMode() {
        let manager = ModeManager()
        manager.activate(.highRisk)
        let eval = manager.evaluate("click", riskLevel: .critical)
        XCTAssertFalse(eval.allowed)
        XCTAssertEqual(eval.blockedBy, .highRisk)
    }

    func testModeManager_evaluate_highRiskAllowsLowRisk() {
        let manager = ModeManager()
        manager.activate(.highRisk)
        let eval = manager.evaluate("read", riskLevel: .trivial)
        XCTAssertTrue(eval.allowed)
    }

    func testModeManager_registerHandler() {
        let manager = ModeManager()
        manager.registerHandler(for: .executable) { _, _ in false }
        manager.activate(.executable)
        let eval = manager.evaluate("read", riskLevel: .low)
        XCTAssertFalse(eval.allowed)
        XCTAssertEqual(eval.blockedBy, .executable)
    }

    func testModeManager_lockedModeStillInActiveSet() {
        let manager = ModeManager()
        manager.activate(.readOnly)
        manager.lock(.readOnly)
        XCTAssertTrue(manager.config.lockedModes.contains(.readOnly))
        XCTAssertTrue(manager.isActive(.readOnly))
    }
}

final class ModeEvaluationTests: XCTestCase {
    func testModeEvaluation_allowed() {
        let eval = ModeEvaluation(allowed: true)
        XCTAssertTrue(eval.allowed)
        XCTAssertNil(eval.blockedBy)
        XCTAssertFalse(eval.requiresConfirmation)
        XCTAssertEqual(eval.effectiveRiskLevel, .low)
    }

    func testModeEvaluation_blocked() {
        let eval = ModeEvaluation(allowed: false, blockedBy: .readOnly)
        XCTAssertFalse(eval.allowed)
        XCTAssertEqual(eval.blockedBy, .readOnly)
    }

    func testModeEvaluation_equality() {
        let a = ModeEvaluation(allowed: true, effectiveRiskLevel: .medium, maskingRequired: true, auditRequired: false)
        let b = ModeEvaluation(allowed: true, effectiveRiskLevel: .medium, maskingRequired: true, auditRequired: false)
        XCTAssertEqual(a, b)
    }

    func testModeEvaluation_blockedBySuggested() {
        let eval = ModeEvaluation(allowed: false, blockedBy: .suggest)
        XCTAssertEqual(eval.blockedBy, .suggest)
    }
}
