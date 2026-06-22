import AppKit
import Foundation
import RenJistrolyModels

/// Chrome automation driver using CDP (Chrome DevTools Protocol) WebSocket
/// instead of AppleScript. Provides real browser-level input simulation,
/// DOM inspection, network/console monitoring, and tab management.
///
/// Thread safety: actor-bound mutable state.
public actor CDPChromeDriver {
    private var session: ChromeDevToolsSession?
    private var connectedPort: Int = 9222
    private var connectedTargetId: String?

    public init() {}

    // MARK: - Connection

    /// Ensure Chrome is running with remote debugging and connect to the first page target.
    public func ensureConnected(port: Int = 9222) async throws {
        if session?.isConnected == true { return }
        let _ = try await ChromeDevToolsSession.ensureChrome(port: port)
        let s = ChromeDevToolsSession()
        s.registerDefaultEventHandlers()
        try await s.connectToAny(port: port)
        // Enable useful domains by default
        _ = try? await s.enableNetwork()
        _ = try? await s.enableConsole()
        _ = try? await s.enablePerformance()
        session = s
        connectedPort = port
        await AgentEventBus.shared.publish(.browser(.pageLoaded(url: "connected", title: "Chrome CDP connected")))
    }

    /// Connect to a specific target (tab) by WebSocket URL.
    public func connect(targetId: String) async throws {
        guard let s = session else {
            // Need to establish initial connection first, then switch
            try await ensureConnected()
            return
        }
        let wsURL = try await s.getWebSocketURL(targetId: targetId)
        let newSession = ChromeDevToolsSession()
        newSession.registerDefaultEventHandlers()
        try await newSession.connect(to: wsURL)
        _ = try? await newSession.enableNetwork()
        _ = try? await newSession.enableConsole()
        _ = try? await newSession.enablePerformance()
        session?.disconnect()
        session = newSession
        connectedTargetId = targetId
    }

    public func disconnect() {
        session?.disconnect()
        session = nil
        connectedTargetId = nil
    }

    public var isConnected: Bool { session?.isConnected ?? false }

    // MARK: - Page State

    /// Get current page state (title, URL, etc.)
    public func currentPageState() async throws -> BrowserPageState {
        guard let s = session else {
            throw CDPError.connectionFailed("not connected")
        }
        let titleRaw = try await s.evaluate(expression: "document.title")
        let title = Self.extractValue(from: titleRaw, key: "result.value") as? String
        let urlRaw = try await s.evaluate(expression: "window.location.href")
        let url = Self.extractValue(from: urlRaw, key: "result.value") as? String
        let windowTitleRaw = try await s.evaluate(expression: "window.document.title")
        let windowTitle = Self.extractValue(from: windowTitleRaw, key: "result.value") as? String

        return BrowserPageState(
            browserName: "Google Chrome (CDP)",
            windowTitle: windowTitle,
            tabTitle: title,
            url: url,
            host: url.flatMap { URL(string: $0)?.host?.replacingOccurrences(of: "www.", with: "") },
            searchQuery: url.flatMap { extractSearchQuery(from: $0) }
        )
    }

    // MARK: - JavaScript Execution

    /// Execute JavaScript in the page context and return the stringified result value.
    @discardableResult
    public func executeJavaScript(_ js: String) async throws -> String {
        guard let s = session else {
            throw CDPError.connectionFailed("not connected")
        }
        let raw = try await s.evaluate(expression: js)
        // Try to extract the value
        if let val = Self.extractValue(from: raw, key: "result.value") {
            if let str = val as? String { return str }
            if let num = val as? NSNumber { return num.stringValue }
            if let dict = val as? [String: Any] {
                if let data = try? JSONSerialization.data(withJSONObject: dict, options: .fragmentsAllowed) {
                    return String(data: data, encoding: .utf8) ?? "\(dict)"
                }
            }
            if let arr = val as? [Any] {
                if let data = try? JSONSerialization.data(withJSONObject: arr) {
                    return String(data: data, encoding: .utf8) ?? "\(arr)"
                }
            }
            return "\(val)"
        }
        // Check for error
        if let exc = Self.extractValue(from: raw, key: "exceptionDetails") {
            let text = Self.extractValue(from: raw, key: "result.description") as? String ?? "\(exc)"
            return "JS Error: \(text)"
        }
        return raw
    }

    // MARK: - DOM Query

    /// Get a single DOM element by CSS selector, with its bounding rect.
    public func getDOMElement(selector: String) async throws -> BrowserDOMElement? {
        guard let s = session else {
            throw CDPError.connectionFailed("not connected")
        }
        let js = """
        (function() {
            var el = document.querySelector('\(selector)');
            if (!el) return '';
            var rect = el.getBoundingClientRect();
            return JSON.stringify({
                tag: el.tagName.toLowerCase(),
                text: (el.textContent || '').trim().substring(0, 200),
                value: el.value || '',
                href: el.href || '',
                visible: rect.width > 0 && rect.height > 0,
                rect: { x: rect.x, y: rect.y, w: rect.width, h: rect.height }
            });
        })()
        """
        let raw = try await s.evaluate(expression: js)
        guard let val = Self.extractValue(from: raw, key: "result.value") as? String,
              !val.isEmpty,
              let data = val.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(BrowserDOMElement.self, from: data)
    }

    /// Query all DOM elements matching a CSS selector.
    public func queryDOMAll(selector: String) async throws -> [BrowserDOMElement] {
        guard let s = session else {
            throw CDPError.connectionFailed("not connected")
        }
        let js = """
        (function() {
            var els = document.querySelectorAll('\(selector)');
            return JSON.stringify(Array.from(els).map(function(el) {
                var rect = el.getBoundingClientRect();
                return {
                    tag: el.tagName.toLowerCase(),
                    text: (el.textContent || '').trim().substring(0, 100),
                    value: el.value || '',
                    href: el.href || '',
                    visible: rect.width > 0 && rect.height > 0,
                    rect: { x: rect.x, y: rect.y, w: rect.width, h: rect.height }
                };
            }));
        })()
        """
        let raw = try await s.evaluate(expression: js)
        guard let val = Self.extractValue(from: raw, key: "result.value") as? String,
              let data = val.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([BrowserDOMElement].self, from: data)) ?? []
    }

    // MARK: - Click (real CDP Input.mouse)

    /// Click an element by CSS selector using real CDP Input.dispatchMouseEvent.
    @discardableResult
    public func clickElement(selector: String) async throws -> Bool {
        guard let s = session else {
            throw CDPError.connectionFailed("not connected")
        }
        do {
            // Get element bounding box via DOM.getBoxModel
            let queryRaw = try await s.querySelector(selector: selector)
            guard let nodeId = Self.extractValue(from: queryRaw, key: "result.nodeId") as? Int else {
                // Fallback: use JS-based click
                let result = try await executeJavaScript("""
                (function() {
                    var el = document.querySelector('\(selector)');
                    if (!el) return 'not_found';
                    el.click();
                    return 'clicked';
                })()
                """)
                let success = result == "clicked"
                await AgentEventBus.shared.publish(.browser(.domClicked(selector: selector, success: success)))
                return success
            }
            let boxRaw = try await s.send(method: "DOM.getBoxModel",
                                          paramsJSON: "{\"nodeId\":\(nodeId),\"track\":false}")
            // Parse content from box model
            guard let content = Self.extractValue(from: boxRaw, key: "result.model.content") as? [Double],
                  content.count >= 4 else {
                await AgentEventBus.shared.publish(.browser(.domClicked(selector: selector, success: false)))
                return false
            }
            let cx = Int((content[0] + content[2]) / 2.0)
            let cy = Int((content[1] + content[3]) / 2.0)
            _ = try await s.dispatchMouseClick(x: cx, y: cy)
            await AgentEventBus.shared.publish(.browser(.domClicked(selector: selector, success: true)))
            return true
        } catch {
            await AgentEventBus.shared.publish(.browser(.domClicked(selector: selector, success: false)))
            return false
        }
    }

    // MARK: - Fill

    /// Fill a form field by CSS selector.
    @discardableResult
    public func fillElement(selector: String, value: String) async throws -> Bool {
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let result = try await executeJavaScript("""
        (function() {
            var el = document.querySelector('\(selector)');
            if (!el) return 'not_found';
            var tag = el.tagName.toLowerCase();
            if (tag === 'input' || tag === 'textarea') {
                el.focus();
                el.value = '\(escaped)';
                el.dispatchEvent(new Event('input', {bubbles: true}));
                el.dispatchEvent(new Event('change', {bubbles: true}));
                return 'filled';
            }
            if (el.isContentEditable) {
                el.focus();
                el.textContent = '\(escaped)';
                el.dispatchEvent(new Event('input', {bubbles: true}));
                return 'filled';
            }
            return 'not_fillable';
        })()
        """)
        let success = result == "filled"
        await AgentEventBus.shared.publish(.browser(.domFilled(selector: selector, success: success)))
        return success
    }

    // MARK: - Submit

    /// Submit a form by CSS selector.
    @discardableResult
    public func submitForm(selector: String) async throws -> Bool {
        let result = try await executeJavaScript("""
        (function() {
            var el = document.querySelector('\(selector)');
            if (!el) return 'not_found';
            if (el.tagName.toLowerCase() === 'form') {
                el.submit();
                return 'submitted';
            }
            var form = el.closest('form');
            if (form) {
                form.submit();
                return 'submitted';
            }
            return 'no_form';
        })()
        """)
        let success = result == "submitted"
        await AgentEventBus.shared.publish(.browser(.domSubmitted(formSelector: selector, success: success)))
        return success
    }

    // MARK: - Tab Management

    /// List all page tabs.
    public func listTabs() async throws -> [(targetId: String, title: String, url: String)] {
        guard let s = session else {
            throw CDPError.connectionFailed("not connected")
        }
        let raw = try await s.getTargets()
        guard let targetInfos = Self.extractValue(from: raw, key: "result.targetInfos") as? [[String: Any]] else {
            return []
        }
        return targetInfos.compactMap { info in
            guard let tid = info["targetId"] as? String,
                  let type = info["type"] as? String,
                  type == "page" else { return nil }
            let title = info["title"] as? String ?? ""
            let url = info["url"] as? String ?? ""
            return (tid, title, url)
        }
    }

    /// Open a new tab and navigate to URL.
    public func openNewTab(url: String = "about:blank") async throws -> String {
        guard let s = session else {
            throw CDPError.connectionFailed("not connected")
        }
        let raw = try await s.createTarget(url: url)
        let targetId = Self.extractValue(from: raw, key: "result.targetId") as? String ?? ""
        await AgentEventBus.shared.publish(.browser(.tabOpened(url: url)))
        return targetId
    }

    /// Close the currently connected tab by target ID.
    public func closeCurrentTab() async throws {
        guard let s = session, let targetId = connectedTargetId else {
            throw CDPError.connectionFailed("not connected to a specific tab")
        }
        _ = try await s.closeTarget(targetId: targetId)
        await AgentEventBus.shared.publish(.browser(.tabClosed))
    }

    /// Switch to a specific tab by target ID.
    public func switchToTab(targetId: String) async throws {
        guard let s = session else {
            throw CDPError.connectionFailed("not connected")
        }
        _ = try await s.activateTarget(targetId: targetId)
        try await connect(targetId: targetId)
        await AgentEventBus.shared.publish(.browser(.tabSwitched(index: 0)))
    }

    // MARK: - Network / Console

    /// Get collected network entries.
    public func getNetworkEntries() -> [ChromeDevToolsSession.NetworkEntry] {
        session?.readNetworkEntries() ?? []
    }

    /// Get collected console messages.
    public func getConsoleMessages() -> [ChromeDevToolsSession.ConsoleMessage] {
        session?.readConsoleMessages() ?? []
    }

    // MARK: - Screenshot

    /// Capture a screenshot of the current page. Returns base64-encoded image data.
    public func captureScreenshot(format: String = "png") async throws -> String {
        guard let s = session else {
            throw CDPError.connectionFailed("not connected")
        }
        return try await s.captureScreenshot(format: format)
    }

    // MARK: - Navigation

    /// Navigate to a URL.
    @discardableResult
    public func navigate(url: String) async throws -> String {
        guard let s = session else {
            throw CDPError.connectionFailed("not connected")
        }
        let result = try await s.navigate(url: url)
        await AgentEventBus.shared.publish(.browser(.pageLoaded(url: url, title: nil)))
        return result
    }

    /// Reload the current page.
    @discardableResult
    public func reload(ignoreCache: Bool = false) async throws -> String {
        guard let s = session else {
            throw CDPError.connectionFailed("not connected")
        }
        return try await s.reload(ignoreCache: ignoreCache)
    }

    // MARK: - Performance

    /// Get performance metrics as a formatted string.
    public func getPerformanceMetrics() async throws -> String {
        guard let s = session else {
            throw CDPError.connectionFailed("not connected")
        }
        return try await s.getPerformanceMetrics()
    }

    // MARK: - Print to PDF

    /// Print page to PDF, returns base64-encoded PDF.
    public func printToPDF() async throws -> String {
        guard let s = session else {
            throw CDPError.connectionFailed("not connected")
        }
        return try await s.printToPDF()
    }

    // MARK: - Helpers

    /// Extract a value from a CDP JSON response by key path.
    private static func extractValue(from json: String, key: String) -> Any? {
        ChromeDevToolsSession.extractString(from: json, keyPath: key)
            ?? ChromeDevToolsSession.extractInt(from: json, keyPath: key)
            ?? ChromeDevToolsSession.extractDouble(from: json, keyPath: key)
            ?? extractDeepValue(from: json, keyPath: key)
    }

    private static func extractDeepValue(from json: String, keyPath: String) -> Any? {
        // Try nested access for "result.value"
        let keys = keyPath.split(separator: ".").map(String.init)
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        var current: Any = dict
        for key in keys {
            if let d = current as? [String: Any] {
                guard let val = d[key] else { return nil }
                current = val
            } else {
                return nil
            }
        }
        return current
    }

    private func extractSearchQuery(from urlString: String) -> String? {
        guard let components = URLComponents(string: urlString),
              let item = components.queryItems?.first(where: { ["q", "query", "text", "p"].contains($0.name.lowercased()) }),
              let value = item.value?.removingPercentEncoding ?? item.value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
