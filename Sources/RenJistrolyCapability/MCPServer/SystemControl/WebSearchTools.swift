import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

public struct WebSearchTool: MCPTool {
    public let definition = ToolDefinition(
        name: "web_search",
        description: "网页搜索，返回搜索结果标题和链接",
        parameters: [
            .init(name: "query", type: .string, description: "搜索关键词"),
            .init(name: "count", type: .string, description: "返回结果数，默认5", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let query = arguments["query"], !query.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: query", isError: true)
        }
        let count = Int(arguments["count"] ?? "5") ?? 5
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return ToolCallResult(id: UUID().uuidString, output: "查询参数编码失败", isError: true)
        }
        guard let url = URL(string: "https://lite.duckduckgo.com/lite/?q=\(encoded)") else {
            return ToolCallResult(id: UUID().uuidString, output: "无法构造搜索 URL", isError: true)
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else {
                return ToolCallResult(id: UUID().uuidString, output: "搜索结果解析失败", isError: true)
            }
            let results = parseDuckDuckGoResults(html, maxResults: count)
            let output = results.isEmpty ? "无搜索结果" : results.joined(separator: "\n\n")
            Task { await AgentEventBus.shared.publish(.browser(.pageLoaded(url: url.absoluteString, title: "搜索: \(query)"))) }
            return ToolCallResult(id: UUID().uuidString, output: output)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "搜索失败: \(error.localizedDescription)", isError: true)
        }
    }

    private func parseDuckDuckGoResults(_ html: String, maxResults: Int) -> [String] {
        var results: [String] = []
        let pattern = #"<a[^>]*class="result__a"[^>]*href="([^"]*)"[^>]*>([\s\S]*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, range: nsRange)
        for match in matches.prefix(maxResults) {
            guard let hrefRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html) else { continue }
            let href = String(html[hrefRange])
                .replacingOccurrences(of: "&amp;", with: "&")
            let title = String(html[titleRange])
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            results.append("\(title)\n  \(href)")
        }
        return results
    }
}

public struct WebFetchTool: MCPTool {
    public let definition = ToolDefinition(
        name: "web_fetch",
        description: "获取指定 URL 的文本内容",
        parameters: [
            .init(name: "url", type: .string, description: "要获取的 URL"),
            .init(name: "max_chars", type: .string, description: "最大字符数，默认5000", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }
    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let urlStr = arguments["url"], !urlStr.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: url", isError: true)
        }
        let maxChars = Int(arguments["max_chars"] ?? "5000") ?? 5000
        let finalUrlStr = urlStr.hasPrefix("http") ? urlStr : "https://" + urlStr
        guard let url = URL(string: finalUrlStr) else {
            return ToolCallResult(id: UUID().uuidString, output: "无效 URL: \(urlStr)", isError: true)
        }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return ToolCallResult(id: UUID().uuidString, output: "仅允许 http/https URL", isError: true)
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let raw = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                return ToolCallResult(id: UUID().uuidString, output: "内容解析失败", isError: true)
            }
            let text = stripHTML(raw)
            let truncated = text.count > maxChars ? String(text.prefix(maxChars)) + "\n\n... [截断，共 \(text.count) 字符]" : text
            let output = "URL: \(finalUrlStr)\n大小: \(data.count) bytes\n---\n\(truncated)"
            Task { await AgentEventBus.shared.publish(.browser(.pageLoaded(url: finalUrlStr, title: nil))) }
            return ToolCallResult(id: UUID().uuidString, output: output)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "获取失败: \(error.localizedDescription)", isError: true)
        }
    }

    private func stripHTML(_ html: String) -> String {
        let text = html
            .replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return lines.joined(separator: "\n")
    }
}
