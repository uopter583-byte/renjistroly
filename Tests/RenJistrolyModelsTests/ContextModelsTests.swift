import Foundation
import XCTest
import RenJistrolyModels

// MARK: - AppContext

func testAppContextMinimal() {
    let ctx = AppContext(appName: "Safari")
    XCTAssertTrue(ctx.appName == "Safari")
    XCTAssertTrue(ctx.bundleIdentifier == nil)
    XCTAssertTrue(ctx.windowTitle == nil)
}

func testAppContextFull() {
    let ctx = AppContext(appName: "Safari", bundleIdentifier: "com.apple.Safari", windowTitle: "Apple")
    XCTAssertTrue(ctx.bundleIdentifier == "com.apple.Safari")
    XCTAssertTrue(ctx.windowTitle == "Apple")
}

// MARK: - RunningAppContext

func testRunningAppContextIDUsesBundle() {
    let app = RunningAppContext(appName: "Safari", bundleIdentifier: "com.apple.Safari")
    XCTAssertTrue(app.id == "com.apple.Safari")
}

func testRunningAppContextIDFallbackToName() {
    let app = RunningAppContext(appName: "UnknownApp")
    XCTAssertTrue(app.id == "UnknownApp")
}

func testRunningAppContextDefaultNotFrontmost() {
    let app = RunningAppContext(appName: "Finder")
    XCTAssertFalse(app.isFrontmost)
}

// MARK: - UIElementContext

func testUIElementContextDefaults() {
    let el = UIElementContext()
    XCTAssertTrue(el.role == nil)
    XCTAssertTrue(el.title == nil)
    XCTAssertTrue(el.value == nil)
    XCTAssertTrue(el.selectedText == nil)
}

func testUIElementContextWithValues() {
    let el = UIElementContext(role: "AXButton", title: "OK", value: "enabled", selectedText: nil)
    XCTAssertTrue(el.role == "AXButton")
    XCTAssertTrue(el.title == "OK")
    XCTAssertTrue(el.value == "enabled")
}

// MARK: - ScreenContext

func testScreenContextDefaults() {
    let ctx = ScreenContext(displayDescription: "内置显示器")
    XCTAssertTrue(ctx.displayDescription == "内置显示器")
    XCTAssertTrue(ctx.imageData == nil)
    XCTAssertTrue(ctx.recognizedText == nil)
    XCTAssertTrue(ctx.visibleWindows.isEmpty)
}

func testScreenContextWithContent() {
    let windows = [
        VisibleWindowContext(ownerName: "Safari", windowTitle: "GitHub", layer: 0, boundsDescription: "{{0,0},{1200,800}}"),
    ]
    let ctx = ScreenContext(
        displayDescription: "外接显示器",
        recognizedText: "Hello World",
        visibleWindows: windows
    )
    XCTAssertTrue(ctx.recognizedText == "Hello World")
    XCTAssertTrue(ctx.visibleWindows.count == 1)
    XCTAssertTrue(ctx.visibleWindows[0].ownerName == "Safari")
}

// MARK: - VisibleWindowContext

func testVisibleWindowContextIDIncludesOwner() {
    let w = VisibleWindowContext(ownerName: "Safari", windowTitle: "GitHub", layer: 0, boundsDescription: "{{0,0},{1200,800}}")
    XCTAssertTrue(w.id.contains("Safari"))
    XCTAssertTrue(w.id.contains("GitHub"))
}

// MARK: - AssistantContext

func testAssistantContextDefaults() {
    let ctx = AssistantContext()
    XCTAssertTrue(ctx.app == nil)
    XCTAssertTrue(ctx.runningApps.isEmpty)
    XCTAssertTrue(ctx.focusedElement == nil)
    XCTAssertTrue(ctx.screen == nil)
}
