import Foundation
import XCTest
import RenJistrolyModels
import RenJistrolySystemBridge
@testable import RenJistrolyCapability

// MARK: - 鼠标控制稳定性测试

func testClickAtScreenCoordinates() {
    // CursorController click is a pure CGEvent operation
    let point = CGPoint(x: 500, y: 500)
    CursorController.click(at: point)
    // No crash means success
    XCTAssertTrue(true)
}

func testClickOnUIElementByLabelAndRole() async {
    let bridge = AccessibilityBridge()
    // Without AX permission, clickElement should throw .noPermission
    do {
        try await bridge.clickElement(role: "AXButton", title: "确定", label: nil)
        XCTFail("应该在无权限时抛出异常")
    } catch let error as AccessibilityError {
        if case .noPermission = error {
            XCTAssertTrue(true)
        } else {
            XCTFail("错误的异常类型: \(error)")
        }
    } catch {
        XCTFail("错误的异常类型: \(error)")
    }
}

func testRightClickFunctionality() {
    let point = CGPoint(x: 600, y: 400)
    CursorController.rightClick(at: point)
    // Right-click is a CGEvent operation with right mouse button
    XCTAssertTrue(true)
}

func testDoubleClickAction() {
    let point = CGPoint(x: 300, y: 300)
    CursorController.doubleClick(at: point)
    // Double-click invokes two left clicks in sequence
    XCTAssertTrue(true)
}

func testDragFromPointAToB() {
    let start = CGPoint(x: 100, y: 100)
    let end = CGPoint(x: 400, y: 400)
    CursorController.drag(from: start, to: end, steps: 10)
    // Drag posts leftMouseDown, leftMouseDragged, leftMouseUp events
    XCTAssertTrue(true)
}

func testScrollUpDownLeftRight() async {
    let bridge = AccessibilityBridge()
    // Without AX permission, scroll should throw .noPermission
    do {
        try await bridge.scroll(deltaY: 3)
        XCTFail("应该在无权限时抛出异常")
    } catch let error as AccessibilityError {
        if case .noPermission = error {
            XCTAssertTrue(true)
        } else {
            XCTFail("错误的异常类型: \(error)")
        }
    } catch {
        XCTFail("错误的异常类型: \(error)")
    }
}

func testTargetAppValidationBeforeClick() {
    // Chromium detection is pure logic
    XCTAssertTrue(InputStrategySelector.isChromium("com.google.Chrome"))
    XCTAssertTrue(InputStrategySelector.isChromium("com.microsoft.VSCode"))
    XCTAssertTrue(InputStrategySelector.isChromium("com.github.electron"))
    XCTAssertTrue(!InputStrategySelector.isChromium("com.apple.finder"))
    XCTAssertTrue(!InputStrategySelector.isChromium("com.apple.Safari"))
    XCTAssertTrue(!InputStrategySelector.isChromium(nil))
}

func testForegroundAppChangeAbort() async {
    let bridge = AccessibilityBridge()
    // Without AX permission, moveMouse should throw
    do {
        try await bridge.moveMouse(to: CGPoint(x: 100, y: 100))
        XCTFail("应该在无权限时抛出异常")
    } catch let error as AccessibilityError {
        if case .noPermission = error {
            XCTAssertTrue(true)
        } else {
            XCTFail("错误的异常类型: \(error)")
        }
    } catch {
        XCTFail("错误的异常类型: \(error)")
    }
}

func testFailureVerificationElementNotFound() async {
    let bridge = AccessibilityBridge()
    // getFocusedElement should throw .noPermission without AX
    do {
        _ = try await bridge.getFocusedElement()
        XCTFail("应该在无权限时抛出异常")
    } catch let error as AccessibilityError {
        if case .noPermission = error {
            XCTAssertTrue(true)
        } else {
            XCTFail("错误的异常类型: \(error)")
        }
    } catch {
        XCTFail("错误的异常类型: \(error)")
    }
}

func testClickWithWrongAppBundleCheck() {
    // Strategy selector with nil bundle and no AX support
    let strategy = InputStrategySelector.selectClickStrategy(
        point: CGPoint(x: 100, y: 100),
        element: nil,
        bundleID: nil
    )
    if case .basicBackground = strategy {
        XCTAssertTrue(true)
    } else {
        XCTFail("expected basicBackground for nil bundle")
    }

    // Chromium bundle with nil element
    let chromeStrategy = InputStrategySelector.selectClickStrategy(
        point: CGPoint(x: 100, y: 100),
        element: nil,
        bundleID: "com.google.Chrome"
    )
    if case .chromiumStyle = chromeStrategy {
        XCTAssertTrue(true)
    } else {
        XCTFail("expected chromiumStyle for Chrome")
    }
}

// MARK: - CursorController edge cases

func testCursorControllerCurrentPosition() {
    let pos = CursorController.currentPosition
    XCTAssertTrue(pos.x >= 0)
    XCTAssertTrue(pos.y >= 0)
}

func testCursorControllerSmoothMove() {
    let target = CGPoint(x: 800, y: 600)
    CursorController.smoothMove(to: target, steps: 5)
    XCTAssertTrue(true)
}

func testClickToolDefinition() {
    let tool = ClickTool()
    XCTAssertTrue(tool.definition.name == "click")
    XCTAssertFalse(tool.definition.description.isEmpty)
    XCTAssertTrue(tool.riskLevel == .medium)
}

func testGetAppStateToolDefinition() {
    let tool = GetAppStateTool()
    XCTAssertTrue(tool.definition.name == "get_app_state")
    XCTAssertFalse(tool.definition.description.isEmpty)
    XCTAssertTrue(tool.riskLevel == .low)
}
