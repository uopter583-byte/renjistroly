import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

extension CommandParser {
    // MARK: - System Info

    static func parseSystemInfo(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("system_info") else { return nil }
        let patterns = [
            #"(?:系统|电脑|mac|机器)\s*(?:信息|状态|情况|配置|spec)"#,
            #"(?:CPU|内存|硬盘|电池|电量)\s*(?:使用率|占用|状态|容量|剩余)?"#,
            #"system_info|sysinfo"#,
        ]
        for p in patterns {
            if (try? Regex(p).firstMatch(in: text)) != nil {
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "system_info", arguments: ["info_type": "all"])],
                    response: "正在获取系统信息..."
                )
            }
        }
        return nil
    }

    // MARK: - Running Apps

    static func parseRunningApps(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("running_apps") else { return nil }
        let patterns = [
            #"(?:正在)?\s*(?:运行|打开|活跃)\s*(?:的|中)?\s*(?:应用|app|程序)"#,
            #"(?:有哪些|什么)\s*(?:应用|app|程序)\s*(?:在|正在)\s*(?:运行|打开)"#,
            #"running_apps|ps"#,
        ]
        for p in patterns {
            if (try? Regex(p).firstMatch(in: text)) != nil {
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "running_apps", arguments: [:])],
                    response: "正在获取运行中的应用列表..."
                )
            }
        }
        return nil
    }

    // MARK: - UI Tree

    static func parseUITree(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("get_ui_tree") else { return nil }
        let patterns = [
            #"(?:获取|显示|查看)?\s*UI\s*(?:树|结构|元素|层级|tree)"#,
            #"(?:界面|屏幕)\s*(?:结构|元素|组成)"#,
            #"get_ui_tree"#,
        ]
        for p in patterns {
            if (try? Regex(p).firstMatch(in: text)) != nil {
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "get_ui_tree", arguments: ["depth": "3"])],
                    response: "正在获取 UI 结构..."
                )
            }
        }
        return nil
    }

    // MARK: - Process Kill

    static func parseProcessKill(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("process") else { return nil }
        let killPatterns = [
            #"(?:杀掉|杀死|终止|结束|kill|stop)\s*(?:进程)?\s*[''"』]?(\S+)[''"』]?"#,
        ]
        for p in killPatterns {
            if let m = try? Regex(p).firstMatch(in: text) {
                let name = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return nil }
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "process", arguments: ["action": "kill", "name": name])],
                    response: "正在终止进程: \(name)"
                )
            }
        }
        let listPatterns = [
            #"(?:查看|列出|显示)\s*(?:进程|ps)"#,
        ]
        for p in listPatterns {
            if (try? Regex(p).firstMatch(in: text)) != nil {
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "process", arguments: ["action": "list"])],
                    response: "正在获取进程列表..."
                )
            }
        }
        return nil
    }
}
