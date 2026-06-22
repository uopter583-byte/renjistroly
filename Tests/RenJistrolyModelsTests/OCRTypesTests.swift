import Foundation
import XCTest
import RenJistrolyModels

// MARK: - OCREngine

func testOCREngineDisplayNames() {
    XCTAssertTrue(OCREngine.appleVision.displayName == "Apple Vision")
    XCTAssertTrue(OCREngine.ppocrV6.displayName == "PP-OCRv6 (ONNX)")
    XCTAssertTrue(OCREngine.both.displayName == "双引擎合并")
}

func testOCREngineAllCases() {
    XCTAssertTrue(OCREngine.allCases.count == 3)
    XCTAssertTrue(OCREngine.allCases.contains(.appleVision))
    XCTAssertTrue(OCREngine.allCases.contains(.ppocrV6))
    XCTAssertTrue(OCREngine.allCases.contains(.both))
}

// MARK: - OCRResult

func testOCRResultInit() {
    let result = OCRResult(
        text: "hello",
        confidence: 0.95,
        x: 10, y: 20,
        width: 100, height: 30,
        engine: .appleVision
    )
    XCTAssertTrue(result.text == "hello")
    XCTAssertTrue(result.confidence == 0.95)
    XCTAssertTrue(result.x == 10)
    XCTAssertTrue(result.y == 20)
    XCTAssertTrue(result.width == 100)
    XCTAssertTrue(result.height == 30)
    XCTAssertTrue(result.engine == .appleVision)
}

func testOCRResultHashable() {
    let a = OCRResult(text: "a", confidence: 0.5, x: 0, y: 0, width: 1, height: 1, engine: .ppocrV6)
    let b = OCRResult(text: "a", confidence: 0.5, x: 0, y: 0, width: 1, height: 1, engine: .ppocrV6)
    let c = OCRResult(text: "b", confidence: 0.5, x: 0, y: 0, width: 1, height: 1, engine: .ppocrV6)
    XCTAssertTrue(a == b)
    XCTAssertTrue(a != c)
}
