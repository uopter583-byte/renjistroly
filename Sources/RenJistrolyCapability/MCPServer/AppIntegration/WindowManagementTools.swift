import Foundation
import AppKit
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - CloseWindowTool

public struct CloseWindowTool: MCPTool {
    public let definition = ToolDefinition(
        name: "close_window",
        description: "关闭当前前台窗口",
        parameters: []
    )
    public let riskLevel: ToolRiskLevel = .medium

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let app = await MainActor.run { NSWorkspace.shared.frontmostApplication }
        guard let app else {
            return ToolCallResult(id: UUID().uuidString, output: "无法获取前台应用", isError: true)
        }
        let appName = app.localizedName ?? "未知"
        let script = """
        tell application "System Events"
            tell process "\(appName)"
                keystroke "w" using command down
            end tell
        end tell
        """
        let bridge = AppleScriptBridge()
        let result = try await bridge.run(script)
        Task { await AgentEventBus.shared.publish(.desktop(.windowClosed(app: appName))) }
        return ToolCallResult(id: UUID().uuidString, output: result.stringValue ?? "窗口已关闭")
    }
}

// MARK: - MinimizeWindowTool

public struct MinimizeWindowTool: MCPTool {
    public let definition = ToolDefinition(
        name: "minimize_window",
        description: "最小化当前前台窗口",
        parameters: []
    )
    public let riskLevel: ToolRiskLevel = .medium

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let app = await MainActor.run { NSWorkspace.shared.frontmostApplication }
        guard let app else {
            return ToolCallResult(id: UUID().uuidString, output: "无法获取前台应用", isError: true)
        }
        let appName = app.localizedName ?? "未知"
        let script = """
        tell application "System Events"
            tell process "\(appName)"
                keystroke "m" using command down
            end tell
        end tell
        """
        let bridge = AppleScriptBridge()
        let result = try await bridge.run(script)
        Task { await AgentEventBus.shared.publish(.desktop(.windowMinimized(app: appName))) }
        return ToolCallResult(id: UUID().uuidString, output: result.stringValue ?? "窗口已最小化")
    }
}

// MARK: - OpenFolderTool

public struct OpenFolderTool: MCPTool {
    public let definition = ToolDefinition(
        name: "open_folder",
        description: "在 Finder 中打开文件夹",
        parameters: [
            .init(name: "path", type: .string, description: "文件夹路径"),
        ]
    )
    public let riskLevel: ToolRiskLevel = .low

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let path = arguments["path"], !path.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: path", isError: true)
        }
        _ = await MainActor.run { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
        Task { await AgentEventBus.shared.publish(.desktop(.folderOpened(path: path))) }
        return ToolCallResult(id: UUID().uuidString, output: "已在 Finder 中打开: \(path)")
    }
}
