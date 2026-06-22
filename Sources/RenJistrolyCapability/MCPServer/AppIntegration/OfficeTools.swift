import Foundation
import AppKit
import RenJistrolyModels

// MARK: - OfficePasteTool

public struct OfficePasteTool: MCPTool {
    public let definition = ToolDefinition(
        name: "office_paste",
        description: "粘贴内容到当前焦点应用（模拟 Cmd+V）",
        parameters: [
            .init(name: "text", type: .string, description: "要粘贴的文本（可选，用于替换剪贴板）", required: false),
        ]
    )
    public let riskLevel: ToolRiskLevel = .medium

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        if let text = arguments["text"], !text.isEmpty {
            await MainActor.run {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdV = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        cmdV?.flags = .maskCommand
        cmdV?.post(tap: .cghidEventTap)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdUp?.post(tap: .cghidEventTap)
        Task { await AgentEventBus.shared.publish(.desktop(.officeAction(action: "paste"))) }
        return ToolCallResult(id: UUID().uuidString, output: "已粘贴")
    }
}

// MARK: - OfficeSelectAllTool

public struct OfficeSelectAllTool: MCPTool {
    public let definition = ToolDefinition(
        name: "office_select_all",
        description: "全选当前焦点应用内容（模拟 Cmd+A）",
        parameters: []
    )
    public let riskLevel: ToolRiskLevel = .low

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdA = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: true)
        cmdA?.flags = .maskCommand
        cmdA?.post(tap: .cghidEventTap)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdUp?.post(tap: .cghidEventTap)
        Task { await AgentEventBus.shared.publish(.desktop(.officeAction(action: "selectAll"))) }
        return ToolCallResult(id: UUID().uuidString, output: "已全选")
    }
}

// MARK: - OfficeSaveTool

public struct OfficeSaveTool: MCPTool {
    public let definition = ToolDefinition(
        name: "office_save",
        description: "保存当前文档（模拟 Cmd+S）",
        parameters: []
    )
    public let riskLevel: ToolRiskLevel = .low

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdS = CGEvent(keyboardEventSource: source, virtualKey: 0x01, keyDown: true)
        cmdS?.flags = .maskCommand
        cmdS?.post(tap: .cghidEventTap)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x01, keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdUp?.post(tap: .cghidEventTap)
        Task { await AgentEventBus.shared.publish(.desktop(.officeAction(action: "save"))) }
        return ToolCallResult(id: UUID().uuidString, output: "已保存")
    }
}

// MARK: - OfficeUndoTool

public struct OfficeUndoTool: MCPTool {
    public let definition = ToolDefinition(
        name: "office_undo",
        description: "撤销（模拟 Cmd+Z）",
        parameters: []
    )
    public let riskLevel: ToolRiskLevel = .low

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdZ = CGEvent(keyboardEventSource: source, virtualKey: 0x06, keyDown: true)
        cmdZ?.flags = .maskCommand
        cmdZ?.post(tap: .cghidEventTap)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x06, keyDown: false)
        cmdUp?.flags = .maskCommand
        cmdUp?.post(tap: .cghidEventTap)
        Task { await AgentEventBus.shared.publish(.desktop(.officeAction(action: "undo"))) }
        return ToolCallResult(id: UUID().uuidString, output: "已撤销")
    }
}
