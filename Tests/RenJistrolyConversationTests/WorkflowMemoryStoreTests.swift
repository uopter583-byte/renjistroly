import Foundation
import XCTest
@testable import RenJistrolyConversation

func testWorkflowMemoryStorePersistsMemoriesToDisk() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directory.appendingPathComponent("workflow-memories.json")

    let store = WorkflowMemoryStore(storageURL: fileURL)
    _ = await store.remember(
        task: "打开 Finder 并搜索文件",
        steps: ["route: fileSystem", "finder_search"],
        success: true,
        learnedWorkflow: "route: fileSystem -> finder_search"
    )

    let reloadedStore = WorkflowMemoryStore(storageURL: fileURL)
    let memories = await reloadedStore.all()

    XCTAssertTrue(memories.count == 1)
    XCTAssertTrue(memories.first?.task == "打开 Finder 并搜索文件")
    XCTAssertTrue(memories.first?.steps == ["route: fileSystem", "finder_search"])
    XCTAssertTrue(memories.first?.success == true)
}

func testWorkflowMemoryStoreRecallReturnsLatestMatchesFirst() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("workflow-memories.json")
    let store = WorkflowMemoryStore(storageURL: fileURL)

    _ = await store.remember(
        task: "搜索 Safari 标签页",
        steps: ["route: browser", "safari_search"],
        success: true
    )
    _ = await store.remember(
        task: "搜索 Finder 文件",
        steps: ["route: fileSystem", "finder_search"],
        success: true
    )

    let recalled = await store.recall(matching: "搜索")

    XCTAssertTrue(recalled.count == 2)
    XCTAssertTrue(recalled.first?.task == "搜索 Finder 文件")
    XCTAssertTrue(recalled.last?.task == "搜索 Safari 标签页")
}

func testWorkflowMemoryStoreAggregatesRecoveryStrategyScores() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("workflow-memories.json")
    let store = WorkflowMemoryStore(storageURL: fileURL)

    _ = await store.remember(
        task: "点击发送按钮",
        steps: ["route: desktop", "tool: click", "strategy: remapByStableID"],
        success: true
    )
    _ = await store.remember(
        task: "再次点击发送按钮",
        steps: ["route: desktop", "tool: click", "strategy: remapByStableID"],
        success: false
    )
    _ = await store.remember(
        task: "恢复前台应用",
        steps: ["route: desktop", "tool: click", "strategy: activateTargetApp"],
        success: true
    )

    let scores = await store.recoveryStrategyScores()

    XCTAssertTrue(scores["remapByStableID"]?.attempts == 2)
    XCTAssertTrue(scores["remapByStableID"]?.successes == 1)
    XCTAssertTrue(scores["remapByStableID"]?.successRate == 0.5)
    XCTAssertTrue(scores["activateTargetApp"]?.successRate == 1.0)
}

func testWorkflowMemoryStoreBucketsRecoveryScoresByAppAndTool() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("workflow-memories.json")
    let store = WorkflowMemoryStore(storageURL: fileURL)

    _ = await store.remember(
        task: "Safari 点击按钮",
        steps: ["route: browser", "app: Safari", "tool: click", "strategy: remapByStableID"],
        success: true
    )
    _ = await store.remember(
        task: "Finder 点击按钮",
        steps: ["route: fileSystem", "app: Finder", "tool: click", "strategy: coordinateClickFallback"],
        success: true
    )
    _ = await store.remember(
        task: "Safari 再次点击按钮",
        steps: ["route: browser", "app: Safari", "tool: click", "strategy: remapByStableID"],
        success: false
    )

    let safariClickScores = await store.recoveryStrategyScores(appName: "Safari", toolName: "click")
    let finderClickScores = await store.recoveryStrategyScores(appName: "Finder", toolName: "click")

    XCTAssertTrue(safariClickScores["remapByStableID"]?.attempts == 2)
    XCTAssertTrue(safariClickScores["coordinateClickFallback"] == nil)
    XCTAssertTrue(finderClickScores["coordinateClickFallback"]?.successRate == 1.0)
    XCTAssertTrue(finderClickScores["remapByStableID"] == nil)
}

func testWorkflowMemoryStoreChoosesMostSpecificRecoveryProfile() async throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("workflow-memories.json")
    let store = WorkflowMemoryStore(storageURL: fileURL)

    _ = await store.remember(
        task: "全局 click 恢复",
        steps: ["tool: click", "strategy: reobserveAndRetry"],
        success: true
    )
    _ = await store.remember(
        task: "Safari click 恢复",
        steps: ["app: Safari", "tool: click", "strategy: remapByStableID"],
        success: true
    )

    let profile = await store.bestRecoveryStrategyProfile(appName: "Safari", toolName: "click")

    XCTAssertTrue(profile.scope == "app+tool")
    XCTAssertTrue(profile.scores["remapByStableID"]?.successRate == 1.0)
    XCTAssertTrue(profile.scores["reobserveAndRetry"] == nil)
}

// MARK: - RecoveryStrategyScore

func testRecoveryStrategyScoreSuccessRateZeroWhenNoAttempts() {
    let score = WorkflowMemoryStore.RecoveryStrategyScore(attempts: 0, successes: 0)
    XCTAssertTrue(score.successRate == 0)
}

func testRecoveryStrategyScoreSuccessRateFull() {
    let score = WorkflowMemoryStore.RecoveryStrategyScore(attempts: 10, successes: 10)
    XCTAssertTrue(score.successRate == 1.0)
}

func testRecoveryStrategyScoreSuccessRateHalf() {
    let score = WorkflowMemoryStore.RecoveryStrategyScore(attempts: 4, successes: 2)
    XCTAssertTrue(score.successRate == 0.5)
}

func testRecoveryStrategyScoreSuccessRatePartial() {
    let score = WorkflowMemoryStore.RecoveryStrategyScore(attempts: 3, successes: 1)
    XCTAssertTrue((score.successRate * 100).rounded() / 100 == 0.33)
}

// MARK: - RecoveryStrategyProfile

func testRecoveryStrategyProfileSuccessRates() {
    let scores: [String: WorkflowMemoryStore.RecoveryStrategyScore] = [
        "remapByStableID": .init(attempts: 5, successes: 4),
        "reobserveAndRetry": .init(attempts: 2, successes: 1),
    ]
    let profile = WorkflowMemoryStore.RecoveryStrategyProfile(scores: scores, scope: "app+tool")
    XCTAssertTrue(profile.scope == "app+tool")
    XCTAssertTrue(profile.successRates["remapByStableID"] == 0.8)
    XCTAssertTrue(profile.successRates["reobserveAndRetry"] == 0.5)
}

func testRecoveryStrategyProfileEmptyScores() {
    let profile = WorkflowMemoryStore.RecoveryStrategyProfile(scores: [:], scope: "global")
    XCTAssertTrue(profile.successRates.isEmpty)
}
