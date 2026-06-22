import Foundation
import RenJistrolyModels

public struct QuickOpenTool: MCPTool {
    public let definition = ToolDefinition(
        name: "quick_open",
        description: "快速搜索项目中的文件（类似 Xcode Cmd+Shift+O）。使用 mdfind 或 fd 进行模糊匹配",
        parameters: [
            .init(name: "query", type: .string, description: "文件名或部分路径"),
            .init(name: "project_path", type: .string, description: "项目根目录", required: false),
            .init(name: "type", type: .string, description: "文件类型过滤，如 swift,md,json", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let query = arguments["query"], !query.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: query", isError: true)
        }

        let projectPath = arguments["project_path"] ?? FileManager.default.currentDirectoryPath
        let fileType = arguments["type"]

        var results: [String] = []

        // Try fd first (fastest, cleanest output)
        if let fdPath = await findBinary("fd") {
            results = await searchWithFD(fdPath: fdPath, query: query, projectPath: projectPath, fileType: fileType)
        }

        // Fallback to mdfind
        if results.isEmpty, let mdfindPath = await findBinary("mdfind") {
            results = await searchWithMDFind(mdfindPath: mdfindPath, query: query, projectPath: projectPath, fileType: fileType)
        }

        // Final fallback to find
        if results.isEmpty {
            results = await searchWithFind(query: query, projectPath: projectPath, fileType: fileType)
        }

        let limited = Array(results.prefix(20))
        let output = limited.isEmpty ? "未找到匹配文件" : limited.joined(separator: "\n")
        return ToolCallResult(id: UUID().uuidString, output: output)
    }

    private func searchWithFD(fdPath: String, query: String, projectPath: String, fileType: String?) async -> [String] {
        var args = ["--type", "f", "--max-results", "20", "--absolute-path"]
        if let type = fileType, !type.isEmpty {
            let exts = type.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for ext in exts {
                args.append(contentsOf: ["--extension", ext])
            }
        }
        args.append(query)
        args.append(projectPath)

        return await runAndCollect(executable: fdPath, args: args, maxLines: 20)
    }

    private func searchWithMDFind(mdfindPath: String, query: String, projectPath: String, fileType: String?) async -> [String] {
        let escapedQuery = query.replacingOccurrences(of: "'", with: "\\'")
        let predicate = "kMDItemFSName == '*\(escapedQuery)*'"
        let args = ["-onlyin", projectPath, predicate]

        // Filter by extension after collecting results
        let raw = await runAndCollect(executable: mdfindPath, args: args, maxLines: 50)
        return filterByType(raw, fileType: fileType)
    }

    private func searchWithFind(query: String, projectPath: String, fileType: String?) async -> [String] {
        var args = [projectPath, "-name", "*\(query)*", "-maxdepth", "5", "-type", "f"]
        if let type = fileType, !type.isEmpty {
            let exts = type.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for ext in exts {
                args.append(contentsOf: ["-name", "*.\(ext)"])
            }
            // find will OR the -name conditions; without type, just use the query
            // Actually, find with multiple -name uses OR within -type f, so this works
        }

        let raw = await runAndCollect(executable: "/usr/bin/find", args: args, maxLines: 50)
        return filterByType(raw, fileType: fileType)
    }

    private func runAndCollect(executable: String, args: [String], maxLines: Int) async -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = args
        task.standardError = FileHandle.nullDevice

        let pipe = Pipe()
        task.standardOutput = pipe
        let output = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { cont.resume(throwing: error) }
        }
        guard let output else { return [] }
        return output.split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
            .prefix(maxLines)
            .map { $0 }
    }

    private func filterByType(_ results: [String], fileType: String?) -> [String] {
        guard let type = fileType, !type.isEmpty else { return results }
        let exts = type.split(separator: ",").map { ".\($0.trimmingCharacters(in: .whitespaces))" }
        return results.filter { path in
            exts.contains { path.hasSuffix($0) }
        }
    }

    private func findBinary(_ name: String) async -> String? {
        for path in ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)", "/usr/bin/\(name)"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [name]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        let out = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { cont.resume(throwing: error) }
        }
        guard let out else { return nil }
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
