import Foundation
import os
import RenJistrolyModels

public actor ClaudeCodeBridge {
    private var claudePath: String

    public init(claudePath: String = "/opt/homebrew/bin/claude") {
        self.claudePath = claudePath
    }

    public func configuredPath() -> String {
        claudePath
    }

    public func updatePath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        claudePath = trimmed
    }

    public func installationStatus() -> ClaudeCodeInstallationStatus {
        ClaudeCodeInstallationStatus(
            executablePath: claudePath,
            isInstalled: FileManager.default.isExecutableFile(atPath: claudePath)
        )
    }

    // MARK: - Text mode (legacy)

    public func run(prompt: String, cwd: String? = nil, environment: [String: String]? = nil) -> AsyncStream<String> {
        AsyncStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: claudePath)
            process.arguments = [
                "--print", prompt,
                "--output-format", "text",
                "--max-turns", "5",
            ]
            if let cwd {
                process.currentDirectoryURL = URL(fileURLWithPath: cwd)
            }
            if let environment {
                var env = ProcessInfo.processInfo.environment
                env.merge(environment) { (_, new) in new }
                process.environment = env
            }

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            // Sendable lock-protected buffer for Process I/O, accessed from @Sendable readability/termination callbacks
            final class Buffer: Sendable {
                private let dataLock = OSAllocatedUnfairLock<Data>(initialState: Data())
                private let finishedLock = OSAllocatedUnfairLock<Bool>(initialState: false)

                var isFinished: Bool { finishedLock.withLock { $0 } }
                func markFinished() { finishedLock.withLock { $0 = true } }

                func append(_ data: Data) {
                    dataLock.withLock { $0.append(data) }
                }

                /// Appends data and returns decoded text, clearing the buffer.
                func appendAndDecode(_ data: Data) -> String? {
                    dataLock.withLock { (buf: inout Data) -> String? in
                        buf.append(data)
                        guard !buf.isEmpty else { return nil }
                        let text = String(data: buf, encoding: .utf8)
                        buf.removeAll()
                        return text
                    }
                }

                /// Returns decoded text from buffered data without clearing.
                var decodedText: String? {
                    dataLock.withLock { (buf: inout Data) -> String? in
                        guard !buf.isEmpty else { return nil }
                        return String(data: buf, encoding: .utf8)
                    }
                }
            }
            let buffer = Buffer()

            let finish: @Sendable () -> Void = {
                guard !buffer.isFinished else { return }
                buffer.markFinished()
                continuation.finish()
            }

            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    stdout.fileHandleForReading.readabilityHandler = nil
                    finish()
                    return
                }
                if let text = buffer.appendAndDecode(data) {
                    continuation.yield(text)
                }
            }

            process.terminationHandler = { proc in
                stdout.fileHandleForReading.readabilityHandler = nil
                guard !buffer.isFinished else { return }
                let remaining = try? stdout.fileHandleForReading.readToEnd()
                if let data = remaining, !data.isEmpty {
                    buffer.append(data)
                }
                if let text = buffer.decodedText {
                    continuation.yield(text)
                }
                if proc.terminationStatus != 0 {
                    let errData = try? stderr.fileHandleForReading.readToEnd()
                    let err = errData.flatMap { String(data: $0, encoding: .utf8) } ?? "exit code \(proc.terminationStatus)"
                    continuation.yield("[错误] \(err)")
                }
                finish()
            }

            continuation.onTermination = { @Sendable _ in process.terminate() }

            do {
                try process.run()
            } catch {
                continuation.yield("[错误] 无法启动 Claude Code: \(error.localizedDescription)")
                continuation.finish()
            }
        }
    }

    // MARK: - Structured mode

    public func runStructured(prompt: String, cwd: String? = nil, environment: [String: String]? = nil) -> AsyncStream<ClaudeCodeEvent> {
        AsyncStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: claudePath)
            process.arguments = [
                "--print", prompt,
                "--output-format", "stream-json",
                "--max-turns", "10",
                "--verbose",
            ]
            if let cwd {
                process.currentDirectoryURL = URL(fileURLWithPath: cwd)
            }
            if let environment {
                var env = ProcessInfo.processInfo.environment
                env.merge(environment) { (_, new) in new }
                process.environment = env
            }

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            // Sendable lock-protected line buffer for stdout, accessed from @Sendable readability/termination callbacks
            final class LineBuffer: Sendable {
                private let lock = OSAllocatedUnfairLock<Data>(initialState: Data())

                /// Appends data and extracts complete line Data chunks (without newline).
                func appendAndExtractLines(_ data: Data) -> [Data] {
                    lock.withLock { (buf: inout Data) in
                        buf.append(data)
                        var lines: [Data] = []
                        while let newlineIndex = buf.firstIndex(of: 0x0A) {
                            let lineSlice = buf[buf.startIndex..<newlineIndex]
                            buf.removeSubrange(...newlineIndex)
                            lines.append(Data(lineSlice))
                        }
                        return lines
                    }
                }
            }
            let lineBuffer = LineBuffer()

            // Sendable lock-protected termination guard flag, accessed from @Sendable callbacks
            final class FinishGuard: Sendable {
                private let lock = OSAllocatedUnfairLock<Bool>(initialState: false)

                var didFinish: Bool { lock.withLock { $0 } }

                /// Atomically checks and sets didFinish. Returns true if this call performed the set.
                @discardableResult
                func finishIfNeeded() -> Bool {
                    lock.withLock { (flag: inout Bool) in
                        guard !flag else { return false }
                        flag = true
                        return true
                    }
                }
            }
            let streamGuard = FinishGuard()

            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    stdout.fileHandleForReading.readabilityHandler = nil
                    if streamGuard.finishIfNeeded() {
                        continuation.finish()
                    }
                    return
                }
                for lineData in lineBuffer.appendAndExtractLines(data) {
                    if let event = Self.parseJSONLine(lineData) {
                        continuation.yield(event)
                    }
                }
            }

            process.terminationHandler = { proc in
                stdout.fileHandleForReading.readabilityHandler = nil
                guard !streamGuard.didFinish else { return }
                let remaining = try? stdout.fileHandleForReading.readToEnd()
                if let data = remaining, !data.isEmpty {
                    for lineData in lineBuffer.appendAndExtractLines(data) {
                        if let event = Self.parseJSONLine(lineData) {
                            continuation.yield(event)
                        }
                    }
                }
                if proc.terminationStatus != 0 {
                    let errData = try? stderr.fileHandleForReading.readToEnd()
                    let err = errData.flatMap { String(data: $0, encoding: .utf8) } ?? "exit code \(proc.terminationStatus)"
                    continuation.yield(.error(err))
                }
                if streamGuard.finishIfNeeded() {
                    continuation.finish()
                }
            }

            continuation.onTermination = { @Sendable _ in process.terminate() }

            do {
                try process.run()
            } catch {
                continuation.yield(.error("无法启动 Claude Code: \(error.localizedDescription)"))
                continuation.finish()
            }
        }
    }

    private static func parseJSONLine(_ data: Data) -> ClaudeCodeEvent? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return .text(text)
            }
            return nil
        }

        if let type = json["type"] as? String {
            switch type {
            case "assistant":
                return parseAssistantMessage(json)
            case "user":
                if let message = json["message"] as? [String: Any],
                   let content = message["content"] as? [[String: Any]] {
                    var events: [ClaudeCodeEvent] = []
                    for block in content {
                        if let text = block["text"] as? String, !text.isEmpty {
                            events.append(.userMessage(text))
                        } else if block["type"] as? String == "tool_result",
                                  let toolUseID = block["tool_use_id"] as? String {
                            let output = block["content"] as? String ?? ""
                            let isError = block["is_error"] as? Bool ?? false
                            events.append(.toolResult(id: toolUseID, name: "", output: output, isError: isError))
                        }
                    }
                    if events.count == 1 { return events[0] }
                    if !events.isEmpty { return .batch(events) }
                }
            case "system":
                if let subtype = json["subtype"] as? String, subtype == "init" {
                    return .initMessage(json["message"] as? String)
                }
            case "result":
                if let result = json["result"] as? String {
                    return .result(result)
                }
            case "tool_result":
                let id = json["tool_use_id"] as? String ?? ""
                let name = json["name"] as? String ?? ""
                let output = json["content"] as? String ?? json["output"] as? String ?? ""
                let isError = json["is_error"] as? Bool ?? false
                return .toolResult(id: id, name: name, output: output, isError: isError)
            default:
                break
            }
        }

        if let text = json["text"] as? String, !text.isEmpty {
            return .text(text)
        }

        return nil
    }

    private static func parseAssistantMessage(_ json: [String: Any]) -> ClaudeCodeEvent? {
        guard let message = json["message"] as? [String: Any],
              let content = message["content"] as? [[String: Any]] else {
            return nil
        }

        var events: [ClaudeCodeEvent] = []

        for block in content {
            if block["type"] as? String == "text",
               let text = block["text"] as? String, !text.isEmpty {
                events.append(.assistantText(text))
            } else if block["type"] as? String == "tool_use",
                      let name = block["name"] as? String,
                      let id = block["id"] as? String {
                let input = block["input"] as? [String: Any] ?? [:]
                let args = input.mapValues { value -> String in
                    if let s = value as? String { return s }
                    if let n = value as? NSNumber { return n.stringValue }
                    if let data = try? JSONSerialization.data(withJSONObject: value),
                       let str = String(data: data, encoding: .utf8) {
                        return str
                    }
                    return "\(value)"
                }
                events.append(.toolUse(id: id, name: name, arguments: args))
            }
        }

        if events.isEmpty { return nil }
        if events.count == 1 { return events[0] }
        return .batch(events)
    }
}

// MARK: - Structured event types

public enum ClaudeCodeEvent: Sendable {
    case assistantText(String)
    case toolUse(id: String, name: String, arguments: [String: String])
    case toolResult(id: String, name: String, output: String, isError: Bool)
    case userMessage(String)
    case initMessage(String?)
    case result(String)
    case text(String)
    case error(String)
    case batch([ClaudeCodeEvent])
}

extension ClaudeCodeEvent {
    public var toolCallRequest: ToolCallRequest? {
        guard case .toolUse(let id, let name, let args) = self else { return nil }
        return ToolCallRequest(id: id, name: name, arguments: args)
    }

    public var textContent: String? {
        switch self {
        case .assistantText(let t), .text(let t), .userMessage(let t): return t
        case .error(let t): return t
        case .result(let t): return t
        case .toolUse, .toolResult, .initMessage, .batch: return nil
        }
    }
}

// MARK: - Structured Result

public struct ClaudeCodeStructuredResult: Sendable {
    public let summary: String
    public let fileChanges: [FileChange]
    public let commandsRun: [String]
    public let buildResults: [BuildResult]
    public let testResults: [TestResult]
    public let errorMessage: String?
    public let succeeded: Bool

    public struct FileChange: Sendable, Hashable {
        public let path: String
        public let kind: Kind
        public enum Kind: String, Sendable, Hashable { case created, modified, deleted }

        public init(path: String, kind: Kind) {
            self.path = path
            self.kind = kind
        }
    }

    public init(
        summary: String,
        fileChanges: [FileChange] = [],
        commandsRun: [String] = [],
        buildResults: [BuildResult] = [],
        testResults: [TestResult] = [],
        errorMessage: String? = nil
    ) {
        self.summary = summary
        self.fileChanges = fileChanges
        self.commandsRun = commandsRun
        self.buildResults = buildResults
        self.testResults = testResults
        self.errorMessage = errorMessage
        self.succeeded = errorMessage == nil
    }
}

extension ClaudeCodeBridge {
    public func collectStructuredResult(from stream: AsyncStream<ClaudeCodeEvent>) async -> ClaudeCodeStructuredResult {
        var textParts: [String] = []
        var fileChanges: [ClaudeCodeStructuredResult.FileChange] = []
        var commandsRun: [String] = []
        var buildResults: [BuildResult] = []
        var testResults: [TestResult] = []
        var errorMessage: String?

        for await event in stream {
            switch event {
            case .assistantText(let t):
                textParts.append(t)
                fileChanges.append(contentsOf: Self.extractFileChanges(from: t))
                commandsRun.append(contentsOf: Self.extractCommands(from: t))
            case .toolUse(_, let name, let args):
                if name == "write_file" || name == "Write" {
                    if let path = args["file_path"] ?? args["path"] {
                        fileChanges.append(.init(path: path, kind: .modified))
                    }
                }
                if name == "run_shell_command" || name == "Bash" {
                    if let cmd = args["command"] {
                        commandsRun.append(cmd)
                    }
                }
            case .toolResult(_, let name, let output, let isError):
                if name == "swift_build" || name == "SwiftBuild" {
                    let diagnostics = XcodeDriver.parseBuildDiagnostics(from: output)
                    buildResults = [BuildResult(
                        success: !isError && diagnostics.allSatisfy({ $0.severity != .error }),
                        errors: diagnostics.filter { $0.severity == .error },
                        warnings: diagnostics.filter { $0.severity == .warning },
                        rawOutput: output
                    )]
                }
                if name == "swift_test" || name == "SwiftTest" {
                    testResults = [TestResult(
                        success: !isError,
                        failures: isError ? [TestFailure(testName: "test", message: output)] : []
                    )]
                }
            case .error(let e):
                errorMessage = e
            case .result(let r):
                textParts.append(r)
            case .text(let t):
                textParts.append(t)
                fileChanges.append(contentsOf: Self.extractFileChanges(from: t))
            case .userMessage, .initMessage, .batch:
                break
            }
        }

        return ClaudeCodeStructuredResult(
            summary: textParts.joined(separator: "\n"),
            fileChanges: fileChanges,
            commandsRun: commandsRun,
            buildResults: buildResults,
            testResults: testResults,
            errorMessage: errorMessage
        )
    }

    public static func extractFileChanges(from text: String) -> [ClaudeCodeStructuredResult.FileChange] {
        var changes: [ClaudeCodeStructuredResult.FileChange] = []
        // Pattern: "created/modified/deleted file filename.ext"
        guard let pattern = try? NSRegularExpression(
            pattern: "(created?|written?|generated?|modified?|edited?|updated?|deleted?|removed?)\\s+(?:file\\s+)?([^\\s,;()]+\\.[a-zA-Z]{1,10})",
            options: .caseInsensitive
        ) else { return [] }
        let nsText = text as NSString
        for match in pattern.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            guard match.numberOfRanges >= 3 else { continue }
            let action = nsText.substring(with: match.range(at: 1)).lowercased()
            let path = nsText.substring(with: match.range(at: 2))
            let kind: ClaudeCodeStructuredResult.FileChange.Kind
            if action.hasPrefix("delet") || action.hasPrefix("remov") {
                kind = .deleted
            } else if action.hasPrefix("creat") || action.hasPrefix("writ") || action.hasPrefix("gener") {
                kind = .created
            } else {
                kind = .modified
            }
            changes.append(.init(path: path, kind: kind))
        }
        return changes
    }

    public static func extractCommands(from text: String) -> [String] {
        guard let pattern = try? NSRegularExpression(pattern: "`([^`]+)`") else { return [] }
        let nsText = text as NSString
        return pattern.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges >= 2 else { return nil }
            let cmd = nsText.substring(with: match.range(at: 1))
            return cmd.contains(" ") ? cmd : nil
        }
    }
}

public struct ClaudeCodeInstallationStatus: Sendable, Hashable {
    public let executablePath: String
    public let isInstalled: Bool

    public init(executablePath: String, isInstalled: Bool) {
        self.executablePath = executablePath
        self.isInstalled = isInstalled
    }
}
