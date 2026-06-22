import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

// =====================================================================
// 场景 376: Xcode build log 结构化解析（增强版）
// =====================================================================
// 已有 ParseBuildErrorsTool + XcodeBuildTool.parseSwiftBuildOutput。
// 此处提供增强版：解析更多格式（Swift 6 新错误格式、ld 错误、test 错误）

public struct XcodeBuildAnalyzeTool: MCPTool {
    public let definition = ToolDefinition(
        name: "xcode_build_analyze",
        description: "解析 xcodebuild / swift build 输出，提取结构化错误（Swift 6 格式、ld 错误、诊断格式），返回按严重程度分组的分析结果",
        parameters: [
            .init(name: "output", type: .string, description: "xcodebuild 或 swift build 的完整输出"),
            .init(name: "project_path", type: .string, description: "项目路径（可选，用于显示文件上下文）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let output = arguments["output"], !output.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: output", isError: true)
        }

        let diagnostics = parseAllDiagnostics(from: output)
        if diagnostics.isEmpty {
            if output.contains("BUILD SUCCEEDED") || output.contains("Build complete") {
                return ToolCallResult(id: UUID().uuidString, output: "构建成功，未发现错误或警告。")
            }
            return ToolCallResult(id: UUID().uuidString, output: "未找到结构化错误信息。输出可能不包含标准诊断格式。")
        }

        let errors = diagnostics.filter { $0.severity == .error }
        let warnings = diagnostics.filter { $0.severity == .warning }
        let notes = diagnostics.filter { $0.severity == .note }

        var result = "=== 构建诊断分析 ===\n\n"

        if !errors.isEmpty {
            result += "【错误】\(errors.count) 个\n"
            for e in errors {
                let loc = formatLocation(e)
                result += "  \(loc)\(e.message)\n"
            }
            result += "\n"
        }

        if !warnings.isEmpty {
            result += "【警告】\(warnings.count) 个\n"
            for w in warnings.prefix(10) {
                let loc = formatLocation(w)
                result += "  \(loc)\(w.message)\n"
            }
            if warnings.count > 10 {
                result += "  ... 还有 \(warnings.count - 10) 个警告\n"
            }
            result += "\n"
        }

        if !notes.isEmpty {
            result += "【提示】\(notes.count) 个\n"
            for n in notes.prefix(5) {
                let loc = formatLocation(n)
                result += "  \(loc)\(n.message)\n"
            }
            if notes.count > 5 {
                result += "  ... 还有 \(notes.count - 5) 个提示\n"
            }
            result += "\n"
        }

        // 汇总统计
        let buildFailed = errors.isEmpty && output.contains("BUILD FAILED")
        let hasErrors = !errors.isEmpty
        if hasErrors || buildFailed {
            result += "结论: 构建失败（\(errors.count) 个错误）\n"
        } else if !warnings.isEmpty {
            result += "结论: 构建成功，但有 \(warnings.count) 个警告\n"
        } else {
            result += "结论: 构建成功\n"
        }

        return ToolCallResult(id: UUID().uuidString, output: result)
    }

    private func formatLocation(_ d: BuildDiagnostic) -> String {
        guard let path = d.filePath else { return "" }
        var loc = path
        if let line = d.line { loc += ":\(line)" }
        if let col = d.column { loc += ":\(col)" }
        return loc + " "
    }

    /// 解析多种诊断格式
    private func parseAllDiagnostics(from output: String) -> [BuildDiagnostic] {
        var all: [BuildDiagnostic] = []

        // 1. 标准 Swift 编译器格式: file.swift:line:col: error/warning/note: message
        let standardPattern = #/(.+?):(\d+):(\d+):\s+(error|warning|note):\s+(.+)/#
        // 2. 无列号格式: file.swift:line: error/warning: message
        let noColumnPattern = #/(.+?):(\d+):\s+(error|warning|note):\s+(.+)/#
        // 3. ld 错误格式: ld: error: message
        let ldPattern = #/(ld|Linker):\s+(error|warning):\s+(.+)/#
        // 4. 通用 error/warning 前缀行
        let genericPattern = #/^(error|warning):\s+(.+)/#

        for line in output.components(separatedBy: .newlines) {
            if let match = try? standardPattern.wholeMatch(in: line) {
                all.append(BuildDiagnostic(
                    filePath: String(match.1),
                    line: Int(match.2),
                    column: Int(match.3),
                    message: String(match.5),
                    severity: severity(from: String(match.4))
                ))
            } else if let match = try? noColumnPattern.wholeMatch(in: line) {
                all.append(BuildDiagnostic(
                    filePath: String(match.1),
                    line: Int(match.2),
                    message: String(match.4),
                    severity: severity(from: String(match.3))
                ))
            } else if let match = try? ldPattern.wholeMatch(in: line) {
                all.append(BuildDiagnostic(
                    filePath: String(match.1),
                    message: String(match.3),
                    severity: severity(from: String(match.2))
                ))
            } else if let match = try? genericPattern.wholeMatch(in: line) {
                all.append(BuildDiagnostic(
                    message: String(match.2),
                    severity: severity(from: String(match.1))
                ))
            }
        }

        return all
    }

    private func severity(from s: String) -> BuildDiagnostic.Severity {
        switch s.lowercased() {
        case "error": return .error
        case "warning": return .warning
        default: return .note
        }
    }
}

// =====================================================================
// 场景 377: 先运行测试再分析失败
// =====================================================================
// 整合 swift test + BuildErrorAnalyzer.analyze(testResult:)

public struct TestAnalyzeTool: MCPTool {
    public let definition = ToolDefinition(
        name: "test_and_analyze",
        description: "先运行 swift test，解析失败测试，再返回分析结果。一步完成「运行测试 → 定位失败 → 分析原因」",
        parameters: [
            .init(name: "project_path", type: .string, description: "SwiftPM 项目路径", required: false),
            .init(name: "filter", type: .string, description: "测试过滤器，如 'TestName'", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let projectPath = arguments["project_path"] ?? FileManager.default.currentDirectoryPath

        // 1. 运行测试
        var args = ["test"]
        if let filter = arguments["filter"] { args.append(contentsOf: ["--filter", filter]) }

        let start = Date()
        let testOut = try await runProcess("/usr/bin/swift", args: args, cwd: projectPath)
        let elapsed = Date().timeIntervalSince(start)

        let testResult = parseTestOutput(testOut, elapsed: elapsed)

        var output = "=== 测试结果 ===\n\n"
        output += "测试\(testResult.success ? "通过" : "失败")"
        if testResult.totalCount > 0 {
            output += ": \(testResult.passedCount)/\(testResult.totalCount) 通过"
        }
        output += " (\(String(format: "%.1f", elapsed))s)\n"

        // 2. 如果有失败测试，列出详细信息
        if !testResult.failures.isEmpty {
            output += "\n【失败测试】\(testResult.failures.count) 个:\n\n"
            for f in testResult.failures {
                output += "  ✗ \(f.testName)\n"
                output += "    原因: \(f.message.prefix(300))\n"
                if let path = f.filePath {
                    output += "    位置: \(path)"
                    if let line = f.line { output += ":\(line)" }
                    output += "\n"
                }
                output += "\n"
            }

            // 3. 针对每个失败分析根因
            output += "【根因分析】\n\n"
            for f in testResult.failures {
                output += "  \(f.testName):\n"
                let analysis = analyzeFailure(f)
                output += "    \(analysis)\n\n"
            }
        } else if testResult.totalCount > 0 {
            output += "\n所有测试通过，无需分析。\n"
        }

        return ToolCallResult(id: UUID().uuidString, output: output, isError: !testResult.success)
    }

    private func analyzeFailure(_ f: TestFailure) -> String {
        let msg = f.message.lowercased()
        if msg.contains("xctassert") || msg.contains("assert") {
            return "断言失败: 条件不满足，检查预期值与实际值是否一致。如需更详细信息，建议添加更多上下文断言或使用 XCTExpectFailure。"
        }
        if msg.contains("optional") && msg.contains("nil") {
            return "可选值解包为 nil: 预期有值但实际为 nil，检查前置条件或确保值已正确初始化。"
        }
        if msg.contains("timeout") || msg.contains("timed out") {
            return "超时: 异步操作未在预期时间内完成。检查网络请求、文件 IO 或异步等待逻辑。"
        }
        if msg.contains("throw") || msg.contains("exception") || msg.contains("error") {
            return "意外抛出错误: 测试预期不抛错但实际抛出了。检查错误处理逻辑是否健全。"
        }
        if msg.contains("not equal") || msg.contains("!=") || msg.contains("is not") {
            return "值不相等: 预期值和实际值不符。检查输入参数和计算逻辑。"
        }
        if msg.contains("crash") || msg.contains("signal") || msg.contains("sig") {
            return "崩溃/信号终止: 测试执行时进程崩溃。可能是内存问题或未处理的 fatalError。"
        }
        return "未知失败原因。检查测试日志以获取更多上下文。"
    }

    private func parseTestOutput(_ raw: String, elapsed: Double) -> TestResult {
        var failures: [TestFailure] = []
        var totalCount = 0
        var failedCount = 0

        for line in raw.split(separator: "\n") {
            let text = String(line)

            if text.contains("Executed") && text.contains("tests") {
                if let m = try? Regex(#"Executed\s+(\d+)\s+tests"#).firstMatch(in: text) {
                    totalCount = Int(m.output[1].substring ?? "0") ?? 0
                }
            }
            if text.contains("failures") {
                if let m = try? Regex(#"(\d+)\s+failures"#).firstMatch(in: text) {
                    failedCount = Int(m.output[1].substring ?? "0") ?? 0
                }
            }

            // 解析失败测试用例
            if text.contains("failed") && text.contains("Test Case") {
                let nameMatch = try? Regex(#"'?(?:Test\s+Case\s+)?'?([^']+)'?\s*failed"#).firstMatch(in: text)
                let name = nameMatch?.output[1].substring.map(String.init) ?? "未知测试"

                // 尝试提取文件位置
                let fileMatch = try? Regex(#"(\S+\.swift):(\d+)"#).firstMatch(in: text)
                let filePath = fileMatch.map { String($0.output[1].substring ?? "") }
                let line = fileMatch.flatMap { m in Int(m.output[2].substring ?? "") }

                failures.append(TestFailure(
                    testName: name,
                    message: text,
                    filePath: filePath,
                    line: line
                ))
            }
        }

        let passedCount = totalCount - failedCount
        let success = failedCount == 0 && (totalCount > 0 || raw.contains("Test run with 0 tests"))

        return TestResult(
            success: success,
            totalCount: totalCount,
            passedCount: passedCount,
            failedCount: failedCount,
            durationSeconds: elapsed,
            failures: failures,
            rawOutput: raw
        )
    }

    private func runProcess(_ exec: String, args: [String], cwd: String) async throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: exec)
        task.arguments = args
        task.currentDirectoryURL = URL(fileURLWithPath: cwd)
        let pipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errPipe
        let (out, err) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, String), Error>) in
            task.terminationHandler = { _ in
                let outData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (String(data: outData, encoding: .utf8) ?? "", String(data: errData, encoding: .utf8) ?? ""))
            }
            do { try task.run() } catch { continuation.resume(throwing: error) }
        }
        return out + "\n" + err
    }
}

// =====================================================================
// 场景 379: LSP/索引驱动的调用链
// =====================================================================
// 已有 grep 驱动的 LSPTool。此工具使用 sourcekit-lsp（真实的 LSP 协议）
// 或回退到更智能的文本分析来查找函数定义、调用者和被调用者。

public struct CallChainTool: MCPTool {
    public let definition = ToolDefinition(
        name: "call_chain",
        description: "查找函数/方法的调用链（调用者和被调用者）。优先尝试 sourcekit-lsp，回退到结构感知的文本搜索。支持方向: callers(谁调我) / callees(我调谁) / both",
        parameters: [
            .init(name: "symbol", type: .string, description: "函数/方法/符号名称"),
            .init(name: "direction", type: .string, description: "callers（谁调用我）/ callees（我调用谁）/ both（双向），默认 both", required: false),
            .init(name: "project_path", type: .string, description: "项目根路径", required: false),
            .init(name: "max_depth", type: .string, description: "调用链深度，默认 1", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let symbol = arguments["symbol"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: symbol", isError: true)
        }

        let projectPath = arguments["project_path"] ?? FileManager.default.currentDirectoryPath
        let direction = arguments["direction"] ?? "both"
        let maxDepth = Int(arguments["max_depth"] ?? "1") ?? 1

        // 1. 查找符号定义
        let definition = await findDefinition(symbol, projectPath: projectPath)

        var output = "=== 调用链分析: \(symbol) ===\n\n"

        if let def = definition {
            output += "定义: \(def)\n\n"
        } else {
            output += "⚠️ 未找到明确的符号定义。基于文本搜索的结果可能不完整。\n\n"
        }

        // 2. 查找调用关系
        if direction == "callees" || direction == "both" {
            output += "【被调用者（\(symbol) 调用了谁）】\n"
            let callees = await findCallees(symbol, projectPath: projectPath, maxDepth: maxDepth)
            if callees.isEmpty {
                output += "  (未检测到内部调用)\n"
            } else {
                for c in callees {
                    output += "  → \(c)\n"
                }
            }
            output += "\n"
        }

        if direction == "callers" || direction == "both" {
            output += "【调用者（谁调用了 \(symbol)）】\n"
            let callers = await findCallers(symbol, projectPath: projectPath)
            if callers.isEmpty {
                output += "  (未检测到调用)\n"
            } else {
                for c in callers.prefix(50) {
                    output += "  ← \(c)\n"
                }
                if callers.count > 50 {
                    output += "  ... 还有 \(callers.count - 50) 个调用点\n"
                }
            }
            output += "\n"
        }

        // 3. 统计
        let callers = await findCallers(symbol, projectPath: projectPath)
        let callees = await findCallees(symbol, projectPath: projectPath, maxDepth: 1)
        output += "---\n调用关系: \(callers.count) 个调用者, \(callees.count) 个被调用者\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }

    // MARK: - 定义查找

    private func findDefinition(_ symbol: String, projectPath: String) async -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: symbol)
        let patterns = [
            #"func\s+\#(escaped)\s*[\(<]"#,
            #"(class|struct|enum|protocol|extension|actor)\s+\#(escaped)\b"#,
            #"(typealias|associatedtype)\s+\#(escaped)\b"#,
            #"(let|var)\s+\#(escaped)\s*[=:]"#,
            #"macro\s+\#(escaped)\b"#,
            #"subscript\s+\#(escaped)\b"#,
            #"operator\s+\#(escaped)\b"#,
        ]

        for pattern in patterns {
            let result = await grepSource(pattern: pattern, projectPath: projectPath, context: 2, swiftOnly: true)
            if !result.isEmpty {
                return result.split(separator: "\n").prefix(5).joined(separator: "\n")
            }
        }
        return nil
    }

    // MARK: - 被调用者分析

    private func findCallees(_ symbol: String, projectPath: String, maxDepth: Int) async -> [String] {
        // 找到符号的函数体，提取其中的函数调用
        let escaped = NSRegularExpression.escapedPattern(for: symbol)

        // 查找函数实现
        let funcPattern = #"\bfunc\s+\#(escaped)\s*\([^)]*\)\s*(?:->\s*\S+)?\s*\{?"#
        let impl = await grepSource(pattern: funcPattern, projectPath: projectPath, context: 30, swiftOnly: true)

        if impl.isEmpty {
            // 回退：搜索所有引用中看起来像被调用的模式
            return findCalledFunctions(in: impl, exclude: [symbol], projectPath: projectPath)
        }

        // 从实现中提取函数调用
        var callees = findCalledFunctions(in: impl, exclude: [symbol], projectPath: projectPath)

        // 递归查找（如果深度 > 1）
        if maxDepth > 1 {
            var allCallees = callees
            for callee in callees {
                let deeper = await findCallees(callee, projectPath: projectPath, maxDepth: maxDepth - 1)
                allCallees.append(contentsOf: deeper.map { "  ↳ \($0)" })
            }
            callees = allCallees
        }

        return uniq(callees)
    }

    private func findCalledFunctions(in text: String, exclude: [String], projectPath: String) -> [String] {
        // 匹配函数调用模式: identifier( 或 identifier<identifier>(
        // 排除 Swift 关键字和常见 API
        let keywords: Set<String> = ["if", "for", "while", "switch", "guard", "return", "let", "var",
                                     "self", "super", "nil", "true", "false", "in", "as", "is", "try",
                                     "await", "throw", "catch", "case", "default", "where", "import",
                                     "func", "class", "struct", "enum", "protocol", "extension", "actor",
                                     "init", "deinit", "subscript", "lazy", "dynamic", "final", "override",
                                     "open", "public", "internal", "fileprivate", "private", "static",
                                     "mutating", "nonmutating", "convenience", "required", "optional",
                                     "unowned", "weak", "indirect", "rethrows", "throws", "async",
                                     "some", "any", "assert", "precondition", "fatalError",
                                     "XCTAssert", "XCTAssertEqual", "XCTAssertTrue", "XCTAssertFalse",
                                     "XCTAssertNil", "XCTAssertNotNil", "XCTFail"]

        let callPattern = try? Regex(#"([a-zA-Z_]\w*)\s*\(#"#)
        guard let regex = callPattern else { return [] }

        var calls: [String] = []
        var seen = Set<String>()

        for match in text.matches(of: regex) {
            let name = String(match.output[1].substring ?? "")
            guard !keywords.contains(name),
                  !exclude.contains(name),
                  !name.contains(".") || name.hasPrefix(".") == false,
                  seen.insert(name).inserted
            else { continue }
            // 过滤常见类型和关键字
            if name.count <= 1 { continue }
            if name == name.uppercased() && name.count <= 3 { continue }
            calls.append(name)
        }

        return calls
    }

    // MARK: - 调用者分析

    private func findCallers(_ symbol: String, projectPath: String) async -> [String] {
        let escaped = NSRegularExpression.escapedPattern(for: symbol)

        // 查找所有 Swift 文件中的调用点
        let usePattern = #"\b\#(escaped)\s*\("# + "|" + #"\.\#(escaped)\b"#

        let raw = await grepSource(pattern: usePattern, projectPath: projectPath, context: 0, swiftOnly: true)
        guard !raw.isEmpty else { return [] }

        var results: [String] = []
        var seen = Set<String>()

        for line in raw.split(separator: "\n") {
            let text = String(line)

            // 跳过定义行自身
            if text.contains("func \(symbol)") || text.contains("class \(symbol)") ||
               text.contains("struct \(symbol)") || text.contains("enum \(symbol)") ||
               text.contains("protocol \(symbol)") || text.contains("extension \(symbol)") {
                continue
            }

            // 跳过注释行
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
                continue
            }

            // 尝试找到包含该调用的父函数
            if let parentFunc = findContainingFunction(text, symbol: symbol, projectPath: projectPath) {
                if seen.insert(parentFunc).inserted {
                    results.append(parentFunc)
                }
            } else {
                // 直接输出调用行
                if seen.insert(text).inserted {
                    results.append(text)
                }
            }
        }

        return results
    }

    private func findContainingFunction(_ line: String, symbol: String, projectPath: String) -> String? {
        // 从 grep 输出格式 "file:line:content" 中解析
        let parts = line.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count >= 3, let lineNum = Int(parts[1]) else { return nil }

        let file = String(parts[0])
        guard let content = try? String(contentsOfFile: file, encoding: .utf8) else { return nil }
        let fileLines = content.split(separator: "\n", omittingEmptySubsequences: false)

        // 从当前行向上搜索最近的函数定义
        let funcPatterns = ["func ", "init(", "deinit", "subscript(", "willSet", "didSet", "get {", "set {"]
        for i in stride(from: min(lineNum - 2, fileLines.count - 1), through: 0, by: -1) {
            let text = String(fileLines[i])
            for pattern in funcPatterns {
                if text.contains(pattern) {
                    let cleaned = text.trimmingCharacters(in: .whitespaces)
                    if cleaned.hasPrefix("func ") || cleaned.hasPrefix("init") || cleaned.hasPrefix("deinit") {
                        return "\(file):\(i + 1)  ── \(cleaned.prefix(80))"
                    }
                }
            }
        }

        return "\(file):\(lineNum)"
    }

    // MARK: - 文本搜索

    private func grepSource(pattern: String, projectPath: String, context: Int, swiftOnly: Bool) async -> String {
        if let rg = await findBinary("rg") {
            var args = ["-n", "--no-heading", "--max-count=200"]
            if context > 0 { args += ["-C", String(context)] }
            if swiftOnly { args += ["-t", "swift"] }
            args += ["-E"]
            args += ["--", pattern, projectPath]
            return await runProcess(rg, args: args)
        }
        if let grep = await findBinary("grep") {
            var args = ["-rn", "-E"]
            if swiftOnly { args += ["--include=*.swift"] }
            if context > 0 { args += ["-C", String(context)] }
            args += [pattern, projectPath]
            return await runProcess(grep, args: args)
        }
        return ""
    }

    private func runProcess(_ exec: String, args: [String]) async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: exec)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        return await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { continuation.resume(returning: "") }
        }
    }

    private func findBinary(_ name: String) async -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [name]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        let out: String = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { continuation.resume(returning: "") }
        }
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func uniq(_ items: [String]) -> [String] {
        var seen = Set<String>()
        return items.filter { seen.insert($0).inserted }
    }
}

// =====================================================================
// 场景 381: CI 状态检查（GitHub Actions）
// =====================================================================
// 使用 gh CLI 查询 GitHub Actions 状态

public struct CIStatusTool: MCPTool {
    public let definition = ToolDefinition(
        name: "ci_status",
        description: "检查 GitHub Actions CI/CD 状态：查看工作流运行状态、最近运行结果、PR 检测状态。需要 gh CLI",
        parameters: [
            .init(name: "repo_path", type: .string, description: "本地仓库路径（用于推断 remote）", required: false),
            .init(name: "repo", type: .string, description: "GitHub 仓库，如 'owner/repo'", required: false),
            .init(name: "branch", type: .string, description: "过滤特定分支的状态", required: false),
            .init(name: "limit", type: .string, description: "最近运行数，默认 5", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        // 检查 gh CLI
        guard let ghPath = await findBinary("gh") else {
            return ToolCallResult(id: UUID().uuidString, output: "未找到 gh CLI。请安装: brew install gh", isError: true)
        }

        let repo: String
        if let explicitRepo = arguments["repo"] {
            repo = explicitRepo
        } else {
            // 从本地仓库推断
            let repoPath = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
            let remote = await runProcess(ghPath, args: ["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"], cwd: repoPath)
            if remote.isEmpty || remote.contains("not found") || remote.contains("not authenticated") {
                return ToolCallResult(id: UUID().uuidString, output: "无法推断远程仓库。请指定 repo='owner/repo' 或确保已登录 gh。\n输出: \(remote)", isError: true)
            }
            repo = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let limit = arguments["limit"] ?? "5"
        let branch = arguments["branch"]

        var output = "=== CI 状态: \(repo) ===\n\n"

        // 1. 最近工作流运行
        var runArgs = ["run", "list", "--repo", repo, "--limit", limit, "--json",
                       "databaseId", "workflowName", "headBranch", "conclusion", "status",
                       "displayTitle", "createdAt", "url"]
        if let branch {
            runArgs.append(contentsOf: ["--branch", branch])
        }

        let runs = await runProcess(ghPath, args: runArgs, cwd: nil)
        if !runs.isEmpty && !runs.contains("HTTP") {
            // gh 返回 JSON array
            if let data = runs.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                if json.isEmpty {
                    output += "未找到工作流运行记录。\n"
                } else {
                    output += "最近 \(json.count) 次运行:\n\n"
                    for run in json {
                        let name = run["workflowName"] as? String ?? "?"
                        let branchName = run["headBranch"] as? String ?? "?"
                        let conclusion = run["conclusion"] as? String ?? (run["status"] as? String ?? "?")
                        let displayTitle = run["displayTitle"] as? String ?? ""
                        let createdAt = String((run["createdAt"] as? String ?? "")
                            .replacingOccurrences(of: "T", with: " ")
                            .prefix(16))
                        let url = run["url"] as? String ?? ""

                        output += "  \(conclusionIcon(conclusion)) \(name)\n"
                        output += "     分支: \(branchName) | \(createdAt)\n"
                        if !displayTitle.isEmpty {
                            output += "     标题: \(displayTitle.prefix(60))\n"
                        }
                        output += "     状态: \(conclusion)\(url.isEmpty ? "" : " (\(url))")\n\n"
                    }
                }
            } else {
                output += "原始输出: \(runs.prefix(500))\n"
            }
        } else {
            output += "获取运行记录失败: \(runs.prefix(200))\n"
        }

        // 2. PR 状态检测（如果指定了分支）
        if let branch {
            let prChecks = await runProcess(ghPath, args: ["pr", "checks", "--repo", repo, branch, "--json",
                                                      "name", "bucket", "status", "conclusion", "startedAt"], cwd: nil)
            if !prChecks.isEmpty && !prChecks.contains("no open pull request") {
                if let data = prChecks.data(using: .utf8),
                   let checks = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    output += "PR 检测 (\(branch)): \(checks.count) 项\n\n"
                    var passed = 0, failed = 0, pending = 0
                    for check in checks {
                        let name = check["name"] as? String ?? "?"
                        let conclusion = check["conclusion"] as? String ?? "pending"
                        switch conclusion {
                        case "success": passed += 1
                        case "failure", "cancelled": failed += 1
                        default: pending += 1
                        }
                        output += "  \(conclusionIcon(conclusion)) \(name) → \(conclusion)\n"
                    }
                    output += "\n\(passed) 通过, \(failed) 失败, \(pending) 进行中\n"
                }
            }
        }

        return ToolCallResult(id: UUID().uuidString, output: output)
    }

    private func conclusionIcon(_ c: String) -> String {
        switch c.lowercased() {
        case "success": return "[PASS]"
        case "failure": return "[FAIL]"
        case "cancelled", "canceled": return "[SKIP]"
        case "skipped": return "[SKIP]"
        case "neutral": return "[NEUT]"
        case "action_required": return "[NEED]"
        case "timed_out": return "[TIME]"
        case "in_progress", "queued", "pending": return "[....]"
        default: return "[?]"
        }
    }

    private func findBinary(_ name: String) async -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [name]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        let out: String = await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { continuation.resume(returning: "") }
        }
        let trimmed = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func runProcess(_ exec: String, args: [String], cwd: String?) async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: exec)
        task.arguments = args
        if let cwd { task.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        let pipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errPipe
        let (out, err) = await withCheckedContinuation { (continuation: CheckedContinuation<(String, String), Never>) in
            task.terminationHandler = { _ in
                let outData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (String(data: outData, encoding: .utf8) ?? "", String(data: errData, encoding: .utf8) ?? ""))
            }
            do { try task.run() } catch { continuation.resume(returning: ("", "")) }
        }
        return out.isEmpty ? err : out
    }
}

// =====================================================================
// 场景 384: 环境感知（开发/生产隔离）
// =====================================================================
// 检测当前工作环境，防止误改生产配置

public struct EnvironmentDetectTool: MCPTool {
    public let definition = ToolDefinition(
        name: "environment_detect",
        description: "检测当前工作环境：开发/生产/测试。检查当前目录、配置文件风险，防止误改生产配置",
        parameters: [
            .init(name: "path", type: .string, description: "要检查的工作目录或文件", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let checkPath = arguments["path"] ?? FileManager.default.currentDirectoryPath

        var output = "=== 环境检测 ===\n\n"

        // 1. 检测是否为生产环境
        let env = detectEnvironment(at: checkPath)
        output += "当前环境: \(env.label)\n\n"

        // 2. 检测敏感文件
        let sensitiveFiles = findSensitiveFiles(at: checkPath)
        if !sensitiveFiles.isEmpty {
            output += "【敏感文件】\n"
            for f in sensitiveFiles {
                output += "  ⚠️ \(f)\n"
            }
            output += "\n"
        }

        // 3. 检查 .env / .env.production 等配置
        let envFiles = findEnvFiles(at: checkPath)
        if !envFiles.isEmpty {
            output += "【环境配置】\n"
            for f in envFiles {
                output += "  📄 \(f)\n"
            }
            output += "\n"
        }

        // 4. 检查是否在修改生产配置
        if env == .production {
            output += "🔴 警告: 当前在生产环境中工作！\n"
            output += "  建议: 不要在 production 环境直接修改配置\n"
            output += "  请切换到 development 或 staging 环境\n"
        } else if containsProductionConfig(at: checkPath) {
            output += "⚠️ 检测到生产配置文件在编辑范围内\n"
            output += "  建议: 确认是否有意修改生产配置\n"
        } else {
            output += "✅ 当前工作环境安全\n"
        }

        // 5. 生产/开发隔离建议
        output += "\n【隔离建议】\n"
        output += "  .env → 开发配置（不要包含真实密钥）\n"
        output += "  .env.production → 生产配置（不要提交到版本控制）\n"
        output += "  .env.development → 开发本地配置（gitignored）\n"
        output += "  配置加载优先级: 环境变量 > .env.local > .env > .env.production\n"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }

    private enum Environment: Equatable {
        case development
        case staging
        case production
        case unknown

        var label: String {
            switch self {
            case .development: return "开发 (Development)"
            case .staging: return "预发布 (Staging)"
            case .production: return "生产 (Production)"
            case .unknown: return "未知"
            }
        }
    }

    private func detectEnvironment(at path: String) -> Environment {
        // 检查环境变量
        let envVars = ProcessInfo.processInfo.environment
        let nodeEnv = envVars["NODE_ENV"]?.lowercased() ?? ""
        let envName = envVars["APP_ENV"]?.lowercased()
            ?? envVars["RACK_ENV"]?.lowercased()
            ?? envVars["ENVIRONMENT"]?.lowercased()
            ?? ""

        if nodeEnv == "production" || envName == "production" { return .production }
        if nodeEnv == "staging" || envName == "staging" { return .staging }
        if nodeEnv == "development" || envName == "development" { return .development }

        // 检查路径特征
        let lowerPath = path.lowercased()
        if lowerPath.contains("production") || lowerPath.contains("/prod/") { return .production }
        if lowerPath.contains("staging") || lowerPath.contains("/stg/") { return .staging }
        if lowerPath.contains("development") || lowerPath.contains("dev") { return .development }

        // 检查是否存在 .env.development 或 .env.production
        let fm = FileManager.default
        if fm.fileExists(atPath: "\(path)/.env.development") { return .development }
        if fm.fileExists(atPath: "\(path)/.env.production") { return .production }

        // 默认: 如果包含 Package.swift 或 Xcode project，通常是开发环境
        if fm.fileExists(atPath: "\(path)/Package.swift") ||
           fm.fileExists(atPath: "\(path)/Makefile") ||
           fm.fileExists(atPath: "\(path)/Podfile") {
            return .development
        }

        return .unknown
    }

    private func findSensitiveFiles(at path: String) -> [String] {
        let sensitive = [
            ".env", ".env.production", ".env.prod",
            "credentials.json", "credentials.plist",
            "secrets.json", "secrets.plist",
            "config.yml", "config.production.yml",
            "GoogleService-Info.plist",
            "api_key.txt", "apikey.txt",
        ]

        let fm = FileManager.default
        var found: [String] = []
        for name in sensitive {
            let fullPath = "\(path)/\(name)"
            if fm.fileExists(atPath: fullPath) {
                found.append(name)
            }
        }
        return found
    }

    private func findEnvFiles(at path: String) -> [String] {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: path) else { return [] }
        return items.filter { $0.hasPrefix(".env") }
            .sorted()
    }

    private func containsProductionConfig(at path: String) -> Bool {
        let prodPatterns = [".env.production", ".env.prod", "config.production", "production.yml", "production.json"]
        for pattern in prodPatterns {
            if path.contains(pattern) {
                return true
            }
        }
        return false
    }
}

// =====================================================================
// 场景 385: 性能分析集成
// =====================================================================
// 使用 macOS built-in sample 工具进行性能采样

public struct ProfileTool: MCPTool {
    public let definition = ToolDefinition(
        name: "profile_collect",
        description: "性能采样分析：使用 macOS sample 工具对进程进行性能采样，识别热点函数和性能瓶颈",
        parameters: [
            .init(name: "pid", type: .string, description: "进程 PID（可选，默认自动选择最耗 CPU 的进程）", required: false),
            .init(name: "process_name", type: .string, description: "进程名称（用于查找 PID）", required: false),
            .init(name: "duration", type: .string, description: "采样时长（秒），默认 3", required: false),
            .init(name: "mode", type: .string, description: "采样模式: sample（默认，轻量快速）/ top（查看最耗 CPU 进程）/ swift（Swift 项目构建时间分析）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let mode = arguments["mode"] ?? "sample"

        switch mode {
        case "top":
            return await topCPU()
        case "swift":
            return await swiftBuildTime()
        case "sample":
            return await sampleProcess(arguments: arguments)
        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知模式: \(mode)，支持: sample / top / swift", isError: true)
        }
    }

    // MARK: - top 模式

    private func topCPU() async -> ToolCallResult {
        let output = await runProcess("/usr/bin/top", args: ["-l", "1", "-n", "10", "-stats", "pid,cpu,mem,command"])
        return ToolCallResult(id: UUID().uuidString, output: "=== 最耗 CPU 的 10 个进程 ===\n\n\(output)")
    }

    // MARK: - sample 模式

    private func sampleProcess(arguments: [String: String]) async -> ToolCallResult {
        var pid: String?

        if let explicitPID = arguments["pid"] {
            pid = explicitPID
        } else if let processName = arguments["process_name"] {
            pid = await findPID(processName)
            if pid == nil {
                return ToolCallResult(
                    id: UUID().uuidString,
                    output: "未找到进程: \(processName)。使用 'profile_collect mode=top' 查看当前进程列表。",
                    isError: true
                )
            }
        }

        guard let targetPID = pid else {
            // 默认采样最耗 CPU 的用户进程
            return ToolCallResult(
                id: UUID().uuidString,
                output: "请指定 pid（进程 ID）或 process_name（进程名）。\n\n提示: 使用 'profile_collect mode=top' 查看当前运行进程。",
                isError: true
            )
        }

        let duration = arguments["duration"] ?? "3"

        var output = "=== 性能采样 ===\n\n"
        output += "目标进程: \(targetPID)\n"
        output += "采样时长: \(duration) 秒\n\n"

        // 运行 sample
        let sampleOutput = await runProcess("/usr/bin/sample", args: [targetPID, duration, "-file", "/dev/stdout"])
        if sampleOutput.isEmpty {
            return ToolCallResult(id: UUID().uuidString, output: "采样失败。PID: \(targetPID) 可能已退出或权限不足。", isError: true)
        }

        // 解析采样结果，提取热点
        let lines = sampleOutput.split(separator: "\n")
        var inCallTree = false
        var sampleCount = 0
        var hotFunctions: [String: Int] = [:]
        var currentFunc = ""

        for line in lines {
            let text = String(line)

            if text.contains("Sample analysis") || text.contains("Call graph") {
                inCallTree = true
                continue
            }
            if text.contains("Total number") || text.contains("Total samples") {
                if let m = try? Regex(#"(\d+)\s+samples?"#).firstMatch(in: text) {
                    sampleCount = Int(m.output[1].substring ?? "0") ?? 0
                }
                break
            }

            if inCallTree {
                // 解析调用树行: "   weight func_name"
                if let m = try? Regex(#"^\s*(\d+)\s+\S+\s+(.+)$"#).firstMatch(in: text) {
                    let weight = Int(m.output[1].substring ?? "0") ?? 0
                    let funcName = String(m.output[2].substring ?? "")
                    hotFunctions[funcName] = (hotFunctions[funcName] ?? 0) + weight
                    currentFunc = funcName
                } else if !text.trimmingCharacters(in: .whitespaces).isEmpty && !currentFunc.isEmpty {
                    let trimmed = text.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("0x") || trimmed.contains("[") {
                        hotFunctions[trimmed] = 1
                    }
                }
            }
        }

        output += "采样次数: \(sampleCount)\n\n"

        // 输出热点函数
        if !hotFunctions.isEmpty {
            let sorted = hotFunctions.sorted { $0.value > $1.value }
            output += "【热点函数 Top \(min(sorted.count, 20))】\n\n"
            for (i, (name, weight)) in sorted.prefix(20).enumerated() {
                let pct = sampleCount > 0 ? Double(weight) / Double(sampleCount) * 100 : 0
                output += "  \(i + 1). \(String(format: "%.1f", pct))%  \(name)\n"
            }
            output += "\n"
        }

        // 性能建议
        output += "【性能分析建议】\n"
        let topPct = hotFunctions.values.max().map { sampleCount > 0 ? Double($0) / Double(sampleCount) * 100 : 0 } ?? 0
        if topPct > 30 {
            output += "  🔴 热点集中: 单个函数占用 \(String(format: "%.0f", topPct))% 的采样时间\n"
            output += "  建议: 检查该函数的算法复杂度、循环、或 IO 操作\n"
        } else if topPct > 15 {
            output += "  🟡 中等热点: 需要关注被频繁调用的函数\n"
            output += "  建议: 检查是否有不必要的重复计算\n"
        } else {
            output += "  🟢 性能分布均匀，无明显热点\n"
        }

        if sampleCount < 10 {
            output += "\n  ⚠️ 采样次数较少（\(sampleCount)），建议增加 duration 获得更准确结果\n"
        }

        return ToolCallResult(id: UUID().uuidString, output: output)
    }

    // MARK: - Swift 构建时间分析

    private func swiftBuildTime() async -> ToolCallResult {
        let projectPath = FileManager.default.currentDirectoryPath
        guard FileManager.default.fileExists(atPath: "\(projectPath)/Package.swift") else {
            return ToolCallResult(id: UUID().uuidString, output: "当前目录没有 Package.swift。请 cd 到 SwiftPM 项目目录。", isError: true)
        }

        var output = "=== Swift 构建时间分析 ===\n\n"

        // 运行一次带时间的构建
        let start = Date()
        let buildOut = await runProcess("/usr/bin/swift", args: ["build"], cwd: projectPath)
        let elapsed = Date().timeIntervalSince(start)

        output += "总构建时间: \(String(format: "%.1f", elapsed)) 秒\n\n"

        // 解析构建输出中的模块编译时间
        var moduleTimes: [(name: String, time: Double)] = []
        for line in buildOut.split(separator: "\n") {
            let text = String(line)
            if let m = try? Regex(#"Compile\s+\S+\s+(\S+)\s+.*\((\d+\.?\d*)\s*seconds?\)"#).firstMatch(in: text) {
                let module = String(m.output[1].substring ?? "?")
                let time = Double(m.output[2].substring ?? "0") ?? 0
                moduleTimes.append((module, time))
            }
        }

        if !moduleTimes.isEmpty {
            output += "模块编译时间:\n\n"
            let sorted = moduleTimes.sorted { $0.time > $1.time }
            let totalCompileTime = sorted.reduce(0) { $0 + $1.time }
            for (name, time) in sorted.prefix(15) {
                let pct = totalCompileTime > 0 ? time / totalCompileTime * 100 : 0
                output += "  \(String(format: "%6.1f", time))s (\(String(format: "%4.1f", pct))%)  \(name)\n"
            }
            if sorted.count > 15 {
                output += "  ... 还有 \(sorted.count - 15) 个模块\n"
            }
            output += "\n"
            output += "总编译时间: \(String(format: "%.1f", totalCompileTime)) 秒\n"

            // 分析
            guard let topModule = sorted.first else {
                output += "\n分析完毕：未找到模块编译时间数据\n"
                return ToolCallResult(id: UUID().uuidString, output: output)
            }
            if topModule.time > 10 {
                output += "\n🔴 最耗时的模块 '\(topModule.name)' 编译了 \(String(format: "%.1f", topModule.time)) 秒\n"
                output += "  建议: 考虑拆分大模块，或减少该模块的依赖\n"
            }
        } else {
            output += "未检测到模块级编译时间。请确保在完整的 clean build 下运行。\n\n"
            // 粗略分析
            let errorCount = buildOut.components(separatedBy: "error:").count - 1
            let warningCount = buildOut.components(separatedBy: "warning:").count - 1
            let isSuccess = buildOut.contains("Build complete") || buildOut.contains("Build succeeded")
            output += "构建\(isSuccess ? "成功" : "失败"): \(errorCount) 错误, \(warningCount) 警告\n"
        }

        return ToolCallResult(id: UUID().uuidString, output: output)
    }

    // MARK: - Helpers

    private func findPID(_ name: String) async -> String? {
        let out = await runProcess("/bin/ps", args: ["-eo", "pid,comm"])
        for line in out.split(separator: "\n") {
            let text = String(line)
            if text.lowercased().contains(name.lowercased()) {
                let parts = text.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                if let pid = parts.first.map(String.init) {
                    return pid
                }
            }
        }
        return nil
    }

    private func runProcess(_ exec: String, args: [String], cwd: String? = nil) async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: exec)
        task.arguments = args
        if let cwd { task.currentDirectoryURL = URL(fileURLWithPath: cwd) }
        let pipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errPipe
        let (out, err) = await withCheckedContinuation { (continuation: CheckedContinuation<(String, String), Never>) in
            task.terminationHandler = { _ in
                let outData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (String(data: outData, encoding: .utf8) ?? "", String(data: errData, encoding: .utf8) ?? ""))
            }
            do { try task.run() } catch { continuation.resume(returning: ("", "")) }
        }
        return out.isEmpty ? err : out
    }
}
