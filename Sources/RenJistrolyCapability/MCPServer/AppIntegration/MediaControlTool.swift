import Foundation
import AppKit
import RenJistrolyModels

// MARK: - MediaControlTool

public struct MediaControlTool: MCPTool {
    public let definition = ToolDefinition(
        name: "media_control",
        description: "控制媒体播放（播放/暂停/上一首/下一首/音量）",
        parameters: [
            .init(name: "action", type: .string, description: "play, pause, playpause, next, previous, volume_up, volume_down, mute"),
        ]
    )
    public let riskLevel: ToolRiskLevel = .low

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "playpause"
        let keyCode: Int

        switch action {
        case "playpause": keyCode = 49
        case "next": keyCode = 124
        case "previous": keyCode = 123
        case "volume_up": keyCode = 111
        case "volume_down": keyCode = 110
        case "mute": keyCode = 109
        default: keyCode = 49
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(keyCode), keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        let labels: [String: String] = [
            "playpause": "播放/暂停", "next": "下一首", "previous": "上一首",
            "volume_up": "音量+", "volume_down": "音量-", "mute": "静音",
        ]
        Task { await AgentEventBus.shared.publish(.desktop(.mediaControl(action: action))) }
        return ToolCallResult(id: UUID().uuidString, output: "已执行: \(labels[action] ?? action)")
    }
}
