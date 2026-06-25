import Foundation
import os

public enum CDPError: Error, LocalizedError, Sendable {
    case chromeNotRunning
    case noDebugPort
    case noTargetFound(String)
    case connectionFailed(String)
    case commandFailed(code: Int, message: String)
    case jsonError(String)

    public var errorDescription: String? {
        switch self {
        case .chromeNotRunning: return "Chrome is not running"
        case .noDebugPort: return "Chrome not started with --remote-debugging-port=9222"
        case .noTargetFound(let detail): return "No debuggable Chrome tab: \(detail)"
        case .connectionFailed(let msg): return "CDP connection failed: \(msg)"
        case .commandFailed(let code, let msg): return "CDP error \(code): \(msg)"
        case .jsonError(let msg): return "CDP JSON error: \(msg)"
        }
    }
}

/// Chrome DevTools Protocol session via WebSocket.
/// Provides both raw CDP command access and high-level convenience methods
/// for browser automation (navigate, evaluate JS, screenshot, cookies, network).
///
/// Thread safety: uses OSAllocatedUnfairLock for mutable state.
/// Marked @unchecked Sendable because the lock protects all mutable properties.
public final class ChromeDevToolsSession: Sendable {
    private let lock = OSAllocatedUnfairLock()
    nonisolated(unsafe) private var webSocketTask: URLSessionWebSocketTask?
    nonisolated(unsafe) private var pending: [Int: CheckedContinuation<String, Error>] = [:]
    nonisolated(unsafe) private var nextId = 1
    nonisolated(unsafe) private var eventHandlers: [String: @Sendable (String) -> Void] = [:]
    nonisolated(unsafe) private var networkEntries: [NetworkEntry] = []
    nonisolated(unsafe) private var consoleMessages: [ConsoleMessage] = []

    /// Captured network request/response entry.
    public struct NetworkEntry: Sendable, Codable, Hashable {
        public let requestId: String
        public let url: String
        public let method: String
        public let statusCode: Int
        public let type: String
        public let timing: Double
        public let error: String?

        public init(requestId: String, url: String, method: String, statusCode: Int, type: String, timing: Double, error: String? = nil) {
            self.requestId = requestId
            self.url = url
            self.method = method
            self.statusCode = statusCode
            self.type = type
            self.timing = timing
            self.error = error
        }
    }

    /// Captured console message entry.
    public struct ConsoleMessage: Sendable, Codable, Hashable {
        public let level: String
        public let text: String
        public let timestamp: Double

        public init(level: String, text: String, timestamp: Double) {
            self.level = level
            self.text = text
            self.timestamp = timestamp
        }
    }

    public init() {}

    // MARK: - Connection

    public func connectToAny(port: Int = 9222) async throws {
        let targets = try await discoverTargets(port: port)
        guard let target = targets.first(where: { ($0["type"] as? String) == "page" })
                ?? targets.first else {
            throw CDPError.noTargetFound("no page targets (got \(targets.count) total)")
        }
        guard let wsURL = target["webSocketDebuggerUrl"] as? String else {
            throw CDPError.noTargetFound("target has no webSocketDebuggerUrl")
        }
        try await connect(to: wsURL)
    }

    public func connect(to wsURL: String) async throws {
        guard let url = URL(string: wsURL) else {
            throw CDPError.connectionFailed("invalid WebSocket URL")
        }
        disconnect()
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        lock.withLock { webSocketTask = task }
        task.resume()
        listen()
    }

    public func disconnect() {
        let oldPending: [Int: CheckedContinuation<String, Error>] = lock.withLock {
            webSocketTask?.cancel(with: .normalClosure, reason: nil)
            webSocketTask = nil
            let p = pending
            pending.removeAll()
            eventHandlers.removeAll()
            networkEntries.removeAll()
            consoleMessages.removeAll()
            return p
        }
        for (_, cont) in oldPending {
            cont.resume(throwing: CDPError.connectionFailed("disconnected"))
        }
    }

    public var isConnected: Bool {
        lock.withLock { webSocketTask != nil }
    }

    // MARK: - Raw CDP Command

    @discardableResult
    public func send(method: String, paramsJSON: String = "{}") async throws -> String {
        let paramsData = paramsJSON.data(using: .utf8) ?? Data()
        guard let paramsObj = try? JSONSerialization.jsonObject(with: paramsData) as? [String: Any] else {
            throw CDPError.jsonError("invalid params JSON")
        }
        let id: Int = lock.withLock {
            let i = nextId
            nextId += 1
            return i
        }
        let cmd: [String: Any] = ["id": id, "method": method, "params": paramsObj]
        let cmdData = try JSONSerialization.data(withJSONObject: cmd)

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let task: URLSessionWebSocketTask? = self.lock.withLock {
                self.pending[id] = cont
                return self.webSocketTask
            }

            guard let task else {
                _ = self.lock.withLock { self.pending.removeValue(forKey: id) }
                cont.resume(throwing: CDPError.connectionFailed("not connected"))
                return
            }

            task.send(.data(cmdData)) { error in
                if let error {
                    _ = self.lock.withLock { self.pending.removeValue(forKey: id) }
                    cont.resume(throwing: CDPError.connectionFailed(error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Event Registration

    public func onEvent(_ method: String, handler: @escaping @Sendable (String) -> Void) {
        lock.withLock { eventHandlers[method] = handler }
    }

    public func clearEvents() {
        lock.withLock { eventHandlers.removeAll() }
    }

    // MARK: - High-level APIs

    public func evaluate(expression: String) async throws -> String {
        let expr = try JSONEncoder().encode(expression)
        let exprStr = String(data: expr, encoding: .utf8) ?? "\"\""
        return try await send(method: "Runtime.evaluate",
                              paramsJSON: "{\"expression\":\(exprStr),\"returnByValue\":true}")
    }

    public func navigate(url: String) async throws -> String {
        let urlEncoded = try JSONEncoder().encode(url)
        let urlStr = String(data: urlEncoded, encoding: .utf8) ?? "\"\""
        return try await send(method: "Page.navigate",
                              paramsJSON: "{\"url\":\(urlStr)}")
    }

    public func captureScreenshot(format: String = "png") async throws -> String {
        try await send(method: "Page.captureScreenshot",
                       paramsJSON: "{\"format\":\"\(format)\"}")
    }

    public func getCookies() async throws -> String {
        try await send(method: "Network.getCookies")
    }

    public func setCookie(name: String, value: String, domain: String? = nil) async throws -> String {
        var parts = ["\"name\":\"\(name)\"", "\"value\":\"\(value)\""]
        if let domain { parts.append("\"domain\":\"\(domain)\"") }
        return try await send(method: "Network.setCookie",
                              paramsJSON: "{\(parts.joined(separator: ","))}")
    }

    public func blockURLs(patterns: [String]) async throws -> String {
        let arr = patterns.map { "\"\($0)\"" }.joined(separator: ",")
        return try await send(method: "Network.setBlockedURLs",
                              paramsJSON: "{\"urls\":[\(arr)]}")
    }

    public func enableNetwork() async throws -> String {
        try await send(method: "Network.enable")
    }

    public func enableConsole() async throws -> String {
        try await send(method: "Console.enable")
    }

    public func getDocument(depth: Int = 2) async throws -> String {
        try await send(method: "DOM.getDocument",
                       paramsJSON: "{\"depth\":\(depth),\"pierce\":true}")
    }

    public func querySelector(selector: String, nodeId: Int = 1) async throws -> String {
        let sel = try JSONEncoder().encode(selector)
        let selStr = String(data: sel, encoding: .utf8) ?? "\"\""
        return try await send(method: "DOM.querySelector",
                              paramsJSON: "{\"nodeId\":\(nodeId),\"selector\":\(selStr)}")
    }

    public func getOuterHTML(nodeId: Int) async throws -> String {
        try await send(method: "DOM.getOuterHTML",
                       paramsJSON: "{\"nodeId\":\(nodeId)}")
    }

    // MARK: - DOM Domain

    /// Query all elements matching a CSS selector. Returns raw CDP JSON.
    public func querySelectorAll(selector: String, nodeId: Int = 1) async throws -> String {
        let sel = try JSONEncoder().encode(selector)
        let selStr = String(data: sel, encoding: .utf8) ?? "\"\""
        return try await send(method: "DOM.querySelectorAll",
                              paramsJSON: "{\"nodeId\":\(nodeId),\"selector\":\(selStr)}")
    }

    /// Get node ID for a given (x, y) coordinate.
    public func getNodeForLocation(x: Int, y: Int) async throws -> String {
        try await send(method: "DOM.getNodeForLocation",
                       paramsJSON: "{\"x\":\(x),\"y\":\(y),\"includeUserAgentShadowDOM\":true}")
    }

    /// Get attributes of a DOM node.
    public func getAttributes(nodeId: Int) async throws -> String {
        try await send(method: "DOM.getAttributes",
                       paramsJSON: "{\"nodeId\":\(nodeId)}")
    }

    /// Resolve a DOM node to a RemoteObjectId (for use with Runtime.callFunctionOn).
    public func resolveNode(nodeId: Int) async throws -> String {
        try await send(method: "DOM.resolveNode",
                       paramsJSON: "{\"nodeId\":\(nodeId),\"objectGroup\":\"renjistroly\"}")
    }

    // MARK: - Input Domain

    /// Dispatch a real mouse click at the center of a bounding box.
    /// The boundingBox can be obtained via DOM.getBoxModel or a ReservationQuery.
    public func dispatchMouseClick(x: Int, y: Int, button: String = "left", clickCount: Int = 1) async throws -> String {
        let downParams = "{\"type\":\"mousePressed\",\"x\":\(x),\"y\":\(y),\"button\":\"\(button)\",\"clickCount\":\(clickCount)}"
        let upParams = "{\"type\":\"mouseReleased\",\"x\":\(x),\"y\":\(y),\"button\":\"\(button)\",\"clickCount\":\(clickCount)}"
        let down = try await send(method: "Input.dispatchMouseEvent", paramsJSON: downParams)
        let up = try await send(method: "Input.dispatchMouseEvent", paramsJSON: upParams)
        return "[mouseDown] \(down)\n[mouseUp] \(up)"
    }

    /// Dispatch a real mouse click by CSS selector. Resolves the element first.
    public func dispatchMouseClick(selector: String) async throws -> String {
        let raw = try await querySelector(selector: selector)
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = dict["result"] as? [String: Any],
              let nodeId = result["nodeId"] as? Int else {
            throw CDPError.commandFailed(code: -1, message: "querySelector returned no nodeId for '\(selector)'")
        }
        let boxRaw = try await send(method: "DOM.getBoxModel",
                                     paramsJSON: "{\"nodeId\":\(nodeId),\"track\":false}")
        let (cx, cy) = try parseBoxCenter(boxRaw)
        return try await dispatchMouseClick(x: cx, y: cy)
    }

    /// Insert text via Input.insertText (simulates real keyboard input).
    public func insertText(_ text: String) async throws -> String {
        let encoded = try JSONEncoder().encode(text)
        let textStr = String(data: encoded, encoding: .utf8) ?? "\"\""
        return try await send(method: "Input.insertText",
                              paramsJSON: "{\"text\":\(textStr)}")
    }

    /// Dispatch a key event (keyDown/keyUp/char).
    public func dispatchKeyEvent(type: String, key: String, code: String = "", text: String = "") async throws -> String {
        var parts = ["\"type\":\"\(type)\"", "\"key\":\"\(key)\""]
        if !code.isEmpty { parts.append("\"code\":\"\(code)\"") }
        if !text.isEmpty {
            let encoded = try JSONEncoder().encode(text)
            let textStr = String(data: encoded, encoding: .utf8) ?? "\"\""
            parts.append("\"text\":\(textStr)")
        }
        return try await send(method: "Input.dispatchKeyEvent",
                              paramsJSON: "{\(parts.joined(separator: ","))}")
    }

    // MARK: - Runtime Domain

    /// Call a function on a resolved object (by objectId).
    public func callFunctionOn(functionDeclaration: String, objectId: String) async throws -> String {
        let fnEncoded = try JSONEncoder().encode(functionDeclaration)
        let fnStr = String(data: fnEncoded, encoding: .utf8) ?? "\"\""
        let objEncoded = try JSONEncoder().encode(objectId)
        let objStr = String(data: objEncoded, encoding: .utf8) ?? "\"\""
        return try await send(method: "Runtime.callFunctionOn",
                              paramsJSON: "{\"functionDeclaration\":\(fnStr),\"objectId\":\(objStr),\"returnByValue\":true}")
    }

    /// Get properties of a RemoteObject.
    public func getProperties(objectId: String) async throws -> String {
        let objEncoded = try JSONEncoder().encode(objectId)
        let objStr = String(data: objEncoded, encoding: .utf8) ?? "\"\""
        return try await send(method: "Runtime.getProperties",
                              paramsJSON: "{\"objectId\":\(objStr),\"ownProperties\":true}")
    }

    // MARK: - Page Domain

    /// Print page to PDF. Returns base64-encoded PDF string.
    public func printToPDF() async throws -> String {
        try await send(method: "Page.printToPDF",
                       paramsJSON: "{\"printBackground\":true}")
    }

    /// Reload current page.
    @discardableResult
    public func reload(ignoreCache: Bool = false) async throws -> String {
        try await send(method: "Page.reload",
                       paramsJSON: "{\"ignoreCache\":\(ignoreCache)}")
    }

    /// Get navigation history.
    public func getNavigationHistory() async throws -> String {
        try await send(method: "Page.getNavigationHistory")
    }

    /// Get the current page URL from navigation history (no JS evaluation needed).
    public func getCurrentURL() async throws -> String {
        let raw = try await getNavigationHistory()
        guard let result = Self.extractDict(from: raw, keyPath: "result"),
              let currentIndex = result["currentIndex"] as? Int,
              let entries = result["entries"] as? [[String: Any]],
              currentIndex >= 0, currentIndex < entries.count,
              let url = entries[currentIndex]["url"] as? String,
              !url.isEmpty else {
            throw CDPError.jsonError("failed to extract current URL from navigation history")
        }
        return url
    }

    /// Add a script to evaluate on every document load.
    public func addScriptToEvaluateOnLoad(source: String) async throws -> String {
        let srcEncoded = try JSONEncoder().encode(source)
        let srcStr = String(data: srcEncoded, encoding: .utf8) ?? "\"\""
        return try await send(method: "Page.addScriptToEvaluateOnLoad",
                              paramsJSON: "{\"scriptSource\":\(srcStr)}")
    }

    // MARK: - Target Domain (Tab Management)

    /// List all available targets (tabs).
    public func getTargets() async throws -> String {
        try await send(method: "Target.getTargets")
    }

    /// Create a new tab (target) with optional URL.
    public func createTarget(url: String = "about:blank") async throws -> String {
        let urlEncoded = try JSONEncoder().encode(url)
        let urlStr = String(data: urlEncoded, encoding: .utf8) ?? "\"\""
        return try await send(method: "Target.createTarget",
                              paramsJSON: "{\"url\":\(urlStr)}")
    }

    /// Close a target (tab) by targetId.
    public func closeTarget(targetId: String) async throws -> String {
        let idEncoded = try JSONEncoder().encode(targetId)
        let idStr = String(data: idEncoded, encoding: .utf8) ?? "\"\""
        return try await send(method: "Target.closeTarget",
                              paramsJSON: "{\"targetId\":\(idStr)}")
    }

    /// Activate a target (bring tab to front).
    public func activateTarget(targetId: String) async throws -> String {
        let idEncoded = try JSONEncoder().encode(targetId)
        let idStr = String(data: idEncoded, encoding: .utf8) ?? "\"\""
        return try await send(method: "Target.activateTarget",
                              paramsJSON: "{\"targetId\":\(idStr)}")
    }

    /// Get the WebSocket URL for a specific target (for multi-tab connection).
    public func getWebSocketURL(targetId: String) async throws -> String {
        guard let url = URL(string: "http://localhost:9222/json") else {
            throw CDPError.noDebugPort
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw CDPError.noTargetFound("invalid JSON response")
        }
        for target in arr {
            if let tid = target["id"] as? String, tid == targetId,
               let wsURL = target["webSocketDebuggerUrl"] as? String {
                return wsURL
            }
        }
        throw CDPError.noTargetFound("target \(targetId) not found")
    }

    // MARK: - Performance Domain

    /// Enable performance metrics collection.
    public func enablePerformance() async throws -> String {
        try await send(method: "Performance.enable")
    }

    /// Get current performance metrics.
    public func getPerformanceMetrics() async throws -> String {
        try await send(method: "Performance.getMetrics")
    }

    // MARK: - Network Event Capture

    /// Get collected network entries (cleared on each read by default).
    public func readNetworkEntries(clear: Bool = true) -> [NetworkEntry] {
        lock.withLock {
            let entries = networkEntries
            if clear { networkEntries.removeAll() }
            return entries
        }
    }

    /// Get collected console messages (cleared on each read by default).
    public func readConsoleMessages(clear: Bool = true) -> [ConsoleMessage] {
        lock.withLock {
            let msgs = consoleMessages
            if clear { consoleMessages.removeAll() }
            return msgs
        }
    }

    /// Register built-in event handlers for Network and Console domains.
    public func registerDefaultEventHandlers() {
        // Network events
        onEvent("Network.requestWillBeSent") { [weak self] json in
            self?.captureNetworkEntry(json)
        }
        onEvent("Network.responseReceived") { [weak self] json in
            self?.updateNetworkEntry(json)
        }
        onEvent("Network.loadingFailed") { [weak self] json in
            self?.captureNetworkError(json)
        }
        // Console events
        onEvent("Console.messageAdded") { [weak self] json in
            self?.captureConsoleMessage(json)
        }
        // Runtime console (alternative to Console domain)
        onEvent("Runtime.consoleAPICalled") { [weak self] json in
            self?.captureRuntimeConsole(json)
        }
    }

    // MARK: - JSON Parsing Helpers

    /// Extract a string value from a CDP JSON result by key path.
    public static func extractString(from json: String, keyPath: String...) -> String? {
        extractValue(from: json, keyPath: keyPath) as? String
    }

    /// Extract an integer value from a CDP JSON result by key path.
    public static func extractInt(from json: String, keyPath: String...) -> Int? {
        extractValue(from: json, keyPath: keyPath) as? Int
    }

    /// Extract a double value from a CDP JSON result by key path.
    public static func extractDouble(from json: String, keyPath: String...) -> Double? {
        extractValue(from: json, keyPath: keyPath) as? Double
    }

    /// Extract a dictionary value from a CDP JSON result by key path.
    public static func extractDict(from json: String, keyPath: String...) -> [String: Any]? {
        extractValue(from: json, keyPath: keyPath) as? [String: Any]
    }

    /// Extract an array value from a CDP JSON result by key path.
    public static func extractArray(from json: String, keyPath: String...) -> [Any]? {
        extractValue(from: json, keyPath: keyPath) as? [Any]
    }

    private static func extractValue(from json: String, keyPath: [String]) -> Any? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        var current: Any = dict
        for key in keyPath {
            if let d = current as? [String: Any] {
                guard let val = d[key] else { return nil }
                current = val
            } else {
                return nil
            }
        }
        return current
    }

    /// Parse {result: {model: {content: [{x, y, width, height}]}}} from DOM.getBoxModel.
    private func parseBoxCenter(_ raw: String) throws -> (Int, Int) {
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = dict["result"] as? [String: Any],
              let model = result["model"] as? [String: Any],
              let content = model["content"] as? [Double] else {
            throw CDPError.commandFailed(code: -1, message: "failed to parse box model")
        }
        guard content.count >= 4 else {
            throw CDPError.commandFailed(code: -1, message: "box model content has insufficient coordinates")
        }
        let cx = Int((content[0] + content[2]) / 2.0)
        let cy = Int((content[1] + content[3]) / 2.0)
        return (cx, cy)
    }

    // MARK: - Network/Console Event Capture (Private)

    private func captureNetworkEntry(_ json: String) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let params = dict["params"] as? [String: Any] else { return }
        let requestId = params["requestId"] as? String ?? ""
        let request = params["request"] as? [String: Any]
        let url = request?["url"] as? String ?? ""
        let method = request?["method"] as? String ?? "GET"
        let entry = NetworkEntry(
            requestId: requestId,
            url: url,
            method: method,
            statusCode: 0,
            type: params["type"] as? String ?? "",
            timing: 0
        )
        lock.withLock { networkEntries.append(entry) }
    }

    private func updateNetworkEntry(_ json: String) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let params = dict["params"] as? [String: Any],
              let requestId = params["requestId"] as? String,
              let response = params["response"] as? [String: Any] else { return }
        let statusCode = response["status"] as? Int ?? 0
        let type = response["type"] as? String ?? ""
        lock.withLock {
            if let idx = networkEntries.firstIndex(where: { $0.requestId == requestId }) {
                let old = networkEntries[idx]
                networkEntries[idx] = NetworkEntry(
                    requestId: old.requestId,
                    url: old.url,
                    method: old.method,
                    statusCode: statusCode,
                    type: type,
                    timing: old.timing,
                    error: old.error
                )
            }
        }
    }

    private func captureNetworkError(_ json: String) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let params = dict["params"] as? [String: Any],
              let requestId = params["requestId"] as? String,
              let errorText = params["errorText"] as? String else { return }
        lock.withLock {
            if let idx = networkEntries.firstIndex(where: { $0.requestId == requestId }) {
                let old = networkEntries[idx]
                networkEntries[idx] = NetworkEntry(
                    requestId: old.requestId,
                    url: old.url,
                    method: old.method,
                    statusCode: old.statusCode,
                    type: old.type,
                    timing: old.timing,
                    error: errorText
                )
            }
        }
    }

    private func captureConsoleMessage(_ json: String) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let params = dict["params"] as? [String: Any],
              let message = params["message"] as? [String: Any] else { return }
        let level = message["level"] as? String ?? "log"
        let text = message["text"] as? String ?? ""
        let timestamp = message["timestamp"] as? Double ?? Date().timeIntervalSince1970
        let msg = ConsoleMessage(level: level, text: text, timestamp: timestamp)
        lock.withLock { consoleMessages.append(msg) }
    }

    private func captureRuntimeConsole(_ json: String) {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let params = dict["params"] as? [String: Any] else { return }
        let type = params["type"] as? String ?? "log"
        let args = params["args"] as? [[String: Any]] ?? []
        let text = args.compactMap { $0["value"] as? String ?? ($0["description"] as? String) }.joined(separator: " ")
        let timestamp = Date().timeIntervalSince1970
        let msg = ConsoleMessage(level: type, text: text, timestamp: timestamp)
        lock.withLock { consoleMessages.append(msg) }
    }

    // MARK: - Chrome Launch

    /// Launch Chrome with remote debugging port if not already running.
    /// Returns true if Chrome was launched by this call.
    public static func ensureChrome(port: Int = 9222) async throws -> Bool {
        if let url = URL(string: "http://localhost:\(port)/json/version") {
            if let (_, resp) = try? await URLSession.shared.data(from: url),
               let httpResp = resp as? HTTPURLResponse,
               httpResp.statusCode == 200 {
                return false
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [
            "-a", "Google Chrome",
            "--args", "--remote-debugging-port=\(port)",
            "--no-first-run",
            "--no-default-browser-check",
        ]
        try process.run()
        process.waitUntilExit()

        for _ in 0..<30 {
            if let url = URL(string: "http://localhost:\(port)/json/version") {
                if let (_, resp) = try? await URLSession.shared.data(from: url),
                   let httpResp = resp as? HTTPURLResponse,
                   httpResp.statusCode == 200 {
                    return true
                }
            }
            try await Task.sleep(for: .milliseconds(500))
        }
        throw CDPError.connectionFailed("Chrome started but debug port not available after 15s")
    }

    // MARK: - Private

    private func listen() {
        let task = lock.withLock { webSocketTask }
        task?.receive(completionHandler: { [weak self] (result: Result<URLSessionWebSocketTask.Message, Error>) in
            guard let self else { return }
            switch result {
            case .success(let message):
                let text: String
                switch message {
                case .string(let s): text = s
                case .data(let d): text = String(data: d, encoding: .utf8) ?? ""
                @unknown default: text = ""
                }
                self.handleMessage(text)
                self.listen()
            case .failure(let error):
                self.handleDisconnect(error)
            }
        })
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let msgId = dict["id"] as? Int {
            let cont: CheckedContinuation<String, Error>? = lock.withLock {
                pending.removeValue(forKey: msgId)
            }
            if let cont {
                if let err = dict["error"] as? [String: Any] {
                    let code = err["code"] as? Int ?? -1
                    let msg = err["message"] as? String ?? "unknown"
                    cont.resume(throwing: CDPError.commandFailed(code: code, message: msg))
                } else {
                    cont.resume(returning: text)
                }
            }
        } else if let method = dict["method"] as? String {
            if let handler: @Sendable (String) -> Void = lock.withLock({ eventHandlers[method] }) {
                handler(text)
            }
        }
    }

    private func handleDisconnect(_ error: Error) {
        let oldPending: [Int: CheckedContinuation<String, Error>] = lock.withLock {
            let p = pending
            pending.removeAll()
            webSocketTask = nil
            return p
        }
        for (_, cont) in oldPending {
            cont.resume(throwing: error)
        }
    }

    private func discoverTargets(port: Int) async throws -> [[String: Any]] {
        guard let url = URL(string: "http://localhost:\(port)/json") else {
            throw CDPError.noDebugPort
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw CDPError.noDebugPort
        }
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw CDPError.noTargetFound("invalid JSON response")
        }
        return arr
    }
}
