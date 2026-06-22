import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - isTerminalResponse

func testIsTerminalResponseChineseComplete() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let r1 = await orch.isTerminalResponse(Message(role: .assistant, content: [.text("已完成")]))
    XCTAssertTrue(r1 == true)
    let r2 = await orch.isTerminalResponse(Message(role: .assistant, content: [.text("操作完成")]))
    XCTAssertTrue(r2 == true)
    let r3 = await orch.isTerminalResponse(Message(role: .assistant, content: [.text("以上是结果")]))
    XCTAssertTrue(r3 == true)
}

func testIsTerminalResponseEnglish() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let r1 = await orch.isTerminalResponse(Message(role: .assistant, content: [.text("done")]))
    XCTAssertTrue(r1 == true)
    let r2 = await orch.isTerminalResponse(Message(role: .assistant, content: [.text("Here is the result")]))
    XCTAssertTrue(r2 == true)
}

func testIsTerminalResponseNotTerminal() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let r1 = await orch.isTerminalResponse(Message(role: .assistant, content: [.text("Let me check that for you")]))
    XCTAssertTrue(r1 == false)
    let r2 = await orch.isTerminalResponse(Message(role: .assistant, content: [.text("I'll look into this")]))
    XCTAssertTrue(r2 == false)
}

func testIsTerminalResponseTooLong() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let long = String(repeating: "已完成 ", count: 30)
    let r = await orch.isTerminalResponse(Message(role: .assistant, content: [.text(long)]))
    XCTAssertTrue(r == false)
}

// MARK: - inferVerificationGoal

func testInferVerificationGoalOpenApp() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let goal = await orch.inferVerificationGoal(for: ToolCallRequest(id: "1", name: "open_app", arguments: ["app_name": "Safari"]))
    XCTAssertTrue(goal?.expectedText == "Safari")
    XCTAssertTrue(goal?.expectedApp == "Safari")
}

func testInferVerificationGoalOpenURL() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let goal = await orch.inferVerificationGoal(for: ToolCallRequest(id: "1", name: "open_url", arguments: ["url": "https://example.com/path"]))
    XCTAssertTrue(goal?.expectedText == "example.com")
    XCTAssertTrue(goal?.expectedApp == "Safari")
    XCTAssertTrue(goal?.expectedWindowTitle == "example.com")
}

func testInferVerificationGoalSafariSearch() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let goal = await orch.inferVerificationGoal(for: ToolCallRequest(id: "1", name: "safari_search", arguments: ["query": "Swift"]))
    XCTAssertTrue(goal?.expectedText == "Swift")
    XCTAssertTrue(goal?.expectedApp == "Safari")
}

func testInferVerificationGoalClick() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let goal = await orch.inferVerificationGoal(for: ToolCallRequest(id: "1", name: "click", arguments: ["title": "OK", "role": "AXButton"]))
    XCTAssertTrue(goal?.expectedText == "OK")
    XCTAssertTrue(goal?.expectedElementRole == "AXButton")
}

func testInferVerificationGoalClickElement() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let goal = await orch.inferVerificationGoal(for: ToolCallRequest(id: "1", name: "click_element", arguments: ["label": "Submit"]))
    XCTAssertTrue(goal?.expectedText == "Submit")
}

func testInferVerificationGoalTypeText() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let goal = await orch.inferVerificationGoal(for: ToolCallRequest(id: "1", name: "type_text", arguments: ["text": "hello"]))
    XCTAssertTrue(goal?.expectedText == "hello")
}

func testInferVerificationGoalSetValue() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let goal = await orch.inferVerificationGoal(for: ToolCallRequest(id: "1", name: "set_value", arguments: ["value": "42"]))
    XCTAssertTrue(goal?.expectedText == "42")
}

func testInferVerificationGoalFocusWindow() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let goal = await orch.inferVerificationGoal(for: ToolCallRequest(id: "1", name: "focus_window", arguments: ["title": "Terminal"]))
    XCTAssertTrue(goal?.expectedWindowTitle == "Terminal")
}

func testInferVerificationGoalUnknown() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let goal = await orch.inferVerificationGoal(for: ToolCallRequest(id: "1", name: "unknown_tool", arguments: [:]))
    XCTAssertTrue(goal == nil)
}

// MARK: - buildStateContext

func testBuildStateContextEmpty() async {
    let orch = AgentOrchestrator(smartRouter: SmartRouter())
    let ctx = await orch.buildStateContext()
    XCTAssertTrue(ctx.contains("Agent 内部状态"))
    XCTAssertTrue(ctx.contains("当前阶段"))
    XCTAssertTrue(ctx.contains("循环轮次"))
}

func testBuildStateContextWithState() async {
    let orch = AgentOrchestrator(
        smartRouter: SmartRouter(),
        state: AgentLoopState(
            observations: [
                AgentObservation(
                    appState: nil, browserState: nil, terminalOutput: nil,
                    summary: "Safari 前台"
                ),
            ],
            completedSubtasks: [
                AgentSubtask(description: "打开 Safari"),
            ],
            pendingSubtasks: [
                AgentSubtask(description: "搜索天气"),
            ],
            failedAttempts: [
                AgentFailedAttempt(
                    toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:]),
                    error: "元素不可见",
                    recoveryStrategy: "remapByStableID"
                ),
            ],
            currentPhase: .acting,
            roundCount: 3,
            stagnationCount: 0
        )
    )
    let ctx = await orch.buildStateContext()
    XCTAssertTrue(ctx.contains("Safari 前台"))
    XCTAssertTrue(ctx.contains("打开 Safari"))
    XCTAssertTrue(ctx.contains("搜索天气"))
    XCTAssertTrue(ctx.contains("click"))
    XCTAssertTrue(ctx.contains("acting"))
    XCTAssertTrue(ctx.contains("3"))
}

// MARK: - AgentError

func testAgentErrorNoAvailableBackend() {
    let desc = String(describing: AgentError.noAvailableBackend(nil))
    XCTAssertTrue(desc.contains("noAvailableBackend"))
}

func testAgentErrorMaxIterationsReached() {
    let desc = String(describing: AgentError.maxIterationsReached)
    XCTAssertTrue(desc.contains("maxIterationsReached"))
}

func testAgentErrorTooManyAgents() {
    let desc = String(describing: AgentError.tooManyAgents)
    XCTAssertTrue(desc.contains("tooManyAgents"))
}

func testAgentErrorToolExecutionFailed() {
    let err = AgentError.toolExecutionFailed("click failed")
    let desc = String(describing: err)
    XCTAssertTrue(desc.contains("toolExecutionFailed"))
    XCTAssertTrue(desc.contains("click failed"))
}

func testAgentErrorAllCasesDistinct() {
    let errors: [AgentError] = [
        .noAvailableBackend(nil),
        .maxIterationsReached,
        .tooManyAgents,
        .toolExecutionFailed("err"),
    ]
    let descriptions = Set(errors.map { String(describing: $0) })
    XCTAssertTrue(descriptions.count == 4)
}
