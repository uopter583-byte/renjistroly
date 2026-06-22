import Foundation
import os
import RenJistrolyModels

public actor CodexCLIBackend: LLMBackend {
    public nonisolated let provider: LLMProvider = .codexCLI
    private let cliPath: String

    public init(cliPath: String = "/opt/homebrew/bin/codex") {
        self.cliPath = cliPath
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

        for await event in runStructured(prompt: prompt) {
            if case .text(let t) = event { fullText += t }
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Message(role: .assistant, content: [.text(trimmed.isEmpty ? "Codex 已完成" : trimmed)])
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

                    case .error(let err):
                        delegate?.onError(
                            NSError(domain: "CodexCLI", code: -1, userInfo: [NSLocalizedDescriptionKey: err]),
                            messageID: messageID
                        )
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
        case error(String)
    }

    /// Codex `exec --json` emits one JSON-LD event per line:
    ///
    /// ```
    /// {"type":"thread.started","thread_id":"..."}
    /// {"type":"turn.started"}
    /// {"type":"item.completed","item":{"id":"...","type":"agent_message","text":"..."}}
    /// {"type":"item.completed","item":{"id":"...","type":"command_execution","command":"...","aggregated_output":"..."}}
    /// {"type":"item.started","item":{"id":"...","type":"file_change",...}}
    /// {"type":"turn.completed","usage":{...}}
    /// ```
    ///
    /// The assistant's text is in complete `agent_message` items (no per-token streaming).
    private func runStructured(prompt: String) -> AsyncStream<StreamEvent> {
        AsyncStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = [
                "exec",
                "--json",
                "--skip-git-repo-check",
                "--color", "never",
                prompt,
            ]

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

            // Exclusively accessed from readabilityHandler callback (serial per-Pipe)
            final class StderrCapture: Sendable {
                nonisolated(unsafe) var data = Data()
            }
            let stderrCapture = StderrCapture()
            stderr.fileHandleForReading.readabilityHandler = { h in
                stderrCapture.data.append(h.availableData)
            }

            // Exclusively accessed from readabilityHandler callback (serial per-Pipe)
            final class LineBuffer: Sendable {
                nonisolated(unsafe) var data = Data()
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
                buffer.data.append(data)

                while let nl = buffer.data.firstIndex(of: 0x0A) {
                    let lineData = buffer.data[..<nl]
                    buffer.data.removeSubrange(...nl)
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
                var fullStderr = stderrCapture.data
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
                continuation.yield(.error("无法启动 Codex: \(error.localizedDescription)"))
                continuation.finish()
            }
        }
    }

    static func parseLine(_ data: Data) -> StreamEvent? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        guard let type = json["type"] as? String else { return nil }

        switch type {
        case "item.completed":
            guard let item = json["item"] as? [String: Any] else { return nil }
            guard let itemType = item["type"] as? String else { return nil }

            if itemType == "agent_message",
               let text = item["text"] as? String,
               !text.isEmpty {
                return .text(text)
            }

            return nil

        case "error":
            let msg = (json["error"] as? String) ?? json["message"] as? String ?? "Codex 错误"
            return .error(msg)

        default:
            return nil
        }
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
