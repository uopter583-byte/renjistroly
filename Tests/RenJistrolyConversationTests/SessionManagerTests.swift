import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyConversation

// MARK: - CRUD

@MainActor func testCreateConversation() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation(title: "Test")
    XCTAssertTrue(conv.title == "Test")
    XCTAssertTrue(manager.conversations.count == 1)
    XCTAssertTrue(manager.activeConversationID == conv.id)
}

@MainActor func testCreateConversationDefaultTitle() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    XCTAssertTrue(conv.title == "新对话")
}

@MainActor func testDeleteConversation() {
    let manager = SessionManager(storageURL: nil)
    let a = manager.createConversation(title: "A")
    let b = manager.createConversation(title: "B")
    XCTAssertTrue(manager.conversations.count == 2)
    manager.deleteConversation(a.id)
    XCTAssertTrue(manager.conversations.count == 1)
    XCTAssertTrue(manager.conversations[0].id == b.id)
}

@MainActor func testDeleteActiveConversationFallsBack() {
    let manager = SessionManager(storageURL: nil)
    let a = manager.createConversation(title: "A")
    let b = manager.createConversation(title: "B")
    manager.setActiveConversation(b.id)
    manager.deleteConversation(b.id)
    XCTAssertTrue(manager.activeConversationID == a.id)
}

@MainActor func testSetActiveInvalidIDIgnored() {
    let manager = SessionManager(storageURL: nil)
    _ = manager.createConversation()
    manager.setActiveConversation(UUID())
    XCTAssertTrue(manager.activeConversationID != nil)
}

// MARK: - Messages

@MainActor func testAppendMessageAutoTitle() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation() // title = "新对话"
    let msg = Message(role: .user, content: [.text("How to use Swift actors")])
    manager.appendMessage(msg, to: conv.id)
    let updated = manager.conversations.first { $0.id == conv.id }
    XCTAssertTrue(updated?.title == "How to use Swift actors")
}

@MainActor func testAppendMessageTrimsTitle() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    let long = String(repeating: "a", count: 60)
    let msg = Message(role: .user, content: [.text(long)])
    manager.appendMessage(msg, to: conv.id)
    let updated = manager.conversations.first { $0.id == conv.id }
    XCTAssertTrue(updated?.title.count == 50)
}

@MainActor func testAppendMessageKeepsCustomTitle() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation(title: "Custom Title")
    let msg = Message(role: .user, content: [.text("Different text")])
    manager.appendMessage(msg, to: conv.id)
    let updated = manager.conversations.first { $0.id == conv.id }
    XCTAssertTrue(updated?.title == "Custom Title")
}

@MainActor func testAppendMessageMultiLineFirstLineOnly() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    let msg = Message(role: .user, content: [.text("First line\nSecond line\nThird")])
    manager.appendMessage(msg, to: conv.id)
    let updated = manager.conversations.first { $0.id == conv.id }
    XCTAssertTrue(updated?.title == "First line")
}

@MainActor func testUpdateMessage() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    let msg = Message(role: .user, content: [.text("original")])
    manager.appendMessage(msg, to: conv.id)
    let updated = Message(id: msg.id, role: .assistant, content: [.text("modified")])
    manager.updateMessage(updated, in: conv.id)
    let found = manager.conversations[0].messages.first { $0.id == msg.id }
    XCTAssertTrue(found?.textContent == "modified")
}

// MARK: - Streaming

@MainActor func testStreamingLifecycle() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    XCTAssertTrue(manager.isStreaming == false)

    let msgID = manager.beginStreamingResponse(in: conv.id)
    XCTAssertTrue(manager.isStreaming == true)

    manager.appendStreamToken("Hello", messageID: msgID, in: conv.id)
    manager.appendStreamToken(" World", messageID: msgID, in: conv.id)

    let mid = manager.conversations[0].messages.first { $0.id == msgID }
    XCTAssertTrue(mid?.textContent == "Hello World")

    manager.finishStreamingResponse(messageID: msgID, in: conv.id)
    XCTAssertTrue(manager.isStreaming == false)
}

// MARK: - Search

@MainActor func testSearchConversationsByTitle() {
    let manager = SessionManager(storageURL: nil)
    _ = manager.createConversation(title: "Swift Tips")
    _ = manager.createConversation(title: "Rust Guide")
    let results = manager.searchConversations("swift")
    XCTAssertTrue(results.count == 1)
    XCTAssertTrue(results[0].title == "Swift Tips")
}

@MainActor func testSearchConversationsByContent() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation(title: "Chat")
    manager.appendMessage(Message(role: .user, content: [.text("How to use async/await")]), to: conv.id)
    let results = manager.searchConversations("async/await")
    XCTAssertTrue(results.count == 1)
}

@MainActor func testSearchConversationsEmptyQuery() {
    let manager = SessionManager(storageURL: nil)
    _ = manager.createConversation(title: "A")
    _ = manager.createConversation(title: "B")
    XCTAssertTrue(manager.searchConversations("").count == 2)
}

@MainActor func testSearchConversationsNoMatch() {
    let manager = SessionManager(storageURL: nil)
    _ = manager.createConversation(title: "Swift")
    XCTAssertTrue(manager.searchConversations("python").isEmpty)
}

// MARK: - defaultStorageURL

@MainActor func testDefaultStorageURL() {
    let url = SessionManager.defaultStorageURL()
    XCTAssertTrue(url.path.contains("RenJistroly"))
    XCTAssertTrue(url.lastPathComponent == "conversations.json")
}

@MainActor func testInitWithoutStorageURL() {
    let manager = SessionManager()
    XCTAssertTrue(manager.conversations.isEmpty)
}

@MainActor
final class SessionManagerPrivacyMigrationTests: XCTestCase {
    func testSanitizesVisibleSkillContextOnLoad() throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-session-sanitize-\(UUID().uuidString)")
            .appendingPathComponent("conversations.json")
        try FileManager.default.createDirectory(at: tmpURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let leaked = Message(
            role: .user,
            content: [.text("?\n\n技能上下文:\n你是一个通用的 macOS AI 助手，可以使用所有可用工具来帮助用户完成任务。")]
        )
        let conversation = Conversation(title: "?", messages: [leaked])
        let data = try JSONEncoder().encode([conversation])
        try data.write(to: tmpURL, options: .atomic)

        let manager = SessionManager(storageURL: tmpURL)

        XCTAssertTrue(manager.conversations.first?.messages.first?.textContent == "?")
        XCTAssertTrue(manager.searchConversations("技能上下文").isEmpty)

        let reloaded = try JSONDecoder().decode([Conversation].self, from: Data(contentsOf: tmpURL))
        XCTAssertTrue(reloaded.first?.messages.first?.textContent == "?")

        try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
    }

    func testSanitizesSkillContextOnAppend() {
        let manager = SessionManager(storageURL: nil)
        let conv = manager.createConversation()
        let leaked = Message(
            role: .user,
            content: [.text("hello\n\n技能上下文:\ninternal-only")]
        )

        manager.appendMessage(leaked, to: conv.id)

        XCTAssertTrue(manager.conversations.first?.messages.first?.textContent == "hello")
    }

    func testMigratesRawClaudeLoginErrorOnLoad() throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-session-login-sanitize-\(UUID().uuidString)")
            .appendingPathComponent("conversations.json")
        try FileManager.default.createDirectory(at: tmpURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let leaked = Message(role: .assistant, content: [.text("Not logged in · Please run /login")])
        let conversation = Conversation(title: "login", messages: [leaked])
        try JSONEncoder().encode([conversation]).write(to: tmpURL, options: .atomic)

        let manager = SessionManager(storageURL: tmpURL)
        let migrated = manager.conversations.first?.messages.first?.textContent ?? ""

        XCTAssertTrue(migrated.contains("Claude Code 需要先登录"))
        XCTAssertTrue(migrated.contains("claude /login"))
        XCTAssertFalse(migrated.contains("Not logged in"))

        let reloaded = try JSONDecoder().decode([Conversation].self, from: Data(contentsOf: tmpURL))
        XCTAssertFalse((reloaded.first?.messages.first?.textContent ?? "").contains("Not logged in"))

        try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
    }
}
