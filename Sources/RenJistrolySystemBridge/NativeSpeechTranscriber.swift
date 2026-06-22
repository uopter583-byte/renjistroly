import AVFoundation
import Foundation
import os
@preconcurrency import RenJistrolyModels
@preconcurrency import Speech

private let voiceLog = OSLog(subsystem: "com.renjistroly", category: "voice")

// SFSpeechAudioBufferRecognitionRequest is non-Sendable but used from
// installTap callbacks on the audio thread. Wrap to bypass isolation tracking.
private final class SendableBufferRequest: Sendable {
    nonisolated(unsafe) let request: SFSpeechAudioBufferRecognitionRequest
    init(_ request: SFSpeechAudioBufferRecognitionRequest) { self.request = request }
}

private enum TranscriberEventBridge {
    /// Convert system-level errors into user-facing Chinese messages.
    static func readableMessage(_ error: Error) -> String {
        let desc = error.localizedDescription
        if desc.contains("connect to the server") || desc.contains("kLSRErrorDomain") {
            return "语音识别服务不可用，请检查「系统设置 > 隐私与安全性 > 语音识别」已开启。"
        }
        if desc.contains("No audio input") || desc.contains("no audio") {
            return "未检测到麦克风输入设备。"
        }
        return desc
    }
}

public final class NativeSpeechTranscriber: Sendable {
    private nonisolated(unsafe) let recognizer: SFSpeechRecognizer?
    private nonisolated(unsafe) let audioEngine = AVAudioEngine()

    // Request and task stored synchronously to avoid the race between async
    // actor store() and async reset(). Lock ensures thread-safe access from
    // both the start() caller and recognition/tap callbacks.
    private let ioLock = OSAllocatedUnfairLock()
    private nonisolated(unsafe) var activeRequest: SFSpeechAudioBufferRecognitionRequest?
    private nonisolated(unsafe) var activeTask: SFSpeechRecognitionTask?
    private nonisolated(unsafe) var activeContinuation: AsyncStream<TranscriptEvent>.Continuation?
    private nonisolated(unsafe) var activeSessionID: UUID?
    private nonisolated(unsafe) var tapInstalled = false
    private nonisolated(unsafe) var recursionDepth = 0
    private let maxRecursionDepth = 20

    public init(locale: Locale = Locale(identifier: "zh-CN")) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    nonisolated public func start() throws -> AsyncStream<TranscriptEvent> {
        let hasCapacity = ioLock.withLock {
            guard recursionDepth < maxRecursionDepth else { return false }
            recursionDepth += 1
            return true
        }
        guard hasCapacity else {
            os_log("[NativeSpeechTranscriber] start failed: re-entrancy limit exceeded", log: voiceLog, type: .error)
            throw NativeSpeechTranscriberError.recursionLimitExceeded
        }
        defer { ioLock.withLock { recursionDepth -= 1 } }

        guard let recognizer else {
            os_log("[NativeSpeechTranscriber] start failed: recognizer is nil", log: voiceLog, type: .error)
            throw NativeSpeechTranscriberError.notAvailable
        }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            os_log("[NativeSpeechTranscriber] start failed: not authorized", log: voiceLog, type: .error)
            throw NativeSpeechTranscriberError.notAuthorized
        }

        os_log("[NativeSpeechTranscriber] start — recognizer locale=%{public}@ isAvailable=%{public}@", log: voiceLog, type: .info, recognizer.locale.identifier, recognizer.isAvailable ? "true" : "false")
        stop()

        guard recognizer.isAvailable else {
            os_log("[NativeSpeechTranscriber] recognizer not available at request time", log: voiceLog, type: .error)
            throw NativeSpeechTranscriberError.recognizerUnavailable
        }

        let sessionID = UUID()
        let (stream, continuation) = AsyncStream.makeStream(of: TranscriptEvent.self)

        continuation.onTermination = { [weak self] _ in
            os_log("[NativeSpeechTranscriber] stream terminated", log: voiceLog, type: .debug)
            self?.stop()
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 13, *) {
            os_log("[NativeSpeechTranscriber] requiresOnDeviceRecognition=false (disabled for compatibility)", log: voiceLog, type: .debug)
        }

        let task = recognizer.recognitionTask(with: request) { result, error in
            if let error {
                os_log("[NativeSpeechTranscriber] recognitionTask error: %{public}@", log: voiceLog, type: .error, error.localizedDescription)
                self.handleError(error, sessionID: sessionID)
                return
            }
            guard let result else {
                os_log("[NativeSpeechTranscriber] recognitionTask: nil result, no error", log: voiceLog, type: .debug)
                return
            }
            os_log("[NativeSpeechTranscriber] recognitionTask result: isFinal=%{public}@ text=%{public}@", log: voiceLog, type: .debug, result.isFinal ? "true" : "false", result.bestTranscription.formattedString)
            self.handleResult(result, sessionID: sessionID)
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        os_log("[NativeSpeechTranscriber] audio format: %{public}@", log: voiceLog, type: .debug, "\(format.sampleRate)Hz \(format.channelCount)ch")
        let sendableRequest = SendableBufferRequest(request)
        // @convention(block) avoids Swift's closure-to-ObjC-block bridging
        // which inserts _swift_task_checkIsolatedSwift for the audio thread.
        let tapBlock: @convention(block) (AVAudioPCMBuffer, AVAudioTime) -> Void = { buffer, _ in
            sendableRequest.request.append(buffer)
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: tapBlock)
        ioLock.withLock { tapInstalled = true }

        // Store request/task synchronously to avoid race with stop()
        ioLock.withLock {
            activeSessionID = sessionID
            activeContinuation = continuation
            activeRequest = request
            activeTask = task
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            os_log("[NativeSpeechTranscriber] audioEngine started successfully", log: voiceLog, type: .info)
        } catch {
            os_log("[NativeSpeechTranscriber] audioEngine start failed: %{public}@", log: voiceLog, type: .error, error.localizedDescription)
            stop()
            throw Self.readableError(error)
        }

        return stream
    }

    public func stop() {
        os_log("[NativeSpeechTranscriber] stop called, audioEngine.isRunning=%{public}@", log: voiceLog, type: .info, audioEngine.isRunning ? "true" : "false")
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        let continuation = ioLock.withLock {
            if tapInstalled {
                audioEngine.inputNode.removeTap(onBus: 0)
                tapInstalled = false
            }
            activeRequest?.endAudio()
            activeTask?.cancel()
            activeRequest = nil
            activeTask = nil
            activeSessionID = nil
            let c = activeContinuation
            activeContinuation = nil
            return c
        }
        continuation?.finish()
    }

    private func handleError(_ error: Error, sessionID: UUID) {
        let msg = TranscriberEventBridge.readableMessage(error)
        os_log("[NativeSpeechTranscriber] handleError: %{public}@", log: voiceLog, type: .error, msg)
        let continuation = ioLock.withLock {
            guard activeSessionID == sessionID else { return nil as AsyncStream<TranscriptEvent>.Continuation? }
            let c = activeContinuation
            activeContinuation = nil
            activeSessionID = nil
            activeRequest = nil
            activeTask = nil
            return c
        }
        continuation?.yield(.failed(msg))
        continuation?.finish()
    }

    private func handleResult(_ result: SFSpeechRecognitionResult, sessionID: UUID) {
        let text = result.bestTranscription.formattedString
        os_log("[NativeSpeechTranscriber] handleResult isFinal=%{public}@ text=%{public}@", log: voiceLog, type: .debug, result.isFinal ? "true" : "false", text)
        let continuation = ioLock.withLock {
            guard activeSessionID == sessionID else { return nil as AsyncStream<TranscriptEvent>.Continuation? }
            if result.isFinal {
                let c = activeContinuation
                activeContinuation = nil
                activeSessionID = nil
                activeRequest = nil
                activeTask = nil
                return c
            }
            return activeContinuation
        }
        continuation?.yield(result.isFinal ? .final(text) : .partial(text))
        if result.isFinal {
            continuation?.finish()
        }
    }

    /// Wrap AVAudioEngine.start() errors with user-facing Chinese descriptions.
    private static func readableError(_ error: Error) -> Error {
        let desc = error.localizedDescription
        if desc.contains("connect") || desc.contains("server") {
            return NativeSpeechTranscriberError.audioServiceUnavailable
        }
        if desc.contains("no audio") || desc.contains("No audio") {
            return NativeSpeechTranscriberError.noAudioInput
        }
        return error
    }

}

public enum NativeSpeechTranscriberError: Error, LocalizedError, Sendable {
    case notAvailable
    case notAuthorized
    case recognizerUnavailable
    case audioServiceUnavailable
    case noAudioInput
    case recursionLimitExceeded

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            "语音识别服务暂时不可用，请在「系统设置 > 辅助功能 > 语音识别」中确认中文语音已启用，或等待服务启动后重试。"
        case .notAuthorized:
            "需要语音识别权限。"
        case .recognizerUnavailable:
            "语音识别模型未就绪，请等待下载完成或在「系统设置 > 隐私与安全性 > 语音识别」中确认中文语音已启用后重试。"
        case .audioServiceUnavailable:
            "语音识别服务不可用，请检查「系统设置 > 隐私与安全性 > 语音识别」已开启，或重启电脑后重试。"
        case .noAudioInput:
            "未检测到麦克风输入设备，请检查麦克风连接和权限。"
        case .recursionLimitExceeded:
            "语音识别服务调用过于频繁，请稍后重试。"
        }
    }
}
