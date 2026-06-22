import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence
@testable import RenJistrolySystemBridge

// MARK: - OpenAI-compatible ProviderKind

@MainActor
final class ProviderStabilityTests: XCTestCase {
    func testProviderKindOpenAICompatibleDefaults() {
        XCTAssertTrue(ProviderKind.openAICompatibleChat.defaultBaseURL?.absoluteString == "https://api.openai.com/v1")
        XCTAssertTrue(ProviderKind.openAICompatibleChat.defaultModel == "gpt-5-mini")
        XCTAssertTrue(ProviderKind.openAICompatibleChat.title == "OpenAI-compatible")
    }

    func testProviderKindLocalEndpointTitle() {
        XCTAssertTrue(ProviderKind.localOpenAICompatible.title == "本地兼容端点")
        XCTAssertTrue(ProviderKind.localOpenAICompatible.defaultBaseURL?.absoluteString == "http://127.0.0.1:1234/v1")
        XCTAssertTrue(ProviderKind.localOpenAICompatible.defaultModel == "local-model")
    }

    // MARK: - Offline Fallback (network error recovery)

    func testChatProviderErrorRecoverableNetworkFailures() {
        let recoverable: [ChatProviderError] = [
            .networkUnavailable(""),
            .timedOut(""),
            .httpError(429, ""),
            .httpError(503, ""),
            .httpError(504, ""),
        ]
        for error in recoverable {
            XCTAssertTrue(error.isRecoverableNetworkFailure, "Expected recoverable for \(error)")
        }
    }

    func testChatProviderErrorNonRecoverableErrors() {
        let nonRecoverable: [ChatProviderError] = [
            .missingAPIKey("X"),
            .missingBaseURL("X"),
            .invalidResponse,
            .httpError(401, ""),
            .httpError(403, ""),
        ]
        for error in nonRecoverable {
            XCTAssertTrue(!error.isRecoverableNetworkFailure, "Expected non-recoverable for \(error)")
        }
    }

    // MARK: - Router dispatch

    func testProviderRouterLocalFirstMapping() {
        var router = ProviderRouter()
        router.preference = .localFirst
        let provider = router.chatProvider()
        XCTAssertTrue(provider.name == "本地兼容端点")
    }

    func testProviderRouterAppleNativeMapping() {
        var router = ProviderRouter()
        router.preference = .appleNative
        let provider = router.chatProvider()
        XCTAssertTrue(provider.name == "本地兼容端点")
    }

    // MARK: - LLM Configuration

    func testLLMConfigurationDefaultLocal() {
        let config = LLMConfiguration.defaultLocal
        XCTAssertTrue(config.provider == .localMLX)
        XCTAssertTrue(config.model == "mlx-community/Qwen3-8B-4bit")
        XCTAssertTrue(config.maxTokens == 4096)
        XCTAssertTrue(config.temperature == 0.7)
    }

    func testLLMConfigurationDefaultCloud() {
        let config = LLMConfiguration.defaultCloud
        XCTAssertTrue(config.provider == .anthropic)
        XCTAssertTrue(config.model == "claude-sonnet-4-6")
        XCTAssertTrue(config.maxTokens == 8192)
    }

    func testLLMConfigurationCustom() {
        let config = LLMConfiguration(
            provider: .deepseek,
            model: "deepseek-coder",
            apiKey: "sk-test",
            baseURL: URL(string: "https://custom.deepseek.com"),
            maxTokens: 4096,
            temperature: 0.3,
            topP: 0.9
        )
        XCTAssertTrue(config.apiKey == "sk-test")
        XCTAssertTrue(config.baseURL?.absoluteString == "https://custom.deepseek.com")
        XCTAssertTrue(config.topP == 0.9)
    }

    // MARK: - ProviderEndpoint (equality, identity, no-API-key providers)

    func testProviderEndpointEquality() {
        let a = ProviderEndpoint(kind: .deepSeek)
        let b = ProviderEndpoint(kind: .deepSeek)
        XCTAssertTrue(a.kind == b.kind)
        XCTAssertTrue(a.displayName == b.displayName)
        XCTAssertTrue(a.model == b.model)
    }

    func testProviderEndpointDefaultEnvVars() {
        XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .openAICompatibleChat) == "OPENAI_API_KEY")
        XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .deepSeek) == "DEEPSEEK_API_KEY")
        XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .localOpenAICompatible) == "")
        XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .appleNative) == "")
    }

    func testProviderEndpointCustomInitAllFields() {
        let endpoint = ProviderEndpoint(
            kind: .qwen,
            displayName: "通义千问",
            baseURL: URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1"),
            model: "qwen-max",
            apiKeyEnvironmentVariable: "QWEN_API_KEY"
        )
        XCTAssertTrue(endpoint.displayName == "通义千问")
        XCTAssertTrue(endpoint.model == "qwen-max")
        XCTAssertTrue(endpoint.apiKeyEnvironmentVariable == "QWEN_API_KEY")
    }

    // MARK: - LLMProvider extended coverage

    func testLLMProviderDisplayNames() {
        XCTAssertTrue(LLMProvider.claudeCodeCLI.displayName == "Claude Code")
        XCTAssertTrue(LLMProvider.localMLX.displayName == "本地 MLX")
        XCTAssertTrue(LLMProvider.anthropic.displayName == "Claude (Anthropic)")
        XCTAssertTrue(LLMProvider.custom.displayName == "自定义")
    }

    func testLLMProviderDefaultBaseURLs() {
        XCTAssertTrue(LLMProvider.deepseek.defaultBaseURL == "https://api.deepseek.com")
        XCTAssertTrue(LLMProvider.groq.defaultBaseURL == "https://api.groq.com/openai")
        XCTAssertTrue(LLMProvider.xAI.defaultBaseURL == "https://api.x.ai")
        XCTAssertTrue(LLMProvider.ollama.defaultBaseURL == nil)
    }

    func testLLMProviderDefaultModels() {
        XCTAssertTrue(LLMProvider.deepseek.defaultModel == "deepseek-chat")
        XCTAssertTrue(LLMProvider.mistral.defaultModel == "mistral-large-latest")
        XCTAssertTrue(LLMProvider.groq.defaultModel == "llama-4-scout-17b-16e-instruct")
        XCTAssertTrue(LLMProvider.localMLX.defaultModel == "")
    }

    // MARK: - Error from transport errors

    func testChatProviderErrorFromTransportTimeout() {
        let urlError = URLError(.timedOut)
        let result = ChatProviderError.fromTransport(urlError)
        if case .timedOut = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected timedOut from URLError.timedOut")
        }
    }

    func testChatProviderErrorFromTransportDNSFailure() {
        let urlError = URLError(.dnsLookupFailed)
        let result = ChatProviderError.fromTransport(urlError)
        if case .networkUnavailable = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected networkUnavailable from DNS failure")
        }
    }

    func testChatProviderErrorFromTransportConnectionLost() {
        let urlError = URLError(.networkConnectionLost)
        let result = ChatProviderError.fromTransport(urlError)
        if case .networkUnavailable = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected networkUnavailable from connectionLost")
        }
    }

    func testChatProviderErrorFromTransportArbitrary() {
        let arbitrary = NSError(domain: "test", code: -1)
        let result = ChatProviderError.fromTransport(arbitrary)
        if case .transport = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected transport for unknown error")
        }
    }

    // MARK: - ProviderRouter dispatch

    func testProviderRouterCreatesChatProviderForDeepSeek() {
        var router = ProviderRouter()
        router.preference = .deepSeek
        let provider = router.chatProvider()
        XCTAssertTrue(provider.name == "DeepSeek")
    }

    func testProviderRouterCreatesChatProviderForQwen() {
        var router = ProviderRouter()
        router.preference = .qwen
        let provider = router.chatProvider()
        XCTAssertTrue(provider.name == "Qwen")
    }

    func testProviderRouterCreatesChatProviderForMoonshot() {
        var router = ProviderRouter()
        router.preference = .moonshot
        let provider = router.chatProvider()
        XCTAssertTrue(provider.name == "Moonshot")
    }

    func testProviderRouterLocalEndpoint() {
        var router = ProviderRouter()
        router.preference = .localEndpoint
        let provider = router.chatProvider()
        XCTAssertTrue(provider.name == "本地兼容端点")
    }

    func testProviderRouterASRProvider() async {
        let router = ProviderRouter()
        let asr = router.asrProvider()
        XCTAssertTrue(asr.name == "Apple Speech")
    }

    func testProviderRouterTTSProvider() async {
        let router = ProviderRouter(speechRateMultiplier: 2.0)
        let tts = router.ttsProvider()
        XCTAssertTrue(tts.name == "macOS System TTS")
    }

    // MARK: - ProviderKind default URLs

    func testProviderKindDefaultBaseURLs() {
        XCTAssertTrue(ProviderKind.deepSeek.defaultBaseURL?.absoluteString == "https://api.deepseek.com")
        XCTAssertTrue(ProviderKind.qwen.defaultBaseURL?.absoluteString == "https://dashscope.aliyuncs.com/compatible-mode/v1")
        XCTAssertTrue(ProviderKind.moonshot.defaultBaseURL?.absoluteString == "https://api.moonshot.cn/v1")
        XCTAssertTrue(ProviderKind.localOpenAICompatible.defaultBaseURL?.absoluteString == "http://127.0.0.1:1234/v1")
    }

    func testProviderKindDefaultModels() {
        XCTAssertTrue(ProviderKind.deepSeek.defaultModel == "deepseek-chat")
        XCTAssertTrue(ProviderKind.qwen.defaultModel == "qwen-plus")
        XCTAssertTrue(ProviderKind.moonshot.defaultModel == "moonshot-v1-8k")
        XCTAssertTrue(ProviderKind.localOpenAICompatible.defaultModel == "local-model")
    }

    // MARK: - ProviderEndpoint

    func testProviderEndpointCustomConfiguration() {
        let endpoint = ProviderEndpoint(
            kind: .deepSeek,
            displayName: "My DeepSeek",
            baseURL: URL(string: "https://custom.deepseek.com/v1"),
            model: "deepseek-coder"
        )
        XCTAssertTrue(endpoint.displayName == "My DeepSeek")
        XCTAssertTrue(endpoint.baseURL?.absoluteString == "https://custom.deepseek.com/v1")
        XCTAssertTrue(endpoint.model == "deepseek-coder")
    }

    func testProviderEndpointDefaultEnvironmentVariable() {
        XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .deepSeek) == "DEEPSEEK_API_KEY")
        XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .qwen) == "DASHSCOPE_API_KEY")
        XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .moonshot) == "MOONSHOT_API_KEY")
        XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .localOpenAICompatible) == "")
    }

    // MARK: - ProviderCatalog

    func testProviderCatalogDefaults() {
        let catalogs = ProviderCatalog.defaults
        XCTAssertTrue(catalogs.count == 6)
        XCTAssertTrue(catalogs.contains(where: { $0.kind == .deepSeek }))
        XCTAssertTrue(catalogs.contains(where: { $0.kind == .qwen }))
        XCTAssertTrue(catalogs.contains(where: { $0.kind == .localOpenAICompatible }))
    }

    // MARK: - ChatProviderError

    func testChatProviderErrorMessages() {
        let missingKey = ChatProviderError.missingAPIKey("DEEPSEEK_API_KEY")
        XCTAssertTrue(missingKey.errorDescription?.contains("API Key") == true)
        XCTAssertTrue(missingKey.errorDescription?.contains("DEEPSEEK_API_KEY") == true)

        let timeout = ChatProviderError.timedOut("timeout after 30s")
        XCTAssertTrue(timeout.errorDescription?.contains("超时") == true)

        let networkUnavailable = ChatProviderError.networkUnavailable("no internet")
        XCTAssertTrue(networkUnavailable.errorDescription?.contains("网络不可用") == true)

        let http429 = ChatProviderError.httpError(429, "Too Many Requests")
        XCTAssertTrue(http429.errorDescription?.contains("429") == true)
        XCTAssertTrue(http429.errorDescription?.contains("限流") == true)

        let http5xx = ChatProviderError.httpError(503, "Service Unavailable")
        XCTAssertTrue(http5xx.errorDescription?.contains("503") == true)
        XCTAssertTrue(http5xx.errorDescription?.contains("上游服务异常") == true)
    }

    func testChatProviderErrorRecoverable() {
        XCTAssertTrue(ChatProviderError.networkUnavailable("").isRecoverableNetworkFailure == true)
        XCTAssertTrue(ChatProviderError.timedOut("").isRecoverableNetworkFailure == true)
        XCTAssertTrue(ChatProviderError.httpError(429, "").isRecoverableNetworkFailure == true)
        XCTAssertTrue(ChatProviderError.httpError(503, "").isRecoverableNetworkFailure == true)
        XCTAssertTrue(ChatProviderError.httpError(401, "").isRecoverableNetworkFailure == false)
        XCTAssertTrue(ChatProviderError.missingAPIKey("X").isRecoverableNetworkFailure == false)
        XCTAssertTrue(ChatProviderError.missingBaseURL("X").isRecoverableNetworkFailure == false)
        XCTAssertTrue(ChatProviderError.invalidResponse.isRecoverableNetworkFailure == false)
    }

    func testChatProviderErrorFromTransport() {
        let timeoutError = URLError(.timedOut)
        let result = ChatProviderError.fromTransport(timeoutError)
        if case .timedOut = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected timedOut")
        }
    }

    func testChatProviderErrorFromTransportNetworkUnreachable() {
        let notConnected = URLError(.notConnectedToInternet)
        let result = ChatProviderError.fromTransport(notConnected)
        if case .networkUnavailable = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected networkUnavailable")
        }
    }

    // MARK: - ChatRequest/Response models

    func testChatRequestModel() {
        let request = ChatRequest(
            model: "deepseek-chat",
            messages: [
                ChatMessage(role: "user", content: "你好"),
                ChatMessage(role: "assistant", content: "你好！有什么可以帮助你的吗？"),
            ],
            temperature: 0.7,
            maxTokens: 4096
        )
        XCTAssertTrue(request.model == "deepseek-chat")
        XCTAssertTrue(request.messages.count == 2)
        XCTAssertTrue(request.temperature == 0.7)
    }

    func testChatResponseModel() {
        let response = ChatResponse(text: "你好！", provider: "DeepSeek", model: "deepseek-chat")
        XCTAssertTrue(response.text == "你好！")
        XCTAssertTrue(response.provider == "DeepSeek")
        XCTAssertTrue(response.model == "deepseek-chat")
    }

    // MARK: - LLMProvider

    func testLLMProviderRequiresAPIKey() {
        XCTAssertTrue(LLMProvider.anthropic.requiresAPIKey == true)
        XCTAssertTrue(LLMProvider.openAI.requiresAPIKey == true)
        XCTAssertTrue(LLMProvider.deepseek.requiresAPIKey == true)
        XCTAssertTrue(LLMProvider.claudeCodeCLI.requiresAPIKey == false)
        XCTAssertTrue(LLMProvider.localMLX.requiresAPIKey == false)
    }

    func testLLMProviderIsLocal() {
        XCTAssertTrue(LLMProvider.claudeCodeCLI.isLocal == true)
        XCTAssertTrue(LLMProvider.localMLX.isLocal == true)
        XCTAssertTrue(LLMProvider.anthropic.isLocal == false)
        XCTAssertTrue(LLMProvider.openAI.isLocal == false)
    }

    // MARK: - ProviderPreference

    func testProviderPreferenceSelectableCases() {
        let cases = ProviderPreference.selectableCases
        XCTAssertTrue(!cases.contains(.cloudRealtime))
        XCTAssertTrue(cases.count == 7)
        for pref in ProviderPreference.allCases {
            XCTAssert(pref.isImplemented == (pref != .cloudRealtime))
        }
    }

    // MARK: - ProviderRouter all preferences

    func testProviderRouterAllPreferences() {
        var router = ProviderRouter()
        router.preference = .claudeCode
        let provider1 = router.chatProvider()
        XCTAssert(provider1.name == "本地兼容端点")

        router.preference = .cloudRealtime
        let provider2 = router.chatProvider()
        XCTAssert(provider2.name == "OpenAI-compatible")
    }

    // MARK: - ProviderKind all defaults

    func testProviderKindAllDefaults() {
        XCTAssert(ProviderKind.openAIRealtime.defaultBaseURL?.absoluteString == "wss://api.openai.com/v1/realtime")
        XCTAssert(ProviderKind.openAIRealtime.defaultModel == "gpt-realtime-2")
        XCTAssert(ProviderKind.openAIRealtime.title == "OpenAI Realtime")

        for kind in ProviderKind.allCases {
            XCTAssertFalse(kind.title.isEmpty)
        }
    }

    // MARK: - LLMProvider extended coverage

    func testLLMProviderExtendedCoverage() {
        for provider in LLMProvider.allCases {
            XCTAssertFalse(provider.displayName.isEmpty)
        }

        XCTAssert(LLMProvider.mistral.defaultBaseURL == "https://api.mistral.ai")
        XCTAssert(LLMProvider.cohere.defaultBaseURL == "https://api.cohere.ai")
        XCTAssert(LLMProvider.replicate.defaultBaseURL == "https://api.replicate.com")
        XCTAssert(LLMProvider.togetherAI.defaultBaseURL == "https://api.together.xyz")
        XCTAssert(LLMProvider.perplexity.defaultBaseURL == "https://api.perplexity.ai")

        XCTAssert(LLMProvider.cohere.defaultModel == "command-r-plus")
        XCTAssert(LLMProvider.replicate.defaultModel == "meta/llama-4-maverick")
        XCTAssert(LLMProvider.perplexity.defaultModel == "sonar-pro")
        XCTAssert(LLMProvider.xAI.defaultModel == "grok-3")
    }

    // MARK: - ChatProviderError transport recovery

    func testChatProviderErrorTransportRecovery() {
        let transportErr = ChatProviderError.transport("connection reset")
        XCTAssert(transportErr.isRecoverableNetworkFailure)
        XCTAssert(transportErr.errorDescription?.contains("传输失败") == true)
        XCTAssertFalse(ChatProviderError.invalidResponse.isRecoverableNetworkFailure)
    }

    // MARK: - ProviderEndpoint local endpoint specific

    func testProviderEndpointLocalSpecific() {
        let endpoint = ProviderEndpoint(kind: .localOpenAICompatible)
        XCTAssert(endpoint.baseURL?.absoluteString == "http://127.0.0.1:1234/v1")
        XCTAssert(endpoint.model == "local-model")
        XCTAssert(endpoint.apiKeyEnvironmentVariable.isEmpty)
    }

    // MARK: - ProviderCatalog count

    func testProviderCatalogCount() {
        XCTAssert(ProviderCatalog.defaults.count == 6)
        XCTAssert(ProviderCatalog.defaults.contains(where: { $0.kind == .deepSeek }))
        XCTAssert(ProviderCatalog.defaults.contains(where: { $0.kind == .localOpenAICompatible }))
    }
}
