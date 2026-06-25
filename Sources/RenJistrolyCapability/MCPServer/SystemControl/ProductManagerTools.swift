import Foundation
import AppKit
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - 396 反馈可信度标记

public struct FeedbackCredibilityTool: MCPTool {
    public let definition = ToolDefinition(
        name: "feedback_credibility",
        description: "分析用户反馈的来源可信度。根据反馈来源（用户层级、渠道、频次、可复现性）标注可信度等级，帮助 PM 区分噪音和真实需求。",
        parameters: [
            .init(name: "feedback_text", type: .string, description: "用户反馈原文"),
            .init(name: "source", type: .string, description: "反馈来源: customer(客户), internal(内部), beta(内测), support(客服), social(社交), review(应用商店)", required: false),
            .init(name: "frequency", type: .string, description: "反馈频次: once(单次), multiple(多次), widespread(普遍)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let feedbackText = arguments["feedback_text"] ?? ""
        let source = arguments["source"] ?? "customer"
        let frequency = arguments["frequency"] ?? "once"

        var output = "=== 反馈可信度分析 ===\n\n"

        let sourceCredibility: [String: (level: Int, label: String)] = [
            "customer": (3, "终端客户 — 直接使用者，可信度高"),
            "beta": (4, "内测用户 — 专业反馈，可信度最高"),
            "internal": (4, "内部反馈 — 熟悉产品，可信度高"),
            "support": (3, "客服渠道 — 经过筛选，可信度较高"),
            "social": (1, "社交媒体 — 未经核实，需交叉验证"),
            "review": (2, "应用商店评价 — 公开但碎片化"),
        ]

        let freqWeights: [String: Int] = [
            "once": 1,
            "multiple": 2,
            "widespread": 3,
        ]

        let sourceInfo = sourceCredibility[source] ?? (2, "未知来源")
        let freqWeight = freqWeights[frequency] ?? 1

        let credibilityScore = sourceInfo.0 * freqWeight
        let maxScore = 12

        output += "【来源】\(sourceInfo.label)\n"
        output += "【频次】\(frequency)\n"
        output += "【可信度评分】\(credibilityScore)/\(maxScore)\n\n"

        let level: String
        switch credibilityScore {
        case 0..<4: level = "低 (仅供参考，需进一步验证)"
        case 4..<8: level = "中 (有一定参考价值，建议结合其他来源)"
        default: level = "高 (可信反馈，建议优先处理)"
        }
        output += "【可信度等级】\(level)\n\n"

        if !feedbackText.isEmpty {
            output += "【反馈原文】\(feedbackText.prefix(500))\n\n"

            // 关键词检测
            let keywords: [(pattern: String, label: String)] = [
                ("崩溃|闪退|crash|fatal", "崩溃/严重问题"),
                ("慢|卡|延迟|loading|性能", "性能问题"),
                ("无法|不能|not work|bug", "功能性缺陷"),
                ("建议|希望|如果|wish|request", "功能请求"),
                ("喜欢|好用|不错|great|love|like", "正面反馈"),
                ("UI|难看|丑|设计|不好看|难看", "UI/UX 问题"),
            ]
            var matchedLabels: [String] = []
            for kw in keywords {
                if feedbackText.range(of: kw.pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    matchedLabels.append(kw.label)
                }
            }
            if !matchedLabels.isEmpty {
                output += "【反馈分类】\(matchedLabels.joined(separator: ", "))\n"
            }
        }

        output += "\n【处理建议】\n"
        output += "- 可信度高且多用户反馈 → 优先排入迭代计划\n"
        output += "- 可信度低但描述详细 → 联系用户获取更多信息\n"
        output += "- 高频同类反馈 → 考虑做用户调研确认真实需求\n"
        output += "- 交叉验证: 对比客服记录、使用数据、用户访谈\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 397 PRD 生成模板+边界检查

public struct PRDGeneratorTool: MCPTool {
    public let definition = ToolDefinition(
        name: "prd_generator",
        description: "生成 PRD（产品需求文档）模板并检查边界条件。自动追问需求中的不明确定义、假设、约束和验收标准。",
        parameters: [
            .init(name: "feature_name", type: .string, description: "功能名称"),
            .init(name: "description", type: .string, description: "需求描述", required: false),
            .init(name: "stakeholders", type: .string, description: "干系人列表, 逗号分隔", required: false),
            .init(name: "constraints", type: .string, description: "已知约束条件", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let featureName = arguments["feature_name"] ?? "未命名功能"
        let description = arguments["description"]
        let stakeholders = arguments["stakeholders"]
        let constraints = arguments["constraints"]

        var output = "=== PRD 生成器 ===\n\n"
        output += "功能名称: \(featureName)\n\n"

        // 1. 模板内容
        output += "# \(featureName) — 产品需求文档\n\n"
        output += "## 1. 背景与目标\n"
        output += "- 业务背景: [填写]\n"
        output += "- 用户痛点: [填写]\n"
        output += "- 成功指标: [填写, 如转化率提升 X%, 用户时长增加 Y%]\n"

        output += "\n## 2. 需求描述\n"
        if let desc = description {
            output += "\(desc)\n"
        } else {
            output += "[请描述功能的核心用户流程]\n"
        }

        output += "\n## 3. 用户故事\n"
        output += "- 作为 [角色], 我希望 [功能], 以便 [价值]\n"
        output += "- 作为 [角色], 我希望 [功能], 以便 [价值]\n"

        output += "\n## 4. 验收标准\n"
        output += "- [ ] 核心功能正常运作\n"
        output += "- [ ] 边界情况处理\n"
        output += "- [ ] 错误状态展示\n"
        output += "- [ ] 性能要求满足\n"
        output += "- [ ] 无障碍支持\n"

        output += "\n## 5. 边界条件检查（需补充）\n"
        let boundaryQuestions = [
            "输入为空时系统行为?",
            "网络异常/超时处理?",
            "大量数据同时加载的性能?",
            "多次快速触发操作的防抖?",
            "不同角色/权限的访问控制?",
            "本地化/多语言需求?",
            "与现有功能的交互影响?",
            "数据持久化和同步策略?",
            "系统资源不足时的降级方案?",
            "用户误操作的撤销/确认机制?",
        ]
        for (i, q) in boundaryQuestions.enumerated() {
            output += "  □ \(i+1). \(q)\n"
        }

        output += "\n## 6. 约束\n"
        if let c = constraints {
            output += "- \(c)\n"
        } else {
            output += "- [填写技术/时间/资源约束]\n"
        }

        output += "\n## 7. 干系人\n"
        if let s = stakeholders {
            for name in s.split(separator: ",") {
                output += "- \(name.trimmingCharacters(in: .whitespaces))\n"
            }
        } else {
            output += "- PM: [姓名]\n- 设计师: [姓名]\n- 开发: [姓名]\n- QA: [姓名]\n"
        }

        output += "\n---\n\n"

        // 2. 追问缺失信息
        output += "【系统追问 — 建议补充以下信息】\n"
        if description == nil || (description?.isEmpty ?? true) {
            output += "1. ❌ 缺少需求描述 — 请描述用户使用场景和核心流程\n"
        }
        if stakeholders == nil || (stakeholders?.isEmpty ?? true) {
            output += "2. ⚠️ 缺少干系人 — 建议明确 PM、设计师、开发、QA 负责人\n"
        }
        if constraints == nil || (constraints?.isEmpty ?? true) {
            output += "3. ⚠️ 缺少约束条件 — 技术选型、时间限制、资源分配?\n"
        }

        output += "\n【边界条件检查结果】\n"
        output += "⚠️ 以上 \(boundaryQuestions.count) 个边界条件尚未明确，建议在评审前逐条确认。\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 398 需求拆解粒度控制

public struct RequirementDecomposeTool: MCPTool {
    public let definition = ToolDefinition(
        name: "requirement_decompose",
        description: "将产品需求拆解为可交付的任务，控制拆分粒度。提供需求拆解建议、粒度评估和任务依赖关系分析。",
        parameters: [
            .init(name: "requirement", type: .string, description: "原始需求描述"),
            .init(name: "granularity", type: .string, description: "期望粒度: coarse(粗), medium(中), fine(细), 默认 medium", required: false),
            .init(name: "tech_stack", type: .string, description: "技术栈描述（影响任务拆分）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let requirement = arguments["requirement"] ?? ""
        let granularity = arguments["granularity"] ?? "medium"
        let techStack = arguments["tech_stack"]

        guard !requirement.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: requirement。请输入需要拆解的需求描述。", isError: true)
        }

        var output = "=== 需求拆解 ===\n\n"
        output += "【原始需求】\(requirement)\n"
        output += "【粒度】\(granularity)\n\n"

        // 估算任务数量
        let granularityMultiplier: Int
        let taskSizeDescription: String
        switch granularity {
        case "coarse":
            granularityMultiplier = 2
            taskSizeDescription = "每个任务 2-5 天"
        case "fine":
            granularityMultiplier = 6
            taskSizeDescription = "每个任务 0.25-1 天"
        default:
            granularityMultiplier = 4
            taskSizeDescription = "每个任务 0.5-2 天"
        }

        let baseTaskCount = granularityMultiplier
        output += "预计拆分为 \(baseTaskCount)~\(baseTaskCount + 2) 个任务\n"
        output += "任务粒度: \(taskSizeDescription)\n\n"

        // 通用拆解模板
        output += "【建议任务拆分】\n\n"

        let commonPhases: [(phase: String, tasks: [String])] = [
            ("数据层", [
                "定义数据模型和 Schema",
                "实现数据存储/持久化",
                "实现数据同步逻辑",
            ]),
            ("业务逻辑层", [
                "实现核心业务逻辑",
                "实现错误处理和边界情况",
                "实现状态管理和缓存",
            ]),
            ("UI/交互层", [
                "实现 UI 组件和布局",
                "实现交互和动画",
                "实现无障碍支持",
            ]),
            ("集成与测试", [
                "前后端联调",
                "编写单元测试",
                "编写集成测试",
                "性能测试和优化",
            ]),
        ]

        var taskId = 1
        for phase in commonPhases {
            let taskCount = max(1, phase.tasks.count * granularityMultiplier / 4)
            output += "  📦 \(phase.phase) (\(taskCount) 个任务)\n"
            for task in phase.tasks.prefix(taskCount) {
                output += "    [#\(taskId)] \(task)\n"
                taskId += 1
            }
            output += "\n"
        }

        output += "【依赖关系】\n"
        output += "- 数据层 → 业务逻辑层 → UI 层\n"
        output += "- 测试可以并行于各层开发\n"
        output += "- 建议: 先完成核心路径（Happy Path），再处理边界情况\n"

        if let stack = techStack {
            output += "\n【技术栈注意事项】\n"
            output += "\(stack)\n"
        }

        output += "\n【粒度控制规则】\n"
        output += "- 粗粒度: 每个任务 ≤ 5 天，适合初期规划\n"
        output += "- 中粒度: 每个任务 ≤ 2 天，适合 Sprint 规划\n"
        output += "- 细粒度: 每个任务 ≤ 1 天，适合执行阶段\n"
        output += "- 任何超过 5 天的任务应进一步拆分\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 399 进度追踪

public struct ProgressTrackTool: MCPTool {
    public let definition = ToolDefinition(
        name: "progress_track",
        description: "跟踪项目/功能的实现进度。检查代码提交、文件变更、分支状态和构建状态，综合评估完成度。",
        parameters: [
            .init(name: "feature_path", type: .string, description: "功能相关代码路径或模块名", required: false),
            .init(name: "project_path", type: .string, description: "项目根目录路径", required: false),
            .init(name: "reference", type: .string, description: "对比基准: 主分支名或日期", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let featurePath = arguments["feature_path"]
        let projectPath = arguments["project_path"] ?? FileManager.default.currentDirectoryPath
        let reference = arguments["reference"] ?? "main"

        var output = "=== 进度追踪报告 ===\n\n"
        output += "【项目】\(projectPath)\n"

        // 1. 检查是否 git 仓库
        let gitDir = "\(projectPath)/.git"
        let isGit = FileManager.default.fileExists(atPath: gitDir)

        if isGit {
            // Git 统计
            let shell = ShellExecutor()

            // 总提交数
            let totalCommitsResult = try? await shell.execute("cd \"\(projectPath)\" && git log --oneline \(reference)..HEAD 2>/dev/null | wc -l")
            if let countStr = totalCommitsResult?.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
               !countStr.isEmpty, let count = Int(countStr) {
                output += "\n【Git 统计】\n"
                output += "- 当前分支相对 \(reference) 的提交数: \(count)\n"

                if count > 0 {
                    let logResult = try? await shell.execute("cd \"\(projectPath)\" && git log --oneline --no-decorate \(reference)..HEAD 2>/dev/null | head -10")
                    if let logOut = logResult?.stdout, !logOut.isEmpty {
                        output += "- 最近提交:\n"
                        for line in logOut.split(separator: "\n").prefix(5) {
                            output += "  \(line.trimmingCharacters(in: CharacterSet.whitespaces))\n"
                        }
                    }
                }
            }

            // 分支信息
            let branchResult = try? await shell.execute("cd \"\(projectPath)\" && git branch --show-current 2>/dev/null")
            let branch = branchResult?.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            if !branch.isEmpty {
                output += "- 当前分支: \(branch)\n"
            }

            // 待提交变更
            let statusResult = try? await shell.execute("cd \"\(projectPath)\" && git status --porcelain 2>/dev/null | wc -l")
            if let pendingStr = statusResult?.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
               let pending = Int(pendingStr) {
                if pending > 0 {
                    output += "- 未提交变更: \(pending) 个文件\n"
                    if pending <= 20 {
                        let filesResult = try? await shell.execute("cd \"\(projectPath)\" && git status --short 2>/dev/null")
                        if let filesOut = filesResult?.stdout {
                            for line in filesOut.split(separator: "\n") {
                                output += "  \(line.trimmingCharacters(in: CharacterSet.whitespaces))\n"
                            }
                        }
                    }
                } else {
                    output += "- 工作区干净 ✅\n"
                }
            }
        } else {
            output += "- 未检测到 Git 仓库，无法自动分析代码提交历史\n"
        }

        // 2. 文件级别进度（如果指定了功能路径）
        if let path = featurePath {
            let fullPath = "\(projectPath)/\(path)"
            if FileManager.default.fileExists(atPath: fullPath) {
                let enumerator = FileManager.default.enumerator(atPath: fullPath)
                var fileCount = 0
                var swiftCount = 0
                var testCount = 0
                while let file = enumerator?.nextObject() as? String {
                    fileCount += 1
                    if file.hasSuffix(".swift") { swiftCount += 1 }
                    if file.contains("Test") || file.contains("test") { testCount += 1 }
                }
                output += "\n【代码文件统计 - \(path)】\n"
                output += "- 文件总数: \(fileCount)\n"
                output += "- Swift 文件: \(swiftCount)\n"
                output += "- 测试文件: \(testCount)\n"

                if fileCount > 0 {
                    let testRatio = Double(testCount) / Double(swiftCount > 0 ? swiftCount : 1)
                    if testRatio >= 0.3 {
                        output += "- 测试覆盖率: 良好 ✅ (测试/代码比例 \(String(format: "%.1f", testRatio))\n"
                    } else {
                        output += "- 测试覆盖率: 不足 ⚠️ (测试/代码比例 \(String(format: "%.1f", testRatio))\n"
                    }
                }
            } else {
                output += "\n【代码文件】指定路径不存在: \(fullPath)\n"
            }
        }

        output += "\n【当前前台应用】"
        if let app = NSWorkspace.shared.frontmostApplication {
            output += "\(app.localizedName ?? "未知")"
        } else {
            output += "未知"
        }
        output += "\n"

        // 3. 运行中的应用（开发者工具）
        let devApps = NSWorkspace.shared.runningApplications.filter {
            guard let name = $0.localizedName else { return false }
            return name == "Xcode" || name == "Terminal" || name == "Visual Studio Code" || name == "GitHub Desktop"
        }
        if !devApps.isEmpty {
            output += "\n【运行中的开发者工具】\n"
            for app in devApps {
                output += "- \(app.localizedName ?? "未知")\n"
            }
        }

        output += "\n【进度评估】\n"
        output += "- 以上数据仅供参考，实际进度需要结合 issue/PR 状态\n"
        output += "- 建议配合 Linear/Jira 等项目管理工具使用\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 400 竞品分析模板

public struct CompetitiveAnalysisTool: MCPTool {
    public let definition = ToolDefinition(
        name: "competitive_analysis",
        description: "生成竞品分析报告模板，提供维度分析框架和对比矩阵。辅助 PM 进行竞品调研和分析。",
        parameters: [
            .init(name: "product_name", type: .string, description: "分析目标产品名称"),
            .init(name: "competitors", type: .string, description: "竞品列表，逗号分隔"),
            .init(name: "dimensions", type: .string, description: "分析维度: features(功能), ux(体验), pricing(定价), tech(技术), all(全部), 默认 all", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let productName = arguments["product_name"] ?? "目标产品"
        let competitors = arguments["competencies"] ?? arguments["competitors"] ?? ""
        let dimensions = arguments["dimensions"] ?? "all"

        var output = "=== 竞品分析报告 ===\n\n"
        output += "分析日期: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))\n"
        output += "目标产品: \(productName)\n\n"

        let competitorList = competitors.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        output += "## 分析范围\n"
        let dimensionList: [(key: String, name: String, items: [String])] = [
            ("features", "功能对比", [
                "核心功能完整度",
                "差异化功能",
                "功能深度和成熟度",
            ]),
            ("ux", "用户体验", [
                "首次使用体验 (Time to Value)",
                "交互流程流畅度",
                "视觉设计质量",
                "无障碍支持",
            ]),
            ("pricing", "定价策略", [
                "定价模式 (免费/订阅/买断)",
                "价格区间",
                "免费版功能边界",
            ]),
            ("tech", "技术能力", [
                "性能表现",
                "跨平台支持",
                "API/集成能力",
                "安全与合规",
            ]),
        ]

        let filteredDimensions: [(key: String, name: String, items: [String])]
        if dimensions == "all" {
            filteredDimensions = dimensionList
        } else {
            filteredDimensions = dimensionList.filter { dimensions.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.contains($0.key) }
        }

        for dim in filteredDimensions {
            output += "\n### \(dim.name)\n"
            for item in dim.items {
                output += "- \(item)\n"
            }
        }

        if !competitorList.isEmpty {
            output += "\n## 竞品对比矩阵\n"
            let header = "| 维度 | \(productName) | " + competitorList.joined(separator: " | ") + " |"
            let separator = "|" + String(repeating: " --- |", count: competitorList.count + 2)
            output += header + "\n" + separator + "\n"

            for dim in filteredDimensions {
                let row = "| \(dim.name) | [评分/备注] | " + competitorList.map { _ in "[评分/备注]" }.joined(separator: " | ") + " |"
                output += row + "\n"
            }
        }

        output += "\n## 优势/劣势分析\n"
        output += "### 我们的优势\n"
        output += "- [填写]\n"
        output += "- [填写]\n\n"
        output += "### 我们的劣势\n"
        output += "- [填写]\n"
        output += "- [填写]\n\n"

        output += "## 机会与威胁\n"
        output += "### 机会\n"
        output += "- [市场空白/竞品弱点]\n\n"
        output += "### 威胁\n"
        output += "- [竞品新功能/市场变化]\n\n"

        output += "## 行动建议\n"
        output += "- [短期行动项]\n"
        output += "- [中期行动项]\n"
        output += "- [长期战略]\n"

        if competitorList.isEmpty {
            output += "\n---\n⚠️ 提示: 未指定竞品名称。使用 competitors 参数传入，如 \"competitors=产品A,产品B\"\n"
        }

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 401 会议记录决策提取

public struct MeetingNotesDecisionTool: MCPTool {
    public let definition = ToolDefinition(
        name: "meeting_notes_decision",
        description: "从会议记录中提取决策项、行动项和待确认事项。自动标记决策、责任人(DRI)和截止日期。",
        parameters: [
            .init(name: "notes", type: .string, description: "会议记录原文"),
            .init(name: "mode", type: .string, description: "提取模式: decision(仅决策), action(行动项), full(全部), 默认 full", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let notes = arguments["notes"] ?? ""
        let mode = arguments["mode"] ?? "full"

        guard !notes.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: notes。请输入会议记录原文。", isError: true)
        }

        var output = "=== 会议记录分析 ===\n\n"

        // 提取决策关键词
        let decisionPatterns = ["决定", "确认", "同意", "批准", "方案选择", "定下来", "就用", "采用",
                                "decided", "confirmed", "agreed", "approved", "consensus"]
        let actionPatterns = ["负责", "跟进", "完成", "提交", "调研", "输出", "owner",
                              "responsible", "follow up", "todo", "action item", "will do", "to do"]
        let questionPatterns = ["待确认", "需要确认", "不确定", "后续再议", "需要调研",
                                "TBD", "question", "pending", "undecided"]

        let lines = notes.components(separatedBy: "\n")
        var decisions: [String] = []
        var actions: [String] = []
        var questions: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let lower = trimmed.lowercased()

            let hasDecision = decisionPatterns.contains { lower.contains($0.lowercased()) }
            let hasAction = actionPatterns.contains { lower.contains($0.lowercased()) }
            let hasQuestion = questionPatterns.contains { lower.contains($0.lowercased()) }

            if hasDecision { decisions.append(trimmed) }
            else if hasAction { actions.append(trimmed) }
            else if hasQuestion { questions.append(trimmed) }
        }

        if mode == "full" || mode == "decision" {
            output += "【决策项】\n"
            if decisions.isEmpty {
                output += "  未检测到明确的决策内容\n"
            } else {
                for (i, d) in decisions.enumerated() {
                    output += "  ✅ D\(i+1): \(d)\n"
                }
            }
            output += "\n"
        }

        if mode == "full" || mode == "action" {
            output += "【行动项】\n"
            if actions.isEmpty {
                output += "  未检测到明确的行动项\n"
            } else {
                for (i, a) in actions.enumerated() {
                    output += "  📋 A\(i+1): \(a)\n"
                }
            }
            output += "\n"
        }

        if mode == "full" || mode == "decision" {
            output += "【待确认事项】\n"
            if questions.isEmpty {
                output += "  未检测到待确认事项\n"
            } else {
                for (i, q) in questions.enumerated() {
                    output += "  ❓ Q\(i+1): \(q)\n"
                }
            }
            output += "\n"
        }

        output += "【摘要】\n"
        output += "- 决策: \(decisions.count) 项\n"
        output += "- 行动项: \(actions.count) 项\n"
        output += "- 待确认: \(questions.count) 项\n"

        output += "\n【建议】\n"
        output += "- 将决策项同步到团队知识库\n"
        output += "- 为每个行动项指定 DRI (直接责任人)\n"
        output += "- 为待确认事项设置截止日期\n"
        output += "- 下次会议前回顾所有行动计划\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 402 Roadmap 可信度标记

public struct RoadmapConfidenceTool: MCPTool {
    public let definition = ToolDefinition(
        name: "roadmap_confidence",
        description: "对路线图中的每项计划标注可信度（确定性程度）。区分已确认(Confirmed)、高确信(High)、假设性(Hypothesis)、探索性(Exploratory)等标记。",
        parameters: [
            .init(name: "roadmap_items", type: .string, description: "路线图项目列表，每行一个项目"),
            .init(name: "auto_mark", type: .string, description: "是否自动标注可信度: true/false, 默认 true", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let itemsText = arguments["roadmap_items"] ?? ""
        let autoMark = arguments["auto_mark"] ?? "true"

        guard !itemsText.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: roadmap_items。请输入路线图项目列表。", isError: true)
        }

        var output = "=== Roadmap 可信度标记 ===\n\n"
        output += "标记说明:\n"
        output += "  ✅ Confirmed - 已确认: 资源已到位，已排期\n"
        output += "  🔷 High Confidence - 高确信: 目标明确，需细化方案\n"
        output += "  💡 Hypothesis - 假设性: 有用户需求但未验证\n"
        output += "  🔬 Exploratory - 探索性: 早期调研，方向未定\n"
        output += "  ❌ Blocked - 受阻: 依赖外部条件未满足\n\n"

        let items = itemsText.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        output += "【路线图评估】\n\n"
        for (i, item) in items.enumerated() {
            let trimmed = item.trimmingCharacters(in: .whitespaces)

            if autoMark == "true" {
                let lower = trimmed.lowercased()

                let confirmedKeywords = ["已确认", "已排期", "已启动", "进行中", "Q1", "Q2", "this quarter",
                                         "confirmed", "scheduled", "in progress", "ongoing"]
                let highConfKeywords = ["计划", "目标", "预计", "Q3", "Q4", "next quarter",
                                        "planned", "target", "estimated"]
                let blockedKeywords = ["受阻", "阻塞", "依赖", "等待", "blocked", "dependent", "waiting for",
                                       "pending"]
                let hypothesisKeywords = ["可能", "考虑", "假设", "maybe", "consider", "hypothesis",
                                          "potential"]

                let marker: String
                if blockedKeywords.contains(where: { lower.contains($0) }) {
                    marker = "❌ Blocked"
                } else if confirmedKeywords.contains(where: { lower.contains($0) }) {
                    marker = "✅ Confirmed"
                } else if highConfKeywords.contains(where: { lower.contains($0) }) {
                    marker = "🔷 High Confidence"
                } else if hypothesisKeywords.contains(where: { lower.contains($0) }) {
                    marker = "💡 Hypothesis"
                } else {
                    marker = "🔬 Exploratory"
                }
                output += "\(i+1). [\(marker)] \(trimmed)\n"
            } else {
                output += "\(i+1). [______] \(trimmed)\n"
            }
        }

        output += "\n【分布统计】\n"
        output += "共 \(items.count) 个项目\n"

        output += "\n【风险管理建议】\n"
        output += "- 已确认项目: 优先级最高，确保按时交付\n"
        output += "- 高确信项目: 尽快细化方案，完成 PRD\n"
        output += "- 假设性项目: 安排用户调研/原型验证\n"
        output += "- 探索性项目: 设定调研截止日期，避免无限期拖沓\n"
        output += "- 受阻项目: 明确阻塞原因和解除条件\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 403 收件人确认机制

public struct EmailConfirmRecipientTool: MCPTool {
    public let definition = ToolDefinition(
        name: "email_confirm_recipient",
        description: "发送邮件前确认收件人信息。检查收件人地址格式、验证收件人名称匹配、提醒是否包含敏感收件人。",
        parameters: [
            .init(name: "recipients", type: .string, description: "收件人列表，逗号分隔"),
            .init(name: "cc", type: .string, description: "抄送列表，逗号分隔", required: false),
            .init(name: "bcc", type: .string, description: "密送列表，逗号分隔", required: false),
            .init(name: "subject", type: .string, description: "邮件主题", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let recipients = arguments["recipients"] ?? ""
        let cc = arguments["cc"] ?? ""
        let bcc = arguments["bcc"] ?? ""
        let subject = arguments["subject"]

        guard !recipients.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: recipients。请输入收件人。", isError: true)
        }

        var output = "=== 收件人确认 ===\n\n"

        // 邮箱格式校验
        let emailPattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"

        let allRecipients = recipients.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let ccList = cc.isEmpty ? [] : cc.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let bccList = bcc.isEmpty ? [] : bcc.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        func validateEmails(_ emails: [String], label: String) -> (valid: [String], invalid: [String]) {
            var valid: [String] = []
            var invalid: [String] = []
            for email in emails {
                if email.range(of: emailPattern, options: .regularExpression) != nil {
                    valid.append(email)
                } else {
                    invalid.append(email)
                }
            }
            return (valid, invalid)
        }

        let toValidation = validateEmails(allRecipients, label: "收件人")

        output += "【收件人】\(recipients)\n"
        if !toValidation.invalid.isEmpty {
            output += "❌ 以下收件人地址格式无效:\n"
            for addr in toValidation.invalid {
                output += "  - \(addr)\n"
            }
        } else {
            output += "✅ 所有收件人地址格式正确\n"
        }

        if !cc.isEmpty {
            let ccValidation = validateEmails(ccList, label: "抄送")
            output += "\n【抄送】\(cc)\n"
            if !ccValidation.invalid.isEmpty {
                output += "❌ 以下抄送地址格式无效:\n"
                for addr in ccValidation.invalid {
                    output += "  - \(addr)\n"
                }
            }
        }

        if !bcc.isEmpty {
            let bccValidation = validateEmails(bccList, label: "密送")
            output += "\n【密送】\(bcc)\n"
            output += "⚠️ 注意: 密送收件人不可见\n"
            if !bccValidation.invalid.isEmpty {
                output += "❌ 以下密送地址格式无效:\n"
                for addr in bccValidation.invalid {
                    output += "  - \(addr)\n"
                }
            }
        }

        if let subject, !subject.isEmpty {
            output += "\n【主题】\(subject)\n"
        }

        // 安全检查
        output += "\n【安全检查】\n"

        // 检查敏感域名
        let sensitiveDomains = ["竞争对手.com", "all@company.com", "everyone@"]
        var hasSensitive = false
        for addr in allRecipients + ccList + bccList {
            for domain in sensitiveDomains {
                if addr.lowercased().contains(domain.lowercased()) {
                    output += "⚠️ 警告: 检测到可能的敏感收件人: \(addr)\n"
                    hasSensitive = true
                }
            }
        }

        let totalTo = allRecipients.count
        let totalCC = ccList.count
        let totalBCC = bccList.count
        let total = totalTo + totalCC + totalBCC

        output += "- 收件人: \(totalTo) 人\n"
        if totalCC > 0 { output += "- 抄送: \(totalCC) 人\n" }
        if totalBCC > 0 { output += "- 密送: \(totalBCC) 人\n" }
        output += "- 总计: \(total) 个收件地址\n"

        if total > 20 {
            output += "⚠️ 收件人数较多 (\(total))，请确认是否应使用邮件列表\n"
        }

        if !hasSensitive {
            if toValidation.invalid.isEmpty {
                output += "\n✅ 收件人检查通过，可以发送\n"
            } else {
                output += "\n❌ 请修正无效地址后再发送\n"
            }
        } else {
            output += "\n⚠️ 发现敏感收件人，请确认后再发送\n"
        }

        output += "\n【发送确认】\n"
        output += "请在发送前确认:\n"
        output += "- [ ] 收件人列表正确无误\n"
        output += "- [ ] 抄送/密送设置正确\n"
        output += "- [ ] 附件已添加（如有）\n"
        output += "- [ ] 邮件内容已完成\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 404 操作确认和审计

public struct IssueConfirmOperationTool: MCPTool {
    public let definition = ToolDefinition(
        name: "issue_confirm_operation",
        description: "执行 Linear/Jira/项目管理工具操作前的确认和审计。进行操作预览、变更影响评估和操作记录。",
        parameters: [
            .init(name: "action", type: .string, description: "操作类型: preview(预览变更), confirm(确认执行), audit(查看历史), 默认 preview"),
            .init(name: "issue_id", type: .string, description: "Issue 编号或 ticket ID"),
            .init(name: "change", type: .string, description: "要执行的变更描述"),
            .init(name: "tool", type: .string, description: "工具名称: linear, jira, github, 默认 auto", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "preview"
        let issueID = arguments["issue_id"]
        let change = arguments["change"]
        let tool = arguments["tool"] ?? "auto"

        var output = "=== Issue 操作确认 ===\n\n"

        switch action {
        case "preview":
            output += "【模式】操作预览\n"
            if let id = issueID {
                output += "【Issue】\(id)\n"
            }
            if let ch = change {
                output += "【变更】\(ch)\n"
            }
            output += "\n【操作预览】\n"
            output += "以下变更将被执行:\n"
            if let ch = change {
                output += "  📝 \(ch)\n"
            }
            output += "\n【影响评估】\n"
            output += "- 变更涉及 " + (issueID ?? "未知 Issue") + "\n"
            output += "- 该操作将修改 Issue 的状态/字段\n"
            output += "- 确认后不可自动撤销\n\n"
            output += "💡 如需执行请调用: action=confirm\n"

        case "confirm":
            guard let id = issueID else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: issue_id。请输入 Issue 编号。", isError: true)
            }
            guard let ch = change else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: change。请描述要执行的变更。", isError: true)
            }

            output += "【模式】确认执行\n"
            output += "【Issue】\(id)\n"
            output += "【变更】\(ch)\n"
            output += "【工具】\(tool)\n"

            // 审计日志记录
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let logDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/RenJistroly")
            try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
            let auditFile = logDir.appendingPathComponent("issue_operations.jsonl")

            let auditEntry: [String: Any] = [
                "timestamp": timestamp,
                "action": "confirm",
                "issue_id": id,
                "change": ch,
                "tool": tool,
                "user": NSUserName(),
            ]
            if let auditData = try? JSONSerialization.data(withJSONObject: auditEntry),
               let auditLine = String(data: auditData, encoding: .utf8) {
                if let handle = try? FileHandle(forWritingTo: auditFile) {
                    handle.seekToEndOfFile()
                    handle.write(Data("\(auditLine)\n".utf8))
                    try? handle.close()
                } else {
                    try? Data("\(auditLine)\n".utf8).write(to: auditFile, options: .atomic)
                }
                output += "\n✅ 操作已记录到审计日志\n"
            }

            output += "\n⚠️ 注意: 以上操作尚未实际执行。请通过项目管理工具 API 或手动完成。\n"
            output += "📋 审计日志位置: \(auditFile.path)\n"

        case "audit":
            output += "【模式】审计历史\n"

            let auditFile = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/RenJistroly/issue_operations.jsonl")

            if FileManager.default.fileExists(atPath: auditFile.path),
               let content = try? String(contentsOf: auditFile, encoding: .utf8) {
                let entries = content.split(separator: "\n").compactMap { line -> [String: Any]? in
                    guard let data = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    else { return nil }
                    return json
                }

                if entries.isEmpty {
                    output += "暂无操作记录\n"
                } else {
                    output += "最近 \(min(entries.count, 20)) 条操作记录:\n\n"
                    for entry in entries.suffix(20) {
                        let ts = entry["timestamp"] as? String ?? "?"
                        let id = entry["issue_id"] as? String ?? "?"
                        let ch = entry["change"] as? String ?? "?"
                        let t = entry["tool"] as? String ?? "?"
                        output += "[\(ts)] \(t) \(id): \(ch)\n"
                    }
                }
            } else {
                output += "暂无操作记录\n"
            }

        default:
            output += "未知操作\n"
        }

        output += "\n【安全建议】\n"
        output += "- 始终先使用 preview 查看变更\n"
        output += "- 修改敏感 Issue（如生产环境相关）前二次确认\n"
        output += "- 定期检查审计日志\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 405 屏幕感知兜底

public struct ScreenPerceptionFallbackTool: MCPTool {
    public let definition = ToolDefinition(
        name: "screen_perception_fallback",
        description: "当屏幕感知失败或不完整时的兜底方案。尝试多个策略恢复屏幕内容感知，包括备用 OCR、应用上下文推断、窗口信息获取。",
        parameters: [
            .init(name: "fallback_strategy", type: .string, description: "兜底策略: auto(自动), ax_only(仅AX), ocr_only(仅OCR), app_info(仅应用信息), 默认 auto", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let strategy = arguments["fallback_strategy"] ?? "auto"

        var output = "=== 屏幕感知兜底 ===\n\n"

        let strategies: [(String, String)]
        if strategy == "auto" {
            strategies = [("ax_only", "仅 AX 辅助功能"), ("ocr_only", "仅 OCR"), ("app_info", "仅应用信息")]
        } else if strategy == "ax_only" {
            strategies = [("ax_only", "仅 AX 辅助功能")]
        } else if strategy == "ocr_only" {
            strategies = [("ocr_only", "仅 OCR")]
        } else {
            strategies = [("app_info", "仅应用信息")]
        }

        for (stratName, stratLabel) in strategies {
            output += "--- 策略: \(stratLabel) ---\n\n"

            switch stratName {
            case "ax_only":
                // 仅使用 AX API
                let bridge = AccessibilityBridge()
                if await bridge.checkPermission() {
                    if let bundleID = try? await bridge.getFocusedAppBundleID() {
                        output += "【前台应用】\(bundleID)\n"
                    }
                    if let title = try? await bridge.getFocusedWindowTitle() {
                        output += "【窗口标题】\(title)\n"
                    }
                    if let role = try? await bridge.getElementRole() {
                        output += "【焦点控件】\(role)\n"
                    }
                    if let value = try? await bridge.getFocusedValue(), !value.isEmpty {
                        output += "【焦点内容】\(value.prefix(200))\n"
                    }
                    if let selected = try? await bridge.getSelectedText(), !selected.isEmpty {
                        output += "【选中文字】\(selected.prefix(200))\n"
                    }
                    let windows = try? await bridge.getWindowList()
                    if let windows, !windows.isEmpty {
                        output += "【窗口列表】\n"
                        for (i, w) in windows.enumerated() {
                            output += "  \(i+1). \(w)\n"
                        }
                    }
                } else {
                    output += "AX 权限未授权，无法获取界面信息。\n"
                }

            case "ocr_only":
                let screen = ScreenCaptureBridge()
                let hasPermission = await screen.requestPermission()
                if hasPermission {
                    do {
                        let ownIDs = (try? await screen.getOwnWindowIDs()) ?? []
                        let pngData = try await screen.captureScreen(excludingWindowIDs: ownIDs)
                        let ocrResults = try await OCRService.shared.recognize(in: pngData, preferredEngine: .appleVision)
                        let filtered = ocrResults.filter { $0.confidence >= 0.2 && !$0.text.isEmpty }
                        if !filtered.isEmpty {
                            output += "【OCR 文字】（共 \(filtered.count) 个区域）\n"
                            for (i, r) in filtered.prefix(20).enumerated() {
                                output += "  \(i+1). \"\(r.text)\" (conf:\(String(format: "%.2f", r.confidence)))\n"
                            }
                            if filtered.count > 20 {
                                output += "  ... 还有 \(filtered.count - 20) 个区域\n"
                            }
                            output += "\n【全文】\(filtered.map(\.text).joined(separator: " ").prefix(500))\n"
                        } else {
                            output += "OCR 未检测到文字内容。\n"
                        }
                    } catch {
                        output += "OCR 失败: \(error.localizedDescription)\n"
                    }
                } else {
                    output += "屏幕录制权限未授权，无法截图 OCR。\n"
                }

            case "app_info":
                // 只用 NSWorkspace
                if let front = NSWorkspace.shared.frontmostApplication {
                    output += "【前台应用】\(front.localizedName ?? "未知") (\(front.bundleIdentifier ?? "未知"))\n"
                    output += "【是否激活】\(front.isActive)\n"
                }
                let runningApps = NSWorkspace.shared.runningApplications
                    .filter { $0.activationPolicy == .regular }
                    .compactMap(\.localizedName)
                if !runningApps.isEmpty {
                    output += "\n【正在运行的应用】\n"
                    for name in runningApps {
                        output += "  - \(name)\n"
                    }
                }
                let screens = NSScreen.screens
                if !screens.isEmpty {
                    output += "\n【显示器信息】\n"
                    for (i, screen) in screens.enumerated() {
                        let frame = screen.frame
                        let backingScale = screen.backingScaleFactor
                        output += "  显示器 \(i+1): \(Int(frame.width))×\(Int(frame.height)) @\(Int(backingScale))x\n"
                    }
                }
                output += "\n⚠️ 应用信息无法提供 UI 控件级别的上下文，\n"
                output += "   建议授权辅助功能和屏幕录制以获得完整屏幕感知。\n"

            default:
                break
            }

            output += "\n"
        }

        output += "【恢复建议】\n"
        if strategy == "auto" {
            output += "- AX 策略成功: 可使用 UI 元素引用和控件操作\n"
            output += "- OCR 策略成功: 可获取屏幕文字内容\n"
            output += "- 应用信息策略: 基础可用但无法精确操作\n"
            output += "- 推荐: 在系统设置中开启辅助功能和屏幕录制权限\n"
        }

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}
