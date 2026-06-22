import Foundation
import RenJistrolyModels

/// Generic backend for any OpenAI-compatible API (DeepSeek, Ollama, custom endpoints, etc.)
public actor CloudOpenAICompatibleBackend: LLMBackend {
    public nonisolated let provider: LLMProvider
    private var apiKey: String?
    private let baseURL: String
    private let session: URLSession

    public init(provider: LLMProvider, baseURL: String, apiKey: String? = nil, session: URLSession = .shared) {
        self.provider = provider
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.apiKey = apiKey
        self.session = session
    }

    public var isAvailable: Bool {
        get async { apiKey?.isEmpty == false }
    }

    public func configure(apiKey: String) {
        self.apiKey = apiKey
    }

    public func chat(
        messages: [Message],
        config: LLMConfiguration,
        tools: [ToolDefinition]?,
        delegate: LLMStreamingDelegate?
    ) async throws -> Message {
        let request = try buildRequest(messages: messages, config: config, tools: tools, stream: false)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw CloudError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        return try parseResponse(data: data)
    }

    public func chatStream(
        messages: [Message],
        config: LLMConfiguration,
        tools: [ToolDefinition]?,
        delegate: LLMStreamingDelegate?
    ) async throws -> AsyncStream<String> {
        let request = try buildRequest(messages: messages, config: config, tools: tools, stream: true)
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw CloudError.httpError(statusCode: httpResponse.statusCode, body: "")
        }

        let responseID = UUID()

        return AsyncStream { continuation in
            Task {
                var fullText = ""
                var pendingToolCalls: [Int: (id: String, name: String, arguments: String)] = [:]
                do {
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        if json == "[DONE]" {
                            continuation.finish()
                            delegate?.onComplete(messageID: responseID, totalTokens: fullText.count)
                            return
                        }
                        guard let data = json.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: data) else { continue }

                        if let delta = chunk.choices.first?.delta {
                            if let text = delta.content {
                                fullText += text
                                continuation.yield(text)
                                delegate?.onToken(text, messageID: responseID)
                            }
                            if let toolCalls = delta.tool_calls {
                                for tc in toolCalls {
                                    if tc.type == "function" {
                                        let index = tc.index ?? 0
                                        if var existing = pendingToolCalls[index] {
                                            existing.arguments += (tc.function?.arguments ?? "")
                                            pendingToolCalls[index] = existing
                                        } else {
                                            pendingToolCalls[index] = (
                                                id: tc.id ?? UUID().uuidString,
                                                name: tc.function?.name ?? "",
                                                arguments: tc.function?.arguments ?? ""
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        if chunk.choices.first?.finishReason == "tool_calls" {
                            for (_, call) in pendingToolCalls.sorted(by: { $0.key < $1.key }) {
                                let args: [String: String]
                                if let data = call.arguments.data(using: .utf8),
                                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                    args = json.mapValues { value -> String in
                                        if let s = value as? String { return s }
                                        if let n = value as? NSNumber { return n.stringValue }
                                        if let b = value as? Bool { return b ? "true" : "false" }
                                        return "\(value)"
                                    }
                                } else {
                                    args = [:]
                                }
                                let request = ToolCallRequest(
                                    id: call.id,
                                    name: call.name,
                                    arguments: args
                                )
                                delegate?.onToolCall(request, messageID: responseID)
                            }
                            continuation.finish()
                            delegate?.onComplete(messageID: responseID, totalTokens: fullText.count)
                            return
                        }
                    }
                } catch {
                    delegate?.onError(error, messageID: responseID)
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Private

    private struct OpenAIRequest: Encodable {
        let model: String
        let messages: [OpenAIMessage]
        let max_tokens: Int?
        let temperature: Double
        let top_p: Double?
        let tools: [OpenAITool]?
        let stream: Bool
        let stream_options: StreamOptions?

        struct OpenAIMessage: Encodable {
            let role: String
            let content: String
        }

        struct OpenAITool: Encodable {
            let type: String = "function"
            let function: FunctionDef

            struct FunctionDef: Encodable {
                let name: String
                let description: String
                let parameters: ParametersDef

                struct ParametersDef: Encodable {
                    let type: String = "object"
                    let properties: [String: PropertyDef]
                    let required: [String]?

                    struct PropertyDef: Encodable {
                        let type: String
                        let description: String
                    }
                }
            }
        }

        struct StreamOptions: Encodable {
            let include_usage: Bool = true
        }
    }

    private struct OpenAIResponse: Decodable {
        let id: String
        let choices: [Choice]

        struct Choice: Decodable {
            let message: MessageContent

            struct MessageContent: Decodable {
                let role: String
                let content: String?
                let tool_calls: [ToolCallContent]?

                struct ToolCallContent: Decodable {
                    let id: String
                    let function: FunctionCall

                    struct FunctionCall: Decodable {
                        let name: String
                        let arguments: String
                    }
                }
            }
        }
    }

    private struct OpenAIStreamChunk: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let delta: Delta?
            let finishReason: String?

            enum CodingKeys: String, CodingKey {
                case delta
                case finishReason = "finish_reason"
            }

            struct Delta: Decodable {
                let role: String?
                let content: String?
                let tool_calls: [ToolCallDelta]?

                struct ToolCallDelta: Decodable {
                    let index: Int?
                    let id: String?
                    let type: String?
                    let function: FunctionDelta?
                    struct FunctionDelta: Decodable {
                        let name: String?
                        let arguments: String?
                    }
                }
            }
        }
    }

    private func buildRequest(
        messages: [Message],
        config: LLMConfiguration,
        tools: [ToolDefinition]?,
        stream: Bool
    ) throws -> URLRequest {
        let apiURL = baseURL.hasSuffix("/v1") ? "\(baseURL)/chat/completions"
            : baseURL.hasSuffix("/v1/chat/completions") ? baseURL
            : "\(baseURL)/v1/chat/completions"

        guard let url = URL(string: apiURL) else { throw CloudError.invalidURL }

        let openAIMessages: [OpenAIRequest.OpenAIMessage] = messages.map { msg in
            let role: String = {
                switch msg.role {
                case .system: return "system"
                case .user: return "user"
                case .assistant: return "assistant"
                case .tool: return "tool"
                }
            }()
            return .init(role: role, content: msg.textContent)
        }

        let openAITools: [OpenAIRequest.OpenAITool]? = tools?.map { tool in
            var properties: [String: OpenAIRequest.OpenAITool.FunctionDef.ParametersDef.PropertyDef] = [:]
            for param in tool.parameters {
                properties[param.name] = .init(type: param.type.rawValue, description: param.description)
            }
            let required = tool.parameters.filter(\.required).map(\.name)
            return .init(function: .init(
                name: tool.name,
                description: tool.description,
                parameters: .init(properties: properties, required: required.isEmpty ? nil : required)
            ))
        }

        let requestBody = OpenAIRequest(
            model: config.model,
            messages: openAIMessages,
            max_tokens: config.maxTokens,
            temperature: config.temperature,
            top_p: config.topP,
            tools: openAITools,
            stream: stream,
            stream_options: stream ? OpenAIRequest.StreamOptions() : nil
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey, !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        urlRequest.timeoutInterval = 120

        return urlRequest
    }

    private func parseResponse(data: Data) throws -> Message {
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let choice = response.choices.first else {
            throw CloudError.invalidResponse
        }
        var blocks: [ContentBlock] = []
        if let text = choice.message.content {
            blocks.append(.text(text))
        }
        if let toolCalls = choice.message.tool_calls {
            for tc in toolCalls {
                let args: [String: String]
                if let data = tc.function.arguments.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    args = json.mapValues { value -> String in
                        if let s = value as? String { return s }
                        if let n = value as? NSNumber { return n.stringValue }
                        if let b = value as? Bool { return b ? "true" : "false" }
                        return "\(value)"
                    }
                } else {
                    args = [:]
                }
                blocks.append(.toolCall(ToolCallRequest(
                    id: tc.id,
                    name: tc.function.name,
                    arguments: args
                )))
            }
        }
        return Message(
            id: UUID(uuidString: response.id) ?? UUID(),
            role: .assistant,
            content: blocks
        )
    }
}
