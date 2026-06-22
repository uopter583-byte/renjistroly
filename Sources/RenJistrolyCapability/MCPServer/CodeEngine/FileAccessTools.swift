import Foundation
import RenJistrolyModels

// MARK: - 文件路径安全校验

/// 文件读写操作的路径安全检查
enum FileAccessValidator {
    /// 敏感子路径（在任何允许根目录下都禁止访问）
    private static let blockedSubpaths: [String] = [
        ".ssh", ".aws", ".kube", ".gnupg", ".docker",
        "Library/Keychains",
    ]

    /// 敏感文件模式
    private static let sensitiveFiles: Set<String> = [
        "id_rsa", "id_rsa.pub", "id_dsa", "id_ecdsa", "id_ecdsa.pub", "id_ed25519", "id_ed25519.pub",
        "authorized_keys", "known_hosts",
        "credentials", "config", "credentials.json", "config.json",
        ".gitconfig", ".netrc", ".env", ".env.local",
    ]

    /// 写入操作允许的根目录
    private static let writeAllowedRoots: [String] = {
        let home = NSHomeDirectory()
        return [
            home + "/Desktop",
            home + "/Documents",
            home + "/Downloads",
            home + "/Developer",
            FileManager.default.currentDirectoryPath,
            NSTemporaryDirectory(),
            "/tmp",
        ]
    }()

    /// 解析文件的真实路径（跟随全部符号链接）
    private static func resolveRealPath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardized.path
    }

    /// 检查路径是否指向敏感文件（SSH 密钥、凭据等）
    static func isSensitiveFile(_ path: String) -> Bool {
        let fileName = (path as NSString).lastPathComponent
        return sensitiveFiles.contains(fileName)
    }

    /// 检查路径或其父路径是否在敏感子路径中
    static func isInBlockedSubpath(_ path: String) -> Bool {
        let resolved = resolveRealPath(path).lowercased()
        for subpath in blockedSubpaths {
            if resolved.contains("/" + subpath.lowercased() + "/") {
                return true
            }
            if resolved.hasSuffix("/" + subpath.lowercased()) {
                return true
            }
        }
        return false
    }

    /// 验证读取路径是否安全（仅阻止敏感凭据文件及敏感子路径）
    static func validateReadAccess(_ path: String) -> String? {
        let expanded = (path as NSString).expandingTildeInPath
        if isSensitiveFile(expanded) {
            return "目标文件为敏感凭据文件，禁止读取"
        }
        if isInBlockedSubpath(expanded) {
            return "目标路径在敏感系统目录中，禁止读取"
        }
        return nil
    }

    /// 验证写入路径是否安全（限制允许根目录 + 阻止敏感路径）
    static func validateWriteAccess(_ path: String) -> String? {
        let expanded = (path as NSString).expandingTildeInPath
        if isSensitiveFile(expanded) {
            return "目标文件为敏感凭据文件，禁止写入"
        }
        if isInBlockedSubpath(expanded) {
            return "目标路径在敏感系统目录中，禁止写入"
        }

        let resolved = resolveRealPath(expanded)
        let allowedRootsNormalized = Set(writeAllowedRoots.map { resolveRealPath($0) })
        let allowed = allowedRootsNormalized.contains { root in
            resolved == root || resolved.hasPrefix(root + "/")
        }
        if !allowed {
            return "路径不在允许的写入目录范围内"
        }
        return nil
    }
}

// MARK: - Read File Tool

public struct ReadFileTool: MCPTool {
    public let definition = ToolDefinition(
        name: "read_file",
        description: "读取文件内容",
        parameters: [
            .init(name: "path", type: .string, description: "文件路径"),
            .init(name: "lines", type: .string, description: "读取行数，默认全部", required: false),
            .init(name: "offset", type: .string, description: "起始行偏移", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let path = arguments["path"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: path", isError: true)
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            return ToolCallResult(id: UUID().uuidString, output: "文件不存在: \(path)", isError: true)
        }
        guard fileManager.isReadableFile(atPath: path) else {
            return ToolCallResult(id: UUID().uuidString, output: "文件不可读: \(path)", isError: true)
        }

        if let blockReason = FileAccessValidator.validateReadAccess(path) {
            return ToolCallResult(id: UUID().uuidString, output: "文件读取被拒绝: \(blockReason)", isError: true)
        }

        let content = try String(contentsOfFile: path, encoding: .utf8)
        let allLines = content.split(separator: "\n", omittingEmptySubsequences: false)

        let maxLines = Int(arguments["lines"] ?? "") ?? allLines.count
        let offset = Int(arguments["offset"] ?? "") ?? 0
        let end = min(offset + maxLines, allLines.count)
        let start = min(offset, allLines.count)

        let selected = allLines[start..<end]
        let output = selected.enumerated()
            .map { "\(start + $0 + 1): \($1)" }
            .joined(separator: "\n")

        Task { await AgentEventBus.shared.publish(.code(.fileOpened(path: path))) }
        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - List Files Tool

public struct ListFilesTool: MCPTool {
    public let definition = ToolDefinition(
        name: "list_files",
        description: "列出目录中的文件",
        parameters: [
            .init(name: "path", type: .string, description: "目录路径"),
            .init(name: "pattern", type: .string, description: "文件名匹配模式", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let path = arguments["path"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: path", isError: true)
        }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            return ToolCallResult(id: UUID().uuidString, output: "目录不存在: \(path)", isError: true)
        }

        if let blockReason = FileAccessValidator.validateReadAccess(path) {
            return ToolCallResult(id: UUID().uuidString, output: "目录列表被拒绝: \(blockReason)", isError: true)
        }

        let items = try fileManager.contentsOfDirectory(atPath: path)
        let pattern = arguments["pattern"]
        let filtered = pattern.map { p in items.filter { fnmatch(p, $0, 0) == 0 } } ?? items

        let output = filtered.sorted().joined(separator: "\n")
        Task { await AgentEventBus.shared.publish(.code(.fileOperation(action: "listDir", path: path))) }
        return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "目录为空" : output)
    }
}

// MARK: - Write File Tool (with confirmation)

public struct WriteFileTool: MCPTool {
    public let definition = ToolDefinition(
        name: "write_file",
        description: "写入文件内容（需要确认）",
        parameters: [
            .init(name: "path", type: .string, description: "文件路径"),
            .init(name: "content", type: .string, description: "文件内容"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let path = arguments["path"], let content = arguments["content"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数", isError: true)
        }

        if let blockReason = FileAccessValidator.validateWriteAccess(path) {
            return ToolCallResult(id: UUID().uuidString, output: "路径不允许写入: \(blockReason)", isError: true)
        }

        let dir = (path as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try content.write(toFile: path, atomically: true, encoding: .utf8)

        Task { await AgentEventBus.shared.publish(.code(.fileSaved(path: path))) }
        return ToolCallResult(id: UUID().uuidString, output: "文件已写入: \(path)")
    }
}
