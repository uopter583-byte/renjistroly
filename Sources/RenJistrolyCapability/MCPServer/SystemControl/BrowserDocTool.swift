import Foundation
import os
import RenJistrolyModels

// =============================================================================
// 文档查阅工具 — Browser Documentation
// 439: BrowserDoc
// =============================================================================

// MARK: - 439: 浏览器文档查阅

public struct BrowserDocTool: MCPTool {
    public let definition = ToolDefinition(
        name: "browser_doc",
        description: """
        浏览器文档查阅工具。支持搜索文档、打开书签和查看浏览历史。
        模拟开发者查阅技术文档的场景。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: search(搜索) / open_bookmark(打开书签) / bookmark_history(书签历史)",
                  required: true),
            .init(name: "query", type: .string,
                  description: "搜索关键词 (action=search 时需要)", required: false),
            .init(name: "bookmark_name", type: .string,
                  description: "书签名称 (action=open_bookmark 时需要)", required: false),
            .init(name: "category", type: .string,
                  description: "书签分类: swift/swiftui/xcode/backend/tools", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private struct Bookmark {
        let name: String
        let url: String
        let category: String
    }

    private static nonisolated(unsafe) var bookmarks: [Bookmark] = [
        .init(name: "Swift 官方文档", url: "https://docs.swift.org/swift-book/", category: "swift"),
        .init(name: "SwiftUI 教程", url: "https://developer.apple.com/tutorials/swiftui", category: "swiftui"),
        .init(name: "Apple 开发者文档", url: "https://developer.apple.com/documentation", category: "xcode"),
        .init(name: "Swift Package Manager", url: "https://github.com/apple/swift-package-manager", category: "tools"),
        .init(name: "Swift 进化提案", url: "https://apple.github.io/swift-evolution/", category: "swift"),
        .init(name: "SwiftUI Lab", url: "https://swiftui-lab.com", category: "swiftui"),
        .init(name: "Apple 人机交互指南", url: "https://developer.apple.com/design/human-interface-guidelines", category: "xcode"),
        .init(name: "WWDC 视频", url: "https://developer.apple.com/wwdc", category: "xcode"),
        .init(name: "GitHub 文档", url: "https://docs.github.com", category: "tools"),
        .init(name: "macOS 开发文档", url: "https://developer.apple.com/documentation/appkit", category: "xcode"),
    ]

    private static nonisolated(unsafe) var history: [String] = []

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "search"

        switch action {
        case "search":
            let query = arguments["query"] ?? ""
            guard !query.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 query 参数", isError: true)
            }
            Self.history.append("搜索: \(query)")
            let matched = Self.bookmarks.filter {
                $0.name.lowercased().contains(query.lowercased()) ||
                $0.category.lowercased().contains(query.lowercased())
            }
            if matched.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: """
                    搜索「\(query)」无匹配书签。
                    建议: 使用 WebSearch 工具进行网络搜索获取最新文档。
                    """)
            }
            let results = matched.map { "- \($0.name) (\($0.url)) [分类: \($0.category)]" }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: """
                文档搜索结果「\(query)」:
                \(results)
                """)

        case "open_bookmark":
            let name = arguments["bookmark_name"] ?? ""
            let category = arguments["category"] ?? ""
            let matched: [Bookmark]
            if !name.isEmpty {
                matched = Self.bookmarks.filter { $0.name.lowercased().contains(name.lowercased()) }
            } else if !category.isEmpty {
                matched = Self.bookmarks.filter { $0.category == category }
            } else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 bookmark_name 或 category 参数", isError: true)
            }

            guard let bookmark = matched.first else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到匹配的书签。")
            }
            Self.history.append("打开书签: \(bookmark.name)")
            return ToolCallResult(id: UUID().uuidString, output: """
                打开书签:
                名称: \(bookmark.name)
                链接: \(bookmark.url)
                分类: \(bookmark.category)
                """)

        case "bookmark_history":
            if Self.history.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: """
                    暂无浏览历史。

                    可用书签分类:
                    - swift: Swift 语言相关
                    - swiftui: SwiftUI 框架
                    - xcode: Xcode 开发工具
                    - tools: 开发工具

                    使用示例:
                    - browser_doc action=search query=SwiftUI 搜索文档
                    - browser_doc action=open_bookmark bookmark_name="Swift 官方文档"
                    """)
            }
            let historyList = Self.history.enumerated().map { "\($0 + 1). \($1)" }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "浏览历史:\n\(historyList)")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}
