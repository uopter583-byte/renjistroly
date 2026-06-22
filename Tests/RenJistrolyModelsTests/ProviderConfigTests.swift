import Foundation
import XCTest
import RenJistrolyModels

// MARK: - ProviderKind

func testProviderKindTitles() {
    XCTAssertTrue(ProviderKind.openAIRealtime.title == "OpenAI Realtime")
    XCTAssertTrue(ProviderKind.openAICompatibleChat.title == "OpenAI-compatible")
    XCTAssertTrue(ProviderKind.deepSeek.title == "DeepSeek")
    XCTAssertTrue(ProviderKind.qwen.title == "Qwen")
    XCTAssertTrue(ProviderKind.moonshot.title == "Moonshot")
    XCTAssertTrue(ProviderKind.localOpenAICompatible.title == "本地兼容端点")
    XCTAssertTrue(ProviderKind.appleNative.title == "Apple 原生")
}

func testProviderKindDefaultBaseURLs() {
    XCTAssertTrue(ProviderKind.deepSeek.defaultBaseURL?.absoluteString == "https://api.deepseek.com")
    XCTAssertTrue(ProviderKind.qwen.defaultBaseURL?.absoluteString == "https://dashscope.aliyuncs.com/compatible-mode/v1")
    XCTAssertTrue(ProviderKind.appleNative.defaultBaseURL == nil)
    XCTAssertTrue(ProviderKind.localOpenAICompatible.defaultBaseURL?.absoluteString == "http://127.0.0.1:1234/v1")
}

func testProviderKindDefaultModels() {
    XCTAssertTrue(ProviderKind.deepSeek.defaultModel == "deepseek-chat")
    XCTAssertTrue(ProviderKind.qwen.defaultModel == "qwen-plus")
    XCTAssertTrue(ProviderKind.openAIRealtime.defaultModel == "gpt-realtime-2")
    XCTAssertTrue(ProviderKind.appleNative.defaultModel == "apple-native")
}

func testProviderKindAllCasesCount() {
    XCTAssertTrue(ProviderKind.allCases.count == 7)
}

// MARK: - ProviderEndpoint

func testProviderEndpointDefaultsFromKind() {
    let endpoint = ProviderEndpoint(kind: .deepSeek)
    XCTAssertTrue(endpoint.displayName == "DeepSeek")
    XCTAssertTrue(endpoint.baseURL?.absoluteString == "https://api.deepseek.com")
    XCTAssertTrue(endpoint.model == "deepseek-chat")
}

func testProviderEndpointCustomOverride() {
    let endpoint = ProviderEndpoint(
        kind: .deepSeek,
        displayName: "Custom DS",
        baseURL: URL(string: "https://custom.example.com")!,
        model: "custom-model",
        apiKeyEnvironmentVariable: "MY_KEY"
    )
    XCTAssertTrue(endpoint.displayName == "Custom DS")
    XCTAssertTrue(endpoint.baseURL?.absoluteString == "https://custom.example.com")
    XCTAssertTrue(endpoint.model == "custom-model")
    XCTAssertTrue(endpoint.apiKeyEnvironmentVariable == "MY_KEY")
}

func testProviderEndpointDefaultEnvVar() {
    XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .openAIRealtime) == "OPENAI_API_KEY")
    XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .deepSeek) == "DEEPSEEK_API_KEY")
    XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .qwen) == "DASHSCOPE_API_KEY")
    XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .moonshot) == "MOONSHOT_API_KEY")
    XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .localOpenAICompatible).isEmpty)
    XCTAssertTrue(ProviderEndpoint.defaultEnvironmentVariable(for: .appleNative).isEmpty)
}

// MARK: - ProviderCatalog

func testProviderCatalogDefaults() {
    let defaults = ProviderCatalog.defaults
    XCTAssertTrue(defaults.count == 6)
    XCTAssertTrue(defaults.contains { $0.kind == .deepSeek })
    XCTAssertTrue(defaults.contains { $0.kind == .openAIRealtime })
}
