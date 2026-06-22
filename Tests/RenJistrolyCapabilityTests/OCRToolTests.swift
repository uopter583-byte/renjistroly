import XCTest
import RenJistrolyModels
@testable import RenJistrolySystemBridge
@testable import RenJistrolyCapability

func testOCRToolDefinition() {
    let tool = OCRTool()
    XCTAssertTrue(tool.definition.name == "ocr_screen")
    XCTAssertTrue(tool.definition.parameters.count == 2)
    XCTAssertTrue(tool.definition.parameters[0].name == "min_confidence")
    XCTAssertTrue(tool.definition.parameters[1].name == "engine")
}

func testOCRToolRiskLevel() {
    let tool = OCRTool()
    XCTAssertTrue(tool.riskLevel == .low)
}

func testOCRToolSafetyAssessmentIsObserveCategory() async throws {
    let registry = MCPToolRegistry()
    await registry.register(OCRTool())
    let gateway = ToolSafetyGateway(registry: registry, policyProvider: { .default })
    let request = ToolCallRequest(id: "1", name: "ocr_screen", arguments: [:])
    let assessment = await gateway.assess(request)
    XCTAssertTrue(assessment.riskLevel == .low)
}

func testOCRToolRegistrationInRegistry() async {
    let registry = MCPToolRegistry()
    await registry.register(OCRTool())
    let tool = await registry.getTool("ocr_screen")
    XCTAssertTrue(tool != nil)
    XCTAssertTrue(tool?.riskLevel == .low)
}
