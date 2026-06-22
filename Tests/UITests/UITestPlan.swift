import Foundation
import XCTest
@testable import RenJistrolyModels
@testable import RenJistrolySystemBridge
@testable import RenJistrolyCapability

// MARK: - UI 自动化测试骨架

/// 定义测试场景的结构和行为。
/// 所有 UI 测试应遵循此框架以确保一致的测试生命周期。
final class UITestPlan: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - 场景结构定义

    /// 测试场景：单个可执行的测试案例
    struct TestScenario: Identifiable {
        let id: String
        let name: String
        let description: String
        let prerequisite: [String]            // 前置条件描述
        let steps: [TestStep]
        let expectedOutcome: String
        let tags: [ScenarioTag]

        var hasCriticalTag: Bool { tags.contains(.critical) }
        var hasSmokeTag: Bool { tags.contains(.smoke) }
    }

    /// 测试步骤
    struct TestStep: Identifiable {
        let id: UUID
        let action: String                    // 操作描述
        let expected: String                  // 预期结果
        let timeout: TimeInterval

        init(action: String, expected: String, timeout: TimeInterval = 5.0) {
            self.id = UUID()
            self.action = action
            self.expected = expected
            self.timeout = timeout
        }
    }

    /// 场景标签
    enum ScenarioTag: String, CaseIterable {
        case smoke        // 冒烟测试
        case critical     // 关键路径
        case regression   // 回归覆盖
        case edgeCase     // 边界情况
        case accessibility // 无障碍
        case performance  // 性能
    }

    // MARK: - 预定义测试场景

    /// 冒烟场景集合：覆盖最核心的用户流程
    static let smokeScenarios: [TestScenario] = [
        TestScenario(
            id: "SMOKE-01",
            name: "前台应用检测",
            description: "验证能正确获取前台正在运行的应用信息",
            prerequisite: ["至少有一个应用在前台运行", "辅助功能权限已授予"],
            steps: [
                TestStep(action: "调用 getFocusedAppBundleID()", expected: "返回非空 bundleID"),
                TestStep(action: "确认返回值与 NSWorkspace.shared.frontmostApplication 一致", expected: "信息匹配"),
            ],
            expectedOutcome: "正确获取前台应用信息",
            tags: [.smoke, .critical]
        ),
        TestScenario(
            id: "SMOKE-02",
            name: "屏幕状态读取",
            description: "验证能正确读取当前屏幕状态，包括窗口列表",
            prerequisite: ["屏幕录制权限已授予", "至少有一个窗口可见"],
            steps: [
                TestStep(action: "调用 captureCurrentScreen(includeImageData: false)", expected: "返回有效的 ScreenContext"),
                TestStep(action: "检查 displayDescription 非空", expected: "包含屏幕描述信息"),
                TestStep(action: "检查 visibleWindows 非空", expected: "至少返回一个窗口"),
            ],
            expectedOutcome: "屏幕上下文正确读取",
            tags: [.smoke, .critical]
        ),
        TestScenario(
            id: "SMOKE-03",
            name: "键盘输入基础操作",
            description: "验证键盘按下和文字输入能正确执行",
            prerequisite: ["辅助功能权限已授予", "有一个可输入的焦点控件"],
            steps: [
                TestStep(action: "按下 Return 键", expected: "无异常抛出"),
                TestStep(action: "输入一段文字", expected: "文字正确输入到焦点控件"),
            ],
            expectedOutcome: "键盘操作正常执行",
            tags: [.smoke]
        ),
    ]

    /// 回归场景集合
    static let regressionScenarios: [TestScenario] = [
        TestScenario(
            id: "REGR-01",
            name: "多窗口环境窗口列表正确性",
            description: "在多窗口下验证窗口列表返回完整且不重复",
            prerequisite: ["至少 3 个窗口可见"],
            steps: [
                TestStep(action: "调用 getWindowList()", expected: "返回至少 3 个窗口"),
                TestStep(action: "检查窗口标题去重后数量", expected: "数量一致，无重复"),
            ],
            expectedOutcome: "窗口列表正确无重复",
            tags: [.regression]
        ),
        TestScenario(
            id: "REGR-02",
            name: "连续快速点击不崩溃",
            description: "在短时间内连续执行多次点击操作，验证稳定性",
            prerequisite: ["辅助功能权限已授予"],
            steps: [
                TestStep(action: "在 1 秒内连续点击 20 次", expected: "所有点击正常返回"),
                TestStep(action: "检查系统无异常对话框", expected: "系统状态正常"),
            ],
            expectedOutcome: "系统稳定运行，无崩溃",
            tags: [.regression, .edgeCase]
        ),
    ]

    // MARK: - 生命周期辅助方法

    /// 执行一个场景的所有步骤，验证是否通过
    func executeScenario(_ scenario: TestScenario, timeout: TimeInterval = 30.0) async -> ScenarioResult {
        var stepResults: [StepResult] = []

        for step in scenario.steps {
            let start = Date()
            let passed = await executeStep(step)
            let duration = Date().timeIntervalSince(start)

            stepResults.append(StepResult(
                stepID: step.id,
                passed: passed,
                duration: duration,
                error: passed ? nil : "步骤 '\(step.action)' 未通过"
            ))
        }

        return ScenarioResult(
            scenarioID: scenario.id,
            passed: stepResults.allSatisfy(\.passed),
            stepResults: stepResults,
            duration: DateInterval(start: Date(), duration: 0)
        )
    }

    private func executeStep(_ step: TestStep) async -> Bool {
        // 基类提供默认的空实现。
        // 子类应 override 实际的执行逻辑。
        true
    }
}

// MARK: - 结果类型

struct ScenarioResult {
    let scenarioID: String
    let passed: Bool
    let stepResults: [StepResult]
    let duration: DateInterval
}

struct StepResult {
    let stepID: UUID
    let passed: Bool
    let duration: TimeInterval
    let error: String?
}

// MARK: - 辅助函数

extension XCTestCase {
    /// 等待条件满足，超时则失败
    func waitUntil(
        _ condition: @autoclosure () -> Bool,
        timeout: TimeInterval = 5.0,
        polling: TimeInterval = 0.1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            let runLoop = RunLoop.current
            runLoop.run(until: Date().addingTimeInterval(polling))
        }
        XCTFail("条件未在 \(timeout)s 内满足", file: file, line: line)
    }

    /// 异步等待
    func waitAsync(
        _ expectation: @escaping () async -> Bool,
        timeout: TimeInterval = 5.0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await expectation() { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("异步条件未在 \(timeout)s 内满足", file: file, line: line)
    }
}

// MARK: - 集成测试：验证场景结构框架

final class UITestPlanStructureTests: XCTestCase {

    // MARK: - 冒烟场景结构验证

    func testSmokeScenariosExist() {
        XCTAssertFalse(UITestPlan.smokeScenarios.isEmpty, "应该有至少一个冒烟场景")
        for scenario in UITestPlan.smokeScenarios {
            XCTAssertFalse(scenario.name.isEmpty, "场景名不能为空")
            XCTAssertFalse(scenario.steps.isEmpty, "场景至少需要一个步骤")
            XCTAssertTrue(scenario.hasSmokeTag, "冒烟场景需包含 .smoke tag")
        }
    }

    func testRegressionScenariosExist() {
        XCTAssertFalse(UITestPlan.regressionScenarios.isEmpty, "应该有至少一个回归场景")
        for scenario in UITestPlan.regressionScenarios {
            XCTAssertTrue(scenario.hasRegressionTag(scenario.tags), "回归场景需包含 .regression tag")
        }
    }

    func testScenarioIDsAreUnique() {
        let all = UITestPlan.smokeScenarios + UITestPlan.regressionScenarios
        let ids = all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "场景 ID 必须唯一")
    }

    private func hasScenario(_ id: String, in scenarios: [UITestPlan.TestScenario]) -> Bool {
        scenarios.contains { $0.id == id }
    }
}

private extension UITestPlan.TestScenario {
    func hasRegressionTag(_ tags: [UITestPlan.ScenarioTag]) -> Bool {
        tags.contains(.regression)
    }
}
