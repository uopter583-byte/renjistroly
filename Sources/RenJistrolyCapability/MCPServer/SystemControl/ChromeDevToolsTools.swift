import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

/// Shared manager for the CDP session. Actor ensures thread-safe access.
public actor CDPSessionManager {
    public static let shared = CDPSessionManager()
    private var session: ChromeDevToolsSession?

    private init() {}

    public func getSession() -> ChromeDevToolsSession? { session }
    public func setSession(_ s: ChromeDevToolsSession) { session = s }
    public func clearSession() { session?.disconnect(); session = nil }

    /// Ensure Chrome is running with debug port and connect to first page.
    public func ensureConnected(port: Int = 9222) async throws -> ChromeDevToolsSession {
        if let existing = session, existing.isConnected { return existing }
        let _ = try await ChromeDevToolsSession.ensureChrome(port: port)
        let s = ChromeDevToolsSession()
        try await s.connectToAny(port: port)
        session = s
        return s
    }
}

// MARK: - CDP Connect Tool

public struct CDPConnectTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_connect",
        description: "连接 Chrome DevTools Protocol 调试端口。启动/连接 Chrome 的远程调试端口，可用于后续的 JS 求值、截图、Cookie 管理等操作",
        parameters: [
            .init(name: "port", type: .string, description: "调试端口号，默认 9222", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let port = arguments["port"].flatMap { Int($0) } ?? 9222
        do {
            let session = try await CDPSessionManager.shared.ensureConnected(port: port)
            return ToolCallResult(id: UUID().uuidString, output: "已连接 CDP (端口 \(port)), 连接状态: \(session.isConnected)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 连接失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Disconnect Tool

public struct CDPDisconnectTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_disconnect",
        description: "断开 Chrome DevTools Protocol 连接",
        parameters: []
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        await CDPSessionManager.shared.clearSession()
        return ToolCallResult(id: UUID().uuidString, output: "CDP 连接已断开")
    }
}

// MARK: - CDP Evaluate Tool

public struct CDPEvaluateTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_evaluate",
        description: "在 Chrome 页面中执行 JavaScript (Runtime.evaluate)，返回执行结果的 JSON",
        parameters: [
            .init(name: "expression", type: .string, description: "要执行的 JavaScript 表达式"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let expr = arguments["expression"], !expr.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: expression", isError: true)
        }
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.evaluate(expression: expr)
            return ToolCallResult(id: UUID().uuidString, output: result)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP evaluate 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Navigate Tool

public struct CDPNavigateTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_navigate",
        description: "导航 Chrome 当前标签页到指定 URL (Page.navigate)",
        parameters: [
            .init(name: "url", type: .string, description: "要跳转的 URL"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let url = arguments["url"], !url.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: url", isError: true)
        }
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.navigate(url: url)
            return ToolCallResult(id: UUID().uuidString, output: result)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP navigate 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Screenshot Tool

public struct CDPCaptureScreenshotTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_capture_screenshot",
        description: "截取 Chrome 当前标签页截图 (Page.captureScreenshot)，返回包含 base64 图片数据的 JSON",
        parameters: [
            .init(name: "format", type: .string, description: "图片格式: png/jpeg，默认 png", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let format = arguments["format"] ?? "png"
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.captureScreenshot(format: format)
            return ToolCallResult(id: UUID().uuidString, output: result)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 截图失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Get Cookies Tool

public struct CDPGetCookiesTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_get_cookies",
        description: "获取 Chrome 当前页面的所有 Cookie (Network.getCookies)，返回包含 cookies 数组的 JSON",
        parameters: []
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.getCookies()
            return ToolCallResult(id: UUID().uuidString, output: result)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP getCookies 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Set Cookie Tool

public struct CDPSetCookieTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_set_cookie",
        description: "设置 Chrome 浏览器 Cookie (Network.setCookie)",
        parameters: [
            .init(name: "name", type: .string, description: "Cookie 名称"),
            .init(name: "value", type: .string, description: "Cookie 值"),
            .init(name: "domain", type: .string, description: "Cookie 域名（可选）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let name = arguments["name"], !name.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: name", isError: true)
        }
        guard let value = arguments["value"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: value", isError: true)
        }
        let domain = arguments["domain"]
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.setCookie(name: name, value: value, domain: domain)
            return ToolCallResult(id: UUID().uuidString, output: result)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP setCookie 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Block URLs Tool

public struct CDPBlockURLsTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_block_urls",
        description: "屏蔽符合指定 URL 模式的网络请求 (Network.setBlockedURLs)。支持通配符如 *://*.example.com/*",
        parameters: [
            .init(name: "patterns", type: .string, description: "JSON 字符串数组: [\"*://*.example.com/*\", \"*://*.google-analytics.com/*\"]"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let jsonStr = arguments["patterns"], !jsonStr.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: patterns", isError: true)
        }
        guard let data = jsonStr.data(using: .utf8),
              let patterns = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return ToolCallResult(id: UUID().uuidString, output: "patterns 需为 JSON 字符串数组", isError: true)
        }
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.blockURLs(patterns: patterns)
            return ToolCallResult(id: UUID().uuidString, output: "已屏蔽 \(patterns.count) 个 URL 模式\n\(result)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP blockURLs 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Enable Network Tool

public struct CDPEnableNetworkTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_enable_network",
        description: "启用 Chrome 网络事件捕获 (Network.enable)，配合 cdp_status 可查看网络请求",
        parameters: []
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.enableNetwork()
            return ToolCallResult(id: UUID().uuidString, output: "网络捕获已启用\n\(result)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP enableNetwork 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Enable Console Tool

public struct CDPEnableConsoleTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_enable_console",
        description: "启用 Chrome 控制台消息捕获 (Console.enable)，之后页面 console.log/warn/error 将被捕获",
        parameters: []
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.enableConsole()
            return ToolCallResult(id: UUID().uuidString, output: "控制台捕获已启用\n\(result)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP enableConsole 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Status Tool

public struct CDPStatusTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_status",
        description: "查看 Chrome CDP 连接状态",
        parameters: []
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let session = await CDPSessionManager.shared.getSession()
        guard let session, session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接。使用 cdp_connect 连接")
        }
        return ToolCallResult(id: UUID().uuidString, output: "CDP 已连接 ✅")
    }
}

// MARK: - CDP Get Document Tool

public struct CDPGetDocumentTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_get_document",
        description: "获取 Chrome 当前页面的 DOM 树结构 (DOM.getDocument)",
        parameters: [
            .init(name: "depth", type: .string, description: "DOM 树深度，默认 2", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let depth = arguments["depth"].flatMap { Int($0) } ?? 2
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.getDocument(depth: depth)
            return ToolCallResult(id: UUID().uuidString, output: result)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP getDocument 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Query Selector Tool

public struct CDPQuerySelectorTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_query_selector",
        description: "在 Chrome 页面中通过 CSS 选择器查询 DOM 节点 (DOM.querySelector)",
        parameters: [
            .init(name: "selector", type: .string, description: "CSS 选择器"),
            .init(name: "nodeId", type: .string, description: "可选的起始节点 ID，默认从文档根开始", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let selector = arguments["selector"], !selector.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: selector", isError: true)
        }
        let nodeId = arguments["nodeId"].flatMap { Int($0) } ?? 1
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.querySelector(selector: selector, nodeId: nodeId)
            return ToolCallResult(id: UUID().uuidString, output: result)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP querySelector 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Query Selector All Tool

public struct CDPQuerySelectorAllTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_query_selector_all",
        description: "通过 CSS 选择器查询 Chrome 页面中所有匹配的 DOM 节点 (DOM.querySelectorAll)",
        parameters: [
            .init(name: "selector", type: .string, description: "CSS 选择器"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let selector = arguments["selector"], !selector.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: selector", isError: true)
        }
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.querySelectorAll(selector: selector)
            return ToolCallResult(id: UUID().uuidString, output: result)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP querySelectorAll 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Click Tool

public struct CDPClickTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_click",
        description: "通过 CDP Input.dispatchMouseEvent 模拟真实鼠标点击 Chrome 页面中的元素（通过 CSS 选择器定位），支持真实点击而非 JS click()",
        parameters: [
            .init(name: "selector", type: .string, description: "CSS 选择器"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let selector = arguments["selector"], !selector.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: selector", isError: true)
        }
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.dispatchMouseClick(selector: selector)
            return ToolCallResult(id: UUID().uuidString, output: "CDP 点击成功: \(selector)\n\(result)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 点击失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Fill Tool

public struct CDPFillTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_fill",
        description: "通过 CDP Runtime.evaluate 填充 Chrome 页面中的表单字段",
        parameters: [
            .init(name: "selector", type: .string, description: "CSS 选择器"),
            .init(name: "value", type: .string, description: "要填充的值"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let selector = arguments["selector"], !selector.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: selector", isError: true)
        }
        guard let value = arguments["value"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: value", isError: true)
        }
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
            let result = try await session.evaluate(expression: """
            (function() {
                var el = document.querySelector('\(selector)');
                if (!el) return 'not_found';
                var tag = el.tagName.toLowerCase();
                if (tag === 'input' || tag === 'textarea') {
                    el.value = '\(escaped)';
                    el.dispatchEvent(new Event('input', {bubbles:true}));
                    el.dispatchEvent(new Event('change', {bubbles:true}));
                    return 'filled';
                }
                if (el.isContentEditable) {
                    el.textContent = '\(escaped)';
                    return 'filled';
                }
                return 'not_fillable';
            })()
            """)
            let successMarker = ChromeDevToolsSession.extractString(from: result, keyPath: "result", "value")
            let success = successMarker == "filled"
            if success {
                return ToolCallResult(id: UUID().uuidString, output: "已填充: \(selector)")
            }
            return ToolCallResult(id: UUID().uuidString, output: "填充结果: \(successMarker ?? result)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 填充失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Submit Tool

public struct CDPSubmitTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_submit",
        description: "通过 CDP Runtime.evaluate 提交 Chrome 页面中的表单",
        parameters: [
            .init(name: "selector", type: .string, description: "表单或表单内元素的 CSS 选择器"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let selector = arguments["selector"], !selector.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: selector", isError: true)
        }
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.evaluate(expression: """
            (function() {
                var el = document.querySelector('\(selector)');
                if (!el) return 'not_found';
                if (el.tagName.toLowerCase() === 'form') { el.submit(); return 'submitted'; }
                var form = el.closest('form');
                if (form) { form.submit(); return 'submitted'; }
                return 'no_form';
            })()
            """)
            let status = ChromeDevToolsSession.extractString(from: result, keyPath: "result", "value") ?? result
            let success = status == "submitted"
            return ToolCallResult(id: UUID().uuidString, output: success ? "已提交: \(selector)" : "提交失败: \(status)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 提交失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Get Outer HTML Tool

public struct CDPGetOuterHTMLTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_get_outer_html",
        description: "获取 Chrome 页面中指定 DOM 节点的 outerHTML (DOM.getOuterHTML)",
        parameters: [
            .init(name: "nodeId", type: .string, description: "DOM 节点 ID"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let nodeIdStr = arguments["nodeId"], let nodeId = Int(nodeIdStr) else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少或无效参数: nodeId", isError: true)
        }
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.getOuterHTML(nodeId: nodeId)
            return ToolCallResult(id: UUID().uuidString, output: result)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP getOuterHTML 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Get Attributes Tool

public struct CDPGetAttributesTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_get_attributes",
        description: "获取 Chrome 页面中指定 DOM 节点的属性列表 (DOM.getAttributes)",
        parameters: [
            .init(name: "nodeId", type: .string, description: "DOM 节点 ID"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let nodeIdStr = arguments["nodeId"], let nodeId = Int(nodeIdStr) else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少或无效参数: nodeId", isError: true)
        }
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.getAttributes(nodeId: nodeId)
            return ToolCallResult(id: UUID().uuidString, output: result)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP getAttributes 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Get Performance Tool

public struct CDPGetPerformanceTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_get_performance",
        description: "获取 Chrome 页面性能指标 (Performance.getMetrics)",
        parameters: []
    )
    public var riskLevel: ToolRiskLevel { .low }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.getPerformanceMetrics()
            return ToolCallResult(id: UUID().uuidString, output: result)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP getPerformance 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Reload Tool

public struct CDPReloadTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_reload",
        description: "刷新 Chrome 当前页面 (Page.reload)",
        parameters: [
            .init(name: "ignore_cache", type: .string, description: "是否忽略缓存: true/false，默认 false", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let ignoreCache = arguments["ignore_cache"]?.lowercased() == "true"
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.reload(ignoreCache: ignoreCache)
            return ToolCallResult(id: UUID().uuidString, output: "页面已刷新\n\(result)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP reload 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP List Tabs Tool

public struct CDPListTabsTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_list_tabs",
        description: "列出 Chrome 中所有页面标签页 (Target.getTargets)",
        parameters: []
    )
    public var riskLevel: ToolRiskLevel { .low }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.getTargets()
            return ToolCallResult(id: UUID().uuidString, output: result)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP listTabs 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP New Tab Tool

public struct CDPNewTabTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_new_tab",
        description: "在 Chrome 中新建标签页 (Target.createTarget)",
        parameters: [
            .init(name: "url", type: .string, description: "标签页初始 URL，默认 about:blank", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let url = arguments["url"] ?? "about:blank"
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.createTarget(url: url)
            return ToolCallResult(id: UUID().uuidString, output: "新建标签页成功\n\(result)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP newTab 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Close Tab Tool

public struct CDPCloseTabTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_close_tab",
        description: "关闭 Chrome 中的指定标签页 (Target.closeTarget)",
        parameters: [
            .init(name: "targetId", type: .string, description: "要关闭的标签页 targetId"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let targetId = arguments["targetId"], !targetId.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: targetId", isError: true)
        }
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.closeTarget(targetId: targetId)
            return ToolCallResult(id: UUID().uuidString, output: "标签页已关闭\n\(result)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP closeTab 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Activate Tab Tool

public struct CDPActivateTabTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_activate_tab",
        description: "激活/切换到 Chrome 中的指定标签页 (Target.activateTarget)",
        parameters: [
            .init(name: "targetId", type: .string, description: "要激活的标签页 targetId"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let targetId = arguments["targetId"], !targetId.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: targetId", isError: true)
        }
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.activateTarget(targetId: targetId)
            return ToolCallResult(id: UUID().uuidString, output: "已切换标签页\n\(result)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP activateTab 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Print to PDF Tool

public struct CDPPrintToPDFTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_print_to_pdf",
        description: "将 Chrome 当前页面导出为 PDF (Page.printToPDF)，返回包含 base64 编码 PDF 数据的 JSON",
        parameters: []
    )
    public var riskLevel: ToolRiskLevel { .low }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        do {
            let result = try await session.printToPDF()
            return ToolCallResult(id: UUID().uuidString, output: result)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "CDP printToPDF 失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - CDP Get Network Entries Tool

public struct CDPGetNetworkEntriesTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_get_network_entries",
        description: "获取 Chrome 页面最近的网络请求记录。需要先使用 cdp_enable_network 启用网络捕获，然后页面发起的请求会被自动记录",
        parameters: [
            .init(name: "clear", type: .string, description: "读取后是否清除记录: true/false，默认 true", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        let clear = arguments["clear"]?.lowercased() != "false"
        let entries = session.readNetworkEntries(clear: clear)
        guard !entries.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "暂无网络请求记录。先调用 cdp_enable_network，然后导航或操作页面")
        }
        var lines = ["网络请求记录 (\(entries.count) 条):"]
        for (i, entry) in entries.enumerated() {
            let status = entry.error ?? (entry.statusCode > 0 ? "\(entry.statusCode)" : "pending")
            lines.append("  \(i+1). [\(status)] \(entry.method) \(entry.url)")
        }
        return ToolCallResult(id: UUID().uuidString, output: lines.joined(separator: "\n"))
    }
}

// MARK: - CDP Get Console Messages Tool

public struct CDPGetConsoleMessagesTool: MCPTool {
    public let definition = ToolDefinition(
        name: "cdp_get_console_messages",
        description: "获取 Chrome 页面控制台消息。需要先使用 cdp_enable_console 启用控制台捕获，之后页面的 console.log/warn/error 会被自动记录",
        parameters: [
            .init(name: "clear", type: .string, description: "读取后是否清除记录: true/false，默认 true", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let session = await CDPSessionManager.shared.getSession(), session.isConnected else {
            return ToolCallResult(id: UUID().uuidString, output: "CDP 未连接，请先使用 cdp_connect", isError: true)
        }
        let clear = arguments["clear"]?.lowercased() != "false"
        let messages = session.readConsoleMessages(clear: clear)
        guard !messages.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "暂无控制台消息。先调用 cdp_enable_console，然后导航或操作页面")
        }
        var lines = ["控制台消息 (\(messages.count) 条):"]
        for (i, msg) in messages.enumerated() {
            let icon: String
            switch msg.level {
            case "error": icon = "❌"
            case "warning": icon = "⚠️"
            case "info": icon = "ℹ️"
            default: icon = "📋"
            }
            lines.append("  \(i+1). \(icon) [\(msg.level)] \(msg.text)")
        }
        return ToolCallResult(id: UUID().uuidString, output: lines.joined(separator: "\n"))
    }
}
