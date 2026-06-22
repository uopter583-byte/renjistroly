import Foundation

public enum TaskKind: String, Codable, Sendable, Hashable, CaseIterable {
    case chat
    case code
    case desktop
    case browser
    case fileSystem
    case mixed
}

public struct TaskRoute: Codable, Sendable, Hashable {
    public let kind: TaskKind
    public let confidence: Double
    public let reason: String

    public init(kind: TaskKind, confidence: Double, reason: String) {
        self.kind = kind
        self.confidence = confidence
        self.reason = reason
    }
}

public struct RoutedTask: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let prompt: String
    public let primaryRoute: TaskRoute
    public let fallbackRoutes: [TaskRoute]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        prompt: String,
        primaryRoute: TaskRoute,
        fallbackRoutes: [TaskRoute] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.prompt = prompt
        self.primaryRoute = primaryRoute
        self.fallbackRoutes = fallbackRoutes
        self.createdAt = createdAt
    }
}

// MARK: - Sub-task Decomposition

public struct SubTask: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let prompt: String
    public let route: TaskRoute
    public let dependsOn: [UUID]
    /// Optional category hint for model routing (e.g. "deep", "quick", "ultrabrain")
    public let categoryHint: String?
    /// Optional tool requirements — hint about what tools this subtask needs
    public let toolHints: [String]

    public init(
        id: UUID = UUID(),
        prompt: String,
        route: TaskRoute,
        dependsOn: [UUID] = [],
        categoryHint: String? = nil,
        toolHints: [String] = []
    ) {
        self.id = id
        self.prompt = prompt
        self.route = route
        self.dependsOn = dependsOn
        self.categoryHint = categoryHint
        self.toolHints = toolHints
    }
}

public struct ExecutionGroup: Codable, Sendable, Hashable {
    /// Subtasks that can run in parallel (no inter-dependencies)
    public let parallelTasks: [SubTask]
    /// Order of this group in the execution sequence
    public let groupIndex: Int

    public init(parallelTasks: [SubTask], groupIndex: Int) {
        self.parallelTasks = parallelTasks
        self.groupIndex = groupIndex
    }
}

public struct DecomposedTask: Codable, Sendable {
    public let originalPrompt: String
    public let subTasks: [SubTask]

    public init(originalPrompt: String, subTasks: [SubTask]) {
        self.originalPrompt = originalPrompt
        self.subTasks = subTasks
    }

    public var orderedForExecution: [SubTask] {
        var executed: Set<UUID> = []
        var remaining = subTasks
        var result: [SubTask] = []
        while !remaining.isEmpty {
            let ready = remaining.filter { $0.dependsOn.allSatisfy { executed.contains($0) } }
            if ready.isEmpty { result.append(contentsOf: remaining); break }
            for task in ready {
                result.append(task)
                executed.insert(task.id)
                remaining.removeAll { $0.id == task.id }
            }
        }
        return result
    }

    /// Group subtasks into parallel-execution groups.
    /// Tasks in the same group have no inter-dependencies.
    public var executionGroups: [ExecutionGroup] {
        var groups: [ExecutionGroup] = []
        var executed: Set<UUID> = []
        var remaining = subTasks
        var groupIndex = 0

        while !remaining.isEmpty {
            let ready = remaining.filter { $0.dependsOn.allSatisfy { executed.contains($0) } }
            if ready.isEmpty {
                // Break dependency cycles — run remaining individually
                for task in remaining {
                    groups.append(ExecutionGroup(parallelTasks: [task], groupIndex: groupIndex))
                    groupIndex += 1
                }
                break
            }
            groups.append(ExecutionGroup(parallelTasks: ready, groupIndex: groupIndex))
            for task in ready {
                executed.insert(task.id)
                remaining.removeAll { $0.id == task.id }
            }
            groupIndex += 1
        }
        return groups
    }

    public var summary: String {
        let groups = executionGroups
        return groups.map { group in
            let header = group.groupIndex == 0 ? "Step 1:" : "Step \(group.groupIndex + 1):"
            let tasks = group.parallelTasks.map { st in
                let hint = st.categoryHint.map { " (\($0))" } ?? ""
                return "  - [\(st.route.kind.rawValue)]\(hint) \(st.prompt)"
            }.joined(separator: "\n")
            let parallelMarker = group.parallelTasks.count > 1 ? " (并行)" : ""
            return "\(header)\(parallelMarker)\n\(tasks)"
        }.joined(separator: "\n")
    }
}

// MARK: - Verification Goal

public struct VerificationGoal: Codable, Sendable, Hashable {
    public let expectedText: String?
    public let expectedApp: String?
    public let expectedWindowTitle: String?
    public let expectedElementRole: String?

    public init(
        expectedText: String? = nil,
        expectedApp: String? = nil,
        expectedWindowTitle: String? = nil,
        expectedElementRole: String? = nil
    ) {
        self.expectedText = expectedText
        self.expectedApp = expectedApp
        self.expectedWindowTitle = expectedWindowTitle
        self.expectedElementRole = expectedElementRole
    }
}

public struct ComputerUseAction: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let toolCall: ToolCallRequest
    public let verificationGoal: VerificationGoal?

    public init(
        id: UUID = UUID(),
        toolCall: ToolCallRequest,
        verificationGoal: VerificationGoal? = nil
    ) {
        self.id = id
        self.toolCall = toolCall
        self.verificationGoal = verificationGoal
    }
}

public struct ComputerUseStepResult: Codable, Sendable, Hashable {
    public let action: ComputerUseAction
    public let beforeState: ComputerUseAppState?
    public let toolResult: ToolCallResult
    public let afterState: ComputerUseAppState?
    public let stateDelta: ComputerUseStateDelta?
    public let verified: Bool
    public let verificationEvidence: [String]
    public let recoveryAttempted: Bool
    public let recoveryStrategy: String?
    public let recoverySummary: String?
    public let backendUsed: String?
    public let recoveryFromBackend: String?
    public let permissionError: String?

    public init(
        action: ComputerUseAction,
        beforeState: ComputerUseAppState?,
        toolResult: ToolCallResult,
        afterState: ComputerUseAppState?,
        stateDelta: ComputerUseStateDelta? = nil,
        verified: Bool,
        verificationEvidence: [String] = [],
        recoveryAttempted: Bool = false,
        recoveryStrategy: String? = nil,
        recoverySummary: String? = nil,
        backendUsed: String? = nil,
        recoveryFromBackend: String? = nil,
        permissionError: String? = nil
    ) {
        self.action = action
        self.beforeState = beforeState
        self.toolResult = toolResult
        self.afterState = afterState
        self.stateDelta = stateDelta
        self.verified = verified
        self.verificationEvidence = verificationEvidence
        self.recoveryAttempted = recoveryAttempted
        self.recoveryStrategy = recoveryStrategy
        self.recoverySummary = recoverySummary
        self.backendUsed = backendUsed
        self.recoveryFromBackend = recoveryFromBackend
        self.permissionError = permissionError
    }

    public var memorySteps: [String] {
        var steps = ["tool: \(action.toolCall.name)"]
        if let recoveryStrategy, !recoveryStrategy.isEmpty {
            steps.append("strategy: \(recoveryStrategy)")
        }
        if let recoverySummary, !recoverySummary.isEmpty {
            steps.append("recover: \(recoverySummary)")
        }
        if let stateDelta, stateDelta.hasMeaningfulChange {
            steps.append("verify: \(stateDelta.summary)")
        }
        if let evidence = verificationEvidence.first, !evidence.isEmpty {
            steps.append("evidence: \(evidence)")
        }
        return steps
    }
}

public struct ComputerUseRunResult: Codable, Sendable, Hashable {
    public let startedAt: Date
    public let finishedAt: Date
    public let steps: [ComputerUseStepResult]

    public init(startedAt: Date, finishedAt: Date = Date(), steps: [ComputerUseStepResult]) {
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.steps = steps
    }

    public var succeeded: Bool {
        !steps.isEmpty && steps.allSatisfy { !$0.toolResult.isError && $0.verified }
    }

    public var memorySteps: [String] {
        steps.flatMap(\.memorySteps)
    }

    public var learnedWorkflowSummary: String? {
        let summary = memorySteps.joined(separator: " -> ")
        return summary.isEmpty ? nil : summary
    }

    public func inferredAppName(fallback: String? = nil) -> String? {
        for step in steps {
            if let expectedApp = step.action.verificationGoal?.expectedApp, !expectedApp.isEmpty {
                return expectedApp
            }
            if let activeAppName = step.afterState?.activeAppName, !activeAppName.isEmpty {
                return activeAppName
            }
            if let activeAppName = step.beforeState?.activeAppName, !activeAppName.isEmpty {
                return activeAppName
            }
        }
        return fallback
    }
}

public struct ComputerUseTraceSnapshot: Codable, Sendable, Hashable {
    public let phase: String
    public let taskText: String
    public let routeLabel: String
    public let browserPageState: BrowserPageState?
    public let run: ComputerUseRunResult
    public let events: [ComputerUseTraceEvent]

    public init(
        phase: String = "completed",
        taskText: String,
        routeLabel: String,
        browserPageState: BrowserPageState? = nil,
        run: ComputerUseRunResult,
        events: [ComputerUseTraceEvent] = []
    ) {
        self.phase = phase
        self.taskText = taskText
        self.routeLabel = routeLabel
        self.browserPageState = browserPageState
        self.run = run
        self.events = events
    }
}

public struct ComputerUseTraceEvent: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let phase: String
    public let stepIndex: Int
    public let toolName: String
    public let summary: String

    public init(
        id: UUID = UUID(),
        phase: String,
        stepIndex: Int,
        toolName: String,
        summary: String
    ) {
        self.id = id
        self.phase = phase
        self.stepIndex = stepIndex
        self.toolName = toolName
        self.summary = summary
    }
}
