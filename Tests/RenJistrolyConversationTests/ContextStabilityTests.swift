import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyConversation

// MARK: - Remember previous turn context

@MainActor func testRememberPreviousTurnContent() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()

    let first = Message(role: .user, content: [.text("What files are in the project?")])
    manager.appendMessage(first, to: conv.id)
    let second = Message(role: .assistant, content: [.text("Sources, Tests, Package.swift")])
    manager.appendMessage(second, to: conv.id)
    let third = Message(role: .user, content: [.text("Show me the Sources folder")])
    manager.appendMessage(third, to: conv.id)

    XCTAssertTrue(conv.messages.count == 3)
    XCTAssertTrue(conv.messages[0].textContent == "What files are in the project?")
    XCTAssertTrue(conv.messages[1].textContent == "Sources, Tests, Package.swift")
    XCTAssertTrue(conv.messages[2].textContent == "Show me the Sources folder")
}

@MainActor func testRememberPreviousTurnToolCalls() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()

    let request = ToolCallRequest(id: "t1", name: "list_directory", arguments: ["path": "/tmp"])
    let msg = Message(role: .assistant, content: [.toolCall(request), .text("Listing...")])
    manager.appendMessage(msg, to: conv.id)

    XCTAssertTrue(conv.messages[0].hasToolCalls)
}

// MARK: - Clear context / new session

@MainActor func testClearContextNewSession() {
    let manager = SessionManager(storageURL: nil)
    let first = manager.createConversation(title: "First Chat")
    let msg = Message(role: .user, content: [.text("Hello")])
    manager.appendMessage(msg, to: first.id)
    XCTAssertTrue(manager.conversations.count == 1)

    let second = manager.createConversation(title: "Second Chat")
    XCTAssertTrue(manager.conversations.count == 2)
    XCTAssertTrue(manager.activeConversationID == second.id)
    XCTAssertTrue(second.messages.isEmpty)
}

@MainActor func testNewSessionDoesNotCarryPreviousMessages() {
    let manager = SessionManager(storageURL: nil)
    let first = manager.createConversation()
    manager.appendMessage(Message(role: .user, content: [.text("secret data")]), to: first.id)

    let second = manager.createConversation()
    XCTAssertTrue(!second.messages.contains(where: { $0.textContent == "secret data" }))
}

// MARK: - Screen context retention

func testDesktopContextRetainsAppAndWindowInfo() {
    let context = DesktopContext(
        activeAppName: "Xcode",
        focusedWindowTitle: "main.swift",
        selectedText: "func hello()"
    )
    XCTAssertTrue(context.activeAppName == "Xcode")
    XCTAssertTrue(context.focusedWindowTitle == "main.swift")
    XCTAssertTrue(context.selectedText == "func hello()")
}

func testDesktopContextPromptSummaryContainsActiveApp() {
    let context = DesktopContext(
        activeAppName: "Safari",
        browserPageState: BrowserPageState(
            browserName: "Safari",
            tabTitle: "Swift Documentation",
            host: "docs.swift.org"
        )
    )
    let summary = context.promptSummary()
    XCTAssertTrue(summary.contains("Safari"))
    XCTAssertTrue(summary.contains("Swift Documentation"))
    XCTAssertTrue(summary.contains("docs.swift.org"))
}

func testDesktopContextPromptSummaryHandlesEmptyContext() {
    let context = DesktopContext()
    let summary = context.promptSummary()
    XCTAssertTrue(summary.contains("当前桌面上下文:"))
}

// MARK: - Cross-app context carry-over

func testCrossAppContextCarryOver() {
    let safariContext = AppContext(appName: "Safari", bundleIdentifier: "com.apple.Safari")
    let terminalContext = AppContext(appName: "Terminal", bundleIdentifier: "com.apple.Terminal")

    XCTAssertTrue(safariContext.appName == "Safari")
    XCTAssertTrue(terminalContext.appName == "Terminal")
    XCTAssertTrue(safariContext.bundleIdentifier == "com.apple.Safari")
    XCTAssertTrue(terminalContext.bundleIdentifier == "com.apple.Terminal")
}

func testDesktopContextMergesMultiWindowState() {
    let context = DesktopContext(
        activeAppName: "Notes",
        windows: [
            DesktopWindow(title: "Meeting Notes"),
            DesktopWindow(title: "Brainstorming"),
        ],
        uiElements: [
            DesktopUIElement(role: "AXTextField", title: "Search", description: nil, depth: 0),
        ]
    )
    let summary = context.promptSummary()
    XCTAssertTrue(summary.contains("Meeting Notes"))
    XCTAssertTrue(summary.contains("Brainstorming"))
    XCTAssertTrue(summary.contains("AXTextField"))
}

// MARK: - False reference prevention

@MainActor func testContextCompilerEmptyMemories() {
    let compiler = ContextCompiler()
    let context = compiler.buildWorkflowMemoryContext(memories: [])
    XCTAssertTrue(context.isEmpty)
}

@MainActor func testContextCompilerFalseReferenceNotGenerated() {
    let compiler = ContextCompiler()
    let memories = [
        TaskMemory(
            task: "Open Safari",
            steps: ["open_app"],
            success: true,
            learnedWorkflow: "open_app -> Safari"
        )
    ]
    let context = compiler.buildWorkflowMemoryContext(memories: memories)
    XCTAssertTrue(context.contains("Open Safari"))
    XCTAssertTrue(!context.contains("Nonexistent"))
    XCTAssertTrue(!context.contains("Hallucinated"))
}

// MARK: - Long context truncation

@MainActor func testSessionManagerTitleTruncatedAtFiftyChars() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    let longText = String(repeating: "a", count: 100)
    let msg = Message(role: .user, content: [.text(longText)])
    manager.appendMessage(msg, to: conv.id)
    let updated = manager.conversations.first { $0.id == conv.id }
    XCTAssertTrue(updated?.title.count == 50)
}

@MainActor func testLongContextTruncationFirstLineOnly() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    let multiLine = "First meaningful line\nAnother line\nAnd more"
    let msg = Message(role: .user, content: [.text(multiLine)])
    manager.appendMessage(msg, to: conv.id)
    let updated = manager.conversations.first { $0.id == conv.id }
    XCTAssertTrue(updated?.title == "First meaningful line")
}

// MARK: - History summarization

func testInteractionTraceSummarizesEvents() {
    var trace = InteractionTrace()
    trace.append(.inputStarted, detail: "voice input")
    trace.append(.speechFinal, detail: "Hello")
    trace.append(.routeSelected, detail: "chat")
    trace.append(.modelFirstToken)
    trace.append(.turnComplete, detail: "done")

    XCTAssertTrue(trace.events.count == 5)
    XCTAssertTrue(trace.completedAt != nil)
    XCTAssertTrue(trace.totalDuration != nil)
}

func testInteractionTraceDurationCalculation() {
    var trace = InteractionTrace(turnID: UUID())
    trace.append(.inputStarted, detail: "")
    trace.append(.turnComplete, detail: "")
    let latency = TraceLatencySummary(from: trace)
    XCTAssertTrue(latency.totalMs != nil)
    XCTAssertTrue(latency.eventCount == 2)
}

// MARK: - User correction handling

@MainActor func testUserCorrectionUpdateMessage() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    let msg = Message(role: .assistant, content: [.text("Wrong answer")])
    manager.appendMessage(msg, to: conv.id)

    let corrected = Message(id: msg.id, role: .assistant, content: [.text("Corrected answer")])
    manager.updateMessage(corrected, in: conv.id)

    let found = manager.conversations[0].messages.first { $0.id == msg.id }
    XCTAssertTrue(found?.textContent == "Corrected answer")
}

@MainActor func testUserCorrectionPreservesOtherMessages() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    let first = Message(role: .user, content: [.text("Hello")])
    let second = Message(role: .assistant, content: [.text("Hi there")])
    manager.appendMessage(first, to: conv.id)
    manager.appendMessage(second, to: conv.id)

    let corrected = Message(id: second.id, role: .assistant, content: [.text("Hey!")])
    manager.updateMessage(corrected, in: conv.id)

    XCTAssertTrue(conv.messages.count == 2)
    XCTAssertTrue(conv.messages[0].textContent == "Hello")
}

// MARK: - Session restoration from disk

@MainActor func testSessionRestorationFromDisk() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-context-stability-\(UUID().uuidString)")
        .appendingPathComponent("conversations.json")

    let writer = SessionManager(storageURL: tmpURL)
    let original = writer.createConversation(title: "Restore Test")
    writer.appendMessage(Message(role: .user, content: [.text("Will I survive?")]), to: original.id)

    let reader = SessionManager(storageURL: tmpURL)
    XCTAssertTrue(reader.conversations.count == 1)
    XCTAssertTrue(reader.conversations[0].title == "Restore Test")
    XCTAssertTrue(reader.conversations[0].messages.count == 1)
    XCTAssertTrue(reader.conversations[0].messages[0].textContent == "Will I survive?")

    try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
}

@MainActor func testSessionRestorationFromDiskEmptyFile() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-context-empty-\(UUID().uuidString)")
        .appendingPathComponent("conversations.json")

    let manager = SessionManager(storageURL: tmpURL)
    XCTAssertTrue(manager.conversations.isEmpty)

    try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
}

// MARK: - State recovery after app restart

@MainActor func testSessionManagerRestoresActiveConversation() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-active-restore-\(UUID().uuidString)")
        .appendingPathComponent("conversations.json")

    let writer = SessionManager(storageURL: tmpURL)
    let _ = writer.createConversation(title: "Alpha")
    let beta = writer.createConversation(title: "Beta")
    _ = writer.createConversation(title: "Gamma")
    writer.setActiveConversation(beta.id)

    let reader = SessionManager(storageURL: tmpURL)
    XCTAssertTrue(reader.conversations.count == 3)
    XCTAssertTrue(reader.conversations[0].title == "Alpha")

    try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
}

@MainActor func testStateRecoveryWithMultipleConversations() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-multi-restore-\(UUID().uuidString)")
        .appendingPathComponent("conversations.json")

    let writer = SessionManager(storageURL: tmpURL)
    _ = writer.createConversation(title: "A")
    writer.appendMessage(Message(role: .user, content: [.text("Hello A")]), to: writer.conversations[0].id)
    _ = writer.createConversation(title: "B")
    writer.appendMessage(Message(role: .user, content: [.text("Hello B")]), to: writer.conversations[1].id)

    let reader = SessionManager(storageURL: tmpURL)
    XCTAssertTrue(reader.conversations.count == 2)
    XCTAssertTrue(reader.conversations[0].messages.count == 1)
    let firstContent = reader.conversations[0].messages.first?.textContent
    XCTAssertTrue(firstContent == "Hello A")

    try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
}

// MARK: - Cross-conversation context isolation

@MainActor func testDeleteDoesNotAffectOtherConversations() {
    let manager = SessionManager(storageURL: nil)
    let a = manager.createConversation(title: "Chat A")
    let b = manager.createConversation(title: "Chat B")
    manager.appendMessage(Message(role: .user, content: [.text("Message A")]), to: a.id)
    manager.appendMessage(Message(role: .user, content: [.text("Message B")]), to: b.id)

    manager.deleteConversation(a.id)
    XCTAssertTrue(manager.conversations.count == 1)
    XCTAssertTrue(manager.conversations[0].title == "Chat B")
    XCTAssertTrue(manager.conversations[0].messages.count == 1)
    XCTAssertTrue(manager.conversations[0].messages[0].textContent == "Message B")
}

@MainActor func testSwitchConversationPreservesContext() {
    let manager = SessionManager(storageURL: nil)
    let first = manager.createConversation(title: "First")
    manager.appendMessage(Message(role: .user, content: [.text("Context in first")]), to: first.id)

    let second = manager.createConversation(title: "Second")
    manager.setActiveConversation(first.id)
    XCTAssertTrue(manager.activeConversationID == first.id)

    manager.setActiveConversation(second.id)
    manager.appendMessage(Message(role: .user, content: [.text("Context in second")]), to: second.id)
    XCTAssertTrue(second.messages.count == 1)
    XCTAssertTrue(first.messages.count == 1)
    XCTAssertTrue(first.messages[0].textContent == "Context in first")
}

// MARK: - Sequential user corrections

@MainActor func testMultipleSequentialUserCorrections() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    let msg1 = Message(role: .assistant, content: [.text("First attempt")])
    manager.appendMessage(msg1, to: conv.id)

    let corrected1 = Message(id: msg1.id, role: .assistant, content: [.text("First correction")])
    manager.updateMessage(corrected1, in: conv.id)
    let corrected2 = Message(id: msg1.id, role: .assistant, content: [.text("Second correction")])
    manager.updateMessage(corrected2, in: conv.id)

    let found = manager.conversations[0].messages.first { $0.id == msg1.id }
    XCTAssertTrue(found?.textContent == "Second correction")
    XCTAssertTrue(conv.messages.count == 1)
}

// MARK: - ContextCompiler with multiple failure memories

@MainActor func testContextCompilerMixedSuccessAndFailure() {
    let compiler = ContextCompiler()
    let memories = [
        TaskMemory(task: "Build project", steps: ["swift build"], success: true, learnedWorkflow: "swift build"),
        TaskMemory(task: "Run tests", steps: ["swift test"], success: false, failureReason: "Test assertion failed"),
        TaskMemory(task: "Open browser", steps: ["open_app"], success: true, learnedWorkflow: "open_app -> Safari"),
    ]
    let context = compiler.buildWorkflowMemoryContext(memories: memories)
    XCTAssertTrue(context.contains("Build project"))
    XCTAssertTrue(context.contains("Run tests"))
    XCTAssertTrue(context.contains("状态: 失败"))
    XCTAssertTrue(context.contains("Test assertion failed"))
}

@MainActor func testContextCompilerPreservesAllMemories() {
    let compiler = ContextCompiler()
    let memories = (0..<5).map { i in
        TaskMemory(task: "Memory \(i)", steps: ["step_\(i)"], success: i.isMultiple(of: 2), failureReason: i.isMultiple(of: 2) ? nil : "reason_\(i)")
    }
    let context = compiler.buildWorkflowMemoryContext(memories: memories)
    for i in 0..<5 {
        XCTAssertTrue(context.contains("Memory \(i)"))
    }
}

// MARK: - Desktop context with empty windows

func testDesktopContextEmptyWindows() {
    let context = DesktopContext(activeAppName: "Finder", windows: [], uiElements: [])
    let summary = context.promptSummary()
    XCTAssertTrue(summary.contains("Finder"))
}

func testDesktopContextOnlySelectedText() {
    let context = DesktopContext(selectedText: "selected code block")
    let summary = context.promptSummary()
    XCTAssertTrue(summary.contains("selected code block") || summary.contains("选中"))
}

// MARK: - Cross-app context with multiple windows

func testCrossAppContextMaintainsBundleIds() {
    let safari = AppContext(appName: "Safari", bundleIdentifier: "com.apple.Safari")
    let xcode = AppContext(appName: "Xcode", bundleIdentifier: "com.apple.dt.Xcode")
    let terminal = AppContext(appName: "Terminal", bundleIdentifier: "com.apple.Terminal")
    XCTAssertTrue(safari.bundleIdentifier == "com.apple.Safari")
    XCTAssertTrue(xcode.bundleIdentifier == "com.apple.dt.Xcode")
    XCTAssertTrue(terminal.bundleIdentifier == "com.apple.Terminal")
}

// MARK: - BrowserPageState additional fields

func testBrowserPageStateCarriesUrlHost() {
    let state = BrowserPageState(browserName: "Safari", tabTitle: "Docs", url: "https://docs.swift.org/6/documentation", host: "docs.swift.org")
    XCTAssertTrue(state.browserName == "Safari")
    XCTAssertTrue(state.url == "https://docs.swift.org/6/documentation")
    XCTAssertTrue(state.host == "docs.swift.org")
}
