import XCTest
@testable import RenJistrolyModels

func testAgentSkillStoresWorkflowSteps() {
    let skill = AgentSkill(
        name: "发布",
        description: "发布流程",
        triggerPhrases: ["发布 app"],
        steps: ["build", "test"]
    )

    XCTAssertTrue(skill.steps == ["build", "test"])
    XCTAssertTrue(skill.triggerPhrases.contains("发布 app"))
}

func testComputerUseEvalTaskCategoriesExist() {
    XCTAssertTrue(ComputerUseEvalTask.Category.allCases.contains(.browser))
    XCTAssertTrue(ComputerUseEvalTask.Category.allCases.contains(.finder))
}
