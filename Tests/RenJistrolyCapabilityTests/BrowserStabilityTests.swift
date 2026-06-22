import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

// MARK: - Open URL Tool


func testOpenURLToolMissingURL() async throws {
    let tool = OpenURLTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("无效") || result.output.contains("缺少"))
}

func testOpenURLToolInvalidScheme() async throws {
    let tool = OpenURLTool()
    let result = try await tool.execute(arguments: ["url": "ftp://example.com"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("仅允许"))
}

func testOpenURLToolEmptyURL() async throws {
    let tool = OpenURLTool()
    let result = try await tool.execute(arguments: ["url": ""])
    XCTAssertTrue(result.isError)
}

// MARK: - Browser Navigate Tool

func testBrowserNavigateToolDefinition() {
    let tool = BrowserNavigateTool()
    XCTAssertTrue(tool.definition.name == "browser_navigate")
    XCTAssertTrue(tool.riskLevel == .low)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "action" })
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "browser" })
}

func testBrowserNavigateToolDefaultAction() async throws {
    let tool = BrowserNavigateTool()
    let result = try await tool.execute(arguments: ["action": "reload"])
    // 工具应执行而不崩溃
    XCTAssertFalse(result.output.isEmpty)
}

// MARK: - DOM Tools

func testDOMClickToolDefinition() {
    let tool = DOMClickTool()
    XCTAssertTrue(tool.definition.name == "dom_click")
    XCTAssertTrue(tool.riskLevel == .medium)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "selector" })
}

func testDOMClickToolMissingSelector() async throws {
    let tool = DOMClickTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
}

func testDOMFillToolDefinition() {
    let tool = DOMFillTool()
    XCTAssertTrue(tool.definition.name == "dom_fill")
    XCTAssertTrue(tool.riskLevel == .medium)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "selector" })
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "value" })
}

func testDOMFillToolMissingValue() async throws {
    let tool = DOMFillTool()
    let result = try await tool.execute(arguments: ["selector": "#search"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}

func testDOMSubmitToolDefinition() {
    let tool = DOMSubmitTool()
    XCTAssertTrue(tool.definition.name == "dom_submit")
    XCTAssertTrue(tool.riskLevel == .high)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "selector" })
}

// MARK: - Get Browser State Tool

func testGetBrowserStateToolDefinition() {
    let tool = GetBrowserStateTool()
    XCTAssertTrue(tool.definition.name == "get_browser_state")
    XCTAssertTrue(tool.riskLevel == .low)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "app" })
}

func testGetBrowserStateToolUnsupportedBrowser() async throws {
    let tool = GetBrowserStateTool()
    let result = try await tool.execute(arguments: ["app": "firefox"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("不支持"))
}

// MARK: - BrowserPageState Models

func testBrowserPageStateInit() {
    let state = BrowserPageState(
        browserName: "Safari",
        windowTitle: "测试页面",
        tabTitle: "首页",
        url: "https://example.com",
        host: "example.com",
        searchQuery: "test"
    )
    XCTAssertTrue(state.browserName == "Safari")
    XCTAssertTrue(state.windowTitle == "测试页面")
    XCTAssertTrue(state.tabTitle == "首页")
    XCTAssertTrue(state.url == "https://example.com")
    XCTAssertTrue(state.host == "example.com")
    XCTAssertTrue(state.searchQuery == "test")
}

func testBrowserPageStateEmpty() {
    let state = BrowserPageState(browserName: "Chrome")
    XCTAssertTrue(state.browserName == "Chrome")
    XCTAssertTrue(state.windowTitle == nil)
    XCTAssertTrue(state.url == nil)
}

func testBrowserDOMElementInit() {
    let element = BrowserDOMElement(
        tag: "button",
        text: "提交",
        value: nil,
        href: nil,
        visible: true,
        rect: BrowserDOMRect(x: 100, y: 200, w: 50, h: 30)
    )
    XCTAssertTrue(element.tag == "button")
    XCTAssertTrue(element.text == "提交")
    XCTAssertTrue(element.visible)
    XCTAssertTrue(element.rect?.x == 100)
    XCTAssertTrue(element.rect?.h == 30)
}

// MARK: - Safari Search Tool

func testSafariSearchToolDefinition() {
    let tool = SafariSearchTool()
    XCTAssertTrue(tool.definition.name == "safari_search")
    XCTAssertTrue(tool.riskLevel == .medium)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "query" })
}

func testSafariSearchToolMissingQuery() async throws {
    let tool = SafariSearchTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}
