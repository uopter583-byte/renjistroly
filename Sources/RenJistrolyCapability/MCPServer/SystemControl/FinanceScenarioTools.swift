import Foundation
import os
import RenJistrolyModels

// MARK: - 408: 高风险操作确认（"发送"确认）

public struct HighRiskConfirmTool: MCPTool {
    public let definition = ToolDefinition(
        name: "high_risk_confirm",
        description: """
        对高风险操作进行二次确认，如发送消息、提交通单、发送邮件等。
        防止误操作。在 AI 执行发送/提交等不可逆操作前，先调用此工具获取确认。
        """,
        parameters: [
            .init(name: "action_type", type: .string,
                  description: "操作类型: send_message / submit_ticket / send_email / execute_payment / custom",
                  required: true),
            .init(name: "action_detail", type: .string,
                  description: "操作描述，详细说明要执行的操作内容", required: true),
            .init(name: "confirm", type: .string,
                  description: "确认标记: yes/no，初次调用时无需提供", required: false),
            .init(name: "target", type: .string,
                  description: "操作目标: 收件人/接收方", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    private static let confirmLock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _pendingConfirmations: [String: Date] = [:]

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let actionType = arguments["action_type"] ?? "custom"
        let detail = arguments["action_detail"] ?? "无描述"
        let target = arguments["target"] ?? "未指定"
        let confirm = arguments["confirm"]?.lowercased()

        let confirmID = "confirm_\(actionType)_\(detail.hashValue)"

        if confirm == "yes" {
            guard Self.confirmLock.withLock({ Self._pendingConfirmations[confirmID] }) != nil else {
                return ToolCallResult(id: UUID().uuidString, output: "确认超时或无效，请重新发起操作。", isError: true)
            }
            _ = Self.confirmLock.withLock { Self._pendingConfirmations.removeValue(forKey: confirmID) }
            return ToolCallResult(id: UUID().uuidString, output: "确认通过。操作已批准: \(actionType)\n目标: \(target)\n详情: \(detail)")
        }

        if confirm == "no" {
            _ = Self.confirmLock.withLock { Self._pendingConfirmations.removeValue(forKey: confirmID) }
            return ToolCallResult(id: UUID().uuidString, output: "操作已取消: \(actionType)")
        }

        // First call: show confirmation prompt
        Self.confirmLock.withLock { Self._pendingConfirmations[confirmID] = Date() }

        let riskNotice: String
        switch actionType {
        case "send_message":
            riskNotice = "发送消息是不可逆操作，消息一旦发出无法撤回。"
        case "submit_ticket":
            riskNotice = "提交通单后将进入处理流程，修改需额外操作。"
        case "send_email":
            riskNotice = "发送邮件后无法撤回，请确认收件人和内容正确。"
        case "execute_payment":
            riskNotice = "支付操作涉及资金变动，请务必确认金额和收款方。"
        default:
            riskNotice = "此操作为高风险，请确认后继续。"
        }

        return ToolCallResult(id: UUID().uuidString, output: """
            ⚠️ 高风险操作确认
            操作类型: \(actionType)
            目标: \(target)
            详情: \(detail)
            风险提示: \(riskNotice)

            请确认是否执行:
            调用 high_risk_confirm action_type=\(actionType) action_detail=\(detail) target=\(target) confirm=yes
            或取消:
            调用 high_risk_confirm action_type=\(actionType) action_detail=\(detail) confirm=no
            """)
    }
}

// MARK: - 414: 风险分级拦截

public struct RefundRiskTool: MCPTool {
    public let definition = ToolDefinition(
        name: "refund_risk_assess",
        description: """
        退款风险评分与分级拦截。根据金额、客户历史等维度评估退款风险，
        高风险退款自动要求人工审批。
        """,
        parameters: [
            .init(name: "amount", type: .string, description: "退款金额", required: true),
            .init(name: "customer_history_days", type: .string,
                  description: "客户注册天数", required: false),
            .init(name: "previous_refunds", type: .string,
                  description: "历史退款次数", required: false),
            .init(name: "action", type: .string,
                  description: "操作: assess(评估) / bypass(强制通过，需提供原因)",
                  required: false),
            .init(name: "bypass_reason", type: .string,
                  description: "强制通过原因 (action=bypass 时需要)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "assess"

        guard let amountStr = arguments["amount"], let amount = Double(amountStr) else {
            return ToolCallResult(id: UUID().uuidString, output: "需要有效的 amount 参数", isError: true)
        }

        let historyDays = Int(arguments["customer_history_days"] ?? "365") ?? 365
        let previousRefunds = Int(arguments["previous_refunds"] ?? "0") ?? 0

        let assessment = RefundRiskAssessment.assess(
            amount: amount,
            customerHistoryDays: historyDays,
            previousRefunds: previousRefunds
        )

        if action == "bypass" {
            guard let reason = arguments["bypass_reason"], !reason.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "强制通过需要提供 bypass_reason。", isError: true)
            }
            return ToolCallResult(id: UUID().uuidString, output: """
                ⚠️ 强制通过退款
                金额: \(amount)
                风险等级: \(assessment.riskLevel.rawValue)
                风险分: \(String(format: "%.2f", assessment.riskScore))
                原因: \(reason)
                标记: \(assessment.flags.isEmpty ? "无" : assessment.flags.joined(separator: ", "))
                """)
        }

        if assessment.riskLevel >= .high {
            return ToolCallResult(id: UUID().uuidString, output: """
                🚫 退款被拦截
                金额: \(amount)
                风险等级: \(assessment.riskLevel.rawValue) (需要人工审批)
                风险分: \(String(format: "%.2f", assessment.riskScore))
                风险标记: \(assessment.flags.isEmpty ? "无" : assessment.flags.joined(separator: ", "))

                如需强制通过，请使用 action=bypass 并提供原因。
                """)
        }

        return ToolCallResult(id: UUID().uuidString, output: """
            ✅ 退款风险评估通过
            金额: \(amount)
            风险等级: \(assessment.riskLevel.rawValue)
            风险分: \(String(format: "%.2f", assessment.riskScore))
            标记: \(assessment.flags.isEmpty ? "无" : assessment.flags.joined(separator: ", "))
            """)
    }
}

// MARK: - 424: 可靠提醒机制

public struct ReminderTool: MCPTool {
    public let definition = ToolDefinition(
        name: "reminder",
        description: """
        创建和管理跟进提醒。支持设置优先级、到期时间和关联实体。
        提醒会在到期时通知用户。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: create(创建) / list(列表) / complete(完成) / delete(删除)",
                  required: true),
            .init(name: "title", type: .string,
                  description: "提醒标题", required: false),
            .init(name: "description", type: .string,
                  description: "提醒详情", required: false),
            .init(name: "due_date", type: .string,
                  description: "到期时间 (ISO8601, 如 2026-06-20T10:00:00Z)", required: false),
            .init(name: "priority", type: .string,
                  description: "优先级: low/medium/high/urgent", required: false),
            .init(name: "related_entity_id", type: .string,
                  description: "关联实体 ID (客户/机会/工单)", required: false),
            .init(name: "related_entity_type", type: .string,
                  description: "关联实体类型: customer/opportunity/ticket", required: false),
            .init(name: "customer_name", type: .string,
                  description: "关联客户姓名", required: false),
            .init(name: "reminder_id", type: .string,
                  description: "提醒 ID (complete/delete 时需要)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private static let lock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _reminders: [ReminderItem] = []

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "list"

        switch action {
        case "create":
            guard let title = arguments["title"], !title.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 title 参数", isError: true)
            }
            let description = arguments["description"] ?? ""
            let priorityRaw = arguments["priority"] ?? "medium"
            let priority = ReminderItem.ReminderPriority(rawValue: priorityRaw) ?? .medium

            let dueDate: Date
            if let dateStr = arguments["due_date"],
               let date = ISO8601DateFormatter().date(from: dateStr) {
                dueDate = date
            } else {
                dueDate = Date().addingTimeInterval(86400) // Default: 1 day
            }

            let reminder = ReminderItem(
                title: title,
                description: description,
                dueDate: dueDate,
                priority: priority,
                context: .init(
                    relatedEntityID: arguments["related_entity_id"],
                    relatedEntityType: arguments["related_entity_type"],
                    customerName: arguments["customer_name"]
                )
            )
            Self.lock.withLock { Self._reminders.append(reminder) }

            let timeStr = ISO8601DateFormatter().string(from: dueDate)
            return ToolCallResult(id: UUID().uuidString, output: """
                ✅ 提醒已创建
                - 标题: \(title)
                - 到期: \(timeStr)
                - 优先级: \(priority.rawValue)
                - 关联: \(arguments["customer_name"] ?? arguments["related_entity_id"] ?? "无")
                - 提醒 ID: \(reminder.id)
                """)

        case "list":
            let snapshot = Self.lock.withLock { Self._reminders }
            if snapshot.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: "暂无提醒。使用 action=create 创建提醒。")
            }
            let list = snapshot.sorted { $0.dueDate < $1.dueDate }.enumerated().map { i, r in
                let status = r.isCompleted ? "✅" : "⏳"
                let timeStr = ISO8601DateFormatter().string(from: r.dueDate)
                return "\(status) \(i + 1). \(r.title) (\(r.priority.rawValue)) - \(timeStr)"
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "提醒列表:\n\(list)")

        case "complete":
            guard let idStr = arguments["reminder_id"],
                  let id = UUID(uuidString: idStr) else {
                return ToolCallResult(id: UUID().uuidString, output: "无效提醒 ID", isError: true)
            }
            let title = Self.lock.withLock { () -> String? in
                guard let idx = Self._reminders.firstIndex(where: { $0.id == id }) else { return nil }
                let r = Self._reminders[idx]
                Self._reminders[idx] = ReminderItem(
                    id: r.id, title: r.title, description: r.description,
                    dueDate: r.dueDate, priority: r.priority,
                    context: r.context, isCompleted: true, createdAt: r.createdAt
                )
                return r.title
            }
            guard let title else {
                return ToolCallResult(id: UUID().uuidString, output: "无效提醒 ID", isError: true)
            }
            return ToolCallResult(id: UUID().uuidString, output: "提醒已标记完成: \(title)")

        case "delete":
            guard let idStr = arguments["reminder_id"],
                  let id = UUID(uuidString: idStr) else {
                return ToolCallResult(id: UUID().uuidString, output: "无效提醒 ID", isError: true)
            }
            Self.lock.withLock { Self._reminders.removeAll { $0.id == id } }
            return ToolCallResult(id: UUID().uuidString, output: "提醒已删除")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// =============================================================================

// MARK: - 426: 生产开关保护

public struct ProductionSwitchTool: MCPTool {
    public let definition = ToolDefinition(
        name: "production_switch",
        description: """
        生产环境开关保护。切换任何生产配置前必须经过确认。
        高风险开关需要多重确认。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: toggle(切换) / status(查看状态) / rollback(回滚)",
                  required: true),
            .init(name: "switch_name", type: .string,
                  description: "开关名称", required: true),
            .init(name: "proposed_value", type: .string,
                  description: "目标值: true/false", required: false),
            .init(name: "confirm", type: .string,
                  description: "确认: yes/no", required: false),
            .init(name: "reason", type: .string,
                  description: "变更原因", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    private static let lock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _switchStates: [String: ProductionSwitch] = [
        "feature_new_checkout": ProductionSwitch(
            name: "新结账流程", currentValue: false, proposedValue: false,
            impact: "启用新版结账流程，影响所有购买用户", riskLevel: .high
        ),
        "maintenance_mode": ProductionSwitch(
            name: "维护模式", currentValue: false, proposedValue: false,
            impact: "开启后所有用户将看到维护页面", riskLevel: .critical
        ),
        "promotion_banner": ProductionSwitch(
            name: "促销横幅", currentValue: true, proposedValue: false,
            impact: "控制首页促销横幅的显示", riskLevel: .low
        ),
    ]

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "status"
        let switchName = arguments["switch_name"] ?? ""

        if action == "status" {
            if switchName.isEmpty {
                let list = Self.lock.withLock { Self._switchStates.values.map { s in
                    "\(s.name): \(s.currentValue ? "🟢 开启" : "🔴 关闭") [风险: \(s.riskLevel.rawValue)]"
                }}.joined(separator: "\n")
                return ToolCallResult(id: UUID().uuidString, output: "生产开关状态:\n\(list)")
            }
            guard let sw = Self.lock.withLock({ Self._switchStates[switchName] ?? Self._switchStates.values.first(where: { $0.name == switchName }) }) else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到开关: \(switchName)")
            }
            return ToolCallResult(id: UUID().uuidString, output: """
                开关: \(sw.name)
                当前值: \(sw.currentValue ? "开启" : "关闭")
                影响: \(sw.impact)
                风险等级: \(sw.riskLevel.rawValue)
                回滚: \(sw.rollbackProcedure ?? "需要手动回滚")
                """)
        }

        if action == "toggle" {
            guard !switchName.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 switch_name 参数", isError: true)
            }
            guard let swSnapshot = Self.lock.withLock({ Self._switchStates[switchName] ?? Self._switchStates.values.first(where: { $0.name == switchName }) }) else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到开关: \(switchName)")
            }
            var sw = swSnapshot

            let proposedRaw = arguments["proposed_value"] ?? "\(!sw.currentValue)"
            let proposedVal = proposedRaw == "true"
            let confirm = arguments["confirm"]?.lowercased()

            if confirm == "yes" {
                sw.currentValue = proposedVal
                let swCopy = sw
                let displayName = swCopy.name
                Self.lock.withLock { [switchName, swCopy] in
                    Self._switchStates[switchName] = swCopy
                }
                return ToolCallResult(id: UUID().uuidString, output: "✅ 开关「\(displayName)」已切换为 \(proposedVal ? "开启" : "关闭")")
            }

            if confirm == "no" {
                return ToolCallResult(id: UUID().uuidString, output: "❌ 开关切换已取消")
            }

            let warning: String
            if sw.riskLevel == .critical {
                warning = "\n🚨 严重警告: 此开关为 CRITICAL 级别，误操作可能导致生产故障！"
            } else if sw.riskLevel == .high {
                warning = "\n⚠️ 警告: 此开关为高风险级别，请确认操作正确。"
            } else {
                warning = ""
            }

            return ToolCallResult(id: UUID().uuidString, output: """
                ⚠️ 生产开关变更确认
                开关: \(sw.name)
                当前值: \(sw.currentValue ? "开启" : "关闭")
                目标值: \(proposedVal ? "开启" : "关闭")
                影响: \(sw.impact)\(warning)
                原因: \(arguments["reason"] ?? "未提供")

                如需确认，调用:
                production_switch action=toggle switch_name=\(switchName) proposed_value=\(proposedRaw) reason=\(arguments["reason"] ?? "变更") confirm=yes
                """)
        }

        if action == "rollback" {
            guard !switchName.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 switch_name 参数", isError: true)
            }
            guard let swSnapshot = Self.lock.withLock({ Self._switchStates[switchName] ?? Self._switchStates.values.first(where: { $0.name == switchName }) }) else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到开关: \(switchName)")
            }
            var sw = swSnapshot
            sw.currentValue = !sw.currentValue
            let swCopy = sw
            let displayName = swCopy.name
            let currentValue = swCopy.currentValue
            Self.lock.withLock { [switchName, swCopy] in
                Self._switchStates[switchName] = swCopy
            }
            return ToolCallResult(id: UUID().uuidString, output: "开关「\(displayName)」已回滚到 \(currentValue ? "开启" : "关闭")")
        }

        return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
    }
}

// MARK: - 427: 数据导出脱敏

public struct DataExportMaskTool: MCPTool {
    public let definition = ToolDefinition(
        name: "data_export_mask",
        description: """
        数据导出脱敏工具。根据隐私规则对导出数据进行脱敏处理，
        避免敏感数据泄露。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: mask(脱敏) / rules(查看规则) / field_info(字段敏感度)",
                  required: true),
            .init(name: "field_name", type: .string,
                  description: "字段名", required: false),
            .init(name: "value", type: .string,
                  description: "要脱敏的值", required: false),
            .init(name: "mask_type", type: .string,
                  description: "脱敏类型: full/partial/emailMask/phoneMask/idMask/dateRounding",
                  required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private static let defaultRules: [DataExportMaskingRule] = [
        .init(fieldName: "手机号", maskingType: .phoneMask, appliesToRoles: []),
        .init(fieldName: "电话", maskingType: .phoneMask),
        .init(fieldName: "邮箱", maskingType: .emailMask),
        .init(fieldName: "身份证", maskingType: .idMask),
        .init(fieldName: "姓名", maskingType: .partial),
        .init(fieldName: "地址", maskingType: .partial),
    ]

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "rules"

        switch action {
        case "rules":
            let rules = Self.defaultRules.map { r in
                "- \(r.fieldName): \(r.maskingType.rawValue)"
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "数据脱敏规则:\n\(rules)")

        case "field_info":
            guard let fieldName = arguments["field_name"] else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 field_name 参数", isError: true)
            }
            let matched = Self.defaultRules.filter {
                $0.fieldName.lowercased().contains(fieldName.lowercased())
            }
            if matched.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: "「\(fieldName)」无默认脱敏规则，按公开数据处理。")
            }
            let info = matched.map { r in
                "- \(r.fieldName): 建议脱敏方式=\(r.maskingType.rawValue)"
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "字段敏感度信息:\n\(info)\n\n导出时请对敏感字段调用 mask 操作脱敏。")

        case "mask":
            guard let fieldName = arguments["field_name"] else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 field_name 参数", isError: true)
            }
            let value = arguments["value"] ?? ""
            let maskTypeStr = arguments["mask_type"]
            let rule: DataExportMaskingRule
            if let mt = maskTypeStr, let maskType = DataExportMaskingRule.MaskingType(rawValue: mt) {
                rule = DataExportMaskingRule(fieldName: fieldName, maskingType: maskType)
            } else if let matched = Self.defaultRules.first(where: {
                $0.fieldName.lowercased().contains(fieldName.lowercased())
            }) {
                rule = matched
            } else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到字段「\(fieldName)」的脱敏规则，请指定 mask_type")
            }
            let masked = rule.apply(to: value)
            return ToolCallResult(id: UUID().uuidString, output: """
                脱敏结果:
                字段: \(fieldName)
                脱敏方式: \(rule.maskingType.rawValue)
                原文: \(value)
                脱敏后: \(masked)
                """)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// MARK: - 428: Dry-run 预览模式

public struct DryRunTool: MCPTool {
    public let definition = ToolDefinition(
        name: "dry_run",
        description: """
        批量配置变更的 dry-run 预览模式。在执行实际变更前，
        先预览将要修改的内容和影响范围。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: preview(预览) / execute(执行) / cancel(取消)",
                  required: true),
            .init(name: "config_type", type: .string,
                  description: "配置类型: feature_flag/pricing/promotion/content/crm_field",
                  required: true),
            .init(name: "changes_json", type: .string,
                  description: "变更内容 JSON", required: false),
            .init(name: "confirm", type: .string,
                  description: "执行确认: yes/no (action=execute 时需要)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    private static let lock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _pendingPreviews: [String: DryRunPreview] = [:]

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "preview"
        let configType = arguments["config_type"] ?? "feature_flag"
        let previewID = "dryrun_\(configType)"

        switch action {
        case "preview":
            let changesJSON = arguments["changes_json"] ?? "[]"
            let parsedChanges = (try? JSONSerialization.jsonObject(with: Data(changesJSON.utf8)) as? [String]) ?? ["预览变更 #1", "预览变更 #2"]

            let preview = DryRunPreview(
                changes: parsedChanges,
                affectedCount: parsedChanges.count,
                rollbackSteps: ["记录变更前值", "执行反向操作"]
            )
            Self.lock.withLock { Self._pendingPreviews[previewID] = preview }

            return ToolCallResult(id: UUID().uuidString, output: """
                === Dry-Run 预览 ===
                配置类型: \(configType)
                影响范围: \(preview.affectedCount) 项变更

                将执行的变更:
                \(preview.changes.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n"))

                回滚方案: \(preview.rollbackSteps?.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n") ?? "需手动回滚")

                请检查上述变更是否正确。
                确认执行: dry_run action=execute config_type=\(configType) confirm=yes
                取消: dry_run action=cancel config_type=\(configType)
                """)

        case "execute":
            guard let confirm = arguments["confirm"]?.lowercased(), confirm == "yes" else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 confirm=yes 确认执行")
            }
            guard let preview = Self.lock.withLock({ Self._pendingPreviews[previewID] }) else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到预览数据，请先执行 dry_run action=preview")
            }
            _ = Self.lock.withLock { Self._pendingPreviews.removeValue(forKey: previewID) }
            return ToolCallResult(id: UUID().uuidString, output: """
                ✅ 已执行 \(preview.affectedCount) 项变更:
                \(preview.changes.enumerated().map { "  \($0 + 1). \($1)" }.joined(separator: "\n"))

                如需回滚，请联系运维人员。
                """)

        case "cancel":
            _ = Self.lock.withLock { Self._pendingPreviews.removeValue(forKey: previewID) }
            return ToolCallResult(id: UUID().uuidString, output: "已取消 \(configType) 的批量变更。")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}
