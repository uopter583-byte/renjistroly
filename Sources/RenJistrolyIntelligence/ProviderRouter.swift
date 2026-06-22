import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

public enum ProviderPreference: String, CaseIterable, Sendable, Identifiable {
    case claudeCode
    case deepSeek
    case qwen
    case moonshot
    case localEndpoint
    case appleNative
    case localFirst
    case cloudRealtime

    public var id: String { rawValue }

    public static var selectableCases: [ProviderPreference] {
        [.claudeCode, .deepSeek, .qwen, .moonshot, .localEndpoint, .appleNative, .localFirst]
    }

    public var title: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .deepSeek: "DeepSeek"
        case .qwen: "Qwen"
        case .moonshot: "Moonshot"
        case .localEndpoint: "本地端点"
        case .appleNative: "Apple 原生"
        case .localFirst: "本地优先"
        case .cloudRealtime: "云端实时"
        }
    }

    public var isImplemented: Bool {
        self != .cloudRealtime
    }
}

public struct ProviderRouter: Sendable {
    public var preference: ProviderPreference
    public var speechRateMultiplier: Double

    public init(preference: ProviderPreference = .claudeCode, speechRateMultiplier: Double = 1.9) {
        self.preference = preference
        self.speechRateMultiplier = speechRateMultiplier
    }

    public func realtimeSession() -> any RealtimeSession {
        OpenAIRealtimeSession()
    }

    public func chatProvider() -> any ChatProvider {
        let kind: ProviderKind = switch preference {
        case .claudeCode: .localOpenAICompatible  // not used; Claude Code paths bypass this
        case .cloudRealtime: .openAICompatibleChat
        case .deepSeek: .deepSeek
        case .qwen: .qwen
        case .moonshot: .moonshot
        case .localEndpoint, .localFirst: .localOpenAICompatible
        case .appleNative: .localOpenAICompatible
        }
        return OpenAICompatibleChatProvider(endpoint: ProviderEndpoint(kind: kind))
    }

    @MainActor
    public func ttsProvider() -> any TTSProvider {
        SystemTextToSpeech(speechRateMultiplier: speechRateMultiplier)
    }

    @MainActor
    public func asrProvider() -> any ASRProvider {
        AppleSpeechProvider()
    }
}
