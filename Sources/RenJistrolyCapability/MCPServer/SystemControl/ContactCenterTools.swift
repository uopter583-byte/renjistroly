import Foundation
import os
import RenJistrolyModels

// =============================================================================
// 客服场景工具组 — Contact Center
// 406: SessionContext, 407: ScriptStrategy, 410: SentimentAnalysis,
// 412: TranslateWithTone, 423: SpeakerDiarization
// =============================================================================

// MARK: - 406: 会话上下文管理

public struct SessionContextTool: MCPTool {
    public let definition = ToolDefinition(
        name: "session_context",
        description: """
        读取当前客户会话上下文，包括客户信息、会话阶段、渠道、上下文变量等。
        防止 AI 丢失客户上下文。适用于客服读取客户会话摘要。
        """,
        parameters: [
            .init(name: "session_id", type: .string,
                  description: "会话 ID，为空时自动读取当前活跃会话", required: false),
            .init(name: "action", type: .string,
                  description: "操作: read(读取) / set_stage(设置阶段) / set_variable(设置变量) / list(列表)",
                  required: true),
            .init(name: "stage", type: .string,
                  description: "会话阶段: greeting/inquiry/issueResolution/followUp/closed", required: false),
            .init(name: "key", type: .string,
                  description: "上下文变量名 (action=set_variable 时)", required: false),
            .init(name: "value", type: .string,
                  description: "上下文变量值 (action=set_variable 时)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private static let contextLock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _activeContexts: [String: SessionContext] = [:]

    private static var activeContexts: [String: SessionContext] {
        get { contextLock.withLock { _activeContexts } }
        set { contextLock.withLock { _activeContexts = newValue } }
    }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "read"
        let sessionID = arguments["session_id"] ?? Self.contextLock.withLock { Self._activeContexts.keys.first } ?? UUID().uuidString

        switch action {
        case "read":
            if let ctx = Self.contextLock.withLock({ Self._activeContexts[sessionID] }) {
                return ToolCallResult(
                    id: UUID().uuidString,
                    output: """
                    当前会话上下文:
                    - 会话 ID: \(ctx.sessionID)
                    - 客户 ID: \(ctx.customerID ?? "未知")
                    - 客户姓名: \(ctx.customerName ?? "未知")
                    - 渠道: \(ctx.channel)
                    - 工单 ID: \(ctx.ticketID ?? "无")
                    - 阶段: \(ctx.stage.rawValue)
                    - 上下文变量: \(ctx.contextVariables.isEmpty ? "无" : ctx.contextVariables.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))
                    """
                )
            }
            return ToolCallResult(id: UUID().uuidString, output: "未找到活跃会话。使用 action=set_variable 创建新会话。")

        case "list":
            let list = Self.contextLock.withLock { Self._activeContexts.values.map {
                "\($0.sessionID) - \($0.customerName ?? "未知") - \($0.stage.rawValue)"
            }}.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: list.isEmpty ? "无活跃会话" : list)

        case "set_stage":
            guard let stageRaw = arguments["stage"],
                  let stage = SessionContext.SessionStage(rawValue: stageRaw) else {
                return ToolCallResult(id: UUID().uuidString, output: "无效阶段: \(arguments["stage"] ?? "")", isError: true)
            }
            Self.contextLock.withLock {
                var ctx = Self._activeContexts[sessionID] ?? SessionContext(sessionID: sessionID)
                ctx.stage = stage
                Self._activeContexts[sessionID] = ctx
            }
            return ToolCallResult(id: UUID().uuidString, output: "会话 \(sessionID) 阶段已更新为: \(stageRaw)")

        case "set_variable":
            guard let key = arguments["key"], let value = arguments["value"] else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 key 和 value 参数", isError: true)
            }
            Self.contextLock.withLock {
                var ctx = Self._activeContexts[sessionID] ?? SessionContext(sessionID: sessionID)
                ctx.contextVariables[key] = value
                Self._activeContexts[sessionID] = ctx
            }
            return ToolCallResult(id: UUID().uuidString, output: "会话变量已设置: \(key)=\(value)")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// MARK: - 407: 话术策略层

public struct ScriptStrategyTool: MCPTool {
    public let definition = ToolDefinition(
        name: "script_strategy",
        description: """
        检查公司话术策略边界。确保客服回复在允许的话术模板范围内，
        检查组词、必要元素，防止越界回复。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: check(检查回复) / list_templates(列表) / load(加载策略)",
                  required: true),
            .init(name: "strategy_name", type: .string,
                  description: "策略名称", required: false),
            .init(name: "reply_text", type: .string,
                  description: "要检查的回复文本 (action=check 时)", required: false),
            .init(name: "stage", type: .string,
                  description: "当前会话阶段", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private static let defaultStrategies: [String: ScriptStrategy] = [
        "standard_cs": ScriptStrategy(
            name: "标准客服话术",
            applicableStages: [.inquiry, .issueResolution],
            allowedTemplates: ["greeting", "apology", "clarification", "resolution", "follow_up"],
            restrictedPhrases: ["退款", "赔偿", "投诉上级", "无法处理", "不关我事"],
            requiredElements: ["称呼", "解决方案", "结束语"]
        ),
        "complaint_handling": ScriptStrategy(
            name: "投诉处理话术",
            applicableStages: [.issueResolution, .followUp],
            allowedTemplates: ["apology", "clarification", "resolution", "escalation"],
            restrictedPhrases: ["不可能", "你错了", "这是规定", "没办法"],
            requiredElements: ["道歉", "问题确认", "解决方案", "时间承诺"]
        ),
    ]

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "list_templates"

        switch action {
        case "list_templates":
            let list = Self.defaultStrategies.values.map { strategy in
                """
                - \(strategy.name) (ID: \(strategy.strategyID))
                  适用阶段: \(strategy.applicableStages.map(\.rawValue).joined(separator: ", "))
                  允许模板: \(strategy.allowedTemplates.joined(separator: ", "))
                  限制词组: \(strategy.restrictedPhrases.joined(separator: ", "))
                  必需元素: \(strategy.requiredElements.joined(separator: ", "))
                """
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "可用话术策略:\n\(list)")

        case "load":
            guard let name = arguments["strategy_name"],
                  let strategy = Self.defaultStrategies[name] else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到策略: \(arguments["strategy_name"] ?? "")", isError: true)
            }
            return ToolCallResult(id: UUID().uuidString, output: """
                已加载话术策略: \(strategy.name)
                允许的模板: \(strategy.allowedTemplates.joined(separator: ", "))
                限制词组: \(strategy.restrictedPhrases.joined(separator: ", "))
                必需元素: \(strategy.requiredElements.joined(separator: ", "))
                """)

        case "check":
            guard let reply = arguments["reply_text"], !reply.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要提供 reply_text 参数", isError: true)
            }
            let stageRaw = arguments["stage"] ?? "inquiry"
            let stage = SessionContext.SessionStage(rawValue: stageRaw) ?? .inquiry
            let applicable = Self.defaultStrategies.values.filter { $0.applicableStages.contains(stage) }
            guard let strategy = applicable.first else {
                return ToolCallResult(id: UUID().uuidString, output: "当前阶段 \(stageRaw) 无适用话术策略")
            }

            var warnings: [String] = []
            for phrase in strategy.restrictedPhrases {
                if reply.contains(phrase) {
                    warnings.append("限制词组「\(phrase)」出现在回复中")
                }
            }
            for element in strategy.requiredElements {
                if !reply.contains(element) {
                    warnings.append("缺少必需元素「\(element)」")
                }
            }
            for template in strategy.allowedTemplates {
                if reply.contains(template) || reply.lowercased().contains(template.replacingOccurrences(of: "_", with: " ")) {
                }
            }

            let isCompliant = warnings.isEmpty
            let output = isCompliant
                ? "回复符合话术策略「\(strategy.name)」，可以发送。"
                : "回复存在以下问题:\n" + warnings.map { "- \($0)" }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: output + "\n合规: \(isCompliant ? "是" : "否")")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// MARK: - 410: 情绪分析

public struct SentimentAnalysisTool: MCPTool {
    public let definition = ToolDefinition(
        name: "sentiment_analysis",
        description: """
        分析客户消息的情绪和强度，支持多维度情绪检测（愤怒、挫败感、紧急度等）。
        用于客服识别需要优先处理的投诉。
        """,
        parameters: [
            .init(name: "text", type: .string,
                  description: "要分析的文本内容", required: true),
            .init(name: "action", type: .string,
                  description: "操作: analyze(分析) / summary(摘要)",
                  required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let text = arguments["text"], !text.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "需要提供 text 参数", isError: true)
        }

        let action = arguments["action"] ?? "analyze"

        let lowerText = text.lowercased()
        let angerWords = ["生气", "愤怒", "气死", "投诉", "差评", "太过分", "不负责任", "可恶", "怒"]
        let frustrationWords = ["烦", "受不了", "这么久", "还没解决", "第几次", "效率", "失望", "敷衍"]
        let urgencyWords = ["马上", "立刻", "紧急", "现在就要", "不能再等", "快"]
        let positiveWords = ["谢谢", "感谢", "满意", "不错", "好", "可以", "没问题", "方便"]

        let anger = Float(angerWords.filter { lowerText.contains($0) }.count) / Float(max(angerWords.count, 1)) * 2.0
        let frustration = Float(frustrationWords.filter { lowerText.contains($0) }.count) / Float(max(frustrationWords.count, 1)) * 2.0
        let urgency = Float(urgencyWords.filter { lowerText.contains($0) }.count) / Float(max(urgencyWords.count, 1)) * 2.0
        let positivity = Float(positiveWords.filter { lowerText.contains($0) }.count) / Float(max(positiveWords.count, 1)) * 2.0

        let intensity = min(max(anger, frustration, urgency, 0), 1.0)
        let overall: SentimentResult.SentimentLabel
        if intensity > 0.6 && anger > 0.3 { overall = .angry }
        else if intensity > 0.5 && frustration > 0.4 { overall = .frustrated }
        else if urgency > 0.4 { overall = .urgent }
        else if positivity > 0.3 { overall = .positive }
        else if intensity > 0.3 { overall = .negative }
        else { overall = .neutral }

        let keywords = (angerWords + frustrationWords + urgencyWords + positiveWords)
            .filter { lowerText.contains($0) }

        let result = SentimentResult(
            overall: overall,
            intensity: min(intensity, 1.0),
            anger: min(anger, 1.0),
            joy: min(positivity, 1.0),
            frustration: min(frustration, 1.0),
            contextualKeywords: keywords
        )

        if action == "summary" {
            return ToolCallResult(id: UUID().uuidString, output: result.summary)
        }

        return ToolCallResult(id: UUID().uuidString, output: """
            情绪分析结果:
            - 总体: \(result.overall.rawValue)
            - 强度: \(String(format: "%.2f", result.intensity))
            - 愤怒: \(String(format: "%.2f", result.anger))
            - 挫败感: \(String(format: "%.2f", result.frustration))
            - 紧急度: \(String(format: "%.2f", urgency))
            - 正面度: \(String(format: "%.2f", positivity))
            - 触发词: \(keywords.isEmpty ? "无" : keywords.joined(separator: ", "))
            \(result.requiresPriorityHandling ? "\n⚠️ 需要优先处理！" : "")
            """)
    }
}

// MARK: - 412: 语气保留翻译

public struct TranslateWithToneTool: MCPTool {
    public let definition = ToolDefinition(
        name: "translate_with_tone",
        description: """
        翻译文本并保留语气风格。支持礼貌/专业/友好/同理性等多种语气。
        客服场景下确保翻译后的消息保留原意的礼貌程度。
        """,
        parameters: [
            .init(name: "text", type: .string, description: "要翻译的文本", required: true),
            .init(name: "source_language", type: .string, description: "源语言，如 zh-CN", required: false),
            .init(name: "target_language", type: .string, description: "目标语言，如 en", required: true),
            .init(name: "tone", type: .string,
                  description: "语气: polite(礼貌)/professional(专业)/friendly(友好)/casual(随意)/empathetic(共情)",
                  required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let text = arguments["text"], !text.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "需要提供 text 参数", isError: true)
        }
        let sourceLang = arguments["source_language"] ?? "自动检测"
        let targetLang = arguments["target_language"] ?? "en"
        let toneRaw = arguments["tone"] ?? "polite"

        let options = TranslationOptions(
            sourceLanguage: sourceLang,
            targetLanguage: targetLang,
            tone: TranslationOptions.TranslationTone(rawValue: toneRaw) ?? .polite,
            preserveFormality: true,
            preserveEmoji: true
        )

        return ToolCallResult(id: UUID().uuidString, output: """
            翻译请求:
            - 源语言: \(options.sourceLanguage)
            - 目标语言: \(options.targetLanguage)
            - 语气: \(options.tone.rawValue)
            - 保留正式度: \(options.preserveFormality)
            - 保留表情: \(options.preserveEmoji)

            原文: \(text)

            [翻译结果需 LLM 处理]
            翻译提示: 请将以下文本以「\(options.tone.rawValue)」语气翻译为 \(targetLang)，保留正式度和表情符号。

            原文: \(text)
            """)
    }
}

// MARK: - 423: 说话人分离

public struct SpeakerDiarizationTool: MCPTool {
    public let definition = ToolDefinition(
        name: "speaker_diarization",
        description: """
        对通话记录进行说话人分离，区分客服/客户/经理等角色。
        支持结构化通话纪要生成。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: segment(分段) / summary(生成摘要) / export(导出)",
                  required: true),
            .init(name: "transcript_text", type: .string,
                  description: "完整通话文本", required: false),
            .init(name: "role", type: .string,
                  description: "当前用户角色: agent/customer/manager (用于标识说话人)",
                  required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "segment"
        let transcript = arguments["transcript_text"] ?? ""
        let role = arguments["role"] ?? "agent"

        switch action {
        case "segment":
            guard !transcript.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要提供通话文本 (transcript_text)")
            }
            let lines = transcript.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            var segments: [String] = []
            let speakers = ["agent", "customer"]
            for (i, line) in lines.enumerated() {
                let speaker = speakers[i % 2]
                segments.append("[\(speaker)] \(line)")
            }
            let output = segments.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "说话人分离结果 (当前角色: \(role)):\n\n\(output)")

        case "summary":
            guard !transcript.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要提供通话文本")
            }
            return ToolCallResult(id: UUID().uuidString, output: """
                通话纪要 (说话人: \(role)):
                全文: \(transcript.prefix(100))...

                [完整通话纪要需要 LLM 处理]
                请提取:
                1. 客户核心诉求
                2. 已确认的信息
                3. 待办事项
                4. 情绪要点
                """)

        case "export":
            return ToolCallResult(id: UUID().uuidString, output: """
                通话纪要导出:
                格式: 结构化文本
                包含: 说话人标注、时间戳（如有）、内容摘要

                使用方法: 先将通话文本通过 segment 处理，再用 summary 生成摘要。
                """)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}
