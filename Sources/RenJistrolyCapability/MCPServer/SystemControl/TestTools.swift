import Foundation
import RenJistrolyModels

// MARK: - Run Tests Tool

public struct RunTestsTool: MCPTool {
    public let definition = ToolDefinition(
        name: "run_tests",
        description: "运行 RenJistroly 测试套件，返回结构化测试结果（通过/失败统计）",
        parameters: [
            .init(name: "filter", type: .string, description: "测试过滤器，如 'ProviderRouterTests' 或 'VoiceInput'", required: false),
            .init(name: "target", type: .string, description: "测试目标，如 'RenJistrolyModelsTests'", required: false),
            .init(name: "verbose", type: .string, description: "详细输出: true/false, 默认 false", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let projectPath = FileManager.default.currentDirectoryPath
        let filter = arguments["filter"]
        let target = arguments["target"]
        let verbose = arguments["verbose"] == "true"

        var command = "cd \(shellEscape(projectPath)) && swift test 2>&1"
        if let target {
            command = "cd \(shellEscape(projectPath)) && swift test --filter '\(target)' 2>&1"
        } else if let filter {
            command = "cd \(shellEscape(projectPath)) && swift test --filter '\(filter)' 2>&1"
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

            let isSuccess = task.terminationStatus == 0

            let totalTests = extractTotalTests(from: output)

            var summary = ""
            if isSuccess {
                summary += "✅ 测试全部通过"
            } else {
                summary += "❌ 测试存在失败"
            }
            if let total = totalTests {
                summary += "\n总计: \(total.total) 测试, \(total.passed) 通过, \(total.failed) 失败"
            }
            summary += "\n退出码: \(task.terminationStatus)"

            if verbose || !isSuccess {
                // Include error details on failure
                let errors = extractTestErrors(from: output)
                if !errors.isEmpty {
                    summary += "\n\n失败详情:"
                    for error in errors {
                        summary += "\n  • \(error)"
                    }
                }

                // Include full output in verbose mode
                if verbose && !output.isEmpty {
                    let maxLen = 4000
                    let trimmed = output.count > maxLen
                        ? String(output.prefix(maxLen)) + "\n... (截断, 共 \(output.count) 字符)"
                        : output
                    summary += "\n\n完整输出:\n\(trimmed)"
                }

                if !errorOutput.isEmpty {
                    summary += "\n\nstderr:\n\(errorOutput)"
                }
            }

            return ToolCallResult(id: UUID().uuidString, output: summary)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "执行测试失败: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Helpers

    private func shellEscape(_ s: String) -> String {
        "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func extractTotalTests(from output: String) -> (total: Int, passed: Int, failed: Int)? {
        let pattern = #"Executed (\d+) tests?, with (\d+) failures?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(output.startIndex..., in: output)
        let matches = regex.matches(in: output, range: nsRange)
        guard let last = matches.last, last.numberOfRanges >= 3 else { return nil }
        let totalRange = last.range(at: 1)
        let failedRange = last.range(at: 2)
        guard let range1 = Range(totalRange, in: output),
              let range2 = Range(failedRange, in: output),
              let total = Int(output[range1]),
              let failed = Int(output[range2]) else { return nil }
        return (total, total - failed, failed)
    }

    private func extractTestErrors(from output: String) -> [String] {
        let pattern = #"/Users/[^/]+[^:]+:\d+:\s*(error:.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(output.startIndex..., in: output)
        let matches = regex.matches(in: output, range: nsRange)
        return matches.compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: output) else { return nil }
            return String(output[range]).trimmingCharacters(in: .whitespaces)
        }
    }
}

// MARK: - Test Coverage Tool

public struct TestCoverageTool: MCPTool {
    public let definition = ToolDefinition(
        name: "test_coverage",
        description: "检查测试覆盖情况，列出所有测试文件和它们的测试函数数量",
        parameters: [
            .init(name: "module", type: .string, description: "模块名过滤, 如 'RenJistrolyIntelligence'", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        var output = "测试覆盖报告\n"
        output += String(repeating: "=", count: 40) + "\n"

        let testsDir = FileManager.default.currentDirectoryPath + "/Tests"
        let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: testsDir),
            includingPropertiesForKeys: nil
        )

        var moduleStats: [(name: String, testFiles: Int, testFuncs: Int)] = []
        let moduleFilter = arguments["module"]

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            let content = try? String(contentsOf: fileURL, encoding: .utf8)
            guard let content else { continue }

            let relativePath = fileURL.path
                .replacingOccurrences(of: testsDir + "/", with: "")
            let module = relativePath.components(separatedBy: "/").first ?? ""

            if let moduleFilter, !module.contains(moduleFilter) { continue }

            let testFuncCount = countMatches(pattern: #"func\s+test"#, in: content)
            let testClassCount = countMatches(pattern: #"(class|struct)\s+\w+Tests?\s*:"#, in: content)

            if testFuncCount > 0 {
                moduleStats.append((module, testClassCount, testFuncCount))
            }
        }

        if moduleStats.isEmpty {
            output += "未找到匹配的测试文件。"
            return ToolCallResult(id: UUID().uuidString, output: output)
        }

        // Group by module
        let grouped = Dictionary(grouping: moduleStats) { $0.name }
        var totalFiles = 0
        var totalFuncs = 0

        for (module, stats) in grouped.sorted(by: { $0.key < $1.key }) {
            let files = stats.count
            let funcs = stats.reduce(0) { $0 + $1.testFuncs }
            output += "\n📦 \(module): \(files) 文件, \(funcs) 测试函数"
            totalFiles += files
            totalFuncs += funcs
        }

        output += "\n\n总计: \(totalFiles) 文件, \(totalFuncs) 测试函数"

        return ToolCallResult(id: UUID().uuidString, output: output)
    }

    private func countMatches(pattern: String, in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return 0 }
        return regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
    }
}
