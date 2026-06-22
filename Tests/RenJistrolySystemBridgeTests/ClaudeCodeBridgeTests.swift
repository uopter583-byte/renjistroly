import XCTest
@testable import RenJistrolySystemBridge
import RenJistrolyModels

// MARK: - ClaudeCodeEvent property tests

func testToolCallRequestFromToolUse() {
    let event = ClaudeCodeEvent.toolUse(id: "abc", name: "click", arguments: ["x": "100", "y": "200"])
    let req = event.toolCallRequest
    XCTAssertTrue(req?.id == "abc")
    XCTAssertTrue(req?.name == "click")
    XCTAssertTrue(req?.arguments["x"] == "100")
}

func testToolCallRequestFromNonToolUseReturnsNil() {
    let event = ClaudeCodeEvent.assistantText("hello")
    XCTAssertTrue(event.toolCallRequest == nil)
}

func testTextContentFromAssistantText() {
    XCTAssertTrue(ClaudeCodeEvent.assistantText("Hello World").textContent == "Hello World")
}

func testTextContentFromText() {
    XCTAssertTrue(ClaudeCodeEvent.text("raw text").textContent == "raw text")
}

func testTextContentFromUserMessage() {
    XCTAssertTrue(ClaudeCodeEvent.userMessage("user says hi").textContent == "user says hi")
}

func testTextContentFromError() {
    XCTAssertTrue(ClaudeCodeEvent.error("something broke").textContent == "something broke")
}

func testTextContentFromToolUseReturnsNil() {
    XCTAssertTrue(ClaudeCodeEvent.toolUse(id: "t1", name: "click", arguments: [:]).textContent == nil)
}

// MARK: - extractFileChanges tests

func testExtractCreatedFile() {
    let changes = ClaudeCodeBridge.extractFileChanges(from: "created file main.swift")
    XCTAssertTrue(changes.count == 1)
    XCTAssertTrue(changes[0].path == "main.swift")
    XCTAssertTrue(changes[0].kind == .created)
}

func testExtractModifiedFile() {
    let changes = ClaudeCodeBridge.extractFileChanges(from: "modified file AppDelegate.swift")
    XCTAssertTrue(changes.count == 1)
    XCTAssertTrue(changes[0].path == "AppDelegate.swift")
    XCTAssertTrue(changes[0].kind == .modified)
}

func testExtractDeletedFile() {
    let changes = ClaudeCodeBridge.extractFileChanges(from: "deleted file old_deprecated.swift")
    XCTAssertTrue(changes.count == 1)
    XCTAssertTrue(changes[0].path == "old_deprecated.swift")
    XCTAssertTrue(changes[0].kind == .deleted)
}

func testExtractMultipleFileChanges() {
    let text = """
    I created file Models.swift and modified file Services.swift.
    Then I removed file Legacy.swift.
    """
    let changes = ClaudeCodeBridge.extractFileChanges(from: text)
    XCTAssertTrue(changes.count == 3)
    let paths = changes.map(\.path)
    XCTAssertTrue(paths.contains("Models.swift"))
    XCTAssertTrue(paths.contains("Services.swift"))
    XCTAssertTrue(paths.contains("Legacy.swift"))
}

func testExtractNoFileChanges() {
    let changes = ClaudeCodeBridge.extractFileChanges(from: "just some text without file references")
    XCTAssertTrue(changes.isEmpty)
}

// MARK: - extractCommands tests

func testExtractBacktickCommands() {
    let cmds = ClaudeCodeBridge.extractCommands(from: "Run `swift build` and then `swift test`")
    XCTAssertTrue(cmds.count == 2)
    XCTAssertTrue(cmds[0] == "swift build")
    XCTAssertTrue(cmds[1] == "swift test")
}

func testExtractNoBacktickCommands() {
    let cmds = ClaudeCodeBridge.extractCommands(from: "no commands here")
    XCTAssertTrue(cmds.isEmpty)
}

func testExtractSingleWordBacktickIgnored() {
    let cmds = ClaudeCodeBridge.extractCommands(from: "Use `swift` for building")
    XCTAssertTrue(cmds.isEmpty)
}

// MARK: - ClaudeCodeStructuredResult tests

func testStructuredResultDefaults() {
    let result = ClaudeCodeStructuredResult(summary: "Done")
    XCTAssertTrue(result.summary == "Done")
    XCTAssertTrue(result.fileChanges.isEmpty)
    XCTAssertTrue(result.commandsRun.isEmpty)
    XCTAssertTrue(result.succeeded)
}

func testStructuredResultWithError() {
    let result = ClaudeCodeStructuredResult(summary: "", errorMessage: "build failed")
    XCTAssertFalse(result.succeeded)
    XCTAssertTrue(result.errorMessage == "build failed")
}

// MARK: - collectStructuredResult tests

func testCollectFromEmptyStream() async {
    let bridge = ClaudeCodeBridge()
    let stream = AsyncStream<ClaudeCodeEvent> { $0.finish() }
    let result = await bridge.collectStructuredResult(from: stream)
    XCTAssertTrue(result.summary.isEmpty)
    XCTAssertTrue(result.fileChanges.isEmpty)
    XCTAssertTrue(result.commandsRun.isEmpty)
    XCTAssertTrue(result.succeeded)
}

func testCollectAssistantTextAggregation() async {
    let bridge = ClaudeCodeBridge()
    let stream = AsyncStream<ClaudeCodeEvent> { cont in
        cont.yield(.assistantText("Part one. "))
        cont.yield(.assistantText("Part two."))
        cont.finish()
    }
    let result = await bridge.collectStructuredResult(from: stream)
    XCTAssertTrue(result.summary == "Part one. \nPart two.")
}

func testCollectToolUseWriteFile() async {
    let bridge = ClaudeCodeBridge()
    let stream = AsyncStream<ClaudeCodeEvent> { cont in
        cont.yield(.toolUse(id: "t1", name: "write_file", arguments: ["file_path": "main.swift"]))
        cont.finish()
    }
    let result = await bridge.collectStructuredResult(from: stream)
    XCTAssertTrue(result.fileChanges.count == 1)
    XCTAssertTrue(result.fileChanges[0].path == "main.swift")
    XCTAssertTrue(result.fileChanges[0].kind == .modified)
}

func testCollectError() async {
    let bridge = ClaudeCodeBridge()
    let stream = AsyncStream<ClaudeCodeEvent> { cont in
        cont.yield(.error("something broke"))
        cont.finish()
    }
    let result = await bridge.collectStructuredResult(from: stream)
    XCTAssertTrue(result.errorMessage == "something broke")
    XCTAssertFalse(result.succeeded)
}

// MARK: - Additional ClaudeCodeEvent coverage

func testTextContentFromResult() {
    XCTAssertTrue(ClaudeCodeEvent.result("final result").textContent == "final result")
}

func testTextContentNilForBatch() {
    XCTAssertTrue(ClaudeCodeEvent.batch([]).textContent == nil)
}

func testTextContentNilForInitMessage() {
    XCTAssertTrue(ClaudeCodeEvent.initMessage("system init").textContent == nil)
}

func testTextContentNilForToolResult() {
    XCTAssertTrue(ClaudeCodeEvent.toolResult(id: "t1", name: "bash", output: "ok", isError: false).textContent == nil)
}

func testExtractCommandsWithMixedContent() {
    let cmds = ClaudeCodeBridge.extractCommands(from: "Run `swift build` and then check the output. Also `git status` to verify.")
    XCTAssertTrue(cmds.count == 2)
    XCTAssertTrue(cmds[0] == "swift build")
    XCTAssertTrue(cmds[1] == "git status")
}

func testCollectMixedEvents() async {
    let bridge = ClaudeCodeBridge()
    let stream = AsyncStream<ClaudeCodeEvent> { cont in
        cont.yield(.assistantText("I will create a file. "))
        cont.yield(.toolUse(id: "t1", name: "write_file", arguments: ["file_path": "main.swift"]))
        cont.yield(.toolResult(id: "t1", name: "write_file", output: "success", isError: false))
        cont.yield(.assistantText("Done."))
        cont.finish()
    }
    let result = await bridge.collectStructuredResult(from: stream)
    XCTAssertTrue(result.fileChanges.count == 1)
    XCTAssertTrue(result.fileChanges[0].path == "main.swift")
    XCTAssertTrue(result.summary.contains("I will create a file"))
    XCTAssertTrue(result.summary.contains("Done"))
}

func testCollectToolUseWriteWithPathKey() async {
    let bridge = ClaudeCodeBridge()
    let stream = AsyncStream<ClaudeCodeEvent> { cont in
        cont.yield(.toolUse(id: "t1", name: "write_file", arguments: ["path": "other.swift"]))
        cont.finish()
    }
    let result = await bridge.collectStructuredResult(from: stream)
    XCTAssertTrue(result.fileChanges.count == 1)
    XCTAssertTrue(result.fileChanges[0].path == "other.swift")
    XCTAssertTrue(result.fileChanges[0].kind == .modified)
}
