import Foundation
import CryptoKit

public actor ChatwootBridge {
    private let baseURL: String
    private let apiAccessToken: String
    private let accountID: String
    private let session: URLSession
    private var webhookSecret: String?

    public init(baseURL: String, apiAccessToken: String, accountID: String, session: URLSession = .shared) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.apiAccessToken = apiAccessToken
        self.accountID = accountID
        self.session = session
    }

    public func configureWebhook(secret: String) { webhookSecret = secret }

    // MARK: - Conversations

    public func listConversations(status: ConversationStatus? = nil, page: Int = 1) async throws -> [ChatwootConversation] {
        var params = ["page": "\(page)"]
        if let status { params["status"] = status.rawValue }
        let data = try await get("/api/v1/accounts/\(accountID)/conversations", params: params)
        return try decode(data, key: "data.payload")
    }

    public func getConversation(id: Int) async throws -> ChatwootConversation {
        let data = try await get("/api/v1/accounts/\(accountID)/conversations/\(id)")
        return try decode(data)
    }

    @discardableResult
    public func toggleConversationStatus(id: Int, status: ConversationStatus) async throws -> Data {
        try await post("/api/v1/accounts/\(accountID)/conversations/\(id)/toggle_status", body: ["status": status.rawValue])
    }

    @discardableResult
    public func assignConversation(id: Int, assigneeID: Int) async throws -> Data {
        try await post("/api/v1/accounts/\(accountID)/conversations/\(id)/assignments", body: ["assignee_id": "\(assigneeID)"])
    }

    // MARK: - Messages

    public func sendMessage(conversationID: Int, content: String, contentType: MessageContentType = .text, privateNote: Bool = false) async throws -> ChatwootMessage {
        var body: [String: Any] = ["content": content, "message_type": contentType.rawValue, "private": privateNote]
        if contentType == .incoming { body["message_type"] = "incoming" }
        let data = try await post("/api/v1/accounts/\(accountID)/conversations/\(conversationID)/messages", body: body)
        return try decode(data)
    }

    public func listMessages(conversationID: Int) async throws -> [ChatwootMessage] {
        let data = try await get("/api/v1/accounts/\(accountID)/conversations/\(conversationID)/messages")
        return try decode(data, key: "data.payload")
    }

    // MARK: - Contacts

    public func searchContacts(query: String) async throws -> [ChatwootContact] {
        let data = try await get("/api/v1/accounts/\(accountID)/contacts/search", params: ["q": query])
        return try decode(data, key: "data.payload")
    }

    public func createContact(name: String, email: String? = nil, phone: String? = nil, customAttributes: [String: String] = [:]) async throws -> ChatwootContact {
        var body: [String: Any] = ["name": name]
        if let email { body["email"] = email }
        if let phone { body["phone_number"] = phone }
        if !customAttributes.isEmpty { body["custom_attributes"] = customAttributes }
        let data = try await post("/api/v1/accounts/\(accountID)/contacts", body: body)
        return try decode(data, key: "data.payload.contact")
    }

    // MARK: - Inbox / Agent Bot

    public func listInboxes() async throws -> [ChatwootInbox] {
        let data = try await get("/api/v1/accounts/\(accountID)/inboxes")
        return try decode(data, key: "data.payload")
    }

    @discardableResult
    public func agentBotEvent(conversationID: Int, event: String, content: String, contentType: MessageContentType = .text) async throws -> Data {
        let body: [String: Any] = ["event": event, "content": content, "message_type": contentType.rawValue]
        return try await post("/api/v1/accounts/\(accountID)/conversations/\(conversationID)/agent_bot", body: body)
    }

    // MARK: - Webhook verification

    public func verifyWebhookSignature(body: Data, signature: String) -> Bool {
        guard let secret = webhookSecret else { return false }
        guard let computed = hmacSHA256(data: body, key: secret) else { return false }
        return computed == signature
    }

    // MARK: - WebSocket (ActionCable)

    public func connectActionCable(pubsubToken: String) -> ChatwootWebSocket {
        ChatwootWebSocket(baseURL: baseURL, pubsubToken: pubsubToken, accountID: accountID)
    }

    // MARK: - HTTP helpers

    private func get(_ path: String, params: [String: String] = [:]) async throws -> Data {
        var components = URLComponents(string: "\(baseURL)\(path)")
        if !params.isEmpty {
            components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw ChatwootError.invalidURL }
        var req = URLRequest(url: url)
        req.setValue(apiAccessToken, forHTTPHeaderField: "api_access_token")
        req.timeoutInterval = 30
        let (data, res) = try await session.data(for: req)
        try validateResponse(res, data: data)
        return data
    }

    private func post(_ path: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else { throw ChatwootError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiAccessToken, forHTTPHeaderField: "api_access_token")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 30
        let (data, res) = try await session.data(for: req)
        try validateResponse(res, data: data)
        return data
    }

    private func validateResponse(_ res: URLResponse, data: Data) throws {
        guard let http = res as? HTTPURLResponse else { throw ChatwootError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ChatwootError.httpError(statusCode: http.statusCode, body: body)
        }
    }

    private func decode<T: Decodable>(_ data: Data, key: String? = nil) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        if let key {
            let root = try JSONSerialization.jsonObject(with: data)
            let keys = key.split(separator: ".")
            var current: Any = root
            for k in keys {
                guard let dict = current as? [String: Any], let next = dict[String(k)] else {
                    throw ChatwootError.decodingFailed("key path '\(key)' not found")
                }
                current = next
            }
            let innerData = try JSONSerialization.data(withJSONObject: current)
            return try decoder.decode(T.self, from: innerData)
        }
        return try decoder.decode(T.self, from: data)
    }

    private func hmacSHA256(data: Data, key: String) -> String? {
        guard let keyData = key.data(using: .utf8) else { return nil }
        let key = SymmetricKey(data: keyData)
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return signature.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - WebSocket (ActionCable)

public actor ChatwootWebSocket {
    private let baseURL: String
    private let pubsubToken: String
    private let accountID: String
    private var task: URLSessionWebSocketTask?
    private let session: URLSession
    private var onMessage: (@Sendable (ChatwootWSMessage) -> Void)?
    private var isConnected = false

    public init(baseURL: String, pubsubToken: String, accountID: String) {
        self.baseURL = baseURL
        self.pubsubToken = pubsubToken
        self.accountID = accountID
        self.session = URLSession(configuration: .default)
    }

    public func connect(onMessage: (@Sendable (ChatwootWSMessage) -> Void)? = nil) {
        self.onMessage = onMessage
        guard let wsURL = URL(string: baseURL.replacingOccurrences(of: "http", with: "ws") + "/cable") else { return }
        var req = URLRequest(url: wsURL)
        req.setValue(pubsubToken, forHTTPHeaderField: "X-Access-Token")
        task = session.webSocketTask(with: req)
        task?.resume()
        receive()
        subscribe()
    }

    public func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        isConnected = false
    }

    public func sendText(_ text: String, conversationID: Int) {
        let msg: [String: Any] = [
            "command": "message",
            "identifier": "{\"channel\":\"RoomChannel\",\"pubsub_token\":\"\(pubsubToken)\",\"account_id\":\(accountID),\"conversation_id\":\(conversationID)}",
            "data": "{\"action\":\"send_message\",\"content\":\"\(text)\"}"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: msg),
              let str = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(str)) { _ in }
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            Task { await self.handleReceive(result: result) }
        }
    }

    private func handleReceive(result: Result<URLSessionWebSocketTask.Message, Error>) {
        switch result {
        case .success(let message):
            switch message {
            case .string(let text):
                if let data = text.data(using: .utf8),
                   let wsMsg = try? JSONDecoder().decode(ChatwootWSMessage.self, from: data) {
                    onMessage?(wsMsg)
                    if wsMsg.type == "welcome" { isConnected = true }
                }
            case .data(let data):
                if let wsMsg = try? JSONDecoder().decode(ChatwootWSMessage.self, from: data) {
                    onMessage?(wsMsg)
                }
            @unknown default: break
            }
            receive()
        case .failure:
            isConnected = false
        }
    }

    private func subscribe() {
        let sub: [String: Any] = [
            "command": "subscribe",
            "identifier": "{\"channel\":\"RoomChannel\",\"pubsub_token\":\"\(pubsubToken)\",\"account_id\":\(accountID)}"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: sub),
              let str = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(str)) { _ in }
    }
}

// MARK: - Types

public enum ConversationStatus: String, Sendable, Codable {
    case open, pending, resolved, snoozed
}

public enum MessageContentType: String, Sendable, Codable {
    case text = "outgoing"
    case incoming
    case activity
}

public struct ChatwootConversation: Codable, Sendable {
    public let id: Int
    public let accountID: Int?
    public let inboxID: Int?
    public let status: String?
    public let contact: ChatwootContact?
    public let agent: ChatwootAgent?
    public let messages: [ChatwootMessage]?
    public let createdAt: String?
    public let unreadCount: Int?
    public let displayID: String?
}

public struct ChatwootMessage: Codable, Sendable {
    public let id: Int?
    public let content: String?
    public let messageType: String?
    public let privateNote: Bool?
    public let sender: ChatwootSender?
    public let createdAt: String?
}

public struct ChatwootContact: Codable, Sendable {
    public let id: Int?
    public let name: String?
    public let email: String?
    public let phoneNumber: String?
    public let customAttributes: [String: String]?
}

public struct ChatwootAgent: Codable, Sendable {
    public let id: Int?
    public let name: String?
    public let email: String?
    public let role: String?
}

public struct ChatwootSender: Codable, Sendable {
    public let id: Int?
    public let name: String?
    public let type: String?
}

public struct ChatwootInbox: Codable, Sendable {
    public let id: Int
    public let name: String?
    public let channelType: String?
}

public struct ChatwootWSMessage: Codable, Sendable {
    public let type: String?
    public let message: ChatwootWSPayload?
    public let identifier: String?
}

public struct ChatwootWSPayload: Codable, Sendable {
    public let event: String?
    public let content: String?
    public let conversationID: Int?
    public let senderID: Int?
    public let senderName: String?

    enum CodingKeys: String, CodingKey {
        case event, content
        case conversationID = "conversation_id"
        case senderID = "sender_id"
        case senderName = "sender_name"
    }
}

public enum ChatwootError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "无效的 Chatwoot URL"
        case .invalidResponse: "无效的响应"
        case .httpError(let code, let body): "HTTP \(code): \(body)"
        case .decodingFailed(let detail): "解析失败: \(detail)"
        }
    }
}
