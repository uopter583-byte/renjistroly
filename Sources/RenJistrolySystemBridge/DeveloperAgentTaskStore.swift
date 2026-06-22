import Foundation
import RenJistrolyModels

public actor DeveloperAgentTaskStore {
    private let claude: ClaudeCodeBridge
    private var tasks: [UUID: DeveloperAgentTask] = [:]
    private var running: [UUID: Task<Void, Never>] = [:]

    public init(claude: ClaudeCodeBridge = ClaudeCodeBridge()) {
        self.claude = claude
    }

    public func create(prompt: String, cwd: String? = nil, dependsOn: [UUID] = []) -> DeveloperAgentTask {
        let blockedBy = dependsOn.filter { tasks[$0]?.status != .completed }
        let task = DeveloperAgentTask(prompt: prompt, cwd: cwd, dependsOn: dependsOn, blockedBy: blockedBy)
        tasks[task.id] = task
        return task
    }

    public func start(_ id: UUID) {
        guard let task = tasks[id], task.blockedBy.isEmpty else { return }
        start(id, promptOverride: nil)
    }

    public func beginExternalRun(_ id: UUID) {
        guard var task = tasks[id], task.status == .queued || task.status == .failed else { return }
        let existingEvents = task.events
        task.status = .running
        task.startedAt = Date()
        task.finishedAt = nil
        task.output = ""
        task.changedFiles = []
        task.commandsRun = []
        task.buildSummary = nil
        task.testSummary = nil
        task.resultSummary = nil
        task.pendingApprovalSummary = nil
        task.events = existingEvents
        task.events.append(DeveloperAgentEvent(kind: "status", summary: "任务由开发闭环接管执行"))
        tasks[id] = task
    }

    public func startAll() {
        for id in tasks.keys where tasks[id]?.status == .queued {
            start(id)
        }
    }

    public func startChain(_ ids: [UUID]) {
        guard let first = ids.first else { return }
        // Wire up sequential dependencies
        for i in 1..<ids.count {
            guard var task = tasks[ids[i]] else { continue }
            let prevID = ids[i - 1]
            if !task.dependsOn.contains(prevID) {
                task.dependsOn.append(prevID)
            }
            if !task.blockedBy.contains(prevID) {
                task.blockedBy.append(prevID)
            }
            tasks[ids[i]] = task
        }
        start(first)
    }

    public func addDependency(_ taskID: UUID, dependsOn dependencyID: UUID) {
        guard var task = tasks[taskID], let dependency = tasks[dependencyID] else { return }
        if !task.dependsOn.contains(dependencyID) {
            task.dependsOn.append(dependencyID)
        }
        if dependency.status != .completed, !task.blockedBy.contains(dependencyID) {
            task.blockedBy.append(dependencyID)
        }
        tasks[taskID] = task
    }

    public func aggregateResults(for ids: [UUID]) -> TaskAggregation {
        let matched = ids.compactMap { tasks[$0] }
        let allOutputs = matched.map { $0.output }.filter { !$0.isEmpty }
        let allFiles = Array(Set(matched.flatMap { $0.changedFiles }))
        let allCommands = Array(Set(matched.flatMap { $0.commandsRun }))
        let summaries = matched.compactMap { $0.resultSummary }
        let failures = matched.filter { $0.status == .failed }
        let successes = matched.filter { $0.status == .completed }

        return TaskAggregation(
            totalTasks: ids.count,
            completed: successes.count,
            failed: failures.count,
            pending: matched.filter { $0.status == .queued || $0.status == .running }.count,
            changedFiles: allFiles,
            commandsRun: allCommands,
            combinedOutput: allOutputs.joined(separator: "\n\n---\n\n"),
            summaries: summaries,
            allSucceeded: failures.isEmpty && successes.count == ids.count
        )
    }

    public func approveAndResume(_ id: UUID) {
        guard var task = tasks[id], task.status == .waitingForConfirmation else { return }
        let previousOutput = task.output
        task.retryCount += 1
        task.status = .queued
        task.startedAt = nil
        task.finishedAt = nil
        task.exitCode = nil
        task.changedFiles = []
        task.commandsRun = []
        task.buildSummary = nil
        task.testSummary = nil
        task.resultSummary = nil
        task.pendingApprovalSummary = nil
        task.events = []
        task.events.append(DeveloperAgentEvent(kind: "resume", summary: "用户已批准，继续执行任务"))
        Task.detached { await AgentEventBus.shared.publish(.lifecycle(.taskResumed(reason: "用户已批准"))) }
        tasks[id] = task

        start(id, promptOverride: approvedContinuationPrompt(originalPrompt: task.prompt, previousOutput: previousOutput))
    }

    private func start(_ id: UUID, promptOverride: String?) {
        guard var task = tasks[id], task.status == .queued || task.status == .failed else { return }
        let runPrompt = promptOverride ?? task.prompt
        let existingEvents = task.events
        task.status = .running
        task.startedAt = Date()
        task.output = ""
        task.changedFiles = []
        task.commandsRun = []
        task.buildSummary = nil
        task.testSummary = nil
        task.resultSummary = nil
        task.pendingApprovalSummary = nil
        task.events = existingEvents
        task.events.append(DeveloperAgentEvent(kind: "status", summary: "任务开始执行"))
        Task.detached { await AgentEventBus.shared.publish(.lifecycle(.actingStarted(action: "developer-task", tool: "claude-code"))) }
        Task.detached { await AgentEventBus.shared.publish(.code(.claudeCodeStarted(prompt: runPrompt))) }
        tasks[id] = task

        running[id] = Task { [claude] in
            var accumulated = ""
            for await chunk in await claude.run(prompt: runPrompt, cwd: task.cwd) {
                accumulated += chunk
                await appendOutput(chunk, to: id)
            }
            await finish(id, output: accumulated)
        }
    }

    public func stop(_ id: UUID) {
        running[id]?.cancel()
        running[id] = nil
        guard var task = tasks[id] else { return }
        task.status = .cancelled
        task.finishedAt = Date()
        task.events.append(DeveloperAgentEvent(kind: "status", summary: "任务已取消"))
        Task.detached { await AgentEventBus.shared.publish(.lifecycle(.actingCompleted(action: "developer-task", success: false))) }
        tasks[id] = task
    }

    public func pause(_ id: UUID) {
        guard var task = tasks[id], task.status == .running else { return }
        running[id]?.cancel()
        running[id] = nil
        task.status = .paused
        task.events.append(DeveloperAgentEvent(kind: "paused", summary: "任务已暂停（可恢复）"))
        Task.detached { await AgentEventBus.shared.publish(.lifecycle(.taskStatusUpdate(summary: "任务已暂停"))) }
        tasks[id] = task
    }

    public func resume(_ id: UUID) {
        guard var task = tasks[id], task.status == .paused else { return }
        let previousOutput = task.output
        let taskPrompt = task.prompt
        task.status = .queued
        task.startedAt = nil
        task.finishedAt = nil
        task.exitCode = nil
        task.events.append(DeveloperAgentEvent(kind: "resume", summary: "从暂停恢复"))
        Task.detached { await AgentEventBus.shared.publish(.lifecycle(.taskResumed(reason: "从暂停恢复: \(taskPrompt)"))) }
        tasks[id] = task

        let continuationPrompt: String
        if !previousOutput.isEmpty {
            let sigLines = significantLines(from: previousOutput).suffix(5)
            let context = sigLines.joined(separator: "\n")
            continuationPrompt = """
            Continue the task you were working on. Your previous output ended with:

            \(context)

            Original task:
            \(task.prompt)

            Pick up where you left off and complete the remaining work.
            """
        } else {
            continuationPrompt = task.prompt
        }

        start(id, promptOverride: continuationPrompt)
    }

    public func takeover(_ id: UUID, newPrompt: String) {
        guard var task = tasks[id], task.status == .running || task.status == .paused else { return }
        if task.status == .running {
            running[id]?.cancel()
            running[id] = nil
        }
        let previousOutput = task.output
        task.status = .queued
        task.startedAt = nil
        task.finishedAt = nil
        task.exitCode = nil
        task.changedFiles = []
        task.commandsRun = []
        task.buildSummary = nil
        task.testSummary = nil
        task.resultSummary = nil
        task.pendingApprovalSummary = nil
        task.events.append(DeveloperAgentEvent(kind: "takeover", summary: "用户接管 → \(newPrompt)"))
        Task.detached { await AgentEventBus.shared.publish(.lifecycle(.taskStatusUpdate(summary: "任务重定向: \(newPrompt)"))) }
        tasks[id] = task

        let takeoverPrompt: String
        if !previousOutput.isEmpty {
            let sigLines = significantLines(from: previousOutput).suffix(3)
            let context = sigLines.joined(separator: "\n")
            takeoverPrompt = """
            Context from previous work:
            \(context)

            New instruction:
            \(newPrompt)
            """
        } else {
            takeoverPrompt = newPrompt
        }

        start(id, promptOverride: takeoverPrompt)
    }

    public func pausedTasks() -> [DeveloperAgentTask] {
        tasks.values.filter { $0.status == .paused }
    }

    public func snapshot(_ id: UUID) -> TaskSnapshot? {
        guard let task = tasks[id] else { return nil }
        return TaskSnapshot(
            taskID: task.id,
            prompt: task.prompt,
            status: task.status,
            outputTail: String(task.output.suffix(2000)),
            eventsTail: Array(task.events.suffix(20)),
            retryCount: task.retryCount,
            capturedAt: Date()
        )
    }

    public struct TaskSnapshot: Codable, Sendable {
        public let taskID: UUID
        public let prompt: String
        public let status: AgentTaskStatus
        public let outputTail: String
        public let eventsTail: [DeveloperAgentEvent]
        public let retryCount: Int
        public let capturedAt: Date

        public var timelineSummary: String {
            let eventSummaries = eventsTail.map { "[\($0.kind)] \($0.summary)" }.joined(separator: "\n  ")
            return "任务: \(prompt)\n状态: \(status.rawValue)\n最近事件:\n  \(eventSummaries)"
        }
    }

    public func retry(_ id: UUID) {
        guard var task = tasks[id] else { return }
        task.retryCount += 1
        task.status = .queued
        task.startedAt = nil
        task.finishedAt = nil
        task.output = ""
        task.exitCode = nil
        task.changedFiles = []
        task.commandsRun = []
        task.buildSummary = nil
        task.testSummary = nil
        task.resultSummary = nil
        task.pendingApprovalSummary = nil
        task.events = []
        task.events.append(DeveloperAgentEvent(kind: "retry", summary: "重新执行任务"))
        let retryAttempt = task.retryCount
        Task.detached { await AgentEventBus.shared.publish(.lifecycle(.taskRetry(attempt: retryAttempt))) }
        tasks[id] = task
        start(id)
    }

    public func task(_ id: UUID) -> DeveloperAgentTask? {
        tasks[id]
    }

    public func allTasks() -> [DeveloperAgentTask] {
        tasks.values.sorted { $0.createdAt > $1.createdAt }
    }

    public func updateOutput(_ id: UUID, _ output: String) {
        guard var task = tasks[id] else { return }
        task.output = output
        tasks[id] = task
    }

    public func complete(_ id: UUID, success: Bool, summary: String) {
        running[id]?.cancel()
        running[id] = nil
        guard var task = tasks[id] else { return }
        let previousTask = task
        task.output = summary
        task.status = success ? .completed : .failed
        task.resultSummary = summary
        task.buildSummary = success ? "构建通过" : "构建失败"
        task.testSummary = success ? "测试通过" : "测试失败"
        task.finishedAt = Date()
        task.events = mergedEvents(for: task, previous: previousTask)
        tasks[id] = task
        if task.status == .completed {
            resolveDependents(of: id)
        }
    }

    private func appendOutput(_ chunk: String, to id: UUID) async {
        guard var task = tasks[id] else { return }
        let previousTask = task
        task.output += chunk
        task.commandsRun = extractCommands(from: task.output)
        task.buildSummary = extractBuildSummary(from: task.output)
        task.testSummary = extractTestSummary(from: task.output)
        task.resultSummary = extractResultSummary(from: task.output)
        task.pendingApprovalSummary = extractPendingApprovalSummary(from: task.output)
        task.changedFiles = await changedFiles(in: task.cwd)
        task.events = mergedEvents(for: task, previous: previousTask)
        tasks[id] = task
    }

    private func finish(_ id: UUID, output: String) async {
        running[id] = nil
        guard var task = tasks[id], task.status == .running else { return }
        let previousTask = task
        task.output = output
        let terminal = terminalStatus(for: output)
        task.status = terminal.status
        task.exitCode = terminal.exitCode
        task.commandsRun = extractCommands(from: output)
        task.buildSummary = extractBuildSummary(from: output)
        task.testSummary = extractTestSummary(from: output)
        task.resultSummary = extractResultSummary(from: output)
        task.pendingApprovalSummary = extractPendingApprovalSummary(from: output)
        task.changedFiles = await changedFiles(in: task.cwd)
        task.events = mergedEvents(for: task, previous: previousTask)
        task.events.append(terminalStatusEvent(for: task, output: output))
        task.finishedAt = Date()
        publishFinishEvent(for: task, output: output)
        tasks[id] = task

        if task.status == .completed || task.status == .cancelled {
            resolveDependents(of: id)
        }
    }

    private func resolveDependents(of completedID: UUID) {
        var readyToStart: [UUID] = []
        for (otherID, var otherTask) in tasks {
            guard otherTask.blockedBy.contains(completedID) else { continue }
            otherTask.blockedBy.removeAll { $0 == completedID }
            tasks[otherID] = otherTask
            if otherTask.blockedBy.isEmpty, otherTask.status == .queued {
                readyToStart.append(otherID)
            }
        }
        for id in readyToStart {
            start(id)
            let prompt = tasks[id]?.prompt ?? ""
            Task.detached { await AgentEventBus.shared.publish(.lifecycle(.taskStatusUpdate(summary: "依赖已满足，自动开始: \(prompt)"))) }
        }
    }

    private func mergedEvents(for task: DeveloperAgentTask, previous: DeveloperAgentTask) -> [DeveloperAgentEvent] {
        var events = previous.events

        if let pending = task.pendingApprovalSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !pending.isEmpty,
           pending != previous.pendingApprovalSummary?.trimmingCharacters(in: .whitespacesAndNewlines) {
            events.append(DeveloperAgentEvent(kind: "approval", summary: pending))
            Task.detached { await AgentEventBus.shared.publish(.lifecycle(.approvalRequired(prompt: pending))) }
        }

        if let summary = task.resultSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !summary.isEmpty,
           summary != previous.resultSummary?.trimmingCharacters(in: .whitespacesAndNewlines) {
            events.append(DeveloperAgentEvent(kind: "summary", summary: summary))
            Task.detached { await AgentEventBus.shared.publish(.code(.taskApproved(summary))) }
        }

        if let build = task.buildSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !build.isEmpty,
           build != previous.buildSummary?.trimmingCharacters(in: .whitespacesAndNewlines) {
            events.append(DeveloperAgentEvent(kind: "build", summary: build))
            Task.detached { await AgentEventBus.shared.publish(.code(.taskEvent(kind: "build", summary: build))) }
        }

        if let test = task.testSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
           !test.isEmpty,
           test != previous.testSummary?.trimmingCharacters(in: .whitespacesAndNewlines) {
            events.append(DeveloperAgentEvent(kind: "test", summary: test))
            Task.detached { await AgentEventBus.shared.publish(.code(.taskEvent(kind: "test", summary: test))) }
        }

        if task.commandsRun.count > previous.commandsRun.count,
           let latestCommand = task.commandsRun.last {
            events.append(DeveloperAgentEvent(kind: "command", summary: latestCommand))
            Task.detached { await AgentEventBus.shared.publish(.code(.commandExecuted(command: latestCommand))) }
            let toolName = latestCommand.split(separator: " ").first.map(String.init) ?? "bash"
            Task.detached { await AgentEventBus.shared.publish(.code(.claudeCodeToolCall(toolName: toolName))) }
        }

        let previousChangedFiles = Set(previous.changedFiles)
        let newChangedFiles = task.changedFiles.filter { !previousChangedFiles.contains($0) }
        for file in newChangedFiles.prefix(3) {
            events.append(DeveloperAgentEvent(kind: "file", summary: file))
            Task.detached { await AgentEventBus.shared.publish(.code(.fileModified(path: file, changeType: "changed"))) }
        }

        return Array(events.suffix(24))
    }

    private func terminalStatusEvent(for task: DeveloperAgentTask, output: String) -> DeveloperAgentEvent {
        let eventSummary: String
        let eventKind: String
        switch task.status {
        case .waitingForConfirmation:
            let summary = task.pendingApprovalSummary?.trimmingCharacters(in: .whitespacesAndNewlines)
            eventSummary = summary.flatMap { $0.isEmpty ? nil : "任务暂停: \($0)" } ?? "任务暂停，等待确认"
            eventKind = "status"
        case .failed:
            let failureLine = significantLines(from: output).first(where: { $0.localizedCaseInsensitiveContains("[错误]") }) ?? "任务执行失败"
            eventSummary = failureLine
            eventKind = "status"
        case .completed:
            eventSummary = "任务完成"
            eventKind = "status"
        case .cancelled:
            eventSummary = "任务已取消"
            eventKind = "status"
        case .paused:
            eventSummary = "任务已暂停"
            eventKind = "status"
        case .queued, .running:
            eventSummary = "任务状态更新"
            eventKind = "status"
        }
        Task.detached { await AgentEventBus.shared.publish(.lifecycle(.taskStatusUpdate(summary: eventSummary))) }
        return DeveloperAgentEvent(kind: eventKind, summary: eventSummary)
    }

    private func publishFinishEvent(for task: DeveloperAgentTask, output: String) {
        switch task.status {
        case .completed:
            let summary = task.resultSummary ?? "任务完成"
            Task.detached { await AgentEventBus.shared.publish(.code(.claudeCodeCompleted(summary: summary))) }
        case .failed:
            let failureLine = significantLines(from: output).first(where: { $0.localizedCaseInsensitiveContains("[错误]") }) ?? "任务执行失败"
            Task.detached { await AgentEventBus.shared.publish(.code(.claudeCodeFailed(error: failureLine))) }
        case .cancelled:
            Task.detached { await AgentEventBus.shared.publish(.code(.claudeCodeFailed(error: "任务已取消"))) }
        case .paused:
            break
        case .waitingForConfirmation, .queued, .running:
            break
        }
    }

    private func terminalStatus(for output: String) -> (status: AgentTaskStatus, exitCode: Int32?) {
        if requiresConfirmation(output) {
            return (.waitingForConfirmation, nil)
        }
        if output.contains("[错误]") {
            return (.failed, 1)
        }
        return (.completed, 0)
    }

    private func requiresConfirmation(_ output: String) -> Bool {
        let normalized = output.lowercased()
        let patterns = [
            "needs approval",
            "needs your approval",
            "awaiting approval",
            "waiting for approval",
            "requires approval",
            "confirm to continue",
            "please confirm",
            "allow this action",
            "permission required",
            "permission needed",
            "requires confirmation",
            "需要确认",
            "等待确认",
            "请确认",
            "需要你的确认",
            "需要批准",
            "等待批准",
        ]
        return patterns.contains { normalized.contains($0) }
    }

    private func approvedContinuationPrompt(originalPrompt: String, previousOutput: String) -> String {
        let trimmedOutput = previousOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedOutput.isEmpty {
            return originalPrompt
        }
        return """
        The user approved the action you requested. Continue the same task and complete it if possible.

        Original task:
        \(originalPrompt)

        Your previous output before approval:
        \(trimmedOutput)
        """
    }

    private func extractCommands(from output: String) -> [String] {
        output
            .split(separator: "\n")
            .compactMap { rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                if line.hasPrefix("$ ") {
                    return String(line.dropFirst(2))
                }
                if line.hasPrefix("> ") {
                    return String(line.dropFirst(2))
                }
                if line.lowercased().hasPrefix("running ") {
                    return line
                }
                return nil
            }
    }

    private func extractBuildSummary(from output: String) -> String? {
        let lines = output.split(separator: "\n").map(String.init)
        if let buildLine = lines.last(where: { $0.localizedCaseInsensitiveContains("build complete") || $0.localizedCaseInsensitiveContains("build failed") }) {
            return buildLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func extractTestSummary(from output: String) -> String? {
        let lines = output.split(separator: "\n").map(String.init)
        if let testLine = lines.last(where: {
            $0.localizedCaseInsensitiveContains("test run with")
                || $0.localizedCaseInsensitiveContains("tests passed")
                || $0.localizedCaseInsensitiveContains("tests failed")
                || $0.localizedCaseInsensitiveContains("executed ")
        }) {
            return testLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func extractResultSummary(from output: String) -> String? {
        let lines = significantLines(from: output)
        let labeledPrefixes = ["summary:", "result:", "done:", "completed:", "updated:", "changed:"]
        if let labeled = lines.first(where: { line in
            let normalized = line.lowercased()
            return labeledPrefixes.contains { normalized.hasPrefix($0) }
        }) {
            return labeled
        }

        if let narrative = lines.first(where: { line in
            let normalized = line.lowercased()
            return !requiresConfirmation(line)
                && !normalized.hasPrefix("[错误]")
                && !normalized.hasPrefix("build complete")
                && !normalized.hasPrefix("build failed")
                && !normalized.hasPrefix("test run with")
                && !normalized.hasPrefix("running ")
                && !line.hasPrefix("$ ")
                && !line.hasPrefix("> ")
        }) {
            return narrative
        }
        return nil
    }

    private func extractPendingApprovalSummary(from output: String) -> String? {
        let lines = significantLines(from: output)
        return lines.first(where: requiresConfirmation)
    }

    private func significantLines(from output: String) -> [String] {
        output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func changedFiles(in cwd: String?) async -> [String] {
        guard let cwd, !cwd.isEmpty else { return [] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", cwd, "status", "--porcelain"]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        let (output, status) = (try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, Int32), Error>) in
            process.terminationHandler = { proc in
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: (String(data: data, encoding: .utf8) ?? "", proc.terminationStatus))
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }) ?? ("", -1)

        Task.detached { await AgentEventBus.shared.publish(.code(.gitOperation(op: "status", result: status == 0 ? "ok" : "failed"))) }
        guard status == 0 else { return [] }
        return output
            .split(separator: "\n")
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.count > 3 else { return nil }
                return String(trimmed.dropFirst(3))
            }
    }
}
