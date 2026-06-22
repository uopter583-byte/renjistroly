import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

extension CommandParser {
    // MARK: - Window Operations

    static func parseWindowOps(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        if toolNames.contains("list_windows") {
            let listPatterns = [
                #"(?:列出|显示|查看)?\s*(?:所有)?\s*窗口"#,
                #"(?:有哪些|什么)\s*窗口"#,
                #"list\s+windows"#,
            ]
            for p in listPatterns {
                if (try? Regex(p).firstMatch(in: text)) != nil {
                    let id = UUID().uuidString
                    return ParsedCommand(
                        toolCalls: [ToolCallRequest(id: id, name: "list_windows", arguments: [:])],
                        response: "正在获取窗口列表..."
                    )
                }
            }
        }

        if toolNames.contains("focus_window") {
            let focusPatterns = [
                #"(?:切换|聚焦|激活|跳到)\s*(?:到)?\s*[''"』]?(\S+)[''"』]?\s*(?:窗口)?"#,
                #"focus\s+(\S+)"#,
            ]
            for p in focusPatterns {
                if let m = try? Regex(p).firstMatch(in: text) {
                    let title = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                    guard !title.isEmpty, title.count < 100 else { return nil }
                    let id = UUID().uuidString
                    return ParsedCommand(
                        toolCalls: [ToolCallRequest(id: id, name: "focus_window", arguments: ["title": title])],
                        response: "正在切换到窗口: \(title)"
                    )
                }
            }
        }
        return nil
    }

    // MARK: - File Operations

    static func parseFileOps(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        if toolNames.contains("list_files") {
            var path: String?
            if let m = try? Regex(#"(?:列出|显示|查看)?\s*(?:文件|目录)\s*(?:列表)?[：:]?\s*(.+)"#).firstMatch(in: text) {
                path = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
            } else if let m = try? Regex(#"ls\s+(.+)"#).firstMatch(in: text) {
                path = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
            } else if (try? Regex(#"ls\s*$"#).firstMatch(in: text)) != nil {
                path = ""
            }
            if path != nil {
                var args: [String: String] = [:]
                if let p = path, !p.isEmpty { args["path"] = p }
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "list_files", arguments: args)],
                    response: "正在列出文件..."
                )
            }
        }

        if toolNames.contains("read_file") {
            let readPatterns = [
                #"(?:读取|查看|打开|读|看|cat)\s*(?:文件)?\s*[''"』]?(\S+\.\S+)[''"』]?"#,
                #"(?:read|open|cat)\s+(\S+\.\S+)"#,
            ]
            for p in readPatterns {
                if let m = try? Regex(p).firstMatch(in: text) {
                    let filePath = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                    guard !filePath.isEmpty else { return nil }
                    let id = UUID().uuidString
                    return ParsedCommand(
                        toolCalls: [ToolCallRequest(id: id, name: "read_file", arguments: ["file_path": filePath])],
                        response: "正在读取: \(filePath)"
                    )
                }
            }
        }

        if toolNames.contains("write_file") {
            let writePatterns = [
                #"(?:写入|保存|写|创建)\s*(?:文件)?\s*[''"』]?(\S+)[''"』]?"#,
            ]
            for p in writePatterns {
                if let m = try? Regex(p).firstMatch(in: text) {
                    let filePath = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                    guard !filePath.isEmpty else { return nil }
                    var args: [String: String] = ["file_path": filePath]
                    if let contentM = try? Regex(#"内容[:：]?\s*(.+)"#).firstMatch(in: text) {
                        args["content"] = String(contentM.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                    }
                    let id = UUID().uuidString
                    return ParsedCommand(
                        toolCalls: [ToolCallRequest(id: id, name: "write_file", arguments: args)],
                        response: "正在写入: \(filePath)"
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Changed Files

    static func parseChangedFiles(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("changed_files") else { return nil }
        let patterns = [
            #"(?:变更|改动|修改|changed)\s*(?:了哪些|哪些|的)?\s*(?:文件|file)"#,
            #"changed_files"#,
            #"(?:最近|最近哪些)\s*(?:改动|变更|修改)"#,
        ]
        for p in patterns {
            if (try? Regex(p).firstMatch(in: text)) != nil {
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "changed_files", arguments: [:])],
                    response: "正在查看变更文件..."
                )
            }
        }
        return nil
    }
}
