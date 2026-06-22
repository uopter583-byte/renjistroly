import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

// @unchecked Sendable: holds non-Sendable URLSession and mutable endpoint/key state; used within URLSession delegate callback patterns
public final class OpenAICompatibleChatProvider: ChatProvider, @unchecked Sendable {
    public let name: String
    private let endpoint: ProviderEndpoint
    private let apiKey: String?
    private let urlSession: URLSession

    public init(endpoint: ProviderEndpoint, apiKey: String? = nil, urlSession: URLSession = .shared) {
        self.endpoint = endpoint
        self.name = endpoint.displayName
        self.apiKey = apiKey
            ?? OpenAIAPIKeyStore.load(account: endpoint.apiKeyEnvironmentVariable)
            ?? Self.environmentKey(endpoint.apiKeyEnvironmentVariable)
        self.urlSession = urlSession
    }

    public func complete(_ request: ChatRequest) async throws -> ChatResponse {
        let payload = ChatCompletionRequest(
            model: request.model.isEmpty ? endpoint.model : request.model,
            messages: request.messages.map { ChatCompletionMessage(role: $0.role, content: $0.content) },
            temperature: request.temperature,
            maxTokens: request.maxTokens,
            stream: false
        )
        let data = try await performRequest(payload: payload)
        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        let text = decoded.choices.first?.message.content ?? ""
        return ChatResponse(text: text, provider: endpoint.displayName, model: payload.model)
    }

    public func stream(_ request: ChatRequest) async throws -> AsyncThrowingStream<String, Error> {
        let payload = ChatCompletionRequest(
            model: request.model.isEmpty ? endpoint.model : request.model,
            messages: request.messages.map { ChatCompletionMessage(role: $0.role, content: $0.content) },
            temperature: request.temperature,
            maxTokens: request.maxTokens,
            stream: true
        )
        let urlRequest = try makeURLRequest(payload: payload)
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await urlSession.bytes(for: urlRequest)
        } catch {
            throw ChatProviderError.fromTransport(error)
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let http = response as? HTTPURLResponse {
                throw ChatProviderError.httpError(http.statusCode, HTTPURLResponse.localizedString(forStatusCode: http.statusCode))
            }
            throw ChatProviderError.invalidResponse
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" {
                            continuation.finish()
                            return
                        }
                        guard let data = payload.data(using: .utf8) else { continue }
                        let event = try JSONDecoder().decode(ChatCompletionStreamResponse.self, from: data)
                        if let delta = event.choices.first?.delta.content, !delta.isEmpty {
                            continuation.yield(delta)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func performRequest(payload: ChatCompletionRequest) async throws -> Data {
        let urlRequest = try makeURLRequest(payload: payload)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: urlRequest)
        } catch {
            throw ChatProviderError.fromTransport(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw ChatProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ChatProviderError.httpError(http.statusCode, body)
        }
        return data
    }

    private func makeURLRequest(payload: ChatCompletionRequest) throws -> URLRequest {
        guard let baseURL = endpoint.baseURL else {
            throw ChatProviderError.missingBaseURL(endpoint.displayName)
        }

        let url = baseURL.appending(path: "chat/completions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 30
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey, !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        } else if endpoint.kind != .localOpenAICompatible {
            throw ChatProviderError.missingAPIKey(endpoint.apiKeyEnvironmentVariable)
        }

        urlRequest.httpBody = try JSONEncoder().encode(payload)
        return urlRequest
    }

    private static func environmentKey(_ variable: String) -> String? {
        guard !variable.isEmpty else { return nil }
        let key = ProcessInfo.processInfo.environment[variable]
        return key?.isEmpty == false ? key : nil
    }
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatCompletionMessage]
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case stream
    }
}

private struct ChatCompletionMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatCompletionMessage
    }
}

private struct ChatCompletionStreamResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let delta: Delta
    }

    struct Delta: Decodable {
        let content: String?
    }
}

public enum ChatProviderError: Error, LocalizedError, Sendable {
    case missingAPIKey(String)
    case missingBaseURL(String)
    case invalidResponse
    case httpError(Int, String)
    case networkUnavailable(String)
    case timedOut(String)
    case transport(String)

    public static func fromTransport(_ error: Error) -> ChatProviderError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timedOut(urlError.localizedDescription)
            case .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .networkConnectionLost, .internationalRoamingOff, .dataNotAllowed:
                return .networkUnavailable(urlError.localizedDescription)
            default:
                return .transport(urlError.localizedDescription)
            }
        }
        return .transport(error.localizedDescription)
    }

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let variable):
            "缺少 API Key。请到设置页填写 \(variable)，或在环境变量中设置。"
        case .missingBaseURL(let provider):
            "Provider 缺少 baseURL：\(provider)"
        case .invalidResponse:
            "Provider 返回了无效响应。"
        case .httpError(let status, let body):
            if status == 401 || status == 403 {
                "Provider HTTP \(status)：认证失败，请检查 API Key 或账号权限。\(body)"
            } else if status == 408 || status == 504 {
                "Provider HTTP \(status)：请求超时，可能是网络、代理或上游服务不稳定。\(body)"
            } else if status == 429 {
                "Provider HTTP 429：请求被限流，请稍后重试或切换 Provider。\(body)"
            } else if (500..<600).contains(status) {
                "Provider HTTP \(status)：上游服务异常，可以切换 Provider 或稍后重试。\(body)"
            } else {
                "Provider HTTP \(status): \(body)"
            }
        case .networkUnavailable(let detail):
            "网络不可用或无法连接 Provider：\(detail)。请检查 Wi-Fi/VPN/代理/DNS，或切换到本地 OpenAI-Compatible 端点。"
        case .timedOut(let detail):
            "Provider 请求超时：\(detail)。可能是网络、代理、DNS 或上游服务过慢。"
        case .transport(let detail):
            "Provider 传输失败：\(detail)。请检查网络、代理、证书或本地端点是否启动。"
        }
    }

    public var isRecoverableNetworkFailure: Bool {
        switch self {
        case .networkUnavailable, .timedOut, .transport:
            true
        case .httpError(let status, _):
            status == 408 || status == 429 || (500..<600).contains(status)
        case .missingAPIKey, .missingBaseURL, .invalidResponse:
            false
        }
    }
}
