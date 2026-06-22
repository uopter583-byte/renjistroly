@preconcurrency import Foundation
import RenJistrolyModels

public struct ClaudeAgentTool: MCPTool {
    private let cliPath: String

    public let definition = ToolDefinition(
        name: "claude_agent",
        description: "使用 Claude Code CLI 执行代码库开发任务，例如读代码、改文件、跑测试、总结 diff；不要用于控制 macOS 图形界面",
        parameters: [
            .init(name: "prompt", type: .string, description: "开发任务指令（自然语言）"),
            .init(name: "cwd", type: .string, description: "项目工作目录；为空时使用当前进程目录", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init(cliPath: String = "/opt/homebrew/bin/claude") {
        self.cliPath = cliPath
    }

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let prompt = arguments["prompt"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: prompt", isError: true)
        }

        Task { await AgentEventBus.shared.publish(.code(.claudeCodeStarted(prompt: prompt))) }
        let supportsMaxTurns = await Self.cliSupportsOption(cliPath: cliPath, option: "--max-turns")

        return try await withCheckedThrowingContinuation { cont in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = Self.buildArguments(prompt: prompt, supportsMaxTurns: supportsMaxTurns)
            if let cwd = arguments["cwd"], !cwd.isEmpty {
                process.currentDirectoryURL = URL(fileURLWithPath: cwd)
            }
            process.environment = ProcessInfo.processInfo.environment

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            let timeout = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 60, execute: timeout)

            process.terminationHandler = { proc in
                timeout.cancel()
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let errOutput = String(data: errData, encoding: .utf8) ?? ""

                if proc.terminationStatus == 0 {
                    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { await AgentEventBus.shared.publish(.code(.claudeCodeCompleted(summary: String(trimmed.prefix(100))))) }
                    cont.resume(returning: ToolCallResult(
                        id: UUID().uuidString,
                        output: trimmed.isEmpty ? "Claude Code 已完成" : trimmed
                    ))
                } else {
                    Task { await AgentEventBus.shared.publish(.code(.claudeCodeFailed(error: String(errOutput.prefix(200))))) }
                    cont.resume(returning: ToolCallResult(
                        id: UUID().uuidString,
                        output: "Claude Code 执行失败:\n\(errOutput.prefix(500))",
                        isError: true
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                cont.resume(throwing: error)
            }
        }
    }

    static func buildArguments(prompt: String, supportsMaxTurns: Bool) -> [String] {
        var arguments = [
            "--print", prompt,
            "--output-format", "text",
        ]
        if supportsMaxTurns {
            arguments += ["--max-turns", "3"]
        }
        arguments += [
            "--allowedTools",
            "Read,Write,Edit,Bash(git *),Bash(swift *),Bash(xcodebuild *),Bash(rg *),Bash(ls *),Bash(cat *)",
        ]
        return arguments
    }

    private static func cliSupportsOption(cliPath: String, option: String) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
        process.arguments = ["--help"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let (output, _) = (try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, Int32), Error>) in
            process.terminationHandler = { proc in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: (String(data: data, encoding: .utf8) ?? "", proc.terminationStatus))
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }) ?? ("", 0)
        return output.contains(option)
    }
}
