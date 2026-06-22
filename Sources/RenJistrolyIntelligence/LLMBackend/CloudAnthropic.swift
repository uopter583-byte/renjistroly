import Foundation
import RenJistrolyModels

public actor CloudAnthropicBackend: LLMBackend {
    public nonisolated let provider: LLMProvider = .anthropic
    private var apiKey: String?
    private let session: URLSession

    public init(apiKey: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public var isAvailable: Bool {
        get async { (apiKey?.isEmpty) == false }
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
                do {
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        if json == "[DONE]" {
                            continuation.finish()
                            delegate?.onComplete(messageID: responseID, totalTokens: fullText.count)
                            return
                        }
                        guard let data = json.data(using: .utf8) else { continue }
                        let event: AnthropicStreamEvent
                        do {
                            event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: data)
                        } catch {
                            delegate?.onError(error, messageID: responseID)
                            continue
                        }

                        switch event.type {
                        case "content_block_delta":
                            if let text = event.delta?.text {
                                fullText += text
                                continuation.yield(text)
                                delegate?.onToken(text, messageID: responseID)
                            }
                        case "content_block_start":
                            if let block = event.contentBlock, block.type == "tool_use" {
                                let request = ToolCallRequest(
                                    id: block.id ?? UUID().uuidString,
                                    name: block.name ?? "",
                                    arguments: block.input ?? [:]
                                )
                                delegate?.onToolCall(request, messageID: responseID)
                            }
                        default:
                            break
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

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"

    private struct AnthropicRequest: Encodable {
        let model: String
        let max_tokens: Int
        let temperature: Double
        let top_p: Double?
        let system: String?
        let messages: [AnthropicMessage]
        let tools: [AnthropicTool]?
        let stream: Bool

        struct AnthropicMessage: Encodable {
            let role: String
            let content: [AnthropicContent]

            struct AnthropicContent: Encodable {
                let type: String
                let text: String?
                let id: String?
                let name: String?
                let input: [String: String]?
                let tool_use_id: String?
                let content: String?
                let source: ImageSourceData?

                struct ImageSourceData: Encodable {
                    let type: String = "base64"
                    let media_type: String
                    let data: String
                }

                init(type: String, text: String?, toolUseID: String?, toolResult: String?, source: ImageSourceData? = nil) {
                    self.type = type
                    self.text = text
                    self.id = toolUseID
                    self.name = nil
                    self.input = nil
                    self.tool_use_id = toolUseID
                    self.content = toolResult
                    self.source = source
                }

                static func imageContent(from imageSource: ContentBlock.ImageSource) -> AnthropicContent? {
                    switch imageSource {
                    case .base64(let data, let mimeType):
                        return AnthropicContent(
                            type: "image",
                            text: nil,
                            toolUseID: nil,
                            toolResult: nil,
                            source: ImageSourceData(media_type: mimeType, data: data)
                        )
                    case .url, .filePath:
                        return nil
                    }
                }

                enum CodingKeys: String, CodingKey {
                    case type, text, id, name, input, tool_use_id, content, source
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encode(type, forKey: .type)
                    try container.encodeIfPresent(text, forKey: .text)
                    try container.encodeIfPresent(id, forKey: .id)
                    try container.encodeIfPresent(name, forKey: .name)
                    try container.encodeIfPresent(input, forKey: .input)
                    try container.encodeIfPresent(tool_use_id, forKey: .tool_use_id)
                    try container.encodeIfPresent(content, forKey: .content)
                    try container.encodeIfPresent(source, forKey: .source)
                }
            }
        }

        struct AnthropicTool: Encodable {
            let name: String
            let description: String
            let input_schema: InputSchema

            struct InputSchema: Encodable {
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

    private struct AnthropicResponse: Decodable {
        let id: String
        let content: [ContentBlock]

        struct ContentBlock: Decodable {
            let type: String
            let text: String?
            let id: String?
            let name: String?
            let input: [String: String]?
        }
    }

    private struct AnthropicStreamEvent: Decodable {
        let type: String
        let delta: DeltaContent?
        let contentBlock: ContentBlockInfo?

        struct DeltaContent: Decodable {
            let type: String?
            let text: String?
        }

        struct ContentBlockInfo: Decodable {
            let type: String?
            let id: String?
            let name: String?
            let input: [String: String]?
        }
    }

    private func buildRequest(
        messages: [Message],
        config: LLMConfiguration,
        tools: [ToolDefinition]?,
        stream: Bool
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL) else { throw CloudError.invalidURL }

        let systemPrompt = messages.first { $0.role == .system }?.textContent

        let anthropicMessages: [AnthropicRequest.AnthropicMessage] = messages
            .filter { $0.role == .user || $0.role == .assistant }
            .map { msg in
                let role: String = msg.role == .user ? "user" : "assistant"
                let blocks: [AnthropicRequest.AnthropicMessage.AnthropicContent] = msg.content
                    .compactMap { block in
                        switch block {
                        case .text(let text):
                            return .init(type: "text", text: text, toolUseID: nil, toolResult: nil)
                        case .toolCall(let req):
                            return .init(type: "tool_use", text: nil, toolUseID: req.id, toolResult: nil)
                        case .toolResult(let res):
                            return .init(type: "tool_result", text: nil, toolUseID: res.id, toolResult: res.output)
                        case .image(let imageSource):
                            return AnthropicRequest.AnthropicMessage.AnthropicContent.imageContent(from: imageSource)
                        case .file:
                            return nil
                        }
                    }
                return .init(role: role, content: blocks)
            }

        let anthropicTools: [AnthropicRequest.AnthropicTool]? = tools?.map { tool in
            var properties: [String: AnthropicRequest.AnthropicTool.InputSchema.PropertyDef] = [:]
            for param in tool.parameters {
                properties[param.name] = .init(type: param.type.rawValue, description: param.description)
            }
            let required = tool.parameters.filter(\.required).map(\.name)
            return .init(
                name: tool.name,
                description: tool.description,
                input_schema: .init(properties: properties, required: required.isEmpty ? nil : required)
            )
        }

        let requestBody = AnthropicRequest(
            model: config.model,
            max_tokens: config.maxTokens,
            temperature: config.temperature,
            top_p: config.topP,
            system: systemPrompt,
            messages: anthropicMessages,
            tools: anthropicTools,
            stream: stream
        )

        guard let apiKey else { throw CloudError.missingAPIKey }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONEncoder().encode(requestBody)
        urlRequest.timeoutInterval = 120

        return urlRequest
    }

    private func parseResponse(data: Data) throws -> Message {
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let blocks: [ContentBlock] = response.content.compactMap { block in
            switch block.type {
            case "text":
                if let text = block.text { return .text(text) }
            case "tool_use":
                if let id = block.id, let name = block.name {
                    return .toolCall(ToolCallRequest(id: id, name: name, arguments: block.input ?? [:]))
                }
            default:
                break
            }
            return nil
        }
        return Message(
            id: UUID(uuidString: response.id) ?? UUID(),
            role: .assistant,
            content: blocks
        )
    }
}

public enum CloudError: Error, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case missingAPIKey
}

extension CloudError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "API 地址配置错误，请检查设置"
        case .invalidResponse:
            return "服务器返回了无法解析的响应，请重试"
        case .httpError(let code, let body):
            return "请求失败 (HTTP \(code))，\(body)"
        case .missingAPIKey:
            return "API 密钥未配置，请在设置中添加"
        }
    }
}
