import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - List Menu Items Tool

public struct ListMenuItemsTool: MCPTool {
    public let definition = ToolDefinition(
        name: "list_menu_items",
        description: "列举前台应用的所有菜单项，支持 compact（仅一级菜单）和 full（全部展开）两种模式",
        parameters: [
            .init(name: "mode", type: .string, description: "列举模式: compact（仅一级菜单，默认）或 full（全部展开）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let mode = arguments["mode"] ?? "compact"
        let bridge = AccessibilityBridge()
        do {
            let items = try await bridge.enumerateMenuBar()
            guard !items.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "未检测到菜单栏")
            }

            let output: String
            if mode == "full" {
                output = renderFull(items)
            } else {
                output = items.map { "\($0.title)\($0.enabled ? "" : " (禁用)")" }.joined(separator: "\n")
            }
            return ToolCallResult(id: UUID().uuidString, output: output)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "列举菜单失败: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Render

    private func renderFull(_ items: [MenuItemInfo], indent: Int = 0) -> String {
        var result = ""
        let prefix = String(repeating: "  ", count: indent)
        for item in items {
            let shortcut = item.shortcut.map { "  [\($0)]" } ?? ""
            let disabled = item.enabled ? "" : " (禁用)"
            result += "\(prefix)\(item.title)\(shortcut)\(disabled)\n"
            if let children = item.children, !children.isEmpty {
                result += renderFull(children, indent: indent + 1)
            }
        }
        return result
    }
}
