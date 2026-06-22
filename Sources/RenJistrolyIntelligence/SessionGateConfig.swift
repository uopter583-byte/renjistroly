import Foundation

// MARK: - Gate Configuration

public struct GateConfiguration: Sendable {
    /// Gate is an experimental feature. When false, the entire relay is disabled.
    public static let isExperimental: Bool = true
    public var timeoutSeconds: TimeInterval = 3.0
    /// Disabled by default — prevents Gate from auto-forwarding terminal commands.
    public var allowAutoTerminalInput: Bool = false

    public static let `default` = GateConfiguration()

    public init(timeoutSeconds: TimeInterval = 3.0, allowAutoTerminalInput: Bool = false) {
        self.timeoutSeconds = timeoutSeconds
        self.allowAutoTerminalInput = allowAutoTerminalInput
    }
}

extension AssistantSessionController {

    func loadGateSetting() {
        // Gate depends on an external relay process (`renjistroly-gate watch`)
        // that reads speech_in.txt and writes replies to reply_out.txt.
        // If the relay is not running, every request would wait 15s+ for
        // the fallback timeout (now 3s). We never restore Gate on launch
        // to avoid unexpected delays. The user must re-enable it explicitly,
        // and probeGate() will immediately detect whether a relay is alive.
        UserDefaults.standard.removeObject(forKey: "gateEnabled")
        gateEnabled = false
    }

    func writeToSpeechFile(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(atPath: gateDir, withIntermediateDirectories: true)
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let escaped = trimmed.replacingOccurrences(of: "\"", with: "\\\"")
            let entry = #"{"text":"\#(escaped)","time":"\#(timestamp)"}"# + "\n"
            if let data = entry.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: speechFilePath) {
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: speechFilePath),
                       let fileSize = attrs[.size] as? Int, fileSize > 100_000 {
                        try data.write(to: URL(fileURLWithPath: speechFilePath))
                    } else {
                        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: speechFilePath))
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    try data.write(to: URL(fileURLWithPath: speechFilePath))
                }
            }
        } catch {
            foundationMessage = "Gate 写入失败：\(error.localizedDescription)"
            Task { await eventBus.publish(.system(.errorOccurred(domain: "gate", message: error.localizedDescription, recoverable: true))) }
        }
        Task { await eventBus.publish(.system(.gateMessageSent(text: trimmed))) }
    }

    func startGateReplyLoop() {
        gateReplyTask?.cancel()
        let _replyPath = replyFilePath
        gateReplyTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                do {
                    if !FileManager.default.fileExists(atPath: _replyPath) {
                        try? FileManager.default.createDirectory(atPath: self?.gateDir ?? "/tmp/renjistroly", withIntermediateDirectories: true)
                    }
                    let replyURL = URL(fileURLWithPath: _replyPath)
                    let tmpURL = URL(fileURLWithPath: _replyPath + ".reading")
                    if FileManager.default.fileExists(atPath: _replyPath) {
                        try? FileManager.default.moveItem(at: replyURL, to: tmpURL)
                        if let data = try? Data(contentsOf: tmpURL),
                           let replyText = String(data: data, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                           !replyText.isEmpty {
                            try? FileManager.default.removeItem(at: tmpURL)
                            guard let self else { continue }
                            await MainActor.run {
                                self.gateTimeoutTask?.cancel()
                                self.gateTimeoutTask = nil
                                self.pendingGateSpeech = nil
                                self.voiceState.latestAssistantText = replyText
                                self.voiceState.isThinking = false
                                Task { await self.eventBus.publish(.system(.gateReplyReceived(text: replyText))) }
                            }
                            await self.speak(replyText)
                        }
                    }
                }
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
    }

    /// Probe whether the external Gate relay is alive by writing a probe message
    /// and checking for a quick response. Sets `gateIsConnected` based on result.
    func probeGate() {
        gateProbeTask?.cancel()
        gateProbeTask = Task { [weak self] in
            guard let self else { return }
            // Quick check: see if any process has speech_in.txt open for reading
            let hasReader = await Self.hasGateReader()
            guard !hasReader else {
                await MainActor.run { self.gateIsConnected = true }
                return
            }
            // Slower: write a probe and wait briefly for a reply
            let probeMessage = "{\"probe\":true,\"time\":\"\(ISO8601DateFormatter().string(from: Date()))\"}\n"
            let probeURL = URL(fileURLWithPath: self.speechFilePath)
            // Clear any stale reply
            let replyURL = URL(fileURLWithPath: self.replyFilePath)
            try? "".write(to: replyURL, atomically: true, encoding: .utf8)
            try? FileManager.default.createDirectory(atPath: self.gateDir, withIntermediateDirectories: true)
            try? probeMessage.write(to: probeURL, atomically: true, encoding: .utf8)
            try? await Task.sleep(nanoseconds: Self.gateProbeTimeoutNanos)
            guard !Task.isCancelled else { return }
            let connected: Bool
            if let data = try? Data(contentsOf: replyURL),
               let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                connected = true
            } else if await Self.hasGateReader() {
                connected = true
            } else {
                connected = false
            }
            // Restore empty reply so the loop doesn't pick up stale data
            if !connected {
                try? "".write(to: replyURL, atomically: true, encoding: .utf8)
            }
            await MainActor.run {
                self.gateIsConnected = connected
                if !connected {
                    self.voiceState.latestAssistantText = "Gate 中继未连接：未检测到外部进程。消息将由本地处理。"
                    Task { await self.eventBus.publish(.system(.gateMessageSent(text: "Gate probe failed — no relay process"))) }
                }
            }
        }
    }

    /// Check if any process currently has the speech file open for reading (a reliable signal
    /// that a Gate relay is listening).
    private static func hasGateReader() async -> Bool {
        let path = "/tmp/renjistroly/speech_in.txt"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = [path]
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        do {
            let output = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                task.terminationHandler = { _ in
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
                }
                do { try task.run() } catch { cont.resume(throwing: error) }
            }
            // lsof exits 0 with output when file is open; exits non-zero or empty when no-one has it open
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return false
        }
    }
}
