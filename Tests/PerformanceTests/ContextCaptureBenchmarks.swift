@testable import RenJistrolySystemBridge
@testable import RenJistrolyModels
import XCTest

// MARK: - Context Capture Performance Benchmarks

@MainActor
final class ContextCaptureBenchmarks: PerformanceTestBase, @unchecked Sendable {

    private lazy var contextProvider = ScreenContextProvider()
    private lazy var accessibilityProvider = AccessibilityContextProvider()
    private lazy var accessibilityBridge = AccessibilityBridge()
    private lazy var ocrService = OCRService.shared
    private lazy var ocrResolver = OCREngineResolver()

    // MARK: - Thresholds

    override func thresholds() -> [String: BenchmarkThreshold] {
        [
            // AX UI tree — these are highly environment-dependent; we set
            // generous ceilings that flag serious regressions.
            "axTreeDepth3": .max(0.5),      // < 500 ms
            "axTreeDepth5": .max(2.0),      // < 2 s
            "axTreeDepth8": .max(8.0),      // < 8 s (deep tree is expensive)

            // OCR
            "ocrVision": .max(3.0),         // < 3 s
            "ocrPPOCR": .max(5.0),          // < 5 s (ONNX model load)
            "ocrBoth": .max(6.0),           // < 6 s (both engines)

            // Screenshot
            "screenCapture": .max(2.0),     // < 2 s

            // End-to-end full context
            "fullContextNoImage": .max(1.0),
            "fullContextWithImage": .max(6.0),
        ]
    }

    // MARK: - AX UI Tree

    func testAXTreeDepth3() async throws {
        let bridge = accessibilityBridge
        _ = await measureBlockAsync(name: "axTreeDepth3") { [bridge] in
            _ = try? await bridge.getAppState(maxDepth: 3, includeScreenshot: false)
        }
        assertBenchPassed("axTreeDepth3")
    }

    func testAXTreeDepth5() async throws {
        let bridge = accessibilityBridge
        _ = await measureBlockAsync(name: "axTreeDepth5") { [bridge] in
            _ = try? await bridge.getAppState(maxDepth: 5, includeScreenshot: false)
        }
        assertBenchPassed("axTreeDepth5")
    }

    func testAXTreeDepth8() async throws {
        let bridge = accessibilityBridge
        _ = await measureBlockAsync(name: "axTreeDepth8") { [bridge] in
            _ = try? await bridge.getAppState(maxDepth: 8, includeScreenshot: false)
        }
        assertBenchPassed("axTreeDepth8")
    }

    // MARK: - OCR

    func testOCRVision() async throws {
        let provider = contextProvider
        _ = await measureBlockAsync(name: "ocrVision") { [provider] in
            _ = await provider.captureCurrentScreen(includeImageData: true)
        }
        assertBenchPassed("ocrVision")
    }

    func testOCRPpocr() async throws {
        guard ocrResolver.ppocrAvailable else {
            throw XCTSkip("PP-OCRv6 not available")
        }
        let screen = await contextProvider.captureCurrentScreen(includeImageData: true)
        guard let imageData = screen.imageData else {
            throw XCTSkip("No screen image data available")
        }
        let service = ocrService
        _ = await measureBlockAsync(name: "ocrPPOCR") { [service, imageData] in
            _ = try? await service.recognize(in: imageData, preferredEngine: .ppocrV6)
        }
        assertBenchPassed("ocrPPOCR")
    }

    func testOCREngineBoth() async throws {
        guard ocrResolver.ppocrAvailable else {
            throw XCTSkip("PP-OCRv6 not available")
        }
        let screen = await contextProvider.captureCurrentScreen(includeImageData: true)
        guard let imageData = screen.imageData else {
            throw XCTSkip("No screen image data available")
        }
        let service = ocrService
        _ = await measureBlockAsync(name: "ocrBoth") { [service, imageData] in
            _ = try? await service.recognize(in: imageData, preferredEngine: .both)
        }
        assertBenchPassed("ocrBoth")
    }

    // MARK: - Screen capture

    func testScreenCaptureLatency() async throws {
        let bridge = ScreenCaptureBridge()
        _ = await measureBlockAsync(name: "screenCapture") { [bridge] in
            _ = try? await bridge.captureScreen()
        }
        assertBenchPassed("screenCapture")
    }

    // MARK: - End-to-end context

    func testFullContextNoImage() async throws {
        let provider = contextProvider
        _ = await measureBlockAsync(name: "fullContextNoImage") { [provider] in
            _ = await provider.captureCurrentScreen(includeImageData: false)
        }
        assertBenchPassed("fullContextNoImage")
    }

    func testFullContextWithImage() async throws {
        let provider = contextProvider
        _ = await measureBlockAsync(name: "fullContextWithImage") { [provider] in
            _ = await provider.captureCurrentScreen(includeImageData: true)
        }
        assertBenchPassed("fullContextWithImage")
    }

    // MARK: - Accessibility context helpers

    func testReadFrontmostApp() async throws {
        let provider = accessibilityProvider
        _ = await measureBlockAsync(name: "readFrontmostApp") { [provider] in
            _ = await provider.readFrontmostApp()
        }
    }

    func testReadRunningApps() async throws {
        let provider = accessibilityProvider
        _ = await measureBlockAsync(name: "readRunningApps") { [provider] in
            _ = await provider.readRunningApps()
        }
    }

    func testReadFocusedElement() async throws {
        let provider = accessibilityProvider
        _ = await measureBlockAsync(name: "readFocusedElement") { [provider] in
            _ = await provider.readFocusedElement()
        }
    }
}
