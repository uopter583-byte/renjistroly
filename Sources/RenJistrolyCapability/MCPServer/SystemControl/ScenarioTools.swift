import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

public struct PolishReplaceTool: MCPTool {
    public let definition = ToolDefinition(
        name: "polish_replace",
        description: "润色当前选中文字并用润色后的文字替换。适用于'润色这段文字''优化文字'等指令",
        parameters: [
            .init(name: "style", type: .string, description: "润色风格: concise(简洁), formal(正式), casual(口语), code(代码优化)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let bridge = AccessibilityBridge()
        guard await bridge.checkPermission() else {
            AccessibilityPermissionGuide.promptAndOpenSettings()
            return ToolCallResult(id: UUID().uuidString, output: AccessibilityPermissionGuide.message, isError: true)
        }

        guard let selected = try? await bridge.getSelectedText(), !selected.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "没有选中文字。请先选中要润色的文字。", isError: true)
        }

        let style = arguments["style"] ?? "concise"
        Task { await AgentEventBus.shared.publish(.lifecycle(.actingStarted(action: "润色文字", tool: "polish_replace"))) }
        return ToolCallResult(
            id: UUID().uuidString,
            output: "__POLISH_SELECTED__\n风格: \(style)\n原文:\n\(selected)",
            isError: false
        )
    }
}

public struct ExplainSelectedTool: MCPTool {
    public let definition = ToolDefinition(
        name: "explain_selected",
        description: "解释当前选中的文字或代码。适用于'解释这段代码''这是什么意思''翻译选中的文字'",
        parameters: [
            .init(name: "focus", type: .string, description: "解释侧重: code(代码), text(文字), translate(翻译)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let bridge = AccessibilityBridge()
        guard let selected = try? await bridge.getSelectedText(), !selected.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "没有选中文字。请先选中要解释的文字。", isError: true)
        }

        let focus = arguments["focus"] ?? "text"
        Task { await AgentEventBus.shared.publish(.lifecycle(.actingStarted(action: "解释选中", tool: "explain_selected"))) }
        return ToolCallResult(
            id: UUID().uuidString,
            output: "__EXPLAIN_SELECTED__\n侧重: \(focus)\n内容:\n\(selected)",
            isError: false
        )
    }
}

public struct ScreenContextTool: MCPTool {
    public let definition = ToolDefinition(
        name: "screen_context",
        description: "获取当前屏幕完整上下文：OCR文字识别结果 + 辅助功能 UI 树 + 前台应用信息。用于理解当前屏幕状态，是 computer use 的统一入口。",
        parameters: [
            .init(name: "ocr_engine", type: .string, description: "OCR 引擎: vision, ppocr, both（默认 vision，速度最快）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let engineStr = arguments["ocr_engine"] ?? "vision"
        let engine: OCREngine = switch engineStr {
        case "ppocr": .ppocrV6
        case "both": .both
        default: .appleVision
        }

        var output = "=== 屏幕上下文 ===\n\n"

        let axBridge = AccessibilityBridge()
        if let bundleID = try? await axBridge.getFocusedAppBundleID() {
            output += "【前台应用】\(bundleID)\n"
        }
        if let windowTitle = try? await axBridge.getFocusedWindowTitle() {
            output += "【窗口标题】\(windowTitle)\n"
        }
        if let role = try? await axBridge.getElementRole() {
            output += "【焦点控件】\(role)\n"
        }
        if let value = try? await axBridge.getFocusedValue(), !value.isEmpty {
            output += "【焦点内容】\(value.prefix(500))\n"
        }
        if let selected = try? await axBridge.getSelectedText(), !selected.isEmpty {
            output += "【选中文字】\(selected.prefix(500))\n"
        }

        let capture = ScreenCaptureBridge()
        do {
            let ownIDs = (try? await capture.getOwnWindowIDs()) ?? []
            let pngData = try await capture.captureScreen(excludingWindowIDs: ownIDs)
            let ocrResults = try await OCRService.shared.recognize(in: pngData, preferredEngine: engine)
            let texts = ocrResults.filter { $0.confidence >= 0.2 && !$0.text.isEmpty }
            if !texts.isEmpty {
                output += "\n【OCR 文字】（共 \(texts.count) 个区域）\n"
                for (i, r) in texts.prefix(30).enumerated() {
                    output += "  \(i + 1). \"\(r.text)\" (conf:\(String(format: "%.2f", r.confidence)) @ "
                    output += "\(String(format: "%.2f", r.x)),\(String(format: "%.2f", r.y)))"
                    if r.engine == .ppocrV6 { output += " [ppocr]" }
                    output += "\n"
                }
                if texts.count > 30 {
                    output += "  ... 还有 \(texts.count - 30) 个区域\n"
                }
                output += "\n【屏幕全文】\(texts.map(\.text).joined(separator: " ").prefix(1000))\n"
            } else {
                output += "\n【OCR】未检测到文字\n"
            }
        } catch {
            output += "\n【OCR】读取失败：\(error.localizedDescription)\n"
        }

        if let tree = try? await axBridge.getUIElementTree(maxDepth: 3), !tree.isEmpty {
            output += "\n【UI 结构】\n"
            for node in tree.prefix(20) {
                let indent = String(repeating: "  ", count: min(node.depth, 3))
                let title = node.title.map { " \"\($0)\"" } ?? ""
                output += "  \(indent)\(node.role)\(title)\n"
            }
        }

        let ocrChars = output.components(separatedBy: "【OCR 文字】").count > 1 ? output.count : 0
        let winCount = output.components(separatedBy: "【UI 结构】").count > 1 ? 1 : 0
        Task { await AgentEventBus.shared.publish(.desktop(.screenCaptured(ocrCharCount: ocrChars, windowCount: winCount))) }
        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

public struct ReadScreenTool: MCPTool {
    public let definition = ToolDefinition(
        name: "read_screen",
        description: "读取当前屏幕内容，包括 OCR 文字、当前应用、窗口标题、焦点元素和 UI 结构",
        parameters: [
            .init(name: "ocr_engine", type: .string, description: "OCR 引擎: vision, ppocr, both（默认 vision）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        try await ScreenContextTool().execute(arguments: arguments)
    }
}
