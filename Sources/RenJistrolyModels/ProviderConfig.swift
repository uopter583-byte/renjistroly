import Foundation

public enum ProviderKind: String, CaseIterable, Identifiable, Sendable, Codable {
    case openAIRealtime
    case openAICompatibleChat
    case deepSeek
    case qwen
    case moonshot
    case localOpenAICompatible
    case appleNative

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .openAIRealtime: "OpenAI Realtime"
        case .openAICompatibleChat: "OpenAI-compatible"
        case .deepSeek: "DeepSeek"
        case .qwen: "Qwen"
        case .moonshot: "Moonshot"
        case .localOpenAICompatible: "本地兼容端点"
        case .appleNative: "Apple 原生"
        }
    }

    public var defaultBaseURL: URL? {
        switch self {
        case .openAIRealtime:
            URL(string: "wss://api.openai.com/v1/realtime")
        case .openAICompatibleChat:
            URL(string: "https://api.openai.com/v1")
        case .deepSeek:
            URL(string: "https://api.deepseek.com")
        case .qwen:
            URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1")
        case .moonshot:
            URL(string: "https://api.moonshot.cn/v1")
        case .localOpenAICompatible:
            URL(string: "http://127.0.0.1:1234/v1")
        case .appleNative:
            nil
        }
    }

    public var defaultModel: String {
        switch self {
        case .openAIRealtime: "gpt-realtime-2"
        case .openAICompatibleChat: "gpt-5-mini"
        case .deepSeek: "deepseek-chat"
        case .qwen: "qwen-plus"
        case .moonshot: "moonshot-v1-8k"
        case .localOpenAICompatible: "local-model"
        case .appleNative: "apple-native"
        }
    }
}

public struct ProviderEndpoint: Identifiable, Sendable, Codable, Equatable {
    public var id: UUID
    public var kind: ProviderKind
    public var displayName: String
    public var baseURL: URL?
    public var model: String
    public var apiKeyEnvironmentVariable: String

    public init(
        id: UUID = UUID(),
        kind: ProviderKind,
        displayName: String? = nil,
        baseURL: URL? = nil,
        model: String? = nil,
        apiKeyEnvironmentVariable: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName ?? kind.title
        self.baseURL = baseURL ?? kind.defaultBaseURL
        self.model = model ?? kind.defaultModel
        self.apiKeyEnvironmentVariable = apiKeyEnvironmentVariable ?? Self.defaultEnvironmentVariable(for: kind)
    }

    public static func defaultEnvironmentVariable(for kind: ProviderKind) -> String {
        switch kind {
        case .openAIRealtime, .openAICompatibleChat: "OPENAI_API_KEY"
        case .deepSeek: "DEEPSEEK_API_KEY"
        case .qwen: "DASHSCOPE_API_KEY"
        case .moonshot: "MOONSHOT_API_KEY"
        case .localOpenAICompatible, .appleNative: ""
        }
    }
}

public struct ProviderCatalog: Sendable {
    public static let defaults: [ProviderEndpoint] = [
        ProviderEndpoint(kind: .openAIRealtime),
        ProviderEndpoint(kind: .deepSeek),
        ProviderEndpoint(kind: .qwen),
        ProviderEndpoint(kind: .moonshot),
        ProviderEndpoint(kind: .localOpenAICompatible),
        ProviderEndpoint(kind: .appleNative),
    ]
}
