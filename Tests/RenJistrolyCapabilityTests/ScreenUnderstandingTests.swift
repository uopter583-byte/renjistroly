import Foundation
import XCTest
import CoreGraphics
import RenJistrolyModels
@testable import RenJistrolyCapability
@testable import RenJistrolySystemBridge

// MARK: - Popup and Dialog Stack

final class ScreenUnderstandingTests: XCTestCase {
        }
    func testActiveDialogStateStackingMultipleDialogs() {
        let dialogs: [ActiveDialogState] = [
            ActiveDialogState(appName: "Safari", title: "确认关闭多个标签页", role: "AXSheet"),
            ActiveDialogState(appName: "Safari", title: "保存密码", role: "AXSheet"),
            ActiveDialogState(appName: "Safari", title: "表单自动填充", role: "AXPopover"),
        ]
        XCTAssertTrue(dialogs.count == 3)
        XCTAssertTrue(dialogs[0].role == "AXSheet")
        XCTAssertTrue(dialogs[1].role == "AXSheet")
        XCTAssertTrue(dialogs[2].role == "AXPopover")

        }
    func testActiveDialogStateUniqueIDs() {
        let ids = [
            ActiveDialogState(appName: "Safari", title: "确认", role: "AXSheet"),
            ActiveDialogState(appName: "Safari", title: "确认", role: "AXSheet"),
            ActiveDialogState(appName: "Finder", title: "确认", role: "AXSheet"),
        ].map(\.id)
        XCTAssertTrue(ids[0] == ids[1])
        XCTAssertTrue(ids[0] != ids[2])

    // MARK: - Occluded Windows

        }
    func testVisibleWindowContextOccludedDetection() {
        let front = VisibleWindowContext(ownerName: "Safari", windowTitle: "Front", layer: 3, boundsDescription: "0,0,1440,900")
        let middle = VisibleWindowContext(ownerName: "Terminal", windowTitle: "Middle", layer: 1, boundsDescription: "100,100,800,600")
        let back = VisibleWindowContext(ownerName: "Finder", windowTitle: nil, layer: 0, boundsDescription: "200,200,400,300")
        let sorted = [back, front, middle].sorted { $0.layer > $1.layer }
        XCTAssertTrue(sorted[0].ownerName == "Safari")
        XCTAssertTrue(sorted[1].ownerName == "Terminal")
        XCTAssertTrue(sorted[2].ownerName == "Finder")

        }
    func testOccludedWindowHasNoTitle() {
        let hidden = VisibleWindowContext(ownerName: "BackgroundApp", windowTitle: nil, layer: 0, boundsDescription: "0,0,300,200")
        XCTAssertTrue(hidden.windowTitle == nil)
        XCTAssertTrue(hidden.ownerName == "BackgroundApp")

    // MARK: - Permission Missing

        }
    func testScreenCaptureErrorNoDisplay() {
        let error = ScreenCaptureError.noDisplayAvailable
        XCTAssertTrue(error.errorDescription?.contains("可用显示器") == true)

        }
    func testScreenCaptureErrorImageConversion() {
        let error = ScreenCaptureError.imageConversionFailed
        XCTAssertTrue(error.errorDescription?.contains("转换失败") == true)

        }
    func testScreenCaptureErrorStreamError() {
        let error = ScreenCaptureError.streamError("permission denied")
        XCTAssertTrue(error.errorDescription?.contains("权限") == true)

        }
    func testScreenRecordingPermissionAllowsDetection() {
        let grant = AppState.PermissionGrant()
        XCTAssertFalse(grant.screenRecording)
        var granted = grant
        granted.screenRecording = true
        XCTAssertTrue(granted.screenRecording)

        }
    func testPermissionGrantIndividualFields() {
        var pg = AppState.PermissionGrant()
        pg.screenRecording = true
        pg.accessibility = true
        XCTAssertTrue(pg.screenRecording)
        XCTAssertTrue(pg.accessibility)
        XCTAssertFalse(pg.microphone)
        XCTAssertFalse(pg.allGranted) // still missing permissions

    // MARK: - Low-Text Pages

        }
    func testScreenContextWithMinimalText() {
        let ctx = ScreenContext(
            displayDescription: "Main Display",
            recognizedText: ""
        )
        XCTAssertTrue(ctx.recognizedText?.isEmpty == true)

        }
    func testScreenContextWithWhitespaceOnlyText() {
        let ctx = ScreenContext(
            displayDescription: "Built-in Retina",
            recognizedText: "   \n  \n  "
        )
        let trimmed = ctx.recognizedText?.trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(trimmed?.isEmpty == true)

        }
    func testScreenContextWithSingleWord() {
        let ctx = ScreenContext(
            displayDescription: "External Display",
            recognizedText: "OK"
        )
        XCTAssertTrue(ctx.recognizedText == "OK")
        XCTAssertTrue(ctx.recognizedText?.count == 2)

    // MARK: - Multi-Window Context

        }
    func testMultiWindowWithMixedVisibility() {
        let windows: [VisibleWindowContext] = [
            VisibleWindowContext(ownerName: "Xcode", windowTitle: "main.swift", layer: 2, boundsDescription: "0,0,1200,800"),
            VisibleWindowContext(ownerName: "Safari", windowTitle: "Documents", layer: 1, boundsDescription: "300,100,900,700"),
            VisibleWindowContext(ownerName: "Terminal", windowTitle: "build log", layer: 0, boundsDescription: "50,50,600,400"),
        ]
        let topWindows = windows.filter { $0.layer >= 1 }
        XCTAssertTrue(topWindows.count == 2)

        }
    func testWindowBoundsParsing() {
        let w = VisibleWindowContext(ownerName: "Safari", windowTitle: "Page", layer: 1, boundsDescription: "0,0,1440,900")
        let parts = w.boundsDescription.split(separator: ",").compactMap { Int($0) }
        XCTAssertTrue(parts == [0, 0, 1440, 900])

        }
    func testWindowIdentityAcrossUpdates() {
        let w1 = VisibleWindowContext(ownerName: "Safari", windowTitle: "Tab A", layer: 1, boundsDescription: "0,0,800,600")
        let w2 = VisibleWindowContext(ownerName: "Safari", windowTitle: "Tab A", layer: 1, boundsDescription: "0,0,800,600")
        XCTAssertTrue(w1.id == w2.id)
        let w3 = VisibleWindowContext(ownerName: "Safari", windowTitle: "Tab B", layer: 1, boundsDescription: "0,0,800,600")
        XCTAssertTrue(w1.id != w3.id)

    // MARK: - AssistantContext (screen-understanding aggregation)

        }
    func testAssistantContextWithNoDialogs() {
        let ctx = AssistantContext(
            app: AppContext(appName: "Finder"),
            screen: ScreenContext(displayDescription: "Main"),
            activeDialogs: []
        )
        XCTAssertTrue(ctx.activeDialogs.isEmpty)

        }
    func testAssistantContextWithoutSelectedText() {
        let ctx = AssistantContext(
            focusedElement: UIElementContext(role: "AXTextField", title: "搜索", value: "hello", selectedText: nil)
        )
        XCTAssertTrue(ctx.focusedElement?.selectedText == nil)
        XCTAssertTrue(ctx.focusedElement?.value == "hello")

        }
    func testAssistantContextAppWithoutBundleID() {
        let ctx = AppContext(appName: "Finder")
        XCTAssertTrue(ctx.appName == "Finder")
        XCTAssertTrue(ctx.bundleIdentifier == nil)

    // MARK: - Screen Context data model tests

        }
    func testScreenContextInitialState() {
        let ctx = ScreenContext(
            displayDescription: "Built-in Retina Display",
            recognizedText: nil,
            visibleWindows: []
        )
        XCTAssertTrue(ctx.displayDescription == "Built-in Retina Display")
        XCTAssertTrue(ctx.recognizedText == nil)
        XCTAssertTrue(ctx.visibleWindows.isEmpty)
        XCTAssertTrue(ctx.imageData == nil)

        }
    func testScreenContextWithRecognizedText() {
        let ctx = ScreenContext(
            displayDescription: "Color LCD",
            recognizedText: "Hello World\nButton: Submit\nLabel: Username",
            visibleWindows: []
        )
        XCTAssertTrue(ctx.recognizedText == "Hello World\nButton: Submit\nLabel: Username")
        XCTAssertTrue(ctx.recognizedText?.contains("Submit") == true)

        }
    func testScreenContextCursorPosition() {
        let ctx = ScreenContext(
            displayDescription: "Main Display",
            cursorPosition: CGPoint(x: 800, y: 600)
        )
        XCTAssertTrue(ctx.cursorPosition?.x == 800)
        XCTAssertTrue(ctx.cursorPosition?.y == 600)

        }
    func testVisibleWindowContextMultipleWindows() {
        let windows: [VisibleWindowContext] = [
            VisibleWindowContext(ownerName: "Safari", windowTitle: "OpenAI", layer: 0, boundsDescription: "0,0,1440,900"),
            VisibleWindowContext(ownerName: "Terminal", windowTitle: "bash", layer: 1, boundsDescription: "500,300,800,600"),
            VisibleWindowContext(ownerName: "Finder", windowTitle: nil, layer: 2, boundsDescription: "100,100,400,300"),
        ]
        XCTAssertTrue(windows.count == 3)
        XCTAssertTrue(windows[0].ownerName == "Safari")
        XCTAssertTrue(windows[0].windowTitle == "OpenAI")
        XCTAssertTrue(windows[2].windowTitle == nil)

        }
    func testVisibleWindowLayerOrder() {
        let w1 = VisibleWindowContext(ownerName: "Safari", windowTitle: "Front", layer: 2, boundsDescription: "0,0,800,600")
        let w2 = VisibleWindowContext(ownerName: "Terminal", windowTitle: "Back", layer: 0, boundsDescription: "0,0,800,600")
        XCTAssertTrue(w1.layer > w2.layer)

        }
    func testAssistantContextWithAllFields() {
        let ctx = AssistantContext(
            app: AppContext(appName: "Safari", bundleIdentifier: "com.apple.Safari", windowTitle: "Settings"),
            runningApps: [
                RunningAppContext(appName: "Finder", bundleIdentifier: "com.apple.finder", isFrontmost: false),
                RunningAppContext(appName: "Safari", bundleIdentifier: "com.apple.Safari", isFrontmost: true),
            ],
            focusedElement: UIElementContext(role: "AXTextField", title: "搜索", value: "hello", selectedText: "he"),
            screen: ScreenContext(displayDescription: "Main Display", recognizedText: "搜索框"),
            activeDialogs: [
                ActiveDialogState(appName: "Safari", title: "确认删除", role: "AXSheet")
            ]
        )
        XCTAssertTrue(ctx.app?.appName == "Safari")
        XCTAssertTrue(ctx.runningApps.count == 2)
        XCTAssertTrue(ctx.focusedElement?.role == "AXTextField")
        XCTAssertTrue(ctx.focusedElement?.selectedText == "he")
        XCTAssertTrue(ctx.screen?.recognizedText == "搜索框")
        XCTAssertTrue(ctx.activeDialogs.count == 1)
        XCTAssertTrue(ctx.activeDialogs[0].title == "确认删除")

        }
    func testActiveDialogStateDetection() {
        let dialog = ActiveDialogState(appName: "Safari", title: "确认", role: "AXSheet", detectedAt: Date())
        XCTAssertTrue(dialog.appName == "Safari")
        XCTAssertTrue(dialog.title == "确认")
        XCTAssertTrue(dialog.role == "AXSheet")
        XCTAssertTrue(dialog.id == "Safari-确认")

        }
    func testFocusedUIElementContext() {
        let el = UIElementContext(role: "AXButton", title: "提交", value: nil, selectedText: nil)
        XCTAssertTrue(el.role == "AXButton")
        XCTAssertTrue(el.title == "提交")
        XCTAssertTrue(el.value == nil)

        }
    func testRunningAppContextFrontmost() {
        let front = RunningAppContext(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode", isFrontmost: true)
        let back = RunningAppContext(appName: "Terminal", bundleIdentifier: "com.apple.Terminal", isFrontmost: false)
        XCTAssertTrue(front.isFrontmost == true)
        XCTAssertTrue(back.isFrontmost == false)
        XCTAssertTrue(front.id == "com.apple.dt.Xcode")

        }
    func testOCREngineEnum() {
        let all = OCREngine.allCases
        XCTAssertTrue(all.count == 3)
        XCTAssertTrue(OCREngine.appleVision.displayName == "Apple Vision")
        XCTAssertTrue(OCREngine.ppocrV6.displayName == "PP-OCRv6 (ONNX)")
        XCTAssertTrue(OCREngine.both.displayName == "双引擎合并")

        }
    func testOCRResultModel() {
        let result = OCRResult(
            text: "登录", confidence: 0.95,
            x: 100, y: 200, width: 50, height: 30,
            engine: .appleVision
        )
        XCTAssertTrue(result.text == "登录")
        XCTAssertTrue(result.confidence == 0.95)
        XCTAssertTrue(result.engine == .appleVision)
        XCTAssertTrue(result.x == 100)
        XCTAssertTrue(result.y == 200)

    // MARK: - Permission error handling

        }
    func testAccessibilityErrorMessages() {
        XCTAssertTrue(AccessibilityError.noPermission.errorDescription?.contains("辅助功能权限") == true)
        XCTAssertTrue(AccessibilityError.elementNotFound.errorDescription?.contains("未找到") == true)
        XCTAssertTrue(AccessibilityError.actionFailed("click").errorDescription?.contains("click") == true)

        }
    func testAccessibilityErrorEquality() {
        XCTAssertTrue(AccessibilityError.noPermission != AccessibilityError.elementNotFound)
        XCTAssertTrue(AccessibilityError.actionFailed("type_text") == AccessibilityError.actionFailed("type_text"))

    // MARK: - Context model equality

        }
    func testScreenContextEquality() {
        let a = ScreenContext(displayDescription: "Display")
        let b = ScreenContext(displayDescription: "Display")
        let c = ScreenContext(displayDescription: "Other")
        XCTAssertTrue(a == b)
        XCTAssertTrue(a != c)

        }
    func testUIElementContextEquality() {
        let a = UIElementContext(role: "AXButton", title: "OK")
        let b = UIElementContext(role: "AXButton", title: "OK")
        let c = UIElementContext(role: "AXButton", title: "Cancel")
        XCTAssert(a == b)
        XCTAssert(a != c)

}

final class ScreenUnderstandingModelTests: XCTestCase {
    func testComputerUseAppState() {
        let state = ComputerUseAppState(
            activeAppBundleID: "com.apple.Safari", activeAppName: "Safari",
            focusedWindowTitle: "Preferences",
            windows: [ComputerUseWindow(title: "Preferences", isFocused: true)]
        )
        XCTAssertEqual(state.focusedWindowTitle, "Preferences")
        XCTAssertEqual(state.activeAppName, "Safari")
        XCTAssertTrue(state.windows[0].isFocused)
    }

    func testComputerUseAppStateWithoutScreenshot() {
        let state = ComputerUseAppState(screenshotPNGBase64: "abc123")
        let clean = state.withoutScreenshot()
        XCTAssertNil(clean.screenshotPNGBase64)
        XCTAssertNotNil(state.screenshotPNGBase64)
    }

    func testComputerUseStateDeltaMeaningfulChange() {
        let before = ComputerUseAppState(activeAppBundleID: "com.apple.Safari", activeAppName: "Safari")
        let after = ComputerUseAppState(activeAppBundleID: "com.apple.Terminal", activeAppName: "Terminal")
        let delta = ComputerUseStateDelta(before: before, after: after)
        XCTAssertTrue(delta.hasMeaningfulChange)
        XCTAssertTrue(delta.activeAppChanged)
        XCTAssertFalse(delta.focusedWindowChanged)
    }

    func testComputerUseStateDeltaNoChange() {
        let state = ComputerUseAppState(
            activeAppName: "Finder", focusedWindowTitle: "Downloads",
            elements: [ComputerUseElement(elementIndex: "0", role: "AXButton", depth: 1, childPath: [])]
        )
        let delta = ComputerUseStateDelta(before: state, after: state)
        XCTAssertFalse(delta.hasMeaningfulChange)
    }

    func testComputerUseElementLabel() {
        let el1 = ComputerUseElement(elementIndex: "1", role: "AXButton", title: "提交", depth: 1, childPath: [])
        XCTAssertEqual(el1.compactLabel, "提交")

        let el2 = ComputerUseElement(elementIndex: "2", role: "AXGroup", depth: 2, childPath: [1, 0])
        XCTAssertEqual(el2.compactLabel, "AXGroup")
    }

    func testDesktopContextPromptSummary() {
        let ctx = DesktopContext(
            activeAppBundleID: "com.apple.Safari", activeAppName: "Safari",
            focusedWindowTitle: "Settings", focusedElementRole: "AXTextField", focusedElementValue: "hello"
        )
        let summary = ctx.promptSummary()
        XCTAssertTrue(summary.contains("Safari"))
        XCTAssertTrue(summary.contains("Settings"))
        XCTAssertTrue(summary.contains("AXTextField"))
    }

    func testDesktopContextEmpty() {
        let ctx = DesktopContext(activeAppName: "Finder")
        let summary = ctx.promptSummary()
        XCTAssertTrue(summary.contains("Finder"))
        XCTAssertFalse(summary.contains("窗口"))
    }

    func testPermissionKindEnum() {
        XCTAssertEqual(PermissionKind.allCases.count, 10)
        XCTAssertTrue(PermissionKind.allCases.contains(.microphone))
        XCTAssertTrue(PermissionKind.allCases.contains(.screenRecording))
        XCTAssertTrue(PermissionKind.allCases.contains(.accessibility))
        for kind in PermissionKind.allCases {
            XCTAssertFalse(kind.title.isEmpty)
            XCTAssertFalse(kind.purpose.isEmpty)
        }
    }

    func testPermissionStatusLabels() {
        XCTAssertEqual(PermissionStatus.granted.label, "已授权")
        XCTAssertEqual(PermissionStatus.denied.label, "未授权")
        XCTAssertEqual(PermissionStatus.notDetermined.label, "未请求")
        XCTAssertEqual(PermissionStatus.unknown.label, "需验证")
        XCTAssertTrue(PermissionStatus.granted.isGranted)
        XCTAssertFalse(PermissionStatus.denied.isGranted)
    }

    func testFullAccessCapabilityKind() {
        XCTAssertEqual(FullAccessCapabilityKind.screenUnderstanding.title, "屏幕理解")
        XCTAssertTrue(FullAccessCapabilityKind.screenUnderstanding.codexEquivalent.contains("OCR"))
        for kind in FullAccessCapabilityKind.allCases {
            XCTAssertFalse(kind.title.isEmpty)
            XCTAssertFalse(kind.codexEquivalent.isEmpty)
        }
    }

    func testFoundationLayerScreenUnderstanding() {
        XCTAssertEqual(FoundationLayer.screenUnderstanding.title, "屏幕理解")
        XCTAssertTrue(FoundationLayer.screenUnderstanding.baselineRequirement.contains("OCR"))
    }

    func testFoundationHealthStatus() {
        XCTAssertEqual(FoundationHealthStatus.ok.label, "正常")
        XCTAssertEqual(FoundationHealthStatus.warning.label, "需关注")
        XCTAssertEqual(FoundationHealthStatus.failing.label, "失败")
        XCTAssertEqual(FoundationHealthStatus.notImplemented.label, "未完成")
    }

    func testNativeAccessibilityFeatureKind() {
        XCTAssertEqual(NativeAccessibilityFeatureKind.dictation.mode, .direct)
        XCTAssertEqual(NativeAccessibilityFeatureKind.dictation.title, "听写")
    }

    func testDesktopUIElement() {
        let el = DesktopUIElement(role: "AXButton", title: "Submit", description: "提交表单", depth: 1)
        XCTAssertEqual(el.role, "AXButton")
        XCTAssertEqual(el.title, "Submit")
        XCTAssertEqual(el.description, "提交表单")

        let el2 = DesktopUIElement(role: "AXGroup", title: nil, description: nil, depth: 0)
        XCTAssertEqual(el2.role, "AXGroup")
        XCTAssertNil(el2.title)
    }
}