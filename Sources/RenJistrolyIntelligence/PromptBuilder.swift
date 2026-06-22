import AppKit
import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - Prompt Building

extension AssistantSessionController {

    func conversationPrompt() -> String {
        if providerPreference == .claudeCode {
            if !voiceState.isConversationMode { return "当前通过 Claude Code 进行交互。你可以使用工具、读写文件、执行代码。请提供详细的技术回复。" }
            return """
            你通过 Claude Code 与用户实时语音对话。你是完整的开发智能体：
            - 默认用中文回复，但代码、术语保持原文。
            - 可以深入技术细节，用户是开发者，不需要过度简化。
            - 可以主动建议架构方案、调试思路、性能优化。
            - 需要屏幕信息时，基于上下文中的 OCR 和窗口信息回答。
            - 如果用户请求复杂操作，直接执行即可。
            """
        }
        guard voiceState.isConversationMode else { return "当前是单轮文本/语音请求。" }
        return """
        当前是实时语音对话模式。请像口语交流一样回答：
        - 默认用中文，短句、直接、不要写长段落。
        - 用户只是测试听没听见时，直接确认即可。
        - 不要解释内部链路，除非用户问。
        - 需要屏幕信息时，基于上下文里的 OCR 和窗口信息回答。
        """
    }

    func contextPrompt(for context: AssistantContext, userText: String) -> String {
        var lines: [String] = [
            "当前 Mac 上下文："
        ]
        if let app = context.app {
            lines.append("- 前台 App：\(app.appName)")
            if let bundle = app.bundleIdentifier {
                lines.append("- Bundle ID：\(bundle)")
            }
            if let title = app.windowTitle, !title.isEmpty {
                lines.append("- 窗口标题：\(title)")
            }
        } else {
            lines.append("- 前台 App：未知")
        }

        if !context.runningApps.isEmpty {
            let apps = context.runningApps.prefix(40).map { app in
                let active = app.isFrontmost ? "（前台）" : ""
                let bundle = app.bundleIdentifier.map { " [\($0)]" } ?? ""
                return "\(app.appName)\(active)\(bundle)"
            }.joined(separator: "\n")
            lines.append("- 正在运行的 App：\n\(apps)")
        }

        if let appInstruction = appInstructionLibrary.instructions(for: context.app?.appName) {
            lines.append("- 当前 App 专用 Computer Use 指令：\(appInstruction)")
        }

        if let element = context.focusedElement {
            lines.append("- 焦点控件角色：\(element.role ?? "未知")")
            if let title = element.title, !title.isEmpty {
                lines.append("- 焦点控件标题：\(title)")
            }
            if let selected = element.selectedText, !selected.isEmpty {
                lines.append("- 当前选中文本：\(selected)")
            }
            if let value = element.value, !value.isEmpty {
                lines.append("- 焦点控件内容：\(value.prefix(500))")
            }
        } else {
            lines.append("- 焦点控件：未读取到。可能未授权辅助功能，或当前 App 不暴露控件。")
        }

        // Claude Code 模式下始终包含屏幕上下文，其他模式按需包含
        let shouldIncludeScreen = providerPreference == .claudeCode || shouldIncludeScreenContext(for: userText)
        if shouldIncludeScreen {
            if let screen = context.screen {
                lines.append("- 屏幕读取状态：\(screen.displayDescription)")
                lines.append("- 屏幕回答规则：用户问能不能看屏幕、当前界面、窗口或截图时，必须先基于这里的上下文回答；除非状态明确说未授权，否则不要回答「看不到」「没有实时屏幕」或要求用户重新发截图。")
                if !screen.visibleWindows.isEmpty {
                    let visibleWindows = screen.visibleWindows.prefix(12).map { window in
                        let title = window.windowTitle.map { " - \($0)" } ?? ""
                        return "\(window.ownerName)\(title) [\(window.boundsDescription)]"
                    }.joined(separator: "\n")
                    lines.append("- 屏幕可见窗口：\n\(visibleWindows)")
                }
                let ocrText = (screen.recognizedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
                    ? (lastComputerUseObservation?.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                    : (screen.recognizedText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                if !ocrText.isEmpty {
                    lines.append("- 屏幕 OCR 文本：\(ocrText.prefix(2000))")
                    lines.append("- 回答屏幕相关问题时，优先基于 OCR 文本、前台 App、窗口标题、焦点控件和选中文本。说明这是文字识别结果，不要假装看到了 OCR 之外的图像细节。")
                } else if screen.displayDescription.localizedCaseInsensitiveContains("permission") || screen.displayDescription.contains("未授权") || screen.displayDescription.contains("not granted") {
                    lines.append("- 屏幕 OCR 文本：未读取到，因为屏幕录制权限未生效。请直接告诉用户需要在系统设置中给当前 App 开启屏幕录制并重启 App。")
                } else {
                    lines.append("- 屏幕 OCR 没有识别到文字，但你可以基于上面的可见窗口列表、前台 App、焦点控件、选中文本等信息来描述屏幕状态。不要说你「看不到屏幕」或「没有收到数据」——你已经收到了完整的窗口和应用上下文，把这些信息告诉用户即可。")
                }
            } else {
                lines.append("- 屏幕读取状态：未读取。可以基于 App、窗口标题、焦点控件和选中文本回答，不要声称直接看见屏幕图像。")
            }
        }

        // Cursor position
        if let cursor = context.screen?.cursorPosition, cursor != .zero {
            let screenFrame = NSScreen.main?.frame ?? .zero
            let relX = screenFrame.width > 0 ? String(format: "%.1f%%", cursor.x / screenFrame.width * 100) : "\(Int(cursor.x))"
            let relY = screenFrame.height > 0 ? String(format: "%.1f%%", cursor.y / screenFrame.height * 100) : "\(Int(cursor.y))"
            lines.append("- 鼠标位置：\(Int(cursor.x)), \(Int(cursor.y))（屏幕 \(relX), \(relY)）")
        }

        // Active dialogs detected within last 5 seconds
        let recentDialogs = context.activeDialogs.filter { Date().timeIntervalSince($0.detectedAt) < 5.0 }
        if !recentDialogs.isEmpty {
            for dialog in recentDialogs {
                lines.append("- 检测到弹窗：\(dialog.appName) — \(dialog.role)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
