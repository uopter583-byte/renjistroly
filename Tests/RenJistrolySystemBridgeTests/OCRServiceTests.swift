import Foundation
import AppKit
import XCTest
import RenJistrolyModels
@testable import RenJistrolySystemBridge

func testOCRResultInitialization() {
    let result = OCRResult(
        text: "测试",
        confidence: 0.95,
        x: 0.1, y: 0.2,
        width: 0.3, height: 0.05,
        engine: .appleVision
    )
    XCTAssertTrue(result.text == "测试")
    XCTAssertTrue(result.confidence == 0.95)
    XCTAssertTrue(result.engine == .appleVision)
}

func testOCREngineAllCases() {
    let cases = OCREngine.allCases
    XCTAssertTrue(cases.contains(.appleVision))
    XCTAssertTrue(cases.contains(.ppocrV6))
    XCTAssertTrue(cases.contains(.both))
}

func testAppleVisionOCRServiceEngineProperty() {
    let service = AppleVisionOCRService()
    XCTAssertTrue(service.engine == .appleVision)
}

func testOCRErrorConformsToError() {
    let err = OCRError.imageConversionFailed
    let mirror = Mirror(reflecting: err)
    XCTAssertTrue(mirror.displayStyle == .enum)
}

func testOCRErrorImageConversionFailed() {
    let err: Error = OCRError.imageConversionFailed
    XCTAssertTrue(String(describing: err).contains("imageConversion"))
}

func testOCRServiceSharedInstanceExists() {
    XCTAssertTrue(type(of: OCRService.shared) == OCRService.self)
}

func testOCREngineResolverFallbackWhenUnavailable() {
    let resolver = OCREngineResolver(ppocrAvailable: false)
    XCTAssertTrue(resolver.resolve(preferred: .ppocrV6) == .appleVision)
    XCTAssertTrue(resolver.resolve(preferred: .both) == .appleVision)
    XCTAssertTrue(resolver.resolve(preferred: .appleVision) == .appleVision)
    XCTAssertTrue(resolver.bestAvailable == .appleVision)
}

func testOCREngineResolverWhenAvailable() {
    let resolver = OCREngineResolver(ppocrAvailable: true)
    XCTAssertTrue(resolver.resolve(preferred: .ppocrV6) == .ppocrV6)
    XCTAssertTrue(resolver.resolve(preferred: .both) == .both)
    XCTAssertTrue(resolver.resolve(preferred: .appleVision) == .appleVision)
    XCTAssertTrue(resolver.bestAvailable == .both)
}

func testCTCDecoderEmptyLogits() {
    let decoder = CTCDecoder(chars: ["-", "a", "b"], blankIndex: 0)
    let result = decoder.greedyDecode(logits: [], timeSteps: 0, numClasses: 3)
    XCTAssertTrue(result == "")
}

func testCTCDecoderBlankOnly() {
    let decoder = CTCDecoder(chars: ["-", "a", "b"], blankIndex: 0)
    let logits: [Float] = [
        1.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
    ]
    let result = decoder.greedyDecode(logits: logits, timeSteps: 2, numClasses: 3)
    XCTAssertTrue(result == "")
}

func testCTCDecoderSimpleDecode() {
    let decoder = CTCDecoder(chars: ["-", "a", "b"], blankIndex: 0)
    let logits: [Float] = [
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
    ]
    let result = decoder.greedyDecode(logits: logits, timeSteps: 3, numClasses: 3)
    XCTAssertTrue(result == "ab")
}

func testCTCDecoderRepeatedCharsCollapsed() {
    let decoder = CTCDecoder(chars: ["-", "a", "b"], blankIndex: 0)
    let logits: [Float] = [
        0.0, 1.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 0.0, 1.0,
    ]
    let result = decoder.greedyDecode(logits: logits, timeSteps: 3, numClasses: 3)
    XCTAssertTrue(result == "ab")
}

func testCTCDecoderBlankSeparatesRepeats() {
    let decoder = CTCDecoder(chars: ["-", "a", "b"], blankIndex: 0)
    let logits: [Float] = [
        0.0, 1.0, 0.0,
        1.0, 0.0, 0.0,
        0.0, 1.0, 0.0,
    ]
    let result = decoder.greedyDecode(logits: logits, timeSteps: 3, numClasses: 3)
    XCTAssertTrue(result == "aa")
}

func testCTCDecoderConfidence() {
    let decoder = CTCDecoder(chars: ["-", "a", "b"], blankIndex: 0)
    let logits: [Float] = [
        0.5, 1.0, 0.0,
        0.0, 0.0, 1.0,
    ]
    let conf = decoder.confidence(logits: logits, timeSteps: 2, numClasses: 3)
    XCTAssertTrue(conf == 1.0)
}

func testDBPostProcessorEmptyHeatmap() {
    let processor = DBPostProcessor()
    let results = processor.process(
        heatmap: [], mapWidth: 0, mapHeight: 0,
        imageWidth: 100, imageHeight: 100
    )
    XCTAssertTrue(results.isEmpty)
}

func testDBPostProcessorAllBelowThreshold() {
    let processor = DBPostProcessor(threshold: 0.5)
    let heatmap: [Float] = [0.1, 0.2, 0.3, 0.4]
    let results = processor.process(
        heatmap: heatmap, mapWidth: 2, mapHeight: 2,
        imageWidth: 100, imageHeight: 100
    )
    XCTAssertTrue(results.isEmpty)
}

func testDBPostProcessorSingleBox() {
    let processor = DBPostProcessor(threshold: 0.2, boxThreshold: 0.1, minSize: 1)
    let heatmap: [Float] = [0.9, 0.1, 0.1, 0.9]
    let results = processor.process(
        heatmap: heatmap, mapWidth: 2, mapHeight: 2,
        imageWidth: 100, imageHeight: 100
    )
    XCTAssertFalse(results.isEmpty)
}

func testDetectedTextBoxInitialization() {
    let box = DetectedTextBox(x: 10, y: 20, width: 100, height: 30, confidence: 0.9)
    XCTAssertTrue(box.x == 10)
    XCTAssertTrue(box.y == 20)
    XCTAssertTrue(box.width == 100)
    XCTAssertTrue(box.height == 30)
    XCTAssertTrue(box.confidence == 0.9)
}

// MARK: - Functional OCR Tests

private func makeTestImage(text: String, width: Int = 800, height: Int = 120) -> Data? {
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    guard let ctx = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: bitmapInfo.rawValue
    ) else { return nil }

    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    let attributed = NSAttributedString(
        string: text,
        attributes: [
            .font: NSFont.systemFont(ofSize: 28),
            .foregroundColor: NSColor.black
        ]
    )
    let line = CTLineCreateWithAttributedString(attributed)
    ctx.textPosition = CGPoint(x: 20, y: 50)
    CTLineDraw(line, ctx)

    guard let cgImage = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
}

func testAppleVisionOCRE2E() async throws {
    guard let imageData = makeTestImage(text: "Hello World 你好世界 テスト") else {
        XCTFail("failed to create test image")
        return
    }
    let service = AppleVisionOCRService()
    let results = try await service.recognizeText(in: imageData)
    XCTAssertTrue(!results.isEmpty, "should recognize at least some text")
    let joined = results.map(\.text).joined(separator: " ")
    print("  [Vision E2E] recognized: \(joined)")
}

func testPPOCRv6ServiceE2E() async throws {
    let service = PPOCRv6Service()
    guard service.isAvailable else {
        print("  [PPOCRv6 E2E] skipped: not available")
        return
    }
    guard let imageData = makeTestImage(text: "Hello World 你好测试") else {
        XCTFail("failed to create test image")
        return
    }
    let results = try await service.recognizeText(in: imageData)
    let joined = results.map(\.text).joined(separator: " ")
    print("  [PPOCRv6 E2E] recognized (\(results.count) regions): \(joined.isEmpty ? "(empty)" : joined)")
    if !results.isEmpty {
        XCTAssertFalse(joined.isEmpty)
    }
}

func testOCRServiceUnifiedE2E() async throws {
    guard let imageData = makeTestImage(text: "RenJistroly 文字识别测试 Apple Vision") else {
        XCTFail("failed to create test image")
        return
    }
    let results = try await OCRService.shared.recognize(in: imageData, preferredEngine: .both)
    XCTAssertTrue(!results.isEmpty, "should recognize at least some text")
    let joined = results.map { "[\($0.engine == .appleVision ? "V" : "P")]\($0.text)" }.joined(separator: " ")
    print("  [Unified E2E] recognized (\(results.count) regions): \(joined)")
}

func testOCREngineResolverE2E() {
    let ppocrAvailable = PPOCRv6Service().isAvailable
    print("  [Resolver] PPOCRv6 available: \(ppocrAvailable)")
    let resolver = OCREngineResolver(ppocrAvailable: ppocrAvailable)
    let best = resolver.bestAvailable
    XCTAssertTrue(best == (ppocrAvailable ? .both : .appleVision))
    XCTAssertTrue(resolver.resolve(preferred: .ppocrV6) == (ppocrAvailable ? .ppocrV6 : .appleVision))
    print("  [Resolver] best=\(best)")
}
