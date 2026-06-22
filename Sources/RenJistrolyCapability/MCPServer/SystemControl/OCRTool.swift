import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

public struct OCRTool: MCPTool {
    public let definition = ToolDefinition(
        name: "ocr_screen",
        description: "对当前屏幕截图进行 OCR 文字识别。使用 Apple Vision + PP-OCRv6 双引擎合并结果，支持中文、英文、日文混合识别。返回检测到的所有文字区域及其屏幕位置（归一化坐标）。",
        parameters: [
            .init(name: "min_confidence", type: .string, description: "最低置信度 0.0-1.0，默认 0.3", required: false),
            .init(name: "engine", type: .string, description: "OCR 引擎: vision, ppocr, both（默认 both）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let minConfidence = Float(arguments["min_confidence"] ?? "0.3") ?? 0.3
        let engineStr = arguments["engine"] ?? "both"
        let engine: OCREngine = switch engineStr {
        case "vision": .appleVision
        case "ppocr": .ppocrV6
        default: .both
        }

        let capture = ScreenCaptureBridge()

        let pngData: Data
        do {
            let ownIDs = (try? await capture.getOwnWindowIDs()) ?? []
            pngData = try await capture.captureScreen(excludingWindowIDs: ownIDs)
        } catch {
            return ToolCallResult(
                id: UUID().uuidString,
                output: "截屏失败: \(error.localizedDescription)",
                isError: true
            )
        }

        let results: [OCRResult]
        do {
            results = try await OCRService.shared.recognize(in: pngData, preferredEngine: engine)
        } catch {
            return ToolCallResult(
                id: UUID().uuidString,
                output: "OCR 识别失败: \(error.localizedDescription)",
                isError: true
            )
        }

        let filtered = results.filter { $0.confidence >= minConfidence }
        if filtered.isEmpty {
            return ToolCallResult(
                id: UUID().uuidString,
                output: "屏幕上未检测到文字（最低置信度: \(String(format: "%.1f", minConfidence))）"
            )
        }

        let visionCount = filtered.filter { $0.engine == .appleVision }.count
        let ppocrCount = filtered.filter { $0.engine == .ppocrV6 }.count
        var header = "屏幕文字识别结果（共 \(filtered.count) 个文本区域"
        if engine == .both {
            header += "，Vision: \(visionCount)，PPOCR: \(ppocrCount)"
        }
        header += "）：\n\n"

        let lines = filtered.enumerated().map { i, r in
            "\(i + 1). \"\(r.text)\" (置信度: \(String(format: "%.2f", r.confidence)), 区域: [\(String(format: "%.2f", r.x)),\(String(format: "%.2f", r.y)) \(String(format: "%.2f", r.width))×\(String(format: "%.2f", r.height))]\(r.engine == .ppocrV6 ? " [PPOCR]" : "")"
        }

        let fullText = filtered.map(\.text).joined(separator: " ")
        let summary = header + lines.joined(separator: "\n") + "\n\n--- 屏幕全文 ---\n" + fullText
        Task { await AgentEventBus.shared.publish(.desktop(.screenCaptured(ocrCharCount: fullText.count, windowCount: 0))) }
        return ToolCallResult(id: UUID().uuidString, output: summary)
    }
}
