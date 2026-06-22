import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyConversation

@MainActor
final class ConversationEngineTests: XCTestCase {

    // MARK: - Terminal verification tests

    func testVerifyTerminalRunError() {
        let result = ToolCallResult(id: "t1", output: "command not found", isError: true)
        let v = ConversationEngine.verifyTerminalRun(command: "foo", cwd: nil, result: result)
        XCTAssertFalse(v.success)
        XCTAssertFalse(v.summary.isEmpty)
        XCTAssertTrue(!v.failureReason!.isEmpty)
    }

    func testVerifyTerminalRunPwdMatchesCwd() {
        let result = ToolCallResult(id: "t1", output: "/Users/test/project")
        let v = ConversationEngine.verifyTerminalRun(command: "pwd", cwd: "/Users/test/project", result: result)
        XCTAssertTrue(v.success)
        XCTAssertTrue(v.summary == "已确认当前目录")
    }

    func testVerifyTerminalRunPwdMissingCwd() {
        let result = ToolCallResult(id: "t1", output: "/other/path")
        let v = ConversationEngine.verifyTerminalRun(command: "pwd", cwd: "/Users/test", result: result)
        XCTAssertFalse(v.success)
    }

    func testVerifyTerminalRunGitStatus() {
        let result = ToolCallResult(id: "t1", output: "On branch main\nnothing to commit")
        let v = ConversationEngine.verifyTerminalRun(command: "git status", cwd: nil, result: result)
        XCTAssertTrue(v.success)
    }

    func testVerifyTerminalRunSwiftBuild() {
        let result = ToolCallResult(id: "t1", output: "Build complete!")
        let v = ConversationEngine.verifyTerminalRun(command: "swift build", cwd: nil, result: result)
        XCTAssertTrue(v.success)
    }

    func testVerifyTerminalRunSwiftTest() {
        let result = ToolCallResult(id: "t1", output: "Test run passed after 5.2 seconds")
        let v = ConversationEngine.verifyTerminalRun(command: "swift test", cwd: nil, result: result)
        XCTAssertTrue(v.success)
    }

    func testVerifyTerminalRunGenericCommand() {
        let result = ToolCallResult(id: "t1", output: "done")
        let v = ConversationEngine.verifyTerminalRun(command: "echo hello", cwd: nil, result: result)
        XCTAssertTrue(v.success)
    }

    func testVerifyTerminalRunEmptyOutput() {
        let result = ToolCallResult(id: "t1", output: "")
        let v = ConversationEngine.verifyTerminalRun(command: "echo", cwd: nil, result: result)
        XCTAssertTrue(v.success)
    }

    func testVerifyTerminalRunErrorEmptyOutput() {
        let result = ToolCallResult(id: "t1", output: "", isError: true)
        let v = ConversationEngine.verifyTerminalRun(command: "bad", cwd: nil, result: result)
        XCTAssertFalse(v.success)
        XCTAssertTrue(v.failureReason == "命令执行失败")
    }

    func testVerifyTerminalRunXcodebuild() {
        let result = ToolCallResult(id: "t1", output: "Build succeeded")
        let v = ConversationEngine.verifyTerminalRun(command: "xcodebuild test", cwd: nil, result: result)
        XCTAssertTrue(v.success)
    }

    func testVerifyTerminalRunGitStatusUntracked() {
        let result = ToolCallResult(id: "t1", output: "Untracked files:\n  new.swift")
        let v = ConversationEngine.verifyTerminalRun(command: "git status", cwd: nil, result: result)
        XCTAssertTrue(v.success)
    }

    // MARK: - Extract local path

    func testExtractLocalPathAbsolute() {
        let path = ConversationEngine.extractLocalPath(from: "open /Users/test/file.swift")
        XCTAssertTrue(path == "/Users/test/file.swift")
    }

    func testExtractLocalPathTilde() {
        let path = ConversationEngine.extractLocalPath(from: "edit ~/Documents/note.txt")
        XCTAssertTrue(path?.hasPrefix("/Users/") == true)
        XCTAssertTrue(path?.hasSuffix("/Documents/note.txt") == true)
    }

    func testExtractLocalPathChineseQuotes() {
        let path = ConversationEngine.extractLocalPath(from: "打开\u{201c}/path/to/file\u{201d}")
        XCTAssertTrue(path == "/path/to/file")
    }

    func testExtractLocalPathNoPath() {
        let path = ConversationEngine.extractLocalPath(from: "just some text without a path")
        XCTAssertTrue(path == nil)
    }

    // MARK: - Normalize path for comparison

    func testNormalizePathStandardizes() {
        let result = ConversationEngine.normalizePathForComparison("/Users/test/../test/project")
        XCTAssertTrue(result == "/Users/test/project")
    }

    func testNormalizePathNil() {
        let result = ConversationEngine.normalizePathForComparison(nil)
        XCTAssertTrue(result == nil)
    }

    func testNormalizePathEmpty() {
        let result = ConversationEngine.normalizePathForComparison("")
        XCTAssertTrue(result == nil)
    }

    func testNormalizePathRemovesTrailingSlash() {
        let result = ConversationEngine.normalizePathForComparison("/Users/test/")
        XCTAssertTrue(result == "/Users/test")
    }

    func testNormalizePathRemovesTrailingSlashFiles() {
        let result = ConversationEngine.normalizePathForComparison("/Users/test/../")
        XCTAssertTrue(result == "/Users")
    }

    // MARK: - Finder verification

    func testVerifyFinderToolResultListDirectory() {
        let result = ToolCallResult(id: "t1", output: "file1.swift\nfile2.swift\nfile3.swift")
        let request = ToolCallRequest(id: "r1", name: "list_directory", arguments: ["path": "/test"])
        let v = ConversationEngine.verifyFinderToolResult(request: request, result: result)
        XCTAssertTrue(v.success)
    }

    func testVerifyFinderToolResultListDirectoryEmpty() {
        let result = ToolCallResult(id: "t1", output: "目录为空")
        let request = ToolCallRequest(id: "r1", name: "list_directory", arguments: ["path": "/test"])
        let v = ConversationEngine.verifyFinderToolResult(request: request, result: result)
        XCTAssertFalse(v.success)
    }

    func testVerifyFinderToolResultError() {
        let result = ToolCallResult(id: "t1", output: "permission denied", isError: true)
        let request = ToolCallRequest(id: "r1", name: "list_directory", arguments: ["path": "/root"])
        let v = ConversationEngine.verifyFinderToolResult(request: request, result: result)
        XCTAssertFalse(v.success)
        XCTAssertTrue(v.summary == "目录读取失败")
    }

    func testVerifyFinderToolResultOpenPath() {
        let result = ToolCallResult(id: "t1", output: "opened /tmp")
        let request = ToolCallRequest(id: "r1", name: "open_path", arguments: ["path": "/tmp"])
        let v = ConversationEngine.verifyFinderToolResult(request: request, result: result)
        XCTAssertFalse(v.success) // No finder state provided, can't verify
    }

    // MARK: - Compact finder state summary

    func testCompactFinderStateSummaryFull() {
        let state = FinderWindowState(
            windowTitle: "Downloads",
            currentPath: "/Users/test/Downloads",
            selectedItems: ["file1.txt", "file2.txt"]
        )
        let summary = ConversationEngine.compactFinderStateSummary(state)
        XCTAssertTrue(summary?.contains("Downloads") == true)
        XCTAssertTrue(summary?.contains("file1.txt") == true)
    }

    func testCompactFinderStateSummaryNil() {
        let summary = ConversationEngine.compactFinderStateSummary(nil)
        XCTAssertTrue(summary == nil)
    }

    // MARK: - Browser verification goal

    func testBrowserVerificationGoalOpenURL() {
        let request = ToolCallRequest(id: "r1", name: "open_url", arguments: ["url": "https://www.example.com/page"])
        let goal = ConversationEngine.browserVerificationGoal(for: request)
        XCTAssertTrue(goal?.expectedText == "example.com")
        XCTAssertTrue(goal?.expectedApp == "Safari")
    }

    func testBrowserVerificationGoalSafariSearch() {
        let request = ToolCallRequest(id: "r1", name: "safari_search", arguments: ["query": "Swift 6  "])
        let goal = ConversationEngine.browserVerificationGoal(for: request)
        XCTAssertTrue(goal?.expectedText == "Swift 6")
        XCTAssertTrue(goal?.expectedApp == "Safari")
    }

    func testBrowserVerificationGoalUnknownTool() {
        let request = ToolCallRequest(id: "r1", name: "unknown_tool", arguments: [:])
        let goal = ConversationEngine.browserVerificationGoal(for: request)
        XCTAssertTrue(goal == nil)
    }

    // MARK: - Desktop verification goal

    func testDesktopVerificationGoalOpenFinder() {
        let request = ToolCallRequest(id: "r1", name: "open_app", arguments: ["app_name": "Finder"])
        let goal = ConversationEngine.desktopVerificationGoal(for: request, originalText: "打开访达")
        XCTAssertTrue(goal?.expectedText == "Finder")
        XCTAssertTrue(goal?.expectedWindowTitle == "Finder")
    }

    func testDesktopVerificationGoalOpenTerminal() {
        let request = ToolCallRequest(id: "r1", name: "open_app", arguments: ["app_name": "Terminal"])
        let goal = ConversationEngine.desktopVerificationGoal(for: request, originalText: "打开终端")
        XCTAssertTrue(goal?.expectedWindowTitle == "Terminal")
    }

    func testDesktopVerificationGoalNotOpenApp() {
        let request = ToolCallRequest(id: "r1", name: "click", arguments: ["x": "10"])
        let goal = ConversationEngine.desktopVerificationGoal(for: request, originalText: "click")
        XCTAssertTrue(goal == nil)
    }

    // Missing browser goal branches

    func testBrowserVerificationGoalOpenURLMissingURL() {
        let request = ToolCallRequest(id: "r1", name: "open_url", arguments: [:])
        let goal = ConversationEngine.browserVerificationGoal(for: request)
        XCTAssertTrue(goal?.expectedApp == "Safari")
        XCTAssertTrue(goal?.expectedText == nil)
    }

    func testBrowserVerificationGoalSafariSearchEmptyQuery() {
        let request = ToolCallRequest(id: "r1", name: "safari_search", arguments: ["query": ""])
        let goal = ConversationEngine.browserVerificationGoal(for: request)
        XCTAssertTrue(goal?.expectedApp == "Safari")
        XCTAssertTrue(goal?.expectedText == nil)
    }

    // Missing desktop goal branches

    func testDesktopVerificationGoalSettingsWindow() {
        let request = ToolCallRequest(id: "r1", name: "open_app", arguments: ["app_name": "System Settings"])
        let goal = ConversationEngine.desktopVerificationGoal(for: request, originalText: "打开设置窗口")
        XCTAssertTrue(goal?.expectedWindowTitle == "Settings")
    }

    func testDesktopVerificationGoalSystemSettings() {
        let request = ToolCallRequest(id: "r1", name: "open_app", arguments: ["app_name": "System Settings"])
        let goal = ConversationEngine.desktopVerificationGoal(for: request, originalText: "打开系统设置")
        XCTAssertTrue(goal?.expectedWindowTitle == "Settings")
    }

    func testDesktopVerificationGoalGenericApp() {
        let request = ToolCallRequest(id: "r1", name: "open_app", arguments: ["app_name": "Music"])
        let goal = ConversationEngine.desktopVerificationGoal(for: request, originalText: "打开音乐")
        XCTAssertTrue(goal?.expectedWindowTitle == nil)
        XCTAssertTrue(goal?.expectedApp == "Music")
    }

    // MARK: - Concise trace event

    func testConciseTraceEventLineObserving() {
        let event = ComputerUseTraceEvent(phase: "observing", stepIndex: 0, toolName: "click", summary: "")
        let line = ConversationEngine.conciseTraceEventLine(event, previousEvent: nil)
        XCTAssertTrue(line?.contains("第1步") == true)
        XCTAssertTrue(line?.contains("观察") == true)
    }

    func testConciseTraceEventLineDuplicatePhaseOmitted() {
        let prev = ComputerUseTraceEvent(phase: "acting", stepIndex: 0, toolName: "click", summary: "")
        let curr = ComputerUseTraceEvent(phase: "acting", stepIndex: 0, toolName: "click", summary: "retry")
        let line = ConversationEngine.conciseTraceEventLine(curr, previousEvent: prev)
        XCTAssertTrue(line == nil)
    }

    func testConciseTraceEventLineActing() {
        let event = ComputerUseTraceEvent(phase: "acting", stepIndex: 2, toolName: "type_text", summary: "")
        let line = ConversationEngine.conciseTraceEventLine(event, previousEvent: nil)
        XCTAssertTrue(line?.contains("第3步") == true)
        XCTAssertTrue(line?.contains("type_text") == true)
    }

    // MARK: - Brief computer use result

    func testBriefComputerUseResultAllSucceeded() {
        let step = ComputerUseStepResult(
            action: ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:])),
            beforeState: nil,
            toolResult: ToolCallResult(id: "1", output: "done"),
            afterState: nil,
            verified: true,
            verificationEvidence: ["clicked"]
        )
        let run = ComputerUseRunResult(startedAt: Date(), steps: [step])
        let result = ConversationEngine.briefComputerUseResult(run)
        XCTAssertTrue(result.contains("已完成"))
        XCTAssertTrue(result.contains("1 步"))
    }

    func testBriefComputerUseResultFailed() {
        let step = ComputerUseStepResult(
            action: ComputerUseAction(toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:])),
            beforeState: nil,
            toolResult: ToolCallResult(id: "1", output: "element not found", isError: true),
            afterState: nil,
            verified: false
        )
        let run = ComputerUseRunResult(startedAt: Date(), steps: [step])
        let result = ConversationEngine.briefComputerUseResult(run)
        XCTAssertTrue(result.contains("未完成"))
    }

    // MARK: - Format developer task final text

    func testFormatDeveloperTaskCompleted() {
        var task = DeveloperAgentTask(prompt: "fix bug", status: .completed, output: "Done fixing the bug")
        task.resultSummary = "Bug resolved in login flow"
        task.changedFiles = ["LoginView.swift"]
        task.commandsRun = ["swift build"]
        let text = ConversationEngine.formatDeveloperTaskFinalText(task)
        XCTAssertTrue(text.contains("Bug resolved"))
        XCTAssertTrue(text.contains("LoginView.swift"))
    }

    func testFormatDeveloperTaskFailed() {
        let task = DeveloperAgentTask(prompt: "fix bug", status: .failed, output: "")
        let text = ConversationEngine.formatDeveloperTaskFinalText(task)
        XCTAssertTrue(text.contains("失败"))
    }

    func testFormatDeveloperTaskWaitingConfirmation() {
        var task = DeveloperAgentTask(prompt: "delete file", status: .waitingForConfirmation, output: "")
        task.pendingApprovalSummary = "Delete production database?"
        let text = ConversationEngine.formatDeveloperTaskFinalText(task)
        XCTAssertTrue(text.contains("等待确认"))
        XCTAssertTrue(text.contains("production"))
    }

    // MARK: - Concise developer task update

    func testConciseDeveloperTaskUpdateNoChanges() {
        var task = DeveloperAgentTask(prompt: "test", status: .running, output: "building...")
        task.buildSummary = "compiling"
        let line = ConversationEngine.conciseDeveloperTaskUpdate(task, previous: task)
        XCTAssertTrue(line == nil)
    }

    func testConciseDeveloperTaskUpdateNewCommand() {
        var task = DeveloperAgentTask(prompt: "test", status: .running, output: "running")
        task.commandsRun = ["swift build"]
        let previous = DeveloperAgentTask(prompt: "test", status: .running, output: "")
        let line = ConversationEngine.conciseDeveloperTaskUpdate(task, previous: previous)
        XCTAssertTrue(line?.contains("swift build") == true)
    }

    // MARK: - Build recent agent timeline

    func testBuildRecentAgentTimelineEmpty() {
        let timeline = ConversationEngine.buildRecentAgentTimeline(developerTasks: [], computerUseTrace: nil)
        XCTAssertTrue(timeline.isEmpty)
    }

    // MARK: - Additional terminal verification

    func testVerifyTerminalRunSwiftTestFailed() {
        let result = ToolCallResult(id: "t1", output: "Tests failed: 2 assertions failed")
        let v = ConversationEngine.verifyTerminalRun(command: "swift test", cwd: nil, result: result)
        XCTAssertFalse(v.success)
    }

    func testVerifyTerminalRunXcodebuildFailed() {
        let result = ToolCallResult(id: "t1", output: "Build failed with 3 errors")
        let v = ConversationEngine.verifyTerminalRun(command: "xcodebuild test", cwd: nil, result: result)
        XCTAssertTrue(v.success)
        XCTAssertTrue(v.summary.contains("已确认"))
    }

    func testVerifyTerminalRunXcodebuildSucceeded() {
        let result = ToolCallResult(id: "t1", output: "** TEST SUCCEEDED **")
        let v = ConversationEngine.verifyTerminalRun(command: "xcodebuild test", cwd: nil, result: result)
        XCTAssertTrue(v.success)
    }

    // MARK: - QuickAction

    func testQuickActionCasesExist() {
        let actions: [QuickAction] = [
            .openApp("Safari"),
            .systemInfo,
            .gitStatus(path: "/tmp"),
            .shell(command: "ls", cwd: nil),
            .swiftBuild(path: nil),
            .swiftTest(path: "/project"),
            .analyzeBuildErrors,
            .analyzeTestFailures,
        ]
        XCTAssertTrue(actions.count == 8)
    }

    func testQuickActionOpenApp() {
        if case .openApp(let name) = QuickAction.openApp("Safari") {
            XCTAssertTrue(name == "Safari")
        } else {
            XCTFail("Expected .openApp")
        }
    }

    func testQuickActionGitStatus() {
        if case .gitStatus(let path) = QuickAction.gitStatus(path: "/repo") {
            XCTAssertTrue(path == "/repo")
        } else {
            XCTFail("Expected .gitStatus")
        }
    }

    func testQuickActionShell() {
        if case .shell(let cmd, let cwd) = QuickAction.shell(command: "make", cwd: "/src") {
            XCTAssertTrue(cmd == "make")
            XCTAssertTrue(cwd == "/src")
        } else {
            XCTFail("Expected .shell")
        }
    }
}
