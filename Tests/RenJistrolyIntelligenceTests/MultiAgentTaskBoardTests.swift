import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - MultiAgentTaskBoard

func testSeedDefaultBoardCreatesSixItems() async {
    let board = MultiAgentTaskBoard()
    let items = await board.seedDefaultBoard(for: "实现登录功能")
    XCTAssertTrue(items.count == 6)
}

func testSeedDefaultBoardIncludesAllRoles() async {
    let board = MultiAgentTaskBoard()
    let items = await board.seedDefaultBoard(for: "测试任务")
    let roles = Set(items.map(\.role))
    XCTAssertTrue(roles.count == 6)
    XCTAssertTrue(roles.contains(.planner))
    XCTAssertTrue(roles.contains(.code))
    XCTAssertTrue(roles.contains(.test))
    XCTAssertTrue(roles.contains(.review))
    XCTAssertTrue(roles.contains(.desktop))
    XCTAssertTrue(roles.contains(.summary))
}

func testSeedDefaultBoardItemsHaveObjective() async {
    let board = MultiAgentTaskBoard()
    let items = await board.seedDefaultBoard(for: "重构数据库层")
    for item in items {
        XCTAssertFalse(item.objective.isEmpty)
        XCTAssertTrue(item.status == .queued)
    }
}

func testSeedDefaultBoardReturnsTemplateOrder() async {
    let board = MultiAgentTaskBoard()
    let items = await board.seedDefaultBoard(for: "任务")
    let roles = items.map(\.role)
    XCTAssertTrue(roles == [.planner, .code, .test, .review, .desktop, .summary])
}

func testAllReturnsSorted() async {
    let board = MultiAgentTaskBoard()
    _ = await board.seedDefaultBoard(for: "任务")
    let all = await board.all()
    XCTAssertTrue(all.count == 6)
    let roleNames = all.map(\.role.rawValue)
    XCTAssertTrue(roleNames == roleNames.sorted())
}

func testAddItem() async {
    let board = MultiAgentTaskBoard()
    let item = await board.add(role: .code, objective: "修复 bug")
    XCTAssertTrue(item.role == .code)
    XCTAssertTrue(item.objective == "修复 bug")
    XCTAssertTrue(item.status == .queued)
    let all = await board.all()
    XCTAssertTrue(all.count == 1)
}

func testUpdateItemStatus() async {
    let board = MultiAgentTaskBoard()
    let item = await board.add(role: .test, objective: "运行测试")
    await board.update(item.id, status: .running)
    let all = await board.all()
    XCTAssertTrue(all.first?.status == .running)
}

func testUpdateItemLog() async {
    let board = MultiAgentTaskBoard()
    let item = await board.add(role: .planner, objective: "规划")
    await board.update(item.id, latestLog: "步骤1完成")
    let all = await board.all()
    XCTAssertTrue(all.first?.latestLog == "步骤1完成")
}

func testUpdateNonexistentItem() async {
    let board = MultiAgentTaskBoard()
    await board.update(UUID(), status: .completed)
    let all = await board.all()
    XCTAssertTrue(all.isEmpty)
}

func testByStatusReturnsFiltered() async {
    let board = MultiAgentTaskBoard()
    let item1 = await board.add(role: .code, objective: "任务1")
    let item2 = await board.add(role: .test, objective: "任务2")
    await board.update(item1.id, status: .completed)
    await board.update(item2.id, status: .running)
    let completed = await board.byStatus(.completed)
    let running = await board.byStatus(.running)
    XCTAssertTrue(completed.count == 1)
    XCTAssertTrue(running.count == 1)
    XCTAssertTrue(completed[0].id == item1.id)
}

func testByStatusEmptyForMissing() async {
    let board = MultiAgentTaskBoard()
    _ = await board.add(role: .summary, objective: "总结")
    let failed = await board.byStatus(.failed)
    XCTAssertTrue(failed.isEmpty)
}

// MARK: - MultiAgentBoardItem

func testMultiAgentBoardItemDefaults() {
    let item = MultiAgentBoardItem(role: .planner, objective: "拆解任务")
    XCTAssertTrue(item.role == .planner)
    XCTAssertTrue(item.status == .queued)
    XCTAssertTrue(item.latestLog == nil)
    XCTAssertTrue(item.artifactPaths.isEmpty)
}

// MARK: - AgentRole

func testAgentRoleAllCases() {
    let all = AgentRole.allCases
    XCTAssertTrue(all.count == 6)
}

// MARK: - AgentTaskStatus

func testAgentTaskStatusDefaultQueued() {
    let item = MultiAgentBoardItem(role: .code, objective: "test")
    XCTAssertTrue(item.status == .queued)
}
