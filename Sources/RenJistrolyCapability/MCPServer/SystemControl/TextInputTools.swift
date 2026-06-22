import Foundation
import AppKit
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - Frontmost App Helper

private func getFrontAppName() async -> String {
    await MainActor.run { NSWorkspace.shared.frontmostApplication?.localizedName ?? "未知" }
}

// MARK: - Type Text Tool

public struct TypeTextTool: MCPTool {
    public let definition = ToolDefinition(
        name: "type_text",
        description: "在当前焦点窗口直接输入文字（模拟键盘输入），可用于终端、编辑器、浏览器等任何输入框",
        parameters: [
            .init(name: "text", type: .string, description: "要输入的文字内容"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let text = arguments["text"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: text", isError: true)
        }
        try? await Task.sleep(for: .milliseconds(500))

        let bridge = AccessibilityBridge()
        if await !bridge.checkPermission() {
            AccessibilityPermissionGuide.promptAndOpenSettings()
            return ToolCallResult(id: UUID().uuidString, output: AccessibilityPermissionGuide.message, isError: true)
        }

        let focusedApp = await getFrontAppName()

        guard await getFrontAppName() == focusedApp else {
            return ToolCallResult(id: UUID().uuidString, output: "前台应用已变更", isError: true)
        }
        do {
            try await bridge.trySetTextToFocused(text)
            let preview = text.count > 80 ? String(text.prefix(80)) + "…" : text
            Task { await AgentEventBus.shared.publish(.desktop(.textTyped(text: text, app: focusedApp))) }
            return ToolCallResult(id: UUID().uuidString, output: "已在 [\(focusedApp)] 输入: \(preview)")
        } catch {
            guard await getFrontAppName() == focusedApp else {
                return ToolCallResult(id: UUID().uuidString, output: "前台应用已变更", isError: true)
            }
            do {
                try await bridge.pasteText(text)
                Task { await AgentEventBus.shared.publish(.desktop(.textTyped(text: text, app: focusedApp))) }
                return ToolCallResult(id: UUID().uuidString, output: "已在 [\(focusedApp)] 粘贴: \(text.prefix(80))")
            } catch {
                guard await getFrontAppName() == focusedApp else {
                    return ToolCallResult(id: UUID().uuidString, output: "前台应用已变更", isError: true)
                }
                do {
                    try await bridge.typeText(text)
                    Task { await AgentEventBus.shared.publish(.desktop(.textTyped(text: text, app: focusedApp))) }
                    return ToolCallResult(id: UUID().uuidString, output: "已在 [\(focusedApp)] 键入: \(text.prefix(80))")
                } catch {
                    return ToolCallResult(id: UUID().uuidString, output: "输入失败 [\(focusedApp)]: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }
}

// MARK: - Read Focused Text Tool

public struct ReadFocusedTextTool: MCPTool {
    public let definition = ToolDefinition(
        name: "read_focused_text",
        description: "读取当前焦点输入框中的文字内容",
        parameters: []
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let bridge = AccessibilityBridge()
        let role = (try? await bridge.getElementRole()) ?? "未知"
        let value = (try? await bridge.getFocusedValue()) ?? ""
        let selected = (try? await bridge.getSelectedText()) ?? ""
        var output = "焦点元素: \(role)"
        if !value.isEmpty { output += "\n内容: \(value)" }
        if !selected.isEmpty { output += "\n选中: \(selected)" }
        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - Press Key Tool

public struct PressKeyTool: MCPTool {
    public let definition = ToolDefinition(
        name: "press_key",
        description: "按下指定按键（支持组合键如 cmd+c, cmd+v, cmd+space, enter, escape 等）",
        parameters: [
            .init(name: "key", type: .string, description: "按键名称，如 return, escape, tab, space, f5 等"),
            .init(name: "modifiers", type: .string, description: "组合键，逗号分隔，如 cmd,shift / ctrl,alt", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let key = arguments["key"]?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: key", isError: true)
        }
        let appBefore = await getFrontAppName()
        try? await Task.sleep(for: .milliseconds(300))

        guard await getFrontAppName() == appBefore else {
            return ToolCallResult(id: UUID().uuidString, output: "前台应用已变更", isError: true)
        }

        let mods = arguments["modifiers"]?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
        let bridge = AccessibilityBridge()
        if await !bridge.checkPermission() {
            AccessibilityPermissionGuide.promptAndOpenSettings()
            return ToolCallResult(id: UUID().uuidString, output: AccessibilityPermissionGuide.message, isError: true)
        }
        do {
            try await bridge.pressKey(key, modifiers: mods)
            let modDesc = mods.isEmpty ? "" : " (modifiers: \(mods.joined(separator: "+")))"
            Task { await AgentEventBus.shared.publish(.desktop(.shortcutPressed(key: key, modifiers: mods.joined(separator: "+")))) }
            return ToolCallResult(id: UUID().uuidString, output: "已按下: \(key)\(modDesc)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "按键失败: \(error.localizedDescription)", isError: true)
        }
    }
}
