import Foundation
import XCTest
import RenJistrolyModels

// MARK: - LLMProvider displayName

func testLLMProviderDisplayNames() {
    XCTAssertTrue(LLMProvider.claudeCodeCLI.displayName == "Claude Code")
    XCTAssertTrue(LLMProvider.localMLX.displayName == "本地 MLX")
    XCTAssertTrue(LLMProvider.anthropic.displayName == "Claude (Anthropic)")
    XCTAssertTrue(LLMProvider.openAI.displayName == "OpenAI")
    XCTAssertTrue(LLMProvider.google.displayName == "Gemini (Google)")
    XCTAssertTrue(LLMProvider.deepseek.displayName == "DeepSeek")
    XCTAssertTrue(LLMProvider.ollama.displayName == "Ollama")
    XCTAssertTrue(LLMProvider.custom.displayName == "自定义")
}

// MARK: - LLMProvider requiresAPIKey

func testLLMProviderRequiresAPIKey() {
    XCTAssertFalse(LLMProvider.claudeCodeCLI.requiresAPIKey)
    XCTAssertFalse(LLMProvider.localMLX.requiresAPIKey)
    XCTAssertFalse(LLMProvider.ollama.requiresAPIKey)
    XCTAssertTrue(LLMProvider.anthropic.requiresAPIKey)
    XCTAssertTrue(LLMProvider.openAI.requiresAPIKey)
    XCTAssertTrue(LLMProvider.google.requiresAPIKey)
    XCTAssertTrue(LLMProvider.deepseek.requiresAPIKey)
    XCTAssertTrue(LLMProvider.custom.requiresAPIKey)
}

// MARK: - LLMProvider isLocal

func testLLMProviderIsLocal() {
    XCTAssertTrue(LLMProvider.claudeCodeCLI.isLocal)
    XCTAssertTrue(LLMProvider.localMLX.isLocal)
    XCTAssertTrue(LLMProvider.ollama.isLocal)
    XCTAssertFalse(LLMProvider.anthropic.isLocal)
    XCTAssertFalse(LLMProvider.openAI.isLocal)
    XCTAssertFalse(LLMProvider.google.isLocal)
    XCTAssertFalse(LLMProvider.deepseek.isLocal)
    XCTAssertFalse(LLMProvider.custom.isLocal)
}

func testLLMProviderAllCasesCount() {
    XCTAssertTrue(LLMProvider.allCases.count == 16)
}

// MARK: - LLMConfiguration

func testLLMConfigurationInitWithDefaults() {
    let config = LLMConfiguration(provider: .anthropic, model: "claude-sonnet-4-6")
    XCTAssertTrue(config.provider == .anthropic)
    XCTAssertTrue(config.model == "claude-sonnet-4-6")
    XCTAssertTrue(config.apiKey == nil)
    XCTAssertTrue(config.baseURL == nil)
    XCTAssertTrue(config.maxTokens == 8192)
    XCTAssertTrue(config.temperature == 0.7)
    XCTAssertTrue(config.topP == nil)
}

func testLLMConfigurationInitFull() {
    let config = LLMConfiguration(
        provider: .openAI,
        model: "gpt-5",
        apiKey: "sk-key",
        baseURL: URL(string: "https://api.openai.com"),
        maxTokens: 4096,
        temperature: 0.3,
        topP: 0.9
    )
    XCTAssertTrue(config.apiKey == "sk-key")
    XCTAssertTrue(config.baseURL?.absoluteString == "https://api.openai.com")
    XCTAssertTrue(config.maxTokens == 4096)
    XCTAssertTrue(config.temperature == 0.3)
    XCTAssertTrue(config.topP == 0.9)
}

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
    XCTAssertTrue(config.temperature == 0.7)
}
