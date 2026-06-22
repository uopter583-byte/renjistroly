import Foundation
import AppKit
import ScreenCaptureKit
@testable import RenJistrolySystemBridge
@testable import RenJistrolyModels

// MARK: - MockScreenCaptureBridge

actor MockScreenCaptureBridge {
    var shouldSucceed: Bool = true
    var mockImageData: Data
    var mockWindows: [WindowInfo]
    var captureCallCount: Int = 0

    init(
        shouldSucceed: Bool = true,
        mockImageData: Data = Data(),
        mockWindows: [WindowInfo] = []
    ) {
        self.shouldSucceed = shouldSucceed
        self.mockImageData = mockImageData
        self.mockWindows = mockWindows
    }

    func requestPermission() -> Bool { true }

    func captureScreen(display: SCDisplay? = nil, excludingWindowIDs: [CGWindowID] = []) async throws -> Data {
        captureCallCount += 1
        if shouldSucceed { return mockImageData }
        throw ScreenCaptureError.noDisplayAvailable
    }

    func getOwnWindowIDs() async throws -> [CGWindowID] { [] }

    func getAvailableWindows() async throws -> [WindowInfo] { mockWindows }
}

// MARK: - MockScreenContextProvider

actor MockScreenContextProvider {
    var mockContext: ScreenContext
    var shouldThrow: Bool = false
    var captureCount: Int = 0

    init(mockContext: ScreenContext) {
        self.mockContext = mockContext
    }

    func captureCurrentScreen(includeImageData: Bool = false, skipOwnWindows: Bool = false) async -> ScreenContext {
        captureCount += 1
        return mockContext
    }
}

// MARK: - MockOCRService

final class MockOCRService: OCRServiceProtocol, @unchecked Sendable {
    let engine: OCREngine = .appleVision
    var mockResults: [OCRResult]
    var shouldThrow: Bool = false

    init(mockResults: [OCRResult] = []) {
        self.mockResults = mockResults
    }

    func recognizeText(in imageData: Data) async throws -> [OCRResult] {
        if shouldThrow { throw OCRError.imageConversionFailed }
        return mockResults
    }
}

// MARK: - MockAccessibilityBridge

actor MockAccessibilityBridge {
    var isTrusted: Bool = true
    var mockFocusedBundleID: String?
    var mockFocusedWindowTitle: String?
    var mockElementTree: [UIElementNode]
    var recordedActions: [String] = []

    init(
        isTrusted: Bool = true,
        mockFocusedBundleID: String? = "com.apple.Safari",
        mockFocusedWindowTitle: String? = "测试窗口",
        mockElementTree: [UIElementNode] = []
    ) {
        self.isTrusted = isTrusted
        self.mockFocusedBundleID = mockFocusedBundleID
        self.mockFocusedWindowTitle = mockFocusedWindowTitle
        self.mockElementTree = mockElementTree
    }

    func requestPermission() -> Bool { true }

    func checkPermission() -> Bool { isTrusted }

    func getFocusedAppBundleID() throws -> String? {
        guard isTrusted else { throw AccessibilityError.noPermission }
        return mockFocusedBundleID
    }

    func getFocusedWindowTitle() throws -> String? {
        guard isTrusted else { throw AccessibilityError.noPermission }
        return mockFocusedWindowTitle
    }

    func getUIElementTree(maxDepth: Int = 3) throws -> [UIElementNode] {
        guard isTrusted else { throw AccessibilityError.noPermission }
        return mockElementTree
    }

    func getWindowList() throws -> [String] {
        guard isTrusted else { throw AccessibilityError.noPermission }
        return ["窗口1", "窗口2", "测试窗口"]
    }

    func click(at point: CGPoint) throws {
        guard isTrusted else { throw AccessibilityError.noPermission }
        recordedActions.append("click(\(point.x), \(point.y))")
    }

    func pressKey(_ key: String, modifiers: [String] = []) throws {
        guard isTrusted else { throw AccessibilityError.noPermission }
        recordedActions.append("pressKey(\(key), modifiers: \(modifiers))")
    }

    func typeText(_ text: String) throws {
        guard isTrusted else { throw AccessibilityError.noPermission }
        recordedActions.append("typeText(\"\(text)\")")
    }

    func scroll(deltaY: Int = 0, deltaX: Int = 0) throws {
        guard isTrusted else { throw AccessibilityError.noPermission }
        recordedActions.append("scroll(deltaY: \(deltaY), deltaX: \(deltaX))")
    }

    func focusWindow(title: String) throws {
        guard isTrusted else { throw AccessibilityError.noPermission }
        recordedActions.append("focusWindow(\"\(title)\")")
    }

    func click(elementIndex: String, app: String?, clickCount: Int) {
        recordedActions.append("click(elementIndex: \(elementIndex), app: \(app ?? "nil"), count: \(clickCount))")
    }

    func resetActions() {
        recordedActions.removeAll()
    }
}

// MARK: - Factory: 预设场景数据

enum MockScreenScenario {
    /// 一个干净桌面：Safari 在前台，无 OCR 文字
    static func emptyDesktop() -> ScreenContext {
        ScreenContext(
            displayDescription: "Displays: 1, main frame: (0,0,1728,1117). Visible windows: Safari: 测试页面. Visual capture not requested.",
            visibleWindows: [
                VisibleWindowContext(ownerName: "Safari", windowTitle: "测试页面", layer: 0, boundsDescription: "x:0, y:0, w:1728, h:1117")
            ]
        )
    }

    /// 含有中文 OCR 文字的屏幕
    static func chineseOCR() -> ScreenContext {
        ScreenContext(
            displayDescription: "Displays: 1, main frame: (0,0,1728,1117). OCR across 1 display(s), 42 chars.",
            recognizedText: "你好世界\n欢迎使用 RenJistroly\n点击这里开始",
            visibleWindows: [
                VisibleWindowContext(ownerName: "RenJistroly", windowTitle: "欢迎", layer: 0, boundsDescription: "x:100, y:100, w:400, h:300")
            ]
        )
    }

    /// 多窗口场景
    static func multiWindow() -> ScreenContext {
        ScreenContext(
            displayDescription: "Displays: 1. Visible windows: Xcode: main.swift | Safari: 文档 | 终端: bash.",
            visibleWindows: [
                VisibleWindowContext(ownerName: "Xcode", windowTitle: "main.swift", layer: 0, boundsDescription: "x:0, y:0, w:1200, h:800"),
                VisibleWindowContext(ownerName: "Safari", windowTitle: "文档", layer: 0, boundsDescription: "x:1200, y:0, w:528, h:1117"),
                VisibleWindowContext(ownerName: "终端", windowTitle: "bash", layer: 0, boundsDescription: "x:0, y:800, w:800, h:317"),
            ]
        )
    }

    /// 对话框场景（需要确认交互）
    static func dialogPresented() -> ScreenContext {
        ScreenContext(
            displayDescription: "Dialog detected. Visible windows: 系统提示: 确认删除.",
            visibleWindows: [
                VisibleWindowContext(ownerName: "系统提示", windowTitle: "确认删除", layer: 1, boundsDescription: "x:600, y:400, w:400, h:200"),
            ]
        )
    }

    /// 可获得标准 OCR 结果数组
    static func sampleOCRResults() -> [OCRResult] {
        [
            OCRResult(text: "你好", confidence: 0.95, x: 100, y: 100, width: 80, height: 30, engine: .appleVision),
            OCRResult(text: "世界", confidence: 0.92, x: 100, y: 140, width: 80, height: 30, engine: .appleVision),
            OCRResult(text: "OK", confidence: 0.98, x: 300, y: 200, width: 40, height: 25, engine: .appleVision),
        ]
    }
}
