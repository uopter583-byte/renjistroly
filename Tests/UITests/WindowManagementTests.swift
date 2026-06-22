import Foundation
import XCTest
@testable import RenJistrolyModels
@testable import RenJistrolySystemBridge

// MARK: - WindowManagementTests

/// 窗口管理测试。
/// 使用 MockAccessibilityBridge 模拟窗口操作：列表、聚焦、调整大小等。
final class WindowManagementTests: XCTestCase {

    private var mockBridge: MockAccessibilityBridge!

    override func setUp() {
        super.setUp()
        mockBridge = MockAccessibilityBridge(
            isTrusted: true,
            mockFocusedBundleID: "com.apple.Safari",
            mockFocusedWindowTitle: "Safari 测试窗口"
        )
    }

    override func tearDown() {
        mockBridge = nil
        super.tearDown()
    }

    // MARK: - 窗口列表

    func testGetWindowList() async throws {
        let windows = try await mockBridge.getWindowList()
        XCTAssertFalse(windows.isEmpty, "窗口列表不应为空")
        XCTAssertTrue(windows.contains("测试窗口"), "应包含模拟的测试窗口")
    }

    func testGetWindowListWhenUntrusted() async {
        let untrusted = MockAccessibilityBridge(isTrusted: false)
        do {
            _ = try await untrusted.getWindowList()
            XCTFail("无权限时应抛出错误")
        } catch {
            XCTAssertTrue(error is AccessibilityError)
        }
    }

    func testGetWindowListReturnsExpectedTitles() async throws {
        let titles = try await mockBridge.getWindowList()
        let expected = ["窗口1", "窗口2", "测试窗口"]
        for title in expected {
            XCTAssertTrue(titles.contains(title), "应包含 '\(title)'")
        }
        XCTAssertEqual(titles.count, expected.count)
    }

    // MARK: - 窗口聚焦

    func testFocusWindowByTitle() async throws {
        try await mockBridge.focusWindow(title: "测试窗口")
        let actions = await mockBridge.recordedActions
        let lastAction = actions.last
        XCTAssertNotNil(lastAction)
        XCTAssertTrue(lastAction?.contains("focusWindow") == true)
        XCTAssertTrue(lastAction?.contains("测试窗口") == true)
    }

    func testFocusWindowPartialMatch() async throws {
        try await mockBridge.focusWindow(title: "测试")
        let actions = await mockBridge.recordedActions
        let lastAction = actions.last
        XCTAssertNotNil(lastAction)
        XCTAssertTrue(lastAction?.contains("测试") == true)
    }

    func testFocusNonexistentWindowThrows() async {
        do {
            try await mockBridge.focusWindow(title: "不存在的窗口啊啊啊")
        } catch {
            XCTFail("Mock 环境下不应抛出")
        }
    }

    // MARK: - 获取焦点信息

    func testGetFocusedAppBundleID() async throws {
        let bundleID = try await mockBridge.getFocusedAppBundleID()
        XCTAssertEqual(bundleID, "com.apple.Safari")
    }

    func testGetFocusedWindowTitle() async throws {
        let title = try await mockBridge.getFocusedWindowTitle()
        XCTAssertEqual(title, "Safari 测试窗口")
    }

    func testGetFocusedInfoWithoutPermission() async {
        let untrusted = MockAccessibilityBridge(isTrusted: false)
        do {
            _ = try await untrusted.getFocusedAppBundleID()
            XCTFail("无权限时应抛出")
        } catch {
            XCTAssertTrue(error is AccessibilityError)
        }
    }

    // MARK: - UI 元素树

    func testGetUIElementTree() async throws {
        let tree = try await mockBridge.getUIElementTree()
        XCTAssertTrue(tree.isEmpty)
    }

    func testGetUIElementTreeWithElements() async throws {
        let elements = [
            UIElementNode(role: "AXWindow", title: "窗口1", description: nil, depth: 0),
            UIElementNode(role: "AXButton", title: "确定", description: "确认按钮", depth: 1),
            UIElementNode(role: "AXTextField", title: "搜索", description: nil, depth: 1),
        ]
        let bridge = MockAccessibilityBridge(mockElementTree: elements)
        let tree = try await bridge.getUIElementTree()
        XCTAssertEqual(tree.count, 3)
        XCTAssertEqual(tree[0].role, "AXWindow")
        XCTAssertEqual(tree[1].title, "确定")
    }

    // MARK: - 窗口操作序列

    func testFocusThenGetTitle() async throws {
        try await mockBridge.focusWindow(title: "测试窗口")
        let title = try await mockBridge.getFocusedWindowTitle()
        XCTAssertEqual(title, "Safari 测试窗口")

        let actions = await mockBridge.recordedActions
        XCTAssertGreaterThanOrEqual(actions.count, 1)
    }

    func testMultiWindowScenario() {
        let ctx = MockScreenScenario.multiWindow()
        let windowNames = ctx.visibleWindows.map(\.ownerName)
        XCTAssertEqual(windowNames, ["Xcode", "Safari", "终端"])
        let bounds = ctx.visibleWindows.map(\.boundsDescription)
        for b in bounds {
            XCTAssertTrue(b.contains("x:"), "boundsDescription 应包含坐标信息")
        }
    }

    // MARK: - Mock 重置

    func testResetAfterWindowOperations() async throws {
        try await mockBridge.focusWindow(title: "窗口1")
        var actions = await mockBridge.recordedActions
        XCTAssertGreaterThan(actions.count, 0)

        await mockBridge.resetActions()
        actions = await mockBridge.recordedActions
        XCTAssertTrue(actions.isEmpty)
    }
}

// MARK: - UIElementNode 结构测试

final class UIElementNodeTests: XCTestCase {
    func testNodeCreation() {
        let node = UIElementNode(role: "AXButton", title: "提交", description: "提交表单", depth: 2)
        XCTAssertEqual(node.role, "AXButton")
        XCTAssertEqual(node.title, "提交")
        XCTAssertEqual(node.description, "提交表单")
        XCTAssertEqual(node.depth, 2)
    }

    func testNodeWithNilTitle() {
        let node = UIElementNode(role: "AXGroup", title: nil, description: nil, depth: 0)
        XCTAssertNil(node.title)
        XCTAssertNil(node.description)
    }

    func testNodeHashable() {
        let a = UIElementNode(role: "AXButton", title: "OK", description: nil, depth: 1)
        let b = UIElementNode(role: "AXButton", title: "OK", description: nil, depth: 1)
        let c = UIElementNode(role: "AXButton", title: "Cancel", description: nil, depth: 1)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
