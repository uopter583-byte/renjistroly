import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - buildPrompt

func testBuildPromptSystemAndUser() async {
    let backend = ClaudeCodeCLIBackend()
    let messages: [Message] = [
        Message(role: .system, content: [.text("You are helpful.")]),
        Message(role: .user, content: [.text("Hello")]),
    ]
    let prompt = await backend.buildPrompt(from: messages)
    XCTAssertTrue(prompt.contains("You are helpful."))
    XCTAssertTrue(prompt.contains("用户:"))
    XCTAssertTrue(prompt.contains("Hello"))
}

func testBuildPromptMultiTurn() async {
    let backend = ClaudeCodeCLIBackend()
    let messages: [Message] = [
        Message(role: .user, content: [.text("Q1")]),
        Message(role: .assistant, content: [.text("A1")]),
        Message(role: .user, content: [.text("Q2")]),
    ]
    let prompt = await backend.buildPrompt(from: messages)
    XCTAssertTrue(prompt.contains("用户: Q1"))
    XCTAssertTrue(prompt.contains("助手: A1"))
    XCTAssertTrue(prompt.contains("用户: Q2"))
}

func testBuildPromptWithToolResults() async {
    let backend = ClaudeCodeCLIBackend()
    let messages: [Message] = [
        Message(role: .user, content: [.text("run tests")]),
        Message(role: .assistant, content: [.toolResult(ToolCallResult(id: "1", output: "Build complete!"))]),
    ]
    let prompt = await backend.buildPrompt(from: messages)
    XCTAssertTrue(prompt.contains("Build complete!"))
    XCTAssertTrue(prompt.contains("[工具返回:"))
}

func testBuildPromptEmptyDefaultsToHello() async {
    let backend = ClaudeCodeCLIBackend()
    let prompt = await backend.buildPrompt(from: [])
    XCTAssertTrue(prompt == "你好")
}

// MARK: - parseLine

func testParseLineAssistantText() {
    let json: [String: Any] = [
        "type": "assistant",
        "message": [
            "content": [
                ["type": "text", "text": "Hello from Claude"],
            ],
        ],
    ]
    let data = try! JSONSerialization.data(withJSONObject: json)
    let event = ClaudeCodeCLIBackend.parseLine(data)
    if case .text(let text) = event {
        XCTAssertTrue(text == "Hello from Claude")
    } else {
        XCTFail("expected .text but got \(String(describing: event))")
    }
}

func testParseLineAssistantToolUse() {
    let json: [String: Any] = [
        "type": "assistant",
        "message": [
            "content": [
                ["type": "tool_use", "name": "read_file", "id": "tool_1", "input": ["path": "/tmp/test.swift"]],
            ],
        ],
    ]
    let data = try! JSONSerialization.data(withJSONObject: json)
    let event = ClaudeCodeCLIBackend.parseLine(data)
    if case .toolUse(let id, let name, let args) = event {
        XCTAssertTrue(id == "tool_1")
        XCTAssertTrue(name == "read_file")
        XCTAssertTrue(args["path"] == "/tmp/test.swift")
    } else {
        XCTFail("expected .toolUse")
    }
}

func testParseLinePlainTextJSON() {
    let json: [String: Any] = ["text": "simple text"]
    let data = try! JSONSerialization.data(withJSONObject: json)
    let event = ClaudeCodeCLIBackend.parseLine(data)
    if case .text(let text) = event {
        XCTAssertTrue(text == "simple text")
    } else {
        XCTFail("expected .text")
    }
}

func testParseLineNonJSON() {
    let data = "plain text line".data(using: .utf8)!
    let event = ClaudeCodeCLIBackend.parseLine(data)
    if case .text(let text) = event {
        XCTAssertTrue(text == "plain text line")
    } else {
        XCTFail("expected .text")
    }
}

func testParseLineEmpty() {
    let data = Data()
    XCTAssertTrue(ClaudeCodeCLIBackend.parseLine(data) == nil)
}

final class ClaudeCodeCLIUserFacingErrorTests: XCTestCase {
    func testLoginErrorIsActionable() {
        let message = ClaudeCodeCLIBackend.userFacingError("Not logged in · Please run /login")
        XCTAssertTrue(message.contains("Claude Code 需要先登录"))
        XCTAssertTrue(message.contains(ClaudeCodeLoginGuide.command))
        XCTAssertFalse(message.contains("Not logged in"))
    }

    func testLoginCommandIsStableForSettingsAndErrors() {
        XCTAssertEqual(ClaudeCodeLoginGuide.command, "claude /login")
        XCTAssertTrue(ClaudeCodeLoginGuide.help.contains(ClaudeCodeLoginGuide.command))
    }
}
