import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

public actor DeveloperLoop {
    public enum Phase: String, Sendable { case planning, building, fixing, testing, verifying, deploying, restarting, summarizing, completed, failed }

    public struct LoopState: Sendable {
        public var phase: Phase = .planning
        public var retryCount: Int = 0
        public var buildErrors: [BuildDiagnostic] = []
        public var testFailures: [String] = []
        public var fileChanges: [ClaudeCodeStructuredResult.FileChange] = []
        public var allOutput: String = ""
        public var lastPatchSummary: String?

        public var isTerminal: Bool { phase == .completed || phase == .failed }
    }

    private let bridge: ClaudeCodeBridge
    private let shell: ShellExecutor
    private let maxRetries: Int
    private var state = LoopState()

    public init(bridge: ClaudeCodeBridge = ClaudeCodeBridge(), shell: ShellExecutor = ShellExecutor(), maxRetries: Int = 3) {
        self.bridge = bridge
        self.shell = shell
        self.maxRetries = maxRetries
    }

    public func currentState() -> LoopState { state }

    public func run(prompt: String, cwd: String?) -> AsyncStream<DeveloperLoopEvent> {
        let (stream, continuation) = AsyncStream<DeveloperLoopEvent>.makeStream()
        let task = Task { [weak self] in
            await self?.executeLoop(prompt: prompt, cwd: cwd, continuation: continuation)
            continuation.finish()
        }
        continuation.onTermination = { @Sendable _ in task.cancel() }
        return stream
    }

    public func runWithDeploy(prompt: String, cwd: String?) -> AsyncStream<DeveloperLoopEvent> {
        let (stream, continuation) = AsyncStream<DeveloperLoopEvent>.makeStream()
        let task = Task { [weak self] in
            await self?.executeLoop(prompt: prompt, cwd: cwd, continuation: continuation, autoDeploy: true)
            continuation.finish()
        }
        continuation.onTermination = { @Sendable _ in task.cancel() }
        return stream
    }

    private func executeLoop(prompt: String, cwd: String?, continuation: AsyncStream<DeveloperLoopEvent>.Continuation, autoDeploy: Bool = false) async {
        state = LoopState()

        // Phase 0: Git safe-checkpoint before any modifications
        if autoDeploy, let cwd {
            let hasGit = (try? await shell.execute("git rev-parse --git-dir", cwd: cwd, timeout: 5))?.isSuccess == true
            if hasGit {
                yield(continuation, .phaseChange(.planning))
                let branchName = "auto-improve-\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-"))"
                _ = try? await shell.execute("git stash", cwd: cwd, timeout: 10)
                _ = try? await shell.execute("git checkout -b \(branchName)", cwd: cwd, timeout: 10)
                yield(continuation, .token("[Git] 已创建分支: \(branchName)\n"))
            }
        }

        // Phase 1: Planning — run Claude Code with initial prompt
        await transition(to: .planning, continuation: continuation)
        let planResult = await runClaudeCode(prompt: prompt, cwd: cwd, continuation: continuation)
        state.allOutput += planResult.summary
        state.fileChanges = planResult.fileChanges
        capState()

        // Phase 2: Build + Fix loop
        await transition(to: .building, continuation: continuation)
        var buildResult = try? await shell.execute("swift build", cwd: cwd, timeout: 120)

        while let br = buildResult, !br.isSuccess, state.retryCount < maxRetries {
            let diagnostics = XcodeDriver.parseBuildDiagnostics(from: br.stdout + "\n" + br.stderr)
            state.buildErrors = diagnostics.filter { $0.severity == .error }
            guard !state.buildErrors.isEmpty else { break }

            yield(continuation, .buildFailed(errors: state.buildErrors.map(\.message)))
            await transition(to: .fixing, continuation: continuation)

            let fixPrompt = Self.buildFixPrompt(errors: state.buildErrors, originalPrompt: prompt)
            state.retryCount += 1
            let fixResult = await runClaudeCode(prompt: fixPrompt, cwd: cwd, continuation: continuation)
            state.allOutput += "\n[修复 #\(state.retryCount)]\n" + fixResult.summary
            state.fileChanges.append(contentsOf: fixResult.fileChanges)
            capState()
            state.lastPatchSummary = fixResult.summary

            yield(continuation, .patchApplied(summary: fixResult.summary))
            await transition(to: .building, continuation: continuation)
            buildResult = try? await shell.execute("swift build", cwd: cwd, timeout: 120)
        }

        if let br = buildResult, !br.isSuccess {
            yield(continuation, .loopExhausted(reason: "构建在 \(maxRetries) 次重试后仍失败"))
            await transition(to: .failed, continuation: continuation)
            return
        }

        if buildResult?.isSuccess == true {
            yield(continuation, .buildSucceeded)
        }

        // Phase 3: Test + Fix loop
        await transition(to: .testing, continuation: continuation)
        var testResult = try? await shell.execute("swift test", cwd: cwd, timeout: 300)

        while let tr = testResult, !tr.isSuccess, state.retryCount < maxRetries {
            let failures = Self.extractTestFailures(from: tr.stdout + "\n" + tr.stderr)
            state.testFailures = failures
            guard !failures.isEmpty else { break }

            yield(continuation, .testFailed(failures: failures))
            await transition(to: .fixing, continuation: continuation)

            let fixPrompt = Self.buildTestFixPrompt(failures: failures, fileChanges: state.fileChanges)
            state.retryCount += 1
            let fixResult = await runClaudeCode(prompt: fixPrompt, cwd: cwd, continuation: continuation)
            state.allOutput += "\n[测试修复 #\(state.retryCount)]\n" + fixResult.summary
            state.fileChanges.append(contentsOf: fixResult.fileChanges)
            capState()
            state.lastPatchSummary = fixResult.summary

            yield(continuation, .patchApplied(summary: fixResult.summary))

            // Rebuild before retesting
            await transition(to: .building, continuation: continuation)
            let rebuildResult = try? await shell.execute("swift build", cwd: cwd, timeout: 120)
            if let rb = rebuildResult, !rb.isSuccess {
                yield(continuation, .buildFailed(errors: ["测试修复后构建失败"]))
                await transition(to: .failed, continuation: continuation)
                return
            }

            await transition(to: .testing, continuation: continuation)
            testResult = try? await shell.execute("swift test", cwd: cwd, timeout: 300)
        }

        if let tr = testResult, !tr.isSuccess {
            yield(continuation, .loopExhausted(reason: "测试在 \(maxRetries) 次重试后仍失败"))
            await transition(to: .failed, continuation: continuation)
            return
        }

        // Phase 4: Verify
        await transition(to: .verifying, continuation: continuation)
        let finalBuild = try? await shell.execute("swift build", cwd: cwd, timeout: 120)
        yield(continuation, .verificationResult(buildPassed: finalBuild?.isSuccess == true))

        // Phase 5: Auto-deploy if enabled
        if autoDeploy, finalBuild?.isSuccess == true, let cwd {
            await transition(to: .deploying, continuation: continuation)
            yield(continuation, .token("[部署] 正在部署新版本...\n"))

            if await Self.deployBinary(cwd: cwd, shell: shell) {
                yield(continuation, .token("[部署] App bundle 已更新\n"))
                await transition(to: .restarting, continuation: continuation)
                yield(continuation, .token("[重启] 正在重启应用...\n"))

                let appPath = "\(cwd)/RenJistroly.app"
                _ = try? await shell.execute("open \"\(appPath)\"", cwd: cwd, timeout: 10)
                yield(continuation, .completed(summary: "部署完成，应用已重启"))
                await transition(to: .completed, continuation: continuation)
                return
            } else {
                yield(continuation, .token("[部署] 未找到构建产物，跳过自动部署\n"))
            }
        }

        await transition(to: .summarizing, continuation: continuation)
        let summary = Self.buildSummary(
            fileChanges: state.fileChanges, retryCount: state.retryCount, allOutput: state.allOutput
        )
        yield(continuation, .completed(summary: summary))

        await transition(to: .completed, continuation: continuation)
    }

    // MARK: - Helpers

    private func runClaudeCode(prompt: String, cwd: String?, continuation: AsyncStream<DeveloperLoopEvent>.Continuation) async -> ClaudeCodeStructuredResult {
        var textParts: [String] = []
        var fileChanges: [ClaudeCodeStructuredResult.FileChange] = []
        var commandsRun: [String] = []
        var buildResults: [BuildResult] = []
        var testResults: [TestResult] = []
        var errorMessage: String?

        let stream = await bridge.runStructured(prompt: prompt, cwd: cwd)
        for await event in stream {
            switch event {
            case .assistantText(let t):
                textParts.append(t)
                fileChanges.append(contentsOf: ClaudeCodeBridge.extractFileChanges(from: t))
                commandsRun.append(contentsOf: ClaudeCodeBridge.extractCommands(from: t))
                continuation.yield(.token(t))
                await AgentEventBus.shared.publish(.code(.claudeCodeToken(t)))
            case .toolUse(_, let name, let args):
                continuation.yield(.toolCall(name: name))
                await AgentEventBus.shared.publish(.code(.claudeCodeToolCall(toolName: name)))
                if name == "write_file" || name == "Write" {
                    if let path = args["file_path"] ?? args["path"] {
                        fileChanges.append(.init(path: path, kind: .modified))
                    }
                }
                if name == "run_shell_command" || name == "Bash" {
                    if let cmd = args["command"] { commandsRun.append(cmd) }
                }
            case .toolResult(_, let name, let output, let isError):
                if isError { continuation.yield(.toolError(name: name, error: output)) }
                if name == "swift_build" || name == "SwiftBuild" {
                    let diagnostics = XcodeDriver.parseBuildDiagnostics(from: output)
                    buildResults = [BuildResult(
                        success: !isError && diagnostics.allSatisfy({ $0.severity != .error }),
                        errors: diagnostics.filter { $0.severity == .error },
                        warnings: diagnostics.filter { $0.severity == .warning },
                        rawOutput: output
                    )]
                }
                if name == "swift_test" || name == "SwiftTest" {
                    testResults = [TestResult(
                        success: !isError,
                        failures: isError ? [TestFailure(testName: "test", message: output)] : []
                    )]
                }
            case .error(let e):
                errorMessage = e
                continuation.yield(.llmError(e))
            case .result(let r):
                textParts.append(r)
            case .text(let t):
                textParts.append(t)
                fileChanges.append(contentsOf: ClaudeCodeBridge.extractFileChanges(from: t))
            case .userMessage, .initMessage, .batch:
                break
            }
        }

        return ClaudeCodeStructuredResult(
            summary: textParts.joined(separator: "\n"),
            fileChanges: fileChanges,
            commandsRun: commandsRun,
            buildResults: buildResults,
            testResults: testResults,
            errorMessage: errorMessage
        )
    }

    private func transition(to phase: Phase, continuation: AsyncStream<DeveloperLoopEvent>.Continuation) async {
        state.phase = phase
        continuation.yield(.phaseChange(phase))
        switch phase {
        case .planning:
            await AgentEventBus.shared.publish(.lifecycle(.planningStarted(goal: "开始开发闭环")))
        case .building:
            await AgentEventBus.shared.publish(.code(.buildStarted(target: nil)))
        case .fixing:
            await AgentEventBus.shared.publish(.lifecycle(.recoveringStarted(action: "修复编译/测试错误", strategy: "Claude Code 自动补丁")))
        case .testing:
            await AgentEventBus.shared.publish(.code(.testStarted(filter: nil)))
        case .verifying:
            await AgentEventBus.shared.publish(.lifecycle(.verifyingStarted(action: "最终验证")))
        case .summarizing:
            await AgentEventBus.shared.publish(.code(.claudeCodeCompleted(summary: "开发闭环完成")))
        case .deploying:
            await AgentEventBus.shared.publish(.code(.buildCompleted(exitCode: 0, errorCount: 0, warningCount: 0)))
        case .restarting:
            break
        case .completed, .failed:
            break
        }
    }

    private func yield(_ c: AsyncStream<DeveloperLoopEvent>.Continuation, _ event: DeveloperLoopEvent) {
        c.yield(event)
    }

    private func capState() {
        if state.allOutput.count > 50000 {
            state.allOutput = String(state.allOutput.suffix(30000))
        }
        if state.fileChanges.count > 200 {
            state.fileChanges.removeFirst(state.fileChanges.count - 200)
        }
    }

    // MARK: - Static helpers

    // Phase 5: Deploy
    private static func deployBinary(cwd: String, shell: ShellExecutor) async -> Bool {
        let findCmd = """
        find \(cwd)/.build -name "RenJistroly" -type f -perm +111 2>/dev/null | head -1
        """
        guard let result = try? await shell.execute(findCmd, cwd: cwd, timeout: 10),
              let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty else {
            return false
        }
        let appPath = "\(cwd)/RenJistroly.app"
        let copyCmd = """
        cp -f "\(path)" "\(appPath)/Contents/MacOS/RenJistroly" && \
        if [ -f "\(cwd)/Resources/entitlements.plist" ]; then \
          codesign --force --sign - --identifier com.renjistroly.app --entitlements "\(cwd)/Resources/entitlements.plist" "\(appPath)"; \
        else \
          codesign --force --sign - --identifier com.renjistroly.app "\(appPath)"; \
        fi
        """
        return (try? await shell.execute(copyCmd, cwd: cwd, timeout: 30))?.isSuccess == true
    }

    static func buildFixPrompt(errors: [BuildDiagnostic], originalPrompt: String) -> String {
        let errorList = errors.map { d in
            let path = d.filePath ?? "unknown"
            let line = d.line.map(String.init) ?? "?"
            return "- \(path):\(line): \(d.message)"
        }.joined(separator: "\n")
        return """
        The following Swift build errors occurred after implementing the changes for: "\(originalPrompt)"

        \(errorList)

        Please fix ALL the compilation errors above. Make minimal, targeted edits. Do NOT refactor or change unrelated code. Only fix what's broken.
        """
    }

    static func buildTestFixPrompt(failures: [String], fileChanges: [ClaudeCodeStructuredResult.FileChange]) -> String {
        let changedFiles = fileChanges.map(\.path).joined(separator: ", ")
        let failureList = failures.joined(separator: "\n")
        return """
        The following test failures occurred. The recently changed files are: \(changedFiles)

        \(failureList)

        Please fix the code to make all tests pass. Focus on the recently changed files. Make minimal, targeted edits. Do NOT refactor or change unrelated code.
        """
    }

    static func extractTestFailures(from output: String) -> [String] {
        let lines = output.components(separatedBy: "\n")
        return lines.filter { line in
            line.contains("XCTAssert") || line.contains("failed") || line.contains("error:")
        }
    }

    static func buildSummary(fileChanges: [ClaudeCodeStructuredResult.FileChange], retryCount: Int, allOutput: String) -> String {
        var parts: [String] = []
        if !fileChanges.isEmpty {
            let created = fileChanges.filter { $0.kind == .created }.count
            let modified = fileChanges.filter { $0.kind == .modified }.count
            parts.append("文件变更: \(created) 新建, \(modified) 修改")
        }
        if retryCount > 0 {
            parts.append("自动修复 \(retryCount) 次后通过")
        } else {
            parts.append("一次性通过构建和测试")
        }
        return parts.joined(separator: "，")
    }
}

// MARK: - Loop Event

public enum DeveloperLoopEvent: Sendable {
    case phaseChange(DeveloperLoop.Phase)
    case token(String)
    case toolCall(name: String)
    case toolError(name: String, error: String)
    case llmError(String)
    case buildFailed(errors: [String])
    case buildSucceeded
    case testFailed(failures: [String])
    case testSucceeded
    case patchApplied(summary: String)
    case verificationResult(buildPassed: Bool)
    case loopExhausted(reason: String)
    case completed(summary: String)
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
