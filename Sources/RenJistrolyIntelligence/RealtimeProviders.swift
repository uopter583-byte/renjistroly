import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

public actor OpenAIRealtimeSession: RealtimeSession {
    public let name = "OpenAI Realtime"
    private var apiKey: String?
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var continuation: AsyncStream<RealtimeEvent>.Continuation?
    private var connected = false
    private var responseInProgress = false
    private var receiveTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var currentConfig: RealtimeConfig?

    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }

    public func updateAPIKey(_ key: String) {
        apiKey = key
    }

    // MARK: - Connect

    public func connect(config: RealtimeConfig) async throws -> AsyncStream<RealtimeEvent> {
        currentConfig = config
        guard let apiKey, !apiKey.isEmpty else {
            return localFallbackStream(message: "未配置 OpenAI API Key。请在设置中填入 API Key 以启用 Realtime 语音。")
        }

        do {
            let token = try await createEphemeralToken(apiKey: apiKey, config: config)
            try await openWebSocket(token: token, model: config.model)
            connected = true

            let (stream, cont) = AsyncStream<RealtimeEvent>.makeStream()
            self.continuation = cont
            cont.yield(.sessionStarted)

            try await sendJSON(sessionUpdateEvent(config: config))
            receiveTask?.cancel()
            startReceiveLoop()
            return stream
        } catch {
            return localFallbackStream(message: Self.readableError(error))
        }
    }

    private static func readableError(_ error: Error) -> String {
        let desc = error.localizedDescription
        if desc.contains("connect") || desc.contains("timed out") || desc.contains("timeout") || desc.contains("Could not connect") {
            return "无法连接 OpenAI Realtime 服务，请检查网络连接和 API Key 配置。"
        }
        if desc.contains("401") || desc.contains("Unauthorized") || desc.contains("unauthorized") || desc.contains("API key") {
            return "API Key 无效或已过期，请在设置中重新填写 OpenAI API Key。"
        }
        return "OpenAI Realtime 连接失败: \(desc)"
    }

    private func localFallbackStream(message: String) -> AsyncStream<RealtimeEvent> {
        let (stream, cont) = AsyncStream<RealtimeEvent>.makeStream()
        cont.yield(.sessionStarted)
        cont.yield(.failed(message))
        cont.finish()
        return stream
    }

    // MARK: - Ephemeral Token

    private func createEphemeralToken(apiKey: String, config: RealtimeConfig) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/realtime/sessions") else {
            throw NSError(domain: "OpenAIRealtime", code: 3, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": config.model,
            "voice": config.voice,
            "instructions": config.instructions,
            "modalities": ["text", "audio"],
            "input_audio_format": "pcm16",
            "output_audio_format": "pcm16",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "OpenAIRealtime", code: 1, userInfo: [NSLocalizedDescriptionKey: "创建会话失败: HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0) \(body)"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let clientSecret = json["client_secret"] as? [String: Any],
              let value = clientSecret["value"] as? String else {
            throw NSError(domain: "OpenAIRealtime", code: 2, userInfo: [NSLocalizedDescriptionKey: "解析 ephemeral token 失败"])
        }

        return value
    }

    // MARK: - WebSocket

    private func openWebSocket(token: String, model: String) async throws {
        guard let url = URL(string: "wss://api.openai.com/v1/realtime?model=\(model)") else {
            throw NSError(domain: "OpenAIRealtime", code: 4, userInfo: [NSLocalizedDescriptionKey: "无效的 URL"])
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        request.timeoutInterval = 30

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: request)
        task.resume()
        urlSession = session
        webSocketTask = task

        // Ping every 30s to keep connection alive
        pingTask = Task { [weak self] in
            while await self?.connected == true {
                try? await Task.sleep(for: .seconds(30))
                _ = await self?.webSocketTask?.sendPing { _ in }
            }
        }
    }

    private func sessionUpdateEvent(config: RealtimeConfig) -> [String: Any] {
        [
            "type": "session.update",
            "session": [
                "instructions": config.instructions,
                "voice": config.voice,
                "modalities": ["text", "audio"],
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": ["model": "whisper-1"],
                "turn_detection": [
                    "type": "server_vad",
                    "threshold": 0.5,
                    "prefix_padding_ms": 300,
                    "silence_duration_ms": 800,
                ],
            ],
        ]
    }

    // MARK: - Send

    public func sendAudio(_ frame: AudioFrame) async throws {
        guard connected else { return }
        let base64 = frame.data.base64EncodedString()
        try await sendJSON([
            "type": "input_audio_buffer.append",
            "audio": base64,
        ])
    }

    public func sendText(_ text: String) async throws {
        guard connected else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try await sendJSON([
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [["type": "input_text", "text": trimmed]],
            ],
        ])
        try await sendJSON(["type": "response.create"])
    }

    public func updateInstructions(_ instructions: String) async throws {
        guard connected else { return }
        try await sendJSON([
            "type": "session.update",
            "session": ["instructions": instructions],
        ])
    }

    public func commitAudio() async throws {
        guard connected else { return }
        try await sendJSON(["type": "input_audio_buffer.commit"])
        try await sendJSON(["type": "response.create"])
    }

    public func interrupt() async throws {
        guard connected else { return }
        try await sendJSON(["type": "response.cancel"])
        try await sendJSON(["type": "input_audio_buffer.clear"])
        responseInProgress = false
        continuation?.yield(.interrupted)
    }

    public func disconnect() async {
        connected = false
        pingTask?.cancel()
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.finishTasksAndInvalidate()
        urlSession = nil
        continuation?.finish()
        continuation = nil
        responseInProgress = false
    }

    // MARK: - Receive Loop

    private func startReceiveLoop() {
        receiveTask = Task { [weak self] in
            guard let self else { return }
            while await self.connected {
                guard let ws = await self.webSocketTask else { break }
                do {
                    let message = try await ws.receive()
                    switch message {
                    case .string(let text):
                        await self.handleMessage(text)
                    case .data(let data):
                        await self.continuation?.yield(.assistantAudioDelta(data))
                    @unknown default: break
                    }
                } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                    break
                } catch {
                    await self.yield(.failed(Self.readableError(error)))
                    await self.disconnect()
                    break
                }
            }
        }
    }

    // MARK: - Message Handling

    private func handleMessage(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "session.created", "session.updated":
            break // already handled

        case "input_audio_buffer.speech_started":
            // User started speaking — if we're currently responding, interrupt
            if responseInProgress {
                try? await interrupt()
            }

        case "input_audio_buffer.speech_stopped":
            // Silence detected, auto-commit
            try? await commitAudio()

        case "conversation.item.input_audio_transcription.completed":
            if let transcript = json["transcript"] as? String, !transcript.isEmpty {
                continuation?.yield(.transcriptDelta(transcript))
            }

        case "response.audio_transcript.delta":
            if let delta = json["delta"] as? String {
                continuation?.yield(.assistantTextDelta(delta))
            }

        case "response.text.delta":
            if let delta = json["delta"] as? String {
                continuation?.yield(.assistantTextDelta(delta))
            }

        case "response.audio.delta":
            if let encoded = json["delta"] as? String,
               let audioData = Data(base64Encoded: encoded) {
                continuation?.yield(.assistantAudioDelta(audioData))
            }

        case "response.content_part.done":
            break

        case "response.done":
            responseInProgress = false
            continuation?.yield(.completed)

        case "error":
            let message = (json["error"] as? [String: Any])?["message"] as? String ?? "未知错误"
            continuation?.yield(.failed(message))

        default:
            break
        }
    }

    // MARK: - Helpers

    private func sendJSON(_ dict: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: dict)
        let text = String(data: data, encoding: .utf8) ?? ""
        try await webSocketTask?.send(.string(text))
    }

    private func yield(_ event: RealtimeEvent) async {
        continuation?.yield(event)
    }
}

// MARK: - Local Realtime Session (pipeline-based)

public actor LocalRealtimeSession: RealtimeSession {
    public let name = "Local Pipeline Realtime"
    private let captureService: AudioCaptureService
    private let asrProvider: ASRProvider
    private let llmBackend: any LLMBackend
    private let ttsProvider: TTSProvider?
    private var instructions: String = ""
    private var continuation: AsyncStream<RealtimeEvent>.Continuation?
    private var captureTask: Task<Void, Never>?
    private var connected = false

    public init(
        captureService: AudioCaptureService,
        asrProvider: ASRProvider,
        llmBackend: any LLMBackend,
        ttsProvider: TTSProvider? = nil
    ) {
        self.captureService = captureService
        self.asrProvider = asrProvider
        self.llmBackend = llmBackend
        self.ttsProvider = ttsProvider
    }

    public func connect(config: RealtimeConfig) async throws -> AsyncStream<RealtimeEvent> {
        connected = true
        instructions = config.instructions

        let stream = AsyncStream<RealtimeEvent> { continuation in
            self.continuation = continuation
            continuation.yield(.sessionStarted)
        }
        return stream
    }

    public func sendAudio(_ frame: AudioFrame) async throws {
        guard connected else { return }
        // Audio frames are processed through the pipeline started by startListening()
        _ = frame
    }

    public func sendText(_ text: String) async throws {
        guard connected, let continuation else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        continuation.yield(.transcriptDelta(trimmed))
        await processTurn(userText: trimmed, continuation: continuation)
    }

    public func updateInstructions(_ instructions: String) async throws {
        self.instructions = instructions
    }

    public func disconnect() async {
        connected = false
        captureTask?.cancel()
        captureTask = nil
        await captureService.stop()
        continuation?.finish()
        continuation = nil
    }

    // MARK: - Pipeline

    public func startListening() async {
        guard connected, captureTask == nil else { return }
        guard let continuation else { return }

        captureTask = Task { [weak self] in
            guard let self else { return }
            do {
                let audioStream = try await self.captureService.start()
                let transcriptStream = try await self.asrProvider.transcribe(audioStream)

                for await event in transcriptStream {
                    if Task.isCancelled { break }
                    switch event {
                    case .partial(let text):
                        await self.yield(.transcriptDelta(text))
                    case .final(let text):
                        await self.yield(.transcriptDelta(text))
                        await self.processTurn(userText: text, continuation: continuation)
                    case .failed(let error):
                        await self.yield(.failed(error))
                    }
                }
            } catch {
                await self.yield(.failed(error.localizedDescription))
            }
        }
    }

    public func stopListening() async {
        captureTask?.cancel()
        captureTask = nil
        await captureService.stop()
    }

    // MARK: - Private

    private func yield(_ event: RealtimeEvent) async {
        continuation?.yield(event)
    }

    private func processTurn(
        userText: String,
        continuation: AsyncStream<RealtimeEvent>.Continuation
    ) async {
        var messages: [Message] = []
        if !instructions.isEmpty {
            messages.append(Message(id: UUID(), role: .system, content: [.text(instructions)]))
        }
        messages.append(Message(id: UUID(), role: .user, content: [.text(userText)]))

        let config = LLMConfiguration(
            provider: llmBackend.provider,
            model: "default",
            maxTokens: 2048,
            temperature: 0.7
        )

        do {
            let stream = try await llmBackend.chatStream(
                messages: messages,
                config: config,
                tools: nil,
                delegate: nil
            )
            var fullResponse = ""
            for await token in stream {
                fullResponse += token
                continuation.yield(.assistantTextDelta(token))
            }

            if !fullResponse.isEmpty {
                await speakResponse(fullResponse)
            }
            continuation.yield(.completed)
        } catch {
            continuation.yield(.failed(error.localizedDescription))
        }
    }

    private func speakResponse(_ text: String) async {
        guard let ttsProvider else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try? await ttsProvider.speak(trimmed)
    }
}

public struct ChineseAssistantPrompts {
    public static let system = """
    你是一个 macOS 原生中文语音助手。用户的语音已经由本机 Apple Speech 转成文字后传给你，
    所以你应该把收到的文本当作用户刚刚说的话来回答。不要说"我无法听到""我不能接收语音"
    或"请先输入文字"，除非用户明确询问系统能力限制。

    App 已经接入本机 Computer Use：可以通过 macOS 原生能力打开/切换 App、读取运行中 App、读取窗口、
    输入文本、复制粘贴、按快捷键、读取屏幕 OCR，并在本地安全层允许后执行。
    不要对打开 App、切换窗口、输入文字这类低风险本地动作说"我无法直接操作电脑"。
    如果动作没有被本地层拦截，你可以简短说明应该由本地动作层执行，并给出明确命令。
    你不能绕过本地安全层执行高风险动作；只能提出结构化动作，由本地安全层验证。
    对高风险、外部发送、删除、支付、提交表单、运行命令等动作，必须要求用户确认。

    当用户问到"屏幕""看到""当前界面""窗口"等问题时，你的上下文中已经预加载了屏幕数据——包括
    可见窗口列表、前台 App、焦点控件、选中文本。直接基于这些数据回答，不要再检查是否"没有数据"。
    你不需要说"我看不到"或"没有收到数据"——你已经有了，把它描述出来即可。

    在执行桌面操作时，系统会自动播报每步进度（如"打开应用""点击已完成"等），用户也可以随时
    用语音打断正在执行的操作。你不需要在回答中逐步骤描述操作过程，系统会通过语音自动播报。
    当用户打断时，直接处理新的语音指令即可，已取消的操作不需要在回答中提及。

    默认用简短中文回答，优先一到三句话。用户没有要求解释时，不要长篇说明。

    如果用户问"能不能听到""能不能发送出去"这类测试问题，直接根据当前链路回答：
    "可以，我已经收到你的语音转写：……"。如果发送指的是给模型发送请求，可以说明已经发送；
    如果发送指的是短信、邮件、微信等外部动作，说明需要用户给出目标和内容并确认。
    """
}
