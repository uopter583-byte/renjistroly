import Foundation
import os
import RenJistrolyModels

// MARK: - 413: CRM 操作审计

public struct CRMAuditTool: MCPTool {
    public let definition = ToolDefinition(
        name: "crm_audit",
        description: """
        CRM 字段修改审计。记录所有对 CRM 数据的修改操作，支持回滚追踪。
        所有修改必须附带修改原因。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: record(记录修改) / history(查看历史) / rollback(回滚)",
                  required: true),
            .init(name: "field", type: .string,
                  description: "CRM 字段名 (record/rollback 时需要)", required: false),
            .init(name: "old_value", type: .string,
                  description: "修改前的值", required: false),
            .init(name: "new_value", type: .string,
                  description: "修改后的值", required: false),
            .init(name: "reason", type: .string,
                  description: "修改原因 (record 时必须提供)", required: false),
            .init(name: "record_id", type: .string,
                  description: "审计记录 ID (rollback 时需要)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    private static let lock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _auditRecords: [CRMAuditRecord] = []

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "history"

        switch action {
        case "record":
            guard let field = arguments["field"] else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 field 参数", isError: true)
            }
            guard let reason = arguments["reason"], !reason.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "修改 CRM 字段必须提供 reason (修改原因)", isError: true)
            }
            let record = CRMAuditRecord(
                field: field,
                oldValue: arguments["old_value"] ?? "",
                newValue: arguments["new_value"] ?? "",
                reason: reason
            )
            Self.lock.withLock { Self._auditRecords.append(record) }
            return ToolCallResult(id: UUID().uuidString, output: """
                CRM 修改已审计记录:
                - 字段: \(field)
                - 旧值: \(arguments["old_value"] ?? "空")
                - 新值: \(arguments["new_value"] ?? "空")
                - 原因: \(reason)
                - 记录 ID: \(record.id)
                """)

        case "history":
            let snapshot = Self.lock.withLock { Array(Self._auditRecords) }
            if snapshot.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: "暂无 CRM 审计记录。")
            }
            let history = snapshot.reversed().enumerated().map { i, r in
                """
                \(i + 1). [\(r.timestamp)] 字段: \(r.field)
                    旧值: \(r.oldValue) → 新值: \(r.newValue)
                    原因: \(r.reason)
                    回滚: \(r.isRolledBack ? "是" : "否")
                    ID: \(r.id)
                """
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "CRM 审计记录:\n\(history)")

        case "rollback":
            guard let recordIDStr = arguments["record_id"],
                  let recordID = UUID(uuidString: recordIDStr) else {
                return ToolCallResult(id: UUID().uuidString, output: "无效记录 ID", isError: true)
            }
            let fieldName = Self.lock.withLock { () -> String? in
                guard let index = Self._auditRecords.firstIndex(where: { $0.id == recordID }) else { return nil }
                let prev = Self._auditRecords[index]
                Self._auditRecords[index] = CRMAuditRecord(
                    id: prev.id, timestamp: prev.timestamp,
                    field: prev.field, oldValue: prev.oldValue,
                    newValue: prev.newValue, operatorID: prev.operatorID,
                    reason: prev.reason, isRolledBack: true
                )
                return prev.field
            }
            guard let field = fieldName else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到指定记录 ID", isError: true)
            }
            return ToolCallResult(id: UUID().uuidString, output: "已回滚 CRM 修改: \(field)")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// =============================================================================

// MARK: - 416: CRM 字段语义映射

public struct CRMFieldMappingTool: MCPTool {
    public let definition = ToolDefinition(
        name: "crm_field_mapping",
        description: """
        查询 CRM 字段的语义映射。帮助 AI 理解 CRM 系统中各字段的含义、
        类型、必填性、敏感度等，正确填充客户资料。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: query(查询字段) / list(列出所有字段) / validate(验证值)",
                  required: true),
            .init(name: "field_name", type: .string,
                  description: "字段名 (显示名或内部键)", required: false),
            .init(name: "value", type: .string,
                  description: "要验证的值 (action=validate 时需要)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private static let defaultFields: [CRMFieldDefinition] = [
        .init(displayName: "客户姓名", internalKey: "customer_name", fieldType: .text, isRequired: true, sensitivity: .public),
        .init(displayName: "联系电话", internalKey: "phone", fieldType: .phone, isRequired: true, sensitivity: .pii),
        .init(displayName: "邮箱地址", internalKey: "email", fieldType: .email, isRequired: false, sensitivity: .pii),
        .init(displayName: "公司名称", internalKey: "company", fieldType: .text, isRequired: true, sensitivity: .internal),
        .init(displayName: "职位", internalKey: "title", fieldType: .text, isRequired: false, sensitivity: .public),
        .init(displayName: "预计成交额", internalKey: "estimated_amount", fieldType: .currency, isRequired: false, sensitivity: .sensitive),
        .init(displayName: "客户来源", internalKey: "source", fieldType: .dropdown, isRequired: false, sensitivity: .internal),
        .init(displayName: "行业", internalKey: "industry", fieldType: .dropdown, isRequired: false, sensitivity: .public),
        .init(displayName: "备注", internalKey: "notes", fieldType: .text, isRequired: false, sensitivity: .internal),
    ]

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "list"

        switch action {
        case "list":
            let fieldList = Self.defaultFields.map { f in
                let req = f.isRequired ? " [必填]" : ""
                let sens = " [\(f.sensitivity.rawValue)]"
                return "- \(f.displayName) (\(f.internalKey)): \(f.fieldType.rawValue)\(req)\(sens)"
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "CRM 字段映射:\n\(fieldList)")

        case "query":
            let query = arguments["field_name"]?.lowercased() ?? ""
            let matched = Self.defaultFields.filter {
                $0.displayName.lowercased().contains(query) || $0.internalKey.lowercased().contains(query)
            }
            if matched.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: "未找到匹配字段: \(query)")
            }
            let result = matched.map { f in
                """
                - 显示名: \(f.displayName)
                  内部键: \(f.internalKey)
                  类型: \(f.fieldType.rawValue)
                  必填: \(f.isRequired ? "是" : "否")
                  敏感度: \(f.sensitivity.rawValue)
                  验证规则: \(f.validationRules.isEmpty ? "无" : f.validationRules.joined(separator: ", "))
                """
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: result)

        case "validate":
            guard let fieldName = arguments["field_name"],
                  let value = arguments["value"] else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 field_name 和 value 参数", isError: true)
            }
            guard let field = Self.defaultFields.first(where: {
                $0.displayName == fieldName || $0.internalKey == fieldName
            }) else {
                return ToolCallResult(id: UUID().uuidString, output: "未知字段: \(fieldName)", isError: true)
            }
            var issues: [String] = []
            if field.isRequired && value.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append("字段「\(field.displayName)」为必填项")
            }
            switch field.fieldType {
            case .email where !value.contains("@") && !value.isEmpty:
                issues.append("邮箱格式无效")
            case .phone:
                let digits = value.filter(\.isNumber)
                if digits.count < 7 && !value.isEmpty {
                    issues.append("电话号码格式无效（至少 7 位数字）")
                }
            case .currency:
                if Double(value) == nil && !value.isEmpty {
                    issues.append("金额格式无效")
                }
            default: break
            }
            if issues.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: "字段「\(field.displayName)」值「\(value)」验证通过 ✅")
            }
            return ToolCallResult(id: UUID().uuidString, output: "字段验证问题:\n" + issues.map { "- \($0)" }.joined(separator: "\n"))

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// MARK: - 417: 销售阶段感知

public struct SalesStageTool: MCPTool {
    public let definition = ToolDefinition(
        name: "sales_stage",
        description: """
        检查客户所处销售阶段，确定哪些操作在当前阶段允许执行。
        例如在需求分析阶段才能发报价。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: check(检查操作) / set(设置阶段) / info(阶段说明)",
                  required: true),
            .init(name: "proposed_action", type: .string,
                  description: "要检查的操作: search/view/add_note/send_email/schedule_meeting/generate_quote/modify_amount",
                  required: false),
            .init(name: "stage", type: .string,
                  description: "销售阶段: prospecting/qualification/needsAnalysis/proposal/negotiation/closedWon/closedLost",
                  required: false),
            .init(name: "customer_id", type: .string,
                  description: "客户 ID (set 操作时需要)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private static let lock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _customerStages: [String: SalesStageContext] = [:]

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "info"

        switch action {
        case "info":
            let stageRaw = arguments["stage"] ?? "prospecting"
            guard let stage = SalesStageContext.Stage(rawValue: stageRaw) else {
                return ToolCallResult(id: UUID().uuidString, output: "无效阶段: \(stageRaw)", isError: true)
            }
            let ctx = SalesStageContext.defaultForStage(stage)
            return ToolCallResult(id: UUID().uuidString, output: """
                销售阶段: \(stage.title) (\(stageRaw))
                - 成交概率: \(ctx.probability)%
                - 允许的操作: \(ctx.allowedActions.joined(separator: ", "))
                - 所需文档: \(ctx.requiredDocuments.isEmpty ? "无" : ctx.requiredDocuments.joined(separator: ", "))
                """)

        case "check":
            guard let proposedAction = arguments["proposed_action"] else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 proposed_action 参数", isError: true)
            }
            let customerID = arguments["customer_id"] ?? "default"
            let stageCtx = Self.lock.withLock { Self._customerStages[customerID] } ?? .defaultForStage(.prospecting)

            if stageCtx.allows(action: proposedAction) {
                return ToolCallResult(id: UUID().uuidString, output: """
                    ✅ 操作「\(proposedAction)」在当前阶段「\(stageCtx.stage.title)」允许执行。
                    """)
            }
            return ToolCallResult(id: UUID().uuidString, output: """
                🚫 操作「\(proposedAction)」在当前阶段「\(stageCtx.stage.title)」不允许执行。
                当前阶段允许的操作: \(stageCtx.allowedActions.joined(separator: ", "))
                如需执行，请先推进销售阶段。
                """)

        case "set":
            guard let customerID = arguments["customer_id"] else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 customer_id 参数", isError: true)
            }
            let stageRaw = arguments["stage"] ?? "prospecting"
            guard let stage = SalesStageContext.Stage(rawValue: stageRaw) else {
                return ToolCallResult(id: UUID().uuidString, output: "无效阶段: \(stageRaw)", isError: true)
            }
            let ctx = SalesStageContext.defaultForStage(stage)
            Self.lock.withLock { Self._customerStages[customerID] = ctx }
            return ToolCallResult(id: UUID().uuidString, output: "客户 \(customerID) 阶段已设为: \(stage.title)")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// MARK: - 418: 金额修改确认

public struct AmountChangeConfirmTool: MCPTool {
    public let definition = ToolDefinition(
        name: "amount_change_confirm",
        description: """
        金额修改的二次确认。在更新机会金额、报价金额时，
        自动计算变动比例并提示确认。
        """,
        parameters: [
            .init(name: "entity_type", type: .string,
                  description: "实体类型: opportunity(机会) / quote(报价) / contract(合同)",
                  required: true),
            .init(name: "entity_id", type: .string,
                  description: "实体 ID", required: true),
            .init(name: "old_amount", type: .string,
                  description: "原金额", required: true),
            .init(name: "new_amount", type: .string,
                  description: "新金额", required: true),
            .init(name: "reason", type: .string,
                  description: "修改原因", required: true),
            .init(name: "confirm", type: .string,
                  description: "确认: yes/no", required: false),
            .init(name: "currency", type: .string,
                  description: "币种，默认 CNY", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    private static let lock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _pendingChanges: [String: AmountChangeRequest] = [:]

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let entityType = arguments["entity_type"] ?? "opportunity"
        let entityID = arguments["entity_id"] ?? "unknown"
        let confirm = arguments["confirm"]?.lowercased()

        let changeID = "\(entityType)_\(entityID)"

        if confirm == "yes" {
            let result = Self.lock.withLock { () -> String? in
                guard let req = Self._pendingChanges.removeValue(forKey: changeID) else {
                    return nil
                }
                return """
                ✅ 金额修改已确认
                \(entityType) \(entityID): \(req.currency) \(String(format: "%.2f", req.oldAmount)) → \(String(format: "%.2f", req.newAmount))
                变动: \(String(format: "%.1f", req.changePercent))%
                原因: \(req.reason)
                """
            }
            guard let output = result else {
                return ToolCallResult(id: UUID().uuidString, output: "确认超时或无效。请重新发起修改。", isError: true)
            }
            return ToolCallResult(id: UUID().uuidString, output: output)
        }

        if confirm == "no" {
            _ = Self.lock.withLock { Self._pendingChanges.removeValue(forKey: changeID) }
            return ToolCallResult(id: UUID().uuidString, output: "❌ 金额修改已取消")
        }

        guard let oldStr = arguments["old_amount"], let oldVal = Double(oldStr),
              let newStr = arguments["new_amount"], let newVal = Double(newStr) else {
            return ToolCallResult(id: UUID().uuidString, output: "需要有效的 old_amount 和 new_amount 参数", isError: true)
        }
        guard let reason = arguments["reason"], !reason.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "金额修改必须提供原因", isError: true)
        }

        let req = AmountChangeRequest(
            entityID: entityID,
            entityType: entityType,
            oldAmount: oldVal,
            newAmount: newVal,
            currency: arguments["currency"] ?? "CNY",
            reason: reason
        )
        Self.lock.withLock { Self._pendingChanges[changeID] = req }

        let changePercent = req.changePercent
        let warning = abs(changePercent) > 50 ? "\n⚠️ 警告: 变动幅度超过 50%，请仔细确认！" : ""

        return ToolCallResult(id: UUID().uuidString, output: """
            ⚠️ 金额修改确认
            \(entityType) \(entityID)
            原金额: \(req.currency) \(String(format: "%.2f", req.oldAmount))
            新金额: \(req.currency) \(String(format: "%.2f", req.newAmount))
            变动: \(String(format: "%.1f", changePercent))%\(warning)
            原因: \(reason)

            请确认:
            调用 amount_change_confirm entity_type=\(entityType) entity_id=\(entityID) old_amount=\(oldVal) new_amount=\(newVal) reason=\(reason) confirm=yes
            或取消:
            调用 amount_change_confirm entity_type=\(entityType) entity_id=\(entityID) confirm=no
            """)
    }
}

// MARK: - 421: 报价模板匹配

public struct QuoteTemplateTool: MCPTool {
    public let definition = ToolDefinition(
        name: "quote_template",
        description: """
        根据销售阶段和金额匹配合适的报价模板。避免使用错误模板。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: match(匹配模板) / list(列出模板) / info(模板详情)",
                  required: true),
            .init(name: "amount", type: .string,
                  description: "报价金额", required: false),
            .init(name: "stage", type: .string,
                  description: "当前销售阶段", required: false),
            .init(name: "template_id", type: .string,
                  description: "模板 ID (info 操作时)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private static let templates: [QuoteTemplate] = [
        .init(
            name: "标准报价模板",
            applicableStages: [.proposal, .negotiation],
            minAmount: 0, maxAmount: 100000,
            requiredClauses: ["价格条款", "交付期限", "付款方式"],
            description: "适用于中小金额标准报价"
        ),
        .init(
            name: "大额报价模板",
            applicableStages: [.proposal, .negotiation],
            minAmount: 100000, maxAmount: 1000000,
            requiredClauses: ["价格条款", "交付期限", "付款方式", "违约责任", "保密条款"],
            description: "适用于大额交易，包含法务条款"
        ),
        .init(
            name: "战略合作报价",
            applicableStages: [.negotiation],
            minAmount: 1000000, maxAmount: nil,
            requiredClauses: ["价格条款", "交付期限", "付款方式", "违约责任", "保密条款", "SLA", "争议解决"],
            description: "适用于战略合作级别的大客户报价"
        ),
        .init(
            name: "续约报价模板",
            applicableStages: [.needsAnalysis, .proposal],
            minAmount: nil, maxAmount: nil,
            requiredClauses: ["续约价格", "续约期限", "服务范围变更说明"],
            description: "适用于老客户续约场景"
        ),
    ]

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "list"

        switch action {
        case "list":
            let list = Self.templates.map { t in
                let amountRange: String
                if let min = t.minAmount, let max = t.maxAmount {
                    amountRange = "¥\(Int(min))~¥\(Int(max))"
                } else if let min = t.minAmount {
                    amountRange = "≥¥\(Int(min))"
                } else if let max = t.maxAmount {
                    amountRange = "≤¥\(Int(max))"
                } else {
                    amountRange = "不限"
                }
                return "- \(t.name) (ID: \(t.id))\n  金额范围: \(amountRange)\n  适用阶段: \(t.applicableStages.map(\.rawValue).joined(separator: ", "))"
            }.joined(separator: "\n\n")
            return ToolCallResult(id: UUID().uuidString, output: "可用报价模板:\n\(list)")

        case "match":
            let stageRaw = arguments["stage"] ?? "proposal"
            guard let stage = SalesStageContext.Stage(rawValue: stageRaw) else {
                return ToolCallResult(id: UUID().uuidString, output: "无效销售阶段: \(stageRaw)", isError: true)
            }
            let amount = Double(arguments["amount"] ?? "0") ?? 0

            let matched = Self.templates.filter { $0.matches(amount: amount, stage: stage) }
            if matched.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: "当前条件（金额: \(amount), 阶段: \(stageRaw)）无匹配模板。")
            }
            let result = matched.map { t in
                "- \(t.name): \(t.description)"
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "匹配的报价模板:\n\(result)")

        case "info":
            guard let tid = arguments["template_id"] else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 template_id 参数", isError: true)
            }
            guard let t = Self.templates.first(where: { $0.id == tid }) else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到模板: \(tid)", isError: true)
            }
            return ToolCallResult(id: UUID().uuidString, output: """
                模板详情:
                - 名称: \(t.name)
                - 说明: \(t.description)
                - 适用阶段: \(t.applicableStages.map(\.rawValue).joined(separator: ", "))
                - 金额范围: \(t.minAmount.map { "¥\(Int($0))" } ?? "不限") ~ \(t.maxAmount.map { "¥\(Int($0))" } ?? "不限")
                - 必需条款: \(t.requiredClauses.joined(separator: ", "))
                - 语言: \(t.language)
                """)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// MARK: - 422: 合同审批流程

public struct ContractApprovalTool: MCPTool {
    public let definition = ToolDefinition(
        name: "contract_approval",
        description: """
        管理合同审批流程。根据合同金额自动生成审批链，
        跟踪每个审批步骤。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: create(创建审批) / status(查看状态) / approve(审批通过) / reject(驳回)",
                  required: true),
            .init(name: "contract_id", type: .string,
                  description: "合同 ID", required: false),
            .init(name: "amount", type: .string,
                  description: "合同金额 (action=create 时需要)", required: false),
            .init(name: "step_id", type: .string,
                  description: "审批步骤 ID (approve/reject 时)", required: false),
            .init(name: "notes", type: .string,
                  description: "审批备注", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    private static let lock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _approvalFlows: [String: ContractApprovalFlow] = [:]

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "status"

        switch action {
        case "create":
            let contractID = arguments["contract_id"] ?? UUID().uuidString
            guard let amountStr = arguments["amount"], let amount = Double(amountStr) else {
                return ToolCallResult(id: UUID().uuidString, output: "需要有效的 amount 参数", isError: true)
            }
            let flow = ContractApprovalFlow.generateChain(amount: amount, contractID: contractID)
            Self.lock.withLock { Self._approvalFlows[contractID] = flow }

            let chainDesc = flow.approvalChain.enumerated().map { i, step in
                "\(i + 1). \(step.role)\(step.isCompleted ? " [已完成]" : "")"
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: """
                合同审批链已创建:
                合同: \(contractID)
                金额: ¥\(String(format: "%.2f", amount))
                状态: \(flow.status.rawValue)
                审批链:
                \(chainDesc)
                """)

        case "status":
            guard let contractID = arguments["contract_id"],
                  let flow = Self.lock.withLock({ Self._approvalFlows[contractID] }) else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到合同审批: \(arguments["contract_id"] ?? "未知")")
            }
            let chainDesc = flow.approvalChain.enumerated().map { i, step in
                let status = step.isCompleted ? "✅ \(step.decidedAt ?? Date())" : "⏳ 待审批"
                let notes = step.notes.map { " (\($0))" } ?? ""
                return "\(i + 1). \(step.role) - \(status)\(notes)"
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: """
                合同审批状态:
                合同: \(contractID)
                金额: ¥\(String(format: "%.2f", flow.amount))
                状态: \(flow.status.rawValue)
                当前步骤: \(flow.currentStep + 1)/\(flow.approvalChain.count)
                审批链:
                \(chainDesc)
                """)

        case "approve":
            guard let contractID = arguments["contract_id"],
                  let flowSnapshot = Self.lock.withLock({ Self._approvalFlows[contractID] }) else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到合同审批", isError: true)
            }
            var flow = flowSnapshot
            let stepIDStr = arguments["step_id"]
            if let stepID = stepIDStr.flatMap({ UUID(uuidString: $0) }),
               let idx = flow.approvalChain.firstIndex(where: { $0.id == stepID }) {
                flow.approvalChain[idx] = ContractApprovalFlow.ApprovalStep(
                    id: flow.approvalChain[idx].id,
                    role: flow.approvalChain[idx].role,
                    approverName: flow.approvalChain[idx].approverName,
                    isCompleted: true,
                    decidedAt: Date(),
                    notes: arguments["notes"]
                )
            } else if flow.currentStep < flow.approvalChain.count {
                flow.approvalChain[flow.currentStep] = ContractApprovalFlow.ApprovalStep(
                    id: flow.approvalChain[flow.currentStep].id,
                    role: flow.approvalChain[flow.currentStep].role,
                    isCompleted: true,
                    decidedAt: Date(),
                    notes: arguments["notes"]
                )
            }
            flow.currentStep += 1
            if flow.currentStep >= flow.approvalChain.count {
                flow.status = .approved
            } else {
                flow.status = .inProgress
            }
            let updatedFlow = flow
            let currentStep = updatedFlow.currentStep
            let stepCount = updatedFlow.approvalChain.count
            Self.lock.withLock { [contractID, updatedFlow] in
                Self._approvalFlows[contractID] = updatedFlow
            }
            return ToolCallResult(id: UUID().uuidString, output: "合同 \(contractID) 审批已推进到步骤 \(currentStep + 1)/\(stepCount)")

        case "reject":
            guard let contractID = arguments["contract_id"],
                  let flowSnapshot = Self.lock.withLock({ Self._approvalFlows[contractID] }) else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到合同审批", isError: true)
            }
            var flow = flowSnapshot
            flow.status = .rejected
            let rejectedFlow = flow
            Self.lock.withLock { [contractID, rejectedFlow] in
                Self._approvalFlows[contractID] = rejectedFlow
            }
            return ToolCallResult(id: UUID().uuidString, output: "合同 \(contractID) 已被驳回。原因: \(arguments["notes"] ?? "未提供")")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}
