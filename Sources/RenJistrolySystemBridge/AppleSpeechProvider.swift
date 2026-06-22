import Foundation
import RenJistrolyModels
@preconcurrency import Speech

@MainActor
public final class AppleSpeechProvider: ASRProvider {
    public let name = "Apple Speech"
    private let recognizer: SFSpeechRecognizer?

    public init(locale: Locale = Locale(identifier: "zh-CN")) {
        recognizer = SFSpeechRecognizer(locale: locale)
    }

    public func transcribe(_ frames: AsyncStream<AudioFrame>) async throws -> AsyncStream<TranscriptEvent> {
        guard let recognizer else { throw AppleSpeechError.notAvailable }
        guard recognizer.isAvailable else { throw AppleSpeechError.recognizerUnavailable }
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw AppleSpeechError.notAuthorized
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 13, *) {
            request.requiresOnDeviceRecognition = true
        }

        return AsyncStream { continuation in
            let task = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.yield(.failed(error.localizedDescription))
                    continuation.finish()
                    return
                }
                guard let result else { return }
                let text = result.bestTranscription.formattedString
                continuation.yield(result.isFinal ? .final(text) : .partial(text))
                if result.isFinal {
                    continuation.finish()
                }
            }

            Task {
                for await frame in frames {
                    request.append(frame.data, sampleRate: frame.sampleRate, channelCount: frame.channelCount)
                }
                request.endAudio()
            }

            continuation.onTermination = { _ in
                Task { @MainActor in
                    task.cancel()
                    request.endAudio()
                }
            }
        }
    }
}

public enum AppleSpeechError: Error, LocalizedError, Sendable {
    case notAvailable
    case notAuthorized
    case recognizerUnavailable

    public var errorDescription: String? {
        switch self {
        case .notAvailable: "当前系统不支持语音识别。"
        case .notAuthorized: "需要语音识别权限，请在系统设置中授权。"
        case .recognizerUnavailable: "语音识别引擎暂时不可用，请检查网络连接或稍后重试。"
        }
    }
}

private extension SFSpeechAudioBufferRecognitionRequest {
    func append(_ data: Data, sampleRate: Double, channelCount: Int) {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: AVAudioChannelCount(channelCount),
            interleaved: false
        )
        guard let format else { return }
        let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Float>.size / max(channelCount, 1))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        data.withUnsafeBytes { rawBuffer in
            guard let source = rawBuffer.bindMemory(to: Float.self).baseAddress else { return }
            for channel in 0..<Int(format.channelCount) {
                guard let destination = buffer.floatChannelData?[channel] else { continue }
                destination.update(from: source, count: Int(frameCount))
            }
        }
        append(buffer)
    }
}
