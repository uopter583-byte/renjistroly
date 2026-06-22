import AppKit
import Foundation
import OSLog
import RenJistrolyModels

/// Browser DOM backend — uses AppleScript `do JavaScript` (Safari) / CDP (Chrome) for web automation.
///
/// Requires "Allow JavaScript from Apple Events" enabled in Safari's Develop menu (macOS 15+).
/// Chrome automation uses the ChromeDriver with accessibility fallback.
public actor DOMComputerUseBackend: ComputerUseBackend {
    public let kind: ComputerUseBackendKind = .dom
    public let displayName = "DOM (浏览器)"

    private enum BrowserKind {
        case safari, chrome
    }

    private let browser: BrowserKind

    public init(browserName: String) {
        switch browserName.lowercased() {
        case "chrome", "google chrome":
            self.browser = .chrome
        default:
            self.browser = .safari
        }
    }

    public func observe(existingObservation: ComputerUseObservation) async -> ComputerUseObservation {
        var updated = existingObservation
        if let pageState = try? await currentPageState() {
            updated.ocrText = [updated.ocrText, "当前页面: \(pageState.tabTitle ?? pageState.url ?? "")"]
                .compactMap { $0 }
                .joined(separator: "\n")
        }
        return updated
    }

    public nonisolated func canHandle(action: MacAction) -> Bool {
        switch action.kind {
        case .clickElement, .setFocusedText, .insertText, .scroll, .pressShortcut:
            return true
        default:
            return false
        }
    }

    public nonisolated func execute(action: MacAction) async -> BackendActionResult {
        let p = action.payload
        do {
            switch action.kind {
            case .clickElement:
                let label = p["label"] ?? p["title"] ?? ""
                let selector = multiStrategySelector(for: label)
                let success = try await driverClickElement(selector: selector)
                return BackendActionResult(
                    success: success,
                    message: success ? "DOM 已点击: \(selector)" : "DOM 未找到元素: \(label)"
                )
            case .setFocusedText, .insertText:
                let text = p["text"] ?? p["value"] ?? ""
                let escaped = text.replacingOccurrences(of: "'", with: "\\'")
                let js = """
                (function() {
                    var el = document.activeElement;
                    if (!el) return 'no_focus';
                    var tag = el.tagName.toLowerCase();
                    if (tag === 'input' || tag === 'textarea' || el.isContentEditable) {
                        el.value = '\(escaped)';
                        el.dispatchEvent(new Event('input', {bubbles:true}));
                        el.dispatchEvent(new Event('change', {bubbles:true}));
                        return 'typed';
                    }
                    return 'not_editable';
                })()
                """
                let result = try await self.executeJS(js)
                return BackendActionResult(success: result == "typed", message: "DOM 输入: \(result)")
            case .openURL:
                guard let url = p["url"] ?? p["href"] else {
                    return BackendActionResult(success: false, message: "DOM 打开 URL: 缺少 url 参数")
                }
                guard let resolved = URL(string: url) else {
                    return BackendActionResult(success: false, message: "DOM 打开 URL: 无效的 URL 格式")
                }
                switch browser {
                case .safari:
                    let driver = SafariDriver()
                    try driver.open(url: resolved)
                case .chrome:
                    let driver = ChromeDriver()
                    try driver.open(url: resolved)
                }
                return BackendActionResult(success: true, message: "DOM 已打开 URL: \(url)")
            case .scroll:
                let deltaY = Int(p["delta_y"] ?? "0") ?? 0
                let deltaX = Int(p["delta_x"] ?? "0") ?? 0
                let scrollJS = "window.scrollBy(\(deltaX), \(deltaY)); 'scrolled'"
                let result = try await executeJS(scrollJS)
                return BackendActionResult(success: result == "scrolled", message: "DOM 已滚动")
            default:
                return BackendActionResult(success: false, message: "DOM 后端暂不支持该操作")
            }
        } catch {
            return BackendActionResult(success: false, message: "DOM 操作失败: \(error.localizedDescription)")
        }
    }

    private nonisolated func multiStrategySelector(for label: String) -> String {
        let id = label.lowercased().replacingOccurrences(of: " ", with: "-")
        return """
        [data-fsb-id="\(id)"], \
        [aria-label="\(label)"], \
        [data-testid="\(id)"], \
        #\(id), \
        a:contains("\(label)"), \
        button:contains("\(label)"), \
        input[placeholder="\(label)"], \
        [title="\(label)"], \
        [name="\(id)"]
        """
    }

    private func executeJS(_ js: String) async throws -> String {
        switch browser {
        case .safari: return try await SafariDriver().executeJavaScript(js)
        case .chrome: return try await ChromeDriver().executeJavaScript(js)
        }
    }

    private func driverClickElement(selector: String) async throws -> Bool {
        switch browser {
        case .safari: return try await SafariDriver().clickElement(selector: selector)
        case .chrome: return try await ChromeDriver().clickElement(selector: selector)
        }
    }

    private func currentPageState() async throws -> BrowserPageState? {
        switch browser {
        case .safari: return try await SafariDriver().currentPageState()
        case .chrome: return try await ChromeDriver().currentPageState()
        }
    }
}
