import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

// MARK: - Mock tool for testing

private struct MockTool: MCPTool {
    let name: String
    let level: ToolRiskLevel
    var executeResult: ToolCallResult

    var definition: ToolDefinition { ToolDefinition(name: name, description: "", parameters: []) }
    var riskLevel: ToolRiskLevel { level }
    func execute(arguments: [String: String]) async throws -> ToolCallResult { executeResult }
}

private func mockTool(_ name: String, level: ToolRiskLevel = .low) -> MockTool {
    MockTool(name: name, level: level, executeResult: ToolCallResult(id: "r1", output: "ok"))
}

// MARK: - Registration

func testRegisterAndGet() async {
    let registry = MCPToolRegistry()
    await registry.register(mockTool("test_tool"))
    let tool = await registry.getTool("test_tool")
    XCTAssertTrue(tool != nil)
    XCTAssertTrue(tool?.definition.name == "test_tool")
}

func testGetMissingTool() async {
    let registry = MCPToolRegistry()
    let tool = await registry.getTool("nonexistent")
    XCTAssertTrue(tool == nil)
}

func testRegisterAll() async {
    let registry = MCPToolRegistry()
    await registry.registerAll([mockTool("a"), mockTool("b"), mockTool("c")])
    let count = await registry.toolCount
    XCTAssertTrue(count == 3)
}

func testToolCount() async {
    let registry = MCPToolRegistry()
    var count = await registry.toolCount
    XCTAssertTrue(count == 0)
    await registry.register(mockTool("t1"))
    count = await registry.toolCount
    XCTAssertTrue(count == 1)
}

func testAllDefinitions() async {
    let registry = MCPToolRegistry()
    await registry.registerAll([mockTool("a"), mockTool("b")])
    let defs = await registry.allDefinitions
    XCTAssertTrue(defs.count == 2)
    XCTAssertTrue(defs.map(\.name).sorted() == ["a", "b"])
}

// MARK: - Execution

func testExecuteKnownTool() async {
    let registry = MCPToolRegistry()
    var tool = mockTool("echo", level: .low)
    tool.executeResult = ToolCallResult(id: "r1", output: "hello")
    await registry.register(tool)

    let result = try? await registry.executeTool(ToolCallRequest(id: "r1", name: "echo", arguments: [:]))
    XCTAssertTrue(result?.output == "hello")
    XCTAssertTrue(result?.isError == false)
}

func testExecuteUnknownTool() async {
    let registry = MCPToolRegistry()
    let result = try? await registry.executeTool(ToolCallRequest(id: "r1", name: "ghost", arguments: [:]))
    XCTAssertTrue(result?.isError == true)
    XCTAssertTrue(result?.output.contains("未知工具") == true)
}

func testExecuteToolError() async {
    let registry = MCPToolRegistry()
    struct FailingTool: MCPTool {
        var definition: ToolDefinition { ToolDefinition(name: "failer", description: "", parameters: []) }
        var riskLevel: ToolRiskLevel { .low }
        func execute(arguments: [String: String]) async throws -> ToolCallResult {
            throw NSError(domain: "test", code: 1)
        }
    }
    await registry.register(FailingTool())
    let result = try? await registry.executeTool(ToolCallRequest(id: "r1", name: "failer", arguments: [:]))
    XCTAssertTrue(result?.isError == true)
    XCTAssertTrue(result?.output.contains("工具执行失败") == true)
}

// MARK: - Overwrite

func testRegisterOverwrites() async {
    let registry = MCPToolRegistry()
    await registry.register(mockTool("dup", level: .low))
    await registry.register(mockTool("dup", level: .high))
    let count = await registry.toolCount
    XCTAssertTrue(count == 1)
}
