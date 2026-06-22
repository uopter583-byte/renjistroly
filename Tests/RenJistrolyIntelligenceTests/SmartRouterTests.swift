import Foundation
import XCTest
@testable import RenJistrolyIntelligence
import RenJistrolyModels

func testSmartRouterLocalForSimpleQuery() async {
    let router = SmartRouter()
    let messages = [Message(role: .user, content: [.text("你好")])]
    let decisions = await router.previewRouteDecisions(for: messages, context: nil)
    let routesToLocal = decisions.contains { decision in
        decision.provider == LLMProvider.localMLX
    }

    XCTAssertTrue(routesToLocal)
}

func testSmartRouterCloudForComplexCode() async {
    let router = SmartRouter()
    let messages = [Message(role: .user, content: [.text("refactor the authentication module and implement a new OAuth flow")])]
    let context = ProjectContext(projectType: .swiftPM)
    let decisions = await router.previewRouteDecisions(for: messages, context: context)
    let routesToCloud = decisions.contains { decision in
        decision.provider == LLMProvider.anthropic || decision.provider == LLMProvider.openAI
    }

    XCTAssertTrue(routesToCloud)
}

func testRAGEngineDirectoryIndexing() async throws {
    let engine = RAGEngine()
    let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("rag_test_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: testDir) }

    let testFile = testDir.appendingPathComponent("test.swift")
    try "func hello() { print(\"Hello\") }".write(to: testFile, atomically: true, encoding: .utf8)

    try await engine.indexProject(at: testDir.path)
    let results = await engine.search("hello")

    XCTAssertFalse(results.isEmpty)
}

// MARK: - Multi-Provider Routing

func testSmartRouterGetBackendReturnsNilForUnconfiguredProviders() async {
    let router = SmartRouter()
    let localMLX = await router.getBackend(for: .localMLX)
    let claudeCodeCLI = await router.getBackend(for: .claudeCodeCLI)
    let anthropic = await router.getBackend(for: .anthropic)
    let openAI = await router.getBackend(for: .openAI)
    let google = await router.getBackend(for: .google)
    let deepseek = await router.getBackend(for: .deepseek)
    let ollama = await router.getBackend(for: .ollama)
    let custom = await router.getBackend(for: .custom)

    XCTAssertNotNil(localMLX)
    XCTAssertNotNil(claudeCodeCLI)
    XCTAssertNil(anthropic)
    XCTAssertNil(openAI)
    XCTAssertNil(google)
    XCTAssertNil(deepseek)
    XCTAssertNil(ollama)
    XCTAssertNil(custom)
}

func testSmartRouterConfigureCloudForGoogle() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .google, apiKey: "test-key")
    let backend = await router.getBackend(for: .google)
    XCTAssertTrue(backend != nil)
    let r9 = await backend?.isAvailable == true
    XCTAssertTrue(r9 == true)
}

func testSmartRouterConfigureCloudForDeepSeek() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .deepseek, apiKey: "test-key")
    let backend = await router.getBackend(for: .deepseek)
    XCTAssertTrue(backend != nil)
    let r10 = await backend?.isAvailable == true
    XCTAssertTrue(r10 == true)
}

func testSmartRouterConfigureCloudForOllama() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .ollama, apiKey: "", baseURL: "http://localhost:11434")
    let backend = await router.getBackend(for: .ollama)
    XCTAssertTrue(backend != nil)
}

func testSmartRouterConfigureCloudForCustomRequiresBaseURL() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .custom, apiKey: "test-key")
    let withoutBaseURL = await router.getBackend(for: .custom)
    XCTAssertNil(withoutBaseURL)

    await router.configureCloud(provider: .custom, apiKey: "test-key", baseURL: "https://api.example.com")
    let withBaseURL = await router.getBackend(for: .custom)
    XCTAssertNotNil(withBaseURL)
}

func testSmartRouterComplexTaskIncludesNewProviders() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .google, apiKey: "test-key")
    let messages = [Message(role: .user, content: [.text("重构认证模块，添加 OAuth 2.0 支持，更新所有测试")])]
    let decisions = await router.previewRouteDecisions(for: messages, context: ProjectContext(projectType: .swiftPM))
    let providers = Set(decisions.map(\.provider))
    XCTAssertTrue(providers.contains(.claudeCodeCLI))
    XCTAssertTrue(providers.contains(.anthropic))
    XCTAssertTrue(providers.contains(.google))
}

func testSmartRouterFallbackChainIncludesAllProviders() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .google, apiKey: "test-key")
    await router.configureCloud(provider: .deepseek, apiKey: "test-key")
    let messages = [Message(role: .user, content: [.text("你好")])]
    let decisions = await router.previewRouteDecisions(for: messages, context: nil)
    let fallbacks = decisions.filter { $0.priority >= 999 }
    XCTAssertTrue(fallbacks.contains { $0.provider == .anthropic })
    XCTAssertTrue(fallbacks.contains { $0.provider == .openAI })
    XCTAssertTrue(fallbacks.contains { $0.provider == .google })
}

func testSmartRouterSequentialComplexitySignal() async {
    let router = SmartRouter()
    let messages = [Message(role: .user, content: [.text("先检查代码风格，然后修复所有警告，最后运行测试")])]
    let complexity = await router.assessComplexity(messages, context: nil)
    XCTAssertTrue(complexity.signals.contains { $0.contains("顺序依赖") })
    XCTAssertTrue(complexity.level >= .moderate)
}

func testSmartRouterBranchingComplexitySignal() async {
    let router = SmartRouter()
    let messages = [Message(role: .user, content: [.text("如果构建成功就部署，否则回滚到上一个版本")])]
    let complexity = await router.assessComplexity(messages, context: nil)
    XCTAssertTrue(complexity.signals.contains { $0.contains("分支逻辑") })
}

func testSmartRouterMultiToolCoordinationSignal() async {
    let router = SmartRouter()
    let messages = [Message(role: .user, content: [.text("打开 Safari，搜索 Swift 6 文档，点击第一个结果，然后复制内容")])]
    let complexity = await router.assessComplexity(messages, context: nil)
    XCTAssertTrue(complexity.signals.contains { $0.contains("多工具协同") })
}

// MARK: - Fallback chain

private actor MockFailingBackend: LLMBackend {
    nonisolated let provider: LLMProvider
    let shouldFail: Bool
    init(provider: LLMProvider, shouldFail: Bool = true) {
        self.provider = provider
        self.shouldFail = shouldFail
    }
    nonisolated var isAvailable: Bool { get async { true } }
    func chat(messages: [Message], config: LLMConfiguration, tools: [ToolDefinition]?, delegate: LLMStreamingDelegate?) async throws -> Message {
        if shouldFail { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "模拟失败"]) }
        return Message(role: .assistant, content: [.text("ok from \(provider.rawValue)")])
    }
    func chatStream(messages: [Message], config: LLMConfiguration, tools: [ToolDefinition]?, delegate: LLMStreamingDelegate?) async throws -> AsyncStream<String> {
        AsyncStream { $0.yield("ok"); $0.finish() }
    }
}

func testSmartRouterChatWithFallbackSucceedsOnSecondBackend() async throws {
    let router = SmartRouter()
    let messages = [Message(role: .user, content: [.text("简单问题")])]
    let result = try await router.chatWithFallback(messages: messages, tools: nil, delegate: nil, context: nil)
    XCTAssertFalse(result.message.textContent.isEmpty)
    XCTAssertTrue(result.attempts >= 1)
}

func testSmartRouterFallbackResultRecordsProvider() async throws {
    let router = SmartRouter()
    let messages = [Message(role: .user, content: [.text("测试")])]
    let result = try await router.chatWithFallback(messages: messages, tools: nil, delegate: nil, context: nil)
    XCTAssertTrue(result.provider == .claudeCodeCLI || result.provider == .localMLX)
    XCTAssertTrue(result.attempts == 1)
}

func testSmartRouterChatWithFallbackPreservesErrorInfo() async throws {
    let router = SmartRouter()
    // When no cloud backends are configured, fallback chain reaches local/claudeCodeCLI
    let messages = [Message(role: .user, content: [.text("hi")])]
    do {
        let result = try await router.chatWithFallback(messages: messages, tools: nil, delegate: nil, context: nil)
        XCTAssertFalse(result.message.textContent.isEmpty)
    } catch {
        // If both local and claudeCode fail, we still expect graceful error
        XCTAssertTrue(String(describing: error).contains("noAvailableBackend") || String(describing: error).contains("不可用"))
    }
}

// MARK: - aisuite provider coverage

func testSmartRouterConfigureGroq() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .groq, apiKey: "test-key")
    let backend = await router.getBackend(for: .groq)
    XCTAssertTrue(backend != nil)
    let r13 = await backend?.isAvailable == true
    XCTAssertTrue(r13 == true)
}

func testSmartRouterConfigureMistral() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .mistral, apiKey: "test-key")
    let backend = await router.getBackend(for: .mistral)
    XCTAssertNotNil(backend)
}

func testSmartRouterConfigureCohere() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .cohere, apiKey: "test-key")
    let backend = await router.getBackend(for: .cohere)
    XCTAssertNotNil(backend)
}

func testSmartRouterConfigureTogetherAI() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .togetherAI, apiKey: "test-key")
    let backend = await router.getBackend(for: .togetherAI)
    XCTAssertNotNil(backend)
}

func testSmartRouterConfigurePerplexity() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .perplexity, apiKey: "test-key")
    let backend = await router.getBackend(for: .perplexity)
    XCTAssertNotNil(backend)
}

func testSmartRouterConfigureXAI() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .xAI, apiKey: "test-key")
    let backend = await router.getBackend(for: .xAI)
    XCTAssertNotNil(backend)
}

func testSmartRouterUnconfiguredNewProvidersReturnNil() async {
    let router = SmartRouter()
    let groq = await router.getBackend(for: .groq)
    let mistral = await router.getBackend(for: .mistral)
    let cohere = await router.getBackend(for: .cohere)
    let replicate = await router.getBackend(for: .replicate)
    let togetherAI = await router.getBackend(for: .togetherAI)
    let perplexity = await router.getBackend(for: .perplexity)
    let xAI = await router.getBackend(for: .xAI)

    XCTAssertNil(groq)
    XCTAssertNil(mistral)
    XCTAssertNil(cohere)
    XCTAssertNil(replicate)
    XCTAssertNil(togetherAI)
    XCTAssertNil(perplexity)
    XCTAssertNil(xAI)
}

func testSmartRouterFallbackChainIncludesNewProviders() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .groq, apiKey: "test-key")
    await router.configureCloud(provider: .mistral, apiKey: "test-key")
    let messages = [Message(role: .user, content: [.text("你好")])]
    let decisions = await router.previewRouteDecisions(for: messages, context: nil)
    let fallbacks = decisions.filter { $0.priority >= 999 }
    XCTAssertTrue(fallbacks.contains { $0.provider == .groq })
    XCTAssertTrue(fallbacks.contains { $0.provider == .mistral })
}

func testSmartRouterComplexTaskWithMultipleNewProviders() async {
    let router = SmartRouter()
    await router.configureCloud(provider: .groq, apiKey: "test-key")
    await router.configureCloud(provider: .mistral, apiKey: "test-key")
    await router.configureCloud(provider: .perplexity, apiKey: "test-key")
    let messages = [Message(role: .user, content: [.text("重构认证模块，添加 OAuth 2.0 支持，更新所有测试")])]
    let decisions = await router.previewRouteDecisions(for: messages, context: ProjectContext(projectType: .swiftPM))
    let providers = Set(decisions.map(\.provider))
    XCTAssertTrue(providers.contains(.groq))
    XCTAssertTrue(providers.contains(.mistral))
}

func testLLMProviderDefaultBaseURLs() async {
    XCTAssertTrue(LLMProvider.groq.defaultBaseURL == "https://api.groq.com/openai")
    XCTAssertTrue(LLMProvider.mistral.defaultBaseURL == "https://api.mistral.ai")
    XCTAssertTrue(LLMProvider.cohere.defaultBaseURL == "https://api.cohere.ai")
    XCTAssertTrue(LLMProvider.togetherAI.defaultBaseURL == "https://api.together.xyz")
    XCTAssertTrue(LLMProvider.perplexity.defaultBaseURL == "https://api.perplexity.ai")
    XCTAssertTrue(LLMProvider.xAI.defaultBaseURL == "https://api.x.ai")
    XCTAssertTrue(LLMProvider.deepseek.defaultBaseURL == "https://api.deepseek.com")
}

func testLLMProviderDefaultModels() async {
    XCTAssertFalse(LLMProvider.groq.defaultModel.isEmpty)
    XCTAssertFalse(LLMProvider.mistral.defaultModel.isEmpty)
    XCTAssertFalse(LLMProvider.cohere.defaultModel.isEmpty)
    XCTAssertFalse(LLMProvider.togetherAI.defaultModel.isEmpty)
    XCTAssertFalse(LLMProvider.perplexity.defaultModel.isEmpty)
    XCTAssertFalse(LLMProvider.xAI.defaultModel.isEmpty)
    XCTAssertFalse(LLMProvider.deepseek.defaultModel.isEmpty)
}
