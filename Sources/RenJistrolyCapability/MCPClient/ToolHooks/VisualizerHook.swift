import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

/// Hook that provides visual feedback for tool executions.
/// Centralizes the VisualizerCoordinator calls that were previously scattered
/// across individual tool execute() methods.
public struct VisualizerHook: ToolHook {
    public let name = "visualizer"
    public let priority = 50

    public init() {}

    public func onBeforeExecute(tool: String, arguments: [String: String]) async {
        // Screenshot flash before the tool executes
        if tool == "screenshot" || tool == "screenshot_compare" {
            await MainActor.run {
                VisualizerCoordinator.shared.notifyScreenshot()
            }
        }
    }

    public func onAfterExecute(tool: String, arguments: [String: String], result: ToolCallResult) async {
        guard !result.isError else { return }

        switch tool {
        case "click":
            if let xStr = arguments["x"], let yStr = arguments["y"],
               let x = Double(xStr), let y = Double(yStr) {
                await MainActor.run {
                    VisualizerCoordinator.shared.notifyClick(at: CGPoint(x: x, y: y))
                }
            }

        case "click_element":
            await MainActor.run {
                VisualizerCoordinator.shared.notifyClick(at: .zero, label: arguments["label"] ?? arguments["title"])
            }

        case "right_click_at":
            if let xStr = arguments["x"], let yStr = arguments["y"],
               let x = Double(xStr), let y = Double(yStr) {
                await MainActor.run {
                    VisualizerCoordinator.shared.notifyRightClick(at: CGPoint(x: x, y: y))
                }
            }

        case "double_click_at":
            if let xStr = arguments["x"], let yStr = arguments["y"],
               let x = Double(xStr), let y = Double(yStr) {
                await MainActor.run {
                    VisualizerCoordinator.shared.notifyDoubleClick(at: CGPoint(x: x, y: y))
                }
            }

        case "type_text":
            let text = arguments["text"] ?? ""
            await MainActor.run {
                VisualizerCoordinator.shared.notifyType(text: text)
            }

        case "press_key":
            let key = arguments["key"] ?? ""
            let mods = (arguments["modifiers"] ?? "").split(separator: ",").map(String.init)
            await MainActor.run {
                VisualizerCoordinator.shared.notifyHotkey(key: key, modifiers: mods)
            }

        case "scroll":
            let direction = arguments["delta_y"].flatMap { Int($0) }.map { $0 > 0 ? "down" : "up" }
                ?? arguments["delta_x"].flatMap { Int($0) }.map { $0 > 0 ? "right" : "left" }
                ?? arguments["lines"].flatMap { Int($0) }.map { $0 > 0 ? "down" : "up" }
                ?? "down"
            let amount = Double(arguments["delta_y"] ?? arguments["lines"] ?? "1") ?? 1
            await MainActor.run {
                VisualizerCoordinator.shared.notifyScroll(direction: direction, amount: amount)
            }

        case "drag":
            if let fx = arguments["from_x"], let fy = arguments["from_y"],
               let tx = arguments["to_x"], let ty = arguments["to_y"],
               let fromX = Double(fx), let fromY = Double(fy),
               let toX = Double(tx), let toY = Double(ty) {
                await MainActor.run {
                    VisualizerCoordinator.shared.notifyDrag(from: CGPoint(x: fromX, y: fromY),
                                                            to: CGPoint(x: toX, y: toY))
                }
            }

        case "activate_menu":
            let path = arguments["path"] ?? ""
            await MainActor.run {
                VisualizerCoordinator.shared.notifyMenu(path: path)
            }

        default:
            break
        }
    }
}
