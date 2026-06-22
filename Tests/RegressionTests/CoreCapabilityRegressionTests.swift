import XCTest
import Foundation
import os
@testable import RenJistrolyModels
@testable import RenJistrolyEnterprise
@testable import RenJistrolyProductIdentity
@testable import RenJistrolySystemBridge

// MARK: - 核心能力回归测试 — 屏幕上下文 / 元素点击 / 窗口 / 模式 / 引擎

final class CoreScreenContextTests: XCTestCase {

    func testScreenContextSnapshotAllFields() {
        let snap = ScreenContextSnapshot(
            displayID: "display-1",
            displayDescription: "Built-in Retina Display",
            capturedAt: Date(),
            recognizedText: "Hello World",
            visibleAppNames: ["Finder", "Safari"]
        )
        XCTAssertEqual(snap.displayID, "display-1")
        XCTAssertEqual(snap.displayDescription, "Built-in Retina Display")
        XCTAssertEqual(snap.recognizedText, "Hello World")
        XCTAssertEqual(snap.visibleAppNames.count, 2)
    }

    func testScreenContextEmptyDefaults() {
        let snap = ScreenContextSnapshot()
        XCTAssertNil(snap.displayID)
        XCTAssertEqual(snap.displayDescription, "")
        XCTAssertNil(snap.recognizedText)
        XCTAssertTrue(snap.visibleAppNames.isEmpty)
    }

    func testAppContextAllFields() {
        let snap = AppContextSnapshot(appName: "Safari", bundleID: "com.apple.Safari", isResponsive: true, cpuUsage: 12.5, memoryUsage: 256_000_000)
        XCTAssertEqual(snap.appName, "Safari")
        XCTAssertEqual(snap.bundleID, "com.apple.Safari")
        XCTAssertTrue(snap.isResponsive)
        XCTAssertEqual(snap.cpuUsage, 12.5)
        XCTAssertEqual(snap.memoryUsage, 256_000_000)
    }

    func testWindowContextAllFields() {
        let snap = WindowContextSnapshot(title: "Untitled - Notes", frame: "{{0,0},{800,600}}", isMinimized: false, isMain: true)
        XCTAssertEqual(snap.title, "Untitled - Notes")
        XCTAssertFalse(snap.isMinimized)
        XCTAssertTrue(snap.isMain)
    }

    func testFocusContextAllFields() {
        let snap = FocusContextSnapshot(elementRole: "AXTextField", elementTitle: "Search", elementValue: "hello", isTextField: true, isEditable: true)
        XCTAssertEqual(snap.elementRole, "AXTextField")
        XCTAssertTrue(snap.isTextField)
        XCTAssertTrue(snap.isEditable)
    }

    func testSelectionContextLengthComputed() {
        let snap = SelectionContextSnapshot(selectedText: "Hello World", sourceApp: "TextEdit")
        XCTAssertEqual(snap.length, 11)
    }

    func testClipboardRiskSnapshotAllFields() {
        let snap = ClipboardRiskSnapshot(hasContent: true, contentType: "text", containsSensitivePattern: true, riskLevel: .high, suggestion: "Clear")
        XCTAssertTrue(snap.hasContent)
        XCTAssertEqual(snap.riskLevel, .high)
        XCTAssertTrue(snap.containsSensitivePattern)
    }

    func testPermissionContextAllFields() {
        let snap = PermissionContextSnapshot(allGranted: false, permissions: ["accessibility": true], missingPermissions: ["screenRecording"])
        XCTAssertFalse(snap.allGranted)
        XCTAssertEqual(snap.missingPermissions, ["screenRecording"])
    }

    func testTaskContextSnapshotAllFields() {
        let snap = TaskContextSnapshot(currentTask: "Refactor", taskHistory: ["Fix bug"], progress: 0.5, remainingSteps: 3)
        XCTAssertEqual(snap.currentTask, "Refactor")
        XCTAssertEqual(snap.progress, 0.5)
        XCTAssertEqual(snap.remainingSteps, 3)
    }

    func testModelContextSnapshotAllFields() {
        let snap = ModelContextSnapshot(provider: "anthropic", modelName: "claude-sonnet-4-20250514", contextWindow: 200_000, tokensUsed: 1500, tokensRemaining: 198_500)
        XCTAssertEqual(snap.provider, "anthropic")
        XCTAssertEqual(snap.contextWindow, 200_000)
        XCTAssertEqual(snap.tokensRemaining, 198_500)
    }
}

final class CoreComputerUseElementTests: XCTestCase {

    func testStableID() {
        let el = ComputerUseElement(elementIndex: "e3", role: "AXButton", title: "Send Message", depth: 2, childPath: [0, 4, 1])
        XCTAssertEqual(el.stableID, "axbutton:0.4.1:send-message")
    }

    func testCompactLabelPrefersValue() {
        let el = ComputerUseElement(elementIndex: "e1", role: "AXTextField", title: nil, value: "Search", depth: 1, childPath: [])
        XCTAssertEqual(el.compactLabel, "Search")
    }

    func testJSONStringOmitsScreenshot() {
        let state = ComputerUseAppState(
            activeAppBundleID: "com.apple.TextEdit", activeAppName: "TextEdit",
            focusedWindowTitle: "Notes",
            elements: [ComputerUseElement(elementIndex: "e1", role: "AXButton", title: "Done", frame: CodableRect(x: 10, y: 20, width: 100, height: 30), depth: 1, childPath: [0])],
            screenshotPNGBase64: "secret-image-data"
        )
        XCTAssertFalse(state.jsonString(includeScreenshot: false).contains("secret-image-data"))
        XCTAssertTrue(state.jsonString(includeScreenshot: true).contains("secret-image-data"))
    }
}

final class CoreModeManagerTests: XCTestCase {

    func testAllTenModes() {
        XCTAssertEqual(OperationMode.allCases.count, 10)
        let expected: Set<OperationMode> = [.readOnly, .suggest, .executable, .highRisk, .noMouse, .localOnly, .sensitiveAppBlock, .autoMask, .policyLock, .auditExport]
        XCTAssertEqual(Set(OperationMode.allCases), expected)
    }

    func testSequentialActivation() {
        let manager = ModeManager()
        for mode in OperationMode.allCases { manager.activate(mode) }
        for mode in OperationMode.allCases { XCTAssertTrue(manager.isActive(mode)) }
        XCTAssertEqual(manager.config.activeModes.count, 10)
    }

    func testSetPolicy() {
        let manager = ModeManager()
        manager.setPolicy(.locked)
        XCTAssertTrue(manager.config.policy.requiresConfirmation)
        XCTAssertEqual(manager.config.policy.maxRiskLevel, .low)
    }

    func testLockAlsoActivates() {
        let manager = ModeManager()
        manager.lock(.readOnly)
        XCTAssertTrue(manager.isActive(.readOnly))
        XCTAssertTrue(manager.config.lockedModes.contains(.readOnly))
    }

    func testUnlockRemovesFromLocked() {
        let manager = ModeManager()
        manager.lock(.readOnly)
        manager.unlock(.readOnly)
        XCTAssertFalse(manager.config.lockedModes.contains(.readOnly))
        XCTAssertTrue(manager.isActive(.readOnly))
    }

    func testEvaluateWithMultipleActiveModes() {
        let manager = ModeManager()
        manager.activate(.readOnly)
        manager.activate(.noMouse)
        let eval = manager.evaluate("write", riskLevel: .low)
        XCTAssertFalse(eval.allowed)
        XCTAssertEqual(eval.blockedBy, .readOnly)
    }

    func testEvaluateAllowsBrowsingInReadOnly() {
        let manager = ModeManager()
        manager.activate(.readOnly)
        let eval = manager.evaluate("read", riskLevel: .low)
        XCTAssertTrue(eval.allowed)
    }

    func testCustomHandler() {
        let manager = ModeManager()
        let customBlocked = OSAllocatedUnfairLock(initialState: false)
        manager.registerHandler(for: .readOnly) { action, _ in
            if action == "special_block" { customBlocked.withLock { $0 = true }; return false }
            return true
        }
        manager.activate(.readOnly)
        let eval = manager.evaluate("special_block", riskLevel: .low)
        XCTAssertFalse(eval.allowed)
        XCTAssertTrue(customBlocked.withLock { $0 })
    }
}

final class CoreActionEngineTests: XCTestCase {

    func testFullLifecycle() {
        let engine = ActionEngine()
        let record = engine.create(type: "click", preview: "Click button", riskLevel: .medium, rollbackAction: "undo_click")
        XCTAssertEqual(record.status, .pending)
        XCTAssertEqual(record.auditTrail.count, 1)

        XCTAssertTrue(engine.approve(record.id))
        XCTAssertTrue(engine.start(record.id))
        XCTAssertTrue(engine.complete(record.id, result: "Clicked", evidence: "screenshot.png"))

        let r = engine.getRecord(record.id)
        XCTAssertEqual(r?.status, .completed)
        XCTAssertEqual(r?.result, "Clicked")
        XCTAssertEqual(r?.auditTrail.count, 4)
    }

    func testFailAndRecovery() {
        let engine = ActionEngine()
        let record = engine.create(type: "write", preview: "Write file", riskLevel: .high, rollbackAction: "restore_backup")
        XCTAssertTrue(engine.approve(record.id))
        XCTAssertTrue(engine.start(record.id))
        XCTAssertTrue(engine.fail(record.id, reason: "Permission denied", recovery: "Grant permission"))
        let failed = engine.getRecord(record.id)
        XCTAssertEqual(failed?.status, .failed)
        XCTAssertEqual(failed?.failureReason, "Permission denied")
        XCTAssertEqual(failed?.recoverySuggestion, "Grant permission")
    }

    func testCancelDuringExecution() {
        let engine = ActionEngine()
        let record = engine.create(type: "long_op", preview: "Long op", riskLevel: .low)
        XCTAssertTrue(engine.approve(record.id))
        XCTAssertTrue(engine.start(record.id))
        XCTAssertTrue(engine.cancel(record.id))
        XCTAssertEqual(engine.getRecord(record.id)?.status, .cancelled)
        XCTAssertNotNil(engine.getRecord(record.id)?.cancelledAt)
    }

    func testGetAuditTrail() {
        let engine = ActionEngine()
        let record = engine.create(type: "test", preview: "Test", riskLevel: .low)
        XCTAssertTrue(engine.approve(record.id))
        XCTAssertTrue(engine.start(record.id))
        XCTAssertTrue(engine.complete(record.id, result: "done"))
        let trail = engine.getAuditTrail(record.id)
        XCTAssertEqual(trail.count, 4)
        XCTAssertEqual(trail[0].event, "created")
        XCTAssertEqual(trail[1].event, "approved")
        XCTAssertEqual(trail[2].event, "started")
        XCTAssertEqual(trail[3].event, "completed")
    }

    func testOnStatusChange() {
        let engine = ActionEngine()
        final class Lock: @unchecked Sendable {
            var changedCount = 0
            var lastStatus: ActionStatus?
        }
        let lock = Lock()
        engine.onStatusChange = { record in
            lock.changedCount += 1
            lock.lastStatus = record.status
        }
        let record = engine.create(type: "click", preview: "Click", riskLevel: .low)
        XCTAssertTrue(engine.approve(record.id))
        XCTAssertTrue(engine.start(record.id))
        XCTAssertTrue(engine.complete(record.id, result: "done"))
        XCTAssertEqual(lock.changedCount, 3)
        XCTAssertEqual(lock.lastStatus, .completed)
    }
}

@MainActor
final class CoreDevContextTests: XCTestCase {

    func testDevContextAllFields() {
        let ctx = DevContext(
            repo: RepoContextSnapshot(rootPath: "/project", name: "MyProject", isDirty: false, fileCount: 42),
            branch: BranchContextSnapshot(currentBranch: "main", baseBranch: "origin/main", aheadCount: 3, behindCount: 1, hasUnpushed: true),
            diff: DiffContextSnapshot(unstagedCount: 2, stagedCount: 1, untrackedCount: 0, totalChanges: 3, changedFiles: ["a.swift"], diffStat: "2+ 1-"),
            testState: TestStateSnapshot(totalTests: 100, passedTests: 98, failedTests: 2, duration: 30.5, failingTestNames: ["testBroken"]),
            buildState: BuildStateSnapshot(isBuilding: false, lastBuildSuccess: true, lastBuildDuration: 45.0, errors: [], warnings: ["deprecated"], configuration: "debug"),
            ciState: CIStateSnapshot(hasActivePipeline: true, latestStatus: "running", branch: "feature/x"),
            issue: IssueContextSnapshot(issueNumber: 42, title: "Fix crash", state: "open"),
            pr: PRContextSnapshot(prNumber: 123, title: "Add feature", state: "open", sourceBranch: "feature/x", targetBranch: "main", hasConflicts: false, reviewStatus: "approved"),
            file: FileContextSnapshot(filePath: "Sources/main.swift", fileName: "main.swift", fileExtension: "swift", lineCount: 200, sizeBytes: 8192, language: "Swift", isModified: true),
            symbol: SymbolContextSnapshot(symbolName: "MyClass", symbolKind: "class", filePath: "Sources/main.swift", lineNumber: 42, columnNumber: 5)
        )
        XCTAssertEqual(ctx.repo.name, "MyProject")
        XCTAssertEqual(ctx.branch.currentBranch, "main")
        XCTAssertEqual(ctx.diff.totalChanges, 3)
        XCTAssertEqual(ctx.testState.passRate, 0.98)
    }

    func testDevContextSummary() {
        let manager = DevContextManager()
        XCTAssertTrue(manager.summary().contains("开发上下文"))
    }

    func testTestStatePassRateZeroWhenNoTests() {
        let snap = TestStateSnapshot(totalTests: 0, passedTests: 0, failedTests: 0)
        XCTAssertEqual(snap.passRate, 1.0)
    }

    func testTestStatePassRateComputed() {
        let snap = TestStateSnapshot(totalTests: 4, passedTests: 3, failedTests: 1)
        XCTAssertEqual(snap.passRate, 0.75)
    }
}
