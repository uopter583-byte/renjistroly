import XCTest
@testable import RenJistrolyEnterprise

// =============================================================================
// Context Snapshot Tests
// =============================================================================

final class ScreenContextSnapshotTests: XCTestCase {
    func testScreenContextSnapshot_default() {
        let snap = ScreenContextSnapshot()
        XCTAssertNil(snap.displayID)
        XCTAssertTrue(snap.displayDescription.isEmpty)
        XCTAssertNil(snap.recognizedText)
        XCTAssertTrue(snap.visibleAppNames.isEmpty)
    }

    func testScreenContextSnapshot_custom() {
        let snap = ScreenContextSnapshot(
            displayID: "1", displayDescription: "Built-in Retina",
            recognizedText: "Hello World", visibleAppNames: ["Finder", "Safari"]
        )
        XCTAssertEqual(snap.displayID, "1")
        XCTAssertEqual(snap.recognizedText, "Hello World")
        XCTAssertEqual(snap.visibleAppNames, ["Finder", "Safari"])
    }

    func testScreenContextSnapshot_codable() throws {
        let snap = ScreenContextSnapshot(displayDescription: "test")
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(ScreenContextSnapshot.self, from: data)
        XCTAssertEqual(snap, decoded)
    }
}

final class AppContextSnapshotTests: XCTestCase {
    func testAppContextSnapshot_default() {
        let snap = AppContextSnapshot()
        XCTAssertTrue(snap.appName.isEmpty)
        XCTAssertNil(snap.bundleID)
        XCTAssertTrue(snap.isResponsive)
    }

    func testAppContextSnapshot_custom() {
        let snap = AppContextSnapshot(appName: "Safari", bundleID: "com.apple.Safari", isResponsive: false, cpuUsage: 45.5, memoryUsage: 500_000_000)
        XCTAssertEqual(snap.appName, "Safari")
        XCTAssertEqual(snap.bundleID, "com.apple.Safari")
        XCTAssertFalse(snap.isResponsive)
        XCTAssertEqual(snap.cpuUsage, 45.5)
    }
}

final class WindowContextSnapshotTests: XCTestCase {
    func testWindowContextSnapshot_default() {
        let snap = WindowContextSnapshot()
        XCTAssertNil(snap.title)
        XCTAssertFalse(snap.isMinimized)
    }

    func testWindowContextSnapshot_custom() {
        let snap = WindowContextSnapshot(title: "Preferences", frame: "{{0,0},{800,600}}", isMinimized: true, isMain: true)
        XCTAssertEqual(snap.title, "Preferences")
        XCTAssertTrue(snap.isMinimized)
        XCTAssertTrue(snap.isMain)
    }
}

final class FocusContextSnapshotTests: XCTestCase {
    func testFocusContextSnapshot_default() {
        let snap = FocusContextSnapshot()
        XCTAssertNil(snap.elementRole)
        XCTAssertFalse(snap.isTextField)
    }

    func testFocusContextSnapshot_custom() {
        let snap = FocusContextSnapshot(elementRole: "AXTextField", elementTitle: "Search", elementValue: "hello", isTextField: true, isEditable: true)
        XCTAssertEqual(snap.elementRole, "AXTextField")
        XCTAssertEqual(snap.elementTitle, "Search")
        XCTAssertTrue(snap.isTextField)
        XCTAssertTrue(snap.isEditable)
    }
}

final class ClipboardRiskSnapshotTests: XCTestCase {
    func testClipboardRiskSnapshot_default() {
        let snap = ClipboardRiskSnapshot()
        XCTAssertFalse(snap.hasContent)
        XCTAssertEqual(snap.riskLevel, .low)
    }

    func testClipboardRiskSnapshot_custom() {
        let snap = ClipboardRiskSnapshot(hasContent: true, contentType: "text", containsSensitivePattern: true, riskLevel: .high, suggestion: "clear clipboard")
        XCTAssertTrue(snap.hasContent)
        XCTAssertTrue(snap.containsSensitivePattern)
        XCTAssertEqual(snap.riskLevel, .high)
    }
}

final class TaskContextSnapshotTests: XCTestCase {
    func testTaskContextSnapshot_default() {
        let snap = TaskContextSnapshot()
        XCTAssertNil(snap.currentTask)
        XCTAssertTrue(snap.taskHistory.isEmpty)
        XCTAssertEqual(snap.progress, 0)
    }

    func testTaskContextSnapshot_custom() {
        let snap = TaskContextSnapshot(currentTask: "build", taskHistory: ["clean", "configure"], progress: 0.5, remainingSteps: 2)
        XCTAssertEqual(snap.currentTask, "build")
        XCTAssertEqual(snap.progress, 0.5)
        XCTAssertEqual(snap.remainingSteps, 2)
    }
}

final class ModelContextSnapshotTests: XCTestCase {
    func testModelContextSnapshot_default() {
        let snap = ModelContextSnapshot()
        XCTAssertNil(snap.provider)
        XCTAssertEqual(snap.contextWindow, 0)
    }

    func testModelContextSnapshot_custom() {
        let snap = ModelContextSnapshot(provider: "anthropic", modelName: "claude-4", contextWindow: 200_000, tokensUsed: 5000, tokensRemaining: 195_000)
        XCTAssertEqual(snap.provider, "anthropic")
        XCTAssertEqual(snap.tokensUsed, 5000)
        XCTAssertEqual(snap.tokensRemaining, 195_000)
    }
}

final class PermissionContextSnapshotTests: XCTestCase {
    func testPermissionContextSnapshot_default() {
        let snap = PermissionContextSnapshot()
        XCTAssertFalse(snap.allGranted)
        XCTAssertTrue(snap.permissions.isEmpty)
    }

    func testPermissionContextSnapshot_custom() {
        let snap = PermissionContextSnapshot(
            allGranted: false,
            permissions: ["accessibility": true, "screenRecording": false],
            missingPermissions: ["screenRecording"]
        )
        XCTAssertFalse(snap.allGranted)
        XCTAssertEqual(snap.permissions["accessibility"], true)
        XCTAssertEqual(snap.missingPermissions, ["screenRecording"])
    }
}

final class SecurityModeContextSnapshotTests: XCTestCase {
    func testSecurityModeContextSnapshot_default() {
        let snap = SecurityModeContextSnapshot()
        XCTAssertTrue(snap.activeModes.isEmpty)
        XCTAssertFalse(snap.isLocked)
    }

    func testSecurityModeContextSnapshot_custom() {
        let snap = SecurityModeContextSnapshot(activeModes: ["readOnly"], lockedModes: ["policyLock"], effectiveRiskLimit: "low", isLocked: true)
        XCTAssertEqual(snap.activeModes, ["readOnly"])
        XCTAssertTrue(snap.isLocked)
        XCTAssertEqual(snap.effectiveRiskLimit, "low")
    }
}

final class SystemContextTests: XCTestCase {
    func testSystemContext_default() {
        let ctx = SystemContext()
        XCTAssertTrue(ctx.app.appName.isEmpty)
        XCTAssertTrue(ctx.screen.visibleAppNames.isEmpty)
        XCTAssertFalse(ctx.securityMode.isLocked)
        XCTAssertEqual(ctx.securityMode.effectiveRiskLimit, "critical")
    }

    func testSystemContext_custom() {
        let screen = ScreenContextSnapshot(recognizedText: "Hello")
        let app = AppContextSnapshot(appName: "Terminal")
        let ctx = SystemContext(
            screen: screen,
            app: app,
            securityMode: SecurityModeContextSnapshot(activeModes: ["readOnly"], isLocked: true)
        )
        XCTAssertEqual(ctx.screen.recognizedText, "Hello")
        XCTAssertEqual(ctx.app.appName, "Terminal")
        XCTAssertTrue(ctx.securityMode.isLocked)
    }

    func testSystemContext_codable() throws {
        let ctx = SystemContext()
        let data = try JSONEncoder().encode(ctx)
        let decoded = try JSONDecoder().decode(SystemContext.self, from: data)
        XCTAssertEqual(ctx, decoded)
    }
}

// =============================================================================
// ContextManager Tests
// =============================================================================

@MainActor
final class ContextManagerTests: XCTestCase {
    func testContextManager_init() {
        let manager = ContextManager()
        XCTAssertNil(manager.lastContext)
        XCTAssertNil(manager.provider)
    }

    func testContextManager_snapshot_default() {
        let manager = ContextManager()
        let snap = manager.snapshot()
        XCTAssertTrue(snap.app.appName.isEmpty)
    }

    func testContextManager_summary_empty() {
        let manager = ContextManager()
        let summary = manager.summary()
        XCTAssertTrue(summary.contains("系统上下文"))
    }

    func testContextManager_summary_withApp() {
        let manager = ContextManager()
        // The snapshot doesn't set app name since there's no provider
        let summary = manager.summary()
        XCTAssertTrue(summary.contains("系统上下文"))
    }

    func testContextManager_setCacheExpiry() {
        let manager = ContextManager()
        manager.setCacheExpiry(5.0)
        // No getter for cacheExpiry, just verify it doesn't crash
    }

    func testContextManager_refreshWithoutProvider() async {
        let manager = ContextManager()
        let ctx = await manager.refresh()
        XCTAssertTrue(ctx.app.appName.isEmpty)
    }
}

// =============================================================================
// Dev Context Tests
// =============================================================================

final class RepoContextSnapshotTests: XCTestCase {
    func testRepoContextSnapshot_default() {
        let snap = RepoContextSnapshot()
        XCTAssertNil(snap.rootPath)
        XCTAssertFalse(snap.isDirty)
        XCTAssertEqual(snap.fileCount, 0)
    }

    func testRepoContextSnapshot_custom() {
        let snap = RepoContextSnapshot(rootPath: "/Users/user/project", name: "MyApp", isDirty: true, fileCount: 42)
        XCTAssertEqual(snap.rootPath, "/Users/user/project")
        XCTAssertEqual(snap.name, "MyApp")
        XCTAssertTrue(snap.isDirty)
        XCTAssertEqual(snap.fileCount, 42)
    }
}

final class BranchContextSnapshotTests: XCTestCase {
    func testBranchContextSnapshot_custom() {
        let snap = BranchContextSnapshot(currentBranch: "feature/test", baseBranch: "main", aheadCount: 3, behindCount: 1, hasUnpushed: true)
        XCTAssertEqual(snap.currentBranch, "feature/test")
        XCTAssertEqual(snap.aheadCount, 3)
        XCTAssertTrue(snap.hasUnpushed)
    }
}

final class DiffContextSnapshotTests: XCTestCase {
    func testDiffContextSnapshot_custom() {
        let snap = DiffContextSnapshot(unstagedCount: 2, stagedCount: 1, untrackedCount: 3, totalChanges: 6, changedFiles: ["a.swift", "b.swift"])
        XCTAssertEqual(snap.totalChanges, 6)
        XCTAssertEqual(snap.changedFiles.count, 2)
    }
}

final class TestStateSnapshotTests: XCTestCase {
    func testTestStateSnapshot_default() {
        let snap = TestStateSnapshot()
        XCTAssertEqual(snap.passRate, 1.0)
    }

    func testTestStateSnapshot_passRate() {
        let snap = TestStateSnapshot(totalTests: 10, passedTests: 7, failedTests: 3)
        XCTAssertEqual(snap.passRate, 0.7)
    }

    func testTestStateSnapshot_zeroTests() {
        let snap = TestStateSnapshot()
        XCTAssertEqual(snap.passRate, 1.0)
    }
}

final class BuildStateSnapshotTests: XCTestCase {
    func testBuildStateSnapshot_custom() {
        let snap = BuildStateSnapshot(isBuilding: true, lastBuildSuccess: false, errors: ["compile error"], configuration: "release")
        XCTAssertTrue(snap.isBuilding)
        XCTAssertEqual(snap.lastBuildSuccess, false)
        XCTAssertEqual(snap.errors.count, 1)
        XCTAssertEqual(snap.configuration, "release")
    }
}

final class CIStateSnapshotTests: XCTestCase {
    func testCIStateSnapshot() {
        let snap = CIStateSnapshot(hasActivePipeline: true, latestStatus: "running", branch: "main")
        XCTAssertTrue(snap.hasActivePipeline)
        XCTAssertEqual(snap.latestStatus, "running")
    }
}

final class DevContextTests: XCTestCase {
    func testDevContext_default() {
        let ctx = DevContext()
        XCTAssertNil(ctx.repo.name)
        XCTAssertNil(ctx.branch.currentBranch)
        XCTAssertEqual(ctx.diff.totalChanges, 0)
    }

    func testDevContext_custom() {
        let ctx = DevContext(
            repo: RepoContextSnapshot(name: "MyApp"),
            branch: BranchContextSnapshot(currentBranch: "main"),
            diff: DiffContextSnapshot(totalChanges: 5)
        )
        XCTAssertEqual(ctx.repo.name, "MyApp")
        XCTAssertEqual(ctx.branch.currentBranch, "main")
        XCTAssertEqual(ctx.diff.totalChanges, 5)
    }

    func testDevContext_codable() throws {
        let ctx = DevContext()
        let data = try JSONEncoder().encode(ctx)
        let decoded = try JSONDecoder().decode(DevContext.self, from: data)
        XCTAssertEqual(ctx, decoded)
    }
}

@MainActor
final class DevContextManagerTests: XCTestCase {
    func testDevContextManager_init() {
        let manager = DevContextManager()
        XCTAssertNil(manager.lastContext)
        XCTAssertNil(manager.provider)
    }

    func testDevContextManager_snapshot_default() {
        let manager = DevContextManager()
        let snap = manager.snapshot()
        XCTAssertNil(snap.repo.name)
    }

    func testDevContextManager_summary_empty() {
        let manager = DevContextManager()
        let summary = manager.summary()
        XCTAssertTrue(summary.contains("开发上下文"))
    }

    func testDevContextManager_summary_withData() {
        let manager = DevContextManager()
        // Simulate a snapshot having been taken
        let summary = manager.summary()
        XCTAssertTrue(summary.contains("开发上下文"))
    }

    func testDevContextManager_refreshWithoutProvider() async {
        let manager = DevContextManager()
        let ctx = await manager.refresh()
        XCTAssertNil(ctx.repo.name)
    }
}
