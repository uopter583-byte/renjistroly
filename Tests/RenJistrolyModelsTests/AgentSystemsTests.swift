import Foundation
import XCTest
@testable import RenJistrolyModels

func testComputerUseRunResultRequiresVerifiedSteps() {
    let action = ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:]))
    let delta = ComputerUseStateDelta(
        before: ComputerUseAppState(activeAppName: "Finder"),
        after: ComputerUseAppState(activeAppName: "Safari")
    )
    let ok = ComputerUseStepResult(
        action: action,
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        stateDelta: delta,
        verified: true,
        verificationEvidence: ["观察到状态变化: 前台应用变化"]
    )
    let failedVerification = ComputerUseStepResult(
        action: action,
        beforeState: nil,
        toolResult: ToolCallResult(id: "2", output: "ok"),
        afterState: nil,
        verified: false,
        recoveryAttempted: true,
        recoverySummary: "重新观察 UI 快照后重试原动作"
    )

    XCTAssertTrue(ComputerUseRunResult(startedAt: Date(), steps: [ok]).succeeded)
    XCTAssertTrue(!ComputerUseRunResult(startedAt: Date(), steps: [ok, failedVerification]).succeeded)
    XCTAssertTrue(failedVerification.recoveryAttempted)
    XCTAssertTrue(failedVerification.recoverySummary?.contains("重新观察") == true)
    XCTAssertTrue(ok.stateDelta?.summary.contains("前台应用变化") == true)
    XCTAssertTrue(failedVerification.memorySteps.contains("recover: 重新观察 UI 快照后重试原动作"))
    XCTAssertTrue(ok.memorySteps.contains(where: { $0.contains("verify: 前台应用变化") }))
    XCTAssertTrue(ok.memorySteps.contains(where: { $0.contains("evidence: 观察到状态变化") }))
    XCTAssertTrue(ComputerUseRunResult(startedAt: Date(), steps: [ok, failedVerification]).memorySteps.count >= 4)
    XCTAssertTrue(ComputerUseRunResult(startedAt: Date(), steps: [ok]).learnedWorkflowSummary?.contains("tool: click") == true)
}

func testSafetyAuditRecordStoresDecision() {
    let assessment = ToolRiskAssessment(
        toolName: "click",
        riskLevel: .medium,
        actionCategory: .localInput,
        arguments: ["element_index": "e1"],
        summary: "点击 UI 元素"
    )
    let record = SafetyAuditRecord(assessment: assessment, decision: .allowedOnce)

    XCTAssertTrue(record.assessment.actionCategory == .localInput)
    XCTAssertTrue(record.decision == .allowedOnce)
}

func testRecoveryProfileSnapshotStoresMetrics() {
    let snapshot = RecoveryProfileSnapshot(
        scope: "app+tool",
        appName: "Safari",
        toolName: "click",
        strategies: [
            RecoveryStrategyMetric(strategy: "remapByStableID", successRate: 0.8),
            RecoveryStrategyMetric(strategy: "reobserveAndRetry", successRate: 0.3),
        ]
    )

    XCTAssertTrue(snapshot.scope == "app+tool")
    XCTAssertTrue(snapshot.appName == "Safari")
    XCTAssertTrue(snapshot.toolName == "click")
    XCTAssertTrue(snapshot.strategies.first?.strategy == "remapByStableID")
    XCTAssertTrue(snapshot.strategies.first?.successRate == 0.8)
}

func testDeveloperAgentEventStoresKindAndSummary() {
    let event = DeveloperAgentEvent(kind: "build", summary: "Build complete! (0.12s)")

    XCTAssertTrue(event.kind == "build")
    XCTAssertTrue(event.summary == "Build complete! (0.12s)")
}

func testComputerUseTraceSnapshotStoresRun() {
    let action = ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:]))
    let step = ComputerUseStepResult(
        action: action,
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: true,
        recoveryStrategy: "remapByStableID",
        recoverySummary: "按 stableID 重试成功"
    )
    let trace = ComputerUseTraceSnapshot(
        phase: "running",
        taskText: "点击发送按钮",
        routeLabel: "desktop",
        browserPageState: BrowserPageState(
            browserName: "Safari",
            tabTitle: "OpenAI docs",
            url: "https://platform.openai.com/docs",
            host: "platform.openai.com",
            searchQuery: "openai docs"
        ),
        run: ComputerUseRunResult(startedAt: Date(), steps: [step]),
        events: [
            ComputerUseTraceEvent(
                phase: "observing",
                stepIndex: 0,
                toolName: "click",
                summary: "观察执行前界面状态"
            )
        ]
    )

    XCTAssertTrue(trace.phase == "running")
    XCTAssertTrue(trace.taskText == "点击发送按钮")
    XCTAssertTrue(trace.routeLabel == "desktop")
    XCTAssertTrue(trace.browserPageState?.host == "platform.openai.com")
    XCTAssertTrue(trace.run.steps.first?.recoveryStrategy == "remapByStableID")
    XCTAssertTrue(trace.events.first?.phase == "observing")
    XCTAssertTrue(trace.run.succeeded)
}
