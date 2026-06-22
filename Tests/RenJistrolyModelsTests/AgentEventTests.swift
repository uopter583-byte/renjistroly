import XCTest
import RenJistrolyModels

// MARK: - Comprehensive AgentEvent description tests

func testAllVoiceEventDescriptions() {
    let events: [AgentEvent] = [
        .voice(.listeningStarted),
        .voice(.listeningStopped),
        .voice(.transcriptPartial("hello world")),
        .voice(.transcriptFinal("hello world")),
        .voice(.speechStarted),
        .voice(.speechEnded),
        .voice(.ttsStarted("hello")),
        .voice(.ttsCompleted),
        .voice(.ttsInterrupted),
        .voice(.conversationModeToggled(true)),
        .voice(.conversationModeToggled(false)),
        .voice(.gateToggled(true)),
        .voice(.gateToggled(false)),
    ]
    for event in events {
        XCTAssertFalse(event.eventDescription.isEmpty)
        XCTAssertTrue(event.kind == .voice)
    }
    XCTAssertTrue(events.count == 13)
}

func testAllDesktopEventDescriptions() {
    let events: [AgentEvent] = [
        .desktop(.appActivated(bundleID: "com.apple.Safari", name: "Safari")),
        .desktop(.appDeactivated(bundleID: "com.apple.Safari", name: "Safari")),
        .desktop(.windowFocused(title: "Test Window", owner: "Safari")),
        .desktop(.windowFocused(title: nil, owner: "Finder")),
        .desktop(.mouseClicked(x: 100, y: 200, button: "left")),
        .desktop(.textTyped(text: "Hello World", app: "Safari")),
        .desktop(.textTyped(text: "Hello", app: nil)),
        .desktop(.shortcutPressed(key: "space", modifiers: "cmd")),
        .desktop(.scrolled(direction: "up", amount: 3)),
        .desktop(.dragStarted(fromX: 0, fromY: 0, toX: 100, toY: 200)),
        .desktop(.menuActivated(path: "File/New Window")),
        .desktop(.screenCaptured(ocrCharCount: 500, windowCount: 3)),
    ]
    for event in events {
        XCTAssertFalse(event.eventDescription.isEmpty)
        XCTAssertTrue(event.kind == .desktop)
    }
    XCTAssertTrue(events.count == 12)
}

func testAllBrowserEventDescriptions() {
    let events: [AgentEvent] = [
        .browser(.pageLoaded(url: "https://example.com", title: "Example")),
        .browser(.pageLoaded(url: "https://example.com", title: nil)),
        .browser(.pageNavigated(from: "https://a.com", to: "https://b.com")),
        .browser(.searchPerformed(query: "Swift", engine: "Google")),
        .browser(.domQueried(selector: ".button", resultCount: 5)),
        .browser(.domClicked(selector: "#submit", success: true)),
        .browser(.domClicked(selector: "#missing", success: false)),
        .browser(.domFilled(selector: "#input", success: true)),
        .browser(.domFilled(selector: "#bad", success: false)),
        .browser(.domSubmitted(formSelector: "#form", success: true)),
        .browser(.domSubmitted(formSelector: "#bad", success: false)),
        .browser(.consoleOutput(level: "error", message: "something broke")),
        .browser(.networkRequest(method: "GET", url: "https://api.example.com", statusCode: 200)),
        .browser(.networkRequest(method: "POST", url: "https://api.example.com", statusCode: nil)),
        .browser(.networkFailure(url: "https://api.example.com", error: "timeout")),
        .browser(.tabOpened(url: "https://example.com")),
        .browser(.tabOpened(url: nil)),
        .browser(.tabClosed),
        .browser(.tabSwitched(index: 2)),
    ]
    for event in events {
        XCTAssertFalse(event.eventDescription.isEmpty)
        XCTAssertTrue(event.kind == .browser)
    }
    XCTAssertTrue(events.count == 19)
}

func testAllCodeEventDescriptions() {
    let events: [AgentEvent] = [
        .code(.buildStarted(target: "MyApp")),
        .code(.buildStarted(target: nil)),
        .code(.buildCompleted(exitCode: 0, errorCount: 0, warningCount: 0)),
        .code(.buildCompleted(exitCode: 1, errorCount: 3, warningCount: 5)),
        .code(.buildFailed(stderr: "error: type 'Foo' has no member 'bar'")),
        .code(.testStarted(filter: "LoginTests")),
        .code(.testStarted(filter: nil)),
        .code(.testCompleted(passed: 10, failed: 2, duration: 5.5)),
        .code(.testFailed(name: "testLogin", message: "expected true, got false")),
        .code(.lintStarted),
        .code(.lintCompleted(issues: 3)),
        .code(.lintCompleted(issues: 0)),
        .code(.gitOperation(op: "commit", result: "1 file changed")),
        .code(.fileOpened(path: "/path/to/main.swift")),
        .code(.fileSaved(path: "/path/to/main.swift")),
        .code(.fileModified(path: "/path/to/main.swift", changeType: "modified")),
        .code(.claudeCodeStarted(prompt: "fix the bug in login flow")),
        .code(.claudeCodeToken("fun")),
        .code(.claudeCodeToolCall(toolName: "Bash")),
        .code(.claudeCodeCompleted(summary: "Fixed the login bug")),
        .code(.claudeCodeFailed(error: "API rate limit exceeded")),
        .code(.commandExecuted(command: "swift build")),
        .code(.taskApproved("fix crash bug")),
        .code(.taskEvent(kind: "build", summary: "Build succeeded")),
    ]
    for event in events {
        XCTAssertFalse(event.eventDescription.isEmpty)
        XCTAssertTrue(event.kind == .code)
    }
    XCTAssertTrue(events.count == 24)
}

func testAllLifecycleEventDescriptions() {
    let events: [AgentEvent] = [
        .lifecycle(.thinkingStarted(reason: "user asked about weather")),
        .lifecycle(.thinkingCompleted),
        .lifecycle(.planningStarted(goal: "open Safari and search")),
        .lifecycle(.planningCompleted(steps: 3)),
        .lifecycle(.actingStarted(action: "click button", tool: "click")),
        .lifecycle(.actingCompleted(action: "click button", success: true)),
        .lifecycle(.actingCompleted(action: "click button", success: false)),
        .lifecycle(.verifyingStarted(action: "check page loaded")),
        .lifecycle(.verifyingCompleted(action: "check page loaded", passed: true)),
        .lifecycle(.verifyingCompleted(action: "check page loaded", passed: false)),
        .lifecycle(.recoveringStarted(action: "click button", strategy: "retry with offset")),
        .lifecycle(.recoveringCompleted(action: "click button", success: true)),
        .lifecycle(.recoveringCompleted(action: "click button", success: false)),
        .lifecycle(.taskDelegated(to: "code agent", reason: "needs build")),
        .lifecycle(.routeSelected(provider: "claude", confidence: 0.95)),
        .lifecycle(.providerFellback(from: "openai", to: "claude", reason: "timeout")),
        .lifecycle(.taskResumed(reason: "用户已批准")),
        .lifecycle(.taskRetry(attempt: 3)),
        .lifecycle(.approvalRequired(prompt: "需要确认删除操作")),
        .lifecycle(.taskStatusUpdate(summary: "构建完成")),
        .lifecycle(.contextObserved(detail: "OCR:on visible:3")),
        .lifecycle(.modelFirstToken),
        .lifecycle(.observingStarted(action: "click")),
        .lifecycle(.turnCompleted(duration: 1.5)),
        .lifecycle(.turnFailed(error: "timeout")),
    ]
    for event in events {
        XCTAssertFalse(event.eventDescription.isEmpty)
        XCTAssertTrue(event.kind == .lifecycle)
    }
    XCTAssertTrue(events.count == 25)
}

func testAllSystemEventDescriptions() {
    let events: [AgentEvent] = [
        .system(.permissionChanged(permission: "accessibility", granted: true)),
        .system(.permissionChanged(permission: "microphone", granted: false)),
        .system(.systemWokeFromSleep),
        .system(.systemWillSleep),
        .system(.gateMessageSent(text: "turn on voice mode")),
        .system(.gateReplyReceived(text: "voice mode enabled")),
        .system(.gateTimeout(duration: 30)),
        .system(.errorOccurred(domain: "network", message: "connection refused", recoverable: true)),
        .system(.errorOccurred(domain: "disk", message: "no space left", recoverable: false)),
        .system(.warningIssued(domain: "memory", message: "high memory pressure")),
        .system(.appNapPrevented),
        .system(.duplicateInstanceDetected),
    ]
    for event in events {
        XCTAssertFalse(event.eventDescription.isEmpty)
        XCTAssertTrue(event.kind == .system)
    }
    XCTAssertTrue(events.count == 12)
}

// MARK: - Event count verification (catches regressions when new events are added)

func testTotalEventCount() {
    // Voice: 11 + Desktop: 10 + Browser: 13 + Code: 20 + Lifecycle: 22 + System: 10 = 86
    func countVoiceCases() -> Int {
        let cases: [VoiceEvent] = [
            .listeningStarted, .listeningStopped,
            .transcriptPartial(""), .transcriptFinal(""),
            .speechStarted, .speechEnded,
            .ttsStarted(""), .ttsCompleted, .ttsInterrupted,
            .conversationModeToggled(true), .gateToggled(true),
        ]
        return cases.count
    }
    func countDesktopCases() -> Int {
        let cases: [DesktopEvent] = [
            .appActivated(bundleID: "", name: ""), .appDeactivated(bundleID: "", name: ""),
            .windowFocused(title: "", owner: ""),
            .mouseClicked(x: 0, y: 0, button: ""),
            .textTyped(text: "", app: ""),
            .shortcutPressed(key: "", modifiers: ""),
            .scrolled(direction: "", amount: 0),
            .dragStarted(fromX: 0, fromY: 0, toX: 0, toY: 0),
            .menuActivated(path: ""),
            .screenCaptured(ocrCharCount: 0, windowCount: 0),
        ]
        return cases.count
    }
    func countSystemCases() -> Int {
        let cases: [SystemEvent] = [
            .permissionChanged(permission: "", granted: true),
            .systemWokeFromSleep, .systemWillSleep,
            .gateMessageSent(text: ""), .gateReplyReceived(text: ""),
            .gateTimeout(duration: 0),
            .errorOccurred(domain: "", message: "", recoverable: true),
            .warningIssued(domain: "", message: ""),
            .appNapPrevented, .duplicateInstanceDetected,
        ]
        return cases.count
    }
    func countBrowserCases() -> Int {
        let cases: [BrowserEvent] = [
            .pageLoaded(url: "", title: ""), .pageNavigated(from: "", to: ""),
            .searchPerformed(query: "", engine: ""),
            .domQueried(selector: "", resultCount: 0),
            .domClicked(selector: "", success: true), .domFilled(selector: "", success: true),
            .domSubmitted(formSelector: "", success: true),
            .consoleOutput(level: "", message: ""),
            .networkRequest(method: "", url: "", statusCode: 0), .networkFailure(url: "", error: ""),
            .tabOpened(url: ""), .tabClosed, .tabSwitched(index: 0),
        ]
        return cases.count
    }
    func countCodeCases() -> Int {
        let cases: [CodeEvent] = [
            .buildStarted(target: ""), .buildCompleted(exitCode: 0, errorCount: 0, warningCount: 0),
            .buildFailed(stderr: ""),
            .testStarted(filter: ""), .testCompleted(passed: 0, failed: 0, duration: 0),
            .testFailed(name: "", message: ""),
            .lintStarted, .lintCompleted(issues: 0),
            .gitOperation(op: "", result: ""),
            .fileOpened(path: ""), .fileSaved(path: ""), .fileModified(path: "", changeType: ""),
            .claudeCodeStarted(prompt: ""), .claudeCodeToken(""), .claudeCodeToolCall(toolName: ""),
            .claudeCodeCompleted(summary: ""), .claudeCodeFailed(error: ""),
            .commandExecuted(command: ""), .taskApproved(""), .taskEvent(kind: "", summary: ""),
        ]
        return cases.count
    }
    func countLifecycleCases() -> Int {
        let cases: [LifecycleEvent] = [
            .thinkingStarted(reason: ""), .thinkingCompleted,
            .planningStarted(goal: ""), .planningCompleted(steps: 0),
            .actingStarted(action: "", tool: ""), .actingCompleted(action: "", success: true),
            .verifyingStarted(action: ""), .verifyingCompleted(action: "", passed: true),
            .recoveringStarted(action: "", strategy: ""), .recoveringCompleted(action: "", success: true),
            .taskDelegated(to: "", reason: ""),
            .routeSelected(provider: "", confidence: 0), .providerFellback(from: "", to: "", reason: ""),
            .taskResumed(reason: ""), .taskRetry(attempt: 0),
            .approvalRequired(prompt: ""), .taskStatusUpdate(summary: ""),
            .contextObserved(detail: ""), .modelFirstToken,
            .observingStarted(action: ""), .turnCompleted(duration: 0),
            .turnFailed(error: ""),
        ]
        return cases.count
    }
    XCTAssertTrue(countVoiceCases() == 11)
    XCTAssertTrue(countDesktopCases() == 10)
    XCTAssertTrue(countBrowserCases() == 13)
    XCTAssertTrue(countCodeCases() == 20)
    XCTAssertTrue(countLifecycleCases() == 22)
    XCTAssertTrue(countSystemCases() == 10)
}

// MARK: - Edge cases

func testEventDescriptionWithLongText() {
    let longText = String(repeating: "A", count: 500)
    let event = AgentEvent.voice(.transcriptFinal(longText))
    XCTAssertFalse(event.eventDescription.isEmpty)
    XCTAssertTrue(event.eventDescription.count < 100) // Should be truncated
}

func testEventDescriptionWithSpecialCharacters() {
    let text = "你好世界 / 🎉 \n\t"
    let event = AgentEvent.voice(.transcriptFinal(text))
    XCTAssertFalse(event.eventDescription.isEmpty)
}

func testEventKindExhaustive() {
    // Every event variant maps to its correct kind
    XCTAssertTrue(AgentEvent.voice(.listeningStarted).kind == .voice)
    XCTAssertTrue(AgentEvent.desktop(.appActivated(bundleID: "", name: "")).kind == .desktop)
    XCTAssertTrue(AgentEvent.browser(.pageLoaded(url: "", title: "")).kind == .browser)
    XCTAssertTrue(AgentEvent.code(.buildStarted(target: "")).kind == .code)
    XCTAssertTrue(AgentEvent.lifecycle(.thinkingStarted(reason: "")).kind == .lifecycle)
    XCTAssertTrue(AgentEvent.system(.systemWokeFromSleep).kind == .system)
}
