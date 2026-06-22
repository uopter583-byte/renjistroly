import Foundation
import XCTest
import RenJistrolyModels

// MARK: - ChatMessage

func testChatMessageInit() {
    let msg = ChatMessage(role: "user", content: "hello")
    XCTAssertTrue(msg.role == "user")
    XCTAssertTrue(msg.content == "hello")
}

func testChatMessageEquatable() {
    let a = ChatMessage(role: "user", content: "hi")
    let b = ChatMessage(role: "user", content: "hi")
    let c = ChatMessage(role: "assistant", content: "hi")
    XCTAssertTrue(a == b)
    XCTAssertTrue(a != c)
}

// MARK: - ChatRequest

func testChatRequestInitWithDefaults() {
    let req = ChatRequest(model: "gpt-5", messages: [ChatMessage(role: "user", content: "hi")])
    XCTAssertTrue(req.model == "gpt-5")
    XCTAssertTrue(req.messages.count == 1)
    XCTAssertTrue(req.temperature == nil)
    XCTAssertTrue(req.maxTokens == nil)
}

func testChatRequestInitFull() {
    let req = ChatRequest(
        model: "claude-sonnet-4-6",
        messages: [ChatMessage(role: "user", content: "test")],
        temperature: 0.5,
        maxTokens: 2048
    )
    XCTAssertTrue(req.temperature == 0.5)
    XCTAssertTrue(req.maxTokens == 2048)
}

// MARK: - ChatResponse

func testChatResponseInit() {
    let resp = ChatResponse(text: "Hello!", provider: "anthropic", model: "claude-sonnet-4-6")
    XCTAssertTrue(resp.text == "Hello!")
    XCTAssertTrue(resp.provider == "anthropic")
    XCTAssertTrue(resp.model == "claude-sonnet-4-6")
}

// MARK: - RealtimeConfig

func testRealtimeConfigInitWithDefaults() {
    let config = RealtimeConfig(instructions: "Be helpful")
    XCTAssertTrue(config.model == "gpt-realtime-2")
    XCTAssertTrue(config.voice == "marin")
    XCTAssertTrue(config.instructions == "Be helpful")
}

func testRealtimeConfigInitCustom() {
    let config = RealtimeConfig(model: "gpt-4o-realtime", voice: "alloy", instructions: "Speak Chinese")
    XCTAssertTrue(config.model == "gpt-4o-realtime")
    XCTAssertTrue(config.voice == "alloy")
}

func testRealtimeConfigEquatable() {
    let a = RealtimeConfig(instructions: "A")
    let b = RealtimeConfig(instructions: "A")
    let c = RealtimeConfig(instructions: "B")
    XCTAssertTrue(a == b)
    XCTAssertTrue(a != c)
}
