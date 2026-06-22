import Foundation
import RenJistrolyModels

public actor PlanGenerator {
    private let smartRouter: SmartRouter

    public init(smartRouter: SmartRouter = SmartRouter()) {
        self.smartRouter = smartRouter
    }

    public func shouldPlan(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        if trimmed.count < 30 { return false }

        let complexityIndicators = [
            "分析", "检查", "审查", "重构", "修复", "优化",
            "创建", "生成", "实现", "添加", "修改", "更新",
            "部署", "测试", "配置", "安装", "迁移", "转换",
            "review", "refactor", "fix", "optimize", "create",
            "implement", "deploy", "test", "configure", "migrate",
        ]
        let lower = trimmed.lowercased()
        let hasIndicator = complexityIndicators.contains { lower.contains($0) }
        let isLong = trimmed.count > 80
        let hasMultiIntent = trimmed.contains("并") || trimmed.contains("然后") || trimmed.contains("之后") || trimmed.contains("再")

        return hasIndicator || (isLong && hasMultiIntent) || (trimmed.count > 150)
    }

    public func generatePlan(
        userMessage: String,
        context: ProjectContext?,
        toolDefinitions: [ToolDefinition]
    ) async throws -> ExecutionPlan? {
        guard shouldPlan(userMessage) else { return nil }

        let toolsDesc = toolDefinitions.isEmpty ? "" :
            "可用工具: \(toolDefinitions.map { "\($0.name)(\($0.description.prefix(30)))" }.joined(separator: ", "))"

        let prompt = """
        [系统]
        你是一个执行计划生成器。根据用户请求，生成一个 2-5 步的执行计划。每步一行，以序号开头。用中文。

        规则:
        - 每个步骤应该是一个独立、可执行的操作
        - 步骤描述要从用户视角写（"读取当前文件"而不是"调用 read_file"）
        - 不要超过 5 步
        - 只输出步骤列表，不要解释

        \(toolsDesc)

        [用户请求]
        \(userMessage)

        [计划]
        """

        let (backend, config) = await smartRouter.getBestAvailableBackend(
            for: [Message(role: .user, content: [.text(prompt)])],
            context: context
        )

        let planConfig = LLMConfiguration(
            provider: config.provider,
            model: config.model,
            apiKey: config.apiKey,
            baseURL: config.baseURL,
            maxTokens: 400,
            temperature: 0.3
        )

        let response = try await backend.chat(
            messages: [Message(role: .user, content: [.text(prompt)])],
            config: planConfig,
            tools: nil,
            delegate: nil
        )

        let steps = parseSteps(from: response.textContent)
        guard steps.count >= 2 else { return nil }

        let title = generateTitle(from: userMessage)
        return ExecutionPlan(title: title, steps: steps)
    }

    func parseSteps(from text: String) -> [PlanStep] {
        let lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        var steps: [PlanStep] = []

        let numberPrefix = (try? Regex("^[\\d]+[.、．)\\s]+"))
        let bulletPrefix = (try? Regex("^[-•·*]\\s*"))

        for line in lines {
            var cleaned = line
            if let re = numberPrefix { cleaned = cleaned.replacing(re, with: "") }
            if let re = bulletPrefix { cleaned = cleaned.replacing(re, with: "") }
            cleaned = cleaned.trimmingCharacters(in: .whitespaces)

            guard !cleaned.isEmpty, cleaned.count >= 4, cleaned.count < 200 else { continue }
            steps.append(PlanStep(description: cleaned))
        }
        return steps
    }

    func generateTitle(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 40 { return trimmed }
        return String(trimmed.prefix(40)).trimmingCharacters(in: .whitespaces) + "…"
    }
}
