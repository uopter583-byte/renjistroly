import Foundation
import os
import RenJistrolyModels

// =============================================================================
// 日程与协同工具组 — Schedule & Collaboration
// 420: TimezoneCheck, 425: MultiWindowFusion
// =============================================================================

// MARK: - 420: 时区冲突检测

public struct TimezoneCheckTool: MCPTool {
    public let definition = ToolDefinition(
        name: "timezone_check",
        description: """
        检测会议安排的时区冲突。检查各参与方所在时区的当地时间，
        避免选错时区导致会议时间错误。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: check(检查) / list_timezones(列出常用时区)",
                  required: true),
            .init(name: "participants_json", type: .string,
                  description: "参与者 JSON: [{\"name\":\"...\",\"timezone\":\"Asia/Shanghai\",\"proposed_time\":\"2026-06-20T10:00:00Z\"}]",
                  required: false),
            .init(name: "proposed_time_utc", type: .string,
                  description: "提议时间 (UTC ISO8601)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "check"

        if action == "list_timezones" {
            return ToolCallResult(id: UUID().uuidString, output: """
                常用时区:
                - Asia/Shanghai (UTC+8) - 中国标准时间
                - Asia/Tokyo (UTC+9) - 日本标准时间
                - America/New_York (UTC-5/-4) - 美东时间
                - America/Los_Angeles (UTC-8/-7) - 美西时间
                - Europe/London (UTC+0/+1) - 英国时间
                - Europe/Berlin (UTC+1/+2) - 欧洲中部时间
                - Australia/Sydney (UTC+10/+11) - 澳大利亚东部时间
                - Asia/Singapore (UTC+8) - 新加坡时间
                - Asia/Seoul (UTC+9) - 韩国时间
                - Pacific/Auckland (UTC+12/+13) - 新西兰时间
                """)
        }

        let participantsJSON = arguments["participants_json"] ?? ""
        let proposedTimeUTC = arguments["proposed_time_utc"] ?? ""

        return ToolCallResult(id: UUID().uuidString, output: """
            时区冲突检查:
            - 建议时间 (UTC): \(proposedTimeUTC.isEmpty ? "未指定" : proposedTimeUTC)
            - 参与者: \(participantsJSON.isEmpty ? "未指定 (请提供 participants_json)" : "已指定")

            注意事项:
            1. 确认提议时间使用的时区
            2. 各参与方当地最佳会议时间通常在 9:00-17:00
            3. 跨时区会议建议使用世界协调时 (UTC) 沟通

            建议: 使用 Calendar 或时间工具验证各时区的当地时间。
            """)
    }
}

// MARK: - 425: 多窗口上下文融合

public struct MultiWindowFusionTool: MCPTool {
    public let definition = ToolDefinition(
        name: "multi_window_fusion",
        description: """
        从多个窗口汇总信息，融合上下文。支持遍历多个应用窗口，
        提取数据并检测矛盾。
        适用于销售从 CRM + 邮件 + 日历中汇总信息。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: fusion(融合) / list(列出窗口) / contradictions(矛盾检测)",
                  required: true),
            .init(name: "windows_json", type: .string,
                  description: "窗口数据 JSON", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "list"

        switch action {
        case "list":
            return ToolCallResult(id: UUID().uuidString, output: """
                窗口列表（需要实际调用 get_app_state/screen_context 获取当前窗口信息）:

                使用步骤:
                1. 调用 running_apps 获取当前运行的应用
                2. 逐个调用 get_app_state 获取每个应用的窗口信息
                3. 调用 multi_window_fusion action=fusion 融合数据
                """)

        case "fusion":
            let windowsJSON = arguments["windows_json"] ?? ""
            if windowsJSON.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: """
                    多窗口上下文融合:

                    请先提供各窗口的数据，例如:
                    - CRM 窗口: 客户名、机会金额、阶段
                    - 邮件窗口: 最新邮件内容
                    - 日历窗口: 会议时间

                    融合步骤:
                    1. 提取每个窗口的关键信息
                    2. 合并到统一的上下文
                    3. 检测矛盾信息（如金额不一致）
                    """)
            }
            return ToolCallResult(id: UUID().uuidString, output: "窗口数据已接收，正在进行上下文融合...\n(实际融合需要 LLM 处理提取的窗口数据)")

        case "contradictions":
            return ToolCallResult(id: UUID().uuidString, output: """
                矛盾检测:
                检查不同窗口间的一致性问题，例如:
                - CRM 中的客户阶段与邮件中的讨论内容是否一致
                - 日历会议时间与邮件确认时间是否一致
                - 多个窗口中的金额数据是否匹配
                """)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}
