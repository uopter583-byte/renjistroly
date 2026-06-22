import AppKit
import Foundation
import RenJistrolyModels

/// macOS AX API backend — wraps AccessibilityContextProvider for native app automation.
public actor AXComputerUseBackend: ComputerUseBackend {
    public let kind: ComputerUseBackendKind = .accessibility
    public let displayName = "AX (辅助功能)"

    private let accessibility: AccessibilityContextProvider

    public init(accessibility: AccessibilityContextProvider) {
        self.accessibility = accessibility
    }

    public func observe(existingObservation: ComputerUseObservation) async -> ComputerUseObservation {
        var updated = existingObservation
        updated.compactAXTree = await accessibility.compactAccessibilityTree(limit: 40)
        return updated
    }

    public nonisolated func canHandle(action: MacAction) -> Bool {
        switch action.kind {
        case .readContext, .clickElement, .setFocusedText, .insertText,
             .pressShortcut, .scroll, .drag, .clickAt,
             .doubleClickAt, .rightClickAt, .openApplication,
             .quitApplication, .hideApplication, .closeWindow, .minimizeWindow,
             .openURL, .openFileOrFolder, .openTerminalAtPath, .openTerminalCommand,
             .focusWeChatMessageInput, .copySelectedText, .readFocusedText, .setElementText:
            return true
        default:
            return false
        }
    }

    public nonisolated func execute(action: MacAction) async -> BackendActionResult {
        let p = action.payload
        do {
            switch action.kind {
            case .clickElement:
                let label = p["label"] ?? p["title"] ?? ""
                let role = p["role"]
                let owner = p["owner"]
                try await self.accessibility.clickElement(label: label, role: role, owner: owner)
                return BackendActionResult(success: true, message: "已点击元素: \(label)")
            case .setFocusedText, .insertText:
                let text = p["text"] ?? p["value"] ?? ""
                try await self.accessibility.setFocusedText(text)
                return BackendActionResult(success: true, message: "已输入文本")
            case .pressShortcut:
                let key = p["key"] ?? ""
                let modifiers = (p["modifiers"] ?? "").split(separator: ",").map(String.init)
                try await self.accessibility.pressShortcut(key: key, modifiers: modifiers)
                return BackendActionResult(success: true, message: "已执行快捷键")
            case .scroll:
                let direction = p["direction"] ?? "down"
                let amount = Double(p["amount"] ?? "1") ?? 1
                let succeeded = await self.accessibility.scroll(direction: direction, amount: amount)
                return BackendActionResult(success: succeeded, message: succeeded ? "已滚动" : "滚动失败")
            case .clickAt:
                let x = Double(p["x"] ?? "0") ?? 0
                let y = Double(p["y"] ?? "0") ?? 0
                let succeeded = await self.accessibility.click(at: CGPoint(x: x, y: y))
                return BackendActionResult(success: succeeded, message: succeeded ? "已点击坐标" : "点击坐标失败")
            case .doubleClickAt:
                let x = Double(p["x"] ?? "0") ?? 0
                let y = Double(p["y"] ?? "0") ?? 0
                let succeeded = await self.accessibility.click(at: CGPoint(x: x, y: y), clickCount: 2)
                return BackendActionResult(success: succeeded, message: succeeded ? "已双击" : "双击失败")
            case .rightClickAt:
                let x = Double(p["x"] ?? "0") ?? 0
                let y = Double(p["y"] ?? "0") ?? 0
                let succeeded = await self.accessibility.click(at: CGPoint(x: x, y: y), button: .right)
                return BackendActionResult(success: succeeded, message: succeeded ? "已右键" : "右键失败")
            case .drag:
                let fromX = Double(p["from_x"] ?? "0") ?? 0
                let fromY = Double(p["from_y"] ?? "0") ?? 0
                let toX = Double(p["to_x"] ?? "0") ?? 0
                let toY = Double(p["to_y"] ?? "0") ?? 0
                let succeeded = await self.accessibility.drag(from: CGPoint(x: fromX, y: fromY), to: CGPoint(x: toX, y: toY))
                return BackendActionResult(success: succeeded, message: succeeded ? "已拖拽" : "拖拽失败")
            case .openApplication:
                let name = p["name"] ?? p["app"] ?? ""
                let succeeded = await self.accessibility.openApplication(named: name)
                return BackendActionResult(success: succeeded, message: succeeded ? "已打开应用: \(name)" : "打开应用失败: \(name)")
            case .quitApplication:
                let name = p["name"] ?? p["app"] ?? ""
                let succeeded = await self.accessibility.quitApplication(named: name)
                return BackendActionResult(success: succeeded, message: succeeded ? "已退出应用: \(name)" : "退出应用失败: \(name)")
            case .hideApplication:
                let name = p["name"] ?? p["app"] ?? ""
                let succeeded = await self.accessibility.hideApplication(named: name)
                return BackendActionResult(success: succeeded, message: succeeded ? "已隐藏应用: \(name)" : "隐藏应用失败: \(name)")
            case .openURL:
                let url = p["url"] ?? ""
                let succeeded = await self.accessibility.openURL(url)
                return BackendActionResult(success: succeeded, message: succeeded ? "已打开 URL" : "打开 URL 失败")
            case .openFileOrFolder:
                let path = p["path"] ?? ""
                let succeeded = await self.accessibility.openFileOrFolder(path)
                return BackendActionResult(success: succeeded, message: succeeded ? "已打开路径: \(path)" : "打开路径失败: \(path)")
            case .readContext:
                let description = await self.accessibility.focusedTextDescription()
                return BackendActionResult(success: true, message: description)
            case .readFocusedText:
                let text = await self.accessibility.readSelectedText() ?? "(无选中文本)"
                return BackendActionResult(success: true, message: text)
            default:
                return BackendActionResult(success: false, message: "AX 后端不支持该操作")
            }
        } catch {
            return BackendActionResult(success: false, message: "AX 操作失败: \(error.localizedDescription)")
        }
    }
}
