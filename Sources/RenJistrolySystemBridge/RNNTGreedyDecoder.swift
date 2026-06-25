import Foundation
import COrt

/// Pure Swift RNNT greedy decoder state machine.
///
/// Manages decoder LSTM state (2-layer h/c) and runs the prediction-network
/// (decoder) + joint network ONNX inference via COrt for blank-augmented
/// greedy decoding.  Follows the classic RNN-T greedy algorithm:
///
///   For each encoder time step:
///     joint(encoder[t], decoder_state) -> logits
///     while argmax != blank:
///       emit token, run decoder to advance state
///     blank -> advance encoder
///
/// - Vocabulary: 13087 BPE tokens + blank (index 0) = 13088.
/// - Decoder: 2-layer LSTM, hidden 640.
/// - Joint:   linear projections -> add -> tanh -> linear -> 13088 logits.
// @unchecked Sendable: wraps OpaquePointer (OrtSession) from COrt module; access serialized by internal queue
final class RNNTGreedyDecoder: @unchecked Sendable {
    let blankID: Int32 = 0
    let maxSymbolsPerFrame: Int

    private let decoderSession: OpaquePointer
    private let jointSession: OpaquePointer

    /// Decoder LSTM state; each [2, 1, 640] flat (2 layers x 1 batch x 640 hidden).
    private var decoderH: [Float]
    private var decoderC: [Float]

    // MARK: - Init / Reset

    init(decoderSession: OpaquePointer, jointSession: OpaquePointer, maxSymbolsPerFrame: Int = 50) {
        self.decoderSession = decoderSession
        self.jointSession = jointSession
        self.maxSymbolsPerFrame = maxSymbolsPerFrame
        self.decoderH = [Float](repeating: 0, count: 2 * 640)
        self.decoderC = [Float](repeating: 0, count: 2 * 640)
    }

    /// Reset decoder LSTM state to all zeros.
    func reset() {
        decoderH = [Float](repeating: 0, count: 2 * 640)
        decoderC = [Float](repeating: 0, count: 2 * 640)
    }

    // MARK: - Public API

    /// Greedy-decode encoder output to a sequence of BPE token IDs.
    ///
    /// - Parameters:
    ///   - encoderOut: flat `[Float]` of shape `[1, 1024, T]` (channel-last).
    ///   - numFrames: `T` -- number of encoder time steps.
    /// - Returns: array of emitted token IDs (blank excluded).
    func decode(encoderOut: [Float], numFrames: Int) -> [Int32] {
        guard numFrames > 0, encoderOut.count >= 1024 * numFrames else { return [] }

        // Prime the decoder with the blank token (zero state -> initial g)
        var g = runDecoder(target: blankID)
        var hypothesis: [Int32] = []
        var t = 0

        while t < numFrames {
            var symbolsThisFrame = 0

            while symbolsThisFrame < maxSymbolsPerFrame {
                // Slice one encoder frame: [1024] at offset t*1024
                let start = t * 1024
                let encoderSlice = Array(encoderOut[start..<start + 1024])

                let logits = runJoint(encoderOutSlice: encoderSlice, decoderOut: g)
                let token = argmax(logits)

                if token == blankID { break } // blank -> next encoder frame

                hypothesis.append(token)
                g = runDecoder(target: token)
                symbolsThisFrame += 1
            }

            t += 1
        }

        return hypothesis
    }

    // MARK: - Private: decoder (prediction network)

    /// Run the prediction-network ONNX model.
    ///
    /// Feeds `target` token + current LSTM state and returns the decoder
    /// output vector `g` (640-dim).  Updates `decoderH` / `decoderC` in place.
    ///
    /// ONNX signature:
    ///   Inputs:  targets(int32[1,1]), target_length(int64[1]),
    ///            state_h(float32[2,1,640]), state_c(float32[2,1,640])
    ///   Outputs: g(float32[1,640,1]),
    ///            new_state_h(float32[2,1,640]), new_state_c(float32[2,1,640])
    private func runDecoder(target: Int32) -> [Float] {
        // Local mutable copies for C pointer passing
        var currentH = decoderH
        var currentC = decoderC
        var targetVal = target
        var targetLength: Int64 = 1

        let gCount = 640
        var g = [Float](repeating: 0, count: gCount)

        var targetShape: [Int64] = [1, 1]
        var lengthShape: [Int64] = [1]
        var stateShape: [Int64] = [2, 1, 640]

        // Nest unsafe-buffer scopes so all pointers outlive the cort_run_batch call.
        // Swift 6.2 enforces that array-to-pointer conversions in struct literals
        // use explicitly scoped buffer pointers.
        currentH.withUnsafeMutableBufferPointer { hBuf in
            currentC.withUnsafeMutableBufferPointer { cBuf in
                targetShape.withUnsafeMutableBufferPointer { tsBuf in
                    lengthShape.withUnsafeMutableBufferPointer { lsBuf in
                        stateShape.withUnsafeMutableBufferPointer { ssBuf in
                            withCStringPointers(["targets", "target_length", "state_h", "state_c"]) { names in
                                withUnsafeBytes(of: &targetVal) { targetBytes in
                                    withUnsafeBytes(of: &targetLength) { lengthBytes in
                                        var inputs: [COrtInput] = [
                                            COrtInput(
                                                name: names[0],
                                                data_type: COrtDataTypeInt32,
                                                shape: tsBuf.baseAddress, ndim: 2,
                                                data: targetBytes.baseAddress, data_len: 1
                                            ),
                                            COrtInput(
                                                name: names[1],
                                                data_type: COrtDataTypeInt64,
                                                shape: lsBuf.baseAddress, ndim: 1,
                                                data: lengthBytes.baseAddress, data_len: 1
                                            ),
                                            COrtInput(
                                                name: names[2],
                                                data_type: COrtDataTypeFloat,
                                                shape: ssBuf.baseAddress, ndim: 3,
                                                data: hBuf.baseAddress, data_len: Int64(hBuf.count)
                                            ),
                                            COrtInput(
                                                name: names[3],
                                                data_type: COrtDataTypeFloat,
                                                shape: ssBuf.baseAddress, ndim: 3,
                                                data: cBuf.baseAddress, data_len: Int64(cBuf.count)
                                            ),
                                        ]

                                        var outputsPtr: UnsafeMutablePointer<OpaquePointer?>?
                                        var numOutputs: Int64 = 0

                                        let result = cort_run_batch(
                                            decoderSession,
                                            &inputs, Int64(inputs.count),
                                            &outputsPtr, &numOutputs
                                        )

                                        guard result == 0,
                                              let optr = outputsPtr,
                                              numOutputs >= 3
                                        else { return }

                                        // Output[0]: g       (float32 [1, 640, 1])
                                        // Output[1]: new_h   (float32 [2, 1, 640])
                                        // Output[2]: new_c   (float32 [2, 1, 640])
                                        if let hRaw = cort_tensor_data_raw(optr[1]) {
                                            memcpy(hBuf.baseAddress, hRaw, hBuf.count * MemoryLayout<Float>.stride)
                                        }
                                        if let cRaw = cort_tensor_data_raw(optr[2]) {
                                            memcpy(cBuf.baseAddress, cRaw, cBuf.count * MemoryLayout<Float>.stride)
                                        }
                                        if let gData = cort_tensor_data(optr[0]) {
                                            for i in 0..<gCount { g[i] = gData[i] }
                                        }

                                        for i in 0..<Int(numOutputs) {
                                            if let t = optr[i] { cort_tensor_destroy(t) }
                                        }
                                        outputsPtr?.deallocate()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Persist updated state
        decoderH = currentH
        decoderC = currentC
        return g
    }

    // MARK: - Private: joint network

    /// Run the joint-network ONNX model.
    ///
    /// Combines one encoder frame (1024-dim) with the current decoder output
    /// (640-dim) and returns logits over the full vocabulary (13088).
    ///
    /// ONNX signature:
    ///   Inputs:  encoder_out(float32[1,1024,1]), decoder_out(float32[1,640,1])
    ///   Outputs: logits(float32[1,1,1,13088])
    private func runJoint(encoderOutSlice: [Float], decoderOut: [Float]) -> [Float] {
        var enc = encoderOutSlice
        var dec = decoderOut
        var encShape: [Int64] = [1, 1024, 1]
        var decShape: [Int64] = [1, 640, 1]

        var logits = [Float](repeating: 0, count: 13088)

        enc.withUnsafeMutableBufferPointer { encBuf in
            dec.withUnsafeMutableBufferPointer { decBuf in
                encShape.withUnsafeMutableBufferPointer { encShapeBuf in
                    decShape.withUnsafeMutableBufferPointer { decShapeBuf in
                        withCStringPointers(["encoder_out", "decoder_out"]) { names in
                            var inputs: [COrtInput] = [
                                COrtInput(
                                    name: names[0],
                                    data_type: COrtDataTypeFloat,
                                    shape: encShapeBuf.baseAddress, ndim: 3,
                                    data: encBuf.baseAddress, data_len: Int64(encBuf.count)
                                ),
                                COrtInput(
                                    name: names[1],
                                    data_type: COrtDataTypeFloat,
                                    shape: decShapeBuf.baseAddress, ndim: 3,
                                    data: decBuf.baseAddress, data_len: Int64(decBuf.count)
                                ),
                            ]

                            var outputsPtr: UnsafeMutablePointer<OpaquePointer?>?
                            var numOutputs: Int64 = 0

                            let result = cort_run_batch(
                                jointSession,
                                &inputs, Int64(inputs.count),
                                &outputsPtr, &numOutputs
                            )

                            guard result == 0,
                                  let optr = outputsPtr,
                                  numOutputs >= 1
                            else { return }

                            guard let tensor = optr[0] else { return }
                            let count = Int(cort_tensor_size(tensor))
                            logits = [Float](repeating: 0, count: count)
                            if let data = cort_tensor_data(tensor) {
                                for i in 0..<count { logits[i] = data[i] }
                            }

                            cort_tensor_destroy(tensor)
                            outputsPtr?.deallocate()
                        }
                    }
                }
            }
        }

        return logits
    }

    // MARK: - Private: helpers

    /// Index of the maximum value in `array`.
    private func argmax(_ array: [Float]) -> Int32 {
        guard !array.isEmpty else { return blankID }
        var maxIdx: Int32 = 0
        var maxVal = array[0]
        for i in 1..<array.count {
            if array[i] > maxVal {
                maxVal = array[i]
                maxIdx = Int32(i)
            }
        }
        return maxIdx
    }
}
