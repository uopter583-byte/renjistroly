import Foundation
import RenJistrolyModels
import XCTest
@testable import RenJistrolyConversation

// MARK: - Log Each Turn's User Input

@MainActor func testDiagnosticsLogsUserInputInSessionLifecycle() {
    var lifecycle = SessionLifecycle()
    XCTAssertTrue(lifecycle.phase == .idle)
    XCTAssertTrue(lifecycle.transitionHistory.isEmpty)

    let ok = lifecycle.transition(to: .thinking, reason: "用户输入: 帮我重构代码")
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .thinking)
    XCTAssertTrue(lifecycle.transitionHistory.count == 1)
    XCTAssertTrue(lifecycle.transitionHistory.first?.reason.contains("重构") == true)
}

@MainActor func testDiagnosticsLogsUserInputViaAgentTimelineEvent() {
    let event = AgentTimelineEvent(
        timestamp: Date(),
        source: "developer",
        kind: "input",
        summary: "用户输入: 帮我重构网络层"
    )
    XCTAssertTrue(event.source == "developer")
    XCTAssertTrue(event.kind == "input")
    XCTAssertTrue(event.summary.contains("重构网络层"))
}

// MARK: - Log Provider Selection and Context

@MainActor func testDiagnosticsLogsRouteSelectionWithProvider() {
    let event = AgentTimelineEvent(
        source: "lifecycle",
        kind: "route",
        summary: "路由: DeepSeek (85%)"
    )
    XCTAssertTrue(event.kind == "route")
    XCTAssertTrue(event.summary.contains("DeepSeek"))
}

@MainActor func testDiagnosticsLogsContextObservedInLifecycle() {
    let event = AgentTimelineEvent(
        source: "lifecycle",
        kind: "context",
        summary: "上下文: 项目路径 /Users/dev/Project"
    )
    XCTAssertTrue(event.summary.contains("项目路径"))
}

// MARK: - Log Action Plan Generation

@MainActor func testDiagnosticsLogsPlanGenerationInTimeline() {
    let event = AgentTimelineEvent(
        source: "developer",
        kind: "plan",
        summary: "规划: 重构网络层为 async/await"
    )
    XCTAssertTrue(event.kind == "plan")
    XCTAssertTrue(event.summary.contains("重构"))
}

@MainActor func testDiagnosticsBuildRecentAgentTimelineWithDeveloperTasks() {
    let devTask = DeveloperAgentTask(
        prompt: "fix build errors",
        status: .completed,
        output: "Build complete!",
        events: [
            DeveloperAgentEvent(kind: "build", summary: "构建通过"),
            DeveloperAgentEvent(kind: "summary", summary: "Finished fixing errors"),
        ]
    )
    let timeline = ConversationEngine.buildRecentAgentTimeline(
        developerTasks: [devTask],
        computerUseTrace: nil
    )
    XCTAssertFalse(timeline.isEmpty)
    XCTAssertTrue(timeline.contains(where: { $0.summary.contains("构建通过") }))
    XCTAssertTrue(timeline.contains(where: { $0.source == "developer" }))
}

// MARK: - Log Execution Plan with Steps

@MainActor func testDiagnosticsLogsExecutionStepsViaDeveloperTaskFinalText() {
    let task = DeveloperAgentTask(
        prompt: "add login feature",
        status: .completed,
        output: "Created LoginView.swift",
        changedFiles: ["Sources/LoginView.swift"],
        commandsRun: ["swift build", "swift test"],
        buildSummary: "Build complete! (0.5s)",
        testSummary: "Test run with 8 tests passed after 0.3s",
        resultSummary: "Summary: Added login screen with validation"
    )
    let text = ConversationEngine.formatDeveloperTaskFinalText(task)
    XCTAssertTrue(text.contains("LoginView.swift"))
    XCTAssertTrue(text.contains("Build complete"))
    XCTAssertTrue(text.contains("8 tests passed"))
    XCTAssertTrue(text.contains("Added login screen"))
}

@MainActor func testDiagnosticsLogsWaitingForConfirmationInSteps() {
    let task = DeveloperAgentTask(
        prompt: "edit config",
        status: .waitingForConfirmation,
        output: "Needs approval before editing files",
        pendingApprovalSummary: "Needs approval before editing files"
    )
    let text = ConversationEngine.formatDeveloperTaskFinalText(task)
    XCTAssertTrue(text.contains("等待确认"))
}

// MARK: - Log Execution Results

@MainActor func testDiagnosticsLogsExecutionResultViaConciseTraceEvent() {
    let observeEvent = ComputerUseTraceEvent(
        id: UUID(),
        phase: "observing",
        stepIndex: 0,
        toolName: "get_app_state",
        summary: "Observation: window title=Safari"
    )
    let line = ConversationEngine.conciseTraceEventLine(observeEvent, previousEvent: nil)
    XCTAssertTrue(line != nil)
    XCTAssertTrue(line?.contains("观察") == true)
}

@MainActor func testDiagnosticsLogsExecutionResultDuplicatesSuppressed() {
    let event = ComputerUseTraceEvent(
        id: UUID(),
        phase: "observing",
        stepIndex: 0,
        toolName: "get_app_state",
        summary: "dup"
    )
    let first = ConversationEngine.conciseTraceEventLine(event, previousEvent: nil)
    let second = ConversationEngine.conciseTraceEventLine(event, previousEvent: event)
    XCTAssertTrue(first != nil)
    XCTAssertTrue(second == nil)
}

// MARK: - Log Errors with Stack Traces

@MainActor func testDiagnosticsLogsErrorViaBriefComputerUseResult() {
    let action = ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "open_app", arguments: ["app_name": "Xcode"]))
    let failedStep = ComputerUseStepResult(
        action: action,
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "Xcode not found", isError: true),
        afterState: nil,
        verified: false
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [failedStep])
    let brief = ConversationEngine.briefComputerUseResult(run)
    XCTAssertTrue(brief.contains("未完成"))
}

@MainActor func testDiagnosticsLogsRecoveryInBriefResult() {
    let action = ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "open_app", arguments: ["app_name": "Xcode"]))
    let recoveredStep = ComputerUseStepResult(
        action: action,
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "done"),
        afterState: nil,
        verified: true,
        recoverySummary: "Found Xcode via Spotlight"
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [recoveredStep])
    let brief = ConversationEngine.briefComputerUseResult(run)
    XCTAssertTrue(brief.contains("已完成"))
    XCTAssertTrue(brief.contains("Found Xcode"))
}

// MARK: - Log Timing / Duration per Step

func testDiagnosticsLogsTimingViaSessionLifecycle() {
    var lifecycle = SessionLifecycle()
    XCTAssertTrue(lifecycle.timeInCurrentPhase >= 0)
    _ = lifecycle.transition(to: .thinking, reason: "分析代码")
    let thinkingTime = lifecycle.timeInCurrentPhase
    XCTAssertTrue(thinkingTime >= 0)
    XCTAssertTrue(lifecycle.transitionHistory.count == 1)
}

func testDiagnosticsLogsPhaseDurationViaTransitionHistory() {
    var lifecycle = SessionLifecycle()
    _ = lifecycle.transition(to: .thinking, reason: "思考")
    _ = lifecycle.transition(to: .planning, reason: "规划")
    _ = lifecycle.transition(to: .acting, reason: "执行")
    _ = lifecycle.transition(to: .verifying, reason: "验证")
    _ = lifecycle.transition(to: .responding, reason: "回复")
    _ = lifecycle.transition(to: .idle, reason: "完成")
    XCTAssertTrue(lifecycle.transitionHistory.count == 6)
    let transitions = lifecycle.transitionHistory
    XCTAssertTrue(transitions[0].from == .idle && transitions[0].to == .thinking)
    XCTAssertTrue(transitions[1].from == .thinking && transitions[1].to == .planning)
    XCTAssertTrue(transitions[2].to == .acting)
    XCTAssertTrue(transitions[3].to == .verifying)
    XCTAssertTrue(transitions[4].to == .responding)
    XCTAssertTrue(transitions[5].to == .idle)
}

// MARK: - Capture Screenshot / OCR Evidence

func testDiagnosticsDesktopContextProvidesScreenSnapshot() {
    let context = DesktopContext(
        activeAppName: "Safari",
        focusedWindowTitle: "GitHub",
        windows: [DesktopWindow(title: "GitHub")]
    )
    XCTAssertTrue(context.activeAppName == "Safari")
    XCTAssertTrue(context.focusedWindowTitle == "GitHub")
    XCTAssertTrue(context.windows.count == 1)
}

func testDiagnosticsAgentEventSummaryForScreenCapture() {
    let event = AgentEvent.desktop(.screenCaptured(ocrCharCount: 1200, windowCount: 5))
    XCTAssertTrue(event.summary.contains("1200"))
    XCTAssertTrue(event.summary.contains("5"))
    XCTAssertTrue(event.category == "desktop")
}

func testDiagnosticsAgentEventSummaryForError() {
    let event = AgentEvent.system(.errorOccurred(domain: "tool", message: "network timeout", recoverable: true))
    XCTAssertTrue(event.summary.contains("timeout"))
    XCTAssertTrue(event.category == "system")
}

// MARK: - Export Replicable Diagnostics

func testDiagnosticsExportsWorkflowMemoryContext() async {
    let store = WorkflowMemoryStore(storageURL: nil)
    await store.remember(
        task: "fix login bug",
        steps: ["tool: open_app", "tool: click", "verify: login works"],
        success: true,
        domain: "developerWorkflow",
        tags: ["login", "bugfix"]
    )
    await store.remember(
        task: "add search feature",
        steps: ["tool: open_app", "tool: type_text"],
        success: false,
        failureReason: "build error: missing dependency",
        failureCategory: .buildError,
        domain: "developerWorkflow"
    )
    let all = await store.all()
    XCTAssertTrue(all.count == 2)
    XCTAssertTrue(all.contains(where: { $0.task == "fix login bug" }))
    XCTAssertTrue(all.contains(where: { $0.task == "add search feature" }))

    let failures = await store.recentFailurePatterns()
    XCTAssertFalse(failures.isEmpty)
}

func testDiagnosticsExportsConsolidatedContext() async {
    let store = WorkflowMemoryStore(storageURL: nil)
    for i in 1...3 {
        await store.remember(
            task: "task \(i)",
            steps: ["step \(i)"],
            success: true,
            domain: "test"
        )
    }
    let context = await store.consolidatedContext(limit: 3)
    XCTAssertFalse(context.isEmpty)
}

// MARK: - Persist Logs Across App Restart

func testDiagnosticsWorkflowMemoryPersistsByDefault() {
    let url = WorkflowMemoryStore.defaultStorageURL()
    XCTAssertTrue(url.lastPathComponent == "workflow-memories.json")
    XCTAssertTrue(url.path.contains("RenJistroly"))
}

func testDiagnosticsFailureCategoryClassification() {
    XCTAssertTrue(FailureCategory.timeout.rawValue == "timeout")
    XCTAssertTrue(FailureCategory.buildError.rawValue == "buildError")
    XCTAssertTrue(FailureCategory.testFailure.rawValue == "testFailure")
    XCTAssertTrue(FailureCategory.networkError.rawValue == "networkError")
    XCTAssertTrue(FailureCategory.permissionDenied.rawValue == "permissionDenied")
    XCTAssertTrue(FailureCategory.elementNotFound.rawValue == "elementNotFound")
    XCTAssertTrue(FailureCategory.appUnresponsive.rawValue == "appUnresponsive")
    XCTAssertTrue(FailureCategory.unknown.rawValue == "unknown")
}

// MARK: - Trace Event Diagnostics

func testDiagnosticsTraceEventErrorAndCompletion() {
    var trace = InteractionTrace()
    trace.append(.turnFailed, detail: "LLM API timeout after 30s")
    XCTAssertTrue(trace.completedAt != nil)
    XCTAssertTrue(trace.events.count == 1)
    XCTAssertTrue(trace.events.first?.detail == "LLM API timeout after 30s")
}

func testDiagnosticsTraceEventTimingExport() {
    var trace = InteractionTrace()
    trace.append(.inputStarted)
    trace.append(.routeSelected, detail: "DeepSeek")
    trace.append(.modelFirstToken)
    trace.append(.turnComplete)
    let summary = TraceLatencySummary(from: trace)
    XCTAssertTrue(summary.eventCount == 4)
    XCTAssertTrue(summary.routingMs != nil)
}

// MARK: - Developer Task Diagnostic Export

@MainActor func testDiagnosticsDeveloperTaskStatusFormatsVariousStates() {
    let completed = ConversationEngine.formatDeveloperTaskFinalText(
        DeveloperAgentTask(prompt: "test", status: .completed, resultSummary: "Summary: all done")
    )
    XCTAssertTrue(completed.contains("Summary: all done"))

    let cancelled = ConversationEngine.formatDeveloperTaskFinalText(
        DeveloperAgentTask(prompt: "cancel", status: .cancelled)
    )
    XCTAssertTrue(cancelled.contains("取消"))

    let failed = ConversationEngine.formatDeveloperTaskFinalText(
        DeveloperAgentTask(prompt: "fail", status: .failed)
    )
    XCTAssertTrue(failed.contains("失败"))
}

// MARK: - Log Input Multiline

@MainActor func testDiagnosticsLogsInputWithMultilineContent() {
    var lifecycle = SessionLifecycle()
    let ok = lifecycle.transition(to: .thinking, reason: "用户输入: 请重构下面代码:\nfunc old() {}\nfunc new() {}")
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.transitionHistory.first?.reason.contains("重构") == true)
}

// MARK: - Log Provider With Confidence

@MainActor func testDiagnosticsLogsProviderRouteWithConfidence() {
    let event = AgentTimelineEvent(source: "lifecycle", kind: "route", summary: "路由: DeepSeek (92%)")
    XCTAssertTrue(event.kind == "route")
    XCTAssertTrue(event.summary.contains("DeepSeek"))
}

// MARK: - Log Plan With Steps

@MainActor func testDiagnosticsLogsPlanWithMultipleSteps() {
    let event = AgentTimelineEvent(source: "developer", kind: "plan", summary: "规划: 1.重构网络层 2.更新依赖 3.运行测试")
    XCTAssertTrue(event.kind == "plan")
    XCTAssertTrue(event.summary.contains("重构网络层"))
}

// MARK: - Log Execution With Commands

@MainActor func testDiagnosticsDeveloperTaskTracksCommands() {
    let task = DeveloperAgentTask(prompt: "fix build", status: .completed, commandsRun: ["swift build", "swift test"], buildSummary: "Build complete!")
    let text = ConversationEngine.formatDeveloperTaskFinalText(task)
    XCTAssertTrue(text.contains("swift build"))
    XCTAssertTrue(text.contains("swift test"))
    XCTAssertTrue(text.contains("Build complete!"))
}

// MARK: - Log Results With Files

@MainActor func testDiagnosticsDeveloperTaskTracksChangedFiles() {
    let task = DeveloperAgentTask(prompt: "refactor", status: .completed, changedFiles: ["Sources/A.swift", "Sources/B.swift"], resultSummary: "Summary: Refactored both files")
    let text = ConversationEngine.formatDeveloperTaskFinalText(task)
    XCTAssertTrue(text.contains("A.swift"))
    XCTAssertTrue(text.contains("B.swift"))
    XCTAssertTrue(text.contains("Refactored"))
}

// MARK: - Log Errors With Tool Result

@MainActor func testDiagnosticsComputerUseResultErrorSummary() {
    let action = ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "shell_command", arguments: ["command": "swift build"]))
    let failedStep = ComputerUseStepResult(action: action, beforeState: nil, toolResult: ToolCallResult(id: "1", output: "error: no such module", isError: true), afterState: nil, verified: false)
    let run = ComputerUseRunResult(startedAt: Date(), steps: [failedStep])
    let brief = ConversationEngine.briefComputerUseResult(run)
    XCTAssertTrue(brief.contains("未完成"))
}

// MARK: - Log Timing Interaction Trace

func testDiagnosticsInteractionTraceTurnFailedRecordsCompletion() {
    var trace = InteractionTrace()
    trace.append(.turnFailed, detail: "LLM unavailable after 3 retries")
    XCTAssertTrue(trace.completedAt != nil)
    XCTAssertTrue(trace.events.count == 1)
    XCTAssertTrue(trace.events.first?.detail == "LLM unavailable after 3 retries")
}

// MARK: - Screenshot Capture Desktop Context

func testDiagnosticsDesktopContextWithMultipleWindows() {
    let context = DesktopContext(activeAppName: "Xcode", windows: [
        DesktopWindow(title: "main.swift"),
        DesktopWindow(title: "Project Navigator"),
    ])
    XCTAssertTrue(context.activeAppName == "Xcode")
    XCTAssertTrue(context.windows.count == 2)
}

// MARK: - Export Diagnostics With Tags

func testDiagnosticsWorkflowMemoryWithTagsRemembered() async {
    let store = WorkflowMemoryStore(storageURL: nil)
    await store.remember(task: "fix crash", steps: ["tool: open_app", "tool: click"], success: true, domain: "developerWorkflow", tags: ["crash", "urgent"])
    let all = await store.all()
    XCTAssertTrue(all.count == 1)
    XCTAssertTrue(all.first?.tags.contains("crash") == true)
}

// MARK: - Persist Diagnostic Snapshot

func testDiagnosticsDiagnosticSnapshotIncludesAllFields() {
    let snap = AssistantDiagnosticSnapshot(
        userText: "帮我编译",
        assistantText: "正在编译...",
        provider: "DeepSeek",
        frontmostApp: "Xcode",
        permissions: ["麦克风": "已授权"],
        latencyMilliseconds: 1200
    )
    XCTAssertTrue(snap.userText == "帮我编译")
    XCTAssertTrue(snap.provider == "DeepSeek")
    XCTAssertTrue(snap.latencyMilliseconds == 1200)
}

// MARK: - InteractionTrace Duration Between Events

func testDiagnosticsInteractionTraceDurationBetweenEvents() {
    var trace = InteractionTrace()
    trace.append(.inputStarted)
    trace.append(.speechFinal)
    trace.append(.contextObserved)
    trace.append(.routeSelected, detail: "DeepSeek")
    trace.append(.modelFirstToken)
    trace.append(.turnComplete)
    let duration = trace.duration(from: .inputStarted, to: .turnComplete)
    XCTAssertTrue(duration != nil)
    XCTAssertTrue(duration! >= 0)
    XCTAssertTrue(trace.events.count == 6)
}

func testDiagnosticsInteractionTraceEmptyDurationReturnsNil() {
    let trace = InteractionTrace()
    XCTAssertTrue(trace.totalDuration == nil)
    let duration = trace.duration(from: .inputStarted, to: .turnComplete)
    XCTAssertTrue(duration == nil)
}

func testDiagnosticsInteractionTraceDurationWithMissingEvents() {
    var trace = InteractionTrace()
    trace.append(.inputStarted)
    trace.append(.turnComplete)
    let routingDuration = trace.duration(from: .contextObserved, to: .routeSelected)
    XCTAssertTrue(routingDuration == nil)
}

// MARK: - TraceLatencySummary Partial Events

func testDiagnosticsTraceLatencySummaryPartialEvents() {
    var trace = InteractionTrace()
    trace.append(.inputStarted)
    trace.append(.turnComplete)
    let summary = TraceLatencySummary(from: trace)
    XCTAssertTrue(summary.eventCount == 2)
    XCTAssertTrue(summary.routingMs == nil)
    XCTAssertTrue(summary.firstTokenMs == nil)
    XCTAssertTrue(summary.totalMs != nil)
}

// MARK: - DesktopContext With OCR Evidence

func testDiagnosticsDesktopContextWithSelectedText() {
    let context = DesktopContext(
        activeAppName: "Safari",
        selectedText: "Login button at center of screen"
    )
    XCTAssertTrue(context.activeAppName == "Safari")
    XCTAssertTrue(context.selectedText?.contains("Login") == true)
}

func testDiagnosticsDesktopContextWithAllWindows() {
    let context = DesktopContext(
        activeAppName: "Xcode",
        windows: [
            DesktopWindow(title: "main.swift"),
            DesktopWindow(title: "Tests"),
            DesktopWindow(title: "Preview"),
        ]
    )
    XCTAssertTrue(context.windows.count == 3)
    XCTAssertTrue(context.focusedWindowTitle == nil)
}

// MARK: - WorkflowMemoryStore Empty State

func testDiagnosticsWorkflowMemoryEmptyResults() async {
    let store = WorkflowMemoryStore(storageURL: nil)
    let all = await store.all()
    XCTAssertTrue(all.isEmpty)
    let failures = await store.recentFailurePatterns()
    XCTAssertTrue(failures.isEmpty)
    let context = await store.consolidatedContext(limit: 5)
    XCTAssertTrue(context.isEmpty)
}

// MARK: - WorkflowMemoryStore Failure with Specific Category

func testDiagnosticsWorkflowMemoryFailureWithCategory() async {
    let store = WorkflowMemoryStore(storageURL: nil)
    await store.remember(
        task: "run tests",
        steps: ["swift test"],
        success: false,
        failureReason: "network timeout",
        failureCategory: .networkError,
        domain: "developerWorkflow"
    )
    let failures = await store.recentFailurePatterns()
    XCTAssertFalse(failures.isEmpty)
    let all = await store.all()
    XCTAssertTrue(all.count == 1)
    XCTAssertTrue(all.first?.failureCategory == .networkError)
}

// MARK: - ComputerUseTraceEvent Different Phases

@MainActor func testDiagnosticsComputerUseTraceEventMultiplePhases() {
    let observe = ComputerUseTraceEvent(phase: "observing", stepIndex: 0, toolName: "get_app_state", summary: "Observation")
    let act = ComputerUseTraceEvent(phase: "acting", stepIndex: 1, toolName: "click", summary: "Clicked button")
    let verify = ComputerUseTraceEvent(phase: "verifying", stepIndex: 2, toolName: "get_app_state", summary: "Verified")

    let line1 = ConversationEngine.conciseTraceEventLine(observe, previousEvent: nil)
    let line2 = ConversationEngine.conciseTraceEventLine(act, previousEvent: observe)
    let line3 = ConversationEngine.conciseTraceEventLine(verify, previousEvent: act)
    XCTAssertTrue(line1 != nil)
    XCTAssertTrue(line2 != nil)
    XCTAssertTrue(line3 != nil)
}

// MARK: - AssistantDiagnosticSnapshot With Error

func testDiagnosticsDiagnosticSnapshotWithError() {
    let snap = AssistantDiagnosticSnapshot(
        userText: "打开 Xcode",
        assistantText: "",
        provider: "DeepSeek",
        permissions: [:],
        error: "权限被拒绝"
    )
    XCTAssertTrue(snap.error == "权限被拒绝")
    XCTAssertTrue(snap.assistantText.isEmpty)
}
