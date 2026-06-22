import Foundation
import OSLog
import RenJistrolyModels

public actor CloudGoogleBackend: LLMBackend {
    public nonisolated let provider: LLMProvider = .google
    private var apiKey: String?
    private let session: URLSession

    public init(apiKey: String? = nil, session: URLSession = .shared) {
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
        guard let apiKey else { throw CloudError.missingAPIKey }
        let request = try buildRequest(messages: messages, config: config, tools: tools, apiKey: apiKey)
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
        guard let apiKey else { throw CloudError.missingAPIKey }
        let request = try buildStreamRequest(messages: messages, config: config, tools: tools, apiKey: apiKey)
        let (bytes, response) = try await session.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            throw CloudError.httpError(statusCode: httpResponse.statusCode, body: "")
        }

        let responseID = UUID()

        return AsyncStream { continuation in
            let streamTask = Task {
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
                        guard let data = json.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(GeminiStreamChunk.self, from: data) else { continue }

                        if let text = chunk.candidates?.first?.content?.parts?.first?.text {
                            fullText += text
                            continuation.yield(text)
                            delegate?.onToken(text, messageID: responseID)
                        }
                    }
                } catch {
                    delegate?.onError(error, messageID: responseID)
                    continuation.finish()
                }
            }
            continuation.onTermination = { @Sendable _ in
                streamTask.cancel()
            }
        }
    }

    // MARK: - Private

    private struct GeminiRequest: Encodable {
        let contents: [Content]
        let systemInstruction: SystemInstruction?
        let tools: [Tool]?
        let generationConfig: GenerationConfig?

        struct Content: Encodable {
            let role: String
            let parts: [Part]
        }

        struct Part: Encodable {
            let text: String
        }

        struct SystemInstruction: Encodable {
            let parts: [Part]
        }

        struct Tool: Encodable {
            let functionDeclarations: [FunctionDeclaration]

            enum CodingKeys: String, CodingKey {
                case functionDeclarations = "function_declarations"
            }
        }

        struct FunctionDeclaration: Encodable {
            let name: String
            let description: String
            let parameters: ParametersDef?

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

        struct GenerationConfig: Encodable {
            let maxOutputTokens: Int?
            let temperature: Double?

            enum CodingKeys: String, CodingKey {
                case maxOutputTokens = "max_output_tokens"
                case temperature
            }
        }
    }

    private struct GeminiResponse: Decodable {
        let candidates: [Candidate]?

        struct Candidate: Decodable {
            let content: Content

            struct Content: Decodable {
                let role: String
                let parts: [Part]?

                struct Part: Decodable {
                    let text: String?
                    let functionCall: FunctionCall?

                    struct FunctionCall: Decodable {
                        let name: String
                        let args: [String: JSONValue]
                    }

                    enum CodingKeys: String, CodingKey {
                        case text
                        case functionCall = "function_call"
                    }
                }
            }
        }
    }

    private struct GeminiStreamChunk: Decodable {
        let candidates: [Candidate]?

        struct Candidate: Decodable {
            let content: Content?

            struct Content: Decodable {
                let parts: [Part]?

                struct Part: Decodable {
                    let text: String?
                }
            }
        }
    }

    private struct JSONValue: Decodable {
        let value: Any

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let s = try? container.decode(String.self) { value = s }
            else if let n = try? container.decode(Double.self) { value = n }
            else if let b = try? container.decode(Bool.self) { value = b }
            else if let a = try? container.decode([String].self) { value = a }
            else if let d = try? container.decode([String: JSONValue].self) { value = d.mapValues { $0.value } }
            else { value = "null" }
        }
    }

    private func buildRequest(
        messages: [Message],
        config: LLMConfiguration,
        tools: [ToolDefinition]?,
        apiKey: String
    ) throws -> URLRequest {
        let model = config.model
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            os_log(.fault, "Invalid Gemini URL for model %{public}@", model)
            throw CloudError.invalidURL
        }

        let body = buildRequestBody(messages: messages, config: config, tools: tools)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        request.timeoutInterval = 120
        return request
    }

    private func buildStreamRequest(
        messages: [Message],
        config: LLMConfiguration,
        tools: [ToolDefinition]?,
        apiKey: String
    ) throws -> URLRequest {
        let model = config.model
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(apiKey)") else {
            os_log(.fault, "Invalid Gemini stream URL for model %{public}@", model)
            throw CloudError.invalidURL
        }

        let body = buildRequestBody(messages: messages, config: config, tools: tools)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)
        request.timeoutInterval = 120
        return request
    }

    private func buildRequestBody(
        messages: [Message],
        config: LLMConfiguration,
        tools: [ToolDefinition]?
    ) -> GeminiRequest {
        var contents: [GeminiRequest.Content] = []
        var systemInstruction: GeminiRequest.SystemInstruction?

        for msg in messages {
            let role: String = switch msg.role {
            case .system: "user"
            case .user: "user"
            case .assistant: "model"
            case .tool: "user"
            }

            if msg.role == .system {
                systemInstruction = GeminiRequest.SystemInstruction(parts: [.init(text: msg.textContent)])
            } else {
                contents.append(.init(role: role, parts: [.init(text: msg.textContent)]))
            }
        }

        let geminiTools: [GeminiRequest.Tool]? = {
            guard let tools, !tools.isEmpty else { return nil }
            let decls = tools.map { tool -> GeminiRequest.FunctionDeclaration in
                var properties: [String: GeminiRequest.FunctionDeclaration.ParametersDef.PropertyDef] = [:]
                for param in tool.parameters {
                    properties[param.name] = .init(type: param.type.rawValue.uppercased(), description: param.description)
                }
                let required = tool.parameters.filter(\.required).map(\.name)
                return .init(
                    name: tool.name,
                    description: tool.description,
                    parameters: .init(properties: properties, required: required.isEmpty ? nil : required)
                )
            }
            return [.init(functionDeclarations: decls)]
        }()

        return GeminiRequest(
            contents: contents,
            systemInstruction: systemInstruction,
            tools: geminiTools,
            generationConfig: .init(
                maxOutputTokens: config.maxTokens,
                temperature: config.temperature
            )
        )
    }

    private func parseResponse(data: Data) throws -> Message {
        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let candidate = response.candidates?.first else {
            throw CloudError.invalidResponse
        }
        var blocks: [ContentBlock] = []
        if let parts = candidate.content.parts {
            for part in parts {
                if let text = part.text {
                    blocks.append(.text(text))
                }
                if let fc = part.functionCall {
                    let args = fc.args.mapValues { v in
                        if let s = v.value as? String { return s }
                        return "\(v.value)"
                    }
                    blocks.append(.toolCall(ToolCallRequest(
                        id: fc.name,
                        name: fc.name,
                        arguments: args
                    )))
                }
            }
        }
        if blocks.isEmpty {
            blocks.append(.text(""))
        }
        return Message(
            id: UUID(),
            role: .assistant,
            content: blocks
        )
    }
}
