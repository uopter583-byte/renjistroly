import XCTest
import RenJistrolyModels

struct ExecutionPlanTests {

func testPlanCreation() {
        let steps = [
            PlanStep(description: "读取文件"),
            PlanStep(description: "分析内容"),
            PlanStep(description: "生成建议"),
        ]
        let plan = ExecutionPlan(title: "分析代码", steps: steps)
        XCTAssertTrue(plan.title == "分析代码")
        XCTAssertTrue(plan.steps.count == 3)
        XCTAssertTrue(plan.status == .pendingApproval)
        XCTAssertTrue(plan.currentStepIndex == 0)
    }

func testPlanProgressTrack() {
        var plan = ExecutionPlan(title: "测试", steps: [
            PlanStep(description: "Step 1"),
            PlanStep(description: "Step 2"),
            PlanStep(description: "Step 3"),
        ])

        XCTAssertTrue(plan.currentStepIndex == 0)
        XCTAssertTrue(plan.hasRemainingSteps)

        plan.currentStepIndex = 1
        plan.steps[0].status = .completed
        XCTAssertTrue(plan.currentStep == plan.steps[1])
        XCTAssertTrue(plan.progressFraction == 1.0 / 3.0)

        plan.currentStepIndex = 2
        plan.steps[1].status = .completed
        plan.currentStepIndex = 3
        plan.steps[2].status = .completed
        XCTAssertFalse(plan.hasRemainingSteps)
        XCTAssertTrue(plan.progressFraction == 1.0)
    }

func testPlanStatusTransitions() {
        var plan = ExecutionPlan(title: "测试", steps: [PlanStep(description: "S1")])
        XCTAssertTrue(plan.status == .pendingApproval)

        plan.status = .approved
        XCTAssertTrue(plan.status == .approved)

        plan.status = .executing
        plan.steps[0].status = .executing
        XCTAssertTrue(plan.steps[0].status == .executing)

        plan.steps[0].status = .completed
        plan.status = .completed
        XCTAssertTrue(plan.status == .completed)
    }

func testPlanCancellation() {
        var plan = ExecutionPlan(title: "取消测试", steps: [
            PlanStep(description: "S1"),
            PlanStep(description: "S2"),
        ])
        plan.status = .cancelled
        XCTAssertTrue(plan.status == .cancelled)
    }

func testEmptyPlanHasNoSteps() {
        let plan = ExecutionPlan(title: "空计划", steps: [])
        XCTAssertTrue(plan.steps.isEmpty)
        XCTAssertFalse(plan.hasRemainingSteps)
        XCTAssertTrue(plan.progressFraction == 0)
    }

func testPlanStepFields() {
        var step = PlanStep(
            id: "s1",
            description: "打开 Safari",
            toolCalls: [ToolCallRequest(id: "t1", name: "open_app", arguments: ["app_name": "Safari"])],
            riskLevel: .medium
        )
        XCTAssertTrue(step.id == "s1")
        XCTAssertTrue(step.description == "打开 Safari")
        XCTAssertTrue(step.toolCalls.count == 1)
        XCTAssertTrue(step.riskLevel == .medium)
        XCTAssertTrue(step.status == .pending)
        XCTAssertTrue(step.result == nil)

        step.status = .completed
        step.result = "已打开 Safari"
        XCTAssertTrue(step.status == .completed)
        XCTAssertTrue(step.result == "已打开 Safari")
    }

func testHighestRiskLevel() {
        let steps = [
            PlanStep(description: "读取状态", riskLevel: .low),
            PlanStep(description: "点击按钮", riskLevel: .medium),
            PlanStep(description: "执行命令", riskLevel: .high),
        ]
        let plan = ExecutionPlan(title: "混合风险", steps: steps)
        XCTAssertTrue(plan.highestRiskLevel == .high)
    }

func testAllLowRiskPlan() {
        let steps = [
            PlanStep(description: "A", riskLevel: .low),
            PlanStep(description: "B", riskLevel: .low),
        ]
        let plan = ExecutionPlan(title: "低风险", steps: steps)
        XCTAssertTrue(plan.highestRiskLevel == .low)
    }

func testCurrentStepOutOfBounds() {
        var plan = ExecutionPlan(title: "边界测试", steps: [PlanStep(description: "唯一")])
        plan.currentStepIndex = 99
        XCTAssertTrue(plan.currentStep == nil)
    }
}
