import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

extension CommandParser {
    // MARK: - Shell Command

    static func parseShellCommand(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("shell_command") else { return nil }
        let shellPatterns = [
            #"^(?:运行|执行)\s*(?:命令|指令)?[:：]\s*(.+)"#,
            #"^(?:run|execute)\s+(.+)"#,
            #"^[\s]*\$[\s]*(.+)"#,
            #"^[\s]*❯[\s]*(.+)"#,
            #"^[\s]*>[^>][\s]*(.+)"#,
        ]
        for p in shellPatterns {
            if let m = try? Regex(p).firstMatch(in: text) {
                let cmd = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                guard !cmd.isEmpty, cmd.count < 2000 else { return nil }
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "shell_command", arguments: ["command": cmd])],
                    response: cmd
                )
            }
        }
        return nil
    }
}
