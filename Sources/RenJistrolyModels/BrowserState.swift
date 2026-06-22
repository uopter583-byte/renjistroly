import Foundation

public struct BrowserPageState: Codable, Sendable, Hashable {
    public let browserName: String
    public let windowTitle: String?
    public let tabTitle: String?
    public let url: String?
    public let host: String?
    public let searchQuery: String?

    public init(
        browserName: String,
        windowTitle: String? = nil,
        tabTitle: String? = nil,
        url: String? = nil,
        host: String? = nil,
        searchQuery: String? = nil
    ) {
        self.browserName = browserName
        self.windowTitle = windowTitle
        self.tabTitle = tabTitle
        self.url = url
        self.host = host
        self.searchQuery = searchQuery
    }
}

public struct BrowserDOMElement: Codable, Sendable, Hashable {
    public let tag: String
    public let text: String?
    public let value: String?
    public let href: String?
    public let visible: Bool
    public let rect: BrowserDOMRect?

    public init(
        tag: String,
        text: String? = nil,
        value: String? = nil,
        href: String? = nil,
        visible: Bool = true,
        rect: BrowserDOMRect? = nil
    ) {
        self.tag = tag
        self.text = text
        self.value = value
        self.href = href
        self.visible = visible
        self.rect = rect
    }
}

public struct BrowserDOMRect: Codable, Sendable, Hashable {
    public let x: Double
    public let y: Double
    public let w: Double
    public let h: Double

    public init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }
}
