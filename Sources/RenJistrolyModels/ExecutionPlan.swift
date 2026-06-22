import Foundation

public enum PlanStatus: String, Codable, Sendable, Hashable {
    case drafting
    case pendingApproval
    case approved
    case executing
    case completed
    case failed
    case cancelled
}

public enum StepStatus: String, Codable, Sendable, Hashable {
    case pending
    case executing
    case completed
    case failed
    case skipped
}

public struct PlanStep: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let description: String
    public let toolCalls: [ToolCallRequest]
    public let riskLevel: ToolRiskLevel
    public var status: StepStatus
    public var result: String?

    public init(
        id: String = UUID().uuidString,
        description: String,
        toolCalls: [ToolCallRequest] = [],
        riskLevel: ToolRiskLevel = .low,
        status: StepStatus = .pending,
        result: String? = nil
    ) {
        self.id = id
        self.description = description
        self.toolCalls = toolCalls
        self.riskLevel = riskLevel
        self.status = status
        self.result = result
    }
}

public struct ExecutionPlan: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let title: String
    public var steps: [PlanStep]
    public var status: PlanStatus
    public var currentStepIndex: Int
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        steps: [PlanStep],
        status: PlanStatus = .pendingApproval,
        currentStepIndex: Int = 0
    ) {
        self.id = id
        self.title = title
        self.steps = steps
        self.status = status
        self.currentStepIndex = currentStepIndex
        self.createdAt = Date()
    }

    public var currentStep: PlanStep? {
        guard steps.indices.contains(currentStepIndex) else { return nil }
        return steps[currentStepIndex]
    }

    public var progressFraction: Double {
        guard !steps.isEmpty else { return 0 }
        let completed = steps.prefix(currentStepIndex).filter { $0.status == .completed }.count
        return Double(completed) / Double(steps.count)
    }

    public var hasRemainingSteps: Bool {
        currentStepIndex < steps.count
    }

    public var highestRiskLevel: ToolRiskLevel {
        steps.map(\.riskLevel).max() ?? .low
    }
}
