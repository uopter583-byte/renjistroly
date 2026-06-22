import Foundation

// MARK: - System Context (536-545)

public struct ScreenContextSnapshot: Sendable, Codable, Equatable {
    public let displayID: String?
    public let displayDescription: String
    public let capturedAt: Date
    public let recognizedText: String?
    public let visibleAppNames: [String]

    public init(
        displayID: String? = nil,
        displayDescription: String = "",
        capturedAt: Date = Date(),
        recognizedText: String? = nil,
        visibleAppNames: [String] = []
    ) {
        self.displayID = displayID
        self.displayDescription = displayDescription
        self.capturedAt = capturedAt
        self.recognizedText = recognizedText
        self.visibleAppNames = visibleAppNames
    }
}

public struct AppContextSnapshot: Sendable, Codable, Equatable {
    public let appName: String
    public let bundleID: String?
    public let isResponsive: Bool
    public let cpuUsage: Double?
    public let memoryUsage: UInt64?

    public init(
        appName: String = "",
        bundleID: String? = nil,
        isResponsive: Bool = true,
        cpuUsage: Double? = nil,
        memoryUsage: UInt64? = nil
    ) {
        self.appName = appName
        self.bundleID = bundleID
        self.isResponsive = isResponsive
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
    }
}

public struct WindowContextSnapshot: Sendable, Codable, Equatable {
    public let title: String?
    public let frame: String?
    public let isMinimized: Bool
    public let isMain: Bool

    public init(
        title: String? = nil,
        frame: String? = nil,
        isMinimized: Bool = false,
        isMain: Bool = false
    ) {
        self.title = title
        self.frame = frame
        self.isMinimized = isMinimized
        self.isMain = isMain
    }
}

public struct FocusContextSnapshot: Sendable, Codable, Equatable {
    public let elementRole: String?
    public let elementTitle: String?
    public let elementValue: String?
    public let isTextField: Bool
    public let isEditable: Bool

    public init(
        elementRole: String? = nil,
        elementTitle: String? = nil,
        elementValue: String? = nil,
        isTextField: Bool = false,
        isEditable: Bool = false
    ) {
        self.elementRole = elementRole
        self.elementTitle = elementTitle
        self.elementValue = elementValue
        self.isTextField = isTextField
        self.isEditable = isEditable
    }
}

public struct SelectionContextSnapshot: Sendable, Codable, Equatable {
    public let selectedText: String?
    public let sourceApp: String?
    public let length: Int

    public init(selectedText: String? = nil, sourceApp: String? = nil) {
        self.selectedText = selectedText
        self.sourceApp = sourceApp
        self.length = selectedText?.count ?? 0
    }
}

public struct ClipboardRiskSnapshot: Sendable, Codable, Equatable {
    public let hasContent: Bool
    public let contentType: String?
    public let containsSensitivePattern: Bool
    public let riskLevel: EnterpriseRiskLevel
    public let suggestion: String

    public init(
        hasContent: Bool = false,
        contentType: String? = nil,
        containsSensitivePattern: Bool = false,
        riskLevel: EnterpriseRiskLevel = .low,
        suggestion: String = ""
    ) {
        self.hasContent = hasContent
        self.contentType = contentType
        self.containsSensitivePattern = containsSensitivePattern
        self.riskLevel = riskLevel
        self.suggestion = suggestion
    }

    public static func == (lhs: ClipboardRiskSnapshot, rhs: ClipboardRiskSnapshot) -> Bool {
        lhs.hasContent == rhs.hasContent &&
        lhs.contentType == rhs.contentType &&
        lhs.containsSensitivePattern == rhs.containsSensitivePattern &&
        lhs.riskLevel == rhs.riskLevel &&
        lhs.suggestion == rhs.suggestion
    }
}

public struct TaskContextSnapshot: Sendable, Codable, Equatable {
    public let currentTask: String?
    public let taskHistory: [String]
    public let progress: Double
    public let remainingSteps: Int

    public init(
        currentTask: String? = nil,
        taskHistory: [String] = [],
        progress: Double = 0,
        remainingSteps: Int = 0
    ) {
        self.currentTask = currentTask
        self.taskHistory = taskHistory
        self.progress = progress
        self.remainingSteps = remainingSteps
    }
}

public struct ModelContextSnapshot: Sendable, Codable, Equatable {
    public let provider: String?
    public let modelName: String?
    public let contextWindow: Int
    public let tokensUsed: Int
    public let tokensRemaining: Int

    public init(
        provider: String? = nil,
        modelName: String? = nil,
        contextWindow: Int = 0,
        tokensUsed: Int = 0,
        tokensRemaining: Int = 0
    ) {
        self.provider = provider
        self.modelName = modelName
        self.contextWindow = contextWindow
        self.tokensUsed = tokensUsed
        self.tokensRemaining = tokensRemaining
    }
}

public struct PermissionContextSnapshot: Sendable, Codable, Equatable {
    public let allGranted: Bool
    public let permissions: [String: Bool]
    public let missingPermissions: [String]

    public init(
        allGranted: Bool = false,
        permissions: [String: Bool] = [:],
        missingPermissions: [String] = []
    ) {
        self.allGranted = allGranted
        self.permissions = permissions
        self.missingPermissions = missingPermissions
    }
}

public struct SecurityModeContextSnapshot: Sendable, Codable, Equatable {
    public let activeModes: [String]
    public let lockedModes: [String]
    public let effectiveRiskLimit: String
    public let isLocked: Bool

    public init(
        activeModes: [String] = [],
        lockedModes: [String] = [],
        effectiveRiskLimit: String = "critical",
        isLocked: Bool = false
    ) {
        self.activeModes = activeModes
        self.lockedModes = lockedModes
        self.effectiveRiskLimit = effectiveRiskLimit
        self.isLocked = isLocked
    }
}

public struct HealthStatusSnapshot: Sendable, Codable, Equatable {
    public let appResponsive: Bool
    public let isForeground: Bool
    public let memoryUsageMB: Double
    public let cpuUsagePercent: Double
    public let isMCPProcessAlive: Bool
    public let isScreenStreamHealthy: Bool
    public let warnings: [String]
    public let capturedAt: Date

    public init(
        appResponsive: Bool = true,
        isForeground: Bool = true,
        memoryUsageMB: Double = 0,
        cpuUsagePercent: Double = 0,
        isMCPProcessAlive: Bool = false,
        isScreenStreamHealthy: Bool = false,
        warnings: [String] = [],
        capturedAt: Date = Date()
    ) {
        self.appResponsive = appResponsive
        self.isForeground = isForeground
        self.memoryUsageMB = memoryUsageMB
        self.cpuUsagePercent = cpuUsagePercent
        self.isMCPProcessAlive = isMCPProcessAlive
        self.isScreenStreamHealthy = isScreenStreamHealthy
        self.warnings = warnings
        self.capturedAt = capturedAt
    }
}

// MARK: - System Context

public struct SystemContext: Sendable, Codable, Equatable {
    public let screen: ScreenContextSnapshot
    public let app: AppContextSnapshot
    public let window: WindowContextSnapshot
    public let focus: FocusContextSnapshot
    public let selection: SelectionContextSnapshot
    public let clipboardRisk: ClipboardRiskSnapshot
    public let task: TaskContextSnapshot
    public let model: ModelContextSnapshot
    public let permission: PermissionContextSnapshot
    public let securityMode: SecurityModeContextSnapshot
    public let capturedAt: Date

    public init(
        screen: ScreenContextSnapshot = .init(),
        app: AppContextSnapshot = .init(),
        window: WindowContextSnapshot = .init(),
        focus: FocusContextSnapshot = .init(),
        selection: SelectionContextSnapshot = .init(),
        clipboardRisk: ClipboardRiskSnapshot = ClipboardRiskSnapshot(),
        task: TaskContextSnapshot = .init(),
        model: ModelContextSnapshot = .init(),
        permission: PermissionContextSnapshot = .init(),
        securityMode: SecurityModeContextSnapshot = .init(),
        capturedAt: Date = Date()
    ) {
        self.screen = screen
        self.app = app
        self.window = window
        self.focus = focus
        self.selection = selection
        self.clipboardRisk = clipboardRisk
        self.task = task
        self.model = model
        self.permission = permission
        self.securityMode = securityMode
        self.capturedAt = capturedAt
    }

    public static func == (lhs: SystemContext, rhs: SystemContext) -> Bool {
        lhs.screen.displayID == rhs.screen.displayID &&
        lhs.screen.displayDescription == rhs.screen.displayDescription &&
        lhs.screen.recognizedText == rhs.screen.recognizedText &&
        lhs.screen.visibleAppNames == rhs.screen.visibleAppNames &&
        lhs.app == rhs.app &&
        lhs.window == rhs.window &&
        lhs.focus == rhs.focus &&
        lhs.selection == rhs.selection &&
        lhs.clipboardRisk == rhs.clipboardRisk &&
        lhs.task == rhs.task &&
        lhs.model == rhs.model &&
        lhs.permission == rhs.permission &&
        lhs.securityMode == rhs.securityMode
    }
}

// MARK: - Context Manager

public protocol ContextProviderProtocol: AnyObject, Sendable {
    func captureScreenContext() async -> ScreenContextSnapshot
    func captureAppContext() async -> AppContextSnapshot
    func captureWindowContext() async -> WindowContextSnapshot
    func captureFocusContext() async -> FocusContextSnapshot
    func captureSelectionContext() async -> SelectionContextSnapshot
    func captureClipboardRisk() async -> ClipboardRiskSnapshot
    func captureTaskContext() async -> TaskContextSnapshot
    func captureModelContext() async -> ModelContextSnapshot
    func capturePermissionContext() async -> PermissionContextSnapshot
    func captureSecurityModeContext() async -> SecurityModeContextSnapshot
    func captureHealthStatus() async -> HealthStatusSnapshot
}

@MainActor
public final class ContextManager {
    public private(set) var lastContext: SystemContext?
    public var provider: ContextProviderProtocol?

    private var cacheExpiry: TimeInterval = 10
    private var cachedHealth: HealthStatusSnapshot?
    private var healthTimestamp: Date?

    public init(provider: ContextProviderProtocol? = nil) {
        self.provider = provider
    }

    public func refresh() async -> SystemContext {
        let p = provider

        let ctx = SystemContext(
            screen: await p?.captureScreenContext() ?? .init(),
            app: await p?.captureAppContext() ?? .init(),
            window: await p?.captureWindowContext() ?? .init(),
            focus: await p?.captureFocusContext() ?? .init(),
            selection: await p?.captureSelectionContext() ?? .init(),
            clipboardRisk: await p?.captureClipboardRisk() ?? ClipboardRiskSnapshot(),
            task: await p?.captureTaskContext() ?? .init(),
            model: await p?.captureModelContext() ?? .init(),
            permission: await p?.capturePermissionContext() ?? .init(),
            securityMode: await p?.captureSecurityModeContext() ?? .init()
        )
        lastContext = ctx
        return ctx
    }

    public func snapshot() -> SystemContext {
        lastContext ?? SystemContext()
    }

    /// Returns cached health status, refreshing if stale (> 10 seconds old).
    public func healthStatus() async -> HealthStatusSnapshot {
        let now = Date()
        if let health = cachedHealth, let ts = healthTimestamp, now.timeIntervalSince(ts) < cacheExpiry {
            return health
        }
        let p = provider
        let fresh = await withTimeout(seconds: 15, defaultValue: HealthStatusSnapshot()) {
            await p?.captureHealthStatus() ?? HealthStatusSnapshot()
        }
        cachedHealth = fresh
        healthTimestamp = now
        return fresh
    }

    private func withTimeout<T: Sendable>(seconds: TimeInterval, defaultValue: T, operation: @escaping @Sendable () async -> T) async -> T {
        await withTaskGroup(of: T.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return defaultValue
            }
            let result = await group.next() ?? defaultValue
            group.cancelAll()
            return result
        }
    }

    public func summary() -> String {
        let ctx = snapshot()
        var parts: [String] = ["=== 系统上下文 ==="]
        if !ctx.app.appName.isEmpty {
            parts.append("App: \(ctx.app.appName)")
        }
        if let title = ctx.window.title, !title.isEmpty {
            parts.append("窗口: \(title)")
        }
        if let text = ctx.selection.selectedText, !text.isEmpty {
            let preview = text.prefix(100)
            parts.append("选中: \(preview)")
        }
        if !ctx.securityMode.activeModes.isEmpty {
            parts.append("安全模式: \(ctx.securityMode.activeModes.joined(separator: ", "))")
        }
        parts.append("时间: \(ctx.capturedAt)")
        return parts.joined(separator: "\n")
    }

    public func setCacheExpiry(_ interval: TimeInterval) {
        cacheExpiry = interval
    }
}
