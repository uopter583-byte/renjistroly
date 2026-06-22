import Foundation

public struct AudioFrame: Sendable, Equatable {
    public let data: Data
    public let sampleRate: Double
    public let channelCount: Int
    public let timestamp: Date

    public init(data: Data, sampleRate: Double, channelCount: Int, timestamp: Date = Date()) {
        self.data = data
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.timestamp = timestamp
    }
}

public enum TranscriptEvent: Sendable, Equatable {
    case partial(String)
    case final(String)
    case failed(String)
}

public enum TurnEvent: Sendable, Equatable {
    case started
    case speechDetected
    case ended
    case cancelled
}

public enum RealtimeEvent: Sendable, Equatable {
    case sessionStarted
    case transcriptDelta(String)
    case assistantTextDelta(String)
    case assistantAudioDelta(Data)
    case toolCallRequested(MacAction)
    case interrupted
    case completed
    case failed(String)
}

public struct VoiceSessionState: Sendable, Equatable {
    public var isListening: Bool
    public var isSpeaking: Bool
    public var isConversationMode: Bool
    public var isThinking: Bool
    public var latestTranscript: String
    public var latestAssistantText: String

    public init(
        isListening: Bool = false,
        isSpeaking: Bool = false,
        isConversationMode: Bool = false,
        isThinking: Bool = false,
        latestTranscript: String = "",
        latestAssistantText: String = ""
    ) {
        self.isListening = isListening
        self.isSpeaking = isSpeaking
        self.isConversationMode = isConversationMode
        self.isThinking = isThinking
        self.latestTranscript = latestTranscript
        self.latestAssistantText = latestAssistantText
    }
}
