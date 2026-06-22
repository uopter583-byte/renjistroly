import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

// MARK: - SystemTools definitions

func testOpenAppToolDefinition() {
    let tool = OpenAppTool()
    XCTAssertTrue(tool.definition.name == "open_app")
    XCTAssertFalse(tool.definition.description.isEmpty)
    XCTAssertTrue(tool.riskLevel == .medium)
}

func testSystemInfoToolDefinition() {
    let tool = SystemInfoTool()
    XCTAssertTrue(tool.definition.name == "system_info")
    XCTAssertTrue(tool.riskLevel == .low)
}

func testRunningAppsToolDefinition() {
    let tool = RunningAppsTool()
    XCTAssertTrue(tool.definition.name == "running_apps")
    XCTAssertTrue(tool.riskLevel == .low)
}

func testOpenURLToolDefinition() {
    let tool = OpenURLTool()
    XCTAssertTrue(tool.definition.name == "open_url")
    XCTAssertTrue(tool.riskLevel == .medium)
}

func testTypeTextToolDefinition() {
    let tool = TypeTextTool()
    XCTAssertTrue(tool.definition.name == "type_text")
    XCTAssertTrue(tool.riskLevel == .high)
}

func testReadFocusedTextToolDefinition() {
    let tool = ReadFocusedTextTool()
    XCTAssertTrue(tool.definition.name == "read_focused_text")
    XCTAssertTrue(tool.riskLevel == .low)
}

func testPressKeyToolDefinition() {
    let tool = PressKeyTool()
    XCTAssertTrue(tool.definition.name == "press_key")
    XCTAssertTrue(tool.riskLevel == .medium)
}

func testOpenInXcodeToolDefinition() {
    let tool = OpenInXcodeTool()
    XCTAssertTrue(tool.definition.name == "open_in_xcode")
    XCTAssertTrue(tool.riskLevel == .medium)
}

func testRevealInFinderToolDefinition() {
    let tool = RevealInFinderTool()
    XCTAssertTrue(tool.definition.name == "reveal_in_finder")
    XCTAssertTrue(tool.riskLevel == .low)
}

func testListSchemesToolDefinition() {
    let tool = ListSchemesTool()
    XCTAssertTrue(tool.definition.name == "list_schemes")
    XCTAssertTrue(tool.riskLevel == .low)
}

func testBuildSettingsToolDefinition() {
    let tool = BuildSettingsTool()
    XCTAssertTrue(tool.definition.name == "build_settings")
    XCTAssertTrue(tool.riskLevel == .low)
}

// MARK: - All SystemTools have non-empty descriptions

func testAllSystemToolsDescriptionsNonEmpty() {
    let tools: [any MCPTool] = [
        OpenAppTool(), SystemInfoTool(), RunningAppsTool(),
        OpenURLTool(), TypeTextTool(), ReadFocusedTextTool(),
        PressKeyTool(), OpenInXcodeTool(), RevealInFinderTool(),
        ListSchemesTool(), BuildSettingsTool(),
    ]
    for tool in tools {
        XCTAssertTrue(!tool.definition.description.isEmpty, "\(tool.definition.name) has empty description")
    }
}
