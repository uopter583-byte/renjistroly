import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

// MARK: - Tool definitions

func testCloseWindowToolDefinition() {
    let tool = CloseWindowTool()
    XCTAssertTrue(tool.definition.name == "close_window")
    XCTAssertTrue(tool.riskLevel == .medium)
}

func testMinimizeWindowToolDefinition() {
    let tool = MinimizeWindowTool()
    XCTAssertTrue(tool.definition.name == "minimize_window")
    XCTAssertTrue(tool.riskLevel == .medium)
}

func testOpenFolderToolDefinition() {
    let tool = OpenFolderTool()
    XCTAssertTrue(tool.definition.name == "open_folder")
    XCTAssertTrue(tool.riskLevel == .low)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "path" })
}

func testCopySelectedToolDefinition() {
    let tool = CopySelectedTool()
    XCTAssertTrue(tool.definition.name == "copy_selected")
    XCTAssertTrue(tool.riskLevel == .low)
}

func testRightClickAtToolDefinition() {
    let tool = RightClickAtTool()
    XCTAssertTrue(tool.definition.name == "right_click_at")
    XCTAssertTrue(tool.riskLevel == .medium)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "x" })
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "y" })
}

func testDoubleClickAtToolDefinition() {
    let tool = DoubleClickAtTool()
    XCTAssertTrue(tool.definition.name == "double_click_at")
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "x" })
}


func testMediaControlToolDefinition() {
    let tool = MediaControlTool()
    XCTAssertTrue(tool.definition.name == "media_control")
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "action" })
}

func testOfficePasteToolDefinition() {
    let tool = OfficePasteTool()
    XCTAssertTrue(tool.definition.name == "office_paste")
    XCTAssertTrue(tool.riskLevel == .medium)
}

func testOfficeSelectAllToolDefinition() {
    let tool = OfficeSelectAllTool()
    XCTAssertTrue(tool.definition.name == "office_select_all")
}

func testOfficeSaveToolDefinition() {
    let tool = OfficeSaveTool()
    XCTAssertTrue(tool.definition.name == "office_save")
}

func testOfficeUndoToolDefinition() {
    let tool = OfficeUndoTool()
    XCTAssertTrue(tool.definition.name == "office_undo")
}

// MARK: - Execution (non-UI)

func testOpenFolderToolExecuteInvalidPath() async throws {
    let tool = OpenFolderTool()
    let result = try await tool.execute(arguments: ["path": "/tmp/nonexistent-folder-12345"])
    XCTAssertFalse(result.isError) // NSWorkspace.open doesn't error on non-existent paths
}

func testRightClickAtToolExecuteInvalidCoords() async throws {
    let tool = RightClickAtTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("无效坐标"))
}

func testDoubleClickAtToolExecuteInvalidCoords() async throws {
    let tool = DoubleClickAtTool()
    let result = try await tool.execute(arguments: ["x": "abc", "y": "def"])
    XCTAssertTrue(result.isError)
}

// MARK: - Registration

func testAppIntegrationToolsInRegistry() async {
    let registry = MCPToolRegistry()
    await registry.registerAll([
        CloseWindowTool(), MinimizeWindowTool(), OpenFolderTool(),
        CopySelectedTool(), RightClickAtTool(), DoubleClickAtTool(),
        BrowserNavigateTool(), MediaControlTool(),
        OfficePasteTool(), OfficeSelectAllTool(), OfficeSaveTool(), OfficeUndoTool(),
    ])
    let count = await registry.toolCount
    XCTAssertTrue(count == 12)
    let closeWindow = await registry.getTool("close_window")
    XCTAssertTrue(closeWindow != nil)
    let browserNavigate = await registry.getTool("browser_navigate")
    XCTAssertTrue(browserNavigate != nil)
    let mediaControl = await registry.getTool("media_control")
    XCTAssertTrue(mediaControl != nil)
    let officePaste = await registry.getTool("office_paste")
    XCTAssertTrue(officePaste != nil)
}
