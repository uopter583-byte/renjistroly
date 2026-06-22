import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - Shell Command Tool

public struct ShellCommandTool: MCPTool {
    public let definition = ToolDefinition(
        name: "shell_command",
        description: "执行 Shell 命令",
        parameters: [
            .init(name: "command", type: .string, description: "要执行的命令"),
            .init(name: "cwd", type: .string, description: "工作目录", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let command = arguments["command"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: command", isError: true)
        }

        let cwd = arguments["cwd"]
        let shell = ShellExecutor()
        do {
            let result = try await shell.execute(command, cwd: cwd, timeout: 60)
            var output = result.stdout
            if !result.stderr.isEmpty { output += "\n[stderr]\n\(result.stderr)" }
            if result.exitCode != 0 { output += "\n退出码: \(result.exitCode)" }
            Task { await AgentEventBus.shared.publish(.code(.commandExecuted(command: command))) }
            return ToolCallResult(
                id: UUID().uuidString,
                output: output.isEmpty ? "命令执行完毕" : output,
                isError: result.exitCode != 0
            )
        } catch {
            return ToolCallResult(
                id: UUID().uuidString,
                output: "命令执行失败: \(error.localizedDescription)",
                isError: true
            )
        }
    }
}
