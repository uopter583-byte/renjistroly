import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

@main
struct RenJistrolyBridgeApp {
    static func main() async {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            printUsage()
            exit(1)
        }

        let cmd = args[1]
        let accessibility = AccessibilityContextProvider()
        let screen = ScreenContextProvider()
        let executor = ActionExecutor(accessibility: accessibility)
        let observer = ComputerUseObserver(accessibility: accessibility, screen: screen)

        do {
            let result = try await handle(cmd: cmd, args: Array(args.dropFirst(2)), executor: executor, observer: observer, accessibility: accessibility, screen: screen)
            print(result)
            exit(result.contains("\"success\": false") ? 1 : 0)
        } catch {
            print(json(["success": false, "error": error.localizedDescription]))
            exit(1)
        }
    }

    static func handle(
        cmd: String,
        args: [String],
        executor: ActionExecutor,
        observer: ComputerUseObserver,
        accessibility: AccessibilityContextProvider,
        screen: ScreenContextProvider
    ) async throws -> String {
        switch cmd {
        case "click":
            let label = args.joined(separator: " ")
            guard !label.isEmpty else { throw BridgeError.missingArg("label") }
            let action = MacAction(kind: .clickElement, payload: ["label": label], riskLevel: .reversibleInput, humanPreview: "点击「\(label)」")
            let result = await executor.execute(action)
            return result.json

        case "type":
            let text = args.joined(separator: " ")
            guard !text.isEmpty else { throw BridgeError.missingArg("text") }
            let action = MacAction(kind: .insertText, payload: ["text": text], riskLevel: .reversibleInput, humanPreview: "输入文本")
            let result = await executor.execute(action)
            return result.json

        case "observe":
            let obs = await observer.observe(includeOCR: true, skipOwnWindows: true)
            return obs.json

        case "open-app":
            let name = args.joined(separator: " ")
            guard !name.isEmpty else { throw BridgeError.missingArg("name") }
            let action = MacAction(kind: .openApplication, payload: ["name": name], riskLevel: .readOnly, humanPreview: "打开「\(name)」")
            let result = await executor.execute(action)
            return result.json

        case "close-window":
            let action = MacAction(kind: .closeWindow, riskLevel: .reversibleInput, humanPreview: "关闭当前窗口")
            let result = await executor.execute(action)
            return result.json

        case "minimize-window":
            let action = MacAction(kind: .minimizeWindow, riskLevel: .reversibleInput, humanPreview: "最小化当前窗口")
            let result = await executor.execute(action)
            return result.json

        case "read-screen":
            let obs = await observer.observe(includeOCR: true, skipOwnWindows: true)
            return json([
                "success": true,
                "ocrText": obs.ocrText ?? "",
                "frontmostApp": obs.frontmostApp?.appName ?? "",
                "windowTitle": obs.frontmostApp?.windowTitle ?? "",
                "visibleWindowsCount": obs.visibleWindows.count,
            ])

        case "shortcut":
            guard let key = args.first else { throw BridgeError.missingArg("key") }
            let mods = args.dropFirst().joined(separator: "+")
            let action = MacAction(
                kind: .pressShortcut,
                payload: ["key": key, "modifiers": mods],
                riskLevel: .reversibleInput,
                humanPreview: "快捷键 \(mods)+\(key)"
            )
            let result = await executor.execute(action)
            return result.json

        case "open-folder":
            let path = args.joined(separator: " ")
            let resolved = path.isEmpty ? NSHomeDirectory() : path
            let action = MacAction(kind: .openFileOrFolder, payload: ["path": resolved], riskLevel: .readOnly, humanPreview: "打开「\(resolved)」")
            let result = await executor.execute(action)
            return result.json

        case "url":
            let url = args.joined(separator: " ")
            guard !url.isEmpty else { throw BridgeError.missingArg("url") }
            let action = MacAction(kind: .openURL, payload: ["url": url], riskLevel: .readOnly, humanPreview: "打开链接「\(url)」")
            let result = await executor.execute(action)
            return result.json

        case "copy-selected":
            let action = MacAction(kind: .copySelectedText, riskLevel: .readOnly, humanPreview: "复制选中文本")
            let result = await executor.execute(action)
            return result.json

        case "focused-text":
            let action = MacAction(kind: .readFocusedText, riskLevel: .readOnly, humanPreview: "读取焦点文本")
            let result = await executor.execute(action)
            return result.json

        case "scroll":
            let direction = args.first ?? "down"
            let amount = Double(args.dropFirst().first ?? "10") ?? 10
            let action = MacAction(kind: .scroll, payload: ["direction": direction, "amount": "\(amount)"], riskLevel: .readOnly, humanPreview: "滚动 \(direction) \(Int(amount))")
            let result = await executor.execute(action)
            return result.json

        case "drag":
            guard args.count >= 4, let fx = Double(args[0]), let fy = Double(args[1]),
                  let tx = Double(args[2]), let ty = Double(args[3]) else { throw BridgeError.missingArg("from_x from_y to_x to_y") }
            let action = MacAction(kind: .drag, payload: ["from_x": "\(fx)", "from_y": "\(fy)", "to_x": "\(tx)", "to_y": "\(ty)"], riskLevel: .reversibleInput, humanPreview: "拖拽")
            let result = await executor.execute(action)
            return result.json

        case "ui-tree":
            let depth = Int(args.first ?? "5") ?? 5
            let bridge = AccessibilityBridge()
            let elements = try await bridge.getUIElementTree(maxDepth: min(depth, 5))
            let tree = elements.map { node in
                let indent = String(repeating: "  ", count: node.depth)
                let title = node.title.map { " \"\($0)\"" } ?? ""
                return "\(indent)\(node.role)\(title)"
            }.joined(separator: "\n")
            return RenJistrolyBridgeApp.json(["success": true, "tree": tree])

        case "activate-menu":
            let path = args.joined(separator: " ")
            guard !path.isEmpty else { throw BridgeError.missingArg("path") }
            let segments = path.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
            guard !segments.isEmpty else { throw BridgeError.missingArg("path") }
            let bridge = AccessibilityBridge()
            try await bridge.activateMenuItem(path: segments)
            return RenJistrolyBridgeApp.json(["success": true, "message": "已执行菜单: \(path)"])

        case "focus-window":
            let title = args.joined(separator: " ")
            guard !title.isEmpty else { throw BridgeError.missingArg("title") }
            let bridge = AccessibilityBridge()
            try await bridge.focusWindow(title: title)
            return RenJistrolyBridgeApp.json(["success": true, "message": "已聚焦窗口: \(title)"])

        case "list-windows":
            let bridge = AccessibilityBridge()
            let windows = try await bridge.getWindowList()
            return RenJistrolyBridgeApp.json(["success": true, "windows": windows])

        case "click-at":
            guard args.count >= 2, let x = Double(args[0]), let y = Double(args[1]) else { throw BridgeError.missingArg("x y") }
            let action = MacAction(kind: .clickAt, payload: ["x": "\(x)", "y": "\(y)"], riskLevel: .reversibleInput, humanPreview: "点击坐标 (\(x), \(y))")
            let result = await executor.execute(action)
            return result.json

        case "right-click-at":
            guard args.count >= 2, let x = Double(args[0]), let y = Double(args[1]) else { throw BridgeError.missingArg("x y") }
            let action = MacAction(kind: .rightClickAt, payload: ["x": "\(x)", "y": "\(y)"], riskLevel: .reversibleInput, humanPreview: "右键坐标 (\(x), \(y))")
            let result = await executor.execute(action)
            return result.json

        case "double-click-at":
            guard args.count >= 2, let x = Double(args[0]), let y = Double(args[1]) else { throw BridgeError.missingArg("x y") }
            let action = MacAction(kind: .doubleClickAt, payload: ["x": "\(x)", "y": "\(y)"], riskLevel: .reversibleInput, humanPreview: "双击坐标 (\(x), \(y))")
            let result = await executor.execute(action)
            return result.json

        case "help", "--help", "-h":
            return printUsageJSON()

        default:
            throw BridgeError.unknownCommand(cmd)
        }
    }

    static func printUsage() {
        print("""
        renjistroly-bridge <command> [args]

        Commands:
          click <label>           Click UI element by accessibility label
          type <text>             Type text at current focus
          observe                 Get screen context (app, window, OCR, AX tree)
          open-app <name>         Open/activate an application
          close-window            Close the current window
          minimize-window         Minimize the current window
          read-screen             OCR all text on screen
          shortcut <key> [mods]   Press keyboard shortcut (mods: cmd+shift etc.)
          open-folder <path>      Open a folder in Finder
          url <url>               Open a URL in default browser
          copy-selected           Copy selected text to clipboard
          focused-text            Read the currently focused text
          scroll <dir> [amt]      Scroll direction (up/down) with optional amount
          drag <fx> <fy> <tx> <ty>  Drag from (fx,fy) to (tx,ty)
          ui-tree [depth]          Get UI element tree (depth 1-5, default 3)
          activate-menu <path>     Activate menu (e.g. "File/New Window")
          focus-window <title>     Bring window with matching title to front
          list-windows             List all windows of frontmost app
          click-at <x> <y>        Click at screen coordinates
          right-click-at <x> <y>  Right-click at screen coordinates
          double-click-at <x> <y> Double-click at screen coordinates
          help                    Show this help

        Output: JSON on stdout. Exit code 0 on success, 1 on failure.
        """)
    }

    static func printUsageJSON() -> String {
        json([
            "success": true,
            "commands": [
                "click <label>",
                "type <text>",
                "observe",
                "open-app <name>",
                "close-window",
                "minimize-window",
                "read-screen",
                "shortcut <key> [mods]",
                "open-folder <path>",
                "url <url>",
                "copy-selected",
                "focused-text",
                "scroll <direction> [amount]",
                "drag <fx> <fy> <tx> <ty>",
                "ui-tree [depth]",
                "activate-menu <path>",
                "focus-window <title>",
                "list-windows",
                "click-at <x> <y>",
                "right-click-at <x> <y>",
                "double-click-at <x> <y>",
                "help",
            ],
        ])
    }

    static func json(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"success\": false, \"error\": \"json encode failed\"}"
        }
        return str
    }
}

enum BridgeError: Error {
    case unknownCommand(String)
    case missingArg(String)
}
extension BridgeError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unknownCommand(let c): "未知命令：\(c)。运行 renjistroly-bridge help 查看可用命令。"
        case .missingArg(let a): "缺少参数：\(a)。"
        }
    }
}

extension ActionResult {
    var json: String {
        guard let data = try? JSONSerialization.data(withJSONObject: [
            "success": success,
            "message": message,
            "actionID": actionID.uuidString,
        ], options: []),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"success\": false}"
        }
        return str
    }
}

extension ComputerUseObservation {
    var json: String {
        var dict: [String: Any] = [
            "success": true,
            "id": id.uuidString,
            "createdAt": ISO8601DateFormatter().string(from: createdAt),
        ]
        if let app = frontmostApp {
            dict["frontmostApp"] = [
                "name": app.appName,
                "bundleID": app.bundleIdentifier ?? "",
                "windowTitle": app.windowTitle ?? "",
            ]
        }
        if let text = ocrText, !text.isEmpty {
            dict["ocrText"] = text
        }
        dict["visibleWindowsCount"] = visibleWindows.count
        dict["visibleWindows"] = visibleWindows.map { w in
            [
                "owner": w.ownerName,
                "title": w.windowTitle ?? "",
                "layer": w.layer,
            ] as [String: Any]
        }
        if let el = focusedElement {
            dict["focusedElement"] = [
                "role": el.role,
                "title": el.title ?? "",
                "selectedText": el.selectedText ?? "",
            ]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
              let str = String(data: data, encoding: .utf8) else {
            return "{\"success\": false}"
        }
        return str
    }
}
