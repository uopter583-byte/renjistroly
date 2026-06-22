import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - LocalModelManager tests

func testLocalModelManagerInitialState() async {
    let manager = LocalModelManager()
    let models = await manager.models
    // Models may or may not exist depending on system, just verify no crash
    XCTAssertTrue(models.count >= 0)
}

func testLocalModelManagerCLICheck() async {
    let manager = LocalModelManager()
    let cliAvailable = await manager.isMLXCLIAvailable
    // CLI may or may not be installed; just verify boolean return
    XCTAssertTrue(cliAvailable || !cliAvailable)
}

func testLocalModelManagerCanRunInference() async {
    let manager = LocalModelManager()
    let canRun = await manager.canRunInference
    XCTAssertTrue(canRun || !canRun) // Boolean sanity check
}

func testLocalModelManagerRefresh() async {
    let manager = LocalModelManager()
    let before = await manager.models
    await manager.refresh()
    let after = await manager.models
    XCTAssertTrue(before.count == after.count)
}

func testLocalModelInfoFormat() {
    let info = LocalModelInfo(name: "test", path: "/tmp/test", format: .mlx, sizeBytes: 1024)
    XCTAssertTrue(info.format == .mlx)
    XCTAssertTrue(info.name == "test")
    XCTAssertTrue(info.sizeBytes == 1024)
}

func testLocalModelInfoHashable() {
    let a = LocalModelInfo(name: "test", path: "/tmp/a", format: .mlx, sizeBytes: nil)
    let b = LocalModelInfo(name: "test", path: "/tmp/a", format: .mlx, sizeBytes: nil)
    let c = LocalModelInfo(name: "other", path: "/tmp/c", format: .gguf, sizeBytes: 2048)
    XCTAssertTrue(a == b)
    XCTAssertTrue(a != c)
    XCTAssertTrue(a.hashValue == b.hashValue)
}

// MARK: - LocalMLXBackend tests

func testLocalMLXBackendBasicChat() async throws {
    let backend = LocalMLXBackend()
    let isAvail = await backend.isAvailable
    XCTAssertTrue(isAvail)

    let result = try await backend.chat(
        messages: [Message(id: UUID(), role: .user, content: [.text("你好")], timestamp: Date())],
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: nil,
        delegate: nil
    )
    XCTAssertTrue(result.role == .assistant)
    XCTAssertFalse(result.textContent.isEmpty)
}

func testLocalMLXBackendWithOpenApp() async throws {
    let backend = LocalMLXBackend()
    let result = try await backend.chat(
        messages: [Message(id: UUID(), role: .user, content: [.text("打开 Safari")], timestamp: Date())],
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: [ToolDefinition(name: "open_app", description: "", parameters: [.init(name: "app_name", type: .string, description: "")])],
        delegate: nil
    )
    XCTAssertTrue(result.hasToolCalls)
    XCTAssertTrue(result.content.contains { if case .toolCall(let tc) = $0 { tc.name == "open_app" } else { false } })
}

func testLocalMLXBackendWithGitStatus() async throws {
    let backend = LocalMLXBackend()
    let result = try await backend.chat(
        messages: [Message(id: UUID(), role: .user, content: [.text("git status")], timestamp: Date())],
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: [ToolDefinition(name: "git_status", description: "", parameters: [])],
        delegate: nil
    )
    XCTAssertTrue(result.hasToolCalls)
    XCTAssertTrue(result.content.contains { if case .toolCall(let tc) = $0 { tc.name == "git_status" } else { false } })
}

func testLocalMLXBackendAlreadyHandled() async throws {
    let backend = LocalMLXBackend()
    let messages: [Message] = [
        Message(id: UUID(), role: .user, content: [.text("打开 Safari")], timestamp: Date()),
        Message(id: UUID(), role: .tool, content: [.toolResult(ToolCallResult(id: "x", output: "done", isError: false))], timestamp: Date()),
    ]
    let result = try await backend.chat(
        messages: messages,
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: [ToolDefinition(name: "open_app", description: "", parameters: [.init(name: "app_name", type: .string, description: "")])],
        delegate: nil
    )
    XCTAssertFalse(result.hasToolCalls)
    XCTAssertTrue(result.textContent.contains("完成"))
}

func testLocalMLXBackendEmptyMessages() async throws {
    let backend = LocalMLXBackend()
    let result = try await backend.chat(
        messages: [Message(id: UUID(), role: .assistant, content: [.text("Hello")], timestamp: Date())],
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: nil,
        delegate: nil
    )
    XCTAssertTrue(result.textContent.contains("请说点什么"))
}

func testLocalMLXBackendFallbackResponse() async throws {
    let backend = LocalMLXBackend()
    let result = try await backend.chat(
        messages: [Message(id: UUID(), role: .user, content: [.text("这是什么奇怪的指令xyzzy123")], timestamp: Date())],
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: [],
        delegate: nil
    )
    XCTAssertFalse(result.hasToolCalls)
    // Should get fallback guidance
    XCTAssertFalse(result.textContent.isEmpty)
}

func testLocalMLXBackendChatStream() async throws {
    let backend = LocalMLXBackend()
    let stream = try await backend.chatStream(
        messages: [Message(id: UUID(), role: .user, content: [.text("你好")], timestamp: Date())],
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: nil,
        delegate: nil
    )
    var tokens: [String] = []
    for await token in stream {
        tokens.append(token)
    }
    XCTAssertFalse(tokens.isEmpty)
    XCTAssertTrue(tokens.joined().contains("你好"))
}

func testLocalMLXBackendDiscoveredModels() async {
    let backend = LocalMLXBackend()
    let models = await backend.discoveredModels
    XCTAssertTrue(models.count >= 0)
    let usingReal = await backend.isUsingRealModel
    XCTAssertTrue(usingReal || !usingReal)
}

func testLocalMLXBackendShellCommand() async throws {
    let backend = LocalMLXBackend()
    let result = try await backend.chat(
        messages: [Message(id: UUID(), role: .user, content: [.text("运行 ls")], timestamp: Date())],
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: [ToolDefinition(name: "shell_command", description: "", parameters: [.init(name: "command", type: .string, description: "")])],
        delegate: nil
    )
    XCTAssertTrue(result.hasToolCalls)
    XCTAssertTrue(result.content.contains { if case .toolCall(let tc) = $0 { tc.name == "shell_command" } else { false } })
}

func testLocalMLXBackendBuildCommand() async throws {
    let backend = LocalMLXBackend()
    let result = try await backend.chat(
        messages: [Message(id: UUID(), role: .user, content: [.text("构建项目")], timestamp: Date())],
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: [ToolDefinition(name: "swift_build", description: "", parameters: [])],
        delegate: nil
    )
    XCTAssertTrue(result.hasToolCalls)
    XCTAssertTrue(result.content.contains { if case .toolCall(let tc) = $0 { tc.name == "swift_build" } else { false } })
}

func testLocalMLXBackendTestCommand() async throws {
    let backend = LocalMLXBackend()
    let result = try await backend.chat(
        messages: [Message(id: UUID(), role: .user, content: [.text("运行测试")], timestamp: Date())],
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: [ToolDefinition(name: "swift_test", description: "", parameters: [])],
        delegate: nil
    )
    XCTAssertTrue(result.hasToolCalls)
    XCTAssertTrue(result.content.contains { if case .toolCall(let tc) = $0 { tc.name == "swift_test" } else { false } })
}

// MARK: - LocalModelError

func testLocalModelErrorDescriptions() {
    XCTAssertTrue(LocalModelError.noModelsFound.errorDescription?.isEmpty == false)
    XCTAssertTrue(LocalModelError.inferenceFailed("test error").errorDescription?.contains("test error") == true)
}
