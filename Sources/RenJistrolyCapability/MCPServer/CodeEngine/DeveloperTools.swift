import Foundation
import OSLog
import RenJistrolyModels

public struct SwiftBuildTool: MCPTool {
    public let definition = ToolDefinition(
        name: "swift_build",
        description: "运行 swift build，解析并返回结构化构建结果。支持 clean、指定 target",
        parameters: [
            .init(name: "project_path", type: .string, description: "SwiftPM 项目路径", required: false),
            .init(name: "configuration", type: .string, description: "debug 或 release，默认 debug", required: false),
            .init(name: "target", type: .string, description: "只构建指定 target", required: false),
            .init(name: "clean", type: .string, description: "true 时先执行 swift package clean", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let projectPath = arguments["project_path"] ?? FileManager.default.currentDirectoryPath
        let config = arguments["configuration"] ?? "debug"

        if (arguments["clean"] ?? "false").lowercased() == "true" {
            let cleanProcess = Process()
            cleanProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
            cleanProcess.arguments = ["package", "clean"]
            cleanProcess.currentDirectoryURL = URL(fileURLWithPath: projectPath)
            cleanProcess.standardOutput = FileHandle.nullDevice
            cleanProcess.standardError = FileHandle.nullDevice
            do {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    cleanProcess.terminationHandler = { _ in cont.resume() }
                    do { try cleanProcess.run() } catch { cont.resume(throwing: error) }
                }
            } catch {
                Logger.tools.error("clean 失败: \(error.localizedDescription, privacy: .public)")
            }
        }

        var args = ["build"]
        if config == "release" { args.append(contentsOf: ["-c", "release"]) }
        if let target = arguments["target"] { args.append(contentsOf: ["--target", target]) }

        let target = arguments["target"]
        Task { await AgentEventBus.shared.publish(.code(.buildStarted(target: target))) }

        let start = Date()
        let result = try await runSwift(command: args, cwd: projectPath)
        let elapsed = Date().timeIntervalSince(start)

        let buildResult = parseSwiftBuildOutput(result.stdout + "\n" + result.stderr)

        var completeResult = buildResult
        if completeResult.durationSeconds == 0 {
            completeResult = BuildResult(
                success: buildResult.success,
                errors: buildResult.errors,
                warnings: buildResult.warnings,
                durationSeconds: elapsed,
                rawOutput: buildResult.rawOutput
            )
        }

        let success = completeResult.success
        let errorCount = completeResult.errors.count
        let warningCount = completeResult.warnings.count
        let firstError = completeResult.errors.first?.message ?? "Build failed"

        if success {
            Task { await AgentEventBus.shared.publish(.code(.buildCompleted(exitCode: 0, errorCount: errorCount, warningCount: warningCount))) }
        } else {
            Task { await AgentEventBus.shared.publish(.code(.buildFailed(stderr: firstError))) }
        }

        let output = formatBuildResult(completeResult)
        return ToolCallResult(
            id: UUID().uuidString,
            output: output,
            isError: !completeResult.success
        )
    }

    func parseSwiftBuildOutput(_ raw: String) -> BuildResult {
        var errors: [BuildDiagnostic] = []
        var warnings: [BuildDiagnostic] = []

        let lines = raw.split(separator: "\n")
        for line in lines {
            let text = String(line)
            let isError = text.contains("error:") && !text.contains("note:")
            let isWarning = text.contains("warning:") && !text.contains("note:")

            guard isError || isWarning else { continue }

            let parsed = parseDiagnosticLine(text, severity: isError ? .error : .warning)
            if isError { errors.append(parsed) }
            else { warnings.append(parsed) }
        }

        let success = errors.isEmpty && raw.contains("Build complete")
        return BuildResult(
            success: success,
            errors: errors,
            warnings: warnings,
            rawOutput: raw
        )
    }

    func parseDiagnosticLine(_ text: String, severity: BuildDiagnostic.Severity) -> BuildDiagnostic {
        let fileMatch = try? Regex(#"(\S+\.swift):(\d+):(\d+)"#).firstMatch(in: text)
        let filePath = fileMatch?.output[1].substring.map(String.init)
        let lineNum = fileMatch?.output[2].substring.flatMap { Int($0) }
        let colNum = fileMatch?.output[3].substring.flatMap { Int($0) }

        let msg: String
        if let re = try? Regex(".*?(error|warning):\\s*") {
            msg = text.replacing(re, with: "")
        } else {
            msg = text
        }

        return BuildDiagnostic(
            filePath: filePath,
            line: lineNum,
            column: colNum,
            message: msg.trimmingCharacters(in: .whitespaces),
            severity: severity
        )
    }

    func formatBuildResult(_ result: BuildResult) -> String {
        var out = "构建\(result.success ? "成功" : "失败") (\(String(format: "%.1f", result.durationSeconds))s)\n"

        if !result.errors.isEmpty {
            out += "\n错误 (\(result.errors.count)):\n"
            for e in result.errors {
                let loc = e.filePath.map { "\($0):\(e.line ?? 0)" } ?? ""
                out += "  \(loc.isEmpty ? "" : "\(loc): ")\(e.message)\n"
            }
        }
        if !result.warnings.isEmpty {
            out += "\n警告 (\(result.warnings.count)):\n"
            for w in result.warnings.prefix(5) {
                out += "  \(w.message)\n"
            }
            if result.warnings.count > 5 {
                out += "  ... 还有 \(result.warnings.count - 5) 个警告\n"
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct SwiftTestTool: MCPTool {
    public let definition = ToolDefinition(
        name: "swift_test",
        description: "运行 swift test，解析并返回结构化测试结果",
        parameters: [
            .init(name: "project_path", type: .string, description: "SwiftPM 项目路径", required: false),
            .init(name: "filter", type: .string, description: "测试过滤器，如 'TestName'", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let projectPath = arguments["project_path"] ?? FileManager.default.currentDirectoryPath

        var args = ["test"]
        if let filter = arguments["filter"] { args.append(contentsOf: ["--filter", filter]) }
        Task { await AgentEventBus.shared.publish(.code(.testStarted(filter: arguments["filter"]))) }

        let start = Date()
        let result = try await runSwift(command: args, cwd: projectPath)
        let elapsed = Date().timeIntervalSince(start)

        let testResult = parseSwiftTestOutput(result.stdout + "\n" + result.stderr, elapsed: elapsed)

        if testResult.success {
            Task { await AgentEventBus.shared.publish(.code(.testCompleted(passed: testResult.passedCount, failed: testResult.failedCount, duration: elapsed))) }
        } else {
            for f in testResult.failures.prefix(3) {
                Task { await AgentEventBus.shared.publish(.code(.testFailed(name: f.testName, message: f.message))) }
            }
        }

        let output = formatTestResult(testResult)

        return ToolCallResult(
            id: UUID().uuidString,
            output: output,
            isError: !testResult.success
        )
    }

    func parseSwiftTestOutput(_ raw: String, elapsed: Double) -> TestResult {
        var failures: [TestFailure] = []
        var totalCount = 0
        var passedCount = 0
        var failedCount = 0

        let lines = raw.split(separator: "\n")
        for line in lines {
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

            if text.contains("failed") && text.contains("Test Case") {
                let nameMatch = try? Regex(#"'?(?:Test\s+Case\s+)?'?([^']+)'?\s*failed"#).firstMatch(in: text)
                let name = nameMatch?.output[1].substring.map(String.init) ?? "未知测试"
                failures.append(TestFailure(testName: name, message: text))
            }
        }

        passedCount = totalCount - failedCount
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

    func formatTestResult(_ result: TestResult) -> String {
        var out = "测试\(result.success ? "通过" : "失败")"
        if result.totalCount > 0 {
            out += ": \(result.passedCount)/\(result.totalCount) 通过"
        }
        out += " (\(String(format: "%.1f", result.durationSeconds))s)"

        if !result.failures.isEmpty {
            out += "\n\n失败测试:\n"
            for f in result.failures {
                out += "  ✗ \(f.testName)\n"
            }
        }
        return out
    }
}

public struct ProjectInfoTool: MCPTool {
    public let definition = ToolDefinition(
        name: "project_info",
        description: "分析 SwiftPM 项目结构：targets、依赖、测试。也可查看 SPM 依赖解析状态",
        parameters: [
            .init(name: "project_path", type: .string, description: "SwiftPM 项目路径", required: false),
            .init(name: "deps_only", type: .string, description: "仅显示已解析依赖列表: true/false", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let projectPath = arguments["project_path"] ?? FileManager.default.currentDirectoryPath
        let packagePath = "\(projectPath)/Package.swift"

        guard FileManager.default.fileExists(atPath: packagePath) else {
            return ToolCallResult(id: UUID().uuidString, output: "未找到 Package.swift", isError: true)
        }

        if (arguments["deps_only"] ?? "false").lowercased() == "true" {
            return try await showResolvedDependencies(projectPath)
        }

        let content = try String(contentsOfFile: packagePath, encoding: .utf8)
        var info = "项目: \(projectPath)\n"

        let nameMatch = try? Regex(#"name:\s*"([^"]+)""#).firstMatch(in: content)
        if let name = nameMatch?.output[1].substring {
            info += "名称: \(name)\n"
        }

        let targetPattern = (try? Regex(#"\.(?:executableTarget|target|testTarget)\s*\(\s*name:\s*"([^"]+)""#))
        let targets = targetPattern.map { content.matches(of: $0) } ?? []
        if !targets.isEmpty {
            info += "\nTargets:\n"
            for t in targets {
                if let name = t.output[1].substring {
                    info += "  - \(name)\n"
                }
            }
        }

        let depPattern = (try? Regex(#"dependencies:\s*\[([^\]]+)\]"#))
        let deps = depPattern.map { content.matches(of: $0) } ?? []
        if !deps.isEmpty {
            info += "\n依赖:\n"
            for d in deps {
                info += "  \(d.output[1].substring ?? "")\n"
            }
        }

        return ToolCallResult(id: UUID().uuidString, output: info)
    }

    private func showResolvedDependencies(_ projectPath: String) async throws -> ToolCallResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["package", "show-dependencies", "--format", "text"]
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        let (output, errOutput) = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, String), Error>) in
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: (String(data: data, encoding: .utf8) ?? "", String(data: errData, encoding: .utf8) ?? ""))
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }
        if process.terminationStatus != 0 {
            return ToolCallResult(id: UUID().uuidString, output: errOutput.isEmpty ? "获取失败" : errOutput, isError: true)
        }
        let truncated = output.split(separator: "\n").prefix(80).joined(separator: "\n")
        return ToolCallResult(id: UUID().uuidString, output: truncated)
    }
}

// MARK: - Code Signing Info Tool

public struct CodeSignTool: MCPTool {
    public let definition = ToolDefinition(
        name: "code_sign_info",
        description: "检查 app/target 的代码签名状态、entitlements、provisioning profile",
        parameters: [
            .init(name: "path", type: .string, description: ".app 或可执行文件路径"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let path = arguments["path"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: path", isError: true)
        }
        let expanded = (path as NSString).expandingTildeInPath

        var info = "代码签名: \(expanded)\n\n"

        // codesign --verify
        var verifyResult = ""
        let verifyProcess = Process()
        verifyProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        verifyProcess.arguments = ["-dvvv", expanded]
        let vOut = Pipe()
        let vErr = Pipe()
        verifyProcess.standardOutput = vOut
        verifyProcess.standardError = vErr
        let (vOutStr, vErrStr) = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, String), Error>) in
            verifyProcess.terminationHandler = { _ in
                let data = vOut.fileHandleForReading.readDataToEndOfFile()
                let errData = vErr.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: (String(data: data, encoding: .utf8) ?? "", String(data: errData, encoding: .utf8) ?? ""))
            }
            do { try verifyProcess.run() } catch { cont.resume(throwing: error) }
        }
        verifyResult = vErrStr + vOutStr

        // Extract key fields
        let fields = ["Identifier", "Authority", "TeamIdentifier", "Signature", "Entitlements"]
        for field in fields {
            if let m = try? Regex("\(field)[=:](.+)").firstMatch(in: verifyResult) {
                let val = m.output[1].substring?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "?"
                info += "\(field): \(val)\n"
            }
        }

        // entitlements
        let entProcess = Process()
        entProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        entProcess.arguments = ["-d", "--entitlements", "-", expanded]
        let ePipe = Pipe()
        entProcess.standardOutput = ePipe
        entProcess.standardError = FileHandle.nullDevice
        let eData = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            entProcess.terminationHandler = { _ in
                cont.resume(returning: ePipe.fileHandleForReading.readDataToEndOfFile())
            }
            do { try entProcess.run() } catch { cont.resume(throwing: error) }
        }
        if let plist = try? PropertyListSerialization.propertyList(from: eData, format: nil) as? [String: Any] {
            info += "\nEntitlements:\n"
            for key in plist.keys.sorted() {
                info += "  \(key): \(plist[key] ?? "?") \n"
            }
        }

        return ToolCallResult(id: UUID().uuidString, output: info)
    }
}

// MARK: - Shared Runner

private func runSwift(command args: [String], cwd: String) async throws -> (stdout: String, stderr: String) {
    try await withCheckedThrowingContinuation { cont in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        process.terminationHandler = { _ in
            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: outData, encoding: .utf8) ?? ""
            let err = String(data: errData, encoding: .utf8) ?? ""
            cont.resume(returning: (out, err))
        }

        do {
            try process.run()
        } catch {
            cont.resume(throwing: error)
        }
    }
}
