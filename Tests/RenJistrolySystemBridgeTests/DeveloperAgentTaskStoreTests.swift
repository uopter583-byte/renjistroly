import Foundation
import RenJistrolyModels
import XCTest
@testable import RenJistrolySystemBridge

private func waitForSettledTask(_ store: DeveloperAgentTaskStore, id: UUID) async -> DeveloperAgentTask? {
    var latest = await store.task(id)
    for _ in 0..<60 where latest?.status == .running || latest?.status == .queued {
        try? await Task.sleep(for: .milliseconds(50))
        latest = await store.task(id)
    }
    return latest
}

func testDeveloperAgentTaskStoreStopMarksTaskCancelled() async {
    let store = DeveloperAgentTaskStore()
    let task = await store.create(prompt: "summarize the repo")

    await store.stop(task.id)
    let stopped = await store.task(task.id)

    XCTAssertTrue(stopped?.status == .cancelled)
    XCTAssertTrue(stopped?.finishedAt != nil)
    XCTAssertTrue(stopped?.events.contains(where: { $0.kind == "status" && $0.summary.contains("取消") }) == true)
}

func testDeveloperAgentTaskStoreRetryIncrementsRetryCount() async {
    let store = DeveloperAgentTaskStore(claude: ClaudeCodeBridge(claudePath: "/tmp/claude-does-not-exist"))
    let task = await store.create(prompt: "run tests")

    await store.retry(task.id)

    let latest = await waitForSettledTask(store, id: task.id)

    XCTAssertTrue(latest?.retryCount == 1)
    XCTAssertTrue(latest?.status == .failed)
    XCTAssertTrue(latest?.output.contains("无法启动 Claude Code") == true)
}

func testDeveloperAgentTaskStoreMarksConfirmationWaitState() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let scriptURL = tempDir.appendingPathComponent("fake-claude")
    let script = """
    #!/bin/sh
    echo "Needs approval before editing files"
    """
    try script.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

    let store = DeveloperAgentTaskStore(claude: ClaudeCodeBridge(claudePath: scriptURL.path))
    let task = await store.create(prompt: "edit the repo", cwd: tempDir.path)
    await store.start(task.id)

    let latest = await waitForSettledTask(store, id: task.id)

    XCTAssertTrue(latest?.status == .waitingForConfirmation)
    XCTAssertTrue(latest?.exitCode == nil)
    XCTAssertTrue(latest?.output.contains("Needs approval") == true)
    XCTAssertTrue(latest?.pendingApprovalSummary == "Needs approval before editing files")
    XCTAssertTrue(latest?.events.contains(where: { $0.kind == "approval" && $0.summary.contains("Needs approval") }) == true)
    XCTAssertTrue(latest?.events.contains(where: { $0.kind == "status" && $0.summary.contains("任务暂停") }) == true)
}

func testDeveloperAgentTaskStoreApproveAndResumeContinuesTask() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let scriptURL = tempDir.appendingPathComponent("fake-claude")
    let script = """
    #!/bin/sh
    marker="$PWD/.approval-granted"
    if [ -f "$marker" ]; then
      echo "Summary: Fixed the failing tests and verified the package."
      echo "Build complete! (0.12s)"
      echo "Test run with 4 tests passed after 0.10 seconds."
    else
      touch "$marker"
      echo "Needs approval before editing files"
    fi
    """
    try script.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

    let store = DeveloperAgentTaskStore(claude: ClaudeCodeBridge(claudePath: scriptURL.path))
    let task = await store.create(prompt: "fix the failing tests", cwd: tempDir.path)
    await store.start(task.id)

    var latest = await waitForSettledTask(store, id: task.id)

    XCTAssertTrue(latest?.status == .waitingForConfirmation)

    await store.approveAndResume(task.id)

    latest = await waitForSettledTask(store, id: task.id)

    XCTAssertTrue(latest?.status == .completed)
    XCTAssertTrue(latest?.retryCount == 1)
    XCTAssertTrue(latest?.resultSummary == "Summary: Fixed the failing tests and verified the package.")
    XCTAssertTrue(latest?.buildSummary == "Build complete! (0.12s)")
    XCTAssertTrue(latest?.testSummary == "Test run with 4 tests passed after 0.10 seconds.")
    XCTAssertTrue(latest?.events.contains(where: { $0.kind == "resume" && $0.summary.contains("继续执行") }) == true)
    XCTAssertTrue(latest?.events.contains(where: { $0.kind == "summary" && $0.summary.contains("Fixed the failing tests") }) == true)
    XCTAssertTrue(latest?.events.contains(where: { $0.kind == "build" && $0.summary.contains("Build complete") }) == true)
    XCTAssertTrue(latest?.events.contains(where: { $0.kind == "test" && $0.summary.contains("4 tests passed") }) == true)
    XCTAssertTrue(latest?.events.contains(where: { $0.kind == "status" && $0.summary.contains("任务完成") }) == true)
}

// MARK: - Pause / Resume

func testDeveloperAgentTaskStorePauseRunningTask() async {
    let store = DeveloperAgentTaskStore()
    let task = await store.create(prompt: "long running task")
    await store.start(task.id)
    await store.pause(task.id)
    let paused = await store.task(task.id)
    XCTAssertTrue(paused?.status == .paused)
    XCTAssertTrue(paused?.events.contains(where: { $0.kind == "paused" && $0.summary.contains("已暂停") }) == true)
}

func testDeveloperAgentTaskStoreResumePausedTask() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let scriptURL = tempDir.appendingPathComponent("fake-claude")
    let script = """
    #!/bin/sh
    echo "Done: task completed successfully."
    echo "Build complete! (0.05s)"
    echo "Test run with 1 tests passed after 0.01 seconds."
    """
    try script.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

    let store = DeveloperAgentTaskStore(claude: ClaudeCodeBridge(claudePath: scriptURL.path))
    let task = await store.create(prompt: "finish the task", cwd: tempDir.path)
    await store.start(task.id)
    await store.pause(task.id)
    let pausedStatus = await store.task(task.id)
    XCTAssertTrue(pausedStatus?.status == .paused)

    await store.resume(task.id)
    let resumed = await waitForSettledTask(store, id: task.id)
    XCTAssertTrue(resumed?.status == .completed)
    XCTAssertTrue(resumed?.events.contains(where: { $0.kind == "resume" && $0.summary.contains("从暂停恢复") }) == true)
}

func testDeveloperAgentTaskStoreResumeCarriesContext() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let scriptURL = tempDir.appendingPathComponent("fake-claude")
    let script = """
    #!/bin/sh
    echo "Previous output line 1"
    echo "Previous output line 2"
    echo "Working on files"
    echo "Summary: All tasks finished."
    echo "Build complete! (0.04s)"
    """
    try script.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

    let store = DeveloperAgentTaskStore(claude: ClaudeCodeBridge(claudePath: scriptURL.path))
    let task = await store.create(prompt: "original task", cwd: tempDir.path)
    await store.start(task.id)
    let running = await waitForSettledTask(store, id: task.id)
    XCTAssertTrue(running?.status == .completed)
    XCTAssertTrue((running?.output ?? "").contains("Previous output") == true)

    await store.pause(task.id)
    await store.resume(task.id)
    let resumed = await waitForSettledTask(store, id: task.id)
    XCTAssertTrue(resumed?.status == .completed)
}

// MARK: - Takeover

func testDeveloperAgentTaskStoreTakeover() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let scriptURL = tempDir.appendingPathComponent("fake-claude")
    let script = """
    #!/bin/sh
    echo "Original task running"
    echo "Build complete! (0.01s)"
    """
    try script.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

    let store = DeveloperAgentTaskStore(claude: ClaudeCodeBridge(claudePath: scriptURL.path))
    let task = await store.create(prompt: "original prompt", cwd: tempDir.path)
    await store.start(task.id)
    // Pause first, then takeover from paused state
    await store.pause(task.id)
    let pausedState = await store.task(task.id)
    XCTAssertTrue(pausedState?.status == .paused)

    await store.takeover(task.id, newPrompt: "new redirected prompt")
    let afterTakeover = await waitForSettledTask(store, id: task.id)
    XCTAssertTrue(afterTakeover?.status == .completed)
    XCTAssertTrue(afterTakeover?.events.contains(where: { $0.kind == "takeover" }) == true)
}

// MARK: - Snapshot

func testDeveloperAgentTaskStoreSnapshot() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    let scriptURL = tempDir.appendingPathComponent("fake-claude")
    let script = """
    #!/bin/sh
    echo "Some output from the task"
    echo "Build complete! (0.02s)"
    """
    try script.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

    let store = DeveloperAgentTaskStore(claude: ClaudeCodeBridge(claudePath: scriptURL.path))
    let task = await store.create(prompt: "snapshot test task", cwd: tempDir.path)
    await store.start(task.id)
    _ = await waitForSettledTask(store, id: task.id)

    let snap = await store.snapshot(task.id)
    XCTAssertTrue(snap != nil)
    XCTAssertTrue(snap?.taskID == task.id)
    XCTAssertTrue(snap?.prompt == "snapshot test task")
    XCTAssertTrue(snap?.timelineSummary.contains("snapshot test task") == true)
}

func testDeveloperAgentTaskStorePausedTasksList() async {
    let store = DeveloperAgentTaskStore()
    let t1 = await store.create(prompt: "task one")
    let t2 = await store.create(prompt: "task two")

    await store.start(t1.id)
    await store.start(t2.id)
    await store.pause(t1.id)

    let pausedList = await store.pausedTasks()
    XCTAssertTrue(pausedList.count == 1)
    XCTAssertTrue(pausedList.first?.id == t1.id)
    XCTAssertTrue(pausedList.first?.prompt == "task one")
}

func testDeveloperAgentTaskStoreCannotResumeNonPausedTask() async {
    let store = DeveloperAgentTaskStore()
    let task = await store.create(prompt: "not paused")
    await store.resume(task.id)
    let status = await store.task(task.id)
    XCTAssertTrue(status?.status == .queued)
}

final class DeveloperAgentTaskStoreExternalRunTests: XCTestCase {
    func testBeginExternalRunDoesNotLaunchClaude() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let marker = tempDir.appendingPathComponent("unexpected-launch")
        let scriptURL = tempDir.appendingPathComponent("fake-claude")
        let script = """
        #!/bin/sh
        touch "\(marker.path)"
        echo "unexpected"
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let store = DeveloperAgentTaskStore(claude: ClaudeCodeBridge(claudePath: scriptURL.path))
        let task = await store.create(prompt: "tracked by external loop", cwd: tempDir.path)

        await store.beginExternalRun(task.id)
        try? await Task.sleep(for: .milliseconds(100))
        let latest = await store.task(task.id)

        XCTAssertTrue(latest?.status == .running)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))

        await store.complete(task.id, success: true, summary: "external loop completed")
        let completed = await store.task(task.id)
        XCTAssertTrue(completed?.status == .completed)
        XCTAssertTrue(completed?.output == "external loop completed")

        try? FileManager.default.removeItem(at: tempDir)
    }
}
