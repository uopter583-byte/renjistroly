import Foundation
import OSLog
import RenJistrolyModels

@MainActor
@Observable
public final class SessionManager {
    public private(set) var conversations: [Conversation] = []
    public private(set) var activeConversationID: UUID?
    public var isStreaming: Bool = false
    public private(set) var lastSaveError: String?

    private let storageURL: URL?

    public init(storageURL: URL? = nil) {
        self.storageURL = storageURL
        loadConversations()
    }

    // MARK: - CRUD

    public func createConversation(title: String = "新对话") -> Conversation {
        let conversation = Conversation(title: title)
        conversations.append(conversation)
        activeConversationID = conversation.id
        saveConversations()
        return conversation
    }

    public func deleteConversation(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        if activeConversationID == id {
            activeConversationID = conversations.first?.id
        }
        saveConversations()
    }

    public func setActiveConversation(_ id: UUID) {
        guard conversations.contains(where: { $0.id == id }) else { return }
        activeConversationID = id
    }

    public var activeConversation: Conversation? {
        get { conversations.first { $0.id == activeConversationID } }
        set {
            guard let newValue else { return }
            if let index = conversations.firstIndex(where: { $0.id == newValue.id }) {
                conversations[index] = newValue
            }
            saveConversations()
        }
    }

    // MARK: - Messages

    public func appendMessage(_ message: Message, to conversationID: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        var conversation = conversations[index]
        let message = Self.sanitizedVisibleMessage(message)
        conversation.messages.append(message)
        conversation.updatedAt = Date()

        // Auto-title from first user message
        if conversation.title == "新对话",
           message.role == .user,
           let firstText = message.textContent.split(separator: "\n").first {
            let title = String(firstText).prefix(50).trimmingCharacters(in: .whitespaces)
            if !title.isEmpty { conversation.title = title }
        }

        conversations[index] = conversation
        saveConversations()
    }

    public func updateMessage(_ message: Message, in conversationID: UUID) {
        guard let convIndex = conversations.firstIndex(where: { $0.id == conversationID }) else { return }
        guard let msgIndex = conversations[convIndex].messages.firstIndex(where: { $0.id == message.id }) else { return }
        conversations[convIndex].messages[msgIndex] = Self.sanitizedVisibleMessage(message)
        saveConversations()
    }

    // MARK: - Streaming

    public func beginStreamingResponse(
        in conversationID: UUID,
        context: ProjectContext? = nil
    ) -> UUID {
        guard conversations.contains(where: { $0.id == conversationID }) else {
            isStreaming = false
            return UUID()
        }
        isStreaming = true
        let messageID = UUID()
        let message = Message(
            id: messageID,
            role: .assistant,
            content: [.text("")]
        )
        appendMessage(message, to: conversationID)
        return messageID
    }

    public func appendStreamToken(_ token: String, messageID: UUID, in conversationID: UUID) {
        guard let convIndex = conversations.firstIndex(where: { $0.id == conversationID }),
              let msgIndex = conversations[convIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }

        var message = conversations[convIndex].messages[msgIndex]
        var currentBlocks = message.content
        if case .text(let current) = currentBlocks.last {
            currentBlocks[currentBlocks.count - 1] = .text(current + token)
        } else {
            currentBlocks.append(.text(token))
        }
        message.content = currentBlocks
        conversations[convIndex].messages[msgIndex] = message
    }

    public func finishStreamingResponse(messageID: UUID, in conversationID: UUID) {
        isStreaming = false
        if let convIndex = conversations.firstIndex(where: { $0.id == conversationID }),
           let msgIndex = conversations[convIndex].messages.firstIndex(where: { $0.id == messageID }) {
            conversations[convIndex].messages[msgIndex].tokenCount = conversations[convIndex].messages[msgIndex].textContent.count
            conversations[convIndex].updatedAt = Date()
        }
        saveConversations()
    }

    // MARK: - Search

    public func searchConversations(_ query: String) -> [Conversation] {
        guard !query.isEmpty else { return conversations }
        let lowercased = query.lowercased()
        return conversations.filter { conv in
            conv.title.lowercased().contains(lowercased) ||
            conv.messages.contains { $0.textContent.lowercased().contains(lowercased) }
        }
    }

    // MARK: - Persistence

    private func saveConversations() {
        lastSaveError = nil
        guard let url = storageURL else { return }
        do {
            let dir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(conversations)
            try data.write(to: url, options: .atomic)
        } catch {
            lastSaveError = error.localizedDescription
            os_log(.error, "保存对话失败: %{public}@", error.localizedDescription)
        }
    }

    private func loadConversations() {
        guard let url = storageURL else { return }
        do {
            let data = try Data(contentsOf: url)
            let saved = try JSONDecoder().decode([Conversation].self, from: data)
            let sanitized = Self.sanitizedVisibleConversations(saved)
            conversations = sanitized.conversations
            activeConversationID = conversations.first?.id
            if sanitized.changed {
                saveConversations()
            }
        } catch {
            os_log(.error, "加载对话失败: %{public}@", error.localizedDescription)
        }
    }

    public static func defaultStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return appSupport
            .appendingPathComponent("RenJistroly")
            .appendingPathComponent("conversations.json")
    }

    static func sanitizedVisibleConversations(_ conversations: [Conversation]) -> (conversations: [Conversation], changed: Bool) {
        var changed = false
        let sanitized = conversations.map { conversation in
            var conversation = conversation
            let messages = conversation.messages.map { message in
                let clean = sanitizedVisibleMessage(message)
                if clean != message { changed = true }
                return clean
            }
            conversation.messages = messages
            return conversation
        }
        return (sanitized, changed)
    }

    static func sanitizedVisibleMessage(_ message: Message) -> Message {
        guard message.role != .system else { return message }
        var changed = false
        let blocks = message.content.map { block -> ContentBlock in
            guard case .text(let text) = block else { return block }
            let clean = sanitizeVisibleText(text)
            if clean != text { changed = true }
            return .text(clean)
        }
        guard changed else { return message }
        return Message(
            id: message.id,
            role: message.role,
            content: blocks,
            timestamp: message.timestamp,
            tokenCount: blocks.compactMap {
                if case .text(let text) = $0 { return text.count }
                return nil
            }.reduce(0, +)
        )
    }

    static func sanitizeVisibleText(_ text: String) -> String {
        var cleaned = text
        let lower = cleaned.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if lower.hasPrefix("not logged in") || lower == "please run /login" {
            cleaned = "Claude Code 需要先登录。请在终端运行 `claude /login`，登录完成后回到 RenJistroly 重试。"
        }
        for marker in ["\n\n技能上下文:", "\n\n已匹配技能:", "\n\n相关工作流记忆:", "\n\n相关代码:"] {
            if let range = cleaned.range(of: marker) {
                cleaned.removeSubrange(range.lowerBound..<cleaned.endIndex)
            }
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
