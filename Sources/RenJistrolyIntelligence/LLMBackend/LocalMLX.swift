import Foundation
import RenJistrolyModels

public actor LocalMLXBackend: LLMBackend {
    public nonisolated let provider: LLMProvider = .localMLX
    private let modelManager: LocalModelManager

    public init(modelManager: LocalModelManager = LocalModelManager()) {
        self.modelManager = modelManager
    }

    public var isAvailable: Bool {
        get async { true } // Always available — CommandParser is built-in
    }

    public var isUsingRealModel: Bool {
        get async { await modelManager.canRunInference }
    }

    public var discoveredModels: [LocalModelInfo] {
        get async { await modelManager.models }
    }

    public func chat(
        messages: [Message],
        config: LLMConfiguration,
        tools: [ToolDefinition]?,
        delegate: LLMStreamingDelegate?
    ) async throws -> Message {
        let responseID = UUID()
        let startTime = Date()

        guard let lastUserIdx = messages.lastIndex(where: { $0.role == .user }) else {
            return Message(id: responseID, role: .assistant, content: [.text("请说点什么。")], timestamp: startTime)
        }

        let lastUserMessage = messages[lastUserIdx].textContent

        let afterLastUser = messages[(lastUserIdx + 1)...]
        let alreadyHandled = afterLastUser.contains { msg in
            msg.role == .tool
            || msg.content.contains { if case .toolResult = $0 { true } else { false } }
            || (msg.role == .assistant && msg.hasToolCalls)
        }

        if alreadyHandled {
            let count = afterLastUser.filter { $0.role == .tool }.count
            return Message(
                id: responseID,
                role: .assistant,
                content: [.text("已完成 — 执行了 \(count) 个操作。")],
                timestamp: startTime,
                tokenCount: 20
            )
        }

        // Try MLX model inference first, fall back to CommandParser
        if await modelManager.canRunInference, let model = await modelManager.models.first {
            do {
                let response = try await modelManager.generate(
                    model: model,
                    prompt: lastUserMessage,
                    maxTokens: config.maxTokens,
                    temperature: Float(config.temperature)
                )
                return Message(
                    id: responseID,
                    role: .assistant,
                    content: [.text(response)],
                    timestamp: startTime,
                    tokenCount: response.count
                )
            } catch {
                // Fall through to CommandParser on inference failure
            }
        }

        try Task.checkCancellation()

        let parsed = CommandParser.parse(lastUserMessage, tools: tools ?? [])

        let textBlock = ContentBlock.text(parsed.response)
        let toolBlocks = parsed.toolCalls.map { ContentBlock.toolCall($0) }
        let allBlocks = [textBlock] + toolBlocks

        return Message(
            id: responseID,
            role: .assistant,
            content: allBlocks,
            timestamp: startTime,
            tokenCount: parsed.response.count
        )
    }

    public func chatStream(
        messages: [Message],
        config: LLMConfiguration,
        tools: [ToolDefinition]?,
        delegate: LLMStreamingDelegate?
    ) async throws -> AsyncStream<String> {
        let responseID = UUID()

        let lastUserMessage = messages.last { $0.role == .user }?.textContent ?? ""

        // Try MLX model inference first
        var modelResponse: String?
        if await modelManager.canRunInference, let model = await modelManager.models.first {
            do {
                modelResponse = try await modelManager.generate(
                    model: model,
                    prompt: lastUserMessage,
                    maxTokens: config.maxTokens,
                    temperature: Float(config.temperature)
                )
            } catch {
                // Fall through
            }
        }

        let responseText = modelResponse ?? CommandParser.parse(lastUserMessage, tools: tools ?? []).response

        return AsyncStream { continuation in
            Task {
                let words = responseText.split(separator: " ")
                for word in words {
                    guard !Task.isCancelled else { break }
                    let token = String(word) + " "
                    continuation.yield(token)
                    delegate?.onToken(token, messageID: responseID)
                    try? await Task.sleep(for: .milliseconds(30))
                }
                continuation.finish()
                delegate?.onComplete(messageID: responseID, totalTokens: responseText.count)
            }
        }
    }
}
