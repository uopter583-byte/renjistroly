import AVFoundation
import Foundation
import os
import RenJistrolyModels

@MainActor
public final class SystemTextToSpeech: NSObject, TTSProvider {
    public let name = "macOS System TTS"
    public var speechRateMultiplier: Double
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private let stopLock = OSAllocatedUnfairLock(initialState: false)

    public init(speechRateMultiplier: Double = 1.9) {
        self.speechRateMultiplier = speechRateMultiplier
        super.init()
        synthesizer.delegate = self
    }

    public func speak(_ text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stopLock.withLock { $0 = true }
        await stop()
        stopLock.withLock { $0 = false }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = min(
            AVSpeechUtteranceMaximumSpeechRate,
            AVSpeechUtteranceDefaultSpeechRate * Float(speechRateMultiplier)
        )

        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    public func stop() async {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finish()
    }

    private func finish() {
        continuation?.resume()
        continuation = nil
    }
}

extension SystemTextToSpeech: AVSpeechSynthesizerDelegate {
    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let stopping = stopLock.withLock { $0 }
        guard !stopping else { return }
        Task { @MainActor in
            self.finish()
        }
    }

    public nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let stopping = stopLock.withLock { $0 }
        guard !stopping else { return }
        Task { @MainActor in
            self.finish()
        }
    }
}
