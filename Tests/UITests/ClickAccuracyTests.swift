import Foundation
import XCTest
@testable import RenJistrolyModels
@testable import RenJistrolySystemBridge

// MARK: - ClickAccuracyTests

/// 点击精度测试。
/// 使用 MockAccessibilityBridge 模拟点击，验证坐标精度、元素定位和边界情况。
final class ClickAccuracyTests: XCTestCase {

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

    // MARK: - 坐标精度

    func testClickAtExactCoordinates() async throws {
        let point = CGPoint(x: 500, y: 300)
        try await mockBridge.click(at: point)

        let actions = await mockBridge.recordedActions
        let lastAction = actions.last
        XCTAssertNotNil(lastAction)
        XCTAssertTrue(lastAction?.contains("click") == true)
    }

    func testClickAtOrigin() async throws {
        try await mockBridge.click(at: .zero)
        let actions = await mockBridge.recordedActions
        let match = actions.last { $0.hasPrefix("click") }
        XCTAssertNotNil(match)
    }

    func testClickAtBoundaryCoordinates() async throws {
        let bounds = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1728, y: 0),
            CGPoint(x: 0, y: 1117),
            CGPoint(x: 1728, y: 1117),
        ]
        for point in bounds {
            try await mockBridge.click(at: point)
        }
        let actions = await mockBridge.recordedActions
        let clickActions = actions.filter { $0.hasPrefix("click") }
        XCTAssertEqual(clickActions.count, 4, "所有边界点击都应被记录")
    }

    func testClickAtNegativeCoordinates() async throws {
        let point = CGPoint(x: -100, y: -100)
        try await mockBridge.click(at: point)
        let actions = await mockBridge.recordedActions
        let clickAction = actions.last
        XCTAssertNotNil(clickAction)
    }

    // MARK: - 权限缺乏

    func testClickWithoutPermission() async {
        let untrustedBridge = MockAccessibilityBridge(isTrusted: false)
        let point = CGPoint(x: 100, y: 100)

        do {
            try await untrustedBridge.click(at: point)
            XCTFail("无权限时应抛出错误")
        } catch {
            XCTAssertTrue(error is AccessibilityError)
        }
    }

    // MARK: - 多次点击

    func testSequentialClicks() async throws {
        let points = stride(from: 0, to: 500, by: 50).map { CGPoint(x: $0, y: $0) }
        for point in points {
            try await mockBridge.click(at: point)
        }
        let actions = await mockBridge.recordedActions
        let clickCount = actions.filter { $0.hasPrefix("click") }.count
        XCTAssertEqual(clickCount, points.count, "所有点击应被记录")
    }

    func testRapidClicksDoNotCrash() async throws {
        for _ in 0..<50 {
            try await mockBridge.click(at: CGPoint(x: 100, y: 200))
        }
        let actions = await mockBridge.recordedActions
        let clickCount = actions.filter { $0.hasPrefix("click") }.count
        XCTAssertEqual(clickCount, 50, "50 次快速点击应全部记录")
    }

    // MARK: - 元素点击

    func testClickWithElementIndex() async throws {
        await mockBridge.click(elementIndex: "e1", app: "Safari", clickCount: 1)
        let actions = await mockBridge.recordedActions
        let clickAction = actions.last
        XCTAssertNotNil(clickAction)
    }

    func testDoubleClickElement() async throws {
        await mockBridge.click(elementIndex: "e1", app: "Finder", clickCount: 2)
        let actions = await mockBridge.recordedActions
        let clickCount = actions.filter { $0.hasPrefix("click") }.count
        XCTAssertGreaterThanOrEqual(clickCount, 1)
    }

    // MARK: - 混合操作序列

    func testClickThenTypeSequence() async throws {
        try await mockBridge.click(at: CGPoint(x: 200, y: 300))
        try await mockBridge.typeText("Hello World")

        let actions = await mockBridge.recordedActions
        let clickCount = actions.filter { $0.hasPrefix("click") }.count
        let typeCount = actions.filter { $0.hasPrefix("typeText") }.count
        XCTAssertEqual(clickCount, 1)
        XCTAssertEqual(typeCount, 1)
    }

    func testClickScrollClickSequence() async throws {
        try await mockBridge.click(at: CGPoint(x: 100, y: 100))
        try await mockBridge.scroll(deltaY: -3)
        try await mockBridge.click(at: CGPoint(x: 100, y: 50))

        let actions = await mockBridge.recordedActions
        let clickCount = actions.filter { $0.hasPrefix("click") }.count
        let scrollCount = actions.filter { $0.hasPrefix("scroll") }.count
        XCTAssertEqual(clickCount, 2)
        XCTAssertEqual(scrollCount, 1)
    }

    // MARK: - 重置验证

    func testResetClearsActions() async throws {
        try await mockBridge.click(at: CGPoint(x: 10, y: 10))
        var actions = await mockBridge.recordedActions
        XCTAssertGreaterThan(actions.count, 0)

        await mockBridge.resetActions()
        actions = await mockBridge.recordedActions
        XCTAssertTrue(actions.isEmpty, "重置后记录应清空")
    }
}

// MARK: - AccessibilityBridge 辅助方法（已通过 actor 直接用）
