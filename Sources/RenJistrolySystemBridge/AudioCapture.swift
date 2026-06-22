import AVFoundation
import Foundation
import os
import RenJistrolyModels

@MainActor
public final class AVAudioCaptureService: AudioCaptureService {
    private nonisolated(unsafe) let engine = AVAudioEngine()
    private let lock = OSAllocatedUnfairLock()
    private nonisolated(unsafe) var _continuation: AsyncStream<AudioFrame>.Continuation?
    private nonisolated(unsafe) var hasTapInstalled = false
    private nonisolated(unsafe) var recursionDepth = 0
    private let maxRecursionDepth = 20

    public init() {}

    public func start() async throws -> AsyncStream<AudioFrame> {
        let hasCapacity = lock.withLock {
            guard recursionDepth < maxRecursionDepth else { return false }
            recursionDepth += 1
            return true
        }
        guard hasCapacity else {
            os_log(.error, "[AVAudioCaptureService] start failed: re-entrancy limit exceeded")
            throw AudioCaptureError.recursionLimitExceeded
        }
        defer { lock.withLock { recursionDepth -= 1 } }

        let stream = AsyncStream<AudioFrame> { [weak self] continuation in
            guard let self else { return }
            lock.withLock { _continuation = continuation }
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.stopSync()
                }
            }
        }

        if engine.isRunning { engine.stop() }
        if hasTapInstalled { engine.inputNode.removeTap(onBus: 0); hasTapInstalled = false }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let frame = AudioFrame(
                data: buffer.pcmData,
                sampleRate: format.sampleRate,
                channelCount: Int(format.channelCount)
            )
            _ = lock.withLock { _continuation?.yield(frame) }
        }
        hasTapInstalled = true

        engine.prepare()
        try engine.start()

        return stream
    }

    public func stop() async {
        stopSync()
    }

    private func stopSync() {
        lock.withLock {
            if engine.isRunning { engine.stop() }
            if hasTapInstalled { engine.inputNode.removeTap(onBus: 0); hasTapInstalled = false }
            let cont = _continuation
            _continuation = nil
            cont?.finish()
        }
    }
}

private enum AudioCaptureError: Error {
    case recursionLimitExceeded
}

private extension AVAudioPCMBuffer {
    var pcmData: Data {
        guard let buffer = audioBufferList.pointee.mBuffers.mData else { return Data() }
        return Data(bytes: buffer, count: Int(audioBufferList.pointee.mBuffers.mDataByteSize))
    }
}
