import Foundation
import RenJistrolyModels
@preconcurrency import COrt

/// Sendable wrapper around OpaquePointer for @MainActor isolation compliance.
// @unchecked Sendable: wraps non-Sendable OpaquePointer (OrtSession); internal queue serializes access
private struct SessionRef: @unchecked Sendable {
    let ptr: OpaquePointer
}

@MainActor
public final class NemotronASRProvider: ASRProvider {
    public let name = "Nemotron 3.5 ASR"

    private let preEncodeSession: SessionRef
    private let conformerSession: SessionRef
    private let promptSession: SessionRef
    private let decoderSession: SessionRef
    private let jointSession: SessionRef

    private let melProcessor = MelSpectrogramProcessor()
    private let decoder: RNNTGreedyDecoder

    private let tokens: [String]
    private let promptIndex: Int64 = 4  // zh-CN
    private let encoderDim = 1024
    private let blankID: Int32 = 0

    public init() throws {
        func load(_ name: String) throws -> OpaquePointer {
            guard let url = Bundle.module.url(forResource: name, withExtension: "onnx") else {
                throw NemotronError.modelNotFound(name)
            }
            let data = try Data(contentsOf: url)
            return try data.withUnsafeBytes { ptr in
                guard let baseAddress = ptr.baseAddress else {
                    throw NemotronError.modelNotFound(name + " (empty data)")
                }
                guard let session = cort_session_create(
                    baseAddress.assumingMemoryBound(to: UInt8.self),
                    ptr.count
                ) else {
                    throw NemotronError.modelNotFound(name + " (session create failed)")
                }
                return session
            }
        }

        func loadFromPath(_ name: String) throws -> OpaquePointer {
            guard let path = Bundle.module.path(forResource: name, ofType: "onnx") else {
                throw NemotronError.modelNotFound(name)
            }
            guard let session = cort_session_create_from_path(path) else {
                throw NemotronError.modelNotFound(name + " (session create failed)")
            }
            return session
        }

        preEncodeSession = SessionRef(ptr: try load("pre_encode"))
        conformerSession = SessionRef(ptr: try loadFromPath("conformer"))
        promptSession   = SessionRef(ptr: try load("prompt"))
        decoderSession  = SessionRef(ptr: try load("decoder"))
        jointSession    = SessionRef(ptr: try load("joint"))

        decoder = RNNTGreedyDecoder(
            decoderSession: decoderSession.ptr,
            jointSession: jointSession.ptr
        )

        let tokenURL = Bundle.module.url(forResource: "tokens", withExtension: "txt")!
        let tokenText = try String(contentsOf: tokenURL, encoding: .utf8)
        tokens = tokenText.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    deinit {
        cort_session_destroy(preEncodeSession.ptr)
        cort_session_destroy(conformerSession.ptr)
        cort_session_destroy(promptSession.ptr)
        cort_session_destroy(decoderSession.ptr)
        cort_session_destroy(jointSession.ptr)
    }

    // MARK: - ASRProvider

    public func transcribe(_ frames: AsyncStream<AudioFrame>) async throws -> AsyncStream<TranscriptEvent> {
        return AsyncStream { continuation in
            Task {
                var accumulatedData = Data()
                for await frame in frames {
                    accumulatedData.append(frame.data)
                }

                let sampleCount = accumulatedData.count / MemoryLayout<Float>.stride
                guard sampleCount > 0 else {
                    continuation.yield(.failed("没有音频数据"))
                    continuation.finish()
                    return
                }

                let audioFloats: [Float] = accumulatedData.withUnsafeBytes { ptr in
                    let bound = ptr.bindMemory(to: Float.self)
                    return Array(UnsafeBufferPointer(start: bound.baseAddress, count: sampleCount))
                }

                do {
                    let text = try self.runInference(audio: audioFloats)
                    continuation.yield(.final(text))
                } catch {
                    continuation.yield(.failed(error.localizedDescription))
                }
                continuation.finish()
            }
        }
    }

    // MARK: - Inference Pipeline

    private func runInference(audio: [Float]) throws -> String {
        // 1. Mel spectrogram
        let (features, _) = melProcessor.process(audio: audio)

        // 2. pre_encode
        let (preEncoded, preFrames) = try runPreEncode(features: features)

        // 3. Get prompt vector and add to pre_encode output
        let promptVec = try getPromptVector()
        var x = preEncoded
        for t in 0..<preFrames {
            let base = t * encoderDim
            for c in 0..<encoderDim {
                x[base + c] += promptVec[c]
            }
        }

        // 4. conformer
        let encoderOut = try runConformer(x: x, length: Int64(preFrames))

        // 5. Greedy decode
        let tokenIDs = decoder.decode(encoderOut: encoderOut, numFrames: preFrames)
        decoder.reset()

        // 6. Decode tokens
        return decodeTokens(tokenIDs)
    }

    // MARK: - ONNX Sessions

    private func runPreEncode(features: [Float]) throws -> (output: [Float], numFrames: Int) {
        var feat = features
        var lengths: Int64 = Int64(features.count / 128)

        return try feat.withUnsafeMutableBufferPointer { featBuf in
            var outPtr: UnsafeMutablePointer<OpaquePointer?>?
            var numOut: Int64 = 0
            var featShape: [Int64] = [1, 128, lengths]
            var lenShape = [Int64(1)]

            var tensor: OpaquePointer? = nil
            try withCStringPointers(["audio_signal", "length"]) { names in
                try featShape.withUnsafeMutableBufferPointer { fsBuf in
                    try lenShape.withUnsafeMutableBufferPointer { lsBuf in
                        try withUnsafeBytes(of: &lengths) { lengthBytes in
                            var inputs: [COrtInput] = [
                                COrtInput(name: names[0], data_type: COrtDataTypeFloat,
                                          shape: fsBuf.baseAddress, ndim: 3,
                                          data: featBuf.baseAddress, data_len: Int64(featBuf.count)),
                                COrtInput(name: names[1], data_type: COrtDataTypeInt64,
                                          shape: lsBuf.baseAddress, ndim: 1,
                                          data: lengthBytes.baseAddress, data_len: 1),
                            ]

                            let rc = cort_run_batch(preEncodeSession.ptr, &inputs, 2, &outPtr, &numOut)
                            guard rc == 0, let ptr = outPtr, numOut >= 1, let t = ptr[0] else {
                                throw NemotronError.inferenceFailed("pre_encode")
                            }
                            tensor = t
                            // Destroy output tensors other than the first (we still need that one)
                            for i in 1..<Int(numOut) { if let t = ptr[i] { cort_tensor_destroy(t) } }
                        }
                    }
                }
            }

            guard let t = tensor else { throw NemotronError.inferenceFailed("pre_encode") }
            defer {
                cort_tensor_destroy(t)
                outPtr?.deallocate()
            }

            let count = Int(cort_tensor_size(t))
            var result = [Float](repeating: 0, count: count)
            if let data = cort_tensor_data(t) {
                for i in 0..<count { result[i] = data[i] }
            }

            var ndim: Int64 = 0
            if let shape = cort_tensor_shape(t, &ndim), ndim >= 2 {
                return (result, Int(shape[Int(ndim) - 1]))
            }
            return (result, count / encoderDim)
        }
    }

    private func getPromptVector() throws -> [Float] {
        var idx = promptIndex
        var shape = [Int64(1), 1]
        var tensor: OpaquePointer? = nil
        var outPtr: UnsafeMutablePointer<OpaquePointer?>?
        var numOut: Int64 = 0

        try withCStringPointers(["prompt_idx"]) { names in
            try shape.withUnsafeMutableBufferPointer { buf in
                try withUnsafeBytes(of: &idx) { idxBytes in
                    var input = COrtInput(name: names[0], data_type: COrtDataTypeInt64,
                                          shape: buf.baseAddress, ndim: 2,
                                          data: idxBytes.baseAddress, data_len: 1)

                    let rc = cort_run_batch(promptSession.ptr, &input, 1, &outPtr, &numOut)
                    guard rc == 0, let ptr = outPtr, numOut >= 1, let t = ptr[0] else {
                        throw NemotronError.inferenceFailed("prompt")
                    }
                    tensor = t
                }
            }
        }

        guard let t = tensor else { throw NemotronError.inferenceFailed("prompt") }
        defer {
            cort_tensor_destroy(t)
            outPtr?.deallocate()
        }

        let count = Int(cort_tensor_size(t))
        var result = [Float](repeating: 0, count: count)
        if let data = cort_tensor_data(t) {
            for i in 0..<count { result[i] = data[i] }
        }
        return result
    }

    private func runConformer(x: [Float], length: Int64) throws -> [Float] {
        var inputData = x
        var len = length

        return try inputData.withUnsafeMutableBufferPointer { buf in
            var outPtr: UnsafeMutablePointer<OpaquePointer?>?
            var numOut: Int64 = 0
            var xShape = [Int64(1), Int64(encoderDim), length]
            var lenShape = [Int64(1)]

            var tensor: OpaquePointer? = nil
            try withCStringPointers(["encoder_input", "length"]) { names in
                try xShape.withUnsafeMutableBufferPointer { xsBuf in
                    try lenShape.withUnsafeMutableBufferPointer { lsBuf in
                        try withUnsafeBytes(of: &len) { lenBytes in
                            var inputs: [COrtInput] = [
                                COrtInput(name: names[0], data_type: COrtDataTypeFloat,
                                          shape: xsBuf.baseAddress, ndim: 3,
                                          data: buf.baseAddress, data_len: Int64(buf.count)),
                                COrtInput(name: names[1], data_type: COrtDataTypeInt64,
                                          shape: lsBuf.baseAddress, ndim: 1,
                                          data: lenBytes.baseAddress, data_len: 1),
                            ]

                            let rc = cort_run_batch(conformerSession.ptr, &inputs, 2, &outPtr, &numOut)
                            guard rc == 0, let ptr = outPtr, numOut >= 1, let t = ptr[0] else {
                                throw NemotronError.inferenceFailed("conformer")
                            }
                            tensor = t
                            for i in 1..<Int(numOut) { if let t = ptr[i] { cort_tensor_destroy(t) } }
                        }
                    }
                }
            }

            guard let t = tensor else { throw NemotronError.inferenceFailed("conformer") }
            defer {
                cort_tensor_destroy(t)
                outPtr?.deallocate()
            }

            let count = Int(cort_tensor_size(t))
            var result = [Float](repeating: 0, count: count)
            if let data = cort_tensor_data(t) {
                for i in 0..<count { result[i] = data[i] }
            }
            return result
        }
    }

    // MARK: - Token Decoding

    private func decodeTokens(_ ids: [Int32]) -> String {
        ids.map { id in
            let idx = Int(id - 1)
            guard idx >= 0, idx < tokens.count else { return "" }
            return tokens[idx]
        }.joined()
        // Proper BPE decoding: replace ▁ (U+2581) with space between words,
        // merge subwords that don't start with ▁
        .replacingOccurrences(of: "\u{2581}", with: " ")
        .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Errors

public enum NemotronError: Error, LocalizedError {
    case modelNotFound(String)
    case inferenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let name): "Nemotron ASR 模型加载失败: \(name)"
        case .inferenceFailed(let name): "模型推理失败 (\(name))"
        }
    }
}
