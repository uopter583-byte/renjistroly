import Foundation
import Vision
import AppKit
import RenJistrolyModels

public protocol OCRServiceProtocol: Sendable {
    var engine: OCREngine { get }
    func recognizeText(in imageData: Data) async throws -> [OCRResult]
}

// MARK: - Apple Vision OCR

public final class AppleVisionOCRService: OCRServiceProtocol {
    public let engine: OCREngine = .appleVision

    private let requestQueue = DispatchQueue(label: "com.renjistroly.ocr.vision")
    private let recognitionLevel: VNRequestTextRecognitionLevel
    private let usesLanguageCorrection: Bool
    private let recognitionLanguages: [String]

    public init(
        recognitionLevel: VNRequestTextRecognitionLevel = .accurate,
        usesLanguageCorrection: Bool = true,
        recognitionLanguages: [String] = ["zh-Hans", "zh-Hant", "en-US", "ja-JP"]
    ) {
        self.recognitionLevel = recognitionLevel
        self.usesLanguageCorrection = usesLanguageCorrection
        self.recognitionLanguages = recognitionLanguages
    }

    public func recognizeText(in imageData: Data) async throws -> [OCRResult] {
        guard let image = CGImage.from(data: imageData) else {
            throw OCRError.imageConversionFailed
        }

        let enhanced = Self.enhanceContrast(image) ?? image

        return try await withCheckedThrowingContinuation { cont in
            requestQueue.async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        cont.resume(throwing: OCRError.recognitionFailed(error))
                        return
                    }
                    let results = (request.results as? [VNRecognizedTextObservation] ?? [])
                        .compactMap { obs -> OCRResult? in
                            guard let top = obs.topCandidates(1).first else { return nil }
                            let r = obs.boundingBox
                            return OCRResult(
                                text: top.string,
                                confidence: top.confidence,
                                x: Double(r.origin.x),
                                y: Double(r.origin.y),
                                width: Double(r.size.width),
                                height: Double(r.size.height),
                                engine: .appleVision
                            )
                        }
                    cont.resume(returning: results)
                }

                request.recognitionLevel = self.recognitionLevel
                request.usesLanguageCorrection = self.usesLanguageCorrection
                request.recognitionLanguages = self.recognitionLanguages
                request.minimumTextHeight = 0.005

                let handler = VNImageRequestHandler(cgImage: enhanced, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(throwing: OCRError.recognitionFailed(error))
                }
            }
        }
    }

    private static let ciContext = CIContext(options: [.workingColorSpace: NSNull()])

    private static func enhanceContrast(_ image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        guard let contrast = CIFilter(name: "CIColorControls") else { return nil }
        contrast.setValue(ciImage, forKey: kCIInputImageKey)
        contrast.setValue(3.0, forKey: kCIInputContrastKey)
        contrast.setValue(0.05, forKey: kCIInputBrightnessKey)
        contrast.setValue(0.0, forKey: kCIInputSaturationKey)
        guard let output = contrast.outputImage else { return nil }
        return Self.ciContext.createCGImage(output, from: output.extent)
    }
}

// MARK: - Unified OCR Service

public final class OCRService: @unchecked Sendable {
    public static let shared = OCRService()

    private let visionOCR = AppleVisionOCRService()
    private let ppocrV6: (any OCRServiceProtocol)?

    private init() {
        let service = PPOCRv6Service()
        ppocrV6 = service.isAvailable ? service : nil
    }

    public func recognize(in imageData: Data, preferredEngine: OCREngine = .appleVision) async throws -> [OCRResult] {
        switch preferredEngine {
        case .appleVision:
            return try await visionOCR.recognizeText(in: imageData)

        case .ppocrV6:
            if let ppocr = ppocrV6 {
                return try await ppocr.recognizeText(in: imageData)
            }
            return try await visionOCR.recognizeText(in: imageData)

        case .both:
            let vision = visionOCR
            let ppocr = ppocrV6
            async let visionResults = vision.recognizeText(in: imageData)
            async let ppocrResults: [OCRResult] = ppocr?.recognizeText(in: imageData) ?? []

            let v = (try? await visionResults) ?? []
            let p = (try? await ppocrResults) ?? []
            return OCRService.mergeResults(v, p)
        }
    }

    private static func mergeResults(_ a: [OCRResult], _ b: [OCRResult]) -> [OCRResult] {
        var merged = a
        for result in b {
            let overlaps = merged.contains { r in
                let ix = max(r.x, result.x)
                let iy = max(r.y, result.y)
                let iw = min(r.x + r.width, result.x + result.width) - ix
                let ih = min(r.y + r.height, result.y + result.height) - iy
                return iw > 0 && ih > 0 && (iw * ih) / (result.width * result.height) > 0.5
            }
            if !overlaps {
                merged.append(result)
            }
        }
        return merged.sorted { ($0.y, $0.x) < ($1.y, $1.x) }
    }
}

// MARK: - Error

public enum OCRError: Error, LocalizedError, Sendable {
    case imageConversionFailed
    case recognitionFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .imageConversionFailed: "屏幕截图转换失败。"
        case .recognitionFailed(let err): "文字识别失败：\(err.localizedDescription)"
        }
    }
}

// MARK: - CGImage Helpers

extension CGImage {
    static func from(data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
