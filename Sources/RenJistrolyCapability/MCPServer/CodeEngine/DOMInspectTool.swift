import Foundation
import RenJistrolyModels

// MARK: - DOM Inspect Tool

public struct DOMInspectTool: MCPTool {
    public let definition = ToolDefinition(
        name: "dom_inspect",
        description: "获取浏览器页面 DOM 结构，支持 CSS 选择器过滤",
        parameters: [
            .init(name: "app", type: .string, description: "浏览器应用名（Safari/Chrome），默认 Safari", required: false),
            .init(name: "selector", type: .string, description: "CSS 选择器过滤，为空则返回 body 下所有可见元素", required: false),
            .init(name: "include_hidden", type: .string, description: "是否包含隐藏元素：true/false，默认 false", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let app = arguments["app"] ?? "Safari"
        let selector = arguments["selector"]
        let includeHidden = (arguments["include_hidden"] ?? "false").lowercased() == "true"

        let visibilityFilter = includeHidden ? "" : ":not([hidden]):not([aria-hidden=\"true\"])"
        let js: String
        if let sel = selector, !sel.isEmpty {
            js = """
            (function() {
                var els = document.querySelectorAll('\(sel)');
                var result = [];
                for (var i = 0; i < Math.min(els.length, 30); i++) {
                    var el = els[i];
                    var rect = el.getBoundingClientRect();
                    result.push({
                        tag: el.tagName.toLowerCase(),
                        text: (el.textContent || '').trim().substring(0, 200),
                        id: el.id || undefined,
                        className: el.className || undefined,
                        href: el.href || undefined,
                        value: el.value || undefined,
                        rect: { x: Math.round(rect.x), y: Math.round(rect.y), w: Math.round(rect.width), h: Math.round(rect.height) },
                        visible: rect.width > 0 && rect.height > 0
                    });
                }
                return JSON.stringify(result);
            })()
            """
        } else {
            js = """
            (function() {
                var els = document.body.querySelectorAll('*\(visibilityFilter)');
                var result = [];
                for (var i = 0; i < Math.min(els.length, 50); i++) {
                    var el = els[i];
                    var hasText = (el.textContent || '').trim().length > 0;
                    var isInteractive = ['BUTTON','A','INPUT','SELECT','TEXTAREA','VIDEO'].includes(el.tagName);
                    if (!hasText && !isInteractive) continue;
                    var rect = el.getBoundingClientRect();
                    result.push({
                        tag: el.tagName.toLowerCase(),
                        text: (el.textContent || '').trim().substring(0, 100),
                        id: el.id || undefined,
                        className: (el.className || '').split(' ').slice(0,3).join(' ') || undefined,
                        href: el.href || undefined,
                        value: el.value || undefined,
                        rect: { x: Math.round(rect.x), y: Math.round(rect.y), w: Math.round(rect.width), h: Math.round(rect.height) },
                        visible: rect.width > 0 && rect.height > 0
                    });
                }
                return JSON.stringify(result);
            })()
            """
        }

        let script: String
        if app.localizedCaseInsensitiveContains("safari") {
            script = """
            tell application "Safari"
                do JavaScript "\(js.replacingOccurrences(of: "\"", with: "\\\""))" in current tab of front window
            end tell
            """
        } else if app.localizedCaseInsensitiveContains("chrome") {
            script = """
            tell application "Google Chrome"
                execute front window's active tab javascript "\(js.replacingOccurrences(of: "\"", with: "\\\""))"
            end tell
            """
        } else {
            return ToolCallResult(id: UUID().uuidString, output: "不支持的浏览器: \(app)，请使用 Safari 或 Chrome", isError: true)
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let pipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errPipe
        let (output, errOutput): (String, String) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, String), Error>) in
            task.terminationHandler = { _ in
                let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: (out, err))
            }
            do { try task.run() } catch { continuation.resume(throwing: error) }
        }

        if !errOutput.isEmpty && output.isEmpty {
            return ToolCallResult(id: UUID().uuidString, output: "DOM 获取失败: \(errOutput)", isError: true)
        }

        let count = output.isEmpty ? 0 : output.split(separator: "\n").count
        let sel = arguments["selector"] ?? "body"
        Task { await AgentEventBus.shared.publish(.browser(.domQueried(selector: sel, resultCount: count))) }
        return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "无匹配 DOM 元素" : output)
    }
}
