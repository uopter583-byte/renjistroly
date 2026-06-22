import CoreGraphics
import Foundation

// MARK: - Cursor state

public struct CursorState: Sendable, Equatable {
    public let position: CGPoint
    public let screenName: String?

    public init(position: CGPoint, screenName: String? = nil) {
        self.position = position
        self.screenName = screenName
    }
}

// MARK: - Dialog / sheet notification

public struct ActiveDialogState: Sendable, Equatable, Identifiable {
    public var id: String { "\(appName)-\(title ?? "")" }
    public let appName: String
    public let title: String?
    public let role: String // kAXSheetCreatedNotification, kAXDrawerCreatedNotification, etc.
    public let detectedAt: Date

    public init(appName: String, title: String?, role: String, detectedAt: Date = Date()) {
        self.appName = appName
        self.title = title
        self.role = role
        self.detectedAt = detectedAt
    }
}

// MARK: - App context

public struct AppContext: Sendable, Equatable {
    public let appName: String
    public let bundleIdentifier: String?
    public let windowTitle: String?

    public init(appName: String, bundleIdentifier: String? = nil, windowTitle: String? = nil) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
    }
}

public struct RunningAppContext: Sendable, Equatable, Codable, Identifiable {
    public var id: String { bundleIdentifier ?? appName }
    public let appName: String
    public let bundleIdentifier: String?
    public let isFrontmost: Bool

    public init(appName: String, bundleIdentifier: String? = nil, isFrontmost: Bool = false) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.isFrontmost = isFrontmost
    }
}

public struct UIElementContext: Sendable, Equatable {
    public let role: String?
    public let title: String?
    public let value: String?
    public let selectedText: String?

    public init(role: String? = nil, title: String? = nil, value: String? = nil, selectedText: String? = nil) {
        self.role = role
        self.title = title
        self.value = value
        self.selectedText = selectedText
    }
}

public struct ScreenContext: Sendable, Equatable {
    public let capturedAt: Date
    public let displayDescription: String
    public let imageData: Data?
    public let recognizedText: String?
    public let visibleWindows: [VisibleWindowContext]
    public var cursorPosition: CGPoint?

    public init(
        capturedAt: Date = Date(),
        displayDescription: String,
        imageData: Data? = nil,
        recognizedText: String? = nil,
        visibleWindows: [VisibleWindowContext] = [],
        cursorPosition: CGPoint? = nil
    ) {
        self.capturedAt = capturedAt
        self.displayDescription = displayDescription
        self.imageData = imageData
        self.recognizedText = recognizedText
        self.visibleWindows = visibleWindows
        self.cursorPosition = cursorPosition
    }
}

public struct VisibleWindowContext: Sendable, Codable, Equatable, Identifiable {
    public var id: String { "\(ownerName)-\(windowTitle ?? "")-\(layer)-\(boundsDescription)" }
    public let ownerName: String
    public let windowTitle: String?
    public let layer: Int
    public let boundsDescription: String

    public init(ownerName: String, windowTitle: String? = nil, layer: Int, boundsDescription: String) {
        self.ownerName = ownerName
        self.windowTitle = windowTitle
        self.layer = layer
        self.boundsDescription = boundsDescription
    }
}

public struct AssistantContext: Sendable, Equatable {
    public var app: AppContext?
    public var runningApps: [RunningAppContext]
    public var focusedElement: UIElementContext?
    public var screen: ScreenContext?
    public var activeDialogs: [ActiveDialogState]

    public init(
        app: AppContext? = nil,
        runningApps: [RunningAppContext] = [],
        focusedElement: UIElementContext? = nil,
        screen: ScreenContext? = nil,
        activeDialogs: [ActiveDialogState] = []
    ) {
        self.app = app
        self.runningApps = runningApps
        self.focusedElement = focusedElement
        self.screen = screen
        self.activeDialogs = activeDialogs
    }
}
