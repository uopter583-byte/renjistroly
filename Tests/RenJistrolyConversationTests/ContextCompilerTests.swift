import Foundation
import XCTest
@testable import RenJistrolyConversation
import RenJistrolyModels

@MainActor
func testBuildWorkflowMemoryContextIncludesSuccessAndFailureDetails() {
    let compiler = ContextCompiler()
    let memories = [
        TaskMemory(
            task: "打开 Safari 搜索文档",
            steps: ["route: browser", "safari_search"],
            success: true,
            learnedWorkflow: "route: browser -> safari_search"
        ),
        TaskMemory(
            task: "运行测试并修复失败",
            steps: ["route: code", "terminal_run", "Claude Code task"],
            success: false,
            failureReason: "swift test 失败，存在 snapshot mismatch"
        )
    ]

    let context = compiler.buildWorkflowMemoryContext(memories: memories)

    XCTAssertTrue(context.contains("任务: 运行测试并修复失败"))
    XCTAssertTrue(context.contains("状态: 失败"))
    XCTAssertTrue(context.contains("失败原因: swift test 失败"))
    XCTAssertTrue(context.contains("任务: 打开 Safari 搜索文档"))
    XCTAssertTrue(context.contains("沉淀流程: route: browser -> safari_search"))
}

@MainActor
func testCompileSystemPromptEmbedsWorkflowMemories() {
    let compiler = ContextCompiler()
    let prompt = compiler.compileSystemPrompt(
        context: nil,
        workflowMemories: [
            TaskMemory(
                task: "查找 Finder 文件",
                steps: ["route: fileSystem", "finder_search"],
                success: true,
                learnedWorkflow: "route: fileSystem -> finder_search"
            )
        ]
    )

    XCTAssertTrue(prompt.contains("相关工作流记忆:"))
    XCTAssertTrue(prompt.contains("任务: 查找 Finder 文件"))
    XCTAssertTrue(prompt.contains("沉淀流程: route: fileSystem -> finder_search"))
}

@MainActor
func testConciseTraceEventLineDeduplicatesRepeatedPhase() {
    let first = ComputerUseTraceEvent(
        phase: "acting",
        stepIndex: 0,
        toolName: "click",
        summary: "执行工具动作"
    )
    let duplicate = ComputerUseTraceEvent(
        phase: "acting",
        stepIndex: 0,
        toolName: "click",
        summary: "执行工具动作"
    )
    let verifying = ComputerUseTraceEvent(
        phase: "verifying",
        stepIndex: 0,
        toolName: "click",
        summary: "验证通过"
    )

    XCTAssertTrue(ConversationEngine.conciseTraceEventLine(first, previousEvent: nil) == "第1步执行 click\n")
    XCTAssertTrue(ConversationEngine.conciseTraceEventLine(duplicate, previousEvent: first) == nil)
    XCTAssertTrue(ConversationEngine.conciseTraceEventLine(verifying, previousEvent: first) == "第1步检查结果\n")
}

@MainActor
func testBriefComputerUseResultSummarizesCompletionAndFailure() {
    let action = ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:]))
    let successStep = ComputerUseStepResult(
        action: action,
        beforeState: nil,
        toolResult: ToolCallResult(id: "1", output: "ok"),
        afterState: nil,
        verified: true,
        recoveryAttempted: true,
        recoverySummary: "重新观察 UI 快照后按 stableID 重定位元素并重试"
    )
    let failedStep = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "2", name: "open_app", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "2", output: "执行失败: app not found", isError: true),
        afterState: nil,
        verified: false
    )

    let successText = ConversationEngine.briefComputerUseResult(
        ComputerUseRunResult(startedAt: Date(), steps: [successStep])
    )
    let failureText = ConversationEngine.briefComputerUseResult(
        ComputerUseRunResult(startedAt: Date(), steps: [failedStep])
    )

    XCTAssertTrue(successText.contains("已完成，共 1 步"))
    XCTAssertTrue(successText.contains("恢复 1 次"))
    XCTAssertTrue(failureText.contains("未完成，停在 open_app"))
}

@MainActor
func testFormatDeveloperTaskFinalTextPrefersStructuredSummary() {
    let task = DeveloperAgentTask(
        prompt: "fix the failing tests",
        status: .completed,
        output: "Summary: Fixed the failing tests.\nBuild complete! (0.12s)\nTest run with 4 tests passed after 0.10 seconds.",
        changedFiles: ["Sources/App.swift", "Tests/AppTests.swift"],
        commandsRun: ["swift test"],
        buildSummary: "Build complete! (0.12s)",
        testSummary: "Test run with 4 tests passed after 0.10 seconds.",
        resultSummary: "Summary: Fixed the failing tests."
    )

    let text = ConversationEngine.formatDeveloperTaskFinalText(task)

    XCTAssertTrue(text.contains("Summary: Fixed the failing tests."))
    XCTAssertTrue(text.contains("构建: Build complete! (0.12s)"))
    XCTAssertTrue(text.contains("测试: Test run with 4 tests passed after 0.10 seconds."))
    XCTAssertTrue(text.contains("变更文件: Sources/App.swift, Tests/AppTests.swift"))
    XCTAssertTrue(text.contains("执行命令: swift test"))
    XCTAssertTrue(text.contains("原始输出:"))
}

@MainActor
func testFormatDeveloperTaskFinalTextSurfacesPendingApproval() {
    let task = DeveloperAgentTask(
        prompt: "edit the repo",
        status: .waitingForConfirmation,
        output: "Needs approval before editing files",
        pendingApprovalSummary: "Needs approval before editing files"
    )

    let text = ConversationEngine.formatDeveloperTaskFinalText(task)

    XCTAssertTrue(text.contains("Claude Code 任务暂停，等待确认后继续。"))
    XCTAssertTrue(text.contains("待批准: Needs approval before editing files"))
}

@MainActor
func testConciseDeveloperTaskUpdateSummarizesNewStructuredProgress() {
    let previous = DeveloperAgentTask(
        prompt: "fix tests",
        status: .running,
        output: "$ swift test",
        commandsRun: ["swift test"]
    )
    let current = DeveloperAgentTask(
        prompt: "fix tests",
        status: .running,
        output: "$ swift test\nBuild complete! (0.12s)",
        changedFiles: ["Sources/App.swift"],
        commandsRun: ["swift test", "git status"],
        buildSummary: "Build complete! (0.12s)"
    )

    let line = ConversationEngine.conciseDeveloperTaskUpdate(current, previous: previous)

    XCTAssertTrue(line?.contains("构建进展: Build complete! (0.12s)") == true)
    XCTAssertTrue(line?.contains("执行命令: git status") == true)
    XCTAssertTrue(line?.contains("变更文件: Sources/App.swift") == true)
}

@MainActor
func testConciseDeveloperTaskUpdateSkipsDuplicateStructuredProgress() {
    let previous = DeveloperAgentTask(
        prompt: "edit repo",
        status: .waitingForConfirmation,
        output: "Needs approval before editing files",
        pendingApprovalSummary: "Needs approval before editing files"
    )
    let current = previous

    let line = ConversationEngine.conciseDeveloperTaskUpdate(current, previous: previous)

    XCTAssertTrue(line == nil)
}

@MainActor
func testBuildRecentAgentTimelineMergesDeveloperAndComputerUseEvents() {
    let developerTask = DeveloperAgentTask(
        prompt: "fix tests",
        events: [
            DeveloperAgentEvent(
                timestamp: Date(timeIntervalSince1970: 20),
                kind: "build",
                summary: "Build complete! (0.12s)"
            )
        ]
    )
    let trace = ComputerUseTraceSnapshot(
        phase: "completed",
        taskText: "打开 Safari",
        routeLabel: "desktop",
        browserPageState: BrowserPageState(
            browserName: "Safari",
            tabTitle: "OpenAI Platform",
            url: "https://platform.openai.com/docs",
            host: "platform.openai.com"
        ),
        run: ComputerUseRunResult(startedAt: Date(timeIntervalSince1970: 10), steps: []),
        events: [
            ComputerUseTraceEvent(
                id: UUID(),
                phase: "acting",
                stepIndex: 0,
                toolName: "open_app",
                summary: "执行打开应用"
            )
        ]
    )

    let timeline = ConversationEngine.buildRecentAgentTimeline(
        developerTasks: [developerTask],
        computerUseTrace: trace
    )

    XCTAssertTrue(timeline.count == 3)
    XCTAssertTrue(timeline.contains(where: { $0.source == "developer" && $0.kind == "build" }))
    XCTAssertTrue(timeline.contains(where: { $0.source == "computer_use" && $0.kind == "acting" }))
    XCTAssertTrue(timeline.contains(where: { $0.source == "computer_use" && $0.kind == "browser_state" }))
}

@MainActor
func testBuildRecentAgentTimelineIncludesBrowserStateAndRecoveryReason() {
    let failedStep = ComputerUseStepResult(
        action: ComputerUseAction(
            toolCall: ToolCallRequest(id: "browser", name: "open_url", arguments: ["url": "https://platform.openai.com/docs"]),
            verificationGoal: VerificationGoal(expectedText: "platform.openai.com", expectedApp: "Safari")
        ),
        beforeState: nil,
        toolResult: ToolCallResult(id: "browser", output: "已打开网址"),
        afterState: nil,
        verified: false,
        verificationEvidence: ["当前页面域名是 example.com，未到达目标 platform.openai.com"],
        recoveryAttempted: true,
        recoveryStrategy: "reopenBrowserPage",
        recoverySummary: "当前页面域名是 example.com，未到达目标 platform.openai.com，重新激活浏览器后重试"
    )
    let trace = ComputerUseTraceSnapshot(
        phase: "completed",
        taskText: "打开 OpenAI 文档",
        routeLabel: "browser",
        browserPageState: BrowserPageState(
            browserName: "Safari",
            tabTitle: "Example Domain",
            url: "https://example.com",
            host: "example.com"
        ),
        run: ComputerUseRunResult(startedAt: Date(timeIntervalSince1970: 10), steps: [failedStep]),
        events: []
    )

    let timeline = ConversationEngine.buildRecentAgentTimeline(
        developerTasks: [],
        computerUseTrace: trace
    )

    XCTAssertTrue(timeline.contains(where: { $0.kind == "browser_state" && $0.summary.contains("Safari · example.com") }))
    XCTAssertTrue(timeline.contains(where: { $0.kind == "recovery_reason" && $0.summary.contains("未到达目标 platform.openai.com") }))
}

@MainActor
func testBrowserVerificationGoalUsesHostForOpenURL() {
    let request = ToolCallRequest(
        id: "1",
        name: "open_url",
        arguments: ["url": "https://www.example.com/docs?q=renjistroly"]
    )

    let goal = ConversationEngine.browserVerificationGoal(for: request)

    XCTAssertTrue(goal?.expectedApp == "Safari")
    XCTAssertTrue(goal?.expectedWindowTitle == "example.com")
    XCTAssertTrue(goal?.expectedText == "example.com")
}

@MainActor
func testBrowserVerificationGoalUsesNormalizedQueryForSafariSearch() {
    let request = ToolCallRequest(
        id: "2",
        name: "safari_search",
        arguments: ["query": "RenJistroly macOS agent runtime"]
    )

    let goal = ConversationEngine.browserVerificationGoal(for: request)

    XCTAssertTrue(goal?.expectedApp == "Safari")
    XCTAssertTrue(goal?.expectedText == "RenJistroly macOS agent")
}

@MainActor
func testVerifyTerminalRunForPwdUsesWorkingDirectory() {
    let result = ToolCallResult(id: "pwd", output: "/Users/yoming/RenJistroly")

    let verification = ConversationEngine.verifyTerminalRun(
        command: "pwd",
        cwd: "/Users/yoming/RenJistroly",
        result: result
    )

    XCTAssertTrue(verification.success)
    XCTAssertTrue(verification.summary == "已确认当前目录")
    XCTAssertTrue(verification.steps.contains("verify: pwd matches cwd"))
}

@MainActor
func testVerifyTerminalRunForGitStatusRequiresRecognizedOutput() {
    let ok = ConversationEngine.verifyTerminalRun(
        command: "git status",
        cwd: nil,
        result: ToolCallResult(id: "git", output: "On branch main\nnothing to commit, working tree clean")
    )
    let bad = ConversationEngine.verifyTerminalRun(
        command: "git status",
        cwd: nil,
        result: ToolCallResult(id: "git", output: "mystery output")
    )

    XCTAssertTrue(ok.success)
    XCTAssertTrue(ok.steps.contains("verify: git status output"))
    XCTAssertFalse(bad.success)
    XCTAssertTrue(bad.failureReason == "mystery output")
}

@MainActor
func testVerifyTerminalRunSurfacesFailureReason() {
    let verification = ConversationEngine.verifyTerminalRun(
        command: "swift test",
        cwd: nil,
        result: ToolCallResult(id: "swift", output: "执行失败: timeout", isError: true)
    )

    XCTAssertFalse(verification.success)
    XCTAssertTrue(verification.message.contains("命令执行失败"))
    XCTAssertTrue(verification.failureReason == "执行失败: timeout")
}

@MainActor
func testVerifyFinderToolResultForSearchMatchesQuery() {
    let verification = ConversationEngine.verifyFinderToolResult(
        request: ToolCallRequest(
            id: "finder",
            name: "finder_search",
            arguments: ["query": "Package", "path": "/tmp"]
        ),
        result: ToolCallResult(id: "finder", output: "Package.swift\nREADME.md")
    )

    XCTAssertTrue(verification.success)
    XCTAssertTrue(verification.summary == "已确认 Finder 搜索结果")
    XCTAssertTrue(verification.steps.contains("verify: finder search results match query"))
}

@MainActor
func testVerifyFinderToolResultForSearchDetectsMiss() {
    let verification = ConversationEngine.verifyFinderToolResult(
        request: ToolCallRequest(
            id: "finder",
            name: "finder_search",
            arguments: ["query": "Missing", "path": "/tmp"]
        ),
        result: ToolCallResult(id: "finder", output: "Package.swift\nREADME.md")
    )

    XCTAssertFalse(verification.success)
    XCTAssertTrue(verification.failureReason == "Package.swift\nREADME.md")
}

@MainActor
func testVerifyFinderToolResultForListDirectoryRequiresEntries() {
    let ok = ConversationEngine.verifyFinderToolResult(
        request: ToolCallRequest(id: "ls", name: "list_directory", arguments: ["path": "/tmp"]),
        result: ToolCallResult(id: "ls", output: "Sources\nTests\nPackage.swift")
    )
    let empty = ConversationEngine.verifyFinderToolResult(
        request: ToolCallRequest(id: "ls2", name: "list_directory", arguments: ["path": "/tmp"]),
        result: ToolCallResult(id: "ls2", output: "目录为空")
    )

    XCTAssertTrue(ok.success)
    XCTAssertTrue(ok.steps.contains("verify: directory contains entries"))
    XCTAssertFalse(empty.success)
    XCTAssertTrue(empty.summary == "目录为空或未返回条目")
}

@MainActor
func testVerifyFinderToolResultIncludesFinderStateSummary() {
    let verification = ConversationEngine.verifyFinderToolResult(
        request: ToolCallRequest(id: "ls", name: "list_directory", arguments: ["path": "/Users/yoming/RenJistroly"]),
        result: ToolCallResult(id: "ls", output: "Sources\nTests\nPackage.swift"),
        finderState: FinderWindowState(
            windowTitle: "Workspace",
            currentPath: "/Users/yoming/RenJistroly",
            selectedItems: ["/Users/yoming/RenJistroly/Package.swift"]
        )
    )

    XCTAssertTrue(verification.message.contains("Finder 当前目录: /Users/yoming/RenJistroly"))
    XCTAssertTrue(verification.steps.contains("verify: finder current path matches request"))
    XCTAssertTrue(verification.steps.contains("verify: finder selection observed"))
}

@MainActor
func testVerifyFinderToolResultForOpenPathUsesFinderState() {
    let verification = ConversationEngine.verifyFinderToolResult(
        request: ToolCallRequest(
            id: "open",
            name: "open_path",
            arguments: ["path": "/Users/yoming/RenJistroly/Package.swift"]
        ),
        result: ToolCallResult(id: "open", output: "已在 Finder 打开: /Users/yoming/RenJistroly/Package.swift"),
        finderState: FinderWindowState(
            windowTitle: "Workspace",
            currentPath: "/Users/yoming/RenJistroly",
            selectedItems: ["/Users/yoming/RenJistroly/Package.swift"]
        )
    )

    XCTAssertTrue(verification.success)
    XCTAssertTrue(verification.summary == "已确认 Finder 打开目标路径")
    XCTAssertTrue(verification.steps.contains("verify: finder opened requested path"))
    XCTAssertTrue(verification.steps.contains("verify: finder selection contains requested path"))
}

@MainActor
func testExtractLocalPathSupportsAbsoluteAndTildePaths() {
    let absolute = ConversationEngine.extractLocalPath(from: "请在 Finder 打开 /Users/yoming/RenJistroly/Package.swift")
    let tilde = ConversationEngine.extractLocalPath(from: "open ~/Documents")

    XCTAssertTrue(absolute == "/Users/yoming/RenJistroly/Package.swift")
    XCTAssertTrue(tilde == (NSString(string: "~/Documents").expandingTildeInPath))
}

@MainActor
func testDesktopVerificationGoalUsesAppAndWindowHints() {
    let request = ToolCallRequest(
        id: "desktop",
        name: "open_app",
        arguments: ["app_name": "System Settings"]
    )

    let goal = ConversationEngine.desktopVerificationGoal(
        for: request,
        originalText: "打开系统设置窗口"
    )

    XCTAssertTrue(goal?.expectedApp == "System Settings")
    XCTAssertTrue(goal?.expectedText == "System Settings")
    XCTAssertTrue(goal?.expectedWindowTitle == "Settings")
}
