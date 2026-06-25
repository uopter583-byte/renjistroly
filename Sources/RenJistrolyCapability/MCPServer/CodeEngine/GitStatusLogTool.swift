import Foundation
import RenJistrolyModels

private enum GitCommandError: LocalizedError {
    case failed(arguments: [String], status: Int32, stderr: String)
    case timedOut(arguments: [String], timeout: TimeInterval)

    var errorDescription: String? {
        switch self {
        case let .failed(arguments, status, stderr):
            let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "git \(arguments.joined(separator: " ")) failed with status \(status)"
                + (message.isEmpty ? "" : ": \(message)")
        case let .timedOut(arguments, timeout):
            return "git \(arguments.joined(separator: " ")) timed out after \(timeout)s"
        }
    }
}

// @unchecked Sendable: mutable PipeDataCollector state guarded by NSLock; single execution path
private final class PipeDataCollector: @unchecked Sendable {
    let pipe = Pipe()

    private let lock = NSLock()
    private var data = Data()

    func start() {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self?.append(chunk)
        }
    }

    func stopAndReadString() -> String {
        pipe.fileHandleForReading.readabilityHandler = nil
        let remaining = pipe.fileHandleForReading.availableData
        if !remaining.isEmpty {
            append(remaining)
        }

        lock.lock()
        let collected = data
        lock.unlock()
        return String(data: collected, encoding: .utf8) ?? ""
    }

    private func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }
}

// @unchecked Sendable: PipeDataCollector + CheckedContinuation guarded by NSLock sentinel
private final class GitCommandRunner: @unchecked Sendable {
    private let task: Process
    private let outputCollector: PipeDataCollector
    private let errorCollector: PipeDataCollector
    private let arguments: [String]
    private let timeout: TimeInterval
    private let continuation: CheckedContinuation<String, Error>
    private let lock = NSLock()
    private var didResume = false

    init(
        task: Process,
        outputCollector: PipeDataCollector,
        errorCollector: PipeDataCollector,
        arguments: [String],
        timeout: TimeInterval,
        continuation: CheckedContinuation<String, Error>
    ) {
        self.task = task
        self.outputCollector = outputCollector
        self.errorCollector = errorCollector
        self.arguments = arguments
        self.timeout = timeout
        self.continuation = continuation
    }

    func complete(process: Process) {
        let output = outputCollector.stopAndReadString()
        let stderr = errorCollector.stopAndReadString()

        guard process.terminationStatus == 0 else {
            finish(.failure(GitCommandError.failed(
                arguments: arguments,
                status: process.terminationStatus,
                stderr: stderr
            )))
            return
        }

        finish(.success(output))
    }

    func timeoutIfStillRunning() {
        if task.isRunning {
            task.terminate()
        }
        finish(.failure(GitCommandError.timedOut(arguments: arguments, timeout: timeout)))
    }

    private func finish(_ result: Result<String, Error>) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true

        switch result {
        case let .success(output):
            continuation.resume(returning: output)
        case let .failure(error):
            continuation.resume(throwing: error)
        }
    }
}

private func runGitCommand(
    arguments: [String],
    currentDirectory: String? = nil,
    timeout: TimeInterval = 5
) async throws -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    task.arguments = arguments
    if let currentDirectory {
        task.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
    }

    let outputCollector = PipeDataCollector()
    let errorCollector = PipeDataCollector()
    task.standardOutput = outputCollector.pipe
    task.standardError = errorCollector.pipe
    outputCollector.start()
    errorCollector.start()
    try task.run()

    return try await withCheckedThrowingContinuation { continuation in
        let runner = GitCommandRunner(
            task: task,
            outputCollector: outputCollector,
            errorCollector: errorCollector,
            arguments: arguments,
            timeout: timeout,
            continuation: continuation
        )
        task.terminationHandler = { process in
            runner.complete(process: process)
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
            runner.timeoutIfStillRunning()
        }
    }
}

// MARK: - Git Status Tool

public struct GitStatusTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_status",
        description: "获取 Git 仓库状态",
        parameters: [
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let path = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let output = try await runGitCommand(arguments: ["-C", path, "status", "--short"], currentDirectory: path)
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: "status", result: output))) }
        return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "仓库干净" : output)
    }
}

// MARK: - Git Log Tool

public struct GitLogTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_log",
        description: "获取 Git 提交历史",
        parameters: [
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
            .init(name: "count", type: .string, description: "提交数量，默认 10", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let path = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let count = arguments["count"] ?? "10"
        let output = try await runGitCommand(arguments: ["-C", path, "log", "--oneline", "-\(count)"])
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: "log", result: output))) }
        return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "无提交记录" : output)
    }
}

// MARK: - Git Diff Tool

public struct GitDiffTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_diff",
        description: "获取 Git 差异(diff)，支持 unstaged/staged/指定文件",
        parameters: [
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
            .init(name: "file", type: .string, description: "指定文件路径，为空则全部", required: false),
            .init(name: "staged", type: .string, description: "是否显示暂存区差异：true/false，默认 false", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let path = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let staged = (arguments["staged"] ?? "false").lowercased() == "true"

        var args = ["-C", path, "diff"]
        if staged { args.append("--staged") }
        if let file = arguments["file"], !file.isEmpty {
            args.append("--")
            args.append(file)
        }

        let output = try await runGitCommand(arguments: args)
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: staged ? "diff-staged" : "diff", result: output))) }
        return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "无差异" : output)
    }
}
