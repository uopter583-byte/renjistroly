import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

private struct TestHighRiskTool: MCPTool {
    let definition = ToolDefinition(
        name: "test_high_risk",
        description: "High risk test tool",
        parameters: []
    )
    let riskLevel: ToolRiskLevel = .high

    func execute(arguments: [String: String]) async throws -> ToolCallResult {
        ToolCallResult(id: arguments["id"] ?? "test", output: "executed")
    }
}

private struct TestLowRiskTool: MCPTool {
    let definition = ToolDefinition(
        name: "test_low_risk",
        description: "Low risk test tool",
        parameters: []
    )
    let riskLevel: ToolRiskLevel = .low

    func execute(arguments: [String: String]) async throws -> ToolCallResult {
        ToolCallResult(id: arguments["id"] ?? "test", output: "executed")
    }
}

func testMCPClientDefaultExecuteBlocksHighRiskTools() async throws {
    let registry = MCPToolRegistry()
    await registry.register(TestHighRiskTool())
    let client = MCPClient(registry: registry)

    do {
        _ = try await client.execute(ToolCallRequest(id: "1", name: "test_high_risk", arguments: [:]))
        XCTFail("high risk tool should require confirmation")
    } catch let error as ToolNeedsConfirmationError {
        XCTAssertTrue(error.assessment.riskLevel == .high)
        XCTAssertTrue(error.request.name == "test_high_risk")
    }
}

func testMCPClientDefaultExecuteAllowsLowRiskTools() async throws {
    let registry = MCPToolRegistry()
    await registry.register(TestLowRiskTool())
    let client = MCPClient(registry: registry)

    let result = try await client.execute(ToolCallRequest(id: "1", name: "test_low_risk", arguments: [:]))

    XCTAssertTrue(result.output == "executed")
}

func testMCPClientPreAssessedExecuteBypassesPolicyExplicitly() async throws {
    let registry = MCPToolRegistry()
    await registry.register(TestHighRiskTool())
    let client = MCPClient(registry: registry)

    let result = try await client.executePreAssessed(ToolCallRequest(id: "1", name: "test_high_risk", arguments: [:]))

    XCTAssertTrue(result.output == "executed")
}

func testSafetyGatewayCategorizesComputerUseObservation() async throws {
    let registry = MCPToolRegistry()
    await registry.register(GetAppStateTool())
    let gateway = ToolSafetyGateway(registry: registry, policyProvider: { .default })

    let assessment = await gateway.assess(ToolCallRequest(
        id: "observe",
        name: "get_app_state",
        arguments: ["app": "TextEdit"]
    ))

    XCTAssertTrue(assessment.actionCategory == .observe)
    XCTAssertTrue(assessment.riskLevel == .low)
}

func testSafetyGatewayCategorizesIndexedClickAsLocalInput() async throws {
    let registry = MCPToolRegistry()
    await registry.register(ClickTool())
    let gateway = ToolSafetyGateway(registry: registry, policyProvider: { .default })

    let assessment = await gateway.assess(ToolCallRequest(
        id: "click",
        name: "click",
        arguments: ["element_index": "e1"]
    ))

    XCTAssertTrue(assessment.actionCategory == .localInput)
    XCTAssertTrue(assessment.riskLevel == .medium)
}

func testSafetyGatewayCategorizesClaudeAsCodeAgent() async throws {
    let registry = MCPToolRegistry()
    await registry.register(ClaudeAgentTool())
    let gateway = ToolSafetyGateway(registry: registry, policyProvider: { .default })

    let assessment = await gateway.assess(ToolCallRequest(
        id: "claude",
        name: "claude_agent",
        arguments: ["prompt": "Run tests and fix failures"]
    ))

    XCTAssertTrue(assessment.actionCategory == .codeAgent)
    XCTAssertTrue(assessment.riskLevel == .high)
}

func testSafetyGatewayCategorizesOpenURLAsLocalNavigation() async throws {
    let registry = MCPToolRegistry()
    await registry.register(OpenURLTool())
    let gateway = ToolSafetyGateway(registry: registry, policyProvider: { .default })

    let assessment = await gateway.assess(ToolCallRequest(
        id: "url",
        name: "open_url",
        arguments: ["url": "https://example.com"]
    ))

    XCTAssertTrue(assessment.actionCategory == .localNavigation)
    XCTAssertTrue(assessment.riskLevel == .medium)
}

func testSafetyGatewayCategorizesGetBrowserStateAsObserve() async throws {
    let registry = MCPToolRegistry()
    await registry.register(GetBrowserStateTool())
    let gateway = ToolSafetyGateway(registry: registry, policyProvider: { .default })

    let assessment = await gateway.assess(ToolCallRequest(
        id: "browser-state",
        name: "get_browser_state",
        arguments: ["app": "Safari"]
    ))

    XCTAssertTrue(assessment.actionCategory == .observe)
    XCTAssertTrue(assessment.riskLevel == .low)
}

func testSafetyGatewayCategorizesGetFinderStateAsObserve() async throws {
    let registry = MCPToolRegistry()
    await registry.register(GetFinderStateTool())
    let gateway = ToolSafetyGateway(registry: registry, policyProvider: { .default })

    let assessment = await gateway.assess(ToolCallRequest(
        id: "finder-state",
        name: "get_finder_state",
        arguments: [:]
    ))

    XCTAssertTrue(assessment.actionCategory == .observe)
    XCTAssertTrue(assessment.riskLevel == .low)
}
