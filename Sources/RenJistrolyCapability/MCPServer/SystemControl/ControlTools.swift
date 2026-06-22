import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - App State Tool

public struct GetAppStateTool: MCPTool {
    public let definition = ToolDefinition(
        name: "get_app_state",
        description: "观察本机当前或指定 Mac 应用，返回窗口、截图和带 element_index 的 AX UI 元素树",
        parameters: [
            .init(name: "app", type: .string, description: "应用名称或 bundle id；为空则观察前台应用", required: false),
            .init(name: "depth", type: .string, description: "AX 遍历深度，默认 5，最高 8", required: false),
            .init(name: "include_screenshot", type: .string, description: "是否包含 PNG base64 截图：true/false，默认 false", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let app = arguments["app"]
        let depth = Int(arguments["depth"] ?? "5") ?? 5
        let includeScreenshot = (arguments["include_screenshot"] ?? "false").lowercased() == "true"
        let bridge = AccessibilityBridge()
        do {
            let state = try await bridge.getAppState(
                app: app,
                maxDepth: min(max(depth, 1), 8),
                includeScreenshot: includeScreenshot
            )
            return ToolCallResult(id: UUID().uuidString, output: state.jsonString(includeScreenshot: includeScreenshot))
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "观察失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - Codex-style Click Tool

public struct ClickTool: MCPTool {
    public let definition = ToolDefinition(
        name: "click",
        description: "点击应用中的 UI 元素。优先使用 get_app_state 返回的 stable_id（跨刷新稳定），次选 element_index，或屏幕坐标",
        parameters: [
            .init(name: "app", type: .string, description: "应用名称或 bundle id；用于校验 UI 快照归属", required: false),
            .init(name: "stable_id", type: .string, description: "get_app_state 返回的稳定 ID，如 axbutton:0.3:ok-button；跨 UI 刷新不变", required: false),
            .init(name: "element_index", type: .string, description: "get_app_state 返回的元素编号，如 e12；刷新后可能变化", required: false),
            .init(name: "x", type: .string, description: "屏幕 X 坐标", required: false),
            .init(name: "y", type: .string, description: "屏幕 Y 坐标", required: false),
            .init(name: "click_count", type: .string, description: "点击次数，默认 1", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let bridge = AccessibilityBridge()
        let clickCount = Int(arguments["click_count"] ?? "1") ?? 1
        let elementID = (arguments["stable_id"].flatMap { $0.isEmpty ? nil : $0 } ?? arguments["element_index"].flatMap { $0.isEmpty ? nil : $0 })
        do {
            if let id = elementID {
                try await bridge.click(elementIndex: id, app: arguments["app"], clickCount: clickCount)
                Task { await AgentEventBus.shared.publish(.desktop(.mouseClicked(x: 0, y: 0, button: id))) }
                return ToolCallResult(id: UUID().uuidString, output: "已点击元素: \(id)")
            }
            guard let xText = arguments["x"], let yText = arguments["y"],
                  let x = Double(xText), let y = Double(yText)
            else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少 stable_id/element_index 或 x/y 坐标", isError: true)
            }
            let success = await CursorNeutralInput.click(
                at: CGPoint(x: x, y: y),
                clickCount: clickCount,
                app: arguments["app"]
            )
            guard success else {
                throw AccessibilityError.actionFailed("cursor-neutral click")
            }
            Task { await AgentEventBus.shared.publish(.desktop(.mouseClicked(x: x, y: y, button: "left"))) }
            return ToolCallResult(id: UUID().uuidString, output: "已点击坐标: (\(x), \(y))")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "点击失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - Set Value Tool

public struct SetValueTool: MCPTool {
    public let definition = ToolDefinition(
        name: "set_value",
        description: "设置 get_app_state 返回的可编辑 UI 元素内容。优先使用 stable_id",
        parameters: [
            .init(name: "app", type: .string, description: "应用名称或 bundle id；用于校验 UI 快照归属", required: false),
            .init(name: "stable_id", type: .string, description: "get_app_state 返回的稳定 ID", required: false),
            .init(name: "element_index", type: .string, description: "元素编号，如 e12；stable_id 不可用时使用", required: false),
            .init(name: "value", type: .string, description: "要设置的文本"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let elementID = (arguments["stable_id"].flatMap { $0.isEmpty ? nil : $0 } ?? arguments["element_index"].flatMap { $0.isEmpty ? nil : $0 })
        guard let id = elementID, let value = arguments["value"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少 stable_id/element_index 或 value", isError: true)
        }
        let bridge = AccessibilityBridge()
        do {
            try await bridge.setValue(elementIndex: id, value: value, app: arguments["app"])
            Task { await AgentEventBus.shared.publish(.desktop(.textTyped(text: value, app: arguments["app"]))) }
            return ToolCallResult(id: UUID().uuidString, output: "已设置元素 \(id)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "设置失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - Click Element Tool

public struct ClickElementTool: MCPTool {
    public let definition = ToolDefinition(
        name: "click_element",
        description: "点击当前应用的 UI 元素（按钮、链接、菜单等），通过角色或文字匹配",
        parameters: [
            .init(name: "title", type: .string, description: "元素的文字/标题（如'确定'、'关闭'）", required: false),
            .init(name: "role", type: .string, description: "元素角色（如 AXButton, AXLink, AXMenuItem）", required: false),
            .init(name: "label", type: .string, description: "辅助功能标签", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let title = arguments["title"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let role = arguments["role"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = arguments["label"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard [title, role, label].contains(where: { !($0 ?? "").isEmpty }) else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少 title/role/label", isError: true)
        }

        let bridge = AccessibilityBridge()
        do {
            try await bridge.clickElement(
                role: role,
                title: title,
                label: label
            )
            let target = title ?? label ?? role ?? "元素"
            Task { await AgentEventBus.shared.publish(.desktop(.mouseClicked(x: 0, y: 0, button: target))) }
            return ToolCallResult(id: UUID().uuidString, output: "已点击: \(target)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "点击失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - Menu Navigation Tool

public struct ActivateMenuTool: MCPTool {
    public let definition = ToolDefinition(
        name: "activate_menu",
        description: "激活菜单栏命令，如 '文件/新建' '编辑/拷贝' '窗口/最小化'",
        parameters: [
            .init(name: "path", type: .string, description: "菜单路径，斜杠分隔，如 'File/New Window' 或 '文件/新建'"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let pathStr = arguments["path"]?.trimmingCharacters(in: .whitespacesAndNewlines), !pathStr.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: path", isError: true)
        }
        let path = pathStr
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !path.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "路径为空", isError: true)
        }
        let bridge = AccessibilityBridge()
        do {
            try await bridge.activateMenuItem(path: path)
            Task { await AgentEventBus.shared.publish(.desktop(.menuActivated(path: pathStr))) }
            return ToolCallResult(id: UUID().uuidString, output: "已执行菜单: \(pathStr)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "菜单失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - Window List Tool

public struct WindowListTool: MCPTool {
    public let definition = ToolDefinition(
        name: "list_windows",
        description: "列出当前前台应用的所有窗口标题",
        parameters: []
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let bridge = AccessibilityBridge()
        do {
            let windows = try await bridge.getWindowList()
            if windows.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: "当前应用无可见窗口")
            }
            let list = windows.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: list)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "获取失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - Focus Window Tool

public struct FocusWindowTool: MCPTool {
    public let definition = ToolDefinition(
        name: "focus_window",
        description: "将指定标题的窗口提到最前",
        parameters: [
            .init(name: "title", type: .string, description: "窗口标题关键词"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let title = arguments["title"]?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: title", isError: true)
        }
        let bridge = AccessibilityBridge()
        do {
            try await bridge.focusWindow(title: title)
            Task { await AgentEventBus.shared.publish(.desktop(.windowFocused(title: title, owner: ""))) }
            return ToolCallResult(id: UUID().uuidString, output: "已聚焦窗口: \(title)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "聚焦失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - Scroll Tool

public struct ScrollTool: MCPTool {
    private let bridge: any AccessibilityScrolling

    public init(bridge: any AccessibilityScrolling = AccessibilityBridge()) {
        self.bridge = bridge
    }

    public let definition = ToolDefinition(
        name: "scroll",
        description: "滚动当前焦点区域。正数向下/右，负数向上/左。delta_y/delta_x 按页滚动。lines 按精确行数滚动。",
        parameters: [
            .init(name: "delta_y", type: .string, description: "垂直滚动量，如 '3' 向下 3 页，'-3' 向上 3 页", required: false),
            .init(name: "delta_x", type: .string, description: "水平滚动量", required: false),
            .init(name: "lines", type: .string, description: "精确行号滚动，如 '15' 向下 15 行，'-10' 向上 10 行。与 delta_y/delta_x 互斥。", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let deltaY = Int(arguments["delta_y"] ?? "0") ?? 0
        let deltaX = Int(arguments["delta_x"] ?? "0") ?? 0
        let lines = Int(arguments["lines"] ?? "0") ?? 0
        do {
            try await bridge.scroll(deltaY: deltaY, deltaX: deltaX, lines: lines)
            let dir = lines != 0 ? (lines > 0 ? "down" : "up") : (deltaY != 0 ? (deltaY > 0 ? "down" : "up") : (deltaX > 0 ? "right" : "left"))
            let amt = lines != 0 ? Double(abs(lines)) : Double(max(abs(deltaY), abs(deltaX)))
            Task { await AgentEventBus.shared.publish(.desktop(.scrolled(direction: dir, amount: amt))) }
            let detail = lines != 0 ? "\(lines) 行" : "y=\(deltaY) x=\(deltaX)"
            return ToolCallResult(id: UUID().uuidString, output: "已滚动 \(detail)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "滚动失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - Drag Tool

public struct DragTool: MCPTool {
    public let definition = ToolDefinition(
        name: "drag",
        description: "从一点拖拽到另一点（可用于拖动文件、选择区域、移动窗口等）",
        parameters: [
            .init(name: "from_x", type: .string, description: "起始 X 坐标"),
            .init(name: "from_y", type: .string, description: "起始 Y 坐标"),
            .init(name: "to_x", type: .string, description: "目标 X 坐标"),
            .init(name: "to_y", type: .string, description: "目标 Y 坐标"),
            .init(name: "app", type: .string, description: "应用名称或 bundle id；为空则投递给前台应用", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let fx = arguments["from_x"], let fy = arguments["from_y"],
              let tx = arguments["to_x"], let ty = arguments["to_y"],
              let fromX = Double(fx), let fromY = Double(fy),
              let toX = Double(tx), let toY = Double(ty)
        else {
            return ToolCallResult(id: UUID().uuidString, output: "坐标参数不完整", isError: true)
        }
        do {
            let success = await CursorNeutralInput.drag(
                from: CGPoint(x: fromX, y: fromY),
                to: CGPoint(x: toX, y: toY),
                app: arguments["app"]
            )
            guard success else {
                throw AccessibilityError.actionFailed("cursor-neutral drag")
            }
            Task { await AgentEventBus.shared.publish(.desktop(.dragStarted(fromX: fromX, fromY: fromY, toX: toX, toY: toY))) }
            return ToolCallResult(id: UUID().uuidString, output: "已拖拽 (\(fromX),\(fromY)) → (\(toX),\(toY))")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "拖拽失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - Get UI Tree Tool

public struct UITreeTool: MCPTool {
    public let definition = ToolDefinition(
        name: "get_ui_tree",
        description: "获取当前前台应用的 UI 元素树，用于了解界面结构和可操作元素",
        parameters: [
            .init(name: "depth", type: .string, description: "遍历深度（1-5），默认 3", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let depth = Int(arguments["depth"] ?? "3") ?? 3
        let bridge = AccessibilityBridge()
        do {
            let tree = try await bridge.getUIElementTree(maxDepth: min(depth, 5))
            let output = tree.map { node in
                let indent = String(repeating: "  ", count: node.depth)
                let title = node.title.map { " \"\($0)\"" } ?? ""
                let desc = node.description.map { " [\($0)]" } ?? ""
                return "\(indent)\(node.role)\(title)\(desc)"
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "无 UI 元素" : output)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "获取失败: \(error.localizedDescription)", isError: true)
        }
    }
}
