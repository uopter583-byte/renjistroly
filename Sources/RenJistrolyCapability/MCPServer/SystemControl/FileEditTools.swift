import Foundation
import OSLog
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - File Edit Tool

public struct FileEditTool: MCPTool {
    public let definition = ToolDefinition(
        name: "file_edit",
        description: "执行文件语义编辑：查找并替换文件中的指定文本内容",
        parameters: [
            .init(name: "file_path", type: .string, description: "文件绝对路径"),
            .init(name: "old_string", type: .string, description: "要替换的原文"),
            .init(name: "new_string", type: .string, description: "替换后的新文本"),
            .init(name: "replace_all", type: .string, description: "是否替换所有匹配 false/true，可选，默认 false", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let filePath = arguments["file_path"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: file_path", isError: true)
        }
        guard let oldString = arguments["old_string"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: old_string", isError: true)
        }
        guard let newString = arguments["new_string"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: new_string", isError: true)
        }

        let replaceAll = (arguments["replace_all"] ?? "false").lowercased() == "true"

        // Resolve absolute path
        let expanded = (filePath as NSString).expandingTildeInPath
        guard (expanded as NSString).isAbsolutePath else {
            return ToolCallResult(id: UUID().uuidString, output: "file_path 必须是绝对路径", isError: true)
        }
        let absPath = expanded

        // Security check: reject sensitive system paths
        if let error = blockedPathError(absPath) {
            return error
        }

        // Verify file exists
        let fm = FileManager.default
        guard fm.fileExists(atPath: absPath) else {
            return ToolCallResult(id: UUID().uuidString, output: "文件不存在: \(absPath)", isError: true)
        }

        // Read file content
        let content: String
        do {
            content = try String(contentsOfFile: absPath, encoding: .utf8)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "读取文件失败: \(error.localizedDescription)", isError: true)
        }

        // Count occurrences
        let count = content.occurrences(of: oldString)
        guard count > 0 else {
            return ToolCallResult(id: UUID().uuidString, output: "未找到匹配的文本:\n\(oldString)", isError: true)
        }

        // Validate uniqueness
        if count > 1, !replaceAll {
            return ToolCallResult(
                id: UUID().uuidString,
                output: "找到 \(count) 处匹配，请使用 replace_all=true 替换所有匹配，或调整 old_string 使其唯一匹配",
                isError: true
            )
        }

        // Perform replacement
        let newContent: String
        if replaceAll {
            newContent = content.replacingOccurrences(of: oldString, with: newString)
        } else {
            guard let range = content.range(of: oldString) else {
                return ToolCallResult(id: UUID().uuidString, output: "替换失败: 无法定位匹配文本", isError: true)
            }
            newContent = content.replacingCharacters(in: range, with: newString)
        }

        // Create backup before writing
        do {
            try createBackup(of: absPath, originalContent: content)
        } catch {
            Logger.tools.error("[FileEdit] 备份失败: \(error.localizedDescription, privacy: .public)")
            return ToolCallResult(id: UUID().uuidString, output: "备份失败，操作已中止: \(error.localizedDescription)", isError: true)
        }

        // Write new content
        do {
            try newContent.write(toFile: absPath, atomically: true, encoding: .utf8)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "写入文件失败: \(error.localizedDescription)", isError: true)
        }

        let changeCount = replaceAll ? count : 1
        let changeType = replaceAll && count > 1 ? "replace_all" : "replace"
        Task { await AgentEventBus.shared.publish(.code(.fileModified(path: absPath, changeType: changeType))) }
        return ToolCallResult(
            id: UUID().uuidString,
            output: "已修改 \(absPath)（\(changeCount) 处替换）"
        )
    }

    // MARK: - Helpers

    private static let sensitivePaths: [String] = [
        "/etc", "/usr/bin", "/usr/sbin", "/System", "/private/etc", "/dev"
    ]

    private func blockedPathError(_ path: String) -> ToolCallResult? {
        let normalized = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        for sensitive in Self.sensitivePaths {
            let normalizedSensitive = URL(fileURLWithPath: sensitive).resolvingSymlinksInPath().path
            if normalized == normalizedSensitive || normalized.hasPrefix(normalizedSensitive + "/") {
                return ToolCallResult(
                    id: UUID().uuidString,
                    output: "安全限制：禁止写入系统敏感路径 \(sensitive)",
                    isError: true
                )
            }
        }
        return nil
    }

    private func createBackup(of path: String, originalContent: String) throws {
        let fm = FileManager.default
        let backupDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".renjistroly_backups")
            .appendingPathComponent("files")

        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true, attributes: nil)

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let fileName = URL(fileURLWithPath: path).lastPathComponent
        let safePath = path
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let backupPath = backupDir
            .appendingPathComponent("\(fileName)_\(timestamp)_\(safePath).bak")

        try originalContent.write(to: backupPath, atomically: true, encoding: .utf8)

        Logger.tools.notice("[FileEdit] 已备份 \(path, privacy: .public) 到 \(backupPath.path, privacy: .public)")
    }
}

// MARK: - String Helpers

private extension String {
    func occurrences(of substring: String) -> Int {
        var count = 0
        var searchRange: Range<String.Index>? = startIndex..<endIndex
        while let range = range(of: substring, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<endIndex
        }
        return count
    }
}
