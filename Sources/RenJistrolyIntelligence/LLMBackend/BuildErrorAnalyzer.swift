import Foundation
import RenJistrolyModels

public actor BuildErrorAnalyzer {
    private let smartRouter: SmartRouter

    public init(smartRouter: SmartRouter = SmartRouter()) {
        self.smartRouter = smartRouter
    }

    public func analyze(buildResult: BuildResult, projectPath: String?) async throws -> String {
        guard !buildResult.errors.isEmpty else {
            return buildResult.success ? "构建通过，没有错误。" : "没有可分析的错误信息。"
        }

        let (backend, config) = await smartRouter.getBestAvailableBackend(
            for: [Message(role: .user, content: [.text("分析构建错误")])],
            context: nil
        )

        let errorsText = buildResult.errors
            .map { e in
                var parts: [String] = []
                if let path = e.filePath { parts.append(path) }
                if let line = e.line { parts.append(":\(line)") }
                parts.append(e.message)
                return parts.joined(separator: " ")
            }
            .joined(separator: "\n")

        let prompt = """
        [错误分析]
        以下是一个 Swift 项目的构建错误。请分析原因并给出修改建议。用中文，简洁。

        \(projectPath.map { "项目路径: \($0)\n" } ?? "")
        错误:
        \(errorsText)

        请按以下格式回答:
        1. 根因分析
        2. 修改建议（具体到文件和行）
        3. 修复代码（如果适用）
        """

        let planConfig = LLMConfiguration(
            provider: config.provider,
            model: config.model,
            apiKey: config.apiKey,
            baseURL: config.baseURL,
            maxTokens: 1200,
            temperature: 0.3
        )

        let response = try await backend.chat(
            messages: [Message(role: .user, content: [.text(prompt)])],
            config: planConfig,
            tools: nil,
            delegate: nil
        )

        return response.textContent
    }

    public func analyze(testResult: TestResult, projectPath: String?) async throws -> String {
        guard !testResult.failures.isEmpty else {
            return testResult.success ? "所有测试通过。" : "没有可分析的失败信息。"
        }

        let (backend, config) = await smartRouter.getBestAvailableBackend(
            for: [Message(role: .user, content: [.text("分析测试失败")])],
            context: nil
        )

        let failuresText = testResult.failures
            .map { "✗ \($0.testName): \($0.message)" }
            .joined(separator: "\n")

        let prompt = """
        [测试失败分析]
        以下 Swift 测试失败。请分析原因并给出修复建议。用中文，简洁。

        \(projectPath.map { "项目路径: \($0)\n" } ?? "")
        \(failuresText)

        请按以下格式回答:
        1. 失败原因
        2. 修复方案
        """

        let planConfig = LLMConfiguration(
            provider: config.provider,
            model: config.model,
            apiKey: config.apiKey,
            baseURL: config.baseURL,
            maxTokens: 800,
            temperature: 0.3
        )

        let response = try await backend.chat(
            messages: [Message(role: .user, content: [.text(prompt)])],
            config: planConfig,
            tools: nil,
            delegate: nil
        )

        return response.textContent
    }
}
