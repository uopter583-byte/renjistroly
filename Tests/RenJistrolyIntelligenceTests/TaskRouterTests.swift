import XCTest
@testable import RenJistrolyIntelligence
import RenJistrolyModels

func testTaskRouterRoutesCodeTasks() {
    let task = TaskRouter().route("修复这个 Swift 项目的测试失败")

    XCTAssertTrue(task.primaryRoute.kind == .code)
    XCTAssertTrue(task.primaryRoute.confidence > 0.8)
}

func testTaskRouterRoutesTerminalCommandsAsCodeTasks() {
    let task = TaskRouter().route("在终端运行 git status")

    XCTAssertTrue(task.primaryRoute.kind == .code)
}

func testTaskRouterRoutesWebSearchAsBrowserTask() {
    let task = TaskRouter().route("搜索网页 RenJistroly macOS agent")

    XCTAssertTrue(task.primaryRoute.kind == .browser)
}

func testTaskRouterRoutesFileSearchAsFileSystemTask() {
    let task = TaskRouter().route("查找文件 Package.swift")

    XCTAssertTrue(task.primaryRoute.kind == .fileSystem)
}

func testTaskRouterRoutesMixedTasks() {
    let task = TaskRouter().route("修复代码后打开 app 点击设置验证窗口")

    XCTAssertTrue(task.primaryRoute.kind == .mixed)
    XCTAssertTrue(task.fallbackRoutes.contains { $0.kind == .code })
    XCTAssertTrue(task.fallbackRoutes.contains { $0.kind == .desktop })
}

func testMultiAgentBoardSeedsDefaultRoles() async {
    let board = MultiAgentTaskBoard()
    let items = await board.seedDefaultBoard(for: "发布 app")

    XCTAssertTrue(items.count == 6)
    XCTAssertTrue(Set(items.map(\.role)) == Set(AgentRole.allCases))
}
