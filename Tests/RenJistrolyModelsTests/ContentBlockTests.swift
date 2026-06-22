import Foundation
import XCTest
@testable import RenJistrolyModels

// MARK: - ContentBlock

func testContentBlockText() {
    let block = ContentBlock.text("hello")
    if case .text(let text) = block {
        XCTAssertTrue(text == "hello")
    } else {
        XCTFail("unexpected false")
    }
}

func testContentBlockToolCall() {
    let request = ToolCallRequest(id: "1", name: "click", arguments: ["x": "100"])
    let block = ContentBlock.toolCall(request)
    if case .toolCall(let req) = block {
        XCTAssertTrue(req.id == "1")
        XCTAssertTrue(req.name == "click")
        XCTAssertTrue(req.arguments["x"] == "100")
    } else {
        XCTFail("unexpected false")
    }
}

func testContentBlockToolResult() {
    let result = ToolCallResult(id: "1", output: "ok")
    let block = ContentBlock.toolResult(result)
    if case .toolResult(let res) = block {
        XCTAssertTrue(res.id == "1")
        XCTAssertTrue(res.output == "ok")
        XCTAssertFalse(res.isError)
    } else {
        XCTFail("unexpected false")
    }
}

func testContentBlockFile() {
    let file = ContentBlock.FileReference(path: "/tmp/test.swift", language: "swift", snippet: "print(1)")
    let block = ContentBlock.file(file)
    if case .file(let ref) = block {
        XCTAssertTrue(ref.path == "/tmp/test.swift")
        XCTAssertTrue(ref.language == "swift")
        XCTAssertTrue(ref.snippet == "print(1)")
    } else {
        XCTFail("unexpected false")
    }
}

// MARK: - Message hasToolCalls

func testMessageHasToolCallsTrue() {
    let msg = Message(
        role: .assistant,
        content: [
            .text("let me click"),
            .toolCall(ToolCallRequest(id: "1", name: "click", arguments: [:]))
        ]
    )
    XCTAssertTrue(msg.hasToolCalls)
}

func testMessageHasToolCallsFalse() {
    let msg = Message(role: .user, content: [.text("hello"), .text("world")])
    XCTAssertFalse(msg.hasToolCalls)
}

func testMessageHasToolCallsEmpty() {
    let msg = Message(role: .assistant, content: [])
    XCTAssertFalse(msg.hasToolCalls)
}

// MARK: - Message textContent edge cases

func testMessageTextContentEmpty() {
    let msg = Message(role: .user, content: [])
    XCTAssertTrue(msg.textContent.isEmpty)
}

func testMessageTextContentSkipsToolCalls() {
    let msg = Message(
        role: .assistant,
        content: [
            .text("before"),
            .toolCall(ToolCallRequest(id: "1", name: "click", arguments: [:])),
            .text("after")
        ]
    )
    XCTAssertTrue(msg.textContent == "before\nafter")
}

func testMessageTextContentSingleText() {
    let msg = Message(role: .user, content: [.text("hello")])
    XCTAssertTrue(msg.textContent == "hello")
}

// MARK: - ToolCallRequest

func testToolCallRequestInit() {
    let req = ToolCallRequest(id: "t1", name: "open_app", arguments: ["app_name": "Safari"])
    XCTAssertTrue(req.id == "t1")
    XCTAssertTrue(req.name == "open_app")
    XCTAssertTrue(req.arguments["app_name"] == "Safari")
}

func testToolCallRequestEmptyArguments() {
    let req = ToolCallRequest(id: "t2", name: "read_context", arguments: [:])
    XCTAssertTrue(req.arguments.isEmpty)
}

// MARK: - ToolCallResult

func testToolCallResultSuccess() {
    let result = ToolCallResult(id: "r1", output: "done")
    XCTAssertTrue(result.id == "r1")
    XCTAssertTrue(result.output == "done")
    XCTAssertFalse(result.isError)
}

func testToolCallResultError() {
    let result = ToolCallResult(id: "r2", output: "permission denied", isError: true)
    XCTAssertTrue(result.isError)
}

// MARK: - MessageRole

func testMessageRoleAllCases() {
    XCTAssertTrue(MessageRole.system.rawValue == "system")
    XCTAssertTrue(MessageRole.user.rawValue == "user")
    XCTAssertTrue(MessageRole.assistant.rawValue == "assistant")
    XCTAssertTrue(MessageRole.tool.rawValue == "tool")
}

// MARK: - ContentBlock.ImageSource

func testContentBlockImageSourceURL() {
    let source = ContentBlock.ImageSource.url(URL(string: "https://example.com/img.png")!)
    if case .url(let url) = source {
        XCTAssertTrue(url.absoluteString == "https://example.com/img.png")
    } else {
        XCTFail("unexpected false")
    }
}

func testContentBlockImageSourceBase64() {
    let source = ContentBlock.ImageSource.base64("abc123", mimeType: "image/png")
    if case .base64(let data, let mime) = source {
        XCTAssertTrue(data == "abc123")
        XCTAssertTrue(mime == "image/png")
    } else {
        XCTFail("unexpected false")
    }
}

func testContentBlockImageSourceFilePath() {
    let source = ContentBlock.ImageSource.filePath("/tmp/screen.png")
    if case .filePath(let path) = source {
        XCTAssertTrue(path == "/tmp/screen.png")
    } else {
        XCTFail("unexpected false")
    }
}

// MARK: - ContentBlock.FileReference

func testFileReferenceMinimal() {
    let ref = ContentBlock.FileReference(path: "/tmp/a.txt")
    XCTAssertTrue(ref.path == "/tmp/a.txt")
    XCTAssertTrue(ref.language == nil)
    XCTAssertTrue(ref.snippet == nil)
}

func testFileReferenceFull() {
    let ref = ContentBlock.FileReference(path: "/tmp/b.swift", language: "swift", snippet: "let x = 1")
    XCTAssertTrue(ref.path == "/tmp/b.swift")
    XCTAssertTrue(ref.language == "swift")
    XCTAssertTrue(ref.snippet == "let x = 1")
}
