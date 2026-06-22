import AppKit
import CoreGraphics
import Foundation
import RenJistrolyModels

public struct ActionPolicy: Sendable {
    public var developerModeEnabled: Bool
    public var maximumAutoAllowRisk: ActionRiskLevel

    public init(
        developerModeEnabled: Bool = false,
        maximumAutoAllowRisk: ActionRiskLevel = .readOnly
    ) {
        self.developerModeEnabled = developerModeEnabled
        self.maximumAutoAllowRisk = maximumAutoAllowRisk
    }

    public func evaluate(_ action: MacAction, context: AssistantContext = AssistantContext()) -> PolicyDecision {
        switch action.kind {
        case .deleteFile, .runShellCommand:
            return developerModeEnabled
                ? .requireConfirmation("高风险动作需要确认：\(action.humanPreview)")
                : .developerModeOnly("该动作默认关闭：\(action.humanPreview)")
        case .sendMessage:
            return .requireConfirmation("外部发送动作需要确认：\(action.humanPreview)")
        case .quitApplication:
            return .requireConfirmation("退出应用可能丢失未保存内容，请确认：\(action.humanPreview)")
        case .openTerminalAtPath, .openTerminalCommand:
            return .requireConfirmation("即将在终端打开路径，请确认：\(action.humanPreview)")
        case .insertText, .setFocusedText, .setElementText:
            let text = action.payload["text"] ?? ""
            if text.count > 120 {
                return .requireConfirmation("即将插入较长文本（\(text.count) 字），请确认目标光标位置正确。")
            }
            if action.riskLevel <= maximumAutoAllowRisk {
                return .allow
            }
            return .requireConfirmation("请确认：\(action.humanPreview)")
        case .readContext, .readFocusedText, .copySelectedText, .pressShortcut, .clickFocused, .clickElement, .clickAt, .doubleClickAt, .rightClickAt, .scroll, .drag, .openApplication, .hideApplication, .closeWindow, .minimizeWindow, .openURL, .openFileOrFolder, .focusWeChatMessageInput:
            if action.riskLevel <= maximumAutoAllowRisk {
                return .allow
            }
            return .requireConfirmation("请确认：\(action.humanPreview)")
        }
    }
}

public actor ActionExecutor {
    private let accessibility: AccessibilityContextProvider

    public init(accessibility: AccessibilityContextProvider) {
        self.accessibility = accessibility
    }

    public func execute(_ action: MacAction) async -> ActionResult {
        do {
            switch action.kind {
            case .readContext:
                return ActionResult(actionID: action.id, success: true, message: "已读取上下文。")
            case .insertText:
                try await accessibility.insertText(action.payload["text"] ?? "")
                return ActionResult(actionID: action.id, success: true, message: "已插入文本。")
            case .setFocusedText:
                try await accessibility.setFocusedText(action.payload["text"] ?? "")
                return ActionResult(actionID: action.id, success: true, message: "已设置当前焦点文本。")
            case .clickElement:
                try await accessibility.clickElement(
                    label: action.payload["label"] ?? "",
                    role: action.payload["role"],
                    owner: action.payload["owner"]
                )
                return ActionResult(actionID: action.id, success: true, message: "已点击目标控件。")
            case .setElementText:
                try await accessibility.setElementText(
                    label: action.payload["label"] ?? "",
                    text: action.payload["text"] ?? "",
                    role: action.payload["role"],
                    owner: action.payload["owner"]
                )
                return ActionResult(actionID: action.id, success: true, message: "已在目标控件输入文本。")
            case .pressShortcut:
                let key = action.payload["key"] ?? ""
                let modifiers = action.payload["modifiers"]?.split(separator: "+").map(String.init) ?? []
                try await accessibility.pressShortcut(key: key, modifiers: modifiers)
                return ActionResult(actionID: action.id, success: true, message: "已发送快捷键。")
            case .clickFocused:
                try await accessibility.clickFocused()
                return ActionResult(actionID: action.id, success: true, message: "已点击焦点元素。")
            case .clickAt:
                let point = pointPayload(action.payload)
                let success = await accessibility.click(at: point, clickCount: 1, button: .left)
                return ActionResult(actionID: action.id, success: success, message: success ? "已点击坐标。" : "点击坐标失败。")
            case .doubleClickAt:
                let point = pointPayload(action.payload)
                let success = await accessibility.click(at: point, clickCount: 2, button: .left)
                return ActionResult(actionID: action.id, success: success, message: success ? "已双击坐标。" : "双击坐标失败。")
            case .rightClickAt:
                let point = pointPayload(action.payload)
                let success = await accessibility.click(at: point, clickCount: 1, button: .right)
                return ActionResult(actionID: action.id, success: success, message: success ? "已右键点击坐标。" : "右键点击失败。")
            case .scroll:
                let direction = action.payload["direction"] ?? "down"
                let amount = Double(action.payload["amount"] ?? "5") ?? 5
                let success = await accessibility.scroll(direction: direction, amount: amount)
                return ActionResult(actionID: action.id, success: success, message: success ? "已滚动。" : "滚动失败。")
            case .drag:
                let success = await accessibility.drag(
                    from: pointPayload(action.payload, prefix: "from"),
                    to: pointPayload(action.payload, prefix: "to")
                )
                return ActionResult(actionID: action.id, success: success, message: success ? "已拖拽。" : "拖拽失败。")
            case .openApplication:
                let name = action.payload["name"] ?? ""
                let success = await accessibility.openApplication(named: name)
                return ActionResult(actionID: action.id, success: success, message: success ? "已切换/打开应用：\(name)。" : "未能打开应用：\(name)。")
            case .quitApplication:
                let name = action.payload["name"] ?? ""
                let success = await accessibility.quitApplication(named: name)
                return ActionResult(actionID: action.id, success: success, message: success ? "已请求退出应用：\(name)。" : "未能退出应用：\(name)。")
            case .hideApplication:
                let name = action.payload["name"] ?? ""
                let success = await accessibility.hideApplication(named: name)
                return ActionResult(actionID: action.id, success: success, message: success ? "已隐藏应用：\(name)。" : "未能隐藏应用：\(name)。")
            case .closeWindow:
                try await accessibility.pressShortcut(key: "w", modifiers: ["cmd"])
                return ActionResult(actionID: action.id, success: true, message: "已关闭当前窗口。")
            case .minimizeWindow:
                try await accessibility.pressShortcut(key: "m", modifiers: ["cmd"])
                return ActionResult(actionID: action.id, success: true, message: "已最小化当前窗口。")
            case .openURL:
                let rawURL = action.payload["url"] ?? ""
                let success = await accessibility.openURL(rawURL)
                return ActionResult(actionID: action.id, success: success, message: success ? "已打开链接。" : "未能打开链接。")
            case .openFileOrFolder:
                let path = action.payload["path"] ?? ""
                let success = await accessibility.openFileOrFolder(path)
                return ActionResult(actionID: action.id, success: success, message: success ? "已打开路径。" : "未能打开路径。")
            case .openTerminalAtPath:
                let path = action.payload["path"] ?? NSHomeDirectory()
                let success = await accessibility.openTerminal(at: path)
                return ActionResult(actionID: action.id, success: success, message: success ? "已打开终端并进入路径。" : "未能打开终端路径。")
            case .openTerminalCommand:
                let path = action.payload["path"] ?? NSHomeDirectory()
                let command = action.payload["command"] ?? ""
                let title = action.payload["title"]
                let success = await accessibility.openTerminal(command: command, at: path, title: title)
                return ActionResult(actionID: action.id, success: success, message: success ? "已打开终端并运行命令。" : "未能运行终端命令。")
            case .focusWeChatMessageInput:
                let success = await accessibility.focusWeChatMessageInput()
                return ActionResult(actionID: action.id, success: success, message: success ? "已定位微信当前会话输入框。" : "未能定位微信输入框。")
            case .copySelectedText:
                try await accessibility.pressShortcut(key: "c", modifiers: ["cmd"])
                return ActionResult(actionID: action.id, success: true, message: "已复制选中文本。")
            case .readFocusedText:
                let text = await accessibility.focusedTextDescription()
                return ActionResult(actionID: action.id, success: true, message: text)
            case .sendMessage, .deleteFile, .runShellCommand:
                return ActionResult(actionID: action.id, success: false, message: "该动作需要更高权限，当前未执行。")
            }
        } catch {
            return ActionResult(actionID: action.id, success: false, message: actionErrorMessage(error))
        }
    }

    private func actionErrorMessage(_ error: Error) -> String {
        if case AccessibilityContextError.notAuthorized = error {
            AccessibilityPermissionGuide.promptAndOpenSettings()
            return AccessibilityPermissionGuide.message
        }
        return error.localizedDescription
    }

    private func pointPayload(_ payload: [String: String], prefix: String = "") -> CGPoint {
        let xKey = prefix.isEmpty ? "x" : "\(prefix)X"
        let yKey = prefix.isEmpty ? "y" : "\(prefix)Y"
        return CGPoint(
            x: Double(payload[xKey] ?? "0") ?? 0,
            y: Double(payload[yKey] ?? "0") ?? 0
        )
    }
}
