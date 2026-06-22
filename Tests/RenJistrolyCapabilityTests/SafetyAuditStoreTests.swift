import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

func testSafetyAuditStoreRecordsRecentDecisions() async {
    let store = SafetyAuditStore()
    let assessment = ToolRiskAssessment(
        toolName: "set_value",
        riskLevel: .medium,
        actionCategory: .localInput,
        arguments: [:],
        summary: "设置值"
    )

    await store.record(assessment: assessment, decision: .autoAllowed)
    let recent = await store.recent()

    XCTAssertTrue(recent.count == 1)
    XCTAssertTrue(recent[0].decision == .autoAllowed)
}
