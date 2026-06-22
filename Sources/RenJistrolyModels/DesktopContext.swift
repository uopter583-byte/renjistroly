import Foundation

public struct DesktopContext: Codable, Sendable, Hashable {
    public let capturedAt: Date
    public let activeAppBundleID: String?
    public let activeAppName: String?
    public let focusedWindowTitle: String?
    public let focusedElementRole: String?
    public let focusedElementValue: String?
    public let selectedText: String?
    public let browserPageState: BrowserPageState?
    public let finderWindowState: FinderWindowState?
    public let windows: [DesktopWindow]
    public let uiElements: [DesktopUIElement]
    public let projectContext: ProjectContext?

    public init(
        capturedAt: Date = Date(),
        activeAppBundleID: String? = nil,
        activeAppName: String? = nil,
        focusedWindowTitle: String? = nil,
        focusedElementRole: String? = nil,
        focusedElementValue: String? = nil,
        selectedText: String? = nil,
        browserPageState: BrowserPageState? = nil,
        finderWindowState: FinderWindowState? = nil,
        windows: [DesktopWindow] = [],
        uiElements: [DesktopUIElement] = [],
        projectContext: ProjectContext? = nil
    ) {
        self.capturedAt = capturedAt
        self.activeAppBundleID = activeAppBundleID
        self.activeAppName = activeAppName
        self.focusedWindowTitle = focusedWindowTitle
        self.focusedElementRole = focusedElementRole
        self.focusedElementValue = focusedElementValue
        self.selectedText = selectedText
        self.browserPageState = browserPageState
        self.finderWindowState = finderWindowState
        self.windows = windows
        self.uiElements = uiElements
        self.projectContext = projectContext
    }

    public func promptSummary(
        maxSelectedTextLength: Int = 800,
        maxFocusedValueLength: Int = 400,
        maxUIElements: Int = 40
    ) -> String {
        var lines: [String] = ["当前桌面上下文:"]

        if let activeAppName {
            lines.append("- 前台应用: \(activeAppName)")
        }
        if let activeAppBundleID {
            lines.append("- 前台应用 Bundle ID: \(activeAppBundleID)")
        }
        if let focusedWindowTitle {
            lines.append("- 当前窗口: \(focusedWindowTitle)")
        }
        if let focusedElementRole {
            lines.append("- 焦点控件角色: \(focusedElementRole)")
        }
        if let focusedElementValue, !focusedElementValue.isEmpty {
            lines.append("- 焦点控件内容: \(String(focusedElementValue.prefix(maxFocusedValueLength)))")
        }
        if let selectedText, !selectedText.isEmpty {
            lines.append("- 选中文本:\n```\n\(String(selectedText.prefix(maxSelectedTextLength)))\n```")
        }
        if let browserPageState {
            lines.append("- 浏览器页面: \(browserPageState.browserName)")
            if let tabTitle = browserPageState.tabTitle, !tabTitle.isEmpty {
                lines.append("- 当前标签页: \(tabTitle)")
            }
            if let host = browserPageState.host, !host.isEmpty {
                lines.append("- 页面域名: \(host)")
            }
            if let searchQuery = browserPageState.searchQuery, !searchQuery.isEmpty {
                lines.append("- 搜索词: \(searchQuery)")
            }
            if let url = browserPageState.url, !url.isEmpty {
                lines.append("- 页面 URL: \(url)")
            }
        }
        if let finderWindowState {
            lines.append("- Finder 状态:")
            if let windowTitle = finderWindowState.windowTitle, !windowTitle.isEmpty {
                lines.append("- Finder 窗口: \(windowTitle)")
            }
            if let currentPath = finderWindowState.currentPath, !currentPath.isEmpty {
                lines.append("- Finder 当前目录: \(currentPath)")
            }
            if !finderWindowState.selectedItems.isEmpty {
                lines.append("- Finder 已选中: \(finderWindowState.selectedItems.prefix(3).joined(separator: " | "))")
            }
        }
        if !windows.isEmpty {
            let windowTitles = windows.prefix(10).map(\.title).filter { !$0.isEmpty }
            if !windowTitles.isEmpty {
                lines.append("- 当前应用窗口: \(windowTitles.joined(separator: " | "))")
            }
        }
        if !uiElements.isEmpty {
            lines.append("- 可见 UI 元素:")
            for element in uiElements.prefix(maxUIElements) {
                let indent = String(repeating: "  ", count: min(element.depth, 4))
                let title = element.title.map { " \"\($0)\"" } ?? ""
                let description = element.description.map { " [\($0)]" } ?? ""
                lines.append("  \(indent)- \(element.role)\(title)\(description)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

public struct DesktopWindow: Codable, Sendable, Hashable {
    public let title: String

    public init(title: String) {
        self.title = title
    }
}

public struct DesktopUIElement: Codable, Sendable, Hashable {
    public let role: String
    public let title: String?
    public let description: String?
    public let depth: Int

    public init(role: String, title: String? = nil, description: String? = nil, depth: Int) {
        self.role = role
        self.title = title
        self.description = description
        self.depth = depth
    }
}
