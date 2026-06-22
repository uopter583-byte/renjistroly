import Foundation

public enum ComputerUseTargetKind: String, Sendable, Codable {
    case accessibilityElement
    case ocrText
    case window
    case runningApp
    case coordinate
    case unknown

    public var title: String {
        switch self {
        case .accessibilityElement: "控件"
        case .ocrText: "屏幕文字"
        case .window: "窗口"
        case .runningApp: "运行中 App"
        case .coordinate: "坐标"
        case .unknown: "未知"
        }
    }
}

public struct ComputerUseTarget: Identifiable, Sendable, Codable, Equatable {
    public var id: UUID
    public var kind: ComputerUseTargetKind
    public var label: String
    public var owner: String?
    public var role: String?
    public var boundsDescription: String?
    public var valuePreview: String?
    public var actions: [String]
    public var depth: Int?
    public var confidence: Double

    public init(
        id: UUID = UUID(),
        kind: ComputerUseTargetKind,
        label: String,
        owner: String? = nil,
        role: String? = nil,
        boundsDescription: String? = nil,
        valuePreview: String? = nil,
        actions: [String] = [],
        depth: Int? = nil,
        confidence: Double = 0.5
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.owner = owner
        self.role = role
        self.boundsDescription = boundsDescription
        self.valuePreview = valuePreview
        self.actions = actions
        self.depth = depth
        self.confidence = confidence
    }
}

public struct ComputerUseObservation: Identifiable, Sendable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var frontmostApp: AppContext?
    public var runningApps: [RunningAppContext]
    public var visibleWindows: [VisibleWindowContext]
    public var focusedElement: UIElementContext?
    public var ocrText: String?
    public var targets: [ComputerUseTarget]
    public var compactAXTree: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        frontmostApp: AppContext? = nil,
        runningApps: [RunningAppContext] = [],
        visibleWindows: [VisibleWindowContext] = [],
        focusedElement: UIElementContext? = nil,
        ocrText: String? = nil,
        targets: [ComputerUseTarget] = [],
        compactAXTree: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.frontmostApp = frontmostApp
        self.runningApps = runningApps
        self.visibleWindows = visibleWindows
        self.focusedElement = focusedElement
        self.ocrText = ocrText
        self.targets = targets
        self.compactAXTree = compactAXTree
    }
}

public enum ComputerUseIntentKind: String, Sendable, Codable {
    case observe
    case activateApp
    case quitApp
    case hideApp
    case closeWindow
    case minimizeWindow
    case clickTarget
    case typeText
    case pasteText
    case pressShortcut
    case scroll
    case openURL
    case openPath
    case composeMessage
    case unknown
}

public struct ComputerUseStep: Identifiable, Sendable, Codable, Equatable {
    public var id: UUID
    public var action: MacAction
    public var expectedState: String
    public var requiresObservation: Bool

    public init(
        id: UUID = UUID(),
        action: MacAction,
        expectedState: String,
        requiresObservation: Bool = true
    ) {
        self.id = id
        self.action = action
        self.expectedState = expectedState
        self.requiresObservation = requiresObservation
    }
}

public struct ComputerUsePlan: Identifiable, Sendable, Equatable {
    public var id: UUID
    public var userText: String
    public var intent: ComputerUseIntentKind
    public var target: ComputerUseTarget?
    public var action: MacAction?
    public var steps: [ComputerUseStep]
    public var requiresConfirmation: Bool
    public var reason: String

    public init(
        id: UUID = UUID(),
        userText: String,
        intent: ComputerUseIntentKind,
        target: ComputerUseTarget? = nil,
        action: MacAction? = nil,
        steps: [ComputerUseStep] = [],
        requiresConfirmation: Bool = false,
        reason: String
    ) {
        self.id = id
        self.userText = userText
        self.intent = intent
        self.target = target
        self.action = action
        self.steps = steps
        self.requiresConfirmation = requiresConfirmation
        self.reason = reason
    }
}

public struct ComputerUseStepOutcome: Identifiable, Sendable, Equatable {
    public var id: UUID
    public var step: ComputerUseStep
    public var actionResult: ActionResult
    public var observationID: UUID?
    public var verified: Bool
    public var note: String

    public init(
        id: UUID = UUID(),
        step: ComputerUseStep,
        actionResult: ActionResult,
        observationID: UUID? = nil,
        verified: Bool,
        note: String
    ) {
        self.id = id
        self.step = step
        self.actionResult = actionResult
        self.observationID = observationID
        self.verified = verified
        self.note = note
    }
}

public struct ComputerUseRunOutcome: Identifiable, Sendable, Equatable {
    public var id: UUID
    public var plan: ComputerUsePlan
    public var actionResult: ActionResult?
    public var stepResults: [ComputerUseStepOutcome]
    public var beforeObservationID: UUID?
    public var afterObservationID: UUID?
    public var message: String

    public init(
        id: UUID = UUID(),
        plan: ComputerUsePlan,
        actionResult: ActionResult? = nil,
        stepResults: [ComputerUseStepOutcome] = [],
        beforeObservationID: UUID? = nil,
        afterObservationID: UUID? = nil,
        message: String
    ) {
        self.id = id
        self.plan = plan
        self.actionResult = actionResult
        self.stepResults = stepResults
        self.beforeObservationID = beforeObservationID
        self.afterObservationID = afterObservationID
        self.message = message
    }
}

public enum TerminalTaskStatus: String, Sendable, Codable, Equatable {
    case pending
    case running
    case succeeded
    case failed
    case waiting
    case cancelled

    public var title: String {
        switch self {
        case .pending: "待执行"
        case .running: "运行中"
        case .succeeded: "成功"
        case .failed: "失败"
        case .waiting: "等待"
        case .cancelled: "已取消"
        }
    }
}

public struct TerminalTaskRecord: Identifiable, Sendable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var command: String
    public var workingDirectory: String
    public var status: TerminalTaskStatus
    public var createdAt: Date
    public var updatedAt: Date
    public var lastMessage: String
    public var pid: Int32?
    public var exitCode: Int32?
    public var logPath: String?
    public var exitCodePath: String?
    public var pidPath: String?
    public var outputTail: String?

    public init(
        id: UUID = UUID(),
        name: String,
        command: String,
        workingDirectory: String,
        status: TerminalTaskStatus = .pending,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastMessage: String = "",
        pid: Int32? = nil,
        exitCode: Int32? = nil,
        logPath: String? = nil,
        exitCodePath: String? = nil,
        pidPath: String? = nil,
        outputTail: String? = nil
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.workingDirectory = workingDirectory
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastMessage = lastMessage
        self.pid = pid
        self.exitCode = exitCode
        self.logPath = logPath
        self.exitCodePath = exitCodePath
        self.pidPath = pidPath
        self.outputTail = outputTail
    }
}
