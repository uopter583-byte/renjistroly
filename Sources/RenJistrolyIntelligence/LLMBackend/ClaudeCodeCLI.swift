import Foundation
import os
import RenJistrolyModels

public actor ClaudeCodeCLIBackend: LLMBackend {
    public nonisolated let provider: LLMProvider = .claudeCodeCLI
    private let cliPath: String
    private var environmentOverrides: [String: String] = [:]

    public init(cliPath: String = "/opt/homebrew/bin/claude") {
        self.cliPath = cliPath
    }

    /// Inject or update an environment variable for the `claude` subprocess.
    /// Use this to pass `ANTHROPIC_API_KEY` when the parent process doesn't inherit it.
    public func setEnvironmentVariable(key: String, value: String) {
        environmentOverrides[key] = value
    }

    public func removeEnvironmentVariable(key: String) {
        environmentOverrides.removeValue(forKey: key)
    }

    public var isAvailable: Bool {
        get async { FileManager.default.isExecutableFile(atPath: cliPath) }
    }

    public func chat(
        messages: [Message],
        config: LLMConfiguration,
        tools: [ToolDefinition]?,
        delegate: LLMStreamingDelegate?
    ) async throws -> Message {
        let prompt = buildPrompt(from: messages)
        var fullText = ""
        var failure: String?

        for await event in runStructured(prompt: prompt) {
            switch event {
            case .text(let t):
                fullText += t
            case .error(let err):
                failure = Self.userFacingError(err)
            case .toolUse:
                continue
            }
        }

        if let failure, fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CLIBackendError.failed(failure)
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Message(role: .assistant, content: [.text(trimmed.isEmpty ? "Claude Code 已完成" : trimmed)])
    }

    public func chatStream(
        messages: [Message],
        config: LLMConfiguration,
        tools: [ToolDefinition]?,
        delegate: LLMStreamingDelegate?
    ) async throws -> AsyncStream<String> {
        let prompt = buildPrompt(from: messages)
        let messageID = UUID()

        return AsyncStream { continuation in
            Task {
                var fullText = ""

                for await event in runStructured(prompt: prompt) {
                    switch event {
                    case .text(let text):
                        fullText += text
                        continuation.yield(text)
                        delegate?.onToken(text, messageID: messageID)

                    case .toolUse(let id, let name, let args):
                        delegate?.onToolCall(ToolCallRequest(id: id, name: name, arguments: args), messageID: messageID)

                    case .error(let err):
                        let message = Self.userFacingError(err)
                        delegate?.onError(
                            NSError(domain: "ClaudeCodeCLI", code: -1, userInfo: [NSLocalizedDescriptionKey: message]),
                            messageID: messageID
                        )
                        if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            fullText = message
                            continuation.yield(message)
                        }
                    }
                }

                continuation.finish()
                delegate?.onComplete(messageID: messageID, totalTokens: fullText.count)
            }
        }
    }

    // MARK: - CLI

    enum StreamEvent: Sendable {
        case text(String)
        case toolUse(id: String, name: String, arguments: [String: String])
        case error(String)
    }

    private func runStructured(prompt: String) -> AsyncStream<StreamEvent> {
        AsyncStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = [
                "--print", prompt,
                "--output-format", "stream-json",
                "--verbose",
            ]
            // Merge parent environment with overrides (e.g. ANTHROPIC_API_KEY)
            var env = ProcessInfo.processInfo.environment
            env.merge(environmentOverrides) { (_, new) in new }
            process.environment = env

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            // Synchronised flag so readabilityHandler and terminationHandler
            // don't race on continuation.finish().
            final class StreamFinisher: Sendable {
                private let lock = OSAllocatedUnfairLock<Bool>(initialState: false)
                func tryFinish() -> Bool {
                    lock.withLock { (flag: inout Bool) in
                        guard !flag else { return false }
                        flag = true
                        return true
                    }
                }
            }
            let finisher = StreamFinisher()

            // Thread-safe stderr data collector.
            final class StderrCapture: Sendable {
                private let lock = OSAllocatedUnfairLock<Data>(initialState: Data())
                func append(_ data: Data) {
                    lock.withLock { (buf: inout Data) in buf.append(data) }
                }
                var collected: Data {
                    lock.withLock { $0 }
                }
            }
            let stderrCapture = StderrCapture()
            stderr.fileHandleForReading.readabilityHandler = { h in
                stderrCapture.append(h.availableData)
            }

            // Thread-safe stdout line buffer.
            final class LineBuffer: Sendable {
                private let lock = OSAllocatedUnfairLock<Data>(initialState: Data())

                /// Appends data and extracts completed lines. Returns lines as Data chunks.
                func appendAndExtractLines(_ data: Data) -> [Data] {
                    lock.withLock { (buf: inout Data) in
                        buf.append(data)
                        var lines: [Data] = []
                        while let nl = buf.firstIndex(of: 0x0A) {
                            let line = Data(buf[buf.startIndex..<nl])
                            buf.removeSubrange(...nl)
                            lines.append(line)
                        }
                        return lines
                    }
                }
            }
            let buffer = LineBuffer()

            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    stdout.fileHandleForReading.readabilityHandler = nil
                    let shouldFinish = finisher.tryFinish()
                    guard shouldFinish else { return }
                    continuation.finish()
                    return
                }
                for lineData in buffer.appendAndExtractLines(data) {
                    if let event = Self.parseLine(lineData) {
                        continuation.yield(event)
                    }
                }
            }

            process.terminationHandler = { proc in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil

                // Drain remaining stderr after the handler is unregistered.
                let remainingStderr = try? stderr.fileHandleForReading.readToEnd()
                var fullStderr = stderrCapture.collected
                if let remaining = remainingStderr { fullStderr.append(remaining) }

                let shouldFinish = finisher.tryFinish()
                guard shouldFinish else { return }

                if proc.terminationStatus != 0 {
                    let stderrText = String(data: fullStderr, encoding: .utf8) ?? ""
                    let err = stderrText.isEmpty ? "exit \(proc.terminationStatus)" : stderrText.trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.yield(.error(err))
                }
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                if process.isRunning { process.terminate() }
            }

            do { try process.run() }
            catch {
                continuation.yield(.error("无法启动 Claude Code: \(error.localizedDescription)"))
                continuation.finish()
            }
        }
    }

    static func parseLine(_ data: Data) -> StreamEvent? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                return .text(text)
            }
            return nil
        }

        if let type = json["type"] as? String, type == "assistant",
           let msg = json["message"] as? [String: Any],
           let content = msg["content"] as? [[String: Any]] {
            var texts: [String] = []
            var toolCalls: [StreamEvent] = []
            for block in content {
                if block["type"] as? String == "text", let t = block["text"] as? String {
                    texts.append(t)
                } else if block["type"] as? String == "tool_use",
                          let name = block["name"] as? String,
                          let id = block["id"] as? String {
                    let input = block["input"] as? [String: Any] ?? [:]
                    let args = input.mapValues { v -> String in
                        if let s = v as? String { return s }
                        if let n = v as? NSNumber { return n.stringValue }
                        return "\(v)"
                    }
                    toolCalls.append(.toolUse(id: id, name: name, arguments: args))
                }
            }
            // Yield tool calls first so delegate can handle before text
            for tc in toolCalls { return tc }
            if !texts.isEmpty { return .text(texts.joined()) }
        }

        if let text = json["text"] as? String { return .text(text) }
        return nil
    }

    static func userFacingError(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower.contains("not logged in") || lower.contains("please run /login") || lower.contains("run /login") {
            return ClaudeCodeLoginGuide.help
        }
        if lower.contains("invalid api key") || lower.contains("authentication") || lower.contains("unauthorized") {
            return "Claude Code 认证失败。请检查 Claude 登录状态或 ANTHROPIC_API_KEY。"
        }
        if lower.contains("command not found") || lower.contains("no such file") {
            return "Claude Code CLI 不可用。请确认已安装并且 `/opt/homebrew/bin/claude` 可执行。"
        }

        return trimmed.isEmpty ? "Claude Code 没有返回错误详情。" : "Claude Code 失败：\(trimmed)"
    }

    // MARK: - Prompt building

    func buildPrompt(from messages: [Message]) -> String {
        var prompt = ""

        if let system = messages.first(where: { $0.role == .system })?.textContent {
            prompt += "\(system)\n\n"
        }

        for msg in messages where msg.role == .user || msg.role == .assistant {
            let prefix = msg.role == .user ? "用户: " : "助手: "
            prompt += prefix + msg.textContent + "\n\n"
        }

        for msg in messages {
            for block in msg.content {
                if case .toolResult(let res) = block {
                    prompt += "[工具返回: \(res.output.prefix(500))]\n"
                }
            }
        }

        if prompt.isEmpty { prompt = "你好" }
        return prompt
    }
}

public enum CLIBackendError: Error, LocalizedError, Sendable {
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .failed(let message):
            message
        }
    }
}
