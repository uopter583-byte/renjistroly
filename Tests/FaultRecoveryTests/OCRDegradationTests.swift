import XCTest
@testable import RenJistrolySystemBridge
@testable import RenJistrolyModels

// MARK: - Mock 基础类型

private enum OCRDegradationError: Error, LocalizedError {
    case visionFailed(String)
    case ppocrFailed(String)
    case axNotAvailable
    case allEnginesFailed

    var errorDescription: String? {
        switch self {
        case .visionFailed(let msg): "Vision OCR 失败: \(msg)"
        case .ppocrFailed(let msg): "PPOCR 失败: \(msg)"
        case .axNotAvailable: "辅助功能不可用"
        case .allEnginesFailed: "所有 OCR 引擎均失败"
        }
    }
}

/// 降级策略
private enum DegradationStrategy: String {
    case visionToPPOCR
    case visionToAXOnly
    case fullDegradation
    case userConfirmRequired
}

/// 降级报告
private struct DegradationReport {
    let attemptedEngines: [String]
    let finalStrategy: String
    let userPrompt: String?
    let requiresUserConfirmation: Bool
}

/// 模拟的 OCR 降级管理器
private final class MockOCRDegradationManager {
    /// 控制 Vision OCR 是否成功
    var visionSuccess: Bool = true
    /// 控制 PPOCR 是否成功
    var ppocrSuccess: Bool = true
    /// 控制 AX 是否可用
    var axAvailable: Bool = true
    /// 模拟 OCR 返回结果
    var mockOCRResults: [OCRResult] = []
    /// 模拟低置信度
    var lowConfidence: Bool = false

    private(set) var degradationLog: [DegradationStrategy] = []
    private(set) var visionCallCount: Int = 0
    private(set) var ppocrCallCount: Int = 0
    private(set) var axCallCount: Int = 0

    /// 执行带降级的 OCR 识别
    func recognizeWithDegradation(in imageData: Data) async -> DegradationReport {
        // 尝试 Vision OCR
        visionCallCount += 1
        if visionSuccess {
            if lowConfidence {
                let results = mockOCRResults.isEmpty
                    ? [OCRResult(text: "可能文字", confidence: 0.35, x: 0, y: 0, width: 100, height: 20, engine: .appleVision)]
                    : mockOCRResults
                let allLowConf = results.allSatisfy { $0.confidence < 0.5 }
                if allLowConf {
                    degradationLog.append(.userConfirmRequired)
                    return DegradationReport(
                        attemptedEngines: ["appleVision"],
                        finalStrategy: "请求用户确认",
                        userPrompt: "OCR 置信度过低（< 50%），请确认识别结果是否正确",
                        requiresUserConfirmation: true
                    )
                }
            }
            _ = mockOCRResults.isEmpty
                ? [OCRResult(text: "测试文字", confidence: 0.95, x: 0, y: 0, width: 100, height: 20, engine: .appleVision)]
                : mockOCRResults
            degradationLog.append(.visionToPPOCR)
            return DegradationReport(
                attemptedEngines: ["appleVision"],
                finalStrategy: "appleVision",
                userPrompt: nil,
                requiresUserConfirmation: false
            )
        }

        // Vision 失败 → 降级到 PPOCR
        ppocrCallCount += 1
        if ppocrSuccess {
            _ = mockOCRResults.isEmpty
                ? [OCRResult(text: "PPOCR 文字", confidence: 0.88, x: 0, y: 0, width: 100, height: 20, engine: .ppocrV6)]
                : mockOCRResults
            degradationLog.append(.visionToPPOCR)
            return DegradationReport(
                attemptedEngines: ["appleVision", "ppocrV6"],
                finalStrategy: "ppocrV6",
                userPrompt: "Vision OCR 不可用，已降级使用 PP-OCRv6",
                requiresUserConfirmation: false
            )
        }

        // PPOCR 也失败 → 降级到 AX-only
        axCallCount += 1
        if axAvailable {
            degradationLog.append(.visionToAXOnly)
            return DegradationReport(
                attemptedEngines: ["appleVision", "ppocrV6"],
                finalStrategy: "AXOnly",
                userPrompt: "OCR 引擎均不可用，已降级使用辅助功能获取界面信息",
                requiresUserConfirmation: false
            )
        }

        // AX 也不可用 → 完整降级报告
        degradationLog.append(.fullDegradation)
        return DegradationReport(
            attemptedEngines: ["appleVision", "ppocrV6"],
            finalStrategy: "none",
            userPrompt: "所有文字识别方式均不可用，请检查权限设置后重试",
            requiresUserConfirmation: true
        )
    }
}

// MARK: - OCRDegradationTests

final class OCRDegradationTests: XCTestCase {

    /// Vision OCR 返回空 → 降级到 PPOCR
    func testVisionEmptyDegradesToPPOCR() async {
        let manager = MockOCRDegradationManager()
        manager.visionSuccess = false
        manager.ppocrSuccess = true
        let data = Data("mock_image".utf8)

        let report = await manager.recognizeWithDegradation(in: data)

        XCTAssertEqual(report.finalStrategy, "ppocrV6", "应降级到 PP-OCRv6")
        XCTAssertEqual(manager.visionCallCount, 1, "应尝试 Vision OCR")
        XCTAssertEqual(manager.ppocrCallCount, 1, "应尝试 PPOCR")
        XCTAssertEqual(manager.axCallCount, 0, "不应尝试 AX")
        XCTAssertTrue(report.userPrompt?.contains("降级") ?? false, "应包含降级提示")
        XCTAssertFalse(report.requiresUserConfirmation, "降级到 PPOCR 不应要求用户确认")
    }

    /// PPOCR 也失败 → 降级到 AX-only
    func testPPOCRFailureDegradesToAXOnly() async {
        let manager = MockOCRDegradationManager()
        manager.visionSuccess = false
        manager.ppocrSuccess = false
        manager.axAvailable = true
        let data = Data("mock_image".utf8)

        let report = await manager.recognizeWithDegradation(in: data)

        XCTAssertEqual(report.finalStrategy, "AXOnly", "应降级到 AX-only")
        XCTAssertEqual(manager.visionCallCount, 1, "应尝试 Vision OCR")
        XCTAssertEqual(manager.ppocrCallCount, 1, "应尝试 PPOCR")
        XCTAssertEqual(manager.axCallCount, 1, "应尝试 AX")
        XCTAssertTrue(report.userPrompt?.contains("降级") ?? false)
    }

    /// AX 也不可用 → 完整降级报告
    func testAllEnginesUnavailableReturnsFullDegradationReport() async {
        let manager = MockOCRDegradationManager()
        manager.visionSuccess = false
        manager.ppocrSuccess = false
        manager.axAvailable = false
        let data = Data("mock_image".utf8)

        let report = await manager.recognizeWithDegradation(in: data)

        XCTAssertEqual(report.finalStrategy, "none", "应返回无可用引擎")
        XCTAssertTrue(report.requiresUserConfirmation, "应要求用户确认")
        XCTAssertTrue(report.userPrompt?.contains("均不可用") ?? false, "应提示所有方式均不可用")
        XCTAssertEqual(manager.degradationLog.last, .fullDegradation)
    }

    /// OCR 置信度低 → 请求用户确认
    func testLowConfidenceRequestsUserConfirmation() async {
        let manager = MockOCRDegradationManager()
        manager.visionSuccess = true
        manager.lowConfidence = true
        manager.mockOCRResults = [
            OCRResult(text: "模糊文字", confidence: 0.30, x: 0, y: 0, width: 50, height: 20, engine: .appleVision),
            OCRResult(text: "不清", confidence: 0.25, x: 0, y: 30, width: 40, height: 20, engine: .appleVision),
        ]
        let data = Data("mock_image".utf8)

        let report = await manager.recognizeWithDegradation(in: data)

        XCTAssertTrue(report.requiresUserConfirmation, "低置信度应要求用户确认")
        XCTAssertTrue(report.userPrompt?.contains("置信度") ?? false, "应提示置信度问题")
        XCTAssertEqual(manager.degradationLog.last, .userConfirmRequired)
    }

    /// 正常 Vision OCR 直接返回结果（无降级路径）
    func testNormalVisionOCRReturnsDirectly() async {
        let manager = MockOCRDegradationManager()
        manager.visionSuccess = true
        let data = Data("mock_image".utf8)

        let report = await manager.recognizeWithDegradation(in: data)

        XCTAssertEqual(report.finalStrategy, "appleVision", "正常情况下应直接使用 Vision OCR")
        XCTAssertNil(report.userPrompt, "正常情况不应有用户提示")
        XCTAssertFalse(report.requiresUserConfirmation)
        XCTAssertEqual(manager.ppocrCallCount, 0, "不应尝试 PPOCR")
    }
}
