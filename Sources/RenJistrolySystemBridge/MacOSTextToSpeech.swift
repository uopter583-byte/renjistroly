import AVFoundation
import os

@MainActor
public final class MacOSTextToSpeech: NSObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?
    private let genLock = OSAllocatedUnfairLock(initialState: 0)

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public var availableVoices: [String] {
        AVSpeechSynthesisVoice.speechVoices().map(\.identifier)
    }

    public var isSpeaking: Bool {
        synthesizer.isSpeaking
    }

    public func speak(_ text: String, voiceIdentifier: String? = nil, rate: Float? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stop()
        genLock.withLock { $0 &+= 1 }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = voiceIdentifier.flatMap { AVSpeechSynthesisVoice(identifier: $0) }
            ?? AVSpeechSynthesisVoice(language: "zh-CN")
        if let rate {
            utterance.rate = rate
        }

        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    public func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finishSpeaking()
    }

    private func finishSpeaking() {
        continuation?.resume()
        continuation = nil
    }
}

extension MacOSTextToSpeech: AVSpeechSynthesizerDelegate {
    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let gen = genLock.withLock { $0 }
        Task { @MainActor in
            guard gen == genLock.withLock({ $0 }) else { return }
            finishSpeaking()
        }
    }

    public nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        let gen = genLock.withLock { $0 }
        Task { @MainActor in
            guard gen == genLock.withLock({ $0 }) else { return }
            finishSpeaking()
        }
    }
}
