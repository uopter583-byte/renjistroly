import Foundation

public struct Conversation: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var title: String
    public var messages: [Message]
    public var createdAt: Date
    public var updatedAt: Date
    public var projectContext: ProjectContext?
    public var metadata: ConversationMetadata

    public init(
        id: UUID = UUID(),
        title: String = "新对话",
        messages: [Message] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        projectContext: ProjectContext? = nil,
        metadata: ConversationMetadata = ConversationMetadata()
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.projectContext = projectContext
        self.metadata = metadata
    }

    public struct ConversationMetadata: Codable, Sendable, Hashable {
        public var provider: LLMProvider?
        public var model: String?
        public var totalTokens: Int = 0
        public var isPinned: Bool = false
        public var tags: [String] = []

        public init(
            provider: LLMProvider? = nil,
            model: String? = nil,
            totalTokens: Int = 0,
            isPinned: Bool = false,
            tags: [String] = []
        ) {
            self.provider = provider
            self.model = model
            self.totalTokens = totalTokens
            self.isPinned = isPinned
            self.tags = tags
        }
    }
}

public struct Message: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let role: MessageRole
    public var content: [ContentBlock]
    public let timestamp: Date
    public var tokenCount: Int?

    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: [ContentBlock],
        timestamp: Date = Date(),
        tokenCount: Int? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.tokenCount = tokenCount
    }
}

public extension Message {
    var textContent: String {
        content.compactMap { block in
            if case .text(let text) = block { return text }
            return nil
        }.joined(separator: "\n")
    }

    var hasToolCalls: Bool {
        content.contains { block in
            if case .toolCall = block { return true }
            return false
        }
    }
}
