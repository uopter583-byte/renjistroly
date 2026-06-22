import Foundation
@preconcurrency import Speech
import AVFoundation
import os
import RenJistrolyModels

private let voiceLog = OSLog(subsystem: "com.renjistroly", category: "voice")

private final class SpeechContinuationGate: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock()
    private var didResume = false

    func tryResume() -> Bool {
        lock.withLock {
            guard !didResume else { return false }
            didResume = true
            return true
        }
    }
}

public final class MacOSSpeechRecognizer: STTProvider, Sendable {

    private nonisolated(unsafe) let speechRecognizer: SFSpeechRecognizer?
    private nonisolated(unsafe) let audioEngine = AVAudioEngine()
    private let lock = OSAllocatedUnfairLock()
    nonisolated(unsafe) private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    nonisolated(unsafe) private var recognitionTask: SFSpeechRecognitionTask?
    nonisolated(unsafe) private var streamContinuation: AsyncStream<String>.Continuation?
    nonisolated(unsafe) private var isStreamFinished = false
    nonisolated(unsafe) private var tapInstalled = false

    public init(locale: Locale = Locale(identifier: "zh-CN")) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        os_log("[init] locale=%{public}@ recognizer=%{public}@", log: voiceLog, type: .info, locale.identifier, speechRecognizer == nil ? "nil" : "OK")
    }

    public var isAuthorized: Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        os_log("[isAuthorized] status=%d", log: voiceLog, type: .debug, status.rawValue)
        return status == .authorized
    }

    public func requestAuthorization() async -> Bool {
        os_log("[requestAuthorization] requesting...", log: voiceLog, type: .info)
        let result = await SpeechAuthorizationRequester.requestAuthorized()
        os_log("[requestAuthorization] result=%{public}@", log: voiceLog, type: .info, result ? "granted" : "denied")
        return result
    }

    public func transcribe(_ audioData: Data, language: String) async throws -> String {
        guard let recognizer = speechRecognizer else {
            os_log("[transcribe] speechRecognizer is nil", log: voiceLog, type: .error)
            throw STTError.notAvailable
        }
        guard isAuthorized else {
            os_log("[transcribe] not authorized", log: voiceLog, type: .error)
            throw STTError.noPermission
        }

        os_log("[transcribe] starting transcription...", log: voiceLog, type: .info)
        return try await withCheckedThrowingContinuation { cont in
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = false
            let resumeGate = SpeechContinuationGate()
            lock.withLock {
                recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        guard resumeGate.tryResume() else { return }
                        os_log("[transcribe] recognition error: %{public}@", log: voiceLog, type: .error, error.localizedDescription)
                        cont.resume(throwing: error)
                        return
                    }
                    if let result = result, result.isFinal {
                        guard resumeGate.tryResume() else { return }
                        os_log("[transcribe] success", log: voiceLog, type: .info)
                        cont.resume(returning: result.bestTranscription.formattedString)
                    }
                }
            }
        }
    }

    public func startStreaming() async throws -> AsyncStream<String> {
        os_log("[startStreaming] called", log: voiceLog, type: .info)

        guard let recognizer = speechRecognizer else {
            os_log("[startStreaming] speechRecognizer is nil", log: voiceLog, type: .error)
            throw STTError.notAvailable
        }
        guard isAuthorized else {
            os_log("[startStreaming] not authorized", log: voiceLog, type: .error)
            throw STTError.noPermission
        }

        os_log("[startStreaming] recognizer.isAvailable=%{public}@", log: voiceLog, type: .info, recognizer.isAvailable ? "true" : "false")
        stopStreaming()

        let (stream, continuation) = AsyncStream<String>.makeStream()

        self.lock.withLock {
            self.streamContinuation = continuation
            self.isStreamFinished = false
        }

        guard recognizer.isAvailable else {
            os_log("[startStreaming] recognizer not available", log: voiceLog, type: .error)
            lock.withLock { streamContinuation = nil }
            continuation.finish()
            return stream
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 13, *) {
            // On-device recognition disabled for compatibility — avoids "No speech detected" errors
        }

        self.lock.withLock {
            self.recognitionRequest = request
            self.recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                let finished = self.lock.withLock { self.isStreamFinished }
                guard !finished else { return }
                if let error = error {
                    os_log("[recognitionTask] error: %{public}@", log: voiceLog, type: .error, error.localizedDescription)
                    continuation.yield("[识别错误: \(error.localizedDescription)]")
                    continuation.finish()
                    return
                }
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    os_log("[recognitionTask] partial result: %{public}@ (isFinal=%{public}@)", log: voiceLog, type: .debug, text, result.isFinal ? "true" : "false")
                    continuation.yield(text)
                    if result.isFinal {
                        continuation.finish()
                    }
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        os_log("[startStreaming] installing tap, format=%{public}@", log: voiceLog, type: .debug, "\(format.sampleRate)Hz \(format.channelCount)ch")
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.lock.withLock { self.recognitionRequest?.append(buffer) }
        }
        self.lock.withLock { self.tapInstalled = true }

        audioEngine.prepare()

        continuation.onTermination = { [weak self] _ in
            os_log("[stream] terminated", log: voiceLog, type: .debug)
            Task { @MainActor in self?.stopStreaming() }
        }

        do {
            try audioEngine.start()
            os_log("[startStreaming] audioEngine started successfully", log: voiceLog, type: .info)
        } catch {
            os_log("[startStreaming] audioEngine start failed: %{public}@", log: voiceLog, type: .error, error.localizedDescription)
            stopStreaming()
            let desc = error.localizedDescription
            if desc.contains("connect") || desc.contains("server") {
                throw STTError.audioServiceUnavailable
            }
            throw error
        }

        return stream
    }

    public func stopStreaming() {
        os_log("[stopStreaming] called", log: voiceLog, type: .info)
        audioEngine.stop()
        let cont = lock.withLock {
            if tapInstalled {
                audioEngine.inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            isStreamFinished = true
            recognitionRequest?.endAudio()
            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest = nil
            let c = streamContinuation
            streamContinuation = nil
            return c
        }
        cont?.finish()
    }
}

public enum STTError: Error, LocalizedError, Sendable {
    case noPermission
    case notAvailable
    case recognitionFailed
    case audioServiceUnavailable

    public var errorDescription: String? {
        switch self {
        case .noPermission: "需要语音识别权限，请在系统设置中授权。"
        case .notAvailable: "当前设备不支持语音识别。"
        case .recognitionFailed: "语音识别失败，请重试。"
        case .audioServiceUnavailable: "麦克风或音频服务不可用，请检查麦克风权限和音频输入设备。"
        }
    }
}
