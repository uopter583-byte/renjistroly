import Foundation
import RenJistrolyModels

public struct LocalActionParser: Sendable {
    /// 项目根路径，可通过环境变量 RENJISTROLY_PROJECT_PATH 配置
    private let projectPath: String

    public init(projectPath: String? = nil) {
        self.projectPath = projectPath ?? ProcessInfo.processInfo.environment["RENJISTROLY_PROJECT_PATH"]
            ?? NSHomeDirectory()
    }

    public func parse(_ text: String) -> MacAction? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "。", with: "")
            .replacingOccurrences(of: "，", with: "")

        guard !normalized.isEmpty else { return nil }

        if let action = parseWindowOrApplicationControl(normalized) {
            return action
        }

        if let url = parseURL(normalized) {
            return MacAction(
                kind: .openURL,
                payload: ["url": url],
                riskLevel: .readOnly,
                humanPreview: "打开链接：\(url)"
            )
        }

        if let path = parseFolderPath(normalized) {
            return MacAction(
                kind: .openFileOrFolder,
                payload: ["path": path],
                riskLevel: .readOnly,
                humanPreview: "打开路径：\(path)"
            )
        }

        if let path = parseTerminalPath(normalized) {
            return MacAction(
                kind: .openTerminalAtPath,
                payload: ["path": path],
                riskLevel: .persistentOrExternal,
                humanPreview: "打开终端并进入：\(path)"
            )
        }

        if let terminalCommand = parseTerminalCommand(normalized) {
            return MacAction(
                kind: .openTerminalCommand,
                payload: terminalCommand,
                riskLevel: .persistentOrExternal,
                humanPreview: "在终端运行：\(terminalCommand["command"] ?? "")"
            )
        }

        if let appName = parseOpenApplicationName(normalized) {
            return MacAction(
                kind: .openApplication,
                payload: ["name": appName],
                riskLevel: .readOnly,
                humanPreview: "打开应用：\(appName)"
            )
        }

        return nil
    }

    private func parseWindowOrApplicationControl(_ text: String) -> MacAction? {
        if containsAny(text, ["关闭当前窗口", "关掉当前窗口", "关当前窗口", "关闭窗口", "关掉窗口"]) {
            return MacAction(
                kind: .closeWindow,
                riskLevel: .reversibleInput,
                humanPreview: "关闭当前窗口"
            )
        }

        if containsAny(text, ["最小化当前窗口", "最小化窗口", "收起窗口"]) {
            return MacAction(
                kind: .minimizeWindow,
                riskLevel: .reversibleInput,
                humanPreview: "最小化当前窗口"
            )
        }

        let quitPrefixes = ["帮我关闭", "帮我关掉", "关闭", "关掉", "退出", "结束"]
        for prefix in quitPrefixes where text.hasPrefix(prefix) {
            let name = cleanedApplicationName(String(text.dropFirst(prefix.count))) ?? ""
            guard !name.isEmpty else { continue }
            return MacAction(
                kind: .quitApplication,
                payload: ["name": name],
                riskLevel: .persistentOrExternal,
                humanPreview: "退出应用：\(name)"
            )
        }

        let hidePrefixes = ["隐藏", "帮我隐藏"]
        for prefix in hidePrefixes where text.hasPrefix(prefix) {
            let name = cleanedApplicationName(String(text.dropFirst(prefix.count))) ?? ""
            guard !name.isEmpty else { continue }
            return MacAction(
                kind: .hideApplication,
                payload: ["name": name],
                riskLevel: .reversibleInput,
                humanPreview: "隐藏应用：\(name)"
            )
        }

        return nil
    }

    private func parseURL(_ text: String) -> String? {
        let lower = text.lowercased()
        if lower.hasPrefix("打开http://") || lower.hasPrefix("打开https://") {
            return String(text.dropFirst("打开".count))
        }
        if lower.hasPrefix("打开网址") {
            let value = String(text.dropFirst("打开网址".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        if lower.contains(".com") || lower.contains(".cn") || lower.contains(".dev") || lower.contains(".ai") {
            if text.hasPrefix("打开") {
                return String(text.dropFirst("打开".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func parseFolderPath(_ text: String) -> String? {
        let mappings = [
            "打开下载": "~/Downloads",
            "打开下载文件夹": "~/Downloads",
            "打开桌面": "~/Desktop",
            "打开桌面文件夹": "~/Desktop",
            "打开文稿": "~/Documents",
            "打开文档": "~/Documents",
            "打开应用程序": "/Applications",
            "打开项目文件夹": projectPath,
            "打开当前项目": projectPath
        ]
        let compact = text.replacingOccurrences(of: " ", with: "")
        if let path = mappings[compact] {
            return path
        }
        if text.hasPrefix("打开文件夹") {
            let path = String(text.dropFirst("打开文件夹".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? nil : path
        }
        return nil
    }

    private func parseTerminalPath(_ text: String) -> String? {
        let compact = text.replacingOccurrences(of: " ", with: "")
        if compact == "在终端打开当前项目" || compact == "终端打开当前项目" {
            return projectPath
        }
        if compact == "在终端打开项目" || compact == "终端打开项目" {
            return projectPath
        }
        if text.hasPrefix("在终端打开") {
            let path = String(text.dropFirst("在终端打开".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return path.isEmpty ? NSHomeDirectory() : path
        }
        return nil
    }

    private func parseTerminalCommand(_ text: String) -> [String: String]? {
        let prefixes = ["在终端运行", "终端运行", "开终端运行", "打开终端运行", "用终端运行"]
        for prefix in prefixes where text.hasPrefix(prefix) {
            let command = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else { return nil }
            return [
                "command": command,
                "path": projectPath,
                "title": "MVA-\(String(command.prefix(18)))"
            ]
        }
        return nil
    }

    private func parseOpenApplicationName(_ text: String) -> String? {
        let prefixes = [
            "你帮我打开", "你帮我开一下", "你帮我开", "帮我打开", "帮我开一下", "帮我开",
            "你打开", "打开一下", "打开",
            "帮我启动", "你帮我启动", "启动一下", "启动", "开启一下", "开启", "运行",
            "帮我切换到", "帮我切到", "帮我转到", "帮我回到", "帮我进入",
            "切换到", "切到", "转到", "回到", "进入"
        ]

        for prefix in prefixes where text.hasPrefix(prefix) {
            let name = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedApplicationName(name)
        }

        let compact = text.replacingOccurrences(of: " ", with: "").lowercased()
        let directCommands: [String: String] = [
            "开终端": "终端",
            "打开terminal": "Terminal",
            "开terminal": "Terminal",
            "开命令行": "终端",
            "打开命令行": "终端",
            "开浏览器": "Safari",
            "开微信": "微信",
            "打开微信": "微信",
            "开codex": "Codex",
            "打开codex": "Codex",
            "开设置": "系统设置",
            "打开设置": "系统设置"
        ]

        return directCommands[compact]
    }

    private func cleanedApplicationName(_ raw: String) -> String? {
        var name = raw
        let suffixes = ["这个app", "这个应用", "app", "应用", "软件", "程序", "窗口"]
        for suffix in suffixes where name.lowercased().hasSuffix(suffix.lowercased()) {
            name = String(name.dropLast(suffix.count))
        }
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private func containsAny(_ text: String, _ candidates: [String]) -> Bool {
        candidates.contains { text.contains($0) }
    }
}
