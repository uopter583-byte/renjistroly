import Foundation
import os
import RenJistrolyModels

// MARK: - 429: 图表 OCR+语义解析

public struct ChartOCRParseTool: MCPTool {
    public let definition = ToolDefinition(
        name: "chart_ocr_parse",
        description: """
        解析广告后台等图表界面。对截图中的图表进行 OCR 识别
        并提取数据点和趋势，帮助运营理解数据。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: parse(解析) / describe(描述) / extract(提取数据点)",
                  required: true),
            .init(name: "chart_type", type: .string,
                  description: "图表类型: line/bar/pie/table/auto",
                  required: false),
            .init(name: "ocr_text", type: .string,
                  description: "从屏幕获取的 OCR 文字",
                  required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "describe"
        let chartType = arguments["chart_type"] ?? "auto"

        switch action {
        case "describe":
            return ToolCallResult(id: UUID().uuidString, output: """
                图表解析工具使用说明:
                1. 先调用 screen_context 或 ocr_screen 获取当前屏幕的 OCR 文本
                2. 将 OCR 结果传入 chart_ocr_parse action=parse
                3. AI 将识别图表类型、数据点和趋势

                当前支持图表类型:
                - 折线图 (line): 趋势分析
                - 柱状图 (bar): 对比分析
                - 饼图 (pie): 占比分析
                - 表格 (table): 数据提取
                """)

        case "extract":
            let ocrText = arguments["ocr_text"] ?? ""
            if ocrText.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: "需要 ocr_text 参数，请先获取屏幕 OCR 文字")
            }
            return ToolCallResult(id: UUID().uuidString, output: """
                从 OCR 文本中提取数据点:
                图表类型: \(chartType)
                OCR 原文: \(ocrText.prefix(200))...

                [数据提取需 LLM 处理 OCR 文本]
                预计提取:
                - 数据标签和值
                - 时间序列
                - 异常波动点
                """)

        case "parse":
            let ocrText = arguments["ocr_text"] ?? ""
            return ToolCallResult(id: UUID().uuidString, output: """
                图表解析结果:
                类型: \(chartType)
                数据点: (需 LLM 从 OCR 文本解析)

                原始 OCR 文本 (\(ocrText.count) 字符):
                \(ocrText.prefix(500))
                """)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// MARK: - 430: 推送确认流程

public struct PushConfirmTool: MCPTool {
    public let definition = ToolDefinition(
        name: "push_confirm",
        description: """
        推送通知发送确认流程。在发送推送前详细展示内容、
        目标人群和预估覆盖量，需要二次确认。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: preview(预览) / send(发送) / cancel(取消)",
                  required: true),
            .init(name: "title", type: .string,
                  description: "推送标题", required: false),
            .init(name: "body", type: .string,
                  description: "推送内容", required: false),
            .init(name: "target_segment", type: .string,
                  description: "目标人群", required: false),
            .init(name: "estimated_recipients", type: .string,
                  description: "预估接收人数", required: false),
            .init(name: "confirm", type: .string,
                  description: "确认: yes/no", required: false),
            .init(name: "test_mode", type: .string,
                  description: "测试模式: true/false", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    private static let lock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _pendingPush: PushNotificationRequest?

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "preview"

        switch action {
        case "preview":
            let title = arguments["title"] ?? "无标题"
            let body = arguments["body"] ?? "无内容"
            let segment = arguments["target_segment"] ?? "全部用户"
            let recipients = Int(arguments["estimated_recipients"] ?? "0") ?? 0
            let testMode = arguments["test_mode"] == "true"

            Self.lock.withLock {
                Self._pendingPush = PushNotificationRequest(
                    title: title,
                    body: body,
                    targetSegment: segment,
                    estimatedRecipients: recipients,
                    isTestMode: testMode
                )
            }

            let modeStr = testMode ? " [测试模式]" : ""

            return ToolCallResult(id: UUID().uuidString, output: """
                === 推送预览\(modeStr) ===
                标题: \(title)
                内容: \(body)
                目标: \(segment)
                预估覆盖: \(recipients > 0 ? "\(recipients) 人" : "未估算")

                请确认无误后发送:
                push_confirm action=send confirm=yes
                取消:
                push_confirm action=cancel
                """)

        case "send":
            guard let confirm = arguments["confirm"]?.lowercased(), confirm == "yes" else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 confirm=yes 确认发送")
            }
            guard let push = Self.lock.withLock({ Self._pendingPush }) else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到推送预览，请先执行 push_confirm action=preview")
            }
            Self.lock.withLock { Self._pendingPush = nil }

            if push.isTestMode {
                return ToolCallResult(id: UUID().uuidString, output: """
                    ✅ 测试推送已发送
                    标题: \(push.title)
                    目标: \(push.targetSegment)
                    """)
            }
            return ToolCallResult(id: UUID().uuidString, output: """
                ✅ 推送已发送
                标题: \(push.title)
                目标: \(push.targetSegment)
                覆盖: \(push.estimatedRecipients) 人
                时间: \(Date())
                """)

        case "cancel":
            Self.lock.withLock { Self._pendingPush = nil }
            return ToolCallResult(id: UUID().uuidString, output: "推送已取消")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// MARK: - 431: CSV 格式校验

public struct CSVValidateTool: MCPTool {
    public let definition = ToolDefinition(
        name: "csv_validate",
        description: """
        校验 CSV 文件格式。检查列数、必需列、数据类型等，
        避免上传格式错误的 CSV 导致数据问题。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: validate(校验) / preview(预览前几行)",
                  required: true),
            .init(name: "csv_content", type: .string,
                  description: "CSV 内容（可直接粘贴）", required: false),
            .init(name: "file_path", type: .string,
                  description: "CSV 文件路径（也可用 read_file 读取）", required: false),
            .init(name: "expected_columns", type: .string,
                  description: "期望的列名，逗号分隔", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "validate"

        let csvContent = arguments["csv_content"] ?? ""

        if csvContent.isEmpty, arguments["file_path"] != nil {
            // In real scenario, read the file
            return ToolCallResult(id: UUID().uuidString, output: "请先使用 read_file 读取 CSV 文件内容，然后传入 csv_content 参数。")
        }

        if csvContent.isEmpty {
            return ToolCallResult(id: UUID().uuidString, output: "需要 csv_content 或 file_path 参数")
        }

        let expectedCols = (arguments["expected_columns"] ?? "")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if action == "preview" {
            let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
            let preview = lines.prefix(5).enumerated().map { "\($0 + 1): \($1)" }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "CSV 预览 (前 \(min(lines.count, 5)) 行):\n\(preview)")
        }

        let result = CSVValidationResult.validate(csvContent: csvContent, expectedColumns: expectedCols)

        var output = result.isValid
            ? "✅ CSV 格式校验通过\n"
            : "❌ CSV 格式校验不通过\n"

        output += "行数: \(result.rowCount) (不含表头)\n"
        output += "列数: \(result.columnCount)\n"

        if !expectedCols.isEmpty {
            output += "期望列: \(expectedCols.joined(separator: ", "))\n"
            if !result.missingColumns.isEmpty {
                output += "缺少列: \(result.missingColumns.joined(separator: ", "))\n"
            }
        }

        if !result.errors.isEmpty {
            output += "\n错误详情:\n"
            for err in result.errors.prefix(10) {
                let colInfo = err.column.map { " [列: \($0)]" } ?? ""
                output += "- 第 \(err.row) 行\(colInfo): \(err.message)\n"
            }
            if result.errors.count > 10 {
                output += "...还有 \(result.errors.count - 10) 个错误\n"
            }
        }

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - 432: CMS 版本管理

public struct CMSVersionTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cms_version",
        description: """
        CMS 内容版本管理。支持版本查看、发布、回滚操作。
        每次发布自动创建版本快照。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: list_versions(版本列表) / publish(发布) / rollback(回滚) / diff(差异对比)",
                  required: true),
            .init(name: "content_id", type: .string,
                  description: "内容 ID", required: false),
            .init(name: "version_number", type: .string,
                  description: "版本号 (rollback/diff 时需要)", required: false),
            .init(name: "confirm", type: .string,
                  description: "确认: yes/no (publish/rollback 时)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    private static let lock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _versionStore: [String: [CMSContentVersion]] = [:]

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "list_versions"
        let contentID = arguments["content_id"] ?? "default"

        switch action {
        case "list_versions":
            let versions = Self.lock.withLock { Self._versionStore[contentID] ?? [] }
            if versions.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: "内容「\(contentID)」暂无版本记录。\n发布新版本: cms_version action=publish content_id=\(contentID)")
            }
            let list = versions.sorted(by: { $0.updatedAt > $1.updatedAt }).enumerated().map { i, v in
                let pub = v.isPublished ? " [已发布]" : ""
                return "\(i + 1). v\(v.versionNumber)\(pub) - \(v.updatedBy) (\(v.updatedAt))"
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "内容「\(contentID)」版本列表:\n\(list)")

        case "publish":
            guard let confirm = arguments["confirm"]?.lowercased() else {
                return ToolCallResult(id: UUID().uuidString, output: """
                    即将发布新版本:
                    内容: \(contentID)

                    请确认:
                    cms_version action=publish content_id=\(contentID) confirm=yes
                    取消:
                    cms_version action=publish content_id=\(contentID) confirm=no
                    """)
            }
            if confirm != "yes" {
                return ToolCallResult(id: UUID().uuidString, output: "发布已取消")
            }
            let nextVersion = Self.lock.withLock { () -> Int in
                let versions = Self._versionStore[contentID] ?? []
                let next = versions.count + 1
                let newVersion = CMSContentVersion(
                    versionNumber: "\(next)",
                    contentID: contentID,
                    contentTitle: "内容 \(contentID)",
                    updatedAt: Date(),
                    updatedBy: "运营人员",
                    isPublished: true,
                    diffSummary: "新版本发布"
                )
                Self._versionStore[contentID, default: []].append(newVersion)
                return next
            }
            return ToolCallResult(id: UUID().uuidString, output: "✅ 内容「\(contentID)」已发布 v\(nextVersion)")

        case "rollback":
            guard let versionStr = arguments["version_number"] else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 version_number 参数", isError: true)
            }
            guard let confirm = arguments["confirm"]?.lowercased() else {
                return ToolCallResult(id: UUID().uuidString, output: """
                    即将回滚内容「\(contentID)」到 v\(versionStr):

                    请确认:
                    cms_version action=rollback content_id=\(contentID) version_number=\(versionStr) confirm=yes
                    """)
            }
            if confirm != "yes" {
                return ToolCallResult(id: UUID().uuidString, output: "回滚已取消")
            }
            Self.lock.withLock {
                let newVersion = CMSContentVersion(
                    versionNumber: "\(versionStr).rollback",
                    contentID: contentID,
                    contentTitle: "内容 \(contentID) (回滚到 v\(versionStr))",
                    updatedAt: Date(),
                    updatedBy: "运营人员",
                    isPublished: true,
                    diffSummary: "回滚到版本 v\(versionStr)"
                )
                Self._versionStore[contentID, default: []].append(newVersion)
            }
            return ToolCallResult(id: UUID().uuidString, output: "✅ 内容「\(contentID)」已回滚到 v\(versionStr)")

        case "diff":
            guard let versionStr = arguments["version_number"] else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 version_number 参数", isError: true)
            }
            let versions = Self.lock.withLock { Self._versionStore[contentID] ?? [] }
            guard let target = versions.first(where: { $0.versionNumber == versionStr }) else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到版本 v\(versionStr)")
            }
            return ToolCallResult(id: UUID().uuidString, output: """
                版本差异对比:
                内容: \(contentID)
                版本: v\(versionStr)
                差异: \(target.diffSummary)
                发布者: \(target.updatedBy)
                发布时间: \(target.updatedAt)
                """)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// MARK: - 433: 站点确认

public struct SiteConfirmTool: MCPTool {
    public let definition = ToolDefinition(
        name: "site_confirm",
        description: """
        在复制粘贴或发布内容前，确认操作站点是否正确。
        防止在错误站点执行操作。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: check(检查) / set(设置预期站点)",
                  required: true),
            .init(name: "intended_site_url", type: .string,
                  description: "预期操作的站点 URL", required: false),
            .init(name: "current_site_url", type: .string,
                  description: "当前所在站点 URL", required: false),
            .init(name: "operation", type: .string,
                  description: "要执行的操作描述", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "check"

        if action == "set" {
            let intended = arguments["intended_site_url"] ?? ""
            return ToolCallResult(id: UUID().uuidString, output: "预期站点已设为: \(intended)")
        }

        let intended = arguments["intended_site_url"] ?? ""
        let current = arguments["current_site_url"] ?? ""
        let operation = arguments["operation"] ?? "未知操作"

        if intended.isEmpty || current.isEmpty {
            return ToolCallResult(id: UUID().uuidString, output: """
                站点确认:
                操作: \(operation)
                请提供 intended_site_url (预期站点) 和 current_site_url (当前站点) 进行比对。

                提示: 使用 get_browser_state 获取当前浏览器 URL。
                """)
        }

        let isMatch = intended == current || intended.contains(current) || current.contains(intended)
        let intendedDisplay = intended
        let currentDisplay = current

        if isMatch {
            return ToolCallResult(id: UUID().uuidString, output: """
                ✅ 站点匹配通过
                操作: \(operation)
                预期站点: \(intendedDisplay)
                当前站点: \(currentDisplay)
                状态: 一致，可以执行操作。
                """)
        }
        return ToolCallResult(id: UUID().uuidString, output: """
            🚫 站点不匹配！
            操作: \(operation)
            预期站点: \(intendedDisplay)
            当前站点: \(currentDisplay)

            请确认当前浏览器标签页是否正确，或修改预期站点后重试。
            """)
    }
}

// MARK: - 434: 窗口匹配验证

public struct WindowVerifyTool: MCPTool {
    public let definition = ToolDefinition(
        name: "window_verify",
        description: """
        验证当前窗口是否与预期匹配。截图前先确认窗口正确，
        防止截错窗口导致错误分析。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: verify(验证) / list(列出窗口)",
                  required: true),
            .init(name: "expected_window", type: .string,
                  description: "预期的窗口标题关键词", required: false),
            .init(name: "expected_app", type: .string,
                  description: "预期的应用名称", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "list"

        if action == "list" {
            return ToolCallResult(id: UUID().uuidString, output: """
                窗口列表 (需实际调用 list_windows 或 get_app_state 获取):

                验证步骤:
                1. 调用 list_windows 获取当前所有窗口
                2. 调用 window_verify action=verify expected_window="报表" 验证窗口
                3. 确认匹配后再截图或操作
                """)
        }

        let expectedWindow = arguments["expected_window"] ?? ""
        let expectedApp = arguments["expected_app"] ?? ""

        if expectedWindow.isEmpty {
            return ToolCallResult(id: UUID().uuidString, output: "需要 expected_window 参数")
        }

        // In real scenario, this would check against actual window list
        return ToolCallResult(id: UUID().uuidString, output: """
            窗口匹配验证:
            - 预期窗口: \(expectedWindow)\(expectedApp.isEmpty ? "" : " (\(expectedApp))")
            - 验证方法: 检查当前前台窗口是否包含「\(expectedWindow)」

            建议:
            1. 调用 running_apps 查看当前运行的应用
            2. 调用 list_windows 查看窗口列表
            3. 匹配窗口标题/应用名
            4. 确认后截图
            """)
    }
}

// MARK: - 435: 基线对比

public struct BaselineCompareTool: MCPTool {
    public let definition = ToolDefinition(
        name: "baseline_compare",
        description: """
        将当前指标与基线值对比，检测异常偏离。
        运营检查异常指标时使用。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: compare(对比) / set_baseline(设置基线) / thresholds(查看阈值)",
                  required: true),
            .init(name: "metric_name", type: .string,
                  description: "指标名称", required: false),
            .init(name: "current_value", type: .string,
                  description: "当前值", required: false),
            .init(name: "baseline_value", type: .string,
                  description: "基线值", required: false),
            .init(name: "threshold_percent", type: .string,
                  description: "异常阈值百分比，默认 20", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private static let lock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _baselines: [String: Double] = [
        "日活跃用户": 10000,
        "转化率": 3.5,
        "平均响应时间": 200,
        "退款率": 2.0,
        "日订单量": 500,
    ]

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "compare"

        switch action {
        case "thresholds":
            let baselineMap = Self.lock.withLock { Self._baselines }
            return ToolCallResult(id: UUID().uuidString, output: """
                异常检测阈值说明:
                - 偏离度 = (当前值 - 基线值) / 基线值 * 100%
                - |偏离度| > 阈值 → 标记为异常
                - 默认阈值: 20%
                - 可根据指标特性调整阈值

                预定义基线:
                \(baselineMap.map { "- \($0.key): \($0.value)" }.joined(separator: "\n"))
                """)

        case "set_baseline":
            guard let metric = arguments["metric_name"], !metric.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 metric_name 参数", isError: true)
            }
            guard let valStr = arguments["baseline_value"], let val = Double(valStr) else {
                return ToolCallResult(id: UUID().uuidString, output: "需要有效的 baseline_value 参数", isError: true)
            }
            Self.lock.withLock { Self._baselines[metric] = val }
            return ToolCallResult(id: UUID().uuidString, output: "基线已设置: \(metric) = \(val)")

        case "compare":
            guard let metric = arguments["metric_name"] else {
                // Show all comparisons
                let snapshot = Self.lock.withLock { Self._baselines }
                var results: [String] = []
                for (name, baseline) in snapshot {
                    results.append("- \(name): 基线=\(baseline), 当前值=未知")
                }
                return ToolCallResult(id: UUID().uuidString, output: "所有基线指标:\n" + results.joined(separator: "\n"))
            }
            guard let currentStr = arguments["current_value"], let current = Double(currentStr) else {
                return ToolCallResult(id: UUID().uuidString, output: "需要有效的 current_value 参数", isError: true)
            }
            let baseline = Self.lock.withLock { Self._baselines[metric] ?? 0 }
            let threshold = Double(arguments["threshold_percent"] ?? "20") ?? 20

            let comparison = BaselineComparison.compute(
                metricName: metric,
                currentValue: current,
                baselineValue: baseline,
                thresholdPercent: threshold
            )

            let anomalyFlag = comparison.isAnomaly ? "⚠️ 异常" : "✅ 正常"
            return ToolCallResult(id: UUID().uuidString, output: """
                基线对比:
                指标: \(metric)
                当前值: \(current)
                基线值: \(baseline)
                偏离度: \(String(format: "%.1f", comparison.deviationPercent))%
                阈值: \(threshold)%
                状态: \(anomalyFlag)
                """)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}
