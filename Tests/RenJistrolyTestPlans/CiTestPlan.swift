import XCTest

// MARK: - CI 测试计划
//
// 三个 CI 阶段：
//  1. 快速检查（<2 分钟）— 每次 push
//  2. 标准检查（<10 分钟）— PR 打开/更新
//  3. 完整检查（<30 分钟）— PR 合并前/发布前
//
// 每阶段定义包含的测试、失败策略、并行化建议
//
// 所有测试标记为手动运行 — 用于生成报告

// MARK: - CI Stage

public enum CIStage: String, Sendable, CaseIterable, Identifiable {
    case quick = "快速检查"
    case standard = "标准检查"
    case full = "完整检查"

    public var id: String { rawValue }

    /// 预期最长执行时间（秒）
    public var maxDuration: TimeInterval {
        switch self {
        case .quick: 120
        case .standard: 600
        case .full: 1800
        }
    }

    /// 触发条件
    public var triggerDescription: String {
        switch self {
        case .quick: "每次 git push"
        case .standard: "PR 打开/更新"
        case .full: "PR 准备合并 / 发布前"
        }
    }

    /// 失败处理策略
    public var failureStrategy: String {
        switch self {
        case .quick: "阻止提交 — 必须修复"
        case .standard: "阻止合并 — 需要人工审核"
        case .full: "警告 — 允许合并但记录"
        }
    }
}

// MARK: - CI Job

public struct CIJob: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let stage: CIStage
    public let testTargets: [String]
    public let testFilters: [String] // --filter patterns
    public let estimatedDuration: TimeInterval
    public let parallelize: Bool
    public let required: Bool // failure blocks the stage
}

// MARK: - CI Plan

public struct CITestPlan: Sendable {
    public let version: String
    public let stages: [CIStage: [CIJob]]
    public let parallelism: Int // max parallel jobs
    public let timeoutPerStage: [CIStage: TimeInterval]


    public static let current = CITestPlan(
        version: "1.0.0",
        stages: Self.defaultStages,
        parallelism: 4,
        timeoutPerStage: [
            .quick: 180,
            .standard: 900,
            .full: 2700,
        ]
    )

    public static func summary() -> String {
        let plan = current
        var lines: [String] = [
            "============================================",
            "  RenJistroly CI 测试计划 v\(plan.version)",
            "============================================",
            "  并行数: \(plan.parallelism)",
            "",
            "--- 阶段概览 ---",
        ]

        for stage in CIStage.allCases {
            let jobs = plan.stages[stage] ?? []
            let totalDuration = jobs.reduce(0) { $0 + $1.estimatedDuration }
            let optimalDuration = plan.parallelism > 1 && !jobs.isEmpty
                ? totalDuration / Double(min(plan.parallelism, jobs.count))
                : totalDuration

            lines.append("")
            lines.append("  [\(stage.rawValue)]")
            lines.append("    触发: \(stage.triggerDescription)")
            lines.append("    超时: \(Int(plan.timeoutPerStage[stage] ?? 0))s")
            lines.append("    作业: \(jobs.count)")
            lines.append("    预计总耗时: \(Int(totalDuration))s (并行优化 ~\(Int(optimalDuration))s)")
            lines.append("    失败策略: \(stage.failureStrategy)")
            lines.append("")

            for job in jobs {
                let req = job.required ? "[必需]" : "[可选]"
                let par = job.parallelize ? "[并行]" : "[串行]"
                let filters = job.testFilters.isEmpty ? "全部" : job.testFilters.joined(separator: ", ")
                lines.append("    \(req)\(par) \(job.name) (~\(Int(job.estimatedDuration))s)")
                lines.append("      过滤器: \(filters)")
            }
        }

        lines.append("")
        lines.append("--- 并行化建议 ---")
        lines.append("  swift test --parallel --num-workers \(plan.parallelism)")
        lines.append("  使用 --filter 按阶段选择测试")
        lines.append("  P0 测试应加入快速检查阶段")
        lines.append("  P1 测试应加入标准检查阶段")
        lines.append("  P2/长稳测试应加入完整检查阶段")
        lines.append("")

        lines.append("--- 运行命令 ---")
        lines.append("  # 快速检查 (<2min)")
        lines.append("  swift test --filter 'p0_|core_|sec_readonly|testMatrix'")
        lines.append("")
        lines.append("  # 标准检查 (<10min)")
        lines.append("  swift test --filter 'p1_|upgrade_|cross_'")
        lines.append("")
        lines.append("  # 完整检查 (<30min)")
        lines.append("  swift test --filter 'p2_|long_|testMatrix'")
        lines.append("")
        lines.append("============================================")

        return lines.joined(separator: "\n")
    }

    private static var defaultStages: [CIStage: [CIJob]] {
        [
            // MARK: 快速检查 (<2min)
            .quick: [
                CIJob(
                    id: "quick-models",
                    name: "Models 单元测试",
                    stage: .quick,
                    testTargets: ["RenJistrolyModelsTests"],
                    testFilters: [],
                    estimatedDuration: 8,
                    parallelize: true,
                    required: true
                ),
                CIJob(
                    id: "quick-system-bridge",
                    name: "SystemBridge 基础测试",
                    stage: .quick,
                    testTargets: ["RenJistrolySystemBridgeTests"],
                    testFilters: [],
                    estimatedDuration: 12,
                    parallelize: true,
                    required: true
                ),
                CIJob(
                    id: "quick-regression-p0",
                    name: "回归测试 P0",
                    stage: .quick,
                    testTargets: ["RegressionTests"],
                    testFilters: ["p0_", "core_", "cross_mode", "testMatrix"],
                    estimatedDuration: 30,
                    parallelize: false,
                    required: true
                ),
                CIJob(
                    id: "quick-security-basics",
                    name: "安全基础测试",
                    stage: .quick,
                    testTargets: ["RenJistrolyCapabilityTests"],
                    testFilters: ["testReadOnly", "testSafety", "testPermission"],
                    estimatedDuration: 15,
                    parallelize: true,
                    required: true
                ),
            ],

            // MARK: 标准检查 (<10min)
            .standard: [
                CIJob(
                    id: "std-capability",
                    name: "Capability 全套测试",
                    stage: .standard,
                    testTargets: ["RenJistrolyCapabilityTests"],
                    testFilters: [],
                    estimatedDuration: 30,
                    parallelize: true,
                    required: true
                ),
                CIJob(
                    id: "std-regression-p1",
                    name: "回归测试 P1",
                    stage: .standard,
                    testTargets: ["RegressionTests"],
                    testFilters: ["p1_", "upgrade_", "cross_"],
                    estimatedDuration: 60,
                    parallelize: false,
                    required: true
                ),
                CIJob(
                    id: "std-cross-module",
                    name: "跨模块集成测试",
                    stage: .standard,
                    testTargets: ["RegressionTests"],
                    testFilters: ["cross_"],
                    estimatedDuration: 45,
                    parallelize: false,
                    required: true
                ),
                CIJob(
                    id: "std-security",
                    name: "安全红队扫描",
                    stage: .standard,
                    testTargets: ["RenJistrolyCapabilityTests"],
                    testFilters: ["testSafety", "testSecurity", "testPolicy"],
                    estimatedDuration: 30,
                    parallelize: true,
                    required: false
                ),
                CIJob(
                    id: "std-intelligence",
                    name: "Intelligence 测试",
                    stage: .standard,
                    testTargets: ["RenJistrolyIntelligenceTests"],
                    testFilters: [],
                    estimatedDuration: 60,
                    parallelize: true,
                    required: true
                ),
                CIJob(
                    id: "std-conversation",
                    name: "Conversation 测试",
                    stage: .standard,
                    testTargets: ["RenJistrolyConversationTests"],
                    testFilters: [],
                    estimatedDuration: 45,
                    parallelize: true,
                    required: true
                ),
            ],

            // MARK: 完整检查 (<30min)
            .full: [
                CIJob(
                    id: "full-regression-p2",
                    name: "回归测试 P2 + 边界条件",
                    stage: .full,
                    testTargets: ["RegressionTests"],
                    testFilters: ["p2_"],
                    estimatedDuration: 60,
                    parallelize: false,
                    required: false
                ),
                CIJob(
                    id: "full-upgrade",
                    name: "升级兼容性全套测试",
                    stage: .full,
                    testTargets: ["RenJistrolyTestPlans"],
                    testFilters: ["upgrade_"],
                    estimatedDuration: 30,
                    parallelize: false,
                    required: false
                ),
                CIJob(
                    id: "full-all-unittests",
                    name: "全部单元测试",
                    stage: .full,
                    testTargets: [
                        "RenJistrolyModelsTests",
                        "RenJistrolySystemBridgeTests",
                        "RenJistrolyCapabilityTests",
                        "RenJistrolyIntelligenceTests",
                        "RenJistrolyConversationTests",
                        "RenJistrolyTests",
                    ],
                    testFilters: [],
                    estimatedDuration: 180,
                    parallelize: true,
                    required: true
                ),
                CIJob(
                    id: "full-long-running",
                    name: "长稳测试",
                    stage: .full,
                    testTargets: ["LongRunningTests"],
                    testFilters: ["long_", "stress_"],
                    estimatedDuration: 300,
                    parallelize: false,
                    required: false
                ),
                CIJob(
                    id: "full-integration",
                    name: "端到端集成测试",
                    stage: .full,
                    testTargets: ["IntegrationTests"],
                    testFilters: [],
                    estimatedDuration: 120,
                    parallelize: false,
                    required: false
                ),
            ],
        ]
    }
}

// MARK: - XCTest: 手动运行的 CI 计划验证

final class CiTestPlanManualTests: XCTestCase {
    override func setUpWithError() throws {
        guard ProcessInfo.processInfo.environment["RUN_MANUAL_TESTS"] == "1" else {
            throw XCTSkip("手动运行 — 不在 CI 中自动执行。设置环境变量 RUN_MANUAL_TESTS=1 启用")
        }
    }

    func testCiPlanSummaryGenerated() {
        let summary = CITestPlan.summary()
        XCTAssertTrue(summary.contains("CI 测试计划"), "摘要应以 CI 测试计划标题开头")
        XCTAssertTrue(summary.contains("快速检查"), "摘要应包含快速检查阶段")
        XCTAssertTrue(summary.contains("标准检查"), "摘要应包含标准检查阶段")
        XCTAssertTrue(summary.contains("完整检查"), "摘要应包含完整检查阶段")
        XCTAssertTrue(summary.contains("并行化建议"), "摘要应包含并行化建议")
    }

    func testCiPlanAllStagesHaveConfig() {
        for stage in CIStage.allCases {
            XCTAssertGreaterThan(stage.maxDuration, 0, "每个阶段应有最长执行时间")
            XCTAssertFalse(stage.triggerDescription.isEmpty, "每个阶段应有触发条件")
            XCTAssertFalse(stage.failureStrategy.isEmpty, "每个阶段应有失败策略")
        }
    }

    func testCiPlanQuickStageUnder2Minutes() {
        let plan = CITestPlan.current
        let quickJobs = plan.stages[.quick] ?? []
        let totalDuration = quickJobs.reduce(0) { $0 + $1.estimatedDuration }
        XCTAssertLessThanOrEqual(totalDuration, CIStage.quick.maxDuration,
                                 "快速检查阶段总时长 \(totalDuration)s 超过限制 \(CIStage.quick.maxDuration)s")
    }

    func testCiPlanStandardStageUnder10Minutes() {
        let plan = CITestPlan.current
        let jobs = plan.stages[.standard] ?? []
        let totalDuration = jobs.reduce(0) { $0 + $1.estimatedDuration }
        XCTAssertLessThanOrEqual(totalDuration, CIStage.standard.maxDuration,
                                 "标准检查阶段总时长 \(totalDuration)s 超过限制 \(CIStage.standard.maxDuration)s")
    }

    func testCiPlanFullStageUnder30Minutes() {
        let plan = CITestPlan.current
        let jobs = plan.stages[.full] ?? []
        let totalDuration = jobs.reduce(0) { $0 + $1.estimatedDuration }
        XCTAssertLessThanOrEqual(totalDuration, CIStage.full.maxDuration,
                                 "完整检查阶段总时长 \(totalDuration)s 超过限制 \(CIStage.full.maxDuration)s")
    }

    func testCiPlanRequiredJobsHaveFilters() {
        let plan = CITestPlan.current
        for (stage, jobs) in plan.stages {
            for job in jobs where job.required {
                XCTAssertFalse(job.testTargets.isEmpty,
                               "\(stage.rawValue) 阶段的必需作业 \(job.id) 必须有测试目标")
            }
        }
    }

    func testCiPlanAllJobIDsUnique() {
        let plan = CITestPlan.current
        var allIDs = Set<String>()
        for (_, jobs) in plan.stages {
            for job in jobs {
                XCTAssertFalse(allIDs.contains(job.id),
                               "作业 ID \(job.id) 重复")
                allIDs.insert(job.id)
            }
        }
    }

    func testCiPlanExpectedDurationsPositive() {
        let plan = CITestPlan.current
        for (_, jobs) in plan.stages {
            for job in jobs {
                XCTAssertGreaterThan(job.estimatedDuration, 0,
                                     "\(job.id) 的预期运行时间应大于 0")
            }
        }
    }

    func testCiPlanTimeoutExceedsTotalDuration() {
        let plan = CITestPlan.current
        for stage in CIStage.allCases {
            let jobs = plan.stages[stage] ?? []
            let totalDur = jobs.reduce(0) { $0 + $1.estimatedDuration }
            let timeout = plan.timeoutPerStage[stage] ?? 0
            XCTAssertGreaterThanOrEqual(timeout, totalDur,
                                        "\(stage.rawValue) 的超时 \(timeout)s 应 >= 总耗时 \(totalDur)s")
        }
    }
}

// MARK: - 信息性测试（始终运行）

final class CiTestPlanInfoTests: XCTestCase {
    func testPrintCiPlanSummary() {
        print("\n" + CITestPlan.summary() + "\n")
    }
}
