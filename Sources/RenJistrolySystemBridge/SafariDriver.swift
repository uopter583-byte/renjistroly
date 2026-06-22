import AppKit
import Foundation
import RenJistrolyModels

public struct SafariDriver: AppDriver {
    public let id = "safari"
    public let displayName = "Safari"
    public let capabilities: Set<AppDriverCapability> = [.open, .search, .read, .write, .manageWindows]
    private let appleScriptBridge: AppleScriptBridge

    public init(appleScriptBridge: AppleScriptBridge = AppleScriptBridge()) {
        self.appleScriptBridge = appleScriptBridge
    }

    public func open(url: URL) throws {
        Task {
            if let current = try? await currentPageState(), let from = current.url {
                await AgentEventBus.shared.publish(.browser(.pageNavigated(from: from, to: url.absoluteString)))
            }
            await AgentEventBus.shared.publish(.browser(.pageLoaded(url: url.absoluteString, title: nil)))
        }
        NSWorkspace.shared.open(url)
    }

    public func search(query: String) throws {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://www.google.com/search?q=\(encoded)") else {
            throw NSError(domain: "SafariDriver", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法构造搜索 URL"])
        }
        try open(url: url)
        Task { await AgentEventBus.shared.publish(.browser(.searchPerformed(query: query, engine: "Google"))) }
    }

    public func executeJavaScript(_ js: String) async throws -> String {
        let escaped = js.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Safari"
            if not (exists front window) then
                error "Safari has no front window"
            end if
            set jsResult to do JavaScript "\(escaped)" in current tab of front window
            return jsResult as text
        end tell
        """
        let result = try await appleScriptBridge.run(script)
        return result.stringValue ?? ""
    }

    public func getDOMElement(selector: String) async throws -> BrowserDOMElement? {
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
        let raw = try await executeJavaScript(js)
        let found = !raw.isEmpty
        Task { await AgentEventBus.shared.publish(.browser(.domQueried(selector: selector, resultCount: found ? 1 : 0))) }
        guard found, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(BrowserDOMElement.self, from: data)
    }

    public func queryDOMAll(selector: String) async throws -> [BrowserDOMElement] {
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
        let raw = try await executeJavaScript(js)
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return [] }
        let elements = (try? JSONDecoder().decode([BrowserDOMElement].self, from: data)) ?? []
        Task { await AgentEventBus.shared.publish(.browser(.domQueried(selector: selector, resultCount: elements.count))) }
        return elements
    }

    /// Multi-strategy click: tries FSB-style selector chain, then falls back to original.
    public func clickElement(selector: String) async throws -> Bool {
        let js = """
        (function() {
            var candidates = ['\(selector)'];
            if (!document.querySelector(candidates[0])) {
                var s = '\(selector)';
                var text = s.replace(/[#.]/g, ' ').replace(/[-_]/g, ' ').trim();
                candidates = [
                    s,
                    '[data-fsb-id="' + text + '"]',
                    '[aria-label="' + text + '"]',
                    '[data-testid="' + text + '"]',
                    '#' + text.replace(/\\s+/g, '-'),
                    'a:contains("' + text + '")',
                    'button:contains("' + text + '")',
                    'input[placeholder="' + text + '"]',
                    '[title="' + text + '"]',
                    '[name="' + text.replace(/\\s+/g, '_') + '"]'
                ];
            }
            for (var i = 0; i < candidates.length; i++) {
                try {
                    var el = document.querySelector(candidates[i]);
                    if (el) { el.click(); return 'clicked:' + candidates[i]; }
                } catch(e) {}
            }
            return 'not_found';
        })()
        """
        let result = try await executeJavaScript(js)
        let success = result.hasPrefix("clicked")
        let usedSelector = success ? String(result.dropFirst("clicked:".count)) : selector
        Task { await AgentEventBus.shared.publish(.browser(.domClicked(selector: usedSelector, success: success))) }
        return success
    }

    public func fillElement(selector: String, value: String) async throws -> Bool {
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let js = """
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
        """
        let result = try await executeJavaScript(js)
        let success = result == "filled"
        Task { await AgentEventBus.shared.publish(.browser(.domFilled(selector: selector, success: success))) }
        return success
    }

    public func submitForm(selector: String) async throws -> Bool {
        let js = """
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
        """
        let result = try await executeJavaScript(js)
        let success = result == "submitted"
        Task { await AgentEventBus.shared.publish(.browser(.domSubmitted(formSelector: selector, success: success))) }
        return success
    }

    public func focusElement(selector: String) async throws -> Bool {
        let js = """
        (function() {
            var el = document.querySelector('\(selector)');
            if (!el) return 'not_found';
            el.focus();
            return 'focused';
        })()
        """
        let result = try await executeJavaScript(js)
        return result == "focused"
    }

    public func selectOption(selector: String, value: String) async throws -> Bool {
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function() {
            var el = document.querySelector('\(selector)');
            if (!el) return 'not_found';
            if (el.tagName.toLowerCase() === 'select') {
                el.value = '\(escaped)';
                el.dispatchEvent(new Event('change', {bubbles: true}));
                return 'selected';
            }
            return 'not_select';
        })()
        """
        let result = try await executeJavaScript(js)
        return result == "selected"
    }

    public func currentPageState() async throws -> BrowserPageState {
        let script = #"""
        tell application "Safari"
            if not (exists front window) then
                return ""
            end if
            set windowTitle to name of front window
            set tabTitle to name of current tab of front window
            set pageURL to URL of current tab of front window
            return windowTitle & linefeed & tabTitle & linefeed & pageURL
        end tell
        """#
        let result = try await appleScriptBridge.run(script)
        return Self.parseBrowserPageState(result.stringValue, browserName: displayName)
    }

    static func parseBrowserPageState(_ raw: String?, browserName: String) -> BrowserPageState {
        let lines = (raw ?? "").components(separatedBy: .newlines)
        let windowTitle = lines[safe: 0]?.nonEmptyValue
        let tabTitle = lines[safe: 1]?.nonEmptyValue
        let url = lines[safe: 2]?.nonEmptyValue
        return BrowserPageState(
            browserName: browserName,
            windowTitle: windowTitle,
            tabTitle: tabTitle,
            url: url,
            host: normalizedHost(from: url),
            searchQuery: extractedSearchQuery(from: url)
        )
    }

    // MARK: - Tab Management

    public func openNewTab(_ url: URL?) async throws {
        if let url {
            let script = """
            tell application "Safari"
                tell front window
                    set newTab to make new tab with properties {URL:"\(url.absoluteString)"}
                    set current tab to newTab
                end tell
            end tell
            """
            _ = try await appleScriptBridge.run(script)
            Task { await AgentEventBus.shared.publish(.browser(.tabOpened(url: url.absoluteString))) }
        } else {
            _ = try await appleScriptBridge.run("tell application \"Safari\" to tell front window to make new tab")
            Task { await AgentEventBus.shared.publish(.browser(.tabOpened(url: nil))) }
        }
    }

    public func closeCurrentTab() async throws {
        _ = try await appleScriptBridge.run("tell application \"Safari\" to close current tab of front window")
        Task { await AgentEventBus.shared.publish(.browser(.tabClosed)) }
    }

    public func switchToTab(_ index: Int) async throws {
        _ = try await appleScriptBridge.run("tell application \"Safari\" to set current tab of front window to tab \(index + 1) of front window")
        Task { await AgentEventBus.shared.publish(.browser(.tabSwitched(index: index))) }
    }

    // MARK: - Devtools (Console + Network)

    public func injectDevtoolsObserver() async throws -> Bool {
        let js = Self.devtoolsInjectionScript()
        let result = try await executeJavaScript(js)
        return result == "injected" || result == "already_injected"
    }

    public func getConsoleLogs() async throws -> [ConsoleLogEntry] {
        let raw = try await executeJavaScript(Self.consoleLogsScript())
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return [] }
        let entries = (try? JSONDecoder().decode([ConsoleLogEntry].self, from: data)) ?? []
        for entry in entries {
            Task { await AgentEventBus.shared.publish(.browser(.consoleOutput(level: entry.level, message: entry.message))) }
        }
        return entries
    }

    public func getNetworkLogs() async throws -> [NetworkRequestEntry] {
        let raw = try await executeJavaScript(Self.networkLogsScript())
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return [] }
        let entries = (try? JSONDecoder().decode([NetworkRequestEntry].self, from: data)) ?? []
        for entry in entries {
            Task { await AgentEventBus.shared.publish(.browser(.networkRequest(method: entry.method, url: entry.url, statusCode: entry.statusCode > 0 ? entry.statusCode : nil))) }
            if let error = entry.error {
                Task { await AgentEventBus.shared.publish(.browser(.networkFailure(url: entry.url, error: error))) }
            }
        }
        return entries
    }

    private static func devtoolsInjectionScript() -> String {
        #"""
        (function() {
            if (window.__renjistrolyObserver) return 'already_injected';
            window.__renjistrolyObserver = true;
            window.__renjistrolyLogs = [];
            window.__renjistrolyNetwork = [];
            var maxLogs = 200;
            function pushLog(level, msg) {
                if (window.__renjistrolyLogs.length >= maxLogs) window.__renjistrolyLogs.shift();
                window.__renjistrolyLogs.push({level: level, message: String(msg).substring(0, 500), ts: Date.now()});
            }
            ['log','warn','error','info','debug'].forEach(function(lvl) {
                var orig = console[lvl];
                console[lvl] = function() {
                    var args = Array.prototype.slice.call(arguments);
                    pushLog(lvl, args.map(function(a) {
                        try { return typeof a === 'object' ? JSON.stringify(a) : String(a); }
                        catch(e) { return String(a); }
                    }).join(' '));
                    return orig.apply(console, arguments);
                };
            });
            window.addEventListener('error', function(e) {
                pushLog('error', (e.message || 'Unknown error') + ' at ' + (e.filename || '') + ':' + (e.lineno || ''));
            });
            return 'injected';
        })()
        """#
    }

    private static func consoleLogsScript() -> String {
        """
        (function() {
            if (!window.__renjistrolyLogs) return '[]';
            var logs = window.__renjistrolyLogs;
            window.__renjistrolyLogs = [];
            return JSON.stringify(logs);
        })()
        """
    }

    private static func networkLogsScript() -> String {
        """
        (function() {
            if (!window.__renjistrolyNetwork) return '[]';
            var logs = window.__renjistrolyNetwork;
            window.__renjistrolyNetwork = [];
            return JSON.stringify(logs);
        })()
        """
    }
}
