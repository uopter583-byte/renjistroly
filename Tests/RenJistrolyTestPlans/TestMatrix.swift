import XCTest

// MARK: - 测试矩阵定义
//
// 6 个测试类别：单元、集成、UI 自动化、人机交互、安全红队、长稳
// 每个条目记录文件数、场景数、运行时间、自动化程度、运行频率、覆盖率缺口
//
// 所有测试标记为手动运行 — 用于生成报告而非验证逻辑

// MARK: - Automation Level

public enum TestAutomationLevel: String, Sendable, CaseIterable {
    case fullyAutomated = "全自动"
    case semiAutomated = "半自动"
    case manual = "手动"
}

// MARK: - Test Category

public enum TestCategory: String, Sendable, CaseIterable, Identifiable {
    case unit = "单元测试"
    case integration = "集成测试"
    case uiAutomation = "UI 自动化测试"
    case humanInLoop = "人机交互测试"
    case securityRedTeam = "安全红队测试"
    case longevityStability = "长稳测试"

    public var id: String { rawValue }
}

// MARK: - Run Frequency

public enum RunFrequency: String, Sendable, CaseIterable {
    case everyCommit = "每次提交"
    case daily = "每日"
    case weekly = "每周"
    case everyRelease = "每次发布"
}

// MARK: - Test Entry

public struct TestEntry: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: TestCategory
    public let priority: Int // P0=0, P1=1, P2=2
    public let files: [String]
    public let scenarioCount: Int
    public let expectedDuration: TimeInterval // seconds
    public let automationLevel: TestAutomationLevel
    public let runFrequency: RunFrequency
}

// MARK: - Coverage Gap

public struct CoverageGap: Identifiable, Sendable {
    public let id: String
    public let area: String
    public let description: String
    public let riskLevel: String // High/Medium/Low
    public let suggestedAction: String
}

// MARK: - Test Matrix

public struct TestMatrix: Sendable {
    public let categories: [TestCategory]
    public let entries: [TestEntry]
    public let coverageGaps: [CoverageGap]
    public let totalAutomationRate: Double
    public let priorityDistribution: [Int: Int]

    public static let current: TestMatrix = {
        let entries = Self.defaultEntries
        return TestMatrix(
            categories: TestCategory.allCases,
            entries: entries,
            coverageGaps: Self.defaultCoverageGaps,
            totalAutomationRate: 0.72,
            priorityDistribution: Self.priorityDistribution(for: entries)
        )
    }()

    private static func priorityDistribution(for entries: [TestEntry]) -> [Int: Int] {
        entries.reduce(into: [:]) { distribution, entry in
            distribution[entry.priority, default: 0] += entry.scenarioCount
        }
    }

    public static func report() -> String {
        let m = current
        var lines: [String] = [
            "============================================",
            "  RenJistroly 测试矩阵",
            "============================================",
            "",
            "总测试场景数: \(m.entries.reduce(0) { $0 + $1.scenarioCount })",
            "自动化率: \(Int(m.totalAutomationRate * 100))%",
            "",
            "--- 优先级分布 ---",
            "P0 (必须通过): \(m.priorityDistribution[0] ?? 0) 测试",
            "P1 (高优先级): \(m.priorityDistribution[1] ?? 0) 测试",
            "P2 (一般): \(m.priorityDistribution[2] ?? 0) 测试",
            "",
            "--- 覆盖率缺口 ---",
        ]
        for gap in m.coverageGaps {
            lines.append("  [\(gap.riskLevel)] \(gap.area): \(gap.description)")
            lines.append("    建议: \(gap.suggestedAction)")
        }
        lines.append("")
        lines.append("--- 测试类别详情 ---")
        for category in m.categories {
            let catEntries = m.entries.filter { $0.category == category }
            let totalScenarios = catEntries.reduce(0) { $0 + $1.scenarioCount }
            let autoCount = catEntries.filter { $0.automationLevel == .fullyAutomated }.count
            lines.append("")
            lines.append("  \(category.rawValue): \(catEntries.count) 文件组, \(totalScenarios) 场景, \(autoCount) 全自动")
            for entry in catEntries {
                lines.append("    P\(entry.priority) \(entry.name) [\(entry.automationLevel.rawValue)] [\(entry.runFrequency.rawValue)] - \(entry.scenarioCount) 场景, \(Int(entry.expectedDuration))s")
                for file in entry.files {
                    lines.append("      - \(file)")
                }
            }
        }
        lines.append("")
        lines.append("============================================")
        return lines.joined(separator: "\n")
    }

    private static var defaultEntries: [TestEntry] {
        [
            // MARK: 单元测试
            TestEntry(
                id: "unit-models",
                name: "Models 单元测试",
                category: .unit,
                priority: 0,
                files: ["Tests/RenJistrolyModelsTests/*.swift"],
                scenarioCount: 35,
                expectedDuration: 8,
                automationLevel: .fullyAutomated,
                runFrequency: .everyCommit
            ),
            TestEntry(
                id: "unit-systembridge",
                name: "SystemBridge 单元测试",
                category: .unit,
                priority: 0,
                files: ["Tests/RenJistrolySystemBridgeTests/*.swift"],
                scenarioCount: 40,
                expectedDuration: 12,
                automationLevel: .fullyAutomated,
                runFrequency: .everyCommit
            ),
            TestEntry(
                id: "unit-capability",
                name: "Capability 单元测试",
                category: .unit,
                priority: 1,
                files: ["Tests/RenJistrolyCapabilityTests/*.swift"],
                scenarioCount: 50,
                expectedDuration: 15,
                automationLevel: .fullyAutomated,
                runFrequency: .everyCommit
            ),
            TestEntry(
                id: "unit-intelligence",
                name: "Intelligence 单元测试",
                category: .unit,
                priority: 1,
                files: ["Tests/RenJistrolyIntelligenceTests/*.swift"],
                scenarioCount: 45,
                expectedDuration: 20,
                automationLevel: .fullyAutomated,
                runFrequency: .daily
            ),
            TestEntry(
                id: "unit-conversation",
                name: "Conversation 单元测试",
                category: .unit,
                priority: 1,
                files: ["Tests/RenJistrolyConversationTests/*.swift"],
                scenarioCount: 30,
                expectedDuration: 15,
                automationLevel: .fullyAutomated,
                runFrequency: .daily
            ),

            // MARK: 集成测试
            TestEntry(
                id: "int-regression",
                name: "回归测试套件 (P0)",
                category: .integration,
                priority: 0,
                files: ["Tests/RegressionTests/RegressionTestSuite.swift"],
                scenarioCount: 24,
                expectedDuration: 30,
                automationLevel: .semiAutomated,
                runFrequency: .everyCommit
            ),
            TestEntry(
                id: "int-core-capability",
                name: "核心能力回归测试",
                category: .integration,
                priority: 0,
                files: ["Tests/RegressionTests/CoreCapabilityRegressionTests.swift"],
                scenarioCount: 30,
                expectedDuration: 40,
                automationLevel: .semiAutomated,
                runFrequency: .everyCommit
            ),
            TestEntry(
                id: "int-cross-module",
                name: "跨模块回归测试",
                category: .integration,
                priority: 1,
                files: ["Tests/RegressionTests/CrossModuleRegressionTests.swift"],
                scenarioCount: 15,
                expectedDuration: 25,
                automationLevel: .semiAutomated,
                runFrequency: .daily
            ),
            TestEntry(
                id: "int-upgrade",
                name: "升级兼容性测试",
                category: .integration,
                priority: 1,
                files: ["Tests/RenJistrolyTestPlans/UpgradeMigrationTests.swift"],
                scenarioCount: 18,
                expectedDuration: 20,
                automationLevel: .fullyAutomated,
                runFrequency: .everyRelease
            ),

            // MARK: UI 自动化测试
            TestEntry(
                id: "ui-state",
                name: "UI 状态机测试",
                category: .uiAutomation,
                priority: 0,
                files: ["Tests/RenJistrolyModelsTests/AppStateTests.swift"],
                scenarioCount: 8,
                expectedDuration: 5,
                automationLevel: .fullyAutomated,
                runFrequency: .everyCommit
            ),
            TestEntry(
                id: "ui-modes",
                name: "模式切换 UI 测试",
                category: .uiAutomation,
                priority: 1,
                files: ["Tests/RegressionTests/CoreCapabilityRegressionTests.swift"],
                scenarioCount: 6,
                expectedDuration: 30,
                automationLevel: .semiAutomated,
                runFrequency: .daily
            ),
            TestEntry(
                id: "ui-elements",
                name: "元素交互全覆盖",
                category: .uiAutomation,
                priority: 2,
                files: ["Tests/RenJistrolySystemBridgeTests/AppDriversTests.swift"],
                scenarioCount: 10,
                expectedDuration: 45,
                automationLevel: .manual,
                runFrequency: .weekly
            ),

            // MARK: 人机交互测试
            TestEntry(
                id: "hci-permissions",
                name: "权限获取流程测试",
                category: .humanInLoop,
                priority: 1,
                files: ["Tests/RenJistrolySystemBridgeTests/PermissionCenterTests.swift"],
                scenarioCount: 6,
                expectedDuration: 60,
                automationLevel: .manual,
                runFrequency: .weekly
            ),
            TestEntry(
                id: "hci-confirmation",
                name: "高风险操作确认流程",
                category: .humanInLoop,
                priority: 1,
                files: ["Tests/RegressionTests/CrossModuleRegressionTests.swift"],
                scenarioCount: 4,
                expectedDuration: 45,
                automationLevel: .manual,
                runFrequency: .weekly
            ),
            TestEntry(
                id: "hci-voice",
                name: "语音交互测试",
                category: .humanInLoop,
                priority: 2,
                files: ["Tests/RenJistrolyModelsTests/VoiceInputModeTests.swift"],
                scenarioCount: 5,
                expectedDuration: 120,
                automationLevel: .manual,
                runFrequency: .everyRelease
            ),

            // MARK: 安全红队测试
            TestEntry(
                id: "sec-mcp-safety",
                name: "MCP 工具安全审计",
                category: .securityRedTeam,
                priority: 1,
                files: ["Tests/RenJistrolyCapabilityTests/MCPClientSafetyTests.swift",
                        "Tests/RenJistrolyCapabilityTests/ToolSafetyGatewayTests.swift"],
                scenarioCount: 12,
                expectedDuration: 30,
                automationLevel: .fullyAutomated,
                runFrequency: .daily
            ),
            TestEntry(
                id: "sec-policy",
                name: "策略层安全性测试",
                category: .securityRedTeam,
                priority: 1,
                files: ["Tests/RegressionTests/CrossModuleRegressionTests.swift"],
                scenarioCount: 6,
                expectedDuration: 20,
                automationLevel: .semiAutomated,
                runFrequency: .daily
            ),
            TestEntry(
                id: "sec-readonly",
                name: "只读模式强制测试",
                category: .securityRedTeam,
                priority: 1,
                files: ["Tests/RegressionTests/CoreCapabilityRegressionTests.swift"],
                scenarioCount: 8,
                expectedDuration: 15,
                automationLevel: .fullyAutomated,
                runFrequency: .everyCommit
            ),
            TestEntry(
                id: "sec-mouseguard",
                name: "MouseGuard 防抢鼠标测试",
                category: .securityRedTeam,
                priority: 2,
                files: ["Tests/RegressionTests/CrossModuleRegressionTests.swift"],
                scenarioCount: 4,
                expectedDuration: 10,
                automationLevel: .fullyAutomated,
                runFrequency: .daily
            ),

            // MARK: 长稳测试
            TestEntry(
                id: "long-action-engine",
                name: "ActionEngine 长时间运行",
                category: .longevityStability,
                priority: 2,
                files: ["Tests/RegressionTests/CoreCapabilityRegressionTests.swift"],
                scenarioCount: 3,
                expectedDuration: 300,
                automationLevel: .fullyAutomated,
                runFrequency: .everyRelease
            ),
            TestEntry(
                id: "long-mode-manager",
                name: "ModeManager 反复切换",
                category: .longevityStability,
                priority: 2,
                files: ["Tests/RegressionTests/CoreCapabilityRegressionTests.swift"],
                scenarioCount: 2,
                expectedDuration: 120,
                automationLevel: .fullyAutomated,
                runFrequency: .everyRelease
            ),
            TestEntry(
                id: "long-context",
                name: "ContextManager 持续刷新",
                category: .longevityStability,
                priority: 2,
                files: ["Tests/RegressionTests/CrossModuleRegressionTests.swift"],
                scenarioCount: 2,
                expectedDuration: 180,
                automationLevel: .fullyAutomated,
                runFrequency: .everyRelease
            ),
        ]
    }

    private static var defaultCoverageGaps: [CoverageGap] {
        [
            CoverageGap(
                id: "gap-screen-capture",
                area: "屏幕捕获",
                description: "ScreenCaptureKit 实际捕获与 OCR 集成缺少自动化测试",
                riskLevel: "High",
                suggestedAction: "添加使用 ScreenCaptureKit 的集成测试（需要屏幕录制权限）"
            ),
            CoverageGap(
                id: "gap-ax-api",
                area: "AX API 桥接",
                description: "AccessibilityBridge 的实际 AX API 调用缺少测试",
                riskLevel: "High",
                suggestedAction: "添加基于真实应用的 AX 元素遍历测试"
            ),
            CoverageGap(
                id: "gap-network-error",
                area: "网络错误恢复",
                description: "LLM 请求超时、重试、降级路径缺少测试",
                riskLevel: "Medium",
                suggestedAction: "添加网络 mock 测试覆盖超时/429/500 场景"
            ),
            CoverageGap(
                id: "gap-concurrent",
                area: "并发安全",
                description: "ActionEngine/ModeManager 多线程竞争条件缺少测试",
                riskLevel: "Medium",
                suggestedAction: "添加并发压力测试（多线程同时调用）"
            ),
            CoverageGap(
                id: "gap-voice",
                area: "语音输入",
                description: "SFSpeechRecognizer 实际录音测试缺失",
                riskLevel: "Medium",
                suggestedAction: "添加使用模拟音频文件的语音识别测试"
            ),
            CoverageGap(
                id: "gap-file-ops",
                area: "文件操作",
                description: "FileOperationSafety 的实际文件读/写/删除缺少测试",
                riskLevel: "Low",
                suggestedAction: "添加临时目录中的文件操作测试"
            ),
            CoverageGap(
                id: "gap-xpc",
                area: "XPC 通信",
                description: "RenJistrolyHelper 的 XPC 桥接缺少测试",
                riskLevel: "Medium",
                suggestedAction: "添加 XPC 服务 mock 测试"
            ),
            CoverageGap(
                id: "gap-update",
                area: "自动更新",
                description: "UpdateManager 的更新流程缺少端到端测试",
                riskLevel: "Low",
                suggestedAction: "添加更新检查 mock 测试"
            ),
        ]
    }
}

// MARK: - XCTest: 手动运行的报告生成测试

final class TestMatrixManualTests: XCTestCase {
    override func setUpWithError() throws {
        guard ProcessInfo.processInfo.environment["RUN_MANUAL_TESTS"] == "1" else {
            throw XCTSkip("手动运行 — 不在 CI 中自动执行。设置环境变量 RUN_MANUAL_TESTS=1 启用")
        }
    }

    func testMatrixReportGenerated() {
        let report = TestMatrix.report()
        XCTAssertTrue(report.contains("测试矩阵"), "报告应以测试矩阵标题开头")
        XCTAssertTrue(report.contains("自动化率"), "报告应包含自动化率")
        XCTAssertTrue(report.contains("覆盖率缺口"), "报告应包含覆盖率缺口")
        XCTAssertTrue(report.contains("单元测试"), "报告应包含单元测试类别")
        XCTAssertTrue(report.contains("集成测试"), "报告应包含集成测试类别")
        XCTAssertTrue(report.contains("P0"), "报告应包含 P0 优先级")
    }

    func testMatrixAllCategoriesPopulated() {
        for cat in TestCategory.allCases {
            let count = TestMatrix.current.entries.filter { $0.category == cat }.count
            XCTAssertGreaterThan(count, 0, "类别 \(cat.rawValue) 应至少有一个测试条目")
        }
    }

    func testMatrixAutomationRateInRange() {
        let rate = TestMatrix.current.totalAutomationRate
        XCTAssertGreaterThanOrEqual(rate, 0)
        XCTAssertLessThanOrEqual(rate, 1)
    }

    func testMatrixPriorityDistributionMatches() {
        let pCounts = TestMatrix.current.priorityDistribution
        let total = pCounts.values.reduce(0, +)
        let scenarioTotal = TestMatrix.current.entries.reduce(0) { $0 + $1.scenarioCount }
        XCTAssertEqual(total, scenarioTotal,
                       "优先级分布总和应等于测试场景总数")
    }

    func testMatrixCoverageGapsUnique() {
        let gaps = TestMatrix.current.coverageGaps
        let gapIDs = Set(gaps.map(\.id))
        XCTAssertEqual(gapIDs.count, gaps.count, "覆盖率缺口 ID 应唯一")
    }

    func testMatrixNoGapWithoutSuggestedAction() {
        for gap in TestMatrix.current.coverageGaps {
            XCTAssertFalse(gap.suggestedAction.isEmpty,
                           "缺口 \(gap.id) 应有建议动作")
        }
    }

    func testMatrixAllEntryIDsUnique() {
        let entries = TestMatrix.current.entries
        let entryIDs = Set(entries.map(\.id))
        XCTAssertEqual(entryIDs.count, entries.count, "测试条目 ID 应唯一")
    }

    func testMatrixExpectedDurationsPositive() {
        for entry in TestMatrix.current.entries {
            XCTAssertGreaterThan(entry.expectedDuration, 0,
                                 "\(entry.id) 的预期运行时间应大于 0")
        }
    }

    func testMatrixScenarioCountsPositive() {
        for entry in TestMatrix.current.entries {
            XCTAssertGreaterThan(entry.scenarioCount, 0,
                                 "\(entry.id) 的场景数应大于 0")
        }
    }
}

// MARK: - 无跳过条件的手动测试（信息性）

final class TestMatrixInfoTests: XCTestCase {
    /// 打印当前测试矩阵报告到控制台（始终运行，仅输出信息）
    func testPrintMatrixReport() {
        print("\n" + TestMatrix.report() + "\n")
    }
}
