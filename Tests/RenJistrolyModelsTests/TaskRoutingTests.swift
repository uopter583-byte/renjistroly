import Foundation
import XCTest
import RenJistrolyEnterprise
@testable import RenJistrolyModels

// MARK: - ComputerUseStepResult.memorySteps

func testMemoryStepsBasic() {
    let step = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: true
    )
    let steps = step.memorySteps
    XCTAssertTrue(steps.first == "tool: click")
    XCTAssertTrue(steps.count == 1)
}

func testMemoryStepsWithRecovery() {
    let step = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: true,
        recoveryAttempted: true,
        recoveryStrategy: "retryWithStableID",
        recoverySummary: "重试成功"
    )
    let steps = step.memorySteps
    XCTAssertTrue(steps.contains("tool: click"))
    XCTAssertTrue(steps.contains("strategy: retryWithStableID"))
    XCTAssertTrue(steps.contains("recover: 重试成功"))
}

func testMemoryStepsWithStateDelta() {
    let before = ComputerUseAppState(activeAppName: "Finder")
    let after = ComputerUseAppState(activeAppName: "Safari")
    let delta = ComputerUseStateDelta(before: before, after: after)
    let step = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "open_app", arguments: ["app_name": "Safari"])),
        beforeState: before,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: after,
        stateDelta: delta,
        verified: true
    )
    XCTAssertTrue(step.memorySteps.contains { $0.hasPrefix("verify: ") })
}

func testMemoryStepsWithEvidence() {
    let step = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: true,
        verificationEvidence: ["screen shows OK button pressed"]
    )
    XCTAssertTrue(step.memorySteps.contains("evidence: screen shows OK button pressed"))
}

func testMemoryStepsEmptyRecoveryStrategySkipped() {
    let step = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: true,
        recoveryAttempted: true,
        recoveryStrategy: "",
        recoverySummary: nil
    )
    let steps = step.memorySteps
    XCTAssertTrue(!steps.contains { $0.hasPrefix("strategy: ") })
    XCTAssertTrue(!steps.contains { $0.hasPrefix("recover: ") })
}

// MARK: - ComputerUseRunResult

func testRunSucceededAllGood() {
    let step = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: true
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [step])
    XCTAssertTrue(run.succeeded == true)
}

func testRunSucceededWithError() {
    let step = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "failed", isError: true),
        afterState: nil,
        verified: true
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [step])
    XCTAssertTrue(run.succeeded == false)
}

func testRunSucceededNotVerified() {
    let step = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: false
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [step])
    XCTAssertTrue(run.succeeded == false)
}

func testRunSucceededEmpty() {
    let run = ComputerUseRunResult(startedAt: Date(), steps: [])
    XCTAssertTrue(run.succeeded == false)
}

func testRunMemoryStepsFlatMaps() {
    let step1 = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: true
    )
    let step2 = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "2", name: "type_text", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "2", output: "ok"),
        afterState: nil,
        verified: true
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [step1, step2])
    let steps = run.memorySteps
    XCTAssertTrue(steps.contains("tool: click"))
    XCTAssertTrue(steps.contains("tool: type_text"))
}

func testLearnedWorkflowSummary() {
    let step1 = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "open_app", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: true
    )
    let step2 = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "2", name: "click", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "2", output: "ok"),
        afterState: nil,
        verified: true
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [step1, step2])
    let summary = run.learnedWorkflowSummary
    XCTAssertTrue(summary?.contains(" -> ") == true)
}

func testLearnedWorkflowSummaryEmpty() {
    let run = ComputerUseRunResult(startedAt: Date(), steps: [])
    XCTAssertTrue(run.learnedWorkflowSummary == nil)
}

func testInferredAppNameFromVerificationGoal() {
    let goal = VerificationGoal(expectedApp: "Safari")
    let action = ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "open_app", arguments: [:]), verificationGoal: goal)
    let step = ComputerUseStepResult(
        action: action,
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: true
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [step])
    XCTAssertTrue(run.inferredAppName() == "Safari")
}

func testInferredAppNameFromAfterState() {
    let action = ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "open_app", arguments: [:]))
    let after = ComputerUseAppState(activeAppName: "Safari")
    let step = ComputerUseStepResult(
        action: action,
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: after,
        verified: true
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [step])
    XCTAssertTrue(run.inferredAppName() == "Safari")
}

func testInferredAppNameFromBeforeState() {
    let action = ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:]))
    let before = ComputerUseAppState(activeAppName: "Terminal")
    let step = ComputerUseStepResult(
        action: action,
        beforeState: before,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: true
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [step])
    XCTAssertTrue(run.inferredAppName() == "Terminal")
}

func testInferredAppNameFallback() {
    let action = ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:]))
    let step = ComputerUseStepResult(
        action: action,
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: true
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [step])
    XCTAssertTrue(run.inferredAppName(fallback: "Unknown") == "Unknown")
}

func testInferredAppNameNilFallback() {
    let action = ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:]))
    let step = ComputerUseStepResult(
        action: action,
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: true
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [step])
    XCTAssertTrue(run.inferredAppName() == nil)
}

// MARK: - ComputerUseStateDelta

func testStateDeltaHasMeaningfulChangeAppSwitch() {
    let before = ComputerUseAppState(activeAppName: "Finder")
    let after = ComputerUseAppState(activeAppName: "Safari")
    let delta = ComputerUseStateDelta(before: before, after: after)
    XCTAssertTrue(delta.hasMeaningfulChange == true)
    XCTAssertTrue(delta.activeAppChanged == true)
}

func testStateDeltaNoChange() {
    let state = ComputerUseAppState(activeAppName: "Finder", focusedWindowTitle: "Home")
    let delta = ComputerUseStateDelta(before: state, after: state)
    XCTAssertTrue(delta.hasMeaningfulChange == false)
}

func testStateDeltaSummaryWithChanges() {
    let before = ComputerUseAppState(activeAppName: "Finder", focusedWindowTitle: "Old")
    let after = ComputerUseAppState(activeAppName: "Safari", focusedWindowTitle: "New")
    let delta = ComputerUseStateDelta(before: before, after: after)
    XCTAssertTrue(delta.summary.contains("前台应用变化"))
    XCTAssertTrue(delta.summary.contains("焦点窗口变化"))
}

func testStateDeltaSummaryNoChanges() {
    let state = ComputerUseAppState()
    let delta = ComputerUseStateDelta(before: state, after: state)
    XCTAssertTrue(delta.summary == "未观察到明显状态变化")
}

func testStateDeltaWindowChange() {
    let before = ComputerUseAppState(focusedWindowTitle: "Old")
    let after = ComputerUseAppState(focusedWindowTitle: "New")
    let delta = ComputerUseStateDelta(before: before, after: after)
    XCTAssertTrue(delta.focusedWindowChanged == true)
}

// MARK: - EnterpriseRiskLevel Comparable

func testEnterpriseRiskLevelComparison() {
    XCTAssertTrue(ActionRiskLevel.readOnly < ActionRiskLevel.reversibleInput)
    XCTAssertTrue(ActionRiskLevel.reversibleInput < ActionRiskLevel.persistentOrExternal)
    XCTAssertTrue(ActionRiskLevel.persistentOrExternal < ActionRiskLevel.destructiveOrSensitive)
    XCTAssertTrue(ActionRiskLevel.readOnly < ActionRiskLevel.destructiveOrSensitive)
    XCTAssertTrue(!(ActionRiskLevel.destructiveOrSensitive < ActionRiskLevel.readOnly))
}

// MARK: - PermissionStatus

func testPermissionStatusIsGranted() {
    XCTAssertTrue(PermissionStatus.granted.isGranted == true)
    XCTAssertTrue(PermissionStatus.denied.isGranted == false)
    XCTAssertTrue(PermissionStatus.notDetermined.isGranted == false)
    XCTAssertTrue(PermissionStatus.unknown.isGranted == false)
}

// MARK: - ComputerUseElement.compactLabel

func testCompactLabelPrefersTitle() {
    let el = ComputerUseElement(elementIndex: "1", role: "AXButton", title: "OK", value: "value", depth: 0, childPath: [])
    XCTAssertTrue(el.compactLabel == "OK")
}

func testCompactLabelFallsBackToValue() {
    let el = ComputerUseElement(elementIndex: "1", role: "AXButton", title: nil, value: "Hello", depth: 0, childPath: [])
    XCTAssertTrue(el.compactLabel == "Hello")
}

func testCompactLabelFallsBackToRole() {
    let el = ComputerUseElement(elementIndex: "1", role: "AXButton", depth: 0, childPath: [])
    XCTAssertTrue(el.compactLabel == "AXButton")
}

// MARK: - ComputerUseAppState.withoutScreenshot

func testWithoutScreenshot() {
    let state = ComputerUseAppState(
        activeAppName: "Safari",
        screenshotPNGBase64: "base64data"
    )
    let stripped = state.withoutScreenshot()
    XCTAssertTrue(stripped.screenshotPNGBase64 == nil)
    XCTAssertTrue(stripped.activeAppName == "Safari")
}

// MARK: - ComputerUseElement stableID generation

func testStableIDGeneration() {
    let el = ComputerUseElement(
        elementIndex: "1",
        role: "AXButton",
        title: "OK",
        depth: 0,
        childPath: []
    )
    XCTAssertTrue(el.stableID.contains("axbutton"))
    XCTAssertTrue(el.stableID.contains("ok"))
}

func testStableIDGenerationWithPath() {
    let el = ComputerUseElement(
        elementIndex: "1",
        role: "AXButton",
        title: "Submit",
        depth: 1,
        childPath: [0, 1]
    )
    XCTAssertTrue(el.stableID.contains("0.1"))
    XCTAssertTrue(el.stableID.contains("submit"))
}
