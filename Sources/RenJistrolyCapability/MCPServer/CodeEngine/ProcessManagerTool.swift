import Foundation
import OSLog
import RenJistrolyModels

private func runProcessOutput(executable: String, arguments: [String]) async throws -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: executable)
    task.arguments = arguments
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    try task.run()

    return try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .utility).async {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
        }
    }
}

// MARK: - Process Tool

public struct ProcessTool: MCPTool {
    public let definition = ToolDefinition(
        name: "process",
        description: "进程管理：list(列出匹配进程)、kill(终止进程)、info(进程详情)",
        parameters: [
            .init(name: "action", type: .string, description: "list/kill/info"),
            .init(name: "name", type: .string, description: "进程名匹配（list/kill）或 PID（kill/info）", required: false),
            .init(name: "signal", type: .string, description: "信号：TERM(默认)/KILL/INT/HUP", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"]?.lowercased() else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action (list/kill/info)", isError: true)
        }

        switch action {
        case "list":
            let name = arguments["name"] ?? ""
            let output = try await runProcessOutput(
                executable: "/bin/ps",
                arguments: ["-eo", "user,pid,%cpu,%mem,comm"]
            )
            let lines = output.split(separator: "\n")
            guard lines.count > 1 else {
                return ToolCallResult(id: UUID().uuidString, output: "无匹配进程")
            }

            // Parse entries
            var entries: [(user: String, pid: String, cpu: Double, mem: String, command: String)] = []
            for rawLine in lines.dropFirst() {
                let line = String(rawLine)
                let parts = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
                guard parts.count >= 5, let cpu = Double(parts[2]) else { continue }
                let cmd = String(parts[4])
                if name.isEmpty || cmd.localizedCaseInsensitiveContains(name) {
                    entries.append((String(parts[0]), String(parts[1]), cpu, String(parts[3]), cmd))
                }
            }

            // Sort by CPU descending
            entries.sort { $0.cpu > $1.cpu }

            // Default to top 20 if no name filter
            let limit = name.isEmpty ? min(entries.count, 20) : entries.count

            // Format output with aligned columns
            var result = "USER                PID     %CPU  %MEM  COMMAND\n"
            result += String(repeating: "-", count: 72) + "\n"
            for entry in entries.prefix(limit) {
                let user = entry.user.padding(toLength: 18, withPad: " ", startingAt: 0).prefix(18)
                let pid = entry.pid.padding(toLength: 6, withPad: " ", startingAt: 0).prefix(6)
                let cpu = String(format: "%5.1f", entry.cpu)
                let mem = entry.mem.padding(toLength: 5, withPad: " ", startingAt: 0).prefix(5)
                let command = entry.command.prefix(50)
                result += "\(user) \(pid) \(cpu) \(mem)  \(command)\n"
            }

            if entries.count > limit {
                result += "\n[已截断至 \(limit) 条，共 \(entries.count) 条匹配]"
            }

            return ToolCallResult(id: UUID().uuidString, output: result)

        case "kill":
            guard let name = arguments["name"] else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: name (进程名或 PID)", isError: true)
            }
            let signal = arguments["signal"] ?? "TERM"
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            if let pid = Int32(name) {
                task.executableURL = URL(fileURLWithPath: "/bin/kill")
                task.arguments = ["-\(signal)", "\(pid)"]
            } else {
                task.arguments = ["-\(signal)", "-f", name]
            }
            let errPipe = Pipe()
            task.standardError = errPipe
            task.standardOutput = FileHandle.nullDevice
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                task.terminationHandler = { _ in cont.resume() }
                do { try task.run() } catch { cont.resume(throwing: error) }
            }
            if task.terminationStatus != 0 {
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                return ToolCallResult(id: UUID().uuidString, output: err.isEmpty ? "终止失败" : err, isError: true)
            }
            Task { await AgentEventBus.shared.publish(.code(.commandExecuted(command: "kill -\(signal) \(name)"))) }
            return ToolCallResult(id: UUID().uuidString, output: "已发送 \(signal) 信号给 \(name)")

        case "info":
            guard let pidStr = arguments["name"], let pid = Int32(pidStr) else {
                return ToolCallResult(id: UUID().uuidString, output: "info 需要 PID 参数", isError: true)
            }
            let output = try await runProcessOutput(
                executable: "/bin/ps",
                arguments: ["-p", "\(pid)", "-o", "pid,ppid,user,%cpu,%mem,state,time,comm"]
            )
            return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "进程不存在" : output)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "无效 action: \(action)", isError: true)
        }
    }
}
