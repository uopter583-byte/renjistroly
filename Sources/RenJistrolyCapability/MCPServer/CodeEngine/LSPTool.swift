import Foundation
import RenJistrolyModels

public struct LSPTool: MCPTool {
    public let definition = ToolDefinition(
        name: "lsp_symbol",
        description: "代码符号导航：定义跳转(definition)、查找引用(references)、悬停信息(hover)。使用 sourcekit-lsp 索引",
        parameters: [
            .init(name: "action", type: .string, description: "definition/references/hover"),
            .init(name: "file_path", type: .string, description: "源文件路径"),
            .init(name: "line", type: .string, description: "行号"),
            .init(name: "column", type: .string, description: "列号"),
            .init(name: "project_path", type: .string, description: "项目根目录（用于启动 sourcekit-lsp）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"]?.lowercased() else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action (definition/references/hover)", isError: true)
        }
        guard let filePath = arguments["file_path"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: file_path", isError: true)
        }
        guard let lineStr = arguments["line"], let line = Int(lineStr), line > 0 else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少或无效参数: line", isError: true)
        }
        guard let colStr = arguments["column"], let column = Int(colStr), column > 0 else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少或无效参数: column", isError: true)
        }

        let projectPath = arguments["project_path"] ?? FileManager.default.currentDirectoryPath

        guard let symbol = extractSymbol(at: line, column: column, filePath: filePath) else {
            return ToolCallResult(id: UUID().uuidString, output: "在 \(filePath):\(line):\(column) 处未找到有效符号", isError: true)
        }

        switch action {
        case "definition":
            return try await findDefinition(symbol, projectPath: projectPath)
        case "references":
            return try await findReferences(symbol, projectPath: projectPath)
        case "hover":
            return try await hoverSymbol(symbol, projectPath: projectPath)
        default:
            return ToolCallResult(id: UUID().uuidString, output: "无效 action: \(action)，可用: definition/references/hover", isError: true)
        }
    }

    // MARK: - Symbol Extraction

    private func extractSymbol(at line: Int, column: Int, filePath: String) -> String? {
        guard FileManager.default.fileExists(atPath: filePath),
              let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return nil
        }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard line >= 1, line <= lines.count else { return nil }
        let sourceLine = String(lines[line - 1])
        return wordAtColumn(column, in: sourceLine)
    }

    private func wordAtColumn(_ column: Int, in line: String) -> String? {
        let chars = Array(line)
        let idx = column - 1
        guard idx >= 0, idx < chars.count else { return nil }
        let wordChars = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        guard wordChars.contains(chars[idx]) else { return nil }

        var start = idx
        while start > 0, wordChars.contains(chars[start - 1]) { start -= 1 }
        var end = idx
        while end < chars.count - 1, wordChars.contains(chars[end + 1]) { end += 1 }
        return String(chars[start...end])
    }

    // MARK: - Definition

    private func findDefinition(_ symbol: String, projectPath: String) async throws -> ToolCallResult {
        let escaped = NSRegularExpression.escapedPattern(for: symbol)
        let pattern = #"(?:func|class|struct|enum|protocol|extension|actor|typealias|let|var|macro)\s+\#(escaped)\b"#

        let output = await searchWithRgOrGrep(pattern: pattern, projectPath: projectPath, context: 1, swiftOnly: true)
        if output.isEmpty {
            return ToolCallResult(id: UUID().uuidString, output: "未找到符号 '\(symbol)' 的定义")
        }
        return ToolCallResult(id: UUID().uuidString, output: "符号: \(symbol)\n\n\(output)")
    }

    // MARK: - References

    private func findReferences(_ symbol: String, projectPath: String) async throws -> ToolCallResult {
        let escaped = NSRegularExpression.escapedPattern(for: symbol)
        let pattern = #"\b\#(escaped)\b"#

        let raw = await searchWithRgOrGrep(pattern: pattern, projectPath: projectPath, context: 0, swiftOnly: false)
        if raw.isEmpty {
            return ToolCallResult(id: UUID().uuidString, output: "未找到符号 '\(symbol)' 的引用")
        }

        let defKeywords = ["func", "class", "struct", "enum", "protocol", "extension", "actor", "typealias", "let", "var", "macro"]
        let allLines = raw.split(separator: "\n", omittingEmptySubsequences: false)
        var seen = Set<String>()
        var refs: [String] = []

        for line in allLines {
            let text = String(line)

            // Skip definition lines
            let isDef = defKeywords.contains { keyword in
                // Match keyword followed by whitespace and the symbol
                text.contains("\(keyword) \(symbol)")
            }
            guard !isDef, seen.insert(text).inserted else { continue }
            refs.append(text)
        }

        if refs.isEmpty {
            return ToolCallResult(id: UUID().uuidString, output: "未找到符号 '\(symbol)' 的非定义引用")
        }

        var output = "符号: \(symbol)\n引用 (\(refs.count) 处):\n"
        for ref in refs.prefix(200) {
            output += "\n\(ref)"
        }
        if refs.count > 200 {
            output += "\n\n[结果截断至 200 行，共 \(refs.count) 行]"
        }
        return ToolCallResult(id: UUID().uuidString, output: output)
    }

    // MARK: - Hover

    private func hoverSymbol(_ symbol: String, projectPath: String) async throws -> ToolCallResult {
        let escaped = NSRegularExpression.escapedPattern(for: symbol)
        let pattern = #"(?:func|class|struct|enum|protocol|extension|actor|typealias|let|var|macro)\s+\#(escaped)\b"#

        let raw = await searchWithRgOrGrep(pattern: pattern, projectPath: projectPath, context: 0, swiftOnly: true)
        guard !raw.isEmpty, let match = parseFirstMatch(raw) else {
            return ToolCallResult(id: UUID().uuidString, output: "未找到符号 '\(symbol)' 的定义信息")
        }

        let defLine = "\(match.file):\(match.line):\(match.content)"
        let contextLines = readContextLines(filePath: match.file, line: match.line, radius: 3)

        var output = "符号: \(symbol)\n\n定义:\n\(defLine)\n"
        if !contextLines.isEmpty {
            output += "\n上下文:\n"
            for (n, text) in contextLines {
                let marker = n == match.line ? ">" : " "
                output += "\(marker) \(n): \(text)\n"
            }
        }
        return ToolCallResult(id: UUID().uuidString, output: output)
    }

    // MARK: - Search

    private func searchWithRgOrGrep(pattern: String, projectPath: String, context: Int, swiftOnly: Bool) async -> String {
        if let rg = await findBinary("rg") {
            return await searchWithRg(rg, pattern: pattern, projectPath: projectPath, context: context, swiftOnly: swiftOnly)
        }
        if let grep = await findBinary("grep") {
            return await searchWithGrep(grep, pattern: pattern, projectPath: projectPath, context: context, swiftOnly: swiftOnly)
        }
        return ""
    }

    private func searchWithRg(_ rg: String, pattern: String, projectPath: String, context: Int, swiftOnly: Bool) async -> String {
        var args = ["-n", "--no-heading", "--max-count=200"]
        if context > 0 { args += ["-C", String(context)] }
        if swiftOnly { args += ["-t", "swift"] }
        args += ["--", pattern, projectPath]
        return await runProcess(rg, args: args) ?? ""
    }

    private func searchWithGrep(_ grep: String, pattern: String, projectPath: String, context: Int, swiftOnly: Bool) async -> String {
        var args = ["-rn", "-E"]
        if swiftOnly { args += ["--include=*.swift"] }
        if context > 0 { args += ["-C", String(context)] }
        args += [pattern, projectPath]
        return await runProcess(grep, args: args) ?? ""
    }

    // MARK: - Parse Helpers

    private struct MatchResult {
        let file: String
        let line: Int
        let content: String
    }

    private func parseFirstMatch(_ raw: String) -> MatchResult? {
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false)
        for line in lines {
            let text = String(line)
            let parts = text.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count >= 3 else { continue }
            let file = String(parts[0])
            guard let lineNum = Int(parts[1]), lineNum > 0 else { continue }
            let content = String(parts[2])
            return MatchResult(file: file, line: lineNum, content: content)
        }
        return nil
    }

    private func readContextLines(filePath: String, line: Int, radius: Int) -> [(Int, String)] {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else { return [] }
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        let start = max(1, line - radius)
        let end = min(lines.count, line + radius)
        var result: [(Int, String)] = []
        for i in start...end {
            result.append((i, String(lines[i - 1])))
        }
        return result
    }

    // MARK: - Process Helpers

    private func runProcess(_ executable: String, args: [String]) async -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        let result = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { cont.resume(throwing: error) }
        }
        return result
    }

    private func findBinary(_ name: String) async -> String? {
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
