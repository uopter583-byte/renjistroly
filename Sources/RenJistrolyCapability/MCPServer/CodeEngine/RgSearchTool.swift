import Foundation
import OSLog
import RenJistrolyModels

// MARK: - Ripgrep Search Tool

public struct RgSearchTool: MCPTool {
    public let definition = ToolDefinition(
        name: "rg_search",
        description: "使用 ripgrep 在项目中搜索代码。支持正则、文件类型过滤、上下文行数",
        parameters: [
            .init(name: "pattern", type: .string, description: "搜索模式（支持正则）"),
            .init(name: "path", type: .string, description: "搜索路径，默认当前目录", required: false),
            .init(name: "working_dir", type: .string, description: "工作目录，默认当前目录", required: false),
            .init(name: "type", type: .string, description: "文件类型过滤，如 swift,py,js,rs,go,ts,md", required: false),
            .init(name: "context", type: .string, description: "上下文行数，默认 2", required: false),
            .init(name: "ignore_case", type: .string, description: "忽略大小写：true/false，默认 true", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let pattern = arguments["pattern"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: pattern", isError: true)
        }
        let workingDir = arguments["working_dir"] ?? FileManager.default.currentDirectoryPath
        let context = arguments["context"] ?? "2"
        let ignoreCase = (arguments["ignore_case"] ?? "true").lowercased() == "true"

        var args = ["-n", "--heading", "-C", context, "--max-count=200"]
        if ignoreCase { args.append("-i") }
        if let fileType = arguments["type"], !fileType.isEmpty {
            args.append("-t")
            args.append(fileType)
        }
        args.append("--")
        args.append(pattern)

        guard let rgPath = await findRipgrep() else {
            return ToolCallResult(id: UUID().uuidString, output: "未找到 ripgrep (rg)。请运行: brew install ripgrep", isError: true)
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: rgPath)
        task.arguments = args
        task.currentDirectoryURL = URL(fileURLWithPath: workingDir)

        let pipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errPipe
        let output = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { continuation.resume(throwing: error) }
        }
        let limitHit = output.split(separator: "\n").count >= 200

        var result = output.isEmpty ? "无匹配" : output
        if limitHit { result += "\n\n[结果已截断至 200 行]" }
        return ToolCallResult(id: UUID().uuidString, output: result)
    }

    private func findRipgrep() async -> String? {
        for path in ["/opt/homebrew/bin/rg", "/usr/local/bin/rg", "/usr/bin/rg"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }
        // Try PATH
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["rg"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            task.terminationHandler = { _ in
                let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
                cont.resume(returning: trimmed.isEmpty ? nil : trimmed)
            }
            do { try task.run() } catch {
                Logger.tools.error("[findRipgrep] which rg 失败: \(error.localizedDescription, privacy: .public)")
                cont.resume(returning: nil)
            }
        }
    }
}
