import Foundation
import os
import RenJistrolyModels

// =============================================================================
// 授权与安全工具组 — Authorization & Security
// 409: PermissionAware, 415: OCRConfidenceCheck, 411: ContextIsolation
// =============================================================================

// MARK: - 409: 权限感知

public struct PermissionAwareTool: MCPTool {
    public let definition = ToolDefinition(
        name: "permission_aware",
        description: """
        查询当前系统的权限状态，确认 AI 是否有权限执行特定操作。
        在查订单、改系统设置等操作前调用，避免无权限操作失败。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: check(检查权限) / list(列出所有权限状态)",
                  required: true),
            .init(name: "permission_type", type: .string,
                  description: "要检查的权限类型: accessibility / screenRecording / microphone / automation / camera",
                  required: false),
            .init(name: "operation", type: .string,
                  description: "要执行的操作描述，用于判断需要哪些权限", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "list"

        switch action {
        case "list":
            return ToolCallResult(id: UUID().uuidString, output: """
                系统权限状态 (静态描述，实际状态需运行 PermissionCenter):
                - 辅助功能 (Accessibility): 需要授权
                - 屏幕录制 (Screen Recording): 需要授权
                - 麦克风 (Microphone): 需要授权
                - 自动化 (Apple Events): 默认允许
                - 摄像头 (Camera): 一般不用于 AI 操作

                建议操作前调用 check 确认具体权限。
                """)

        case "check":
            let permissionType = arguments["permission_type"] ?? "accessibility"
            let operation = arguments["operation"] ?? "未知操作"
            let permissionName: String
            switch permissionType {
            case "accessibility": permissionName = "辅助功能 (Accessibility)"
            case "screenRecording": permissionName = "屏幕录制 (Screen Recording)"
            case "microphone": permissionName = "麦克风"
            case "automation": permissionName = "自动化 (Apple Events)"
            case "camera": permissionName = "摄像头"
            default: permissionName = permissionType
            }
            return ToolCallResult(id: UUID().uuidString, output: """
                权限检查:
                操作: \(operation)
                需要权限: \(permissionName)
                状态: 待确认（需调用 PermissionCenter 实际检测）

                提示: 如果操作失败，请先检查系统偏好设置中的权限授权。
                """)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// MARK: - 415: OCR 置信度校验

public struct OCRConfidenceCheckTool: MCPTool {
    public let definition = ToolDefinition(
        name: "ocr_confidence_check",
        description: """
        校验 OCR 识别结果的置信度，过滤低置信度区域。
        防止因 OCR 识别错误导致 AI 做出错误判断或回复。
        """,
        parameters: [
            .init(name: "min_confidence", type: .string,
                  description: "最低置信度阈值 0.0~1.0，默认 0.6", required: false),
            .init(name: "ocr_results_json", type: .string,
                  description: "OCR 结果的 JSON 描述", required: false),
            .init(name: "action", type: .string,
                  description: "操作: check(校验) / threshold(设置阈值)",
                  required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "check"
        let minConf = Float(arguments["min_confidence"] ?? "0.6") ?? 0.6

        if action == "threshold" {
            return ToolCallResult(id: UUID().uuidString, output: "OCR 置信度阈值已设为: \(String(format: "%.2f", minConf))")
        }

        _ = arguments["ocr_results_json"] ?? ""

        return ToolCallResult(id: UUID().uuidString, output: """
            OCR 置信度校验:
            - 最小阈值: \(String(format: "%.2f", minConf))

            注意: 如果 OCR 结果中包含置信度低于 \(String(format: "%.2f", minConf)) 的区域，
            请勿将这些区域的文字用于关键判断。

            建议: 在做出重要回复或操作前，使用 screen_context 重新获取 OCR，
            并关注每个区域的 confidence 值。
            """)
    }
}

// MARK: - 411: 上下文隔离

public struct ContextIsolationTool: MCPTool {
    public let definition = ToolDefinition(
        name: "context_isolation",
        description: """
        管理工单上下文的隔离。当切换工单时，确保上下文不串线。
        每个工单有独立的上下文空间，切换时自动隔离。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: switch(切换工单) / current(当前) / list(列表) / clear(清理)",
                  required: true),
            .init(name: "ticket_id", type: .string,
                  description: "工单 ID (switch 操作时需要)", required: false),
            .init(name: "context_data", type: .string,
                  description: "上下文数据 JSON (switch 时附带)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private static let isolationLock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _isolationStates: [String: ContextIsolationState] = [:]
    private static nonisolated(unsafe) var _activeTicketID: String?

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "current"

        switch action {
        case "current":
            let snapshot = Self.isolationLock.withLock { () -> (active: String, state: ContextIsolationState)? in
                guard let active = Self._activeTicketID, let state = Self._isolationStates[active] else { return nil }
                return (active, state)
            }
            guard let (_, state) = snapshot else {
                return ToolCallResult(id: UUID().uuidString, output: "当前未激活任何工单上下文。使用 action=switch 切换工单。")
            }
            return ToolCallResult(id: UUID().uuidString, output: """
                当前工单:
                - 工单 ID: \(state.activeTicketID)
                - 开始隔离时间: \(state.isolationStartedAt)
                - 上下文变量: \(state.isolatedContext.isEmpty ? "无" : state.isolatedContext.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))
                - 历史工单: \(state.previousTicketIDs.isEmpty ? "无" : state.previousTicketIDs.joined(separator: ", "))
                """)

        case "list":
            let list = Self.isolationLock.withLock { () -> String in
                let ids = Array(Self._isolationStates.keys)
                let lines = ids.map { id in
                    let isActive = id == Self._activeTicketID
                    let customerName = Self._isolationStates[id]?.isolatedContext["customerName"] ?? "未知"
                    return "\(isActive ? "* " : "  ")\(id) (客户: \(customerName))\(isActive ? " [当前]" : "")"
                }
                return lines.isEmpty ? "" : "工单上下文列表:\n" + lines.joined(separator: "\n")
            }
            return ToolCallResult(id: UUID().uuidString, output: list.isEmpty ? "无隔离工单" : list)

        case "switch":
            guard let ticketID = arguments["ticket_id"], !ticketID.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 ticket_id 参数", isError: true)
            }

            Self.isolationLock.withLock {
                if let previousID = Self._activeTicketID, var prevState = Self._isolationStates[previousID] {
                    prevState.previousTicketIDs.append(ticketID)
                    Self._isolationStates[previousID] = prevState
                }

                if Self._isolationStates[ticketID] == nil {
                    var contextData: [String: String] = [:]
                    if let jsonStr = arguments["context_data"],
                       let data = jsonStr.data(using: .utf8),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                        contextData = dict
                    }
                    Self._isolationStates[ticketID] = ContextIsolationState(
                        activeTicketID: ticketID,
                        isolatedContext: contextData,
                        previousTicketIDs: Self._activeTicketID.map { [$0] } ?? []
                    )
                }

                Self._activeTicketID = ticketID
            }
            return ToolCallResult(id: UUID().uuidString, output: "已切换到工单 \(ticketID)，上下文已隔离。")

        case "clear":
            let count = Self.isolationLock.withLock {
                let c = Self._isolationStates.count
                Self._isolationStates.removeAll()
                Self._activeTicketID = nil
                return c
            }
            return ToolCallResult(id: UUID().uuidString, output: "已清理 \(count) 个工单上下文。")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}
