import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - Detect Dialogs Tool

public struct DetectDialogsTool: MCPTool {
    public let definition = ToolDefinition(
        name: "detect_dialogs",
        description: "检测当前前台应用中的对话框、表单和警告框，返回按钮和输入框信息",
        parameters: []
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let detector = DialogDetector()
        do {
            let dialogs = try await detector.detectDialogs()
            guard !dialogs.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "未检测到活动对话框")
            }
            var output = "检测到 \(dialogs.count) 个对话框:\n"
            for (i, dialog) in dialogs.enumerated() {
                let title = dialog.title.map { " \"\($0)\"" } ?? ""
                let message = dialog.message.map { "\n    内容: \($0.prefix(200))" } ?? ""
                let buttons = dialog.buttons.map { "\($0.title)\($0.enabled ? "" : " (禁用)")" }.joined(separator: ", ")
                let textFields = dialog.textFieldCount > 0 ? "\n    输入框: \(dialog.textFieldCount) 个" : ""
                output += "\n\(i + 1). [\(dialog.role)]\(title)\(message)\n    按钮: \(buttons.isEmpty ? "无" : buttons)\(textFields)\n"
            }
            return ToolCallResult(id: UUID().uuidString, output: output)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "检测对话框失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - Dialog Press Button Tool

public struct DialogPressButtonTool: MCPTool {
    public let definition = ToolDefinition(
        name: "dialog_press_button",
        description: "按下对话框中指定标题的按钮。不指定 dialog_title 时操作最前端的对话框",
        parameters: [
            .init(name: "button_label", type: .string, description: "按钮标题（如 '确定'、'取消'、'保存'）"),
            .init(name: "dialog_title", type: .string, description: "对话框标题（可选，用于精确匹配）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let buttonLabel = arguments["button_label"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: button_label", isError: true)
        }
        let dialogTitle = arguments["dialog_title"]
        let detector = DialogDetector()
        do {
            try await detector.pressButton(inDialogMatching: dialogTitle, buttonLabel: buttonLabel)
            let detail = dialogTitle.map { " in '\($0)'" } ?? ""
            return ToolCallResult(id: UUID().uuidString, output: "已按下按钮 '\(buttonLabel)'\(detail)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "按钮点击失败: \(error.localizedDescription)", isError: true)
        }
    }
}
