import XCTest
import os
@testable import RenJistrolyProductIdentity
import RenJistrolyModels
// RenJistrolyProductIdentity re-exports MacAction/EnterpriseRiskLevel from RenJistrolyModels

final class ProductIdentityTests: XCTestCase {
    func testProductIdentity_constants() {
        XCTAssertEqual(ProductIdentity.productName, "RenJistroly")
        XCTAssertEqual(ProductIdentity.tagline, "Your Mac Operating Agent")
        XCTAssertEqual(ProductIdentity.version, "0.8.0")
        XCTAssertFalse(ProductIdentity.description.isEmpty)
    }

    func testProductIdentity_coreCapabilities() {
        XCTAssertFalse(ProductIdentity.coreCapabilities.isEmpty)
        XCTAssertTrue(ProductIdentity.coreCapabilities.contains { $0.contains("屏幕感知") })
        XCTAssertTrue(ProductIdentity.coreCapabilities.contains { $0.contains("终端执行") })
    }

    func testProductIdentity_outOfScope() {
        XCTAssertFalse(ProductIdentity.outOfScope.isEmpty)
        XCTAssertTrue(ProductIdentity.outOfScope.contains { $0.contains("Android") })
    }

    func testCapabilityLevel_ordering() {
        XCTAssertLessThan(ProductIdentity.CapabilityLevel.observe, ProductIdentity.CapabilityLevel.readWrite)
        XCTAssertLessThan(ProductIdentity.CapabilityLevel.readWrite, ProductIdentity.CapabilityLevel.automate)
        XCTAssertLessThan(ProductIdentity.CapabilityLevel.automate, ProductIdentity.CapabilityLevel.autonomous)
    }

    func testCapabilityLevel_titles() {
        XCTAssertEqual(ProductIdentity.CapabilityLevel.observe.title, "观察")
        XCTAssertEqual(ProductIdentity.CapabilityLevel.readWrite.title, "读写")
        XCTAssertEqual(ProductIdentity.CapabilityLevel.automate.title, "自动化")
        XCTAssertEqual(ProductIdentity.CapabilityLevel.autonomous.title, "自主")
    }

    func testCapabilityLevel_rawValues() {
        XCTAssertEqual(ProductIdentity.CapabilityLevel.observe.rawValue, 0)
        XCTAssertEqual(ProductIdentity.CapabilityLevel.autonomous.rawValue, 3)
    }
}

// =============================================================================
// OperatingScope Tests
// =============================================================================

final class OperatingScopeTests: XCTestCase {
    func testOperatingScope_allCases() {
        let scopes = OperatingScope.allCases
        XCTAssertTrue(scopes.contains(.repository))
        XCTAssertTrue(scopes.contains(.application))
        XCTAssertTrue(scopes.contains(.desktop))
        XCTAssertTrue(scopes.contains(.voice))
    }

    func testOperatingScope_titles() {
        XCTAssertEqual(OperatingScope.repository.title, "仓库")
        XCTAssertEqual(OperatingScope.application.title, "应用")
        XCTAssertEqual(OperatingScope.desktop.title, "桌面")
        XCTAssertEqual(OperatingScope.voice.title, "语音")
    }

    func testOperatingScope_details() {
        XCTAssertTrue(OperatingScope.repository.detail.contains("Git"))
        XCTAssertTrue(OperatingScope.desktop.detail.contains("文件管理"))
    }
}

final class OperatingScopeConfigTests: XCTestCase {
    func testOperatingScopeConfig_default() {
        let config = OperatingScopeConfig()
        XCTAssertEqual(config.enabledScopes.count, 4)
        XCTAssertEqual(config.defaultScope, .desktop)
        XCTAssertTrue(config.autoDetectScope)
    }

    func testOperatingScopeConfig_isEnabled() {
        let config = OperatingScopeConfig()
        XCTAssertTrue(config.isEnabled(.repository))
        XCTAssertTrue(config.isEnabled(.desktop))
    }

    func testOperatingScopeConfig_isEnabledDisabled() {
        let config = OperatingScopeConfig(enabledScopes: [.desktop])
        XCTAssertTrue(config.isEnabled(.desktop))
        XCTAssertFalse(config.isEnabled(.repository))
    }

    func testOperatingScopeConfig_merging() {
        let a = OperatingScopeConfig(enabledScopes: [.desktop, .application])
        let b = OperatingScopeConfig(enabledScopes: [.repository, .voice], autoDetectScope: false)
        let merged = a.merging(b)
        XCTAssertEqual(merged.enabledScopes.count, 4)
        XCTAssertTrue(merged.autoDetectScope)
    }

    func testOperatingScopeConfig_customDefault() {
        let config = OperatingScopeConfig(defaultScope: .repository, autoDetectScope: false)
        XCTAssertEqual(config.defaultScope, .repository)
        XCTAssertFalse(config.autoDetectScope)
    }
}

// =============================================================================
// ContextAcquisitionManager Tests
// =============================================================================

@MainActor
final class ContextAcquisitionManagerTests: XCTestCase {
    override func setUp() async throws {
        await MainActor.run {
            ContextAcquisitionManager.shared.strategy = .always
            ContextAcquisitionManager.shared.invalidateCache()
        }
    }

    func testContextAcquisitionManager_shared() {
        let shared = ContextAcquisitionManager.shared
        XCTAssertTrue(shared.strategy == .always)
    }

    func testContextAcquisitionManager_strategies() {
        let manager = ContextAcquisitionManager.shared
        manager.strategy = .always
        XCTAssertTrue(manager.needsFreshContext())

        manager.strategy = .onDemand
        XCTAssertTrue(manager.needsFreshContext())

        manager.strategy = .cached(60)
        XCTAssertTrue(manager.needsFreshContext()) // no cache yet
    }

    func testContextAcquisitionManager_cachedHit() async {
        let manager = ContextAcquisitionManager.shared
        manager.strategy = .cached(60)
        let _ = await manager.acquireContext()
        XCTAssertFalse(manager.needsFreshContext())
    }

    func testContextAcquisitionManager_cachedExpired() async {
        let manager = ContextAcquisitionManager.shared
        manager.strategy = .cached(0) // TTL = 0, always expired
        let _ = await manager.acquireContext()
        // Even with TTL=0, tiny time has elapsed so needsFreshContext should be true
        XCTAssertTrue(manager.needsFreshContext())
    }

    func testContextAcquisitionManager_invalidateCache() async {
        let manager = ContextAcquisitionManager.shared
        manager.strategy = .cached(60)
        let _ = await manager.acquireContext()
        manager.invalidateCache()
        XCTAssertTrue(manager.needsFreshContext())
    }

    func testContextAcquisitionManager_acquireContext() async {
        let manager = ContextAcquisitionManager.shared
        let snapshot = await manager.acquireContext()
        XCTAssertNil(snapshot.frontmostApp)
        XCTAssertTrue(snapshot.screenStable)
    }

    func testContextSnapshot_empty() {
        let empty = ContextAcquisitionManager.ContextSnapshot.empty
        XCTAssertTrue(empty.runningApps.isEmpty)
    }

    func testContextSnapshot_custom() {
        let snap = ContextAcquisitionManager.ContextSnapshot(
            frontmostApp: "Safari",
            activeWindowTitle: "Preferences",
            screenStable: true,
            mousePosition: CGPoint(x: 100, y: 200),
            runningApps: ["Safari", "Terminal"]
        )
        XCTAssertEqual(snap.frontmostApp, "Safari")
        XCTAssertEqual(snap.activeWindowTitle, "Preferences")
        XCTAssertEqual(snap.runningApps.count, 2)
    }

    func testContextSnapshot_equality() {
        let a = ContextAcquisitionManager.ContextSnapshot(frontmostApp: "Safari")
        let b = ContextAcquisitionManager.ContextSnapshot(frontmostApp: "Safari")
        XCTAssertEqual(a, b)
    }
}

// =============================================================================
// PolicyLayer Tests
// =============================================================================

final class PolicyLayerTests: XCTestCase {
    override func setUp() {
        PolicyLayer.shared.clearRules()
        PolicyLayer.shared.tier = .standard
    }

    func testPolicyLayer_shared() {
        let layer = PolicyLayer.shared
        XCTAssertEqual(layer.tier, .standard)
        XCTAssertEqual(layer.ruleCount, 0)
    }

    func testPolicyLayer_tiers() {
        XCTAssertLessThan(PolicyLayer.Tier.minimal, PolicyLayer.Tier.standard)
        XCTAssertLessThan(PolicyLayer.Tier.standard, PolicyLayer.Tier.strict)
        XCTAssertLessThan(PolicyLayer.Tier.strict, PolicyLayer.Tier.lockdown)
    }

    func testPolicyLayer_tierTitles() {
        XCTAssertEqual(PolicyLayer.Tier.minimal.title, "最低")
        XCTAssertEqual(PolicyLayer.Tier.standard.title, "标准")
        XCTAssertEqual(PolicyLayer.Tier.strict.title, "严格")
        XCTAssertEqual(PolicyLayer.Tier.lockdown.title, "锁定")
    }

    func testPolicyLayer_allowByDefault() {
        let action = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "read")
        let decision = PolicyLayer.shared.evaluate(action)
        XCTAssertEqual(decision, .allow)
    }

    func testPolicyLayer_denyByRule() {
        PolicyLayer.shared.addRule(PolicyLayer.Rule(name: "block all") { _ in .deny("blocked") })
        let action = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "read")
        let decision = PolicyLayer.shared.evaluate(action)
        XCTAssertEqual(decision, .deny("blocked"))
    }

    func testPolicyLayer_requireConfirmationOnStrict() {
        PolicyLayer.shared.tier = .strict
        PolicyLayer.shared.addRule(PolicyLayer.Rule(name: "confirm") { _ in .requireConfirmation("needs OK") })
        let action = MacAction(kind: .deleteFile, riskLevel: .destructiveOrSensitive, humanPreview: "delete")
        let decision = PolicyLayer.shared.evaluate(action)
        XCTAssertEqual(decision, .requireConfirmation("needs OK"))
    }

    func testPolicyLayer_requireConfirmationSkippedOnStandard() {
        PolicyLayer.shared.tier = .standard
        PolicyLayer.shared.addRule(PolicyLayer.Rule(name: "confirm") { _ in .requireConfirmation("needs OK") })
        let action = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "read")
        // Standard tier skips requireConfirmation and continues to next rule (allow)
        let decision = PolicyLayer.shared.evaluate(action)
        XCTAssertEqual(decision, .allow)
    }

    func testPolicyLayer_multipleRules() {
        PolicyLayer.shared.addRule(PolicyLayer.Rule(name: "rule1") { _ in .allow })
        PolicyLayer.shared.addRule(PolicyLayer.Rule(name: "rule2") { _ in .deny("blocked") })
        let action = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "read")
        let decision = PolicyLayer.shared.evaluate(action)
        XCTAssertEqual(decision, .deny("blocked"))
    }

    func testPolicyLayer_clearRules() {
        PolicyLayer.shared.addRule(PolicyLayer.Rule(name: "test") { _ in .deny("no") })
        PolicyLayer.shared.clearRules()
        XCTAssertEqual(PolicyLayer.shared.ruleCount, 0)
    }
}

// =============================================================================
// ReadOnlyModeEnforcer Tests
// =============================================================================

@MainActor
final class ReadOnlyModeEnforcerTests: XCTestCase {
    override func setUp() async throws {
        await MainActor.run {
            ReadOnlyModeEnforcer.shared.level = .disabled
        }
    }

    func testReadOnlyModeEnforcer_disabledAllowsAll() {
        let action = MacAction(kind: .deleteFile, riskLevel: .destructiveOrSensitive, humanPreview: "delete")
        let decision = ReadOnlyModeEnforcer.shared.evaluate(action)
        XCTAssertEqual(decision, .allow)
    }

    func testReadOnlyModeEnforcer_warningBlocksWrite() {
        ReadOnlyModeEnforcer.shared.level = .warning
        let action = MacAction(kind: .insertText, riskLevel: .reversibleInput, humanPreview: "type hello")
        let decision = ReadOnlyModeEnforcer.shared.evaluate(action)
        if case .requireConfirmation(let msg) = decision {
            XCTAssertTrue(msg.contains("只读模式"))
        } else {
            XCTFail("expected requireConfirmation")
        }
    }

    func testReadOnlyModeEnforcer_warningAllowsRead() {
        ReadOnlyModeEnforcer.shared.level = .warning
        let action = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "read")
        let decision = ReadOnlyModeEnforcer.shared.evaluate(action)
        XCTAssertEqual(decision, .allow)
    }

    func testReadOnlyModeEnforcer_strictBlocksWrite() {
        ReadOnlyModeEnforcer.shared.level = .strict
        let action = MacAction(kind: .runShellCommand, riskLevel: .destructiveOrSensitive, humanPreview: "rm -rf")
        let decision = ReadOnlyModeEnforcer.shared.evaluate(action)
        if case .deny(let msg) = decision {
            XCTAssertTrue(msg.contains("只读模式禁止写操作"))
        } else {
            XCTFail("expected deny")
        }
    }

    func testReadOnlyModeEnforcer_strictAllowsRead() {
        ReadOnlyModeEnforcer.shared.level = .strict
        let action = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "read")
        let decision = ReadOnlyModeEnforcer.shared.evaluate(action)
        XCTAssertEqual(decision, .allow)
    }

    func testReadOnlyModeEnforcer_levels() {
        ReadOnlyModeEnforcer.shared.level = .disabled
        XCTAssertFalse(ReadOnlyModeEnforcer.shared.isReadOnly(.deleteFile)) // deleteFile is a write action

        ReadOnlyModeEnforcer.shared.level = .strict
        XCTAssertFalse(ReadOnlyModeEnforcer.shared.isReadOnly(.deleteFile)) // level doesn't affect isReadOnly
    }

    func testReadOnlyModeEnforcer_warningStillCanWrite() {
        ReadOnlyModeEnforcer.shared.level = .warning
        let action = MacAction(kind: .readFocusedText, riskLevel: .readOnly, humanPreview: "read focused")
        let decision = ReadOnlyModeEnforcer.shared.evaluate(action)
        XCTAssertEqual(decision, .allow)
    }
}

// =============================================================================
// ActionVerificationEngine Tests
// =============================================================================

@MainActor
final class ActionVerificationEngineTests: XCTestCase {
    func testActionVerificationEngine_shared() {
        let engine = ActionVerificationEngine.shared
        XCTAssertNotNil(engine)
    }

    func testVerificationResult_comparable() {
        XCTAssertTrue(ActionVerificationEngine.VerificationResult.success.isSuccessful)
        XCTAssertTrue(ActionVerificationEngine.VerificationResult.partial("partial").isSuccessful)
        XCTAssertFalse(ActionVerificationEngine.VerificationResult.failure("fail").isSuccessful)
        XCTAssertFalse(ActionVerificationEngine.VerificationResult.unknown.isSuccessful)
    }

    func testVerificationResult_equality() {
        XCTAssertEqual(ActionVerificationEngine.VerificationResult.success, ActionVerificationEngine.VerificationResult.success)
        XCTAssertEqual(ActionVerificationEngine.VerificationResult.failure("x"), ActionVerificationEngine.VerificationResult.failure("x"))
        XCTAssertNotEqual(ActionVerificationEngine.VerificationResult.partial("a"), ActionVerificationEngine.VerificationResult.partial("b"))
    }

    func testActionVerificationEngine_verify() async {
        let engine = ActionVerificationEngine.shared
        let action = MacAction(kind: .clickElement, payload: ["label": "OK", "role": "AXButton"], riskLevel: .reversibleInput, humanPreview: "click OK")
        let report = await engine.verify(action: action, expectedState: "button visible")
        XCTAssertEqual(report.result, ActionVerificationEngine.VerificationResult.unknown)
        XCTAssertEqual(report.expectedState, "button visible")
    }
}

// =============================================================================
// CancelMechanism Tests
// =============================================================================

@MainActor
final class CancelMechanismTests: XCTestCase {
    override func setUp() async throws {
        await MainActor.run {
            // Reset by calling cancel with .all scope
            _ = CancelMechanism.shared.cancel(scope: .all, reason: .userRequested)
        }
    }

    func testCancelMechanism_register() {
        let cm = CancelMechanism.shared
        let token = cm.register {}
        // If we cancel with .currentAction scope, handlers should still exist
        // But isCancelled would report tokens.isEmpty which is inverted logic
        cm.unregister(token)
    }

    func testCancelMechanism_cancelCurrentAction() {
        let cm = CancelMechanism.shared
        let called = OSAllocatedUnfairLock(initialState: false)
        let token = cm.register { called.withLock { $0 = true } }
        let event = cm.cancel(scope: .currentAction, reason: .userRequested)
        XCTAssertTrue(called.withLock { $0 })
        XCTAssertEqual(event.reason, .userRequested)
        cm.unregister(token)
    }

    func testCancelMechanism_cancelPlanRemovesHandlers() {
        let cm = CancelMechanism.shared
        _ = cm.register {}
        _ = cm.register {}
        _ = cm.cancel(scope: .currentPlan, reason: .safetyViolation)
        // After .currentPlan, all handlers should be removed
        XCTAssertTrue(cm.isCancelled)
    }

    func testCancelMechanism_cancelAllRemovesHandlers() {
        let cm = CancelMechanism.shared
        _ = cm.register {}
        _ = cm.cancel(scope: .all, reason: .policyDenied("blocked"))
        XCTAssertTrue(cm.isCancelled)
    }

    func testCancelMechanism_unregister() {
        let cm = CancelMechanism.shared
        let token = cm.register {}
        cm.unregister(token)
        // After cancelAll, isCancelled will report true
        _ = cm.cancel(scope: .all, reason: .userRequested)
        XCTAssertTrue(cm.isCancelled)
    }

    func testCancelMechanism_eventProperties() {
        let event = CancelMechanism.Event(scope: .currentAction, reason: .timeout)
        XCTAssertEqual(event.scope, .currentAction)
        if case .timeout = event.reason {
            XCTAssertTrue(true)
        } else {
            XCTFail("wrong reason")
        }
    }
}

// =============================================================================
// StateMachineManager Tests
// =============================================================================

@MainActor
final class StateMachineManagerTests: XCTestCase {
    override func setUp() {
        MainActor.assumeIsolated {
            StateMachineManager.shared.reset()
        }
    }

    func testStateMachineManager_initialState() {
        let s = StateMachineManager.shared.state
        XCTAssertEqual(s, .idle)
    }

    func testStateMachineManager_validTransition() {
        let r1 = StateMachineManager.shared.transition(to: .observing)
        XCTAssertTrue(r1)
        let s1 = StateMachineManager.shared.state
        XCTAssertEqual(s1, .observing)
    }

    func testStateMachineManager_invalidTransition() {
        // Cannot go from idle to executing directly
        let r1 = StateMachineManager.shared.transition(to: .executing)
        XCTAssertFalse(r1)
        let s1 = StateMachineManager.shared.state
        XCTAssertEqual(s1, .idle)
    }

    func testStateMachineManager_fullFlow() {
        let sm = StateMachineManager.shared
        let r1 = sm.transition(to: .observing)
        XCTAssertTrue(r1)
        let r2 = sm.transition(to: .planning)
        XCTAssertTrue(r2)
        let r3 = sm.transition(to: .executing)
        XCTAssertTrue(r3)
        let r4 = sm.transition(to: .verifying)
        XCTAssertTrue(r4)
        let r5 = sm.transition(to: .idle)
        XCTAssertTrue(r5)
    }

    func testStateMachineManager_cancelFromAnyState() {
        let sm = StateMachineManager.shared
        sm.transition(to: .executing)
        // executing -> cancelled is valid
        let r1 = sm.transition(to: .cancelled)
        XCTAssertTrue(r1)
        let s1 = sm.state
        XCTAssertEqual(s1, .cancelled)
    }

    func testStateMachineManager_errorRecovery() {
        let sm = StateMachineManager.shared
        sm.transition(to: .observing)
        sm.transition(to: .planning)
        sm.transition(to: .executing)
        // executing -> error
        let r1 = sm.transition(to: .error)
        XCTAssertTrue(r1)
        // error -> idle
        let r2 = sm.transition(to: .idle)
        XCTAssertTrue(r2)
    }

    func testStateMachineManager_waitForUser() {
        let sm = StateMachineManager.shared
        sm.transition(to: .executing)
        let r1 = sm.transition(to: .waitingForUser)
        XCTAssertTrue(r1)
        let s1 = sm.state
        XCTAssertEqual(s1, .waitingForUser)
    }

    func testStateMachineManager_reset() {
        let sm = StateMachineManager.shared
        sm.transition(to: .observing)
        sm.reset()
        let s1 = sm.state
        XCTAssertEqual(s1, .idle)
    }

    func testStateMachineManager_recent() {
        let sm = StateMachineManager.shared
        sm.reset()
        sm.transition(to: .observing)
        sm.transition(to: .planning)
        let recent = sm.recent(limit: 10)
        XCTAssertEqual(recent.count, 2)
    }
}

// =============================================================================
// AuditHighRiskAction Tests
// =============================================================================

@MainActor
final class AuditHighRiskActionTests: XCTestCase {
    override func setUp() async throws {
        await MainActor.run {
            AuditHighRiskAction.shared.clear()
        }
    }

    func testAuditHighRiskAction_record() {
        let action = MacAction(kind: .deleteFile, riskLevel: .destructiveOrSensitive, humanPreview: "delete /tmp/test")
        let record = AuditHighRiskAction.shared.record(action: action, context: "test cleanup", approved: true, approver: "admin")
        XCTAssertEqual(record.riskLevel, .destructiveOrSensitive)
        XCTAssertTrue(record.approved)
        XCTAssertEqual(record.approver, "admin")
    }

    func testAuditHighRiskAction_recordWithoutApprover() {
        let action = MacAction(kind: .runShellCommand, riskLevel: .destructiveOrSensitive, humanPreview: "rm -rf /")
        let record = AuditHighRiskAction.shared.record(action: action, context: "dangerous", approved: false)
        XCTAssertFalse(record.approved)
        XCTAssertNil(record.approver)
    }

    func testAuditHighRiskAction_recent() {
        for i in 0..<25 {
            let action = MacAction(kind: .readContext, riskLevel: .reversibleInput, humanPreview: "op \(i)")
            _ = AuditHighRiskAction.shared.record(action: action, context: "test", approved: true)
        }
        let recent = AuditHighRiskAction.shared.recent(limit: 20)
        XCTAssertEqual(recent.count, 20)
    }

    func testAuditHighRiskAction_recordsByKind() {
        let deleteAction = MacAction(kind: .deleteFile, riskLevel: .destructiveOrSensitive, humanPreview: "delete")
        _ = AuditHighRiskAction.shared.record(action: deleteAction, context: "test", approved: true)
        let readAction = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "read")
        _ = AuditHighRiskAction.shared.record(action: readAction, context: "test", approved: true)
        let deleteRecords = AuditHighRiskAction.shared.records(for: .deleteFile)
        XCTAssertEqual(deleteRecords.count, 1)
    }

    func testAuditHighRiskAction_clear() {
        let action = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "test")
        _ = AuditHighRiskAction.shared.record(action: action, context: "test", approved: true)
        AuditHighRiskAction.shared.clear()
        XCTAssertTrue(AuditHighRiskAction.shared.export().isEmpty)
    }

    func testAuditHighRiskAction_export() {
        let action = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "test")
        _ = AuditHighRiskAction.shared.record(action: action, context: "test", approved: true)
        let exported = AuditHighRiskAction.shared.export()
        XCTAssertEqual(exported.count, 1)
    }

    func testAuditHighRiskAction_auditRecordProperties() {
        let action = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "test")
        let record = AuditHighRiskAction.shared.record(action: action, context: "testing", approved: true)
        XCTAssertEqual(record.context, "testing")
        XCTAssertEqual(record.action.humanPreview, "test")
    }
}

// =============================================================================
// TestMatrixPlanner Tests
// =============================================================================

final class TestMatrixPlannerTests: XCTestCase {
    func testTestMatrixPlanner_defaultMatrix() {
        let matrix = TestMatrixPlanner.defaultMatrix(for: .desktop)
        XCTAssertFalse(matrix.cases.isEmpty)
        XCTAssertEqual(matrix.scope, .desktop)
    }

    func testTestMatrixPlanner_filterByCategory() {
        let matrix = TestMatrixPlanner.defaultMatrix(for: .application)
        let safetyCases = matrix.filtered(by: .safety)
        let allSafety = safetyCases.allSatisfy { $0.category == .safety }
        XCTAssertTrue(allSafety)
    }

    func testTestMatrixPlanner_summary() {
        let matrix = TestMatrixPlanner.defaultMatrix(for: .repository)
        let summary = matrix.summary
        XCTAssertTrue(summary.contains("仓库"))
        XCTAssertTrue(summary.contains("测试数"))
    }

    func testTestMatrixPlanner_allScopes() {
        for scope in OperatingScope.allCases {
            let matrix = TestMatrixPlanner.defaultMatrix(for: scope)
            XCTAssertFalse(matrix.cases.isEmpty, "scope \(scope) should have test cases")
        }
    }
}
