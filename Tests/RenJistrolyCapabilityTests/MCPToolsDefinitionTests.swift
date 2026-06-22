import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

// MARK: - ControlTools

func testControlToolsDefinitions() {
    let tools: [(any MCPTool, String, ToolRiskLevel)] = [
        (GetAppStateTool(), "get_app_state", .low),
        (ClickTool(), "click", .medium),
        (SetValueTool(), "set_value", .medium),
        (ClickElementTool(), "click_element", .medium),
        (ActivateMenuTool(), "activate_menu", .medium),
        (WindowListTool(), "list_windows", .low),
        (FocusWindowTool(), "focus_window", .medium),
        (ScrollTool(), "scroll", .low),
        (DragTool(), "drag", .high),
        (UITreeTool(), "get_ui_tree", .low),
    ]
    for (tool, expectedName, expectedRisk) in tools {
        XCTAssertTrue(tool.definition.name == expectedName)
        XCTAssertTrue(!tool.definition.description.isEmpty, "\(expectedName) has empty description")
        XCTAssertTrue(tool.riskLevel == expectedRisk, "\(expectedName) risk level mismatch")
    }
}

// MARK: - ScenarioTools

func testScenarioToolsDefinitions() {
    let tools: [(any MCPTool, String)] = [
        (PolishReplaceTool(), "polish_replace"),
        (ExplainSelectedTool(), "explain_selected"),
        (ReadScreenTool(), "read_screen"),
        (ScreenContextTool(), "screen_context"),
    ]
    for (tool, expectedName) in tools {
        XCTAssertTrue(tool.definition.name == expectedName)
        XCTAssertTrue(!tool.definition.description.isEmpty, "\(expectedName) has empty description")
    }
}

// MARK: - CodeTools

func testCodeToolsDefinitions() {
    let tools: [(any MCPTool, String, ToolRiskLevel)] = [
        (GitStatusTool(), "git_status", .low),
        (GitLogTool(), "git_log", .low),
        (GitDiffTool(), "git_diff", .low),
        (ReadFileTool(), "read_file", .low),
        (ListFilesTool(), "list_files", .low),
        (WriteFileTool(), "write_file", .high),
        (ShellCommandTool(), "shell_command", .high),
        (ClipboardTool(), "clipboard", .high),
    ]
    for (tool, expectedName, expectedRisk) in tools {
        XCTAssertTrue(tool.definition.name == expectedName)
        XCTAssertTrue(!tool.definition.description.isEmpty, "\(expectedName) has empty description")
        XCTAssertTrue(tool.riskLevel == expectedRisk, "\(expectedName) risk level mismatch")
    }
}

// MARK: - ScreenshotCompare and DOM tools

func testScreenshotAndDOMToolsDefinitions() {
    let sc = ScreenshotCompareTool()
    XCTAssertTrue(sc.definition.name == "screenshot_compare")
    XCTAssertTrue(sc.riskLevel == .low)

    let di = DOMInspectTool()
    XCTAssertTrue(di.definition.name == "dom_inspect")
    XCTAssertTrue(di.riskLevel == .low)

    let dc = DOMClickTool()
    XCTAssertTrue(dc.definition.name == "dom_click")
    XCTAssertTrue(dc.riskLevel == .medium)

    let df = DOMFillTool()
    XCTAssertTrue(df.definition.name == "dom_fill")
    XCTAssertTrue(df.riskLevel == .medium)

    let ds = DOMSubmitTool()
    XCTAssertTrue(ds.definition.name == "dom_submit")
    XCTAssertTrue(ds.riskLevel == .high)
}

// MARK: - AppDriverTools

func testAppDriverToolsDefinitions() {
    let tools: [(any MCPTool, String, ToolRiskLevel)] = [
        (ListAppDriversTool(), "list_app_drivers", .low),
        (OpenPathTool(), "open_path", .medium),
        (FinderSearchTool(), "finder_search", .low),
        (ListDirectoryTool(), "list_directory", .low),
        (GetFinderStateTool(), "get_finder_state", .low),
        (SafariSearchTool(), "safari_search", .medium),
        (GetBrowserStateTool(), "get_browser_state", .low),
        (TerminalRunTool(), "terminal_run", .high),
        (XcodeNavigateTool(), "xcode_navigate", .medium),
        (ParseBuildErrorsTool(), "parse_build_errors", .low),
        (CreateFolderTool(), "create_folder", .medium),
        (MoveFileTool(), "move_file", .high),
        (CopyFileTool(), "copy_file", .medium),
        (DeleteFileTool(), "delete_file", .high),
        (FileInfoTool(), "file_info", .low),
    ]
    for (tool, expectedName, expectedRisk) in tools {
        XCTAssertTrue(tool.definition.name == expectedName)
        XCTAssertTrue(!tool.definition.description.isEmpty, "\(expectedName) has empty description")
        XCTAssertTrue(tool.riskLevel == expectedRisk, "\(expectedName) risk level mismatch")
    }
}

// MARK: - All tools have required parameters documented

func testAllBuiltinToolsHaveNonEmptyParameters() {
    let allTools: [any MCPTool] = [
        GetAppStateTool(), ClickTool(), SetValueTool(), ClickElementTool(),
        ActivateMenuTool(), WindowListTool(), FocusWindowTool(), ScrollTool(),
        DragTool(), UITreeTool(),
        OpenAppTool(), SystemInfoTool(), RunningAppsTool(), OpenURLTool(),
        TypeTextTool(), ReadFocusedTextTool(), PressKeyTool(),
        OpenInXcodeTool(), RevealInFinderTool(), ListSchemesTool(), BuildSettingsTool(),
        PolishReplaceTool(), ExplainSelectedTool(), ReadScreenTool(), ScreenContextTool(),
        GitStatusTool(), GitLogTool(), GitDiffTool(),
        ReadFileTool(), ListFilesTool(), WriteFileTool(),
        ShellCommandTool(), ClipboardTool(),
        ScreenshotCompareTool(), DOMInspectTool(), DOMClickTool(), DOMFillTool(), DOMSubmitTool(),
        ListAppDriversTool(), OpenPathTool(), FinderSearchTool(), ListDirectoryTool(),
        GetFinderStateTool(), SafariSearchTool(), GetBrowserStateTool(), TerminalRunTool(),
        XcodeNavigateTool(), ParseBuildErrorsTool(), CreateFolderTool(), MoveFileTool(),
        CopyFileTool(), DeleteFileTool(), FileInfoTool(),
    ]
    for tool in allTools {
        for param in tool.definition.parameters {
            XCTAssertTrue(!param.name.isEmpty, "\(tool.definition.name) has empty param name")
            XCTAssertTrue(!param.description.isEmpty, "\(tool.definition.name).\(param.name) has empty description")
        }
    }
}
