import Foundation

public protocol AudioCaptureService: Sendable {
    func start() async throws -> AsyncStream<AudioFrame>
    func stop() async
}

public protocol ASRProvider: Sendable {
    var name: String { get }
    func transcribe(_ frames: AsyncStream<AudioFrame>) async throws -> AsyncStream<TranscriptEvent>
}

public protocol VADProvider: Sendable {
    var name: String { get }
    func observe(_ frames: AsyncStream<AudioFrame>) async throws -> AsyncStream<TurnEvent>
}

public protocol TTSProvider: Sendable {
    var name: String { get }
    func speak(_ text: String) async throws
    func stop() async
}

public protocol ChatProvider: Sendable {
    var name: String { get }
    func complete(_ request: ChatRequest) async throws -> ChatResponse
    func stream(_ request: ChatRequest) async throws -> AsyncThrowingStream<String, Error>
}

public struct ChatMessage: Sendable, Codable, Equatable {
    public var role: String
    public var content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct ChatRequest: Sendable, Codable, Equatable {
    public var model: String
    public var messages: [ChatMessage]
    public var temperature: Double?
    public var maxTokens: Int?

    public init(model: String, messages: [ChatMessage], temperature: Double? = nil, maxTokens: Int? = nil) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

public struct ChatResponse: Sendable, Codable, Equatable {
    public var text: String
    public var provider: String
    public var model: String

    public init(text: String, provider: String, model: String) {
        self.text = text
        self.provider = provider
        self.model = model
    }
}

public protocol RealtimeSession: Sendable {
    var name: String { get }
    func connect(config: RealtimeConfig) async throws -> AsyncStream<RealtimeEvent>
    func sendAudio(_ frame: AudioFrame) async throws
    func sendText(_ text: String) async throws
    func updateInstructions(_ instructions: String) async throws
    func disconnect() async
}

public struct RealtimeConfig: Sendable, Equatable {
    public var model: String
    public var voice: String
    public var instructions: String

    public init(model: String = "gpt-realtime-2", voice: String = "marin", instructions: String) {
        self.model = model
        self.voice = voice
        self.instructions = instructions
    }
}
