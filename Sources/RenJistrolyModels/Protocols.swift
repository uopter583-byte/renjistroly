import Foundation

public protocol LLMStreamingDelegate: AnyObject, Sendable {
    func onToken(_ token: String, messageID: UUID)
    func onToolCall(_ request: ToolCallRequest, messageID: UUID)
    func onComplete(messageID: UUID, totalTokens: Int)
    func onError(_ error: Error, messageID: UUID)
}

public protocol STTProvider: Sendable {
    func transcribe(_ audioData: Data, language: String) async throws -> String
    func startStreaming() async throws -> AsyncStream<String>
    func stopStreaming()
}

public protocol LLMBackend: Sendable {
    var provider: LLMProvider { get }
    var isAvailable: Bool { get async }

    func chat(
        messages: [Message],
        config: LLMConfiguration,
        tools: [ToolDefinition]?,
        delegate: LLMStreamingDelegate?
    ) async throws -> Message

    func chatStream(
        messages: [Message],
        config: LLMConfiguration,
        tools: [ToolDefinition]?,
        delegate: LLMStreamingDelegate?
    ) async throws -> AsyncStream<String>
}

// MARK: - System Bridge Protocols

/// 精确行滚动能力（AX API 抽象层，可 mock）
public protocol AccessibilityScrolling: Sendable {
    func scroll(deltaY: Int, deltaX: Int, lines: Int) async throws
}

// MARK: - Tool Definition

public struct ToolDefinition: Codable, Sendable, Hashable {
    public let name: String
    public let description: String
    public let parameters: [Parameter]

    public init(name: String, description: String, parameters: [Parameter]) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }

    public struct Parameter: Codable, Sendable, Hashable {
        public let name: String
        public let type: ParameterType
        public let description: String
        public let required: Bool

        public init(name: String, type: ParameterType, description: String, required: Bool = true) {
            self.name = name
            self.type = type
            self.description = description
            self.required = required
        }

        public enum ParameterType: String, Codable, Sendable, Hashable {
            case string
            case number
            case boolean
            case object
            case array
        }
    }
}
