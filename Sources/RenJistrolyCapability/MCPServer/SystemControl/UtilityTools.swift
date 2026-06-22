import Foundation
import RenJistrolyModels

// MARK: - Process Helper

private enum ProcessRunner {
    /// 异步执行 shell 命令，返回 stdout 字符串。
    /// 非零退出码抛出包含 stderr 的 NSError。
    static func run(
        executable: String,
        arguments: [String],
        currentDirectory: String? = nil
    ) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let cwd = currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            process.terminationHandler = { _ in
                let output = Self.readAll(from: outputPipe)
                let errOutput = Self.readAll(from: errorPipe)
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let message = errOutput.isEmpty ? output : errOutput
                    continuation.resume(throwing: NSError(
                        domain: "UtilityTools",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: message.trimmingCharacters(in: .whitespacesAndNewlines)]
                    ))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func readAll(from pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// MARK: - ArchiveTool

public struct ArchiveTool: MCPTool {
    public let definition = ToolDefinition(
        name: "archive",
        description: "文件压缩或解压。压缩默认使用 zip 格式；解压自动识别 zip、tar.gz、tgz、tar.bz2、tbz2、tar.xz、txz、tar、gz、bz2 格式",
        parameters: [
            .init(name: "action", type: .string, description: "compress(压缩) / decompress(解压)"),
            .init(name: "source", type: .string, description: "源文件或目录路径"),
            .init(name: "destination", type: .string, description: "目标路径（可选；压缩时默认 source.zip，解压时默认源所在目录）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"]?.lowercased() else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action", isError: true)
        }
        guard let source = arguments["source"], !source.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: source", isError: true)
        }

        let sourcePath = (source as NSString).expandingTildeInPath
        let fm = FileManager.default

        guard fm.fileExists(atPath: sourcePath) else {
            return ToolCallResult(id: UUID().uuidString, output: "源路径不存在: \(sourcePath)", isError: true)
        }

        switch action {
        case "compress":
            return try await compress(sourcePath: sourcePath, destination: arguments["destination"], fm: fm)
        case "decompress":
            return try await decompress(sourcePath: sourcePath, destination: arguments["destination"], fm: fm)
        default:
            return ToolCallResult(id: UUID().uuidString, output: "无效 action: \(action)，请使用 compress 或 decompress", isError: true)
        }
    }

    // MARK: - Compress

    private func compress(sourcePath: String, destination: String?, fm: FileManager) async throws -> ToolCallResult {
        let dest = destination ?? (sourcePath + ".zip")
        let destPath = (dest as NSString).expandingTildeInPath

        let destDir = (destPath as NSString).deletingLastPathComponent
        if !fm.fileExists(atPath: destDir) {
            try fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)
        }

        let parentDir = (sourcePath as NSString).deletingLastPathComponent
        let baseName = (sourcePath as NSString).lastPathComponent

        var isDir: ObjCBool = false
        fm.fileExists(atPath: sourcePath, isDirectory: &isDir)

        // cd to parent so zip stores clean relative paths
        if isDir.boolValue {
            _ = try await ProcessRunner.run(
                executable: "/usr/bin/zip",
                arguments: ["-r", "--symlinks", destPath, baseName],
                currentDirectory: parentDir
            )
        } else {
            _ = try await ProcessRunner.run(
                executable: "/usr/bin/zip",
                arguments: [destPath, baseName],
                currentDirectory: parentDir
            )
        }

        return ToolCallResult(id: UUID().uuidString, output: "已压缩: \(sourcePath) -> \(destPath)")
    }

    // MARK: - Decompress

    private func decompress(sourcePath: String, destination: String?, fm: FileManager) async throws -> ToolCallResult {
        let destDir: String
        if let dest = destination {
            destDir = (dest as NSString).expandingTildeInPath
        } else {
            destDir = (sourcePath as NSString).deletingLastPathComponent
        }
        if !fm.fileExists(atPath: destDir) {
            try fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)
        }

        let lower = sourcePath.lowercased()
        if lower.hasSuffix(".zip") {
            _ = try await ProcessRunner.run(executable: "/usr/bin/unzip", arguments: ["-o", sourcePath, "-d", destDir])
        } else if lower.hasSuffix(".tar.gz") || lower.hasSuffix(".tgz") {
            _ = try await ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-xzf", sourcePath, "-C", destDir])
        } else if lower.hasSuffix(".tar.bz2") || lower.hasSuffix(".tbz2") {
            _ = try await ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-xjf", sourcePath, "-C", destDir])
        } else if lower.hasSuffix(".tar.xz") || lower.hasSuffix(".txz") {
            _ = try await ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-xJf", sourcePath, "-C", destDir])
        } else if lower.hasSuffix(".tar") {
            _ = try await ProcessRunner.run(executable: "/usr/bin/tar", arguments: ["-xf", sourcePath, "-C", destDir])
        } else if lower.hasSuffix(".gz") {
            _ = try await ProcessRunner.run(executable: "/usr/bin/gunzip", arguments: ["-k", sourcePath])
        } else if lower.hasSuffix(".bz2") {
            _ = try await ProcessRunner.run(executable: "/usr/bin/bunzip2", arguments: ["-k", sourcePath])
        } else {
            return ToolCallResult(id: UUID().uuidString, output: "不支持的压缩格式: \(sourcePath)", isError: true)
        }

        return ToolCallResult(id: UUID().uuidString, output: "已解压: \(sourcePath) -> \(destDir)")
    }
}

// MARK: - HomebrewTool

public struct HomebrewTool: MCPTool {
    private static var brewPath: String {
        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
            "/home/linuxbrew/.linuxbrew/bin/brew",
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return "/opt/homebrew/bin/brew" // default for Apple Silicon
    }

    public let definition = ToolDefinition(
        name: "homebrew",
        description: "Homebrew 包管理：搜索、安装、卸载、列出已安装包、更新源或升级所有包。install 和 upgrade 属于高风险操作",
        parameters: [
            .init(name: "action", type: .string, description: "search(搜索) / install(安装) / uninstall(卸载) / list(列出已安装) / update(更新源) / upgrade(升级所有)"),
            .init(name: "package", type: .string, description: "包名（search / install / uninstall 时需要）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"]?.lowercased() else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action", isError: true)
        }

        let brew = Self.brewPath

        switch action {
        case "search":
            guard let pkg = arguments["package"], !pkg.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: package", isError: true)
            }
            let output = try await ProcessRunner.run(executable: brew, arguments: ["search", pkg])
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return ToolCallResult(id: UUID().uuidString, output: trimmed.isEmpty ? "未找到匹配的包" : trimmed)

        case "install":
            guard let pkg = arguments["package"], !pkg.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: package", isError: true)
            }
            let output = try await ProcessRunner.run(executable: brew, arguments: ["install", pkg])
            return ToolCallResult(id: UUID().uuidString, output: "已安装: \(pkg)\n\(output)")

        case "uninstall":
            guard let pkg = arguments["package"], !pkg.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: package", isError: true)
            }
            let output = try await ProcessRunner.run(executable: brew, arguments: ["uninstall", pkg])
            return ToolCallResult(id: UUID().uuidString, output: "已卸载: \(pkg)\n\(output)")

        case "list":
            let output = try await ProcessRunner.run(executable: brew, arguments: ["list", "--formula"])
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return ToolCallResult(id: UUID().uuidString, output: trimmed.isEmpty ? "未安装任何 formula" : trimmed)

        case "update":
            let output = try await ProcessRunner.run(executable: brew, arguments: ["update"])
            return ToolCallResult(id: UUID().uuidString, output: output.trimmingCharacters(in: .whitespacesAndNewlines))

        case "upgrade":
            let output = try await ProcessRunner.run(executable: brew, arguments: ["upgrade"])
            return ToolCallResult(id: UUID().uuidString, output: output.trimmingCharacters(in: .whitespacesAndNewlines))

        default:
            return ToolCallResult(id: UUID().uuidString, output: "无效 action: \(action)，可选: search / install / uninstall / list / update / upgrade", isError: true)
        }
    }
}

// MARK: - SpotlightSearchTool

public struct SpotlightSearchTool: MCPTool {
    public let definition = ToolDefinition(
        name: "spotlight_search",
        description: "使用 Spotlight（mdfind）搜索文件，支持按文件类型过滤。搜索文件名称和内容",
        parameters: [
            .init(name: "query", type: .string, description: "搜索关键词"),
            .init(name: "limit", type: .string, description: "最大结果数，默认 20", required: false),
            .init(name: "kind", type: .string, description: "文件类型过滤：document / image / pdf / code / folder（可选）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let query = arguments["query"], !query.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: query", isError: true)
        }

        let limit = max(1, Int(arguments["limit"] ?? "20") ?? 20)

        let output: String
        if let kind = arguments["kind"]?.lowercased() {
            let filter: String
            switch kind {
            case "document":
                filter = "kMDItemContentTypeTree == 'public.content'"
            case "image":
                filter = "kMDItemContentTypeTree == 'public.image'"
            case "pdf":
                filter = "kMDItemContentType == 'com.adobe.pdf'"
            case "code":
                filter = "kMDItemContentTypeTree == 'public.source-code'"
            case "folder":
                filter = "kMDItemContentType == 'public.folder'"
            default:
                return ToolCallResult(
                    id: UUID().uuidString,
                    output: "不支持的 kind: \(kind)，可选: document / image / pdf / code / folder",
                    isError: true
                )
            }
            // Compound Spotlight query: kind filter AND user query
            let escaped = query.replacingOccurrences(of: "'", with: "\\'")
            output = try await ProcessRunner.run(
                executable: "/usr/bin/mdfind",
                arguments: ["-literal", "(\(filter)) && (\(escaped))"]
            )
        } else {
            output = try await ProcessRunner.run(
                executable: "/usr/bin/mdfind",
                arguments: [query]
            )
        }

        let lines = output.split(separator: "\n").map(String.init)
        let limited = lines.prefix(limit)
        let result = limited.joined(separator: "\n")

        var summary = ""
        if lines.count > limit {
            summary = "\n（共 \(lines.count) 个结果，显示前 \(limit) 个）"
        } else if lines.isEmpty {
            summary = "未找到匹配的文件"
        }

        return ToolCallResult(id: UUID().uuidString, output: result.isEmpty ? summary : result + summary)
    }
}
