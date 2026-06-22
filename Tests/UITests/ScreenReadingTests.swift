import Foundation
import XCTest
@testable import RenJistrolyModels
@testable import RenJistrolySystemBridge

// MARK: - ScreenReadingTests

/// 屏幕读取测试。
/// 测试屏幕捕获、OCR 文字识别、窗口信息获取等场景。
final class ScreenReadingTests: XCTestCase {

    // MARK: - 屏幕上下文

    func testScreenContextEmptyDesktop() {
        let ctx = MockScreenScenario.emptyDesktop()
        XCTAssertFalse(ctx.displayDescription.isEmpty)
        XCTAssertFalse(ctx.visibleWindows.isEmpty)
        XCTAssertNil(ctx.recognizedText, "空桌面场景不应有 OCR 文字")
        XCTAssertNil(ctx.imageData)
    }

    func testScreenContextWithOCR() {
        let ctx = MockScreenScenario.chineseOCR()
        XCTAssertNotNil(ctx.recognizedText)
        XCTAssertTrue(ctx.recognizedText!.contains("你好"), "应包含中文 OCR 结果")
        XCTAssertTrue(ctx.recognizedText!.contains("RenJistroly"))
    }

    func testScreenContextMultiWindow() {
        let ctx = MockScreenScenario.multiWindow()
        XCTAssertEqual(ctx.visibleWindows.count, 3, "多窗口场景应有 3 个窗口")
        let apps = ctx.visibleWindows.map(\.ownerName)
        XCTAssertTrue(apps.contains("Xcode"))
        XCTAssertTrue(apps.contains("Safari"))
        XCTAssertTrue(apps.contains("终端"))
    }

    func testScreenContextDialog() {
        let ctx = MockScreenScenario.dialogPresented()
        let dialogWindows = ctx.visibleWindows.filter { $0.layer > 0 }
        XCTAssertGreaterThan(dialogWindows.count, 0, "对话框应该在更高层")
    }

    // MARK: - MockScreenCaptureBridge

    func testMockScreenCaptureSuccess() async throws {
        let mockData = "fake-image-data".data(using: .utf8)!
        let bridge = MockScreenCaptureBridge(
            shouldSucceed: true,
            mockImageData: mockData,
            mockWindows: [
                WindowInfo(id: 1, title: "测试窗口", bundleID: "com.test", appName: "TestApp", frame: .zero, isOnScreen: true)
            ]
        )

        let data = try await bridge.captureScreen()
        XCTAssertEqual(data, mockData, "应返回模拟的图片数据")

        let windows = try await bridge.getAvailableWindows()
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows.first?.title, "测试窗口")
    }

    func testMockScreenCaptureFailure() async {
        let bridge = MockScreenCaptureBridge(shouldSucceed: false)
        do {
            _ = try await bridge.captureScreen()
            XCTFail("捕获失败时应该抛出错误")
        } catch {
            XCTAssertTrue(error is ScreenCaptureError)
        }
    }

    func testMockScreenCaptureCallCount() async throws {
        let bridge = MockScreenCaptureBridge(shouldSucceed: true)
        _ = try await bridge.captureScreen()
        _ = try await bridge.captureScreen()
        _ = try await bridge.captureScreen()

        let count = await bridge.captureCallCount
        XCTAssertEqual(count, 3, "每次调用都应该递增计数")
    }

    // MARK: - MockOCRService

    func testOCRServiceWithResults() async throws {
        let results = MockScreenScenario.sampleOCRResults()
        let service = MockOCRService(mockResults: results)

        let recognized = try await service.recognizeText(in: Data())
        XCTAssertEqual(recognized.count, 3)
        XCTAssertEqual(recognized[0].text, "你好")
        XCTAssertEqual(recognized[2].text, "OK")
    }

    func testOCRServiceHighConfidence() async throws {
        let results = MockScreenScenario.sampleOCRResults()
        let service = MockOCRService(mockResults: results)

        let recognized = try await service.recognizeText(in: Data())
        for result in recognized {
            XCTAssertGreaterThanOrEqual(result.confidence, 0.9, "模拟场景的置信度应 >= 0.9")
        }
    }

    func testOCRServiceFailure() async {
        let service = MockOCRService(mockResults: [])
        service.shouldThrow = true

        do {
            _ = try await service.recognizeText(in: Data())
            XCTFail("应抛出错误")
        } catch {
            XCTAssertTrue(error is OCRError)
        }
    }

    func testOCRServiceBoundingBoxes() async throws {
        let results = MockScreenScenario.sampleOCRResults()
        let service = MockOCRService(mockResults: results)

        let recognized = try await service.recognizeText(in: Data())
        for result in recognized {
            XCTAssertGreaterThan(result.width, 0, "宽度应大于 0")
            XCTAssertGreaterThan(result.height, 0, "高度应大于 0")
        }
    }

    // MARK: - OCR 引擎切换

    func testOCREngineEnum() {
        XCTAssertEqual(OCREngine.appleVision.displayName, "Apple Vision")
        XCTAssertEqual(OCREngine.ppocrV6.displayName, "PP-OCRv6 (ONNX)")
        XCTAssertEqual(OCREngine.both.displayName, "双引擎合并")

        let allCases = OCREngine.allCases
        XCTAssertEqual(allCases.count, 3)
    }

    func testAppleVisionOCRServiceConfiguration() {
        let service = AppleVisionOCRService(recognitionLevel: .fast, usesLanguageCorrection: false)
        XCTAssertEqual(service.engine, .appleVision)
    }

    // MARK: - MockScreenContextProvider

    func testScreenContextProviderBasic() async {
        let scenario = MockScreenScenario.chineseOCR()
        let provider = MockScreenContextProvider(mockContext: scenario)

        let result = await provider.captureCurrentScreen()
        XCTAssertNotNil(result.recognizedText)
        XCTAssertTrue(result.recognizedText!.contains("你好"))
    }

    func testScreenContextProviderCountsCaptures() async {
        let provider = MockScreenContextProvider(mockContext: MockScreenScenario.emptyDesktop())

        _ = await provider.captureCurrentScreen()
        _ = await provider.captureCurrentScreen()

        let count = await provider.captureCount
        XCTAssertEqual(count, 2)
    }

    // MARK: - WindowInfo 结构

    func testWindowInfoCreation() {
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let info = WindowInfo(id: 42, title: "文档窗口", bundleID: "com.apple.TextEdit", appName: "TextEdit", frame: frame, isOnScreen: true)

        XCTAssertEqual(info.id, 42)
        XCTAssertEqual(info.title, "文档窗口")
        XCTAssertEqual(info.bundleID, "com.apple.TextEdit")
        XCTAssertEqual(info.frame, frame)
        XCTAssertTrue(info.isOnScreen)
    }

    func testWindowInfoHashable() {
        let a = WindowInfo(id: 1, title: "A", bundleID: "com.a", appName: "A", frame: .zero, isOnScreen: true)
        let b = WindowInfo(id: 1, title: "A", bundleID: "com.a", appName: "A", frame: .zero, isOnScreen: true)
        let c = WindowInfo(id: 2, title: "B", bundleID: "com.b", appName: "B", frame: .zero, isOnScreen: false)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }
}
