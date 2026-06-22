import Foundation
import XCTest
import RenJistrolyModels

// MARK: - ComputerUseTargetKind

func testComputerUseTargetKindTitles() {
    XCTAssertTrue(ComputerUseTargetKind.accessibilityElement.title == "控件")
    XCTAssertTrue(ComputerUseTargetKind.ocrText.title == "屏幕文字")
    XCTAssertTrue(ComputerUseTargetKind.window.title == "窗口")
    XCTAssertTrue(ComputerUseTargetKind.runningApp.title == "运行中 App")
    XCTAssertTrue(ComputerUseTargetKind.coordinate.title == "坐标")
    XCTAssertTrue(ComputerUseTargetKind.unknown.title == "未知")
}

// MARK: - TerminalTaskStatus

func testTerminalTaskStatusTitles() {
    XCTAssertTrue(TerminalTaskStatus.pending.title == "待执行")
    XCTAssertTrue(TerminalTaskStatus.running.title == "运行中")
    XCTAssertTrue(TerminalTaskStatus.succeeded.title == "成功")
    XCTAssertTrue(TerminalTaskStatus.failed.title == "失败")
    XCTAssertTrue(TerminalTaskStatus.waiting.title == "等待")
    XCTAssertTrue(TerminalTaskStatus.cancelled.title == "已取消")
}

// MARK: - ComputerUseTarget

func testComputerUseTargetDefaults() {
    let target = ComputerUseTarget(kind: .accessibilityElement, label: "OK按钮")
    XCTAssertTrue(target.kind == .accessibilityElement)
    XCTAssertTrue(target.label == "OK按钮")
    XCTAssertTrue(target.confidence == 0.5)
    XCTAssertTrue(target.actions.isEmpty)
}

func testComputerUseTargetWithFullDetails() {
    let target = ComputerUseTarget(
        kind: .window,
        label: "Safari",
        owner: "com.apple.Safari",
        role: "AXWindow",
        boundsDescription: "{{0,0},{1200,800}}",
        valuePreview: nil,
        actions: ["focus", "close"],
        depth: 1,
        confidence: 0.9
    )
    XCTAssertTrue(target.owner == "com.apple.Safari")
    XCTAssertTrue(target.depth == 1)
    XCTAssertTrue(target.confidence == 0.9)
    XCTAssertTrue(target.actions.count == 2)
}

// MARK: - ComputerUseObservation

func testComputerUseObservationDefaults() {
    let obs = ComputerUseObservation()
    XCTAssertTrue(obs.runningApps.isEmpty)
    XCTAssertTrue(obs.visibleWindows.isEmpty)
    XCTAssertTrue(obs.targets.isEmpty)
    XCTAssertTrue(obs.frontmostApp == nil)
}

// MARK: - ComputerUsePlan

func testComputerUsePlanMinimal() {
    let plan = ComputerUsePlan(userText: "打开Safari", intent: .activateApp, reason: "用户请求")
    XCTAssertTrue(plan.intent == .activateApp)
    XCTAssertTrue(plan.steps.isEmpty)
    XCTAssertFalse(plan.requiresConfirmation)
}

func testComputerUsePlanWithSteps() {
    let action = MacAction(kind: .openApplication, payload: ["name": "Safari"], riskLevel: .reversibleInput, humanPreview: "打开Safari")
    let step = ComputerUseStep(action: action, expectedState: "Safari在前台")
    let plan = ComputerUsePlan(
        userText: "打开Safari",
        intent: .activateApp,
        action: action,
        steps: [step],
        reason: "用户请求"
    )
    XCTAssertTrue(plan.steps.count == 1)
    XCTAssertTrue(plan.action?.kind == .openApplication)
}

// MARK: - ComputerUseStepOutcome

func testComputerUseStepOutcomeVerified() {
    let action = MacAction(kind: .insertText, payload: ["text": "hello"], riskLevel: .reversibleInput, humanPreview: "输入文本")
    let step = ComputerUseStep(action: action, expectedState: "文本已输入")
    let result = ActionResult(actionID: action.id, success: true, message: "输入成功")
    let outcome = ComputerUseStepOutcome(step: step, actionResult: result, verified: true, note: "已验证")
    XCTAssertTrue(outcome.verified)
    XCTAssertTrue(outcome.note == "已验证")
}

// MARK: - ComputerUseRunOutcome

func testComputerUseRunOutcomeEmpty() {
    let plan = ComputerUsePlan(userText: "测试", intent: .unknown, reason: "测试")
    let outcome = ComputerUseRunOutcome(plan: plan, message: "完成")
    XCTAssertTrue(outcome.stepResults.isEmpty)
    XCTAssertTrue(outcome.message == "完成")
}

// MARK: - TerminalTaskRecord

func testTerminalTaskRecordDefaults() {
    let task = TerminalTaskRecord(name: "构建", command: "swift build", workingDirectory: "/tmp")
    XCTAssertTrue(task.status == .pending)
    XCTAssertTrue(task.lastMessage.isEmpty)
    XCTAssertTrue(task.pid == nil)
}
