import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - BrowserNavigateTool

public struct BrowserNavigateTool: MCPTool {
    public let definition = ToolDefinition(
        name: "browser_navigate",
        description: "在浏览器中导航（前进/后退/刷新）",
        parameters: [
            .init(name: "action", type: .string, description: "back, forward, or reload"),
            .init(name: "browser", type: .string, description: "Safari 或 Chrome", required: false),
        ]
    )
    public let riskLevel: ToolRiskLevel = .low

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "reload"
        let browser = arguments["browser"] ?? "Safari"
        let script: String
        if browser.localizedCaseInsensitiveContains("chrome") {
            script = """
            tell application "Google Chrome"
                tell active tab of front window
                    execute javascript "history.\(action)()"
                end tell
            end tell
            """
        } else {
            let key = action == "reload" ? "r" : (action == "back" ? "[" : "]")
            script = """
            tell application "System Events"
                tell process "\(browser)"
                    keystroke "\(key)" using command down
                end tell
            end tell
            """
        }
        let bridge = AppleScriptBridge()
        let result = try await bridge.run(script)
        Task { await AgentEventBus.shared.publish(.browser(.browserAction(action: action, browser: browser))) }
        return ToolCallResult(id: UUID().uuidString, output: result.stringValue ?? "浏览器已执行 \(action)")
    }
}
