import Foundation
import AppKit
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - CopySelectedTool

public struct CopySelectedTool: MCPTool {
    public let definition = ToolDefinition(
        name: "copy_selected",
        description: "复制当前选中的文本到剪贴板（Cmd+C）",
        parameters: []
    )
    public let riskLevel: ToolRiskLevel = .low

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let before = await MainActor.run { NSPasteboard.general.string(forType: .string) }
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdC = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        cmdC?.flags = .maskCommand
        cmdC?.post(tap: .cghidEventTap)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdUp?.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(200))
        let after = await MainActor.run { NSPasteboard.general.string(forType: .string) }
        let changed = after != nil && after != before
        let copiedText = after?.prefix(200) ?? ""
        Task { await AgentEventBus.shared.publish(.desktop(.textCopied(text: String(copiedText)))) }
        return ToolCallResult(
            id: UUID().uuidString,
            output: changed ? "已复制: \(copiedText)" : "已执行 Cmd+C（剪贴板变化: \(changed)）"
        )
    }
}

// MARK: - RightClickAtTool

public struct RightClickAtTool: MCPTool {
    public let definition = ToolDefinition(
        name: "right_click_at",
        description: "右键点击屏幕坐标",
        parameters: [
            .init(name: "x", type: .string, description: "屏幕 X 坐标"),
            .init(name: "y", type: .string, description: "屏幕 Y 坐标"),
            .init(name: "app", type: .string, description: "应用名称或 bundle id；为空则投递给前台应用", required: false),
        ]
    )
    public let riskLevel: ToolRiskLevel = .medium

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let xStr = arguments["x"], let yStr = arguments["y"],
              let x = Double(xStr), let y = Double(yStr) else {
            return ToolCallResult(id: UUID().uuidString, output: "无效坐标", isError: true)
        }
        let point = CGPoint(x: x, y: y)
        guard await CursorNeutralInput.click(at: point, button: .right, app: arguments["app"]) else {
            return ToolCallResult(id: UUID().uuidString, output: "右键点击失败", isError: true)
        }
        Task { await AgentEventBus.shared.publish(.desktop(.rightClicked(x: x, y: y))) }
        return ToolCallResult(id: UUID().uuidString, output: "右键点击: (\(x), \(y))")
    }
}

// MARK: - DoubleClickAtTool

public struct DoubleClickAtTool: MCPTool {
    public let definition = ToolDefinition(
        name: "double_click_at",
        description: "双击屏幕坐标",
        parameters: [
            .init(name: "x", type: .string, description: "屏幕 X 坐标"),
            .init(name: "y", type: .string, description: "屏幕 Y 坐标"),
            .init(name: "app", type: .string, description: "应用名称或 bundle id；为空则投递给前台应用", required: false),
        ]
    )
    public let riskLevel: ToolRiskLevel = .medium

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let xStr = arguments["x"], let yStr = arguments["y"],
              let x = Double(xStr), let y = Double(yStr) else {
            return ToolCallResult(id: UUID().uuidString, output: "无效坐标", isError: true)
        }
        let point = CGPoint(x: x, y: y)
        guard await CursorNeutralInput.click(at: point, clickCount: 2, app: arguments["app"]) else {
            return ToolCallResult(id: UUID().uuidString, output: "双击失败", isError: true)
        }
        Task { await AgentEventBus.shared.publish(.desktop(.doubleClicked(x: x, y: y))) }
        return ToolCallResult(id: UUID().uuidString, output: "双击: (\(x), \(y))")
    }
}
