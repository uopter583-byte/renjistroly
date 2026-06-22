import Foundation
import CoreGraphics
import COrt
import os
import RenJistrolyModels

// NOTE: deliberately not @MainActor — this class performs CPU-bound ONNX
// inference and manages its own thread safety via OSAllocatedUnfairLock
// and DispatchQueue. No UIKit/AppKit UI is involved.

// OpaquePointer is not Sendable, so we wrap it for capture in @Sendable closures.
private struct UnmanagedSession: @unchecked Sendable {
    let ptr: OpaquePointer?
}

/// Thread-safe lazy storage for ONNX sessions. OpaquePointer is non-Sendable,
/// so we back it with nonisolated(unsafe) vars guarded by OSAllocatedUnfairLock.
private enum SessionStore {
    private static let initLock = OSAllocatedUnfairLock()
    nonisolated(unsafe) private static var _detSession: OpaquePointer?
    nonisolated(unsafe) private static var _recSession: OpaquePointer?
    nonisolated(unsafe) private static var _ctcDecoder: CTCDecoder?
    nonisolated(unsafe) private static var _ready = false

    static var detSession: OpaquePointer? { load(); return _detSession }
    static var recSession: OpaquePointer? { load(); return _recSession }
    static var ctcDecoder: CTCDecoder? { load(); return _ctcDecoder }

    private static func load() {
        initLock.withLock {
            guard !_ready else { return }

            if let detURL = Bundle.module.url(forResource: "PPOCRv6_det", withExtension: "onnx"),
               let detData = try? Data(contentsOf: detURL) {
                _detSession = detData.withUnsafeBytes { ptr in
                    cort_session_create(ptr.baseAddress?.assumingMemoryBound(to: UInt8.self), detData.count)
                }
            }

            if let recURL = Bundle.module.url(forResource: "PPOCRv6_rec", withExtension: "onnx"),
               let recData = try? Data(contentsOf: recURL) {
                _recSession = recData.withUnsafeBytes { ptr in
                    cort_session_create(ptr.baseAddress?.assumingMemoryBound(to: UInt8.self), recData.count)
                }
            }

            _ctcDecoder = CTCDecoder.loadFromBundle()
            _ready = true
        }
    }
}

public final class PPOCRv6Service: OCRServiceProtocol {
    public let engine: OCREngine = .ppocrV6

    private let dbProcessor: DBPostProcessor
    private let ctcDecoder: CTCDecoder?
    private let requestQueue = DispatchQueue(label: "com.renjistroly.ocr.ppocr")

    private static let detInputSize = (width: 640, height: 640)
    private static let recInputSize = (width: 320, height: 48)

    public init(dbProcessor: DBPostProcessor = DBPostProcessor()) {
        self.dbProcessor = dbProcessor
        self.ctcDecoder = SessionStore.ctcDecoder
    }

    public var isAvailable: Bool {
        SessionStore.detSession != nil && SessionStore.recSession != nil && SessionStore.ctcDecoder != nil
    }

    public func recognizeText(in imageData: Data) async throws -> [OCRResult] {
        guard isAvailable else {
            throw OCRError.recognitionFailed(
                NSError(domain: "PPOCRv6", code: -1, userInfo: [NSLocalizedDescriptionKey: "模型未加载或字符表缺失"])
            )
        }

        guard let image = CGImage.from(data: imageData) else {
            throw OCRError.imageConversionFailed
        }

        let imageWidth = image.width
        let imageHeight = image.height

        let detBoxes = try await runDetection(image: image, imageWidth: imageWidth, imageHeight: imageHeight)
        guard !detBoxes.isEmpty else { return [] }

        var results: [OCRResult] = []
        for box in detBoxes {
            guard let crop = image.cropping(
                to: CGRect(x: Int(box.x), y: Int(box.y), width: Int(box.width), height: Int(box.height))
            ) else { continue }

            guard let (text, conf) = try? await runRecognition(cropImage: crop) else { continue }
            if text.isEmpty { continue }

            results.append(OCRResult(
                text: text,
                confidence: Float(conf),
                x: box.x / Double(imageWidth),
                y: box.y / Double(imageHeight),
                width: box.width / Double(imageWidth),
                height: box.height / Double(imageHeight),
                engine: .ppocrV6
            ))
        }

        return results
    }

    // MARK: - Detection

    private func runDetection(image: CGImage, imageWidth: Int, imageHeight: Int) async throws -> [DetectedTextBox] {
        guard let session = SessionStore.detSession else { return [] }

        let us = UnmanagedSession(ptr: session)
        return try await withCheckedThrowingContinuation { cont in
            requestQueue.async {
                let (input, padH, padW, _, _) = OrtImageHelper.preprocessDet(image, maxSide: 960)

                let shape: [Int64] = [1, 3, Int64(padH), Int64(padW)]
                let inputName = cort_input_name(us.ptr, 0)

                var output: OpaquePointer? = nil
                let rc = cort_run(us.ptr, inputName, shape, 4, input, Int64(input.count), &output)

                guard rc == 0, let out = output else {
                    cont.resume(returning: [])
                    return
                }
                defer { cort_tensor_destroy(out) }

                let data = cort_tensor_data(out)
                let count = Int(cort_tensor_size(out))
                let heatmap = Array(UnsafeBufferPointer(start: data, count: count))

                var ndim: Int64 = 0
                guard let outShape = cort_tensor_shape(out, &ndim), ndim >= 2 else {
                    cont.resume(returning: [])
                    return
                }
                let n = Int(ndim)
                let mapH = Int(outShape[n - 2])
                let mapW = Int(outShape[n - 1])

                let boxes = self.dbProcessor.process(
                    heatmap: heatmap,
                    mapWidth: mapW,
                    mapHeight: mapH,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight
                )
                cont.resume(returning: boxes)
            }
        }
    }

    // MARK: - Recognition

    private func runRecognition(cropImage: CGImage) async throws -> (text: String, confidence: Float) {
        guard let session = SessionStore.recSession, let decoder = self.ctcDecoder ?? SessionStore.ctcDecoder else {
            return ("", 0)
        }

        let us = UnmanagedSession(ptr: session)
        return try await withCheckedThrowingContinuation { cont in
            requestQueue.async {
                let w = Self.recInputSize.width
                let h = Self.recInputSize.height
                let input = OrtImageHelper.preprocessRec(cropImage, width: w, height: h)

                let shape: [Int64] = [1, 3, Int64(h), Int64(w)]
                let inputName = cort_input_name(us.ptr, 0)

                var output: OpaquePointer? = nil
                let rc = cort_run(us.ptr, inputName, shape, 4, input, Int64(input.count), &output)

                guard rc == 0, let out = output else {
                    cont.resume(returning: ("", 0))
                    return
                }
                defer { cort_tensor_destroy(out) }

                let data = cort_tensor_data(out)
                let count = Int(cort_tensor_size(out))
                let logits = Array(UnsafeBufferPointer(start: data, count: count))

                var ndim: Int64 = 0
                guard let outShape = cort_tensor_shape(out, &ndim), ndim >= 2 else {
                    cont.resume(returning: ("", 0))
                    return
                }
                let n = Int(ndim)
                let timeSteps = Int(outShape[n - 2])
                let numClasses = Int(outShape[n - 1])

                let text = decoder.greedyDecode(logits: logits, timeSteps: timeSteps, numClasses: numClasses)
                let conf = decoder.confidence(logits: logits, timeSteps: timeSteps, numClasses: numClasses)
                cont.resume(returning: (text, conf))
            }
        }
    }
}
