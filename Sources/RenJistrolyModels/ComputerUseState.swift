import Foundation

public struct ComputerUseAppState: Codable, Sendable, Hashable {
    public let capturedAt: Date
    public let requestedApp: String?
    public let activeAppBundleID: String?
    public let activeAppName: String?
    public let focusedWindowTitle: String?
    public let windows: [ComputerUseWindow]
    public let elements: [ComputerUseElement]
    public let screenshotPNGBase64: String?

    public init(
        capturedAt: Date = Date(),
        requestedApp: String? = nil,
        activeAppBundleID: String? = nil,
        activeAppName: String? = nil,
        focusedWindowTitle: String? = nil,
        windows: [ComputerUseWindow] = [],
        elements: [ComputerUseElement] = [],
        screenshotPNGBase64: String? = nil
    ) {
        self.capturedAt = capturedAt
        self.requestedApp = requestedApp
        self.activeAppBundleID = activeAppBundleID
        self.activeAppName = activeAppName
        self.focusedWindowTitle = focusedWindowTitle
        self.windows = windows
        self.elements = elements
        self.screenshotPNGBase64 = screenshotPNGBase64
    }

    public func jsonString(pretty: Bool = true, includeScreenshot: Bool = false) -> String {
        let value = includeScreenshot ? self : withoutScreenshot()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if pretty {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }

    public func withoutScreenshot() -> ComputerUseAppState {
        ComputerUseAppState(
            capturedAt: capturedAt,
            requestedApp: requestedApp,
            activeAppBundleID: activeAppBundleID,
            activeAppName: activeAppName,
            focusedWindowTitle: focusedWindowTitle,
            windows: windows,
            elements: elements,
            screenshotPNGBase64: nil
        )
    }
}

public struct ComputerUseWindow: Codable, Sendable, Hashable {
    public let title: String
    public let frame: CodableRect?
    public let isMain: Bool
    public let isFocused: Bool

    public init(title: String, frame: CodableRect? = nil, isMain: Bool = false, isFocused: Bool = false) {
        self.title = title
        self.frame = frame
        self.isMain = isMain
        self.isFocused = isFocused
    }
}

public struct ComputerUseElement: Codable, Sendable, Hashable {
    public let elementIndex: String
    public let stableID: String
    public let role: String
    public let title: String?
    public let value: String?
    public let description: String?
    public let help: String?
    public let frame: CodableRect?
    public let enabled: Bool?
    public let focused: Bool?
    public let depth: Int
    public let childPath: [Int]

    public init(
        elementIndex: String,
        stableID: String? = nil,
        role: String,
        title: String? = nil,
        value: String? = nil,
        description: String? = nil,
        help: String? = nil,
        frame: CodableRect? = nil,
        enabled: Bool? = nil,
        focused: Bool? = nil,
        depth: Int,
        childPath: [Int]
    ) {
        self.elementIndex = elementIndex
        self.stableID = stableID ?? Self.makeStableID(
            role: role,
            title: title,
            value: value,
            description: description,
            help: help,
            childPath: childPath
        )
        self.role = role
        self.title = title
        self.value = value
        self.description = description
        self.help = help
        self.frame = frame
        self.enabled = enabled
        self.focused = focused
        self.depth = depth
        self.childPath = childPath
    }

    public var compactLabel: String {
        [title, value, description, help]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? role
    }

    private static func makeStableID(
        role: String,
        title: String?,
        value: String?,
        description: String?,
        help: String?,
        childPath: [Int]
    ) -> String {
        let rawLabel = [title, value, description, help]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .first { !$0.isEmpty }
        let label = rawLabel?
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            ?? "node"
        let path = childPath.map(String.init).joined(separator: ".")
        return path.isEmpty ? "\(role.lowercased()):\(label)" : "\(role.lowercased()):\(path):\(label)"
    }
}

public struct CodableRect: Codable, Sendable, Hashable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct ComputerUseStateDelta: Codable, Sendable, Hashable {
    public let activeAppChanged: Bool
    public let focusedWindowChanged: Bool
    public let focusedElementChanged: Bool
    public let elementCountChanged: Bool
    public let visibleTextChanged: Bool

    public init(before: ComputerUseAppState, after: ComputerUseAppState) {
        activeAppChanged = before.activeAppBundleID != after.activeAppBundleID
            || before.activeAppName != after.activeAppName
        focusedWindowChanged = before.focusedWindowTitle != after.focusedWindowTitle
        focusedElementChanged = Self.focusedElementFingerprint(in: before) != Self.focusedElementFingerprint(in: after)
        elementCountChanged = before.elements.count != after.elements.count
        visibleTextChanged = Self.visibleTextFingerprint(in: before) != Self.visibleTextFingerprint(in: after)
    }

    public var hasMeaningfulChange: Bool {
        activeAppChanged
            || focusedWindowChanged
            || focusedElementChanged
            || elementCountChanged
            || visibleTextChanged
    }

    public var changeDescriptions: [String] {
        var descriptions: [String] = []
        if activeAppChanged {
            descriptions.append("前台应用变化")
        }
        if focusedWindowChanged {
            descriptions.append("焦点窗口变化")
        }
        if focusedElementChanged {
            descriptions.append("焦点控件变化")
        }
        if elementCountChanged {
            descriptions.append("界面元素数量变化")
        }
        if visibleTextChanged {
            descriptions.append("可见文本变化")
        }
        return descriptions
    }

    public var summary: String {
        let descriptions = changeDescriptions
        return descriptions.isEmpty ? "未观察到明显状态变化" : descriptions.joined(separator: "，")
    }

    private static func focusedElementFingerprint(in state: ComputerUseAppState) -> String? {
        state.elements.first { $0.focused == true }.map { element in
            [
                element.elementIndex,
                element.role,
                element.compactLabel,
                element.frame.map { "\($0.x),\($0.y),\($0.width),\($0.height)" },
            ]
            .compactMap(\.self)
            .joined(separator: "|")
        }
    }

    private static func visibleTextFingerprint(in state: ComputerUseAppState) -> String {
        state.elements
            .map(\.compactLabel)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: "\n")
    }
}
