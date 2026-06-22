import XCTest
import Foundation
import os
@testable import RenJistrolyModels
@testable import RenJistrolyEnterprise
@testable import RenJistrolyProductIdentity
@testable import RenJistrolySystemBridge

// MARK: - P0: Critical Path Tests

@MainActor
final class RegressionP0Tests: XCTestCase {

    @MainActor
    func testAppStateDefaultValues() {
        let state = AppState()
        XCTAssertEqual(state.mode, .compact)
        XCTAssertEqual(state.voiceState, .idle)
        XCTAssertTrue(state.isHotkeyEnabled)
        XCTAssertTrue(state.isOnline)
    }

    @MainActor
    func testAppModeTransitions() {
        let state = AppState()
        XCTAssertEqual(state.mode, .compact)
        state.mode = .expanded
        XCTAssertEqual(state.mode, .expanded)
        state.mode = .immersive
        XCTAssertEqual(state.mode, .immersive)
        state.mode = .compact
        XCTAssertEqual(state.mode, .compact)
    }

    func testOperationModeActivation() {
        let manager = ModeManager()
        XCTAssertFalse(manager.isActive(.readOnly))
        manager.activate(.readOnly)
        XCTAssertTrue(manager.isActive(.readOnly))
        manager.deactivate(.readOnly)
        XCTAssertFalse(manager.isActive(.readOnly))
    }

    func testOperationModeToggle() {
        let manager = ModeManager()
        XCTAssertFalse(manager.isActive(.executable))
        manager.toggle(.executable)
        XCTAssertTrue(manager.isActive(.executable))
        manager.toggle(.executable)
        XCTAssertFalse(manager.isActive(.executable))
    }

    func testLockedModeCannotBeDeactivated() {
        let manager = ModeManager()
        manager.lock(.readOnly)
        XCTAssertTrue(manager.isActive(.readOnly))
        manager.deactivate(.readOnly)
        XCTAssertTrue(manager.isActive(.readOnly))
    }

    func testActionEngineCreateToCompleteLifecycle() {
        let engine = ActionEngine()
        let record = engine.create(type: "click", preview: "Click OK button", riskLevel: .low)
        XCTAssertEqual(record.status, .pending)
        XCTAssertGreaterThanOrEqual(record.auditTrail.count, 1)

        XCTAssertTrue(engine.approve(record.id))
        XCTAssertEqual(engine.getRecord(record.id)?.status, .approved)

        XCTAssertTrue(engine.start(record.id))
        XCTAssertEqual(engine.getRecord(record.id)?.status, .executing)

        XCTAssertTrue(engine.complete(record.id, result: "OK button clicked"))
        XCTAssertEqual(engine.getRecord(record.id)?.status, .completed)
    }

    @MainActor
    func testReadOnlyModeBlocksWriteActions() {
        let enforcer = ReadOnlyModeEnforcer()
        enforcer.level = .strict

        let writeAction = MacAction(
            kind: .insertText, payload: ["text": "hello"],
            riskLevel: .reversibleInput, humanPreview: "Insert text"
        )
        XCTAssertNotEqual(enforcer.evaluate(writeAction), .allow)

        let readAction = MacAction(
            kind: .readContext, payload: [:],
            riskLevel: .readOnly, humanPreview: "Read context"
        )
        XCTAssertEqual(enforcer.evaluate(readAction), .allow)

        enforcer.level = .disabled
    }

    func testMouseGuardPermissionCheck() {
        let guard_ = MouseGuard.shared
        guard_.accessLevel = .denyWhenUserActive
        guard_.reportUserActivity()
        XCTAssertFalse(guard_.checkPermission())
        guard_.tick()
    }

    func testContextManagerRefreshProducesSnapshot() async {
        let manager = ContextManager()
        let ctx = await manager.refresh()
        XCTAssertEqual(ctx.screen.displayDescription, "")
        XCTAssertTrue(ctx.screen.visibleAppNames.isEmpty)
    }

    func testSecurityModeContextPreservesActiveModes() {
        let snapshot = SecurityModeContextSnapshot(
            activeModes: ["readOnly", "executable"],
            lockedModes: ["policyLock"],
            effectiveRiskLimit: "critical",
            isLocked: true
        )
        XCTAssertEqual(snapshot.activeModes.count, 2)
        XCTAssertTrue(snapshot.activeModes.contains("readOnly"))
        XCTAssertEqual(snapshot.lockedModes.count, 1)
        XCTAssertTrue(snapshot.isLocked)
    }
}

// MARK: - P1: High Priority Tests

@MainActor
final class RegressionP1Tests: XCTestCase {

    func testAllOperationModesHaveTitles() {
        for mode in OperationMode.allCases {
            XCTAssertFalse(mode.title.isEmpty)
            XCTAssertFalse(mode.description.isEmpty)
        }
    }

    func testEnterpriseRiskLevelOrdering() {
        XCTAssertLessThan(EnterpriseRiskLevel.trivial, .low)
        XCTAssertLessThan(EnterpriseRiskLevel.low, .medium)
        XCTAssertLessThan(EnterpriseRiskLevel.medium, .high)
        XCTAssertLessThan(EnterpriseRiskLevel.high, .critical)
    }

    func testActionStatusAllCasesCovered() {
        let allCases: [ActionStatus] = [
            .pending, .approved, .rejected, .executing,
            .completed, .failed, .cancelled, .rolledBack,
        ]
        XCTAssertEqual(allCases.count, 8)
    }

    func testAuditEntryCreatedWithTimestamp() {
        let entry = AuditEntry(event: "test", detail: "detail")
        XCTAssertFalse(entry.id.isEmpty)
        XCTAssertEqual(entry.event, "test")
        XCTAssertEqual(entry.detail, "detail")
        XCTAssertLessThan(entry.timestamp.timeIntervalSinceNow, 1)
    }

    func testEngineRejectPendingAction() {
        let engine = ActionEngine()
        let record = engine.create(type: "delete", preview: "Delete file", riskLevel: .high)
        XCTAssertTrue(engine.reject(record.id, reason: "Not authorized"))
        XCTAssertEqual(engine.getRecord(record.id)?.status, .rejected)
    }

    func testEngineRollbackReturnsRollbackAction() {
        let engine = ActionEngine()
        let record = engine.create(type: "write", preview: "Write config", riskLevel: .medium, rollbackAction: "undo_write")
        XCTAssertTrue(engine.approve(record.id))
        XCTAssertTrue(engine.start(record.id))
        XCTAssertTrue(engine.complete(record.id, result: "done"))
        XCTAssertEqual(engine.rollback(record.id), "undo_write")
        XCTAssertEqual(engine.getRecord(record.id)?.status, .rolledBack)
    }

    func testEngineCannotApproveNonExistent() {
        let engine = ActionEngine()
        XCTAssertFalse(engine.approve("nonexistent"))
    }

    func testEngineCanStartPendingAction() {
        let engine = ActionEngine()
        let record = engine.create(type: "click", preview: "Click", riskLevel: .low)
        XCTAssertTrue(engine.start(record.id))
    }

    func testEngineCancelPendingAction() {
        let engine = ActionEngine()
        let record = engine.create(type: "click", preview: "Click", riskLevel: .low)
        XCTAssertTrue(engine.cancel(record.id))
        XCTAssertEqual(engine.getRecord(record.id)?.status, .cancelled)
    }

    func testModePolicyDefaultValues() {
        let policy = ModePolicy.default
        XCTAssertFalse(policy.requiresConfirmation)
        XCTAssertFalse(policy.requiresApproval)
        XCTAssertTrue(policy.allowedDomains.isEmpty)
        XCTAssertEqual(policy.maxRiskLevel, .critical)
        XCTAssertEqual(policy.auditRetentionDays, 90)
    }

    func testModePolicyLockedValues() {
        let policy = ModePolicy.locked
        XCTAssertTrue(policy.requiresConfirmation)
        XCTAssertTrue(policy.requiresApproval)
        XCTAssertEqual(policy.maxRiskLevel, .low)
        XCTAssertEqual(policy.auditRetentionDays, 365)
    }

    func testModeManagerEvaluateReadOnlyBlocksWrite() {
        let manager = ModeManager()
        manager.activate(.readOnly)
        let eval = manager.evaluate("write", riskLevel: .low)
        XCTAssertFalse(eval.allowed)
        XCTAssertEqual(eval.blockedBy, .readOnly)
    }

    func testModeManagerEvaluateExecutableAllowsAll() {
        let manager = ModeManager()
        manager.activate(.executable)
        let eval = manager.evaluate("delete", riskLevel: .critical)
        XCTAssertTrue(eval.allowed)
        XCTAssertTrue(eval.requiresConfirmation)
    }

    func testModeManagerEvaluateHighRiskBlocksHigh() {
        let manager = ModeManager()
        manager.activate(.highRisk)
        let eval = manager.evaluate("delete", riskLevel: .high)
        XCTAssertFalse(eval.allowed)
        XCTAssertEqual(eval.blockedBy, .highRisk)
    }

    func testModeManagerEvaluateNoMouseBlocksClick() {
        let manager = ModeManager()
        manager.activate(.noMouse)
        let eval = manager.evaluate("click", riskLevel: .low)
        XCTAssertFalse(eval.allowed)
        XCTAssertEqual(eval.blockedBy, .noMouse)
    }

    func testModeManagerEvaluateLocalOnlyBlocksNetwork() {
        let manager = ModeManager()
        manager.activate(.localOnly)
        let eval = manager.evaluate("fetch", riskLevel: .low)
        XCTAssertFalse(eval.allowed)
        XCTAssertEqual(eval.blockedBy, .localOnly)
    }

    func testModeManagerEvaluateSensitiveAppBlock() {
        let manager = ModeManager()
        manager.activate(.sensitiveAppBlock)
        let eval = manager.evaluate("readSensitiveApp", riskLevel: .medium)
        XCTAssertFalse(eval.allowed)
    }

    func testContextManagerSnapshotReturnsEmptyIfNotRefreshed() {
        let manager = ContextManager()
        let snap = manager.snapshot()
        XCTAssertEqual(snap.screen.displayDescription, "")
        XCTAssertEqual(snap.app.appName, "")
    }

    func testContextManagerSummaryIncludesModeInfo() {
        let manager = ContextManager()
        let _ = manager.snapshot()
        let summary = manager.summary()
        XCTAssertTrue(summary.contains("系统上下文"))
    }

    @MainActor
    func testPermissionGrantAllGranted() {
        var grant = AppState.PermissionGrant()
        grant.accessibility = true
        grant.microphone = true
        grant.speechRecognition = true
        grant.screenRecording = true
        grant.appleEvents = true
        XCTAssertTrue(grant.allGranted)
    }

    @MainActor
    func testPermissionGrantAllGrantedFalseWhenMissing() {
        var grant = AppState.PermissionGrant()
        grant.accessibility = true
        grant.microphone = true
        grant.speechRecognition = true
        grant.screenRecording = true
        grant.appleEvents = false
        XCTAssertFalse(grant.allGranted)
    }

    func testPolicyLayerTierOrdering() {
        XCTAssertLessThan(PolicyLayer.Tier.minimal, .standard)
        XCTAssertLessThan(PolicyLayer.Tier.standard, .strict)
        XCTAssertLessThan(PolicyLayer.Tier.strict, .lockdown)
    }

    func testReadOnlyEnforcerLevelOrdering() {
        XCTAssertLessThan(ReadOnlyModeEnforcer.Level.disabled, .warning)
        XCTAssertLessThan(ReadOnlyModeEnforcer.Level.warning, .strict)
    }
}

// MARK: - P2: General/Edge Case Tests

final class RegressionP2Tests: XCTestCase {

    func testModeManagerToggleAllModes() {
        let manager = ModeManager()
        for mode in OperationMode.allCases {
            manager.toggle(mode)
            XCTAssertTrue(manager.isActive(mode))
            manager.toggle(mode)
            XCTAssertFalse(manager.isActive(mode))
        }
    }

    func testActionEngineRejectNonPendingAction() {
        let engine = ActionEngine()
        let record = engine.create(type: "click", preview: "Click", riskLevel: .low)
        XCTAssertTrue(engine.approve(record.id))
        XCTAssertFalse(engine.reject(record.id))
    }

    func testActionEngineFailWithoutStart() {
        let engine = ActionEngine()
        let record = engine.create(type: "click", preview: "Click", riskLevel: .low)
        XCTAssertFalse(engine.fail(record.id, reason: "error"))
    }

    func testActionEngineHistoryAppendedOnComplete() {
        let engine = ActionEngine()
        let r1 = engine.create(type: "click", preview: "C1", riskLevel: .low)
        XCTAssertTrue(engine.approve(r1.id))
        XCTAssertTrue(engine.start(r1.id))
        XCTAssertTrue(engine.complete(r1.id, result: "done"))
        XCTAssertEqual(engine.getRecentHistory().count, 1)

        let r2 = engine.create(type: "click", preview: "C2", riskLevel: .low)
        XCTAssertTrue(engine.approve(r2.id))
        XCTAssertTrue(engine.start(r2.id))
        XCTAssertTrue(engine.complete(r2.id, result: "done"))
        XCTAssertEqual(engine.getRecentHistory().count, 2)
    }

    func testActionEngineHistoryLimit() {
        let engine = ActionEngine()
        for i in 0..<60 {
            let r = engine.create(type: "op\(i)", preview: "Op \(i)", riskLevel: .low)
            XCTAssertTrue(engine.approve(r.id))
            XCTAssertTrue(engine.start(r.id))
            XCTAssertTrue(engine.complete(r.id, result: "done"))
        }
        XCTAssertEqual(engine.getRecentHistory(limit: 50).count, 50)
    }

    func testSystemContextEquality() {
        let ctx1 = SystemContext()
        let ctx2 = SystemContext()
        XCTAssertEqual(ctx1, ctx2)
    }

    func testSystemContextWithCustomValuesNotEqualToDefault() {
        let defaultCtx = SystemContext()
        let customCtx = SystemContext(screen: ScreenContextSnapshot(displayDescription: "Custom"))
        XCTAssertNotEqual(defaultCtx, customCtx)
    }

    func testModeConfigurationEncodeDecodeRoundTrip() throws {
        let config = ModeConfiguration(
            activeModes: [.readOnly, .executable],
            policy: .locked,
            lockedModes: [.policyLock],
            maskingPatterns: ["password", "token"],
            sensitiveAppBundleIDs: ["com.apple.Safari"]
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ModeConfiguration.self, from: data)
        XCTAssertEqual(decoded.activeModes, config.activeModes)
        XCTAssertEqual(decoded.policy, config.policy)
        XCTAssertEqual(decoded.lockedModes, config.lockedModes)
        XCTAssertEqual(decoded.maskingPatterns, config.maskingPatterns)
        XCTAssertEqual(decoded.sensitiveAppBundleIDs, config.sensitiveAppBundleIDs)
    }

    func testActionRecordEncodeDecodeRoundTrip() throws {
        let record = ActionRecord(
            type: "test", preview: "Test action", riskLevel: .medium,
            auditTrail: [AuditEntry(event: "created", detail: "test")]
        )
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(ActionRecord.self, from: data)
        XCTAssertEqual(decoded.id, record.id)
        XCTAssertEqual(decoded.type, record.type)
        XCTAssertEqual(decoded.preview, record.preview)
        XCTAssertEqual(decoded.riskLevel, record.riskLevel)
        XCTAssertEqual(decoded.auditTrail.count, record.auditTrail.count)
    }

    func testMouseGuardDenyAlways() {
        let guard_ = MouseGuard.shared
        guard_.accessLevel = .denyAlways
        guard_.reportUserActivity()
        XCTAssertFalse(guard_.checkPermission())
    }

    func testMouseGuardAllowWithPermission() {
        let guard_ = MouseGuard.shared
        guard_.accessLevel = .allowWithPermission
        guard_.reportUserActivity()
        XCTAssertTrue(guard_.checkPermission())
    }

    @MainActor
    func testReadOnlyEnforcerWarningReturnsRequireConfirmation() {
        let enforcer = ReadOnlyModeEnforcer()
        enforcer.level = .warning
        let action = MacAction(kind: .deleteFile, payload: [:], riskLevel: .destructiveOrSensitive, humanPreview: "Delete file")
        let decision = enforcer.evaluate(action)
        if case .requireConfirmation = decision {
            XCTAssertTrue(true)
        } else {
            XCTFail("expected requireConfirmation in warning mode")
        }
        enforcer.level = .disabled
    }

    @MainActor
    func testReadOnlyDisableAllowsAll() {
        let enforcer = ReadOnlyModeEnforcer()
        enforcer.level = .disabled
        let action = MacAction(kind: .deleteFile, payload: [:], riskLevel: .destructiveOrSensitive, humanPreview: "Delete file")
        XCTAssertEqual(enforcer.evaluate(action), .allow)
    }

    func testProductIdentityCoreCapabilities() {
        XCTAssertFalse(ProductIdentity.coreCapabilities.isEmpty)
        XCTAssertTrue(ProductIdentity.coreCapabilities.contains { $0.contains("屏幕感知") })
        XCTAssertTrue(ProductIdentity.coreCapabilities.contains { $0.contains("窗口操控") })
        XCTAssertEqual(ProductIdentity.productName, "RenJistroly")
        XCTAssertFalse(ProductIdentity.version.isEmpty)
    }

    func testProductIdentityOutOfScope() {
        XCTAssertFalse(ProductIdentity.outOfScope.isEmpty)
        XCTAssertTrue(ProductIdentity.outOfScope.contains { $0.contains("Android") })
    }

    func testCapabilityLevelOrdering() {
        XCTAssertLessThan(ProductIdentity.CapabilityLevel.observe, .readWrite)
        XCTAssertLessThan(ProductIdentity.CapabilityLevel.readWrite, .automate)
        XCTAssertLessThan(ProductIdentity.CapabilityLevel.automate, .autonomous)
    }

    @MainActor
    func testPolicyLayerAddRuleEvaluates() {
        let layer = PolicyLayer()
        let evaluated = OSAllocatedUnfairLock(initialState: false)
        layer.addRule(PolicyLayer.Rule(name: "blockAll") { _ in
            evaluated.withLock { $0 = true }
            return .deny("Blocked by rule")
        })
        let action = MacAction(kind: .clickAt, payload: [:], riskLevel: .reversibleInput, humanPreview: "Click")
        let decision = layer.evaluate(action)
        XCTAssertTrue(evaluated.withLock { $0 })
        XCTAssertNotEqual(decision, .allow)
        layer.clearRules()
        XCTAssertEqual(layer.ruleCount, 0)
    }
}
