import Foundation

public enum AgentTaskStatus: String, Codable, Sendable, Hashable {
    case queued
    case running
    case waitingForConfirmation
    case paused
    case completed
    case failed
    case cancelled
}

public struct DeveloperAgentEvent: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let kind: String
    public let summary: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        kind: String,
        summary: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
        self.summary = summary
    }
}

public struct AgentTimelineEvent: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let source: String
    public let kind: String
    public let summary: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        source: String,
        kind: String,
        summary: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.kind = kind
        self.summary = summary
    }
}

public struct DeveloperAgentTask: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let prompt: String
    public let cwd: String?
    public let createdAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?
    public var status: AgentTaskStatus
    public var output: String
    public var exitCode: Int32?
    public var changedFiles: [String]
    public var commandsRun: [String]
    public var buildSummary: String?
    public var testSummary: String?
    public var resultSummary: String?
    public var pendingApprovalSummary: String?
    public var events: [DeveloperAgentEvent]
    public var retryCount: Int
    public var dependsOn: [UUID]
    public var blockedBy: [UUID]

    public init(
        id: UUID = UUID(),
        prompt: String,
        cwd: String? = nil,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        finishedAt: Date? = nil,
        status: AgentTaskStatus = .queued,
        output: String = "",
        exitCode: Int32? = nil,
        changedFiles: [String] = [],
        commandsRun: [String] = [],
        buildSummary: String? = nil,
        testSummary: String? = nil,
        resultSummary: String? = nil,
        pendingApprovalSummary: String? = nil,
        events: [DeveloperAgentEvent] = [],
        retryCount: Int = 0,
        dependsOn: [UUID] = [],
        blockedBy: [UUID] = []
    ) {
        self.id = id
        self.prompt = prompt
        self.cwd = cwd
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.status = status
        self.output = output
        self.exitCode = exitCode
        self.changedFiles = changedFiles
        self.commandsRun = commandsRun
        self.buildSummary = buildSummary
        self.testSummary = testSummary
        self.resultSummary = resultSummary
        self.pendingApprovalSummary = pendingApprovalSummary
        self.events = events
        self.retryCount = retryCount
        self.dependsOn = dependsOn
        self.blockedBy = blockedBy
    }

}

public struct MemoryPattern: Codable, Sendable, Hashable, Identifiable {
    public var id: String { pattern }
    public let pattern: String
    public let sourceTaskCount: Int
    public let successRate: Double
    public let kind: Kind

    public enum Kind: String, Codable, Sendable, Hashable {
        case stepPattern
        case workflowSequence
        case learnedWorkflow
    }

    public init(
        pattern: String,
        sourceTaskCount: Int,
        successRate: Double,
        kind: Kind
    ) {
        self.pattern = pattern
        self.sourceTaskCount = sourceTaskCount
        self.successRate = successRate
        self.kind = kind
    }
}

public struct TaskAggregation: Codable, Sendable, Hashable {
    public let totalTasks: Int
    public let completed: Int
    public let failed: Int
    public let pending: Int
    public let changedFiles: [String]
    public let commandsRun: [String]
    public let combinedOutput: String
    public let summaries: [String]
    public let allSucceeded: Bool

    public init(
        totalTasks: Int,
        completed: Int,
        failed: Int,
        pending: Int,
        changedFiles: [String],
        commandsRun: [String],
        combinedOutput: String,
        summaries: [String],
        allSucceeded: Bool
    ) {
        self.totalTasks = totalTasks
        self.completed = completed
        self.failed = failed
        self.pending = pending
        self.changedFiles = changedFiles
        self.commandsRun = commandsRun
        self.combinedOutput = combinedOutput
        self.summaries = summaries
        self.allSucceeded = allSucceeded
    }
}

public struct SafetyAuditRecord: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let timestamp: Date
    public let assessment: ToolRiskAssessment
    public let decision: Decision
    public let note: String?
    public let traceabilityID: String?

    public enum Decision: String, Codable, Sendable, Hashable {
        case autoAllowed
        case allowedOnce
        case alwaysAllowed
        case denied
        case blocked
    }

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        assessment: ToolRiskAssessment,
        decision: Decision,
        note: String? = nil,
        traceabilityID: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.assessment = assessment
        self.decision = decision
        self.note = note
        self.traceabilityID = traceabilityID
    }
}

public enum FailureCategory: String, Codable, Sendable, CaseIterable {
    case timeout
    case permissionDenied
    case elementNotFound
    case networkError
    case buildError
    case testFailure
    case appUnresponsive
    case unknown
}

public struct TaskMemory: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let task: String
    public let steps: [String]
    public let success: Bool
    public let failureReason: String?
    public let failureCategory: FailureCategory?
    public let learnedWorkflow: String?
    public let domain: String?
    public let appName: String?
    public let projectPath: String?
    public let tags: [String]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        task: String,
        steps: [String],
        success: Bool,
        failureReason: String? = nil,
        failureCategory: FailureCategory? = nil,
        learnedWorkflow: String? = nil,
        domain: String? = nil,
        appName: String? = nil,
        projectPath: String? = nil,
        tags: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.task = task
        self.steps = steps
        self.success = success
        self.failureReason = failureReason
        self.failureCategory = failureCategory
        self.learnedWorkflow = learnedWorkflow
        self.domain = domain
        self.appName = appName
        self.projectPath = projectPath
        self.tags = tags
        self.createdAt = createdAt
    }

    public var searchableText: String {
        ([task] + steps + [learnedWorkflow, domain, appName, failureCategory?.rawValue])
            .compactMap { $0 }
            .joined(separator: " ")
    }

    public var failurePattern: String? {
        guard !success, let category = failureCategory else { return nil }
        let app = appName.map { "@\($0)" } ?? ""
        return "\(category.rawValue)\(app)"
    }
}

public struct RecoveryStrategyMetric: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let strategy: String
    public let successRate: Double

    public init(strategy: String, successRate: Double) {
        self.id = strategy
        self.strategy = strategy
        self.successRate = successRate
    }
}

public struct RecoveryProfileSnapshot: Codable, Sendable, Hashable {
    public let scope: String
    public let appName: String?
    public let toolName: String?
    public let strategies: [RecoveryStrategyMetric]

    public init(
        scope: String,
        appName: String? = nil,
        toolName: String? = nil,
        strategies: [RecoveryStrategyMetric] = []
    ) {
        self.scope = scope
        self.appName = appName
        self.toolName = toolName
        self.strategies = strategies
    }
}

public enum AgentRole: String, Codable, Sendable, Hashable, CaseIterable {
    case planner
    case code
    case test
    case review
    case desktop
    case summary
}

// MARK: - Agent Loop State

public struct AgentLoopState: Codable, Sendable, Hashable {
    public var observations: [AgentObservation]
    public var completedSubtasks: [AgentSubtask]
    public var pendingSubtasks: [AgentSubtask]
    public var failedAttempts: [AgentFailedAttempt]
    public var currentPhase: AgentPhase
    public var roundCount: Int
    public var stagnationCount: Int
    public var totalToolRetryCount: Int

    public init(
        observations: [AgentObservation] = [],
        completedSubtasks: [AgentSubtask] = [],
        pendingSubtasks: [AgentSubtask] = [],
        failedAttempts: [AgentFailedAttempt] = [],
        currentPhase: AgentPhase = .observing,
        roundCount: Int = 0,
        stagnationCount: Int = 0,
        totalToolRetryCount: Int = 0
    ) {
        self.observations = observations
        self.completedSubtasks = completedSubtasks
        self.pendingSubtasks = pendingSubtasks
        self.failedAttempts = failedAttempts
        self.currentPhase = currentPhase
        self.roundCount = roundCount
        self.stagnationCount = stagnationCount
        self.totalToolRetryCount = totalToolRetryCount
    }

    public var progressSummary: String {
        var parts: [String] = []
        if !completedSubtasks.isEmpty {
            parts.append("已完成 \(completedSubtasks.count) 个子任务")
        }
        if !pendingSubtasks.isEmpty {
            parts.append("待执行 \(pendingSubtasks.count) 个子任务")
        }
        if !failedAttempts.isEmpty {
            parts.append("失败 \(failedAttempts.count) 次")
        }
        return parts.isEmpty ? "空闲" : parts.joined(separator: "，")
    }
}

public enum AgentPhase: String, Codable, Sendable, Hashable, CaseIterable {
    case observing
    case planning
    case acting
    case verifying
    case recovering
    case replanning
    case completed
    case failed
}

public struct AgentObservation: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let appState: ComputerUseAppState?
    public let browserState: BrowserPageState?
    public let terminalOutput: String?
    public let summary: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        appState: ComputerUseAppState? = nil,
        browserState: BrowserPageState? = nil,
        terminalOutput: String? = nil,
        summary: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.appState = appState
        self.browserState = browserState
        self.terminalOutput = terminalOutput
        self.summary = summary
    }
}

public struct AgentSubtask: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let description: String
    public let toolCalls: [ToolCallRequest]
    public var status: AgentSubtaskStatus
    public var result: String?
    public var recoveryAttempts: Int

    public enum AgentSubtaskStatus: String, Codable, Sendable, Hashable {
        case pending
        case executing
        case completed
        case failed
        case skipped
    }

    public init(
        id: UUID = UUID(),
        description: String,
        toolCalls: [ToolCallRequest] = [],
        status: AgentSubtaskStatus = .pending,
        result: String? = nil,
        recoveryAttempts: Int = 0
    ) {
        self.id = id
        self.description = description
        self.toolCalls = toolCalls
        self.status = status
        self.result = result
        self.recoveryAttempts = recoveryAttempts
    }
}

public struct AgentFailedAttempt: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let toolCall: ToolCallRequest
    public let error: String
    public let recoveryStrategy: String?
    public let wasRecovered: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        toolCall: ToolCallRequest,
        error: String,
        recoveryStrategy: String? = nil,
        wasRecovered: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.toolCall = toolCall
        self.error = error
        self.recoveryStrategy = recoveryStrategy
        self.wasRecovered = wasRecovered
    }
}

// MARK: - Agent Configuration

public struct AgentLoopConfig: Codable, Sendable, Hashable {
    public let maxRounds: Int
    public let maxStagnationRounds: Int
    public let maxRecoveryAttemptsPerStep: Int
    public let maxSubtaskDepth: Int
    public let progressCheckInterval: Int
    public let screenshotInterval: Int

    public static let `default` = AgentLoopConfig(
        maxRounds: 50,
        maxStagnationRounds: 5,
        maxRecoveryAttemptsPerStep: 3,
        maxSubtaskDepth: 3,
        progressCheckInterval: 5,
        screenshotInterval: 3
    )

    public static let conservative = AgentLoopConfig(
        maxRounds: 20,
        maxStagnationRounds: 3,
        maxRecoveryAttemptsPerStep: 1,
        maxSubtaskDepth: 2,
        progressCheckInterval: 3,
        screenshotInterval: 3
    )

    public init(
        maxRounds: Int,
        maxStagnationRounds: Int,
        maxRecoveryAttemptsPerStep: Int,
        maxSubtaskDepth: Int,
        progressCheckInterval: Int,
        screenshotInterval: Int = 3
    ) {
        self.maxRounds = maxRounds
        self.maxStagnationRounds = maxStagnationRounds
        self.maxRecoveryAttemptsPerStep = maxRecoveryAttemptsPerStep
        self.maxSubtaskDepth = maxSubtaskDepth
        self.progressCheckInterval = progressCheckInterval
        self.screenshotInterval = screenshotInterval
    }
}

// MARK: - Agent Loop Events (streaming)

public enum AgentLoopEvent: Sendable {
    case phaseChange(AgentPhase, summary: String)
    case observation(AgentObservation)
    case subtaskStarted(AgentSubtask)
    case subtaskCompleted(AgentSubtask)
    case subtaskFailed(AgentSubtask, error: String)
    case toolCallStarted(ToolCallRequest)
    case toolCallCompleted(ToolCallResult)
    case recoveryAttempt(String, strategy: String)
    case token(String, messageID: UUID)
    case warning(String)
    case screenshotInjected(Int) // byte count
    case completed(AgentResponse)
    case failed(Error)
}

public struct AgentResponse: Sendable, Hashable {
    public let finalMessage: Message
    public let toolResults: [ToolCallResult]
    public let iterations: Int
    public let backendUsed: LLMProvider

    public init(
        finalMessage: Message,
        toolResults: [ToolCallResult],
        iterations: Int,
        backendUsed: LLMProvider
    ) {
        self.finalMessage = finalMessage
        self.toolResults = toolResults
        self.iterations = iterations
        self.backendUsed = backendUsed
    }
}

public struct MultiAgentBoardItem: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let role: AgentRole
    public let objective: String
    public var status: AgentTaskStatus
    public var latestLog: String?
    public var artifactPaths: [String]

    public init(
        id: UUID = UUID(),
        role: AgentRole,
        objective: String,
        status: AgentTaskStatus = .queued,
        latestLog: String? = nil,
        artifactPaths: [String] = []
    ) {
        self.id = id
        self.role = role
        self.objective = objective
        self.status = status
        self.latestLog = latestLog
        self.artifactPaths = artifactPaths
    }
}

// MARK: - Session Lifecycle FSM

public enum SessionPhase: String, Codable, Sendable, Hashable, CaseIterable {
    case idle
    case listening
    case thinking
    case planning
    case acting
    case verifying
    case recovering
    case responding

    public var label: String {
        switch self {
        case .idle: "空闲"
        case .listening: "监听中"
        case .thinking: "思考中"
        case .planning: "规划中"
        case .acting: "执行中"
        case .verifying: "验证中"
        case .recovering: "恢复中"
        case .responding: "回复中"
        }
    }

    public var isActive: Bool { self != .idle }
}

public struct SessionLifecycle: Sendable {
    public private(set) var phase: SessionPhase
    public private(set) var phaseStartedAt: Date
    public private(set) var transitionHistory: [Transition]

    public struct Transition: Codable, Sendable, Hashable {
        public let from: SessionPhase
        public let to: SessionPhase
        public let at: Date
        public let reason: String

        public init(from: SessionPhase, to: SessionPhase, at: Date = Date(), reason: String = "") {
            self.from = from
            self.to = to
            self.at = at
            self.reason = reason
        }
    }

    public init(phase: SessionPhase = .idle) {
        self.phase = phase
        self.phaseStartedAt = Date()
        self.transitionHistory = []
    }

    public var timeInCurrentPhase: TimeInterval {
        Date().timeIntervalSince(phaseStartedAt)
    }

    public var isActive: Bool { phase.isActive }

    public mutating func transition(to next: SessionPhase, reason: String = "") -> Bool {
        guard isValidTransition(from: phase, to: next) else { return false }
        let t = Transition(from: phase, to: next, reason: reason)
        transitionHistory.append(t)
        phase = next
        phaseStartedAt = Date()
        return true
    }

    public func isValidTransition(from: SessionPhase, to: SessionPhase) -> Bool {
        switch (from, to) {
        case (.idle, .listening), (.idle, .thinking):
            return true
        case (.listening, .thinking), (.listening, .idle):
            return true
        case (.thinking, .planning), (.thinking, .responding), (.thinking, .idle):
            return true
        case (.planning, .acting), (.planning, .thinking), (.planning, .idle):
            return true
        case (.acting, .verifying), (.acting, .recovering), (.acting, .responding):
            return true
        case (.verifying, .responding), (.verifying, .recovering), (.verifying, .acting):
            return true
        case (.recovering, .acting), (.recovering, .responding):
            return true
        case (.responding, .idle):
            return true
        default:
            return false
        }
    }
}

// MARK: - Workflow Template

public struct WorkflowTemplate: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public var name: String
    public var description: String
    public var appName: String?
    public var steps: [TemplateStep]
    public var tags: [String]
    public var useCount: Int
    public var lastUsedAt: Date?
    public let createdAt: Date

    public struct TemplateStep: Codable, Sendable, Hashable, Identifiable {
        public let id: String
        public var toolName: String
        public var arguments: [String: String]
        public var expectedVerification: String?

        public init(
            id: String = UUID().uuidString,
            toolName: String,
            arguments: [String: String] = [:],
            expectedVerification: String? = nil
        ) {
            self.id = id
            self.toolName = toolName
            self.arguments = arguments
            self.expectedVerification = expectedVerification
        }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        appName: String? = nil,
        steps: [TemplateStep] = [],
        tags: [String] = [],
        useCount: Int = 0,
        lastUsedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.appName = appName
        self.steps = steps
        self.tags = tags
        self.useCount = useCount
        self.lastUsedAt = lastUsedAt
        self.createdAt = createdAt
    }

    public var actionCount: Int { steps.count }

    public func toComputerUseActions() -> [ComputerUseAction] {
        steps.map { step in
            ComputerUseAction(
                id: UUID(uuidString: step.id) ?? UUID(),
                toolCall: ToolCallRequest(
                    id: step.id,
                    name: step.toolName,
                    arguments: step.arguments
                ),
                verificationGoal: step.expectedVerification.map {
                    VerificationGoal(expectedText: $0)
                }
            )
        }
    }
}
