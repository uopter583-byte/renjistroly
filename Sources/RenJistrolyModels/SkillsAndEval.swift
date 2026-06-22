import Foundation

public struct AgentSkill: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let description: String
    public let triggerPhrases: [String]
    public let steps: [String]
    public let createdAt: Date
    public var successCount: Int
    public var failureCount: Int

    public init(
        id: UUID = UUID(),
        name: String,
        description: String,
        triggerPhrases: [String],
        steps: [String],
        createdAt: Date = Date(),
        successCount: Int = 0,
        failureCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.triggerPhrases = triggerPhrases
        self.steps = steps
        self.createdAt = createdAt
        self.successCount = successCount
        self.failureCount = failureCount
    }
}

public struct ComputerUseEvalTask: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let name: String
    public let category: Category
    public let instruction: String
    public let expectedOutcome: String

    public enum Category: String, Codable, Sendable, Hashable, CaseIterable {
        case finder
        case browser
        case textEntry
        case appNavigation
        case systemSettings
        case webSearch
        case codeBuild
        case codeTest
        case codeFixBug
        case failureRecovery
        case multiStepWorkflow
    }

    public init(
        id: UUID = UUID(),
        name: String,
        category: Category,
        instruction: String,
        expectedOutcome: String
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.instruction = instruction
        self.expectedOutcome = expectedOutcome
    }
}

public struct ComputerUseEvalResult: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let task: ComputerUseEvalTask
    public let succeeded: Bool
    public let attempts: Int
    public let failureReason: String?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        task: ComputerUseEvalTask,
        succeeded: Bool,
        attempts: Int,
        failureReason: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.task = task
        self.succeeded = succeeded
        self.attempts = attempts
        self.failureReason = failureReason
        self.createdAt = createdAt
    }
}
