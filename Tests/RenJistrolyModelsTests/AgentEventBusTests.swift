import Foundation
import XCTest
import RenJistrolyModels

// MARK: - AgentEventBus tests

func testPublishAndSubscribe() async {
    let bus = AgentEventBus()
    let (stream, id) = await bus.subscribe()
    defer { Task { await bus.unsubscribe(id) } }

    await bus.publish(.system(.systemWokeFromSleep))

    var events: [AgentEvent] = []
    for await event in stream.prefix(1) {
        events.append(event)
    }
    XCTAssertTrue(events.count == 1)
}

func testMultipleSubscribers() async {
    let bus = AgentEventBus()
    let (s1, id1) = await bus.subscribe()
    let (s2, id2) = await bus.subscribe()
    defer {
        Task { await bus.unsubscribe(id1) }
        Task { await bus.unsubscribe(id2) }
    }

    await bus.publish(.voice(.listeningStarted))

    await withTaskGroup(of: Int.self) { group in
        group.addTask {
            var c = 0
            for await _ in s1.prefix(1) { c += 1 }
            return c
        }
        group.addTask {
            var c = 0
            for await _ in s2.prefix(1) { c += 1 }
            return c
        }
        var total = 0
        for await r in group { total += r }
        XCTAssertTrue(total == 2)
    }
}

func testUnsubscribeStopsDelivery() async {
    let bus = AgentEventBus()
    let (stream, id) = await bus.subscribe()
    await bus.unsubscribe(id)

    await bus.publish(.system(.systemWillSleep))

    var count = 0
    // Stream should be finished after unsubscribe
    for await _ in stream {
        count += 1
    }
    XCTAssertTrue(count == 0)
}

func testRecentEventsBuffer() async {
    let bus = AgentEventBus(maxBufferSize: 10)
    for i in 0..<5 {
        await bus.publish(.voice(.transcriptFinal("msg\(i)")))
    }
    let recent = await bus.recentEvents(3)
    XCTAssertTrue(recent.count == 3)
}

func testBufferEviction() async {
    let bus = AgentEventBus(maxBufferSize: 3)
    for i in 0..<5 {
        await bus.publish(.voice(.transcriptFinal("msg\(i)")))
    }
    let all = await bus.recentEvents(10)
    XCTAssertTrue(all.count == 3)

    // Check that the transcript texts are from the last 3 messages
    let texts = all.compactMap { entry -> String? in
        if case .voice(.transcriptFinal(let t)) = entry.event { return t }
        return nil
    }
    XCTAssertTrue(texts == ["msg2", "msg3", "msg4"])
}

func testFilterByEventKind() async {
    let bus = AgentEventBus()
    await bus.publish(.voice(.listeningStarted))
    await bus.publish(.system(.systemWokeFromSleep))
    await bus.publish(.voice(.listeningStopped))

    let voiceEvents = await bus.events(matching: .voice, limit: 10)
    XCTAssertTrue(voiceEvents.count == 2)
    let systemEvents = await bus.events(matching: .system, limit: 10)
    XCTAssertTrue(systemEvents.count == 1)
}

func testSubscriberCount() async {
    let bus = AgentEventBus()
    var count = await bus.subscriberCount
    XCTAssertTrue(count == 0)

    let (_, id1) = await bus.subscribe()
    count = await bus.subscriberCount
    XCTAssertTrue(count == 1)

    let (_, id2) = await bus.subscribe()
    count = await bus.subscriberCount
    XCTAssertTrue(count == 2)

    await bus.unsubscribe(id1)
    count = await bus.subscriberCount
    XCTAssertTrue(count == 1)

    await bus.unsubscribe(id2)
    count = await bus.subscriberCount
    XCTAssertTrue(count == 0)
}

func testConcurrentPublish() async {
    let bus = AgentEventBus()
    let (stream, id) = await bus.subscribe()
    defer { Task { await bus.unsubscribe(id) } }

    await withTaskGroup(of: Void.self) { group in
        for i in 0..<20 {
            group.addTask {
                await bus.publish(.system(.gateMessageSent(text: "msg\(i)")))
            }
        }
    }

    var count = 0
    for await _ in stream.prefix(20) {
        count += 1
    }
    XCTAssertTrue(count == 20)
}

// MARK: - EventKind and eventDescription

func testEventKindMapping() {
    let voiceEvent = AgentEvent.voice(.listeningStarted)
    XCTAssertTrue(voiceEvent.kind == .voice)

    let desktopEvent = AgentEvent.desktop(.mouseClicked(x: 100, y: 200, button: "left"))
    XCTAssertTrue(desktopEvent.kind == .desktop)

    let browserEvent = AgentEvent.browser(.pageLoaded(url: "https://example.com", title: "Example"))
    XCTAssertTrue(browserEvent.kind == .browser)

    let codeEvent = AgentEvent.code(.buildStarted(target: "MyApp"))
    XCTAssertTrue(codeEvent.kind == .code)

    let lifecycleEvent = AgentEvent.lifecycle(.thinkingStarted(reason: "test"))
    XCTAssertTrue(lifecycleEvent.kind == .lifecycle)

    let systemEvent = AgentEvent.system(.systemWokeFromSleep)
    XCTAssertTrue(systemEvent.kind == .system)
}

func testEventMatchesFiltering() {
    let event = AgentEvent.voice(.listeningStarted)
    XCTAssertTrue(event.matches(.voice))
    XCTAssertTrue(!event.matches(.system))
}

func testEventDescriptionsNotEmpty() {
    let events: [AgentEvent] = [
        .voice(.listeningStarted),
        .voice(.transcriptFinal("hello")),
        .desktop(.appActivated(bundleID: "com.example", name: "Example")),
        .browser(.pageLoaded(url: "https://example.com", title: "Example")),
        .code(.buildCompleted(exitCode: 0, errorCount: 0, warningCount: 0)),
        .lifecycle(.planningCompleted(steps: 3)),
        .system(.systemWokeFromSleep),
    ]
    for event in events {
        XCTAssertFalse(event.eventDescription.isEmpty)
    }
}

// MARK: - Desktop event construction

func testAllDesktopEventsConstructCorrectly() {
    let events: [AgentEvent] = [
        .desktop(.appActivated(bundleID: "com.apple.Safari", name: "Safari")),
        .desktop(.appDeactivated(bundleID: "com.apple.Safari", name: "Safari")),
        .desktop(.windowFocused(title: "RenJistroly", owner: "Xcode")),
        .desktop(.mouseClicked(x: 100, y: 200, button: "left")),
        .desktop(.textTyped(text: "hello", app: "Safari")),
        .desktop(.shortcutPressed(key: "space", modifiers: "cmd")),
        .desktop(.scrolled(direction: "down", amount: 3)),
        .desktop(.dragStarted(fromX: 0, fromY: 0, toX: 100, toY: 100)),
        .desktop(.menuActivated(path: "File/New Window")),
        .desktop(.screenCaptured(ocrCharCount: 500, windowCount: 3)),
    ]
    for event in events {
        XCTAssertTrue(event.kind == .desktop)
        XCTAssertFalse(event.eventDescription.isEmpty)
    }
}

// MARK: - Browser event construction

func testAllBrowserEventsConstructCorrectly() {
    let events: [AgentEvent] = [
        .browser(.pageLoaded(url: "https://example.com", title: "Example")),
        .browser(.pageNavigated(from: "a.com", to: "b.com")),
        .browser(.searchPerformed(query: "swift", engine: "Google")),
        .browser(.domQueried(selector: ".btn", resultCount: 3)),
        .browser(.domClicked(selector: "#submit", success: true)),
        .browser(.domFilled(selector: "#name", success: true)),
        .browser(.domSubmitted(formSelector: "form", success: false)),
        .browser(.consoleOutput(level: "error", message: "404")),
        .browser(.networkRequest(method: "GET", url: "/api", statusCode: 200)),
        .browser(.networkFailure(url: "/api", error: "timeout")),
        .browser(.tabOpened(url: "https://new.com")),
        .browser(.tabClosed),
        .browser(.tabSwitched(index: 1)),
    ]
    for event in events {
        XCTAssertTrue(event.kind == .browser)
        XCTAssertFalse(event.eventDescription.isEmpty)
    }
}

// MARK: - Code event construction

func testAllCodeEventsConstructCorrectly() {
    let events: [AgentEvent] = [
        .code(.buildStarted(target: "MyApp")),
        .code(.buildCompleted(exitCode: 0, errorCount: 0, warningCount: 2)),
        .code(.buildFailed(stderr: "linker error")),
        .code(.testStarted(filter: "LoginTests")),
        .code(.testCompleted(passed: 42, failed: 0, duration: 3.5)),
        .code(.testFailed(name: "testLogin", message: "assertion failed")),
        .code(.lintStarted),
        .code(.lintCompleted(issues: 3)),
        .code(.gitOperation(op: "commit", result: "ok")),
        .code(.fileOpened(path: "/src/main.swift")),
        .code(.fileSaved(path: "/src/main.swift")),
        .code(.fileModified(path: "/src/main.swift", changeType: "changed")),
        .code(.claudeCodeStarted(prompt: "fix the bug")),
        .code(.claudeCodeToken("import")),
        .code(.claudeCodeToolCall(toolName: "bash")),
        .code(.claudeCodeCompleted(summary: "done")),
        .code(.claudeCodeFailed(error: "timeout")),
        .code(.commandExecuted(command: "swift build")),
        .code(.taskApproved("用户已批准")),
        .code(.taskEvent(kind: "build", summary: "build complete")),
    ]
    for event in events {
        XCTAssertTrue(event.kind == .code)
        XCTAssertFalse(event.eventDescription.isEmpty)
    }
}

// MARK: - System event construction

func testAllSystemEventsConstructCorrectly() {
    let events: [AgentEvent] = [
        .system(.permissionChanged(permission: "辅助功能", granted: true)),
        .system(.permissionChanged(permission: "屏幕录制", granted: false)),
        .system(.systemWokeFromSleep),
        .system(.systemWillSleep),
        .system(.gateMessageSent(text: "hello")),
        .system(.gateReplyReceived(text: "world")),
        .system(.gateTimeout(duration: 30.0)),
        .system(.errorOccurred(domain: "network", message: "timeout", recoverable: true)),
        .system(.warningIssued(domain: "memory", message: "low memory")),
        .system(.appNapPrevented),
        .system(.duplicateInstanceDetected),
    ]
    for event in events {
        XCTAssertTrue(event.kind == .system)
        XCTAssertFalse(event.eventDescription.isEmpty)
    }
}

// MARK: - Lifecycle event construction

func testAllLifecycleEventsConstructCorrectly() {
    let events: [AgentEvent] = [
        .lifecycle(.thinkingStarted(reason: "用户输入")),
        .lifecycle(.thinkingCompleted),
        .lifecycle(.planningStarted(goal: "打开Safari")),
        .lifecycle(.planningCompleted(steps: 3)),
        .lifecycle(.actingStarted(action: "click", tool: "accessibility")),
        .lifecycle(.actingCompleted(action: "click", success: true)),
        .lifecycle(.verifyingStarted(action: "click")),
        .lifecycle(.verifyingCompleted(action: "click", passed: true)),
        .lifecycle(.recoveringStarted(action: "click", strategy: "retry")),
        .lifecycle(.recoveringCompleted(action: "click", success: true)),
        .lifecycle(.taskDelegated(to: "子Agent", reason: "并行")),
        .lifecycle(.routeSelected(provider: "deepSeek", confidence: 0.85)),
        .lifecycle(.providerFellback(from: "claudeCode", to: "deepSeek", reason: "timeout")),
        .lifecycle(.taskResumed(reason: "用户已批准")),
        .lifecycle(.taskRetry(attempt: 2)),
        .lifecycle(.approvalRequired(prompt: "需要确认")),
        .lifecycle(.taskStatusUpdate(summary: "执行中")),
        .lifecycle(.contextObserved(detail: "Safari已打开")),
        .lifecycle(.modelFirstToken),
        .lifecycle(.observingStarted(action: "screen")),
        .lifecycle(.turnCompleted(duration: 1.5)),
        .lifecycle(.turnFailed(error: "网络错误")),
    ]
    for event in events {
        XCTAssertTrue(event.kind == .lifecycle)
        XCTAssertFalse(event.eventDescription.isEmpty)
    }
}

// MARK: - Voice event construction

func testAllVoiceEventsConstructCorrectly() {
    let events: [AgentEvent] = [
        .voice(.listeningStarted),
        .voice(.listeningStopped),
        .voice(.transcriptPartial("正在听")),
        .voice(.transcriptFinal("打开Safari")),
        .voice(.speechStarted),
        .voice(.speechEnded),
        .voice(.ttsStarted("已打开Safari")),
        .voice(.ttsCompleted),
        .voice(.ttsInterrupted),
        .voice(.conversationModeToggled(true)),
        .voice(.gateToggled(false)),
    ]
    for event in events {
        XCTAssertTrue(event.kind == .voice)
        XCTAssertFalse(event.eventDescription.isEmpty)
    }
}

// MARK: - Code event value checks

func testClaudeCodeStartedEventValues() {
    let event = AgentEvent.code(.claudeCodeStarted(prompt: "fix the bug"))
    XCTAssertTrue(event.eventDescription.contains("fix the bug"))
}

func testClaudeCodeCompletedEventValues() {
    let event = AgentEvent.code(.claudeCodeCompleted(summary: "task done"))
    XCTAssertTrue(event.eventDescription.contains("task done"))
}

func testClaudeCodeFailedEventValues() {
    let event = AgentEvent.code(.claudeCodeFailed(error: "timeout"))
    XCTAssertTrue(event.eventDescription.contains("timeout"))
}

func testBuildEventsContainKeyInfo() {
    let completed = AgentEvent.code(.buildCompleted(exitCode: 0, errorCount: 0, warningCount: 2))
    XCTAssertTrue(completed.eventDescription.contains("0"))
    XCTAssertTrue(completed.eventDescription.contains("2"))

    let failed = AgentEvent.code(.buildFailed(stderr: "linker error"))
    XCTAssertTrue(failed.eventDescription.contains("linker error"))
}

func testTestEventsContainKeyInfo() {
    let completed = AgentEvent.code(.testCompleted(passed: 42, failed: 0, duration: 3.5))
    XCTAssertTrue(completed.eventDescription.contains("42"))

    let failed = AgentEvent.code(.testFailed(name: "testLogin", message: "assertion"))
    XCTAssertTrue(failed.eventDescription.contains("testLogin"))
}

// MARK: - Browser DOM event value checks

func testDOMQueriedEventValues() {
    let event = AgentEvent.browser(.domQueried(selector: ".btn", resultCount: 3))
    XCTAssertTrue(event.eventDescription.contains(".btn"))
    XCTAssertTrue(event.eventDescription.contains("3"))
}

func testDOMClickedEventValues() {
    let success = AgentEvent.browser(.domClicked(selector: "#submit", success: true))
    XCTAssertTrue(success.eventDescription.contains("#submit"))
    let failure = AgentEvent.browser(.domClicked(selector: "#missing", success: false))
    XCTAssertTrue(failure.eventDescription.contains("#missing"))
}

func testDOMFilledEventValues() {
    let event = AgentEvent.browser(.domFilled(selector: "#name", success: true))
    XCTAssertTrue(event.eventDescription.contains("#name"))
}

func testDOMSubmittedEventValues() {
    let event = AgentEvent.browser(.domSubmitted(formSelector: "form.login", success: true))
    XCTAssertTrue(event.eventDescription.contains("form.login"))
}

// MARK: - System event value checks

func testPermissionChangedEventValues() {
    let granted = AgentEvent.system(.permissionChanged(permission: "辅助功能", granted: true))
    XCTAssertTrue(granted.eventDescription.contains("辅助功能"))
    let denied = AgentEvent.system(.permissionChanged(permission: "屏幕录制", granted: false))
    XCTAssertTrue(denied.eventDescription.contains("屏幕录制"))
}

func testDesktopScreenCapturedEventValues() {
    let event = AgentEvent.desktop(.screenCaptured(ocrCharCount: 500, windowCount: 3))
    XCTAssertTrue(event.eventDescription.contains("500"))
    XCTAssertTrue(event.eventDescription.contains("3"))
}

// MARK: - Code event value checks (additional)

func testGitOperationEventValues() {
    let event = AgentEvent.code(.gitOperation(op: "status", result: "ok"))
    XCTAssertTrue(event.eventDescription.contains("status"))
}

func testFileOpenedEventValues() {
    let event = AgentEvent.code(.fileOpened(path: "/src/main.swift"))
    XCTAssertTrue(event.eventDescription.contains("/src/main.swift"))
}

func testFileSavedEventValues() {
    let event = AgentEvent.code(.fileSaved(path: "/src/main.swift"))
    XCTAssertTrue(event.eventDescription.contains("/src/main.swift"))
}

func testClaudeCodeToolCallEventValues() {
    let event = AgentEvent.code(.claudeCodeToolCall(toolName: "swift"))
    XCTAssertTrue(event.eventDescription.contains("swift"))
}

// MARK: - Desktop event value checks (additional)

func testDragStartedEventDescriptionNonEmpty() {
    let event = AgentEvent.desktop(.dragStarted(fromX: 10, fromY: 20, toX: 100, toY: 200))
    XCTAssertFalse(event.eventDescription.isEmpty)
}

func testWindowFocusedEventValues() {
    let withTitle = AgentEvent.desktop(.windowFocused(title: "Safari", owner: "Safari"))
    XCTAssertTrue(withTitle.eventDescription.contains("Safari"))
    let withoutTitle = AgentEvent.desktop(.windowFocused(title: nil, owner: "Finder"))
    XCTAssertFalse(withoutTitle.eventDescription.isEmpty)
}

// MARK: - Session Lifecycle FSM tests

func testSessionLifecycleInitialState() {
    let lifecycle = SessionLifecycle()
    XCTAssertTrue(lifecycle.phase == .idle)
    XCTAssertFalse(lifecycle.isActive)
}

func testValidTransitions() {
    var lifecycle = SessionLifecycle()
    var ok = lifecycle.transition(to: .listening)
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .listening)
    XCTAssertTrue(lifecycle.isActive)

    ok = lifecycle.transition(to: .thinking)
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .thinking)

    ok = lifecycle.transition(to: .planning)
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .planning)

    ok = lifecycle.transition(to: .acting)
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .acting)

    ok = lifecycle.transition(to: .verifying)
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .verifying)

    ok = lifecycle.transition(to: .responding)
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .responding)

    ok = lifecycle.transition(to: .idle)
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .idle)
    XCTAssertFalse(lifecycle.isActive)
}

func testInvalidTransitionsBlocked() {
    var lifecycle = SessionLifecycle()
    var ok = lifecycle.transition(to: .acting)
    XCTAssertFalse(ok)
    XCTAssertTrue(lifecycle.phase == .idle)

    ok = lifecycle.transition(to: .verifying)
    XCTAssertFalse(ok)
    XCTAssertTrue(lifecycle.phase == .idle)

    ok = lifecycle.transition(to: .recovering)
    XCTAssertFalse(ok)
    XCTAssertTrue(lifecycle.phase == .idle)
}

func testRecoveryPath() {
    var lifecycle = SessionLifecycle()
    _ = lifecycle.transition(to: .listening)
    _ = lifecycle.transition(to: .thinking)
    _ = lifecycle.transition(to: .planning)
    _ = lifecycle.transition(to: .acting)

    var ok = lifecycle.transition(to: .recovering)
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .recovering)

    ok = lifecycle.transition(to: .acting)
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .acting)

    _ = lifecycle.transition(to: .recovering)
    ok = lifecycle.transition(to: .responding)
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .responding)
}

func testVerificationRecoveryPath() {
    var lifecycle = SessionLifecycle()
    _ = lifecycle.transition(to: .listening)
    _ = lifecycle.transition(to: .thinking)
    _ = lifecycle.transition(to: .planning)
    _ = lifecycle.transition(to: .acting)
    _ = lifecycle.transition(to: .verifying)

    var ok = lifecycle.transition(to: .recovering)
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .recovering)

    _ = lifecycle.transition(to: .acting)
    _ = lifecycle.transition(to: .verifying)
    ok = lifecycle.transition(to: .responding)
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .responding)
}

func testThinkingToResponding() {
    var lifecycle = SessionLifecycle()
    _ = lifecycle.transition(to: .thinking)
    let ok = lifecycle.transition(to: .responding)
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .responding)
}

func testTransitionHistory() {
    var lifecycle = SessionLifecycle()
    _ = lifecycle.transition(to: .listening, reason: "voice started")
    _ = lifecycle.transition(to: .thinking, reason: "processing")
    _ = lifecycle.transition(to: .idle, reason: "done")

    XCTAssertTrue(lifecycle.transitionHistory.count == 3)
    XCTAssertTrue(lifecycle.transitionHistory[0].from == .idle)
    XCTAssertTrue(lifecycle.transitionHistory[0].to == .listening)
    XCTAssertTrue(lifecycle.transitionHistory[0].reason == "voice started")
    XCTAssertTrue(lifecycle.transitionHistory[2].to == .idle)
}

func testPhaseLabels() {
    XCTAssertTrue(SessionPhase.idle.label == "空闲")
    XCTAssertTrue(SessionPhase.listening.label == "监听中")
    XCTAssertTrue(SessionPhase.thinking.label == "思考中")
    XCTAssertTrue(SessionPhase.planning.label == "规划中")
    XCTAssertTrue(SessionPhase.acting.label == "执行中")
    XCTAssertTrue(SessionPhase.verifying.label == "验证中")
    XCTAssertTrue(SessionPhase.recovering.label == "恢复中")
    XCTAssertTrue(SessionPhase.responding.label == "回复中")
}

func testTimeInCurrentPhase() async {
    var lifecycle = SessionLifecycle()
    _ = lifecycle.transition(to: .thinking)
    try? await Task.sleep(for: .milliseconds(10))
    XCTAssertTrue(lifecycle.timeInCurrentPhase >= 0.01)
}

// MARK: - Browser console/network event value checks

func testConsoleOutputEventValues() {
    let event = AgentEvent.browser(.consoleOutput(level: "error", message: "undefined is not a function"))
    XCTAssertTrue(event.eventDescription.contains("error"))
    XCTAssertTrue(event.eventDescription.contains("undefined"))
}

func testNetworkRequestEventValues() {
    let withStatus = AgentEvent.browser(.networkRequest(method: "POST", url: "https://api.example.com/data", statusCode: 200))
    XCTAssertTrue(withStatus.eventDescription.contains("POST"))
    XCTAssertTrue(withStatus.eventDescription.contains("200"))

    let withoutStatus = AgentEvent.browser(.networkRequest(method: "GET", url: "https://example.com", statusCode: nil))
    XCTAssertTrue(withoutStatus.eventDescription.contains("GET"))
}

func testNetworkFailureEventValues() {
    let event = AgentEvent.browser(.networkFailure(url: "https://api.example.com", error: "timeout"))
    XCTAssertTrue(event.eventDescription.contains("api.example.com"))
}

// MARK: - Model Codable round-trips

func testTaskAggregationCodable() throws {
    let agg = TaskAggregation(
        totalTasks: 5, completed: 3, failed: 1, pending: 1,
        changedFiles: ["a.swift", "b.swift"],
        commandsRun: ["swift build", "swift test"],
        combinedOutput: "build ok\n1210 tests passed",
        summaries: ["done", "failed: timeout"],
        allSucceeded: false
    )
    let data = try JSONEncoder().encode(agg)
    let decoded = try JSONDecoder().decode(TaskAggregation.self, from: data)
    XCTAssertTrue(decoded.totalTasks == 5)
    XCTAssertTrue(decoded.completed == 3)
    XCTAssertTrue(decoded.failed == 1)
    XCTAssertTrue(decoded.changedFiles.count == 2)
    XCTAssertTrue(decoded.allSucceeded == false)
}

func testMemoryPatternCodable() throws {
    let pattern = MemoryPattern(
        pattern: "click → type → submit",
        sourceTaskCount: 5,
        successRate: 0.8,
        kind: .workflowSequence
    )
    let data = try JSONEncoder().encode(pattern)
    let decoded = try JSONDecoder().decode(MemoryPattern.self, from: data)
    XCTAssertTrue(decoded.pattern == "click → type → submit")
    XCTAssertTrue(decoded.sourceTaskCount == 5)
    XCTAssertTrue(decoded.successRate == 0.8)
    XCTAssertTrue(decoded.kind == .workflowSequence)
    XCTAssertTrue(decoded.id == "click → type → submit")
}

func testTaskMemoryWithOptionalFields() throws {
    let memory = TaskMemory(
        task: "refactor auth",
        steps: ["step1", "step2"],
        success: true,
        failureReason: nil,
        learnedWorkflow: "use OAuth pattern"
    )
    XCTAssertTrue(memory.success)
    XCTAssertTrue(memory.failureReason == nil)
    XCTAssertTrue(memory.learnedWorkflow == "use OAuth pattern")

    let failed = TaskMemory(
        task: "deploy",
        steps: ["push"],
        success: false,
        failureReason: "network timeout"
    )
    XCTAssertFalse(failed.success)
    XCTAssertTrue(failed.failureReason == "network timeout")
    XCTAssertTrue(failed.learnedWorkflow == nil)
}

func testDeveloperAgentTaskDependencyFields() {
    let taskA = DeveloperAgentTask(prompt: "task A", dependsOn: [], blockedBy: [])
    XCTAssertTrue(taskA.dependsOn.isEmpty)
    XCTAssertTrue(taskA.blockedBy.isEmpty)

    let idB = UUID()
    let taskB = DeveloperAgentTask(prompt: "task B", dependsOn: [idB], blockedBy: [idB])
    XCTAssertTrue(taskB.dependsOn == [idB])
    XCTAssertTrue(taskB.blockedBy == [idB])
}
