import Foundation
import os

public actor ShellExecutor {
    private let allowedCommands: Set<String>
    private let sandboxPaths: [String]

    public init(allowedCommands: Set<String> = defaultAllowedCommands, sandboxPaths: [String] = []) {
        self.allowedCommands = allowedCommands
        self.sandboxPaths = sandboxPaths
    }

    public func execute(_ command: String, cwd: String? = nil, timeout: TimeInterval = 30) async throws -> ShellResult {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw ShellError.emptyCommand }

        let firstWord = String(trimmed.split(separator: " ").first ?? "")
        guard allowedCommands.contains(firstWord) else {
            throw ShellError.commandNotAllowed(firstWord)
        }
        guard !hasUnsafePatterns(trimmed) else {
            throw ShellError.commandNotAllowed("unsafe pattern in: \(trimmed.prefix(60))")
        }

        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.arguments = ["-c", trimmed]
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        if let cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        if !sandboxPaths.isEmpty {
            var env = ProcessInfo.processInfo.environment
            env["HOME"] = sandboxPaths.first
            process.environment = env
        }

        // Bridge Process's synchronous termination callback into async/await,
        // avoiding two problems with the old withThrowingTaskGroup approach:
        //   1. waitUntilExit() blocks a cooperative thread pool thread.
        //   2. A non-Sendable Process object was shared across concurrent child tasks.
        //
        // The done flag (protected by OSAllocatedUnfairLock) ensures the
        // continuation is resumed exactly once: either the process finishes
        // first, or the timeout fires first and terminates it. Whichever
        // path "wins" sets the flag; the other path sees it set and returns.
        let done = OSAllocatedUnfairLock(initialState: false)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ShellResult, Error>) in
            process.terminationHandler = { proc in
                let finishedFirst = done.withLock { alreadyDone in
                    guard !alreadyDone else { return false }
                    alreadyDone = true
                    return true
                }
                guard finishedFirst else { return }

                let out = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let err = errorPipe.fileHandleForReading.readDataToEndOfFile()

                continuation.resume(returning: ShellResult(
                    stdout: String(data: out, encoding: .utf8) ?? "",
                    stderr: String(data: err, encoding: .utf8) ?? "",
                    exitCode: proc.terminationStatus
                ))
            }

            do {
                try process.run()
            } catch {
                done.withLock { alreadyDone in
                    guard !alreadyDone else { return }
                    alreadyDone = true
                    continuation.resume(throwing: error)
                }
                return
            }

            // Timeout: terminate the process. If process finishes first, the
            // terminationHandler already set the flag and this is a no-op.
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                let fired = done.withLock { alreadyDone in
                    guard !alreadyDone else { return false }
                    alreadyDone = true
                    return true
                }
                guard fired else { return }
                process.terminate()
                continuation.resume(throwing: ShellError.timeout)
            }
        }
    }

    private static let allowedGitSubcommands: Set<String> = [
        "status", "log", "diff", "add", "commit", "push", "pull", "fetch",
        "branch", "checkout", "merge", "rebase", "stash", "tag", "remote",
        "rev-parse", "rev-list", "show", "blame", "config", "describe",
        "ls-files", "ls-tree", "cat-file", "for-each-ref", "gc", "reset",
        "restore", "switch", "clean", "mv", "rm", "bisect", "grep",
        "cherry-pick", "revert", "shortlog", "worktree", "submodule",
    ]

    private func requireSafeArg(_ arg: String) throws {
        let dangerousChars = CharacterSet(charactersIn: ";|&`$(){}[]!<>\"'\\\n\r\t")
        guard arg.rangeOfCharacter(from: dangerousChars) == nil else {
            throw ShellError.commandNotAllowed(arg)
        }
    }

    public func gitCommand(_ subcommand: String, in repoPath: String) async throws -> ShellResult {
        try requireSafeArg(repoPath)
        let firstWord = subcommand.split(separator: " ").first.map(String.init) ?? ""
        try requireSafeArg(subcommand)
        guard Self.allowedGitSubcommands.contains(firstWord) else {
            throw ShellError.commandNotAllowed(firstWord)
        }
        return try await execute("git -C \(repoPath) \(subcommand)")
    }

    public func getProjectGitContext(_ projectPath: String) async throws -> GitContext? {
        try requireSafeArg(projectPath)
        async let branch = execute("git -C \(projectPath) rev-parse --abbrev-ref HEAD")
        async let remote = execute("git -C \(projectPath) remote get-url origin 2>/dev/null")
        async let status = execute("git -C \(projectPath) status --porcelain")
        async let recentCommits = execute("git -C \(projectPath) log --oneline -5")

        do {
            let (branchResult, remoteResult, statusResult, commitsResult) = try await (
                branch, remote, status, recentCommits
            )
            return GitContext(
                branch: branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines),
                remote: remoteResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines),
                hasChanges: !statusResult.stdout.isEmpty,
                recentCommits: commitsResult.stdout
                    .split(separator: "\n")
                    .map(String.init)
                    .filter { !$0.isEmpty }
            )
        } catch {
            return nil
        }
    }

    private func hasUnsafePatterns(_ command: String) -> Bool {
        // 反引号 / 命令替换
        if command.contains("`") || command.contains("$(") { return true }
        // 变量展开 ${} 可被用于注入
        if command.contains("${") { return true }
        // 换行符注入：在 -c 参数中嵌入换行可执行任意后续命令
        if command.contains("\n") || command.contains("\r") { return true }
        // 管道到任何 shell / 解释器
        if command.contains("| sh") || command.contains("| bash") || command.contains("| zsh") { return true }
        if command.contains("| python") || command.contains("| node") { return true }
        // 逻辑操作符链：&& 和 || 可串联任意命令
        if command.contains("&&") { return true }
        if command.contains("||") { return true }
        // 多语句分隔：; 分隔多条命令
        if command.contains(";") && !command.contains(";;") {
            let parts = command.split(separator: ";", omittingEmptySubsequences: true)
            if parts.count > 1 { return true }
        }
        // 深度防御：即使绕过 firstWord 检查（通过允许的命令嵌入），也阻止危险操作
        if command.contains("rm -rf") || command.contains("rm -rf ") || command.contains("rm -fr ") { return true }
        if command.contains("sudo ") && !command.contains("\"sudo ") { return true }
        if command.contains("curl ") && (command.contains("|") || command.contains("`") || command.contains("$(")) {
            return true
        }
        return false
    }

    public static let defaultAllowedCommands: Set<String> = [
        "git", "ls", "find", "grep", "cat", "head", "tail", "echo",
        "wc", "sort", "uniq", "xargs", "which", "whereis",
        "swift", "xcodebuild", "xcode-select",
        "npm", "npx", "yarn", "pnpm", "node",
        "python3", "pip3", "python",
        "cargo", "rustup", "rustc",
        "go", "gofmt",
        "brew", "port",
        "make", "cmake",
        "docker", "docker-compose",
        "whoami", "date", "pwd", "env",
        "df", "du", "top", "ps",
    ]
}

public struct ShellResult: Sendable, Hashable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }

    public var isSuccess: Bool { exitCode == 0 }
}

public struct GitContext: Sendable, Hashable {
    public let branch: String
    public let remote: String
    public let hasChanges: Bool
    public let recentCommits: [String]

    public init(branch: String, remote: String, hasChanges: Bool, recentCommits: [String]) {
        self.branch = branch
        self.remote = remote
        self.hasChanges = hasChanges
        self.recentCommits = recentCommits
    }
}

public enum ShellError: Error, LocalizedError, Sendable {
    case emptyCommand
    case commandNotAllowed(String)
    case timeout
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyCommand: "命令内容为空，请输入要执行的命令。"
        case .commandNotAllowed(let cmd): "命令「\(cmd)」不在允许列表中，已阻止执行。"
        case .timeout: "命令执行超时，请检查命令是否需要更长时间。"
        case .executionFailed(let reason): "命令执行失败：\(reason)，请检查后重试。"
        }
    }
}
