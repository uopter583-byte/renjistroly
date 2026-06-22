import Foundation
import RenJistrolyModels

// MARK: - Find Symbol Tool (LSP-based via sourcekit-lsp)

public struct FindSymbolTool: MCPTool {
    public let definition = ToolDefinition(
        name: "find_symbol",
        description: "在 Swift 项目中搜索符号定义。使用 sourcekit-lsp 索引",
        parameters: [
            .init(name: "symbol", type: .string, description: "符号名（函数、类、变量等）"),
            .init(name: "project_path", type: .string, description: "项目路径", required: false),
            .init(name: "file", type: .string, description: "文件 glob 模式（如 *.swift）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let symbol = arguments["symbol"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: symbol", isError: true)
        }
        // Fallback: use rg to search for symbol definitions
        let path = arguments["project_path"] ?? FileManager.default.currentDirectoryPath
        let task = Process()

        // Try ripgrep first (richer output)
        if let rg = await findBinary("rg") {
            task.executableURL = URL(fileURLWithPath: rg)
            var rgArgs = ["-n", "--heading", "-C", "1", "--max-count=50"]
            if let file = arguments["file"], !file.isEmpty {
                rgArgs.append("--glob=\(file)")
            }
            rgArgs.append(#"(?:func|class|struct|enum|protocol|extension|actor|typealias|macro|operator)\s+\#(NSRegularExpression.escapedPattern(for: symbol))\b"#)
            rgArgs.append(path)
            task.arguments = rgArgs
        } else {
            task.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
            task.arguments = ["-rn", "--include=*.swift", "-E",
                              "func \(symbol)|class \(symbol)|struct \(symbol)|enum \(symbol)|protocol \(symbol)|extension \(symbol)|actor \(symbol)|typealias \(symbol)|macro \(symbol)|operator \(symbol)", path]
        }
        task.currentDirectoryURL = URL(fileURLWithPath: path)

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        let output = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { cont.resume(throwing: error) }
        }
        let deduped = deduplicateSymbolResults(output)
        return ToolCallResult(id: UUID().uuidString, output: deduped.isEmpty ? "未找到符号: \(symbol)" : deduped)
    }

    func deduplicateSymbolResults(_ output: String) -> String {
        var seen = Set<String>()
        var currentFile = ""
        var dedupLines: [String] = []
        for line in output.split(separator: "\n") {
            let s = String(line)
            // File heading (rg --heading)
            if !s.contains(":") && (s.contains("/") || s.contains(".")) {
                if s != currentFile {
                    currentFile = s
                    dedupLines.append(s)
                }
                continue
            }
            if s.contains(":") {
                let parts = s.split(separator: ":", maxSplits: 2)
                if parts.count >= 2 {
                    if let lineNum = Int(parts[0]) {
                        // rg heading "line:content"
                        let key = "\(currentFile):\(lineNum)"
                        if !seen.insert(key).inserted { continue }
                    } else if parts.count >= 3, let lineNum = Int(parts[1]) {
                        // grep "file:line:content"
                        let key = "\(parts[0]):\(lineNum)"
                        if !seen.insert(key).inserted { continue }
                    }
                }
            }
            dedupLines.append(s)
        }
        return dedupLines.joined(separator: "\n")
    }

    private func findBinary(_ name: String) async -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [name]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            task.terminationHandler = { _ in
                let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
                cont.resume(returning: trimmed.isEmpty ? nil : trimmed)
            }
            do { try task.run() } catch { cont.resume(returning: nil) }
        }
    }
}
