import Foundation
import XCTest
@testable import RenJistrolyModels

func testDesktopContextPromptSummaryIncludesCoreFields() {
    let context = DesktopContext(
        activeAppBundleID: "com.apple.TextEdit",
        activeAppName: "TextEdit",
        focusedWindowTitle: "Notes.txt",
        focusedElementRole: "AXTextArea",
        focusedElementValue: "hello",
        selectedText: "selected text",
        browserPageState: BrowserPageState(
            browserName: "Safari",
            tabTitle: "OpenAI Docs",
            url: "https://platform.openai.com/docs",
            host: "platform.openai.com",
            searchQuery: "openai docs"
        ),
        finderWindowState: FinderWindowState(
            windowTitle: "Workspace",
            currentPath: "/Users/yoming/RenJistroly",
            selectedItems: ["/Users/yoming/RenJistroly/Package.swift"]
        ),
        windows: [DesktopWindow(title: "Notes.txt")],
        uiElements: [
            DesktopUIElement(role: "AXButton", title: "Done", description: "Confirm", depth: 1)
        ]
    )

    let summary = context.promptSummary()

    XCTAssertTrue(summary.contains("前台应用: TextEdit"))
    XCTAssertTrue(summary.contains("com.apple.TextEdit"))
    XCTAssertTrue(summary.contains("当前窗口: Notes.txt"))
    XCTAssertTrue(summary.contains("焦点控件角色: AXTextArea"))
    XCTAssertTrue(summary.contains("selected text"))
    XCTAssertTrue(summary.contains("浏览器页面: Safari"))
    XCTAssertTrue(summary.contains("页面域名: platform.openai.com"))
    XCTAssertTrue(summary.contains("Finder 当前目录: /Users/yoming/RenJistroly"))
    XCTAssertTrue(summary.contains("AXButton"))
}

func testDesktopContextEmptyMinimal() {
    let context = DesktopContext()
    let summary = context.promptSummary()
    XCTAssertTrue(summary.contains("当前桌面上下文:"))
    XCTAssertTrue(!summary.contains("前台应用:"))
    XCTAssertTrue(!summary.contains("浏览器页面:"))
    XCTAssertTrue(!summary.contains("Finder 状态:"))
}

func testDesktopContextOnlyAppInfo() {
    let context = DesktopContext(activeAppName: "Finder")
    let summary = context.promptSummary()
    XCTAssertTrue(summary.contains("前台应用: Finder"))
    XCTAssertTrue(!summary.contains("当前窗口:"))
    XCTAssertTrue(!summary.contains("焦点控件"))
}

func testDesktopContextTruncatesSelectedText() {
    let longText = String(repeating: "X", count: 1000)
    let context = DesktopContext(selectedText: longText)
    let summary = context.promptSummary(maxSelectedTextLength: 100)
    XCTAssertTrue(summary.contains(String(repeating: "X", count: 100)))
    XCTAssertTrue(!summary.contains(String(repeating: "X", count: 101)))
}

func testDesktopContextTruncatesFocusedValue() {
    let longValue = String(repeating: "Y", count: 500)
    let context = DesktopContext(focusedElementValue: longValue)
    let summary = context.promptSummary(maxFocusedValueLength: 100)
    XCTAssertTrue(summary.contains(String(repeating: "Y", count: 100)))
    XCTAssertTrue(!summary.contains(String(repeating: "Y", count: 101)))
}

func testDesktopContextLimitsUIElements() {
    let elements = (0..<50).map { i in
        DesktopUIElement(role: "AXButton", title: "Btn\(i)", depth: 1)
    }
    let context = DesktopContext(uiElements: elements)
    let summary = context.promptSummary(maxUIElements: 10)
    let buttonLines = summary.components(separatedBy: "\n").filter { $0.contains("AXButton") }
    XCTAssertTrue(buttonLines.count <= 10)
}

func testDesktopContextEmptyWindowsSkipped() {
    let context = DesktopContext(windows: [])
    let summary = context.promptSummary()
    XCTAssertTrue(!summary.contains("当前应用窗口:"))
}

func testDesktopContextEmptyFinderItemsSkipped() {
    let finderState = FinderWindowState(currentPath: "/tmp", selectedItems: [])
    let context = DesktopContext(finderWindowState: finderState)
    let summary = context.promptSummary()
    XCTAssertTrue(summary.contains("Finder 当前目录: /tmp"))
    XCTAssertTrue(!summary.contains("Finder 已选中"))
}

func testDesktopContextMultipleFinderItems() {
    let finderState = FinderWindowState(
        currentPath: "/tmp",
        selectedItems: ["a.txt", "b.txt", "c.txt", "d.txt"]
    )
    let context = DesktopContext(finderWindowState: finderState)
    let summary = context.promptSummary()
    XCTAssertTrue(summary.contains("a.txt | b.txt | c.txt"))
    XCTAssertTrue(!summary.contains("d.txt")) // limit is 3
}

func testDesktopContextUIElementIndentation() {
    let elements = [
        DesktopUIElement(role: "AXButton", title: "OK", depth: 1),
        DesktopUIElement(role: "AXTextField", title: "Input", depth: 3),
    ]
    let context = DesktopContext(uiElements: elements)
    let summary = context.promptSummary()
    XCTAssertTrue(summary.contains("    - AXTextField")) // depth 3 = 2*3 = 6 spaces, wait: min(depth,4)*2= 2 spaces per depth
}

func testDesktopContextBrowserWithoutHost() {
    let browser = BrowserPageState(browserName: "Safari", tabTitle: "New Tab")
    let context = DesktopContext(browserPageState: browser)
    let summary = context.promptSummary()
    XCTAssertTrue(summary.contains("浏览器页面: Safari"))
    XCTAssertTrue(summary.contains("当前标签页: New Tab"))
    XCTAssertTrue(!summary.contains("页面域名:"))
    XCTAssertTrue(!summary.contains("页面 URL:"))
}

func testDesktopContextWindowsTruncated() {
    let windows = (0..<15).map { i in DesktopWindow(title: "Window\(i)") }
    let context = DesktopContext(windows: windows)
    let summary = context.promptSummary()
    // Should only show first 10
    XCTAssertTrue(summary.contains("Window0"))
    XCTAssertTrue(summary.contains("Window9"))
    XCTAssertTrue(!summary.contains("Window10"))
}

func testDesktopContextProjectContext() {
    let project = ProjectContext(
        rootPath: "/Users/yoming/RenJistroly",
        activeFile: "Package.swift",
        gitBranch: "main"
    )
    let context = DesktopContext(projectContext: project)
    XCTAssertTrue(context.projectContext?.rootPath == "/Users/yoming/RenJistroly")
    XCTAssertTrue(context.projectContext?.activeFile == "Package.swift")
    XCTAssertTrue(context.projectContext?.gitBranch == "main")
}

func testDesktopContextEmptyFocusedValueSkipped() {
    let context = DesktopContext(focusedElementValue: "")
    let summary = context.promptSummary()
    XCTAssertTrue(!summary.contains("焦点控件内容:"))
}

func testDesktopContextEmptySelectedTextSkipped() {
    let context = DesktopContext(selectedText: "")
    let summary = context.promptSummary()
    XCTAssertTrue(!summary.contains("选中文本:"))
}
