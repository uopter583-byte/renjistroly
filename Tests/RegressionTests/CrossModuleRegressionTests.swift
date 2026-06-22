import XCTest
import Foundation
import os
@testable import RenJistrolyModels
@testable import RenJistrolyEnterprise
@testable import RenJistrolyProductIdentity
@testable import RenJistrolySystemBridge

// MARK: - 跨模块回归测试

@MainActor
final class CrossModeManagerActionEngineTests: XCTestCase {

    func testModeManagerEvaluatesThenEngineExecutes() {
        let modeManager = ModeManager()
        let engine = ActionEngine()

        modeManager.activate(.readOnly)
        XCTAssertFalse(modeManager.evaluate("write", riskLevel: .medium).allowed)

        let record = engine.create(type: "write", preview: "Write blocked by policy", riskLevel: .medium)
        XCTAssertEqual(record.status, .pending)
        XCTAssertTrue(engine.approve(record.id))
        XCTAssertTrue(engine.start(record.id))
        XCTAssertTrue(engine.fail(record.id, reason: "Blocked by readOnly mode", recovery: "Switch to executable mode"))
        XCTAssertEqual(engine.getRecord(record.id)?.failureReason, "Blocked by readOnly mode")

        modeManager.deactivate(.readOnly)
        modeManager.activate(.executable)
        XCTAssertTrue(modeManager.evaluate("write", riskLevel: .medium).allowed)
    }

    func testModeManagerHighRiskRequiresConfirmation() {
        let modeManager = ModeManager()
        let engine = ActionEngine()

        modeManager.activate(.highRisk)
        _ = engine.create(type: "delete", preview: "Delete database", riskLevel: .high)
        XCTAssertFalse(modeManager.evaluate("delete", riskLevel: .high).allowed)

        modeManager.deactivate(.highRisk)
        modeManager.activate(.executable)
        let eval = modeManager.evaluate("delete", riskLevel: .high)
        XCTAssertTrue(eval.allowed)
        XCTAssertTrue(eval.requiresConfirmation)
    }

    func testModeManagerMultipleModesBlockChain() {
        let modeManager = ModeManager()

        modeManager.activate(.readOnly)
        modeManager.activate(.noMouse)
        modeManager.activate(.localOnly)

        XCTAssertFalse(modeManager.evaluate("write", riskLevel: .low).allowed)
        XCTAssertFalse(modeManager.evaluate("click", riskLevel: .low).allowed)
        XCTAssertFalse(modeManager.evaluate("fetch", riskLevel: .low).allowed)
        XCTAssertTrue(modeManager.evaluate("read", riskLevel: .low).allowed)
    }
}

@MainActor
final class CrossContextProviderTests: XCTestCase {

    func testContextManagerWithProvider() async {
        let provider = MockContextProvider()
        let manager = ContextManager(provider: provider)
        let ctx = await manager.refresh()

        XCTAssertEqual(ctx.screen.displayDescription, "Mock Display")
        XCTAssertEqual(ctx.screen.visibleAppNames, ["MockApp"])
        XCTAssertEqual(ctx.app.appName, "MockApplication")
        XCTAssertEqual(ctx.window.title, "Mock Window")
        XCTAssertEqual(ctx.focus.elementRole, "AXButton")
        XCTAssertEqual(ctx.selection.selectedText, "mock selection")
        XCTAssertTrue(ctx.clipboardRisk.hasContent)
        XCTAssertEqual(ctx.model.provider, "mock")
        XCTAssertFalse(ctx.permission.allGranted)
        XCTAssertEqual(ctx.securityMode.activeModes, ["readOnly"])
    }

    func testContextManagerSnapshotAfterRefresh() async {
        let provider = MockContextProvider()
        let manager = ContextManager(provider: provider)
        let ctx = await manager.refresh()
        XCTAssertEqual(manager.snapshot(), ctx)
    }

    func testContextManagerWithoutProvider() async {
        let manager = ContextManager()
        let ctx = await manager.refresh()
        XCTAssertEqual(ctx.screen.displayDescription, "")
        XCTAssertEqual(ctx.app.appName, "")
        XCTAssertNil(ctx.window.title)
        XCTAssertFalse(ctx.permission.allGranted)
    }

    func testDevContextManagerWithProvider() async {
        let provider = MockDevContextProvider()
        let manager = DevContextManager(provider: provider)
        let ctx = await manager.refresh()

        XCTAssertEqual(ctx.repo.name, "MockRepo")
        XCTAssertEqual(ctx.branch.currentBranch, "feature/test")
        XCTAssertEqual(ctx.diff.totalChanges, 5)
        XCTAssertEqual(ctx.testState.totalTests, 50)
        XCTAssertTrue(ctx.buildState.lastBuildSuccess ?? false)
        XCTAssertEqual(ctx.issue.issueNumber, 1)
        XCTAssertEqual(ctx.pr.prNumber, 2)
        XCTAssertEqual(ctx.symbol.symbolName, "mockSymbol")
    }

    func testDevContextManagerWithoutProvider() async {
        let manager = DevContextManager()
        let ctx = await manager.refresh()
        XCTAssertNil(ctx.repo.name)
        XCTAssertNil(ctx.branch.currentBranch)
    }
}

final class CrossProductIdentityPolicyTests: XCTestCase {

    func testProductIdentityInformsPolicyTier() {
        XCTAssertGreaterThanOrEqual(ProductIdentity.coreCapabilities.count, 5)
        XCTAssertTrue(ProductIdentity.coreCapabilities.contains { $0.contains("屏幕感知") })
        XCTAssertEqual(ProductIdentity.CapabilityLevel.observe.rawValue, 0)
        XCTAssertEqual(ProductIdentity.CapabilityLevel.readWrite.rawValue, 1)
        XCTAssertEqual(ProductIdentity.CapabilityLevel.automate.rawValue, 2)
        XCTAssertEqual(ProductIdentity.CapabilityLevel.autonomous.rawValue, 3)
    }

    @MainActor
    func testPolicyLayerWithMouseGuardIntegration() {
        let layer = PolicyLayer.shared
        let mouseGuard = MouseGuard.shared

        let mouseGuardChecked = OSAllocatedUnfairLock(initialState: false)
        layer.addRule(PolicyLayer.Rule(name: "mouseGuardRule") { _ in
            mouseGuardChecked.withLock { $0 = true }
            return mouseGuard.checkPermission() ? .allow : .deny("MouseGuard blocks input")
        })

        mouseGuard.accessLevel = .denyAlways
        let action = MacAction(kind: .clickAt, payload: ["x": "100", "y": "200"], riskLevel: .reversibleInput, humanPreview: "Click")
        let decision = layer.evaluate(action)
        XCTAssertTrue(mouseGuardChecked.withLock { $0 })
        XCTAssertNotEqual(decision, .allow)

        layer.clearRules()
        mouseGuard.accessLevel = .denyWhenUserActive
    }
}

final class CrossSecurityIntegrationTests: XCTestCase {

    @MainActor
    func testMouseGuardAndReadOnlyEnforcerTogether() {
        let enforcer = ReadOnlyModeEnforcer()
        enforcer.level = .strict
        let mouseGuard = MouseGuard.shared
        mouseGuard.accessLevel = .denyAlways

        let writeAction = MacAction(kind: .insertText, payload: ["text": "hello"], riskLevel: .reversibleInput, humanPreview: "Insert text")
        XCTAssertNotEqual(enforcer.evaluate(writeAction), .allow)
        XCTAssertFalse(mouseGuard.checkPermission())

        let readAction = MacAction(kind: .readContext, payload: [:], riskLevel: .readOnly, humanPreview: "Read")
        XCTAssertEqual(enforcer.evaluate(readAction), .allow)

        enforcer.level = .disabled
        mouseGuard.accessLevel = .denyWhenUserActive
    }

    func testMouseGuardUserStateTransitions() {
        let guard_ = MouseGuard.shared
        guard_.accessLevel = .denyWhenUserActive
        XCTAssertEqual(guard_.userState(), .idle)
        guard_.reportUserActivity()
        let state = guard_.userState()
        XCTAssertTrue(state == .active || state == .critical)
        guard_.accessLevel = .denyWhenUserActive
    }
}

// MARK: - Mock Implementations

private final class MockContextProvider: ContextProviderProtocol, Sendable {
    func captureScreenContext() async -> ScreenContextSnapshot {
        ScreenContextSnapshot(displayDescription: "Mock Display", visibleAppNames: ["MockApp"])
    }
    func captureAppContext() async -> AppContextSnapshot {
        AppContextSnapshot(appName: "MockApplication", bundleID: "com.mock.app")
    }
    func captureWindowContext() async -> WindowContextSnapshot {
        WindowContextSnapshot(title: "Mock Window", isMain: true)
    }
    func captureFocusContext() async -> FocusContextSnapshot {
        FocusContextSnapshot(elementRole: "AXButton", elementTitle: "Mock Button")
    }
    func captureSelectionContext() async -> SelectionContextSnapshot {
        SelectionContextSnapshot(selectedText: "mock selection", sourceApp: "MockApp")
    }
    func captureClipboardRisk() async -> ClipboardRiskSnapshot {
        ClipboardRiskSnapshot(hasContent: true, contentType: "text")
    }
    func captureTaskContext() async -> TaskContextSnapshot {
        TaskContextSnapshot(currentTask: "testing", progress: 0.5)
    }
    func captureModelContext() async -> ModelContextSnapshot {
        ModelContextSnapshot(provider: "mock", modelName: "mock-model")
    }
    func capturePermissionContext() async -> PermissionContextSnapshot {
        PermissionContextSnapshot(allGranted: false, permissions: ["accessibility": true, "screenRecording": false], missingPermissions: ["screenRecording"])
    }
    func captureSecurityModeContext() async -> SecurityModeContextSnapshot {
        SecurityModeContextSnapshot(activeModes: ["readOnly"])
    }
    func captureHealthStatus() async -> HealthStatusSnapshot {
        HealthStatusSnapshot(appResponsive: true, isForeground: true)
    }
}

private final class MockDevContextProvider: DevContextProviderProtocol, Sendable {
    func captureRepoContext() async -> RepoContextSnapshot {
        RepoContextSnapshot(rootPath: "/mock/repo", name: "MockRepo", fileCount: 100)
    }
    func captureBranchContext() async -> BranchContextSnapshot {
        BranchContextSnapshot(currentBranch: "feature/test", baseBranch: "main", aheadCount: 5, hasUnpushed: true)
    }
    func captureDiffContext() async -> DiffContextSnapshot {
        DiffContextSnapshot(unstagedCount: 3, stagedCount: 2, totalChanges: 5, changedFiles: ["a.swift"], diffStat: "10+ 5-")
    }
    func captureTestState() async -> TestStateSnapshot {
        TestStateSnapshot(totalTests: 50, passedTests: 48, failedTests: 2, duration: 20.0, failingTestNames: ["testBroken"])
    }
    func captureBuildState() async -> BuildStateSnapshot {
        BuildStateSnapshot(isBuilding: false, lastBuildSuccess: true, lastBuildDuration: 60.0)
    }
    func captureCIState() async -> CIStateSnapshot {
        CIStateSnapshot(hasActivePipeline: false, latestStatus: "passed", branch: "main")
    }
    func captureIssueContext() async -> IssueContextSnapshot {
        IssueContextSnapshot(issueNumber: 1, title: "Test issue", state: "open")
    }
    func capturePRContext() async -> PRContextSnapshot {
        PRContextSnapshot(prNumber: 2, title: "Test PR", state: "open")
    }
    func captureFileContext() async -> FileContextSnapshot {
        FileContextSnapshot(filePath: "Sources/main.swift", fileName: "main.swift", fileExtension: "swift", lineCount: 300, language: "Swift", isModified: true)
    }
    func captureSymbolContext() async -> SymbolContextSnapshot {
        SymbolContextSnapshot(symbolName: "mockSymbol", symbolKind: "func", filePath: "Sources/main.swift", lineNumber: 42, columnNumber: 7)
    }
}
