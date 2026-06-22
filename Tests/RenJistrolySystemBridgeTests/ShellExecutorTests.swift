import XCTest
@testable import RenJistrolySystemBridge

func testShellExecutorEmptyCommand() async {
    let executor = ShellExecutor()
    do {
        _ = try await executor.execute("")
        XCTFail("应该抛出异常")
    } catch let error as ShellError {
        if case .emptyCommand = error {
            // expected
        } else {
            XCTFail("错误的异常类型")
        }
    } catch {
        XCTFail("错误的异常类型")
    }
}

func testShellExecutorDisallowedCommand() async {
    let executor = ShellExecutor(allowedCommands: ["ls"])
    do {
        _ = try await executor.execute("rm -rf /")
        XCTFail("应该抛出异常")
    } catch let error as ShellError {
        if case .commandNotAllowed = error {
            // expected
        } else {
            XCTFail("错误的异常类型")
        }
    } catch {
        XCTFail("错误的异常类型")
    }
}

func testShellExecutorAllowedCommand() async throws {
    let executor = ShellExecutor(allowedCommands: ["echo"])
    let result = try await executor.execute("echo hello")
    XCTAssertTrue(result.exitCode == 0)
    XCTAssertTrue(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
}

// MARK: - ShellResult

func testShellResultIsSuccess() {
    let success = ShellResult(stdout: "", stderr: "", exitCode: 0)
    let failure = ShellResult(stdout: "", stderr: "error", exitCode: 1)
    XCTAssertTrue(success.isSuccess)
    XCTAssertFalse(failure.isSuccess)
}

func testShellResultFields() {
    let result = ShellResult(stdout: "output", stderr: "error", exitCode: 2)
    XCTAssertTrue(result.stdout == "output")
    XCTAssertTrue(result.stderr == "error")
    XCTAssertTrue(result.exitCode == 2)
}

// MARK: - GitContext

func testGitContextInit() {
    let ctx = GitContext(
        branch: "main",
        remote: "origin",
        hasChanges: true,
        recentCommits: ["abc123 fix bug", "def456 add feature"]
    )
    XCTAssertTrue(ctx.branch == "main")
    XCTAssertTrue(ctx.remote == "origin")
    XCTAssertTrue(ctx.hasChanges == true)
    XCTAssertTrue(ctx.recentCommits.count == 2)
    XCTAssertTrue(ctx.recentCommits[0] == "abc123 fix bug")
}

func testGitContextCleanState() {
    let ctx = GitContext(
        branch: "feature/foo",
        remote: "upstream",
        hasChanges: false,
        recentCommits: []
    )
    XCTAssertFalse(ctx.hasChanges)
    XCTAssertTrue(ctx.recentCommits.isEmpty)
}

// MARK: - ShellError

func testShellErrorEmptyCommand() {
    let error = ShellError.emptyCommand
    if case .emptyCommand = error {
        XCTAssertTrue(true)
    } else {
        XCTFail("unexpected false")
    }
}

func testShellErrorCommandNotAllowed() {
    let error = ShellError.commandNotAllowed("rm")
    if case .commandNotAllowed(let cmd) = error {
        XCTAssertTrue(cmd == "rm")
    } else {
        XCTFail("unexpected false")
    }
}

func testShellErrorTimeout() {
    let error = ShellError.timeout
    if case .timeout = error {
        XCTAssertTrue(true)
    } else {
        XCTFail("unexpected false")
    }
}

func testShellErrorExecutionFailed() {
    let error = ShellError.executionFailed("broken pipe")
    if case .executionFailed(let msg) = error {
        XCTAssertTrue(msg == "broken pipe")
    } else {
        XCTFail("unexpected false")
    }
}

// MARK: - ShellResult hashable

func testShellResultHashable() {
    let a = ShellResult(stdout: "ok", stderr: "", exitCode: 0)
    let b = ShellResult(stdout: "ok", stderr: "", exitCode: 0)
    let c = ShellResult(stdout: "ok", stderr: "", exitCode: 1)
    XCTAssertTrue(a == b)
    XCTAssertTrue(a != c)
}

func testShellExecutorDefaultAllowsGit() async throws {
    let executor = ShellExecutor()
    let result = try await executor.execute("git --version")
    XCTAssertTrue(result.exitCode == 0)
}

func testShellExecutorCustomAllowedCommandsBlocksUnexpected() async {
    let executor = ShellExecutor(allowedCommands: ["swift"])
    do {
        _ = try await executor.execute("git status")
        XCTFail("应该抛出异常")
    } catch {
        XCTAssertTrue(error is ShellError)
    }
}
