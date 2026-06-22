import Foundation
import RenJistrolyModels
import OSLog

public actor SmartRouter {
    private var localBackend: LocalMLXBackend
    private var claudeCodeBackend: ClaudeCodeCLIBackend
    private var codexBackend: CodexCLIBackend
    private var anthropicBackend: CloudAnthropicBackend?
    private var openAIBackend: CloudOpenAIBackend?
    private var googleBackend: CloudGoogleBackend?
    private var openAICompatibleBackends: [LLMProvider: CloudOpenAICompatibleBackend] = [:]
    private let routingRules: RoutingRules
    private let cache: LMCache

    public init(
        localBackend: LocalMLXBackend = LocalMLXBackend(),
        claudeCodeBackend: ClaudeCodeCLIBackend = ClaudeCodeCLIBackend(),
        codexBackend: CodexCLIBackend = CodexCLIBackend(),
        anthropicBackend: CloudAnthropicBackend? = nil,
        openAIBackend: CloudOpenAIBackend? = nil,
        googleBackend: CloudGoogleBackend? = nil,
        routingRules: RoutingRules = RoutingRules(),
        cache: LMCache = LMCache()
    ) {
        self.localBackend = localBackend
        self.claudeCodeBackend = claudeCodeBackend
        self.codexBackend = codexBackend
        self.anthropicBackend = anthropicBackend
        self.openAIBackend = openAIBackend
        self.googleBackend = googleBackend
        self.routingRules = routingRules
        self.cache = cache
    }

    public func configureCloud(provider: LLMProvider, apiKey: String, baseURL: String? = nil) {
        switch provider {
        case .anthropic:
            anthropicBackend = CloudAnthropicBackend(apiKey: apiKey)
        case .openAI:
            openAIBackend = CloudOpenAIBackend(apiKey: apiKey)
        case .google:
            googleBackend = CloudGoogleBackend(apiKey: apiKey)
        case .deepseek, .ollama, .groq, .mistral, .cohere, .replicate, .togetherAI, .perplexity, .xAI, .custom:
            let url = baseURL ?? provider.defaultBaseURL
            guard let url else {
                os_log(.error, "[SmartRouter] %{public}s 需要 baseURL，跳过配置", provider.displayName)
                return
            }
            openAICompatibleBackends[provider] = CloudOpenAICompatibleBackend(provider: provider, baseURL: url, apiKey: apiKey)
        default:
            os_log(.error, "[SmartRouter] 不支持的云端 provider: %{public}s", "\(provider)")
        }
    }

    public func getBestAvailableBackend(
        for messages: [Message],
        context: ProjectContext?
    ) async -> (any LLMBackend, LLMConfiguration) {
        let complexity = assessComplexity(messages, context: context)
        let decisions = routeDecisions(complexity: complexity, messages: messages, context: context)

        for decision in decisions {
            guard let backend = await getBackend(for: decision.provider) else { continue }
            guard await backend.isAvailable else { continue }
            let config = buildConfig(provider: decision.provider, complexity: complexity)
            return (backend, config)
        }

        os_log(.default, "[SmartRouter] 无可用云端后端，回退到本地模型")
        return (localBackend, .defaultLocal)
    }

    public struct FallbackResult: Sendable {
        public let message: Message
        public let provider: LLMProvider
        public let attempts: Int
    }

    public func chatWithFallback(
        messages: [Message],
        tools: [ToolDefinition]? = nil,
        delegate: LLMStreamingDelegate? = nil,
        context: ProjectContext?
    ) async throws -> FallbackResult {
        let complexity = assessComplexity(messages, context: context)
        let decisions = routeDecisions(complexity: complexity, messages: messages, context: context)

        // Tier 1-3: check LMCache
        if complexity.level == .simple, let primary = decisions.first {
            let config = buildConfig(provider: primary.provider, complexity: complexity)
            let key = await cache.cacheKey(messages: messages, config: config)
            if let cached = await cache.get(key: key) {
                let msg = Message(role: .assistant, content: [.text(cached.text)])
                return FallbackResult(message: msg, provider: LLMProvider(rawValue: cached.provider) ?? .localMLX, attempts: 0)
            }
        }

        var errors: [String] = []
        var attempts = 0

        for decision in decisions {
            try Task.checkCancellation()
            guard let backend = await getBackend(for: decision.provider) else {
                errors.append("[\(decision.provider.rawValue)] 后端未配置")
                continue
            }
            guard await backend.isAvailable else {
                errors.append("[\(decision.provider.rawValue)] 不可用")
                continue
            }

            let config = buildConfig(provider: decision.provider, complexity: complexity)
            attempts += 1

            do {
                let response = try await backend.chat(
                    messages: messages,
                    config: config,
                    tools: tools,
                    delegate: delegate
                )
                if attempts > 1 {
                    os_log(.default, "[SmartRouter] 回退成功: 第 %d 个后端 %{public}s 响应", attempts, decision.provider.rawValue)
                }
                // Cache successful response
                if complexity.level == .simple {
                    let key = await cache.cacheKey(messages: messages, config: config)
                    await cache.set(key: key, value: CachedResponse(
                        text: response.textContent,
                        provider: decision.provider.rawValue,
                        model: config.model
                    ))
                }
                return FallbackResult(message: response, provider: decision.provider, attempts: attempts)
            } catch {
                errors.append("[\(decision.provider.rawValue)] \(error.localizedDescription)")
                await AgentEventBus.shared.publish(.lifecycle(.providerFellback(
                    from: decision.provider.rawValue,
                    to: decisions.first(where: { d in
                        d.priority > decision.priority && errors.count < decisions.count
                    })?.provider.rawValue ?? "none",
                    reason: error.localizedDescription
                )))
            }
        }

        throw AgentError.noAvailableBackend(errors.joined(separator: "; "))
    }

    public func route(_ messages: [Message], context: ProjectContext?) -> [RouteDecision] {
        let complexity = assessComplexity(messages, context: context)
        return routeDecisions(complexity: complexity, messages: messages, context: context)
    }

    public func previewRouteDecisions(
        for messages: [Message],
        context: ProjectContext?
    ) -> [RouteDecision] {
        route(messages, context: context)
    }

    public func getBackend(for provider: LLMProvider) async -> (any LLMBackend)? {
        switch provider {
        case .localMLX: return localBackend
        case .claudeCodeCLI: return claudeCodeBackend
        case .codexCLI: return codexBackend
        case .anthropic: return anthropicBackend
        case .openAI: return openAIBackend
        case .google: return googleBackend
        case .deepseek, .ollama, .groq, .mistral, .cohere, .replicate, .togetherAI, .perplexity, .xAI, .custom:
            return openAICompatibleBackends[provider]
        }
    }

    // MARK: - Complexity Assessment

    public func assessComplexity(_ messages: [Message], context: ProjectContext?) -> TaskComplexity {
        let lastUser = messages.last { $0.role == .user }
        let text = lastUser?.textContent.lowercased() ?? ""
        let rawText = lastUser?.textContent ?? ""
        var score: Double = 0
        var signals: [String] = []

        // Token count factor
        let totalChars = messages.reduce(0) { $0 + $1.textContent.count }
        if totalChars > 4000 { score += 2; signals.append("长上下文(\(totalChars)字符)") }
        else if totalChars > 2000 { score += 1; signals.append("中等上下文(\(totalChars)字符)") }

        // User message length signal (long messages often mean complex requirements)
        let userChars = rawText.count
        if userChars > 500 { score += 1.5; signals.append("长指令(\(userChars)字符)") }

        // Task structure signals
        let stepMarkers = ["先", "然后", "接着", "最后", "第一步", "第二步", "first", "then", "next", "finally", "step"]
        let stepCount = stepMarkers.filter { text.contains($0) }.count
        if stepCount >= 3 { score += 3; signals.append("明显多步骤(\(stepCount))") }
        else if stepCount >= 1 { score += 1.5; signals.append("含步骤指令(\(stepCount))") }

        // Sequential dependency detection ("先检查...再修改...最后测试")
        let seqPatterns = ["先.*然后", "先.*再", "检查.*修改", "修改.*测试", "check.*then", "fix.*test"]
        let hasSequential = seqPatterns.contains { text.range(of: $0, options: .regularExpression) != nil }
        if hasSequential { score += 1.5; signals.append("顺序依赖") }

        // Branching logic detection
        let branchingWords = ["如果", "否则", "不然", "if", "else", "或者", "要么", "either", "whether"]
        let branchCount = branchingWords.filter { text.contains($0) }.count
        if branchCount >= 2 { score += 1.5; signals.append("分支逻辑") }

        // Domain breadth
        var domains = detectDomains(text)
        if domains.count >= 3 { score += 3; signals.append("跨域任务(\(domains.map(\.rawValue).joined(separator: "+")))") }
        else if domains.count == 2 { score += 1.5; signals.append("双域任务") }

        // Visual/screen interaction detection
        let visualKeywords = ["看到", "屏幕", "窗口", "截图", "按钮", "图标", "图片", "画面", "按钮",
                              "look", "see", "screen", "window", "screenshot", "ui"]
        let hasVisualNeed = containsAny(text, visualKeywords)
        if hasVisualNeed {
            domains.insert(.desktop)
            score += 0.5
            signals.append("视觉需求")
        }

        // Code complexity
        if domains.contains(.code) {
            let codeTerms = ["refactor", "重构", "架构", "设计模式", "并发", "线程安全",
                             "性能优化", "optimize", "implement", "实现", "debug", "调试"]
            let codeTermMatches = codeTerms.filter { text.contains($0) }.count
            // Multi-file signal
            let filePaths: Int
            if let fileRegex = try? Regex(#"[\/\w]+\.\w{1,6}"#) {
                filePaths = rawText.matches(of: fileRegex).count
            } else {
                filePaths = 0
            }
            if filePaths >= 2 { score += 1; signals.append("多文件(\(filePaths))") }
            if codeTermMatches >= 2 { score += 2.5; signals.append("复杂代码任务") }
            else { score += 1; signals.append("简单代码任务") }
        }

        // System interaction depth
        if domains.contains(.desktop) {
            let deepOps = ["设置", "配置", "修改系统", "安装", "卸载", "configure", "setup", "install"]
            let deepCount = deepOps.filter { text.contains($0) }.count
            if deepCount >= 2 { score += 2.5; signals.append("深度系统操作") }
            else { score += 1; signals.append("常规桌面操作") }
        }

        // Multi-tool coordination signal
        let toolVerbs = ["打开", "点击", "输入", "搜索", "运行", "构建", "测试", "创建",
                         "open", "click", "type", "search", "build", "test", "run", "create"]
        let toolVerbCount = toolVerbs.filter { text.contains($0) }.count
        if toolVerbCount >= 3 { score += 1.5; signals.append("多工具协同(\(toolVerbCount))") }

        // Recovery / error handling needed
        let failureWords = ["如果失败", "备选", "替代方案", "万一", "出错", "fallback", "alternative", "retry"]
        if failureWords.contains(where: { text.contains($0) }) {
            score += 1; signals.append("需要容错")
        }

        // Context dependency
        if context != nil { score += 0.5 }
        if context?.selectedText?.isEmpty == false { score += 0.5; signals.append("有选中文本") }

        // Classification
        let level: TaskComplexity.Level
        switch score {
        case ..<2: level = .simple
        case 2..<5: level = .moderate
        case 5..<8: level = .complex
        default: level = .veryComplex
        }

        return TaskComplexity(
            score: score,
            level: level,
            domains: domains,
            signals: signals,
            estimatedToolCalls: estimateToolCalls(level: level, domains: domains),
            estimatedRounds: estimateRounds(level: level, domains: domains)
        )
    }

        /// Classify the task into an Oh My OpenAgent-style category for optimal model routing.
    public func classifyCategory(_ text: String) -> TaskCategory {
        let lower = text.lowercased()
        // Visual-engineering: frontend, UI, design
        if containsAny(lower, ["前端", "界面", "ui", "布局", "样式", "css", "html",
                                "设计稿", "figma", "视觉", "design", "frontend",
                                "按钮布局", "颜色", "字号", "间距", "响应式"]) {
            return .visualEngineering
        }
        // Ultrabrain: hard logic, architecture, complex decisions
        if containsAny(lower, ["架构", "设计模式", "算法", "数据结构", "系统设计",
                                "性能优化", "安全", "并发", "分布式",
                                "architecture", "design pattern", "algorithm",
                                "system design", "distributed", "consensus"]) {
            return .ultrabrain
        }
        // Deep: autonomous research + execution
        if containsAny(lower, ["调研", "研究", "分析", "比较", "评估", "调查",
                                "research", "investigate", "analyze", "survey",
                                "深度", "复杂", "全面", "comprehensive",
                                "实现一个", "implement a", "build a", "从头"]) {
            return .deep
        }
        // Quick: simple single-file changes
        if containsAny(lower, ["简单", "快速", "quick", "simple", "easy", "minor",
                                "小改动", "微调", "调整", "tweak", "adjust",
                                "一个文件", "single file", "一个方法"]) {
            return .quick
        }
        return .quick
    }

    /// Get optimal model provider for a task category.
    public func bestProvider(for category: TaskCategory) async -> LLMProvider? {
        switch category {
        case .visualEngineering:
            // Gemini/Claude best for visual tasks
            return await isAvailable(.google) ? .google
                : await isAvailable(.anthropic) ? .anthropic
                : nil
        case .ultrabrain:
            // Claude Opus best for hard reasoning
            return await isAvailable(.anthropic) ? .anthropic
                : await isAvailable(.openAI) ? .openAI
                : nil
        case .deep:
            // Claude good for deep research
            return await isAvailable(.anthropic) ? .anthropic
                : await isAvailable(.claudeCodeCLI) ? .claudeCodeCLI
                : nil
        case .quick:
            // Local or cheapest for simple tasks
            return await isAvailable(.localMLX) ? .localMLX
                : await isAvailable(.claudeCodeCLI) ? .claudeCodeCLI
                : nil
        }
    }

    private func isAvailable(_ provider: LLMProvider) async -> Bool {
        guard let backend = await getBackend(for: provider) else { return false }
        return await backend.isAvailable
    }

    private func routeDecisions(
        complexity: TaskComplexity,
        messages: [Message],
        context: ProjectContext?
    ) -> [RouteDecision] {
        if routingRules.alwaysLocal {
            return [RouteDecision(provider: .localMLX, priority: 1, reason: "规则：始终本地")]
        }

        var decisions: [RouteDecision] = []
        let domains = complexity.domains

        // CLI agents are preferred for all tasks when available (has tools, eyes, hands)
        let claudeP1 = RouteDecision(provider: .claudeCodeCLI, priority: 1, reason: "Claude Code（工具+视觉+操控）")
        let codexP2 = RouteDecision(provider: .codexCLI, priority: 2, reason: "Codex 备选 CLI Agent")

        switch complexity.level {
        case .simple:
            decisions.append(claudeP1)
            decisions.append(codexP2)
            decisions.append(RouteDecision(provider: .localMLX, priority: 3, reason: "简单任务本地处理"))
        case .moderate:
            decisions.append(claudeP1)
            decisions.append(codexP2)
            // 域感知路由
            appendDomainAwareDecisions(&decisions, domains: domains, basePriority: 3)
            decisions.append(RouteDecision(provider: .anthropic, priority: 5, reason: "云端备选"))
            decisions.append(RouteDecision(provider: .openAI, priority: 6, reason: "OpenAI 备选"))
            decisions.append(RouteDecision(provider: .google, priority: 7, reason: "Gemini 备选"))
            decisions.append(RouteDecision(provider: .groq, priority: 8, reason: "Groq 备选"))
            decisions.append(RouteDecision(provider: .mistral, priority: 9, reason: "Mistral 备选"))
        case .complex, .veryComplex:
            decisions.append(claudeP1)
            decisions.append(codexP2)
            decisions.append(RouteDecision(provider: .anthropic, priority: 3, reason: "复杂任务需云端 Agent"))
            if openAIBackend != nil {
                decisions.append(RouteDecision(provider: .openAI, priority: 4, reason: "备选云端"))
            }
            if googleBackend != nil {
                decisions.append(RouteDecision(provider: .google, priority: 5, reason: "Gemini 备选"))
            }
            if openAICompatibleBackends[.deepseek] != nil {
                decisions.append(RouteDecision(provider: .deepseek, priority: 6, reason: "DeepSeek 备选"))
            }
            if openAICompatibleBackends[.groq] != nil {
                decisions.append(RouteDecision(provider: .groq, priority: 7, reason: "Groq 备选"))
            }
            if openAICompatibleBackends[.mistral] != nil {
                decisions.append(RouteDecision(provider: .mistral, priority: 8, reason: "Mistral 备选"))
            }
            // 域感知 fallback：当 domainFallbackEnabled 时添加通用 fallback
            if routingRules.domainFallbackEnabled && domains.count == 1, domains != [.chat] {
                decisions.append(RouteDecision(provider: .localMLX, priority: 50, reason: "单域任务通用 fallback"))
            }
            decisions.append(RouteDecision(provider: .localMLX, priority: 99, reason: "最后备选"))
        }

        // 通用 fallback（domainFallbackEnabled 时保留这些作为最兜底选择）
        if routingRules.domainFallbackEnabled {
            decisions.append(RouteDecision(provider: .localMLX, priority: 200, reason: "通用 fallback"))
        }
        decisions.append(RouteDecision(provider: .anthropic, priority: 999, reason: "默认"))
        decisions.append(RouteDecision(provider: .openAI, priority: 1000, reason: "默认"))
        decisions.append(RouteDecision(provider: .google, priority: 1001, reason: "默认"))
        decisions.append(RouteDecision(provider: .groq, priority: 1002, reason: "默认"))
        decisions.append(RouteDecision(provider: .mistral, priority: 1003, reason: "默认"))
        return decisions.sorted { $0.priority < $1.priority }
    }

    /// 根据域类型添加域感知的路由决策
    private func appendDomainAwareDecisions(_ decisions: inout [RouteDecision], domains: Set<TaskKind>, basePriority: Int) {
        guard routingRules.domainFallbackEnabled else { return }
        for domain in domains {
            switch domain {
            case .code:
                decisions.append(RouteDecision(provider: .claudeCodeCLI, priority: basePriority, reason: "代码域优先 CLI Agent"))
            case .desktop:
                decisions.append(RouteDecision(provider: .localMLX, priority: basePriority, reason: "桌面域本地优先"))
            case .browser:
                decisions.append(RouteDecision(provider: .anthropic, priority: basePriority, reason: "浏览器/网络域云端优先"))
            case .fileSystem:
                decisions.append(RouteDecision(provider: .localMLX, priority: basePriority, reason: "文件系统域本地优先"))
            case .chat, .mixed:
                decisions.append(RouteDecision(provider: .localMLX, priority: basePriority, reason: "通用域本地优先"))
            }
        }
    }

    // MARK: - Private Helpers

    private func detectDomains(_ text: String) -> Set<TaskKind> {
        var domains: Set<TaskKind> = []
        // 代码域
        if containsAny(text, ["代码", "code", "编译", "build", "测试", "test", "git", "终端", "terminal",
                               "仓库", "pr", "commit", "diff", "swift", "重构", "debug",
                               "compile", "运行", "run", "execute", "修复", "fix", "bug", "error",
                               "实现", "implement", "feature", "函数", "method", "class", "struct",
                               "架构", "architecture", "依赖", "dependency", "package", "module"]) {
            domains.insert(.code)
        }
        // 桌面操控域
        if containsAny(text, ["打开", "点击", "输入", "窗口", "app", "应用", "桌面",
                               "微信", "finder", "访达", "系统设置", "设置",
                               "鼠标", "键盘", "滚动", "scroll", "drag", "拖拽", "菜单", "menu",
                               "启动", "launch", "切换", "switch", "最小化", "关闭"]) {
            domains.insert(.desktop)
        }
        // 浏览器/网络域
        if containsAny(text, ["浏览器", "网页", "网址", "url", "搜索", "safari", "chrome", "网站",
                               "curl", "wget", "下载", "download", "上传", "upload",
                               "http", "https", "api", "请求", "request", "response",
                               "json", "rest", "网络", "network", "web", "page"]) {
            domains.insert(.browser)
        }
        // 文件操作域
        if containsAny(text, ["文件", "目录", "文件夹", "移动", "复制", "重命名", "删除", "创建",
                               "read", "write", "保存", "save", "读取", "写入",
                               "file", "path", "路径", "内容", "content", "文本",
                               "备份", "backup", "压缩", "解压", "zip", "tar"]) {
            domains.insert(.fileSystem)
        }
        return domains.isEmpty ? [.chat] : domains
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private func estimateToolCalls(level: TaskComplexity.Level, domains: Set<TaskKind>) -> Int {
        switch level {
        case .simple: return max(1, domains.count)
        case .moderate: return domains.count * 3
        case .complex: return domains.count * 6
        case .veryComplex: return max(15, domains.count * 10)
        }
    }

    private func estimateRounds(level: TaskComplexity.Level, domains: Set<TaskKind>) -> Int {
        switch level {
        case .simple: return 2
        case .moderate: return 5
        case .complex: return 12
        case .veryComplex: return 30
        }
    }

    private func buildConfig(provider: LLMProvider, complexity: TaskComplexity) -> LLMConfiguration {
        let maxTokens: Int
        switch complexity.level {
        case .simple: maxTokens = 2048
        case .moderate: maxTokens = 4096
        case .complex: maxTokens = 8192
        case .veryComplex: maxTokens = 16384
        }

        let model = provider.defaultModel.isEmpty
            ? (provider == .localMLX ? LLMConfiguration.defaultLocal.model : LLMConfiguration.defaultCloud.model)
            : provider.defaultModel

        return LLMConfiguration(
            provider: provider,
            model: model,
            maxTokens: maxTokens,
            temperature: complexity.level == .veryComplex ? 0.5 : 0.7
        )
    }
}

// MARK: - Supporting Types

public struct TaskComplexity: Sendable, Hashable {
    public let score: Double
    public let level: Level
    public let domains: Set<TaskKind>
    public let signals: [String]
    public let estimatedToolCalls: Int
    public let estimatedRounds: Int

    public enum Level: String, Sendable, Hashable, Comparable {
        case simple
        case moderate
        case complex
        case veryComplex

        public static func < (lhs: Level, rhs: Level) -> Bool {
            let order: [Level] = [.simple, .moderate, .complex, .veryComplex]
            return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
        }
    }

    public init(
        score: Double,
        level: Level,
        domains: Set<TaskKind>,
        signals: [String],
        estimatedToolCalls: Int,
        estimatedRounds: Int
    ) {
        self.score = score
        self.level = level
        self.domains = domains
        self.signals = signals
        self.estimatedToolCalls = estimatedToolCalls
        self.estimatedRounds = estimatedRounds
    }
}

public struct RouteDecision: Sendable, Hashable {
    public let provider: LLMProvider
    public let priority: Int
    public let reason: String

    public init(provider: LLMProvider, priority: Int, reason: String) {
        self.provider = provider
        self.priority = priority
        self.reason = reason
    }
}

public struct RoutingRules: Sendable, Hashable {
    public var alwaysLocal: Bool
    public var preferLocalForSystem: Bool
    public var cloudOnlyForCode: Bool
    public var domainFallbackEnabled: Bool
    /// Enable task-category-aware model selection (P3 feature)
    public var categoryAwareRouting: Bool

    public init(alwaysLocal: Bool = false, preferLocalForSystem: Bool = true, cloudOnlyForCode: Bool = false, domainFallbackEnabled: Bool = true, categoryAwareRouting: Bool = true) {
        self.alwaysLocal = alwaysLocal
        self.preferLocalForSystem = preferLocalForSystem
        self.cloudOnlyForCode = cloudOnlyForCode
        self.domainFallbackEnabled = domainFallbackEnabled
        self.categoryAwareRouting = categoryAwareRouting
    }
}

// MARK: - Task Category (P3: Oh My OpenAgent-style routing)

public enum TaskCategory: String, Codable, Sendable, Hashable, CaseIterable {
    /// 前端/UI/视觉任务 — 适合 Gemini/Claude Vision
    case visualEngineering = "visual-engineering"
    /// 自主研究+执行 — 适合 Claude Opus
    case deep
    /// 单文件修改/简单任务 — 适合本地/快速模型
    case quick
    /// 硬逻辑/架构决策 — 适合最强模型
    case ultrabrain
}

extension TaskCategory {
    public var displayName: String {
        switch self {
        case .visualEngineering: return "视觉工程"
        case .deep: return "深度任务"
        case .quick: return "快速任务"
        case .ultrabrain: return "超脑任务"
        }
    }

    /// Priority weight: ultrabrain/deep get cloud preference,
    /// quick gets local preference, visual-engineering gets multimodal.
    public var recommendedProviderPriority: [LLMProvider] {
        switch self {
        case .visualEngineering: return [.google, .anthropic, .claudeCodeCLI, .openAI, .localMLX]
        case .deep: return [.anthropic, .claudeCodeCLI, .openAI, .google, .localMLX]
        case .quick: return [.localMLX, .claudeCodeCLI, .codexCLI, .anthropic, .openAI]
        case .ultrabrain: return [.anthropic, .openAI, .google, .claudeCodeCLI, .localMLX]
        }
    }
}
