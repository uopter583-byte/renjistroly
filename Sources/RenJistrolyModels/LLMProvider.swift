import Foundation

public enum LLMProvider: String, Codable, Sendable, Hashable, CaseIterable {
    case claudeCodeCLI
    case codexCLI
    case localMLX
    case anthropic
    case openAI
    case google
    case deepseek
    case ollama
    case groq
    case mistral
    case cohere
    case replicate
    case togetherAI
    case perplexity
    case xAI
    case custom

    public var displayName: String {
        switch self {
        case .claudeCodeCLI: "Claude Code"
        case .codexCLI: "Codex"
        case .localMLX: "本地 MLX"
        case .anthropic: "Claude (Anthropic)"
        case .openAI: "OpenAI"
        case .google: "Gemini (Google)"
        case .deepseek: "DeepSeek"
        case .ollama: "Ollama"
        case .groq: "Groq"
        case .mistral: "Mistral"
        case .cohere: "Cohere"
        case .replicate: "Replicate"
        case .togetherAI: "Together AI"
        case .perplexity: "Perplexity"
        case .xAI: "xAI (Grok)"
        case .custom: "自定义"
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .claudeCodeCLI, .codexCLI, .localMLX, .ollama: false
        default: true
        }
    }

    public var isLocal: Bool {
        switch self {
        case .claudeCodeCLI, .codexCLI, .localMLX, .ollama: true
        default: false
        }
    }

    public var defaultBaseURL: String? {
        switch self {
        case .groq: "https://api.groq.com/openai"
        case .mistral: "https://api.mistral.ai"
        case .cohere: "https://api.cohere.ai"
        case .replicate: "https://api.replicate.com"
        case .togetherAI: "https://api.together.xyz"
        case .perplexity: "https://api.perplexity.ai"
        case .xAI: "https://api.x.ai"
        case .deepseek: "https://api.deepseek.com"
        default: nil
        }
    }

    public var defaultModel: String {
        switch self {
        case .groq: "llama-4-scout-17b-16e-instruct"
        case .mistral: "mistral-large-latest"
        case .cohere: "command-r-plus"
        case .replicate: "meta/llama-4-maverick"
        case .togetherAI: "meta-llama/Llama-4-Maverick-17B-128E-Instruct"
        case .perplexity: "sonar-pro"
        case .xAI: "grok-3"
        case .deepseek: "deepseek-chat"
        default: ""
        }
    }
}

public struct LLMConfiguration: Codable, Sendable, Hashable {
    public let provider: LLMProvider
    public let model: String
    public let apiKey: String?
    public let baseURL: URL?
    public let maxTokens: Int
    public let temperature: Double
    public let topP: Double?

    public init(
        provider: LLMProvider,
        model: String,
        apiKey: String? = nil,
        baseURL: URL? = nil,
        maxTokens: Int = 8192,
        temperature: Double = 0.7,
        topP: Double? = nil
    ) {
        self.provider = provider
        self.model = model
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.topP = topP
    }

    public static let defaultLocal = LLMConfiguration(
        provider: .localMLX,
        model: "mlx-community/Qwen3-8B-4bit",
        maxTokens: 4096,
        temperature: 0.7
    )

    public static let defaultCloud = LLMConfiguration(
        provider: .anthropic,
        model: "claude-sonnet-4-6",
        maxTokens: 8192,
        temperature: 0.7
    )
}
