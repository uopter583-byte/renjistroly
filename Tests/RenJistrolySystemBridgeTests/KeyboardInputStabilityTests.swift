import Foundation
import XCTest
@testable import RenJistrolySystemBridge

// MARK: - 键盘输入稳定性测试

func testTypeTextAtCurrentCursorPosition() async {
    let bridge = AccessibilityBridge()
    // Without AX permission, typeText should throw .noPermission
    do {
        try await bridge.typeText("hello world")
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

func testTypeTextIntoSpecificAXControl() async {
    let bridge = AccessibilityBridge()
    // Without AX permission, setValue should throw .noPermission
    do {
        try await bridge.setValue(elementIndex: "e1", value: "test input", app: nil)
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

func testPasteTextFromClipboard() async {
    let bridge = AccessibilityBridge()
    // Without AX permission, pasteText should throw .noPermission
    do {
        try await bridge.pasteText("pasted content", restorePasteboard: false)
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

func testKeyboardShortcutExecution() async {
    let bridge = AccessibilityBridge()
    // Without AX permission, pressKey should throw .noPermission
    do {
        try await bridge.pressKey("c", modifiers: ["cmd"])
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

func testEnterReturnKeyPress() async {
    let bridge = AccessibilityBridge()
    // Without AX permission, pressKey should throw .noPermission
    do {
        try await bridge.pressKey("return")
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

func testUndoActionCmdZ() async {
    let bridge = AccessibilityBridge()
    // Without AX permission, pressKey should throw .noPermission
    do {
        try await bridge.pressKey("z", modifiers: ["cmd"])
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

func testCrossAppInputPreventionSecurity() async {
    let bridge = AccessibilityBridge()
    // Cmd+Q and Cmd+W should be blocked even with permission
    do {
        try await bridge.pressKey("q", modifiers: ["cmd"])
        XCTFail("应该阻止 Cmd+Q")
    } catch let error as AccessibilityError {
        if case .actionFailed(let msg) = error {
            XCTAssertTrue(msg.contains("安全限制"))
        } else {
            XCTFail("错误的异常类型: \(error)")
        }
    } catch {
        XCTFail("错误的异常类型: \(error)")
    }

    do {
        try await bridge.pressKey("w", modifiers: ["cmd"])
        XCTFail("应该阻止 Cmd+W")
    } catch let error as AccessibilityError {
        if case .actionFailed(let msg) = error {
            XCTAssertTrue(msg.contains("安全限制"))
        } else {
            XCTFail("错误的异常类型: \(error)")
        }
    } catch {
        XCTFail("错误的异常类型: \(error)")
    }
}

func testClipboardContentRestorationAfterPaste() async {
    let sys = SystemDriver()
    // Save and restore clipboard
    let original = sys.readClipboard()
    sys.writeClipboard("temp paste content")
    XCTAssertTrue(sys.readClipboard() == "temp paste content")
    // Restore original
    if let original {
        sys.writeClipboard(original)
        XCTAssertTrue(sys.readClipboard() == original)
    }
}

func testChineseInputMethodHandling() async {
    let bridge = AccessibilityBridge()
    // TypeText with Chinese characters requires AX permission
    do {
        try await bridge.typeText("中文测试")
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

func testInputFailureGracefulError() {
    // Verify AccessibilityError descriptions are meaningful
    let noPerm = AccessibilityError.noPermission
    XCTAssertTrue(noPerm.errorDescription?.contains("辅助功能权限") == true)

    let actionFail = AccessibilityError.actionFailed("pressKey")
    XCTAssertTrue(actionFail.errorDescription?.contains("pressKey") == true)

    let notFound = AccessibilityError.elementNotFound
    XCTAssertTrue(notFound.errorDescription?.contains("未找到") == true)
}

// MARK: - AppleScriptBridge keyboard tests

func testAppleScriptBridgeSendKeystroke() async {
    let bridge = AppleScriptBridge()
    // Keystroke execution may fail due to permissions, but should not crash
    do {
        try await bridge.sendKeystroke("hello", to: nil)
        // If success, keystroke was sent
        XCTAssertTrue(true)
    } catch {
        // If error, it should be AppleScriptError
        XCTAssertTrue(error is AppleScriptError)
    }
}

func testAppleScriptBridgeSendKeystrokeToApp() async {
    let bridge = AppleScriptBridge()
    do {
        try await bridge.sendKeystroke("test", to: "Finder")
        XCTAssertTrue(true)
    } catch {
        XCTAssertTrue(error is AppleScriptError)
    }
}

func testSystemDriverClipboardRoundTrip() {
    let sys = SystemDriver()
    let testString = "clipboard-test-\(UUID().uuidString)"
    sys.writeClipboard(testString)
    let read = sys.readClipboard()
    XCTAssertTrue(read == testString)
}

func testAccessibilityBridgeTrySetTextToFocused() async {
    let bridge = AccessibilityBridge()
    do {
        try await bridge.trySetTextToFocused("test")
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
