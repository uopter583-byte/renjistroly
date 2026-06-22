import Foundation
import XCTest
import RenJistrolyModels

// MARK: - WorkflowTemplate tests

func testTemplateCreation() {
    let template = WorkflowTemplate(
        name: "Safari Search",
        description: "打开 Safari 并搜索关键词",
        appName: "Safari",
        steps: [
            .init(toolName: "open_app", arguments: ["app_name": "Safari"]),
            .init(toolName: "safari_search", arguments: ["query": "Swift 6"]),
        ],
        tags: ["browser", "search"]
    )
    XCTAssertTrue(template.name == "Safari Search")
    XCTAssertTrue(template.appName == "Safari")
    XCTAssertTrue(template.actionCount == 2)
    XCTAssertTrue(template.tags == ["browser", "search"])
    XCTAssertTrue(template.useCount == 0)
    XCTAssertTrue(template.lastUsedAt == nil)
}

func testTemplateToComputerUseActions() {
    let template = WorkflowTemplate(
        name: "Test",
        steps: [
            .init(id: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", toolName: "open_app", arguments: ["app_name": "Finder"]),
            .init(id: "F721E1F8-C36C-495A-93FC-0C247A3E6E5G", toolName: "click", arguments: ["x": "100", "y": "200"]),
        ]
    )
    let actions = template.toComputerUseActions()
    XCTAssertTrue(actions.count == 2)
    XCTAssertTrue(actions[0].toolCall.name == "open_app")
    XCTAssertTrue(actions[0].toolCall.arguments["app_name"] == "Finder")
    XCTAssertTrue(actions[1].toolCall.name == "click")
    XCTAssertTrue(actions[1].toolCall.arguments["x"] == "100")
}

func testTemplateWithVerification() {
    let template = WorkflowTemplate(
        name: "Type and Verify",
        steps: [
            .init(
                toolName: "type_text",
                arguments: ["text": "Hello World"],
                expectedVerification: "Hello World"
            ),
        ]
    )
    let actions = template.toComputerUseActions()
    XCTAssertTrue(actions.count == 1)
    XCTAssertTrue(actions[0].verificationGoal?.expectedText == "Hello World")
}

func testTemplateEmptySteps() {
    let template = WorkflowTemplate(name: "Empty")
    XCTAssertTrue(template.actionCount == 0)
    XCTAssertTrue(template.toComputerUseActions().isEmpty)
}

func testTemplateCodableRoundTrip() throws {
    let template = WorkflowTemplate(
        name: "Test",
        description: "A test template",
        appName: "Finder",
        steps: [
            .init(toolName: "open_path", arguments: ["path": "/Users"], expectedVerification: "Users"),
        ],
        tags: ["finder", "navigation"],
        useCount: 5
    )
    let data = try JSONEncoder().encode(template)
    let decoded = try JSONDecoder().decode(WorkflowTemplate.self, from: data)
    XCTAssertTrue(decoded.name == "Test")
    XCTAssertTrue(decoded.appName == "Finder")
    XCTAssertTrue(decoded.actionCount == 1)
    XCTAssertTrue(decoded.tags == ["finder", "navigation"])
    XCTAssertTrue(decoded.useCount == 5)
}

func testTemplateStepIdentifiable() {
    let step = WorkflowTemplate.TemplateStep(
        id: "step-1",
        toolName: "click",
        arguments: ["x": "10"]
    )
    XCTAssertTrue(step.id == "step-1")
    XCTAssertTrue(step.toolName == "click")
    XCTAssertTrue(step.arguments["x"] == "10")
    XCTAssertTrue(step.expectedVerification == nil)
}

// MARK: - SessionPhase coding

func testSessionPhaseCodable() throws {
    for phase in SessionPhase.allCases {
        let data = try JSONEncoder().encode(phase)
        let decoded = try JSONDecoder().decode(SessionPhase.self, from: data)
        XCTAssertTrue(decoded == phase)
    }
}

func testSessionLifecycleEncoding() throws {
    var lifecycle = SessionLifecycle(phase: .idle)
    _ = lifecycle.transition(to: .listening, reason: "start")
    _ = lifecycle.transition(to: .thinking, reason: "process")
    XCTAssertTrue(lifecycle.phase == .thinking)
    XCTAssertTrue(lifecycle.transitionHistory.count == 2)
    XCTAssertTrue(lifecycle.transitionHistory[0].from == .idle)
    XCTAssertTrue(lifecycle.transitionHistory[0].to == .listening)
}
