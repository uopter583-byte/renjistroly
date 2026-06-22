import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - ChatProviderError

func testChatProviderErrorMissingAPIKey() {
    let err = ChatProviderError.missingAPIKey("OPENAI_API_KEY")
    XCTAssertTrue(err.errorDescription?.contains("OPENAI_API_KEY") == true)
    XCTAssertTrue(err.errorDescription?.contains("缺少 API Key") == true)
}

func testChatProviderErrorMissingBaseURL() {
    let err = ChatProviderError.missingBaseURL("Qwen")
    XCTAssertTrue(err.errorDescription?.contains("Qwen") == true)
    XCTAssertTrue(err.errorDescription?.contains("baseURL") == true)
}

func testChatProviderErrorInvalidResponse() {
    let err = ChatProviderError.invalidResponse
    XCTAssertTrue(err.errorDescription?.contains("无效响应") == true)
}

func testChatProviderErrorHTTPError() {
    let err = ChatProviderError.httpError(502, "Bad Gateway")
    XCTAssertTrue(err.errorDescription?.contains("502") == true)
    XCTAssertTrue(err.errorDescription?.contains("Bad Gateway") == true)
    XCTAssertTrue(err.isRecoverableNetworkFailure)
}

func testChatProviderErrorHTTPRateLimitIsActionable() {
    let err = ChatProviderError.httpError(429, "Too Many Requests")
    XCTAssertTrue(err.errorDescription?.contains("限流") == true)
    XCTAssertTrue(err.isRecoverableNetworkFailure)
}

func testChatProviderTransportTimeoutMapping() {
    let err = ChatProviderError.fromTransport(URLError(.timedOut))
    XCTAssertTrue(err.errorDescription?.contains("超时") == true)
    XCTAssertTrue(err.isRecoverableNetworkFailure)
}

func testChatProviderTransportNetworkMapping() {
    let err = ChatProviderError.fromTransport(URLError(.notConnectedToInternet))
    XCTAssertTrue(err.errorDescription?.contains("网络不可用") == true)
    XCTAssertTrue(err.errorDescription?.contains("本地 OpenAI-Compatible") == true)
    XCTAssertTrue(err.isRecoverableNetworkFailure)
}

func testChatProviderErrorAllCasesDistinct() {
    let cases: [ChatProviderError] = [
        .missingAPIKey("A"),
        .missingBaseURL("B"),
        .invalidResponse,
        .httpError(200, "ok"),
        .networkUnavailable("offline"),
        .timedOut("slow"),
        .transport("tls")
    ]
    let descriptions = Set(cases.compactMap(\.errorDescription))
    XCTAssertTrue(descriptions.count == 7)
}

// MARK: - OpenAICompatibleChatProvider init

func testOpenAICompatibleChatProviderInitWithEndpoint() {
    let endpoint = ProviderEndpoint(
        kind: .qwen,
        displayName: "测试 Qwen",
        apiKeyEnvironmentVariable: "QWEN_KEY"
    )
    let provider = OpenAICompatibleChatProvider(endpoint: endpoint)
    XCTAssertTrue(provider.name == "测试 Qwen")
}

func testOpenAICompatibleChatProviderInitWithExplicitAPIKey() {
    let endpoint = ProviderEndpoint(kind: .deepSeek, apiKeyEnvironmentVariable: "DS_KEY")
    let provider = OpenAICompatibleChatProvider(endpoint: endpoint, apiKey: "sk-test")
    XCTAssertTrue(provider.name.contains("DeepSeek") == true)
}

// MARK: - ProviderEndpoint defaults

func testProviderEndpointDefaultsForQwen() {
    let ep = ProviderEndpoint(kind: .qwen)
    XCTAssertTrue(ep.displayName == "Qwen")
    XCTAssertTrue(ep.model == "qwen-plus")
    XCTAssertTrue(ep.baseURL?.absoluteString == "https://dashscope.aliyuncs.com/compatible-mode/v1")
    XCTAssertTrue(ep.apiKeyEnvironmentVariable == "DASHSCOPE_API_KEY")
}

func testProviderEndpointDefaultsForMoonshot() {
    let ep = ProviderEndpoint(kind: .moonshot)
    XCTAssertTrue(ep.displayName == "Moonshot")
    XCTAssertTrue(ep.model == "moonshot-v1-8k")
}

func testProviderEndpointDefaultsForLocalOpenAI() {
    let ep = ProviderEndpoint(kind: .localOpenAICompatible)
    XCTAssertTrue(ep.apiKeyEnvironmentVariable.isEmpty)
}

func testProviderEndpointCustomOverride() {
    let ep = ProviderEndpoint(
        kind: .openAICompatibleChat,
        displayName: "自定义",
        baseURL: URL(string: "https://proxy.example.com/v1"),
        model: "custom-model",
        apiKeyEnvironmentVariable: "CUSTOM_KEY"
    )
    XCTAssertTrue(ep.displayName == "自定义")
    XCTAssertTrue(ep.baseURL?.absoluteString == "https://proxy.example.com/v1")
    XCTAssertTrue(ep.model == "custom-model")
    XCTAssertTrue(ep.apiKeyEnvironmentVariable == "CUSTOM_KEY")
}
