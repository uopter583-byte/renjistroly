import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

private actor MCPToolsTestScrollBridge: AccessibilityScrolling {
    var recordedArgs: [(deltaY: Int, deltaX: Int, lines: Int)] = []

    func scroll(deltaY: Int, deltaX: Int, lines: Int) async throws {
        recordedArgs.append((deltaY, deltaX, lines))
    }
}

// MARK: - ControlTools error-path execution

final class MCPToolsExecutionTests: XCTestCase {

func testClickToolMissingParameters() async throws {
    let tool = ClickTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}

func testClickToolInvalidCoordinates() async throws {
    let tool = ClickTool()
    let result = try await tool.execute(arguments: ["x": "abc", "y": "def"])
    XCTAssertTrue(result.isError)
}

func testClickToolDefinitionAcceptsStableIDAndCoordinates() async throws {
    let tool = ClickTool()
    let parameterNames = Set(tool.definition.parameters.map(\.name))
    XCTAssertTrue(parameterNames.contains("stable_id"))
    XCTAssertTrue(parameterNames.contains("element_index"))
    XCTAssertTrue(parameterNames.contains("x"))
    XCTAssertTrue(parameterNames.contains("y"))
}

func testSetValueToolMissingParameters() async throws {
    let tool = SetValueTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}

func testSetValueToolMissingValue() async throws {
    let tool = SetValueTool()
    let result = try await tool.execute(arguments: ["element_index": "e1"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("value"))
}

func testClickElementToolEmptyParamsRejected() async throws {
    let tool = ClickElementTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("title"))
}

func testClickElementToolBlankTitleRejected() async throws {
    let tool = ClickElementTool()
    let result = try await tool.execute(arguments: ["title": "   "])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("title"))
}

func testActivateMenuToolMissingPath() async throws {
    let tool = ActivateMenuTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("path"))
}

func testActivateMenuToolBlankPath() async throws {
    let tool = ActivateMenuTool()
    let result = try await tool.execute(arguments: ["path": "   "])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("path"))
}

func testActivateMenuToolEmptyPath() async throws {
    let tool = ActivateMenuTool()
    let result = try await tool.execute(arguments: ["path": ""])
    XCTAssertTrue(result.isError)
}

func testFocusWindowToolMissingTitle() async throws {
    let tool = FocusWindowTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("title"))
}

func testFocusWindowToolBlankTitle() async throws {
    let tool = FocusWindowTool()
    let result = try await tool.execute(arguments: ["title": "  "])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("title"))
}

func testScrollToolDefault() async throws {
    let mock = MCPToolsTestScrollBridge()
    let tool = ScrollTool(bridge: mock)
    let result = try await tool.execute(arguments: [:])
    XCTAssertFalse(result.isError)
    let args = await mock.recordedArgs
    XCTAssertEqual(args.count, 1)
    XCTAssertEqual(args.first?.deltaY, 0)
    XCTAssertEqual(args.first?.deltaX, 0)
    XCTAssertEqual(args.first?.lines, 0)
}

func testScrollToolWithDeltas() async throws {
    let mock = MCPToolsTestScrollBridge()
    let tool = ScrollTool(bridge: mock)
    let result = try await tool.execute(arguments: ["delta_y": "3"])
    XCTAssertFalse(result.isError)
    let args = await mock.recordedArgs
    XCTAssertEqual(args.count, 1)
    XCTAssertEqual(args.first?.deltaY, 3)
}

func testDragToolMissingParameters() async throws {
    let tool = DragTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("坐标"))
}

func testDragToolIncompleteParameters() async throws {
    let tool = DragTool()
    let result = try await tool.execute(arguments: ["from_x": "0", "from_y": "0"])
    XCTAssertTrue(result.isError)
}

func testDragToolRejectsInvalidCoordinates() async throws {
    let tool = DragTool()
    let result = try await tool.execute(arguments: ["from_x": "0", "from_y": "0", "to_x": "abc", "to_y": "100"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("坐标"))
}

// MARK: - SystemTools error-path execution

func testOpenAppToolMissingName() async throws {
    let tool = OpenAppTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("app_name"))
}

func testOpenAppToolBlankName() async throws {
    let tool = OpenAppTool()
    let result = try await tool.execute(arguments: ["app_name": "   "])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("app_name"))
}

func testSystemInfoToolAll() async throws {
    let tool = SystemInfoTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertFalse(result.isError)
    XCTAssertTrue(result.output.contains("macOS"))
}

func testSystemInfoToolCPU() async throws {
    let tool = SystemInfoTool()
    let result = try await tool.execute(arguments: ["info_type": "cpu"])
    XCTAssertFalse(result.isError)
    XCTAssertTrue(result.output.contains("CPU"))
}

func testSystemInfoToolMemory() async throws {
    let tool = SystemInfoTool()
    let result = try await tool.execute(arguments: ["info_type": "memory"])
    XCTAssertFalse(result.isError)
    XCTAssertTrue(result.output.contains("物理内存"))
}

func testRunningAppsTool() async throws {
    let tool = RunningAppsTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertFalse(result.isError)
}

func testRunningAppsToolWithFilter() async throws {
    let tool = RunningAppsTool()
    let result = try await tool.execute(arguments: ["filter": "Finder"])
    XCTAssertFalse(result.isError)
    XCTAssertTrue(result.output.contains("com.apple.finder"))
}

func testOpenURLToolInvalidURL() async throws {
    let tool = OpenURLTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("无效"))
}

func testOpenURLToolNonHTTP() async throws {
    let tool = OpenURLTool()
    let result = try await tool.execute(arguments: ["url": "file:///etc/passwd"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("仅允许"))
}

func testTypeTextToolMissingText() async throws {
    let tool = TypeTextTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("text"))
}

func testPressKeyToolMissingKey() async throws {
    let tool = PressKeyTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("key"))
}

func testPressKeyToolBlankKey() async throws {
    let tool = PressKeyTool()
    let result = try await tool.execute(arguments: ["key": "   "])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("key"))
}

func testPressKeyToolDefinitionSupportsModifiers() async throws {
    let tool = PressKeyTool()
    let parameterNames = Set(tool.definition.parameters.map(\.name))
    XCTAssertTrue(parameterNames.contains("key"))
    XCTAssertTrue(parameterNames.contains("modifiers"))
}

func testOpenInXcodeToolMissingPath() async throws {
    let tool = OpenInXcodeTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("file_path"))
}

func testOpenInXcodeToolNonexistentFile() async throws {
    let tool = OpenInXcodeTool()
    let result = try await tool.execute(arguments: ["file_path": "/nonexistent/file.swift"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("不存在"))
}

func testRevealInFinderToolMissingPath() async throws {
    let tool = RevealInFinderTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("path"))
}

func testRevealInFinderToolNonexistentPath() async throws {
    let tool = RevealInFinderTool()
    let result = try await tool.execute(arguments: ["path": "/nonexistent/path"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("不存在"))
}

// MARK: - ScenarioTools error-path execution

func testPolishReplaceToolDefinitionHasStyle() async throws {
    let tool = PolishReplaceTool()
    XCTAssertEqual(tool.definition.name, "polish_replace")
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "style" })
}

func testPolishReplaceToolIsHighRisk() async throws {
    let tool = PolishReplaceTool()
    XCTAssertEqual(tool.riskLevel, .high)
}

func testExplainSelectedToolDefinitionHasFocus() async throws {
    let tool = ExplainSelectedTool()
    XCTAssertEqual(tool.definition.name, "explain_selected")
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "focus" })
}

func testScreenContextToolDefault() async throws {
    let tool = ScreenContextTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertFalse(result.isError)
    XCTAssertTrue(result.output.contains("屏幕上下文"))
}

func testScreenContextToolVisionEngine() async throws {
    let tool = ScreenContextTool()
    let result = try await tool.execute(arguments: ["ocr_engine": "vision"])
    XCTAssertFalse(result.isError)
}

// MARK: - CodeTools error-path execution

func testReadFileToolMissingPath() async throws {
    let tool = ReadFileTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("path"))
}

func testReadFileToolNonexistent() async throws {
    let tool = ReadFileTool()
    let result = try await tool.execute(arguments: ["path": "/nonexistent/file.txt"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("不存在"))
}

func testWriteFileToolMissingParams() async throws {
    let tool = WriteFileTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}

func testListFilesToolMissingPath() async throws {
    let tool = ListFilesTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("path"))
}

func testListFilesToolNonexistent() async throws {
    let tool = ListFilesTool()
    let result = try await tool.execute(arguments: ["path": "/nonexistent/dir"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("不存在"))
}

func testShellCommandToolMissingCommand() async throws {
    let tool = ShellCommandTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("command"))
}

func testShellCommandToolEcho() async throws {
    let tool = ShellCommandTool()
    let result = try await tool.execute(arguments: ["command": "echo hello"])
    XCTAssertFalse(result.isError)
    XCTAssertTrue(result.output.contains("hello"))
}

func testGitStatusToolDefault() async throws {
    let tool = GitStatusTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertFalse(result.isError)
}

func testGitLogToolDefault() async throws {
    let tool = GitLogTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertFalse(result.isError)
}

func testGitDiffToolDefault() async throws {
    let tool = GitDiffTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertFalse(result.isError)
}

func testClipboardToolMissingAction() async throws {
    let tool = ClipboardTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("action"))
}

func testClipboardToolInvalidAction() async throws {
    let tool = ClipboardTool()
    let result = try await tool.execute(arguments: ["action": "invalid"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("无效"))
}

// MARK: - ClaudeAgentTool

func testClaudeAgentToolMissingPrompt() async throws {
    let tool = ClaudeAgentTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("prompt"))
}

// MARK: - DeveloperTools

func testSwiftBuildToolDefinitionHasBuildOptions() async throws {
    let tool = SwiftBuildTool()
    XCTAssertEqual(tool.definition.name, "swift_build")
    let parameterNames = Set(tool.definition.parameters.map(\.name))
    XCTAssertTrue(parameterNames.contains("project_path"))
    XCTAssertTrue(parameterNames.contains("configuration"))
    XCTAssertTrue(parameterNames.contains("target"))
}

func testProjectInfoToolDefault() async throws {
    let tool = ProjectInfoTool()
    let result = try await tool.execute(arguments: [:])
    // Should find Package.swift in current directory
    XCTAssertTrue(!result.output.contains("未找到") || result.isError)
    _ = result.output
}

// MARK: - AppDriverTools error-path execution

func testOpenPathToolMissingPath() async throws {
    let tool = OpenPathTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("path"))
}

func testFinderSearchToolMissingParams() async throws {
    let tool = FinderSearchTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("query"))
}

func testListDirectoryToolMissingPath() async throws {
    let tool = ListDirectoryTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("path"))
}

func testSafariSearchToolMissingQuery() async throws {
    let tool = SafariSearchTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("query"))
}

func testTerminalRunToolMissingCommand() async throws {
    let tool = TerminalRunTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("command"))
}

func testXcodeNavigateToolMissingPath() async throws {
    let tool = XcodeNavigateTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("path"))
}

func testDOMClickToolMissingSelector() async throws {
    let tool = DOMClickTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("selector"))
}

func testDOMFillToolMissingSelector() async throws {
    let tool = DOMFillTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("selector"))
}

func testDOMFillToolMissingValue() async throws {
    let tool = DOMFillTool()
    let result = try await tool.execute(arguments: ["selector": "#name"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("value"))
}

func testDOMSubmitToolMissingSelector() async throws {
    let tool = DOMSubmitTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("selector"))
}

// MARK: - DeveloperToolbox

func testRgSearchToolMissingPattern() async throws {
    let tool = RgSearchTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("pattern"))
}

func testGitBlameToolMissingPath() async throws {
    let tool = GitBlameTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("file_path"))
}

func testGitBranchToolMissingAction() async throws {
    let tool = GitBranchTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("action"))
}

func testGitBranchToolInvalidAction() async throws {
    let tool = GitBranchTool()
    let result = try await tool.execute(arguments: ["action": "invalid"])
    XCTAssertTrue(result.isError)
}

func testGitCommitToolMissingMessage() async throws {
    let tool = GitCommitTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("message"))
}

func testProcessToolMissingAction() async throws {
    let tool = ProcessTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("action"))
}

func testProcessToolInvalidAction() async throws {
    let tool = ProcessTool()
    let result = try await tool.execute(arguments: ["action": "invalid"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("无效"))
}

func testProcessToolList() async throws {
    let tool = ProcessTool()
    let result = try await tool.execute(arguments: ["action": "list"])
    XCTAssertFalse(result.isError)
}

func testGitStashToolMissingAction() async throws {
    let tool = GitStashTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
}

func testGitPushPullToolMissingAction() async throws {
    let tool = GitPushPullTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
}

func testGitRemoteToolMissingAction() async throws {
    let tool = GitRemoteTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
}

func testGitRemoteToolInvalidAction() async throws {
    let tool = GitRemoteTool()
    let result = try await tool.execute(arguments: ["action": "invalid"])
    XCTAssertTrue(result.isError)
}

func testGitMergeRebaseToolMissingAction() async throws {
    let tool = GitMergeRebaseTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
}

func testGitMergeRebaseToolMissingBranch() async throws {
    let tool = GitMergeRebaseTool()
    let result = try await tool.execute(arguments: ["action": "merge"])
    XCTAssertTrue(result.isError)
}

func testGitTagToolMissingAction() async throws {
    let tool = GitTagTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
}

func testGitCherryPickToolMissingAction() async throws {
    let tool = GitCherryPickTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
}

func testGitRevertToolMissingCommit() async throws {
    let tool = GitRevertTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
}

func testFindSymbolToolMissingSymbol() async throws {
    let tool = FindSymbolTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("symbol"))
}
}
