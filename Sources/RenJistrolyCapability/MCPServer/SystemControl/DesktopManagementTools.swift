import AppKit
import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - Clipboard Monitor (Shared Actor)

/// 监听系统剪贴板变化，维护最近 20 条记录。
public actor ClipboardMonitor {
    public static let shared = ClipboardMonitor()
    private var history: [String] = []
    private var lastChangeCount: Int
    private let maxHistory = 20

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    /// 检查剪贴板是否有新内容，有则加入历史队列。
    @discardableResult
    public func checkForNew() -> String? {
        let pb = NSPasteboard.general
        let currentCount = pb.changeCount
        guard currentCount != lastChangeCount else { return nil }
        lastChangeCount = currentCount
        guard let content = pb.string(forType: .string) else { return nil }
        // 避免重复记录相同的连续内容
        if history.first != content {
            history.insert(content, at: 0)
            if history.count > maxHistory {
                history = Array(history.prefix(maxHistory))
            }
        }
        return content
    }

    /// 返回完整历史，最新在前。
    public func getHistory() -> [String] {
        checkForNew()
        return history
    }

    /// 获取指定索引的历史项（0 = 最新）。
    public func getItem(at index: Int) -> String? {
        let hist = getHistory()
        guard index >= 0, index < hist.count else { return nil }
        return hist[index]
    }

    /// 清空历史。
    public func clear() {
        history = []
    }
}

// MARK: - ClipboardHistoryTool

public struct ClipboardHistoryTool: MCPTool {
    public let definition = ToolDefinition(
        name: "clipboard_history",
        description: "查看或管理剪贴板历史记录。自动监听剪贴板变化，保留最近 20 条记录。",
        parameters: [
            .init(name: "action", type: .string, description: "操作: list(列出历史) / get(获取特定历史项) / clear(清空历史)"),
            .init(name: "index", type: .string, description: "历史项索引（action=get 时需要，0 为最新）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "list"
        let monitor = ClipboardMonitor.shared

        switch action {
        case "list":
            let history = await monitor.getHistory()
            guard !history.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "剪贴板历史为空")
            }
            let lines = history.enumerated().map { i, text in
                let preview = text.count > 120
                    ? String(text.prefix(120)) + "…"
                    : text
                let escaped = preview.replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "\\r")
                return "\(i). \(escaped)"
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "剪贴板历史（共 \(history.count) 条）:\n\(lines)")

        case "get":
            guard let indexStr = arguments["index"], let index = Int(indexStr) else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少或无效的 index 参数", isError: true)
            }
            guard let item = await monitor.getItem(at: index) else {
                let count = await monitor.getHistory().count
                return ToolCallResult(id: UUID().uuidString, output: "索引 \(index) 超出范围（当前共 \(count) 条）", isError: true)
            }
            Task { await AgentEventBus.shared.publish(.desktop(.textCopied(text: item))) }
            return ToolCallResult(id: UUID().uuidString, output: item)

        case "clear":
            await monitor.clear()
            return ToolCallResult(id: UUID().uuidString, output: "剪贴板历史已清空")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)，支持 list / get / clear", isError: true)
        }
    }
}

// MARK: - WindowLayoutTool

public struct WindowLayoutTool: MCPTool {
    public let definition = ToolDefinition(
        name: "window_layout",
        description: "调整窗口布局：左半屏、右半屏、全屏、最大化、居中。通过 AppleScript 控制 System Events 调整窗口位置和大小。",
        parameters: [
            .init(name: "layout", type: .string, description: "布局: left(左半屏) / right(右半屏) / full(全屏) / maximize(最大化) / center(居中)"),
            .init(name: "app", type: .string, description: "应用名称（如 Safari、Xcode），为空则操作当前前台应用", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let layout = arguments["layout"]?.lowercased() else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: layout", isError: true)
        }
        guard ["left", "right", "full", "maximize", "center"].contains(layout) else {
            return ToolCallResult(id: UUID().uuidString, output: "不支持的布局: \(layout)，支持 left/right/full/maximize/center", isError: true)
        }

        let targetApp = arguments["app"]

        let bridge = AppleScriptBridge()

        // 确定目标应用名称
        let appName: String
        if let specified = targetApp, !specified.isEmpty {
            appName = specified
        } else {
            appName = (try? await bridge.getActiveAppName()) ?? ""
        }

        guard !appName.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "无法确定目标应用", isError: true)
        }

        // 获取屏幕可见区域（排除 Dock、菜单栏）
        let screenFrame = await MainActor.run { NSScreen.main?.visibleFrame }
        guard let screen = screenFrame else {
            return ToolCallResult(id: UUID().uuidString, output: "无法获取屏幕信息", isError: true)
        }

        // 计算目标位置和大小
        let newPosition: CGPoint
        let newSize: CGSize

        switch layout {
        case "left":
            newPosition = CGPoint(x: screen.minX, y: screen.minY)
            newSize = CGSize(width: screen.width / 2, height: screen.height)
        case "right":
            newPosition = CGPoint(x: screen.minX + screen.width / 2, y: screen.minY)
            newSize = CGSize(width: screen.width / 2, height: screen.height)
        case "full", "maximize":
            newPosition = CGPoint(x: screen.minX, y: screen.minY)
            newSize = CGSize(width: screen.width, height: screen.height)
        case "center":
            // 居中窗口：保持当前窗口大小，将其居中
            // 使用 60% 屏幕尺寸作为默认窗口大小
            let w = screen.width * 0.6
            let h = screen.height * 0.6
            newPosition = CGPoint(x: screen.minX + (screen.width - w) / 2, y: screen.minY + (screen.height - h) / 2)
            newSize = CGSize(width: w, height: h)
        default:
            // 不会到达这里
            return ToolCallResult(id: UUID().uuidString, output: "未知布局", isError: true)
        }

        // 构建 AppleScript 设置窗口位置和大小
        let x = Int(newPosition.x)
        let y = Int(newPosition.y)
        let w = Int(newSize.width)
        let h = Int(newSize.height)

        let escapedApp = appName.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "System Events"
            tell process "\(escapedApp)"
                try
                    set position of front window to {\(x), \(y)}
                    set size of front window to {\(w), \(h)}
                    return "ok"
                on error errMsg
                    return "error: " & errMsg
                end try
            end tell
        end tell
        """

        do {
            let result = try await bridge.run(script)
            if let errStr = result.stringValue, errStr.hasPrefix("error:") {
                return ToolCallResult(id: UUID().uuidString, output: "布局调整失败 [\(appName)]: \(errStr)", isError: true)
            }
            Task {
                await AgentEventBus.shared.publish(.desktop(.windowFocused(title: nil, owner: appName)))
            }
            return ToolCallResult(id: UUID().uuidString, output: "已将 [\(appName)] 窗口布局设为: \(layout)（位置: {\(x), \(y)}, 大小: {\(w), \(h)}）")
        } catch {
            // 如果 System Events 无法控制该进程，尝试通过激活应用自身来设置 bounds
            let fallbackApplescript = """
            tell application "\(escapedApp)"
                try
                    set bounds of front window to {\(x), \(y), \(x + w), \(y + h)}
                    return "ok"
                on error errMsg
                    return "error: " & errMsg
                end try
            end tell
            """
            do {
                let fallbackResult = try await bridge.run(fallbackApplescript)
                if let errStr = fallbackResult.stringValue, errStr.hasPrefix("error:") {
                    return ToolCallResult(id: UUID().uuidString, output: "布局调整失败 [\(appName)]: \(errStr)", isError: true)
                }
                return ToolCallResult(id: UUID().uuidString, output: "已将 [\(appName)] 窗口布局设为: \(layout)")
            } catch {
                return ToolCallResult(id: UUID().uuidString, output: "布局调整失败 [\(appName)]: \(error.localizedDescription)", isError: true)
            }
        }
    }
}

/// 检查保存路径是否在允许范围内（桌面、下载、文档、用户目录）
func isAllowedSavePath(_ path: String) -> Bool {
    let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    let allowed = [NSHomeDirectory() + "/Desktop", NSHomeDirectory() + "/Downloads", NSHomeDirectory() + "/Documents", NSHomeDirectory()]
    return allowed.contains { resolved == $0 || resolved.hasPrefix($0 + "/") }
}

// MARK: - ScreenshotTool

public struct ScreenshotTool: MCPTool {
    public let definition = ToolDefinition(
        name: "screenshot",
        description: "截取屏幕截图。支持全屏、指定区域或窗口截图，可保存到文件或复制到剪贴板。",
        parameters: [
            .init(name: "action", type: .string, description: "操作: capture(截取并保存到桌面) / clipboard(截取到剪贴板) / save(截取并保存到指定路径)"),
            .init(name: "path", type: .string, description: "保存路径 (action=save 时需要)", required: false),
            .init(name: "region", type: .string, description: "截取区域: full(全屏) / screen(当前屏幕) / window(当前窗口)，默认 full", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "capture"
        let region = arguments["region"] ?? "full"

        guard ["capture", "clipboard", "save"].contains(action) else {
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)，支持 capture / clipboard / save", isError: true)
        }
        guard ["full", "screen", "window"].contains(region) else {
            return ToolCallResult(id: UUID().uuidString, output: "未知区域: \(region)，支持 full / screen / window", isError: true)
        }

        let bridge = ScreenCaptureBridge()

        switch action {
        case "capture":
            // 使用 AppleScript 触发系统截图（Cmd+Shift+3 保存到桌面）
            let applescriptBridge = AppleScriptBridge()
            let regionKey: String
            switch region {
            case "full", "screen": regionKey = "3"
            case "window": regionKey = "4"
            default: regionKey = "3"
            }
            // 注意：先短暂延迟以确保系统准备好
            try? await Task.sleep(for: .milliseconds(300))
            let script = """
            tell application "System Events"
                keystroke "\(regionKey)" using {command down, shift down}
            end tell
            """
            do {
                _ = try await applescriptBridge.run(script)
                // Wait briefly for screenshot to save
                try? await Task.sleep(for: .milliseconds(500))
                Task { await AgentEventBus.shared.publish(.desktop(.screenCaptured(ocrCharCount: 0, windowCount: 0))) }
                            return ToolCallResult(id: UUID().uuidString, output: "已截取屏幕截图并保存到桌面（区域: \(region)）")
            } catch {
                // Fall back to programmatic capture via ScreenCaptureBridge
                let data = try await bridge.captureScreen()
                let desktopPath = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Desktop")
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd-HHmmss"
                let filename = "Screenshot_\(formatter.string(from: Date())).png"
                let fileURL = desktopPath.appendingPathComponent(filename)
                try data.write(to: fileURL)
                Task { await AgentEventBus.shared.publish(.desktop(.screenCaptured(ocrCharCount: 0, windowCount: 0))) }
                            return ToolCallResult(id: UUID().uuidString, output: "已截取屏幕截图并保存到: \(fileURL.path)")
            }

        case "clipboard":
            // 使用程序化截图并复制到剪贴板
            let data = try await bridge.captureScreen()
            await MainActor.run {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setData(data, forType: .png)
            }
            Task { await AgentEventBus.shared.publish(.desktop(.screenCaptured(ocrCharCount: 0, windowCount: 0))) }
                        return ToolCallResult(id: UUID().uuidString, output: "已截取屏幕截图并复制到剪贴板（区域: \(region)，大小: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))）")

        case "save":
            let savePath: String
            if let customPath = arguments["path"], !customPath.isEmpty {
                savePath = (customPath as NSString).expandingTildeInPath
            } else {
                // 默认保存到桌面
                let desktop = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Desktop")
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd-HHmmss"
                let filename = "Screenshot_\(formatter.string(from: Date())).png"
                savePath = desktop.appendingPathComponent(filename).path
            }

            let fileURL = URL(fileURLWithPath: savePath)

            guard isAllowedSavePath(savePath) else {
                return ToolCallResult(id: UUID().uuidString, output: "不允许的保存路径: \(savePath)", isError: true)
            }

            let parentDir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

            let data = try await bridge.captureScreen()
            try data.write(to: fileURL)

            Task { await AgentEventBus.shared.publish(.desktop(.screenCaptured(ocrCharCount: 0, windowCount: 0))) }
                        return ToolCallResult(id: UUID().uuidString, output: "已截取屏幕截图并保存到: \(savePath)（大小: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))）")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}
