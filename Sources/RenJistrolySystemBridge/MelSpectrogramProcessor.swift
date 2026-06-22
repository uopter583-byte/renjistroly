@preconcurrency import Accelerate

/// Log-mel spectrogram processor matching NeMo's audio_preprocessor output.
///
/// Converts raw PCM float32 audio (16 kHz mono) into log-mel spectrogram features
/// suitable for the Nemotron 3.5 ASR model.
///
/// Output shape: (batch=1, mel=128, time=nFrames) stored as a flat `[Float]` array.
public struct MelSpectrogramProcessor: @unchecked Sendable {

    // MARK: - Configuration

    public let sampleRate: Float
    public let windowLength: Int       // 400 @ 16 kHz
    public let hopLength: Int          // 160 @ 16 kHz
    public let nFft: Int               // 512
    public let nMel: Int               // 128
    public let fMin: Float             // 0
    public let fMax: Float             // sampleRate / 2 = 8000
    public let dither: Float           // 1e-5

    private let numBins: Int           // nFft / 2 + 1 = 257

    // Pre-computed, immutable after init
    private let hannWindow: [Float]
    private let melFilterbank: [Float] // nMel * numBins

    // FFT setup – the class reference is immutable after init
    private let fft: vDSP.FFT<DSPSplitComplex>

    // MARK: - Init

    public init(
        sampleRate: Float = 16000,
        windowSize: Float = 0.025,
        windowStride: Float = 0.01,
        nFft: Int = 512,
        nMel: Int = 128,
        fMin: Float = 0,
        dither: Float = 1e-5
    ) {
        precondition(nFft.nonzeroBitCount == 1, "nFft must be a power of two")

        self.sampleRate = sampleRate
        self.windowLength = Int(sampleRate * windowSize)
        self.hopLength = Int(sampleRate * windowStride)
        self.nFft = nFft
        self.nMel = nMel
        self.fMin = fMin
        self.fMax = sampleRate / 2
        self.dither = dither
        self.numBins = nFft / 2 + 1

        // Hann window (vDSP.WindowSequence doesn't include Hann in this SDK)
        self.hannWindow = Self.computeHannWindow(length: windowLength)

        // Mel filterbank
        self.melFilterbank = Self.computeMelFilterbank(
            nMel: nMel,
            nFft: nFft,
            numBins: numBins,
            sampleRate: sampleRate,
            fMin: fMin,
            fMax: sampleRate / 2
        )

        // FFT (log2n = 9 for nFft = 512)
        self.fft = vDSP.FFT(
            log2n: UInt(log2f(Float(nFft))),
            radix: .radix2,
            ofType: DSPSplitComplex.self
        )!
    }

    // MARK: - Public API

    /// Process raw PCM float32 audio to mel spectrogram features.
    ///
    /// - Parameter audio: float32 samples (mono, 16 kHz).
    /// - Returns: `(features, numFrames)` where `features` is a flat `[Float]` of
    ///            shape `(1, nMel, numFrames)` — batch × mel × time.
    public func process(audio: [Float]) -> (features: [Float], numFrames: Int) {
        guard !audio.isEmpty else {
            return (features: [], numFrames: 0)
        }

        // ---- 1. Dither ----
        var signal = audio
        if dither > 0 {
            applyDither(&signal)
        }

        // ---- 2. Reflection pad both sides (nFft/2 each) ----
        let padLength = nFft / 2 // 256
        let paddedLength = signal.count + 2 * padLength
        var padded = [Float](repeating: 0, count: paddedLength)

        // Left reflection: first padLength samples of signal, reversed
        for i in 0 ..< padLength {
            padded[i] = signal[padLength - 1 - i]
        }
        // Original signal
        for i in 0 ..< signal.count {
            padded[padLength + i] = signal[i]
        }
        // Right reflection: last padLength samples of signal, reversed
        let srcEnd = signal.count - 1
        for i in 0 ..< padLength {
            padded[padLength + signal.count + i] = signal[srcEnd - i]
        }

        // ---- 3. Compute number of frames ----
        let nFrames = max(0, (padded.count - windowLength) / hopLength + 1)
        guard nFrames > 0 else {
            return (features: [], numFrames: 0)
        }

        // ---- 4. Allocate output buffers ----
        var features = [Float](repeating: 0, count: nMel * nFrames)

        // Per-frame working buffers
        var windowed = [Float](repeating: 0, count: nFft)
        var realp = [Float](repeating: 0, count: nFft / 2)
        var imagp = [Float](repeating: 0, count: nFft / 2)
        var powerSpec = [Float](repeating: 0, count: numBins)

        for frameIdx in 0 ..< nFrames {
            let start = frameIdx * hopLength

            // ---- 4a. Extract frame, apply Hann window, zero-pad to nFft ----
            for i in 0 ..< windowLength {
                windowed[i] = padded[start + i] * hannWindow[i]
            }
            for i in windowLength ..< nFft {
                windowed[i] = 0
            }

            // ---- 4b. Pack for real FFT (even → realp, odd → imagp) ----
            for k in 0 ..< nFft / 2 {
                realp[k] = windowed[2 * k]
                imagp[k] = windowed[2 * k + 1]
            }

            // ---- 4c. Forward real FFT (in-place) ----
            realp.withUnsafeMutableBufferPointer { realpBP in
                imagp.withUnsafeMutableBufferPointer { imagpBP in
                    var split = DSPSplitComplex(realp: realpBP.baseAddress!, imagp: imagpBP.baseAddress!)
                    fft.forward(input: split, output: &split)
                }
            }
            // realp and imagp are now modified in-place

            // ---- 4d. Power spectrum |X[k]|² ----
            // After real FFT:
            //   realp[0] = DC component, imagp[0] = Nyquist component
            //   realp[k] = Re(X[k]), imagp[k] = Im(X[k]) for 1 ≤ k < nFft/2
            powerSpec[0] = realp[0] * realp[0]
            for k in 1 ..< nFft / 2 {
                powerSpec[k] = realp[k] * realp[k] + imagp[k] * imagp[k]
            }
            powerSpec[nFft / 2] = imagp[0] * imagp[0]

            // ---- 4e. Apply mel filterbank & log ----
            let outBase = frameIdx * nMel
            for m in 0 ..< nMel {
                let fbBase = m * numBins
                var sum: Float = 0
                for b in 0 ..< numBins {
                    sum += powerSpec[b] * melFilterbank[fbBase + b]
                }
                // Clip floor before log (natural log)
                features[outBase + m] = logf(max(sum, 1e-10))
            }
        }

        // Output flat array: batch=1 dimension is implicit;
        // shape is (1, nMel, nFrames) = [mel][time] in row-major order.
        return (features: features, numFrames: nFrames)
    }

    // MARK: - Private Helpers

    /// Add Gaussian noise with stddev = `dither` using Box-Muller.
    private func applyDither(_ signal: inout [Float]) {
        var i = 0
        while i < signal.count {
            let u1 = Float.random(in: 0 ... 1)
            let u2 = Float.random(in: 0 ... 1)
            let radius = (-2 * logf(u1 + .leastNonzeroMagnitude)).squareRoot()
            let theta = 2 * Float.pi * u2
            signal[i] += dither * radius * cosf(theta)
            i += 1
            if i < signal.count {
                signal[i] += dither * radius * sinf(theta)
                i += 1
            }
        }
    }

    /// Generate a Hann window of the given length.
    /// w[i] = 0.5 * (1 - cos(2*pi*i / (length-1)))
    private static func computeHannWindow(length: Int) -> [Float] {
        guard length > 1 else { return [Float](repeating: 1, count: length) }
        var window = [Float](repeating: 0, count: length)
        let factor = 2 * Float.pi / Float(length - 1)
        for i in 0 ..< length {
            window[i] = 0.5 * (1 - cosf(factor * Float(i)))
        }
        return window
    }

    // MARK: - Mel Filterbank Construction

    private static func computeMelFilterbank(
        nMel: Int,
        nFft: Int,
        numBins: Int,
        sampleRate: Float,
        fMin: Float,
        fMax: Float
    ) -> [Float] {
        let melMin = hzToMel(fMin)   // 0
        let melMax = hzToMel(fMax)   // ≈ 2840

        // nMel + 2 equally spaced points in mel scale
        var melPoints = [Float](repeating: 0, count: nMel + 2)
        let melStep = (melMax - melMin) / Float(nMel + 1)
        for i in 0 ..< nMel + 2 {
            melPoints[i] = melMin + Float(i) * melStep
        }

        // Convert mel points to Hz, then to FFT bin indices (fractional)
        var binPoints = [Float](repeating: 0, count: nMel + 2)
        for i in 0 ..< nMel + 2 {
            let hz = melToHz(melPoints[i])
            binPoints[i] = hz * Float(nFft) / sampleRate
        }

        // Build triangular filters
        var filterbank = [Float](repeating: 0, count: nMel * numBins)

        for m in 0 ..< nMel {
            let left   = binPoints[m]
            let center = binPoints[m + 1]
            let right  = binPoints[m + 2]

            let startBin = max(0, Int(left.rounded(.up)))
            let endBin   = min(numBins - 1, Int(right.rounded(.down)))

            let fbBase = m * numBins

            if endBin >= startBin {
                for b in startBin ... endBin {
                    let fb = Float(b)
                    let weight: Float
                    if fb <= center {
                        weight = (fb - left) / (center - left)
                    } else {
                        weight = (right - fb) / (right - center)
                    }
                    filterbank[fbBase + b] = max(0, weight)
                }
            }

            // Normalise so that sum of weights = 1 (area-normalised)
            var sum: Float = 0
            for b in 0 ..< numBins {
                sum += filterbank[fbBase + b]
            }
            if sum > 0 {
                for b in 0 ..< numBins {
                    filterbank[fbBase + b] /= sum
                }
            }
        }

        return filterbank
    }

    // MARK: - Mel Scale Conversion

    @inline(__always)
    private static func hzToMel(_ hz: Float) -> Float {
        2595 * log10f(1 + hz / 700)
    }

    @inline(__always)
    private static func melToHz(_ mel: Float) -> Float {
        700 * (powf(10, mel / 2595) - 1)
    }
}
