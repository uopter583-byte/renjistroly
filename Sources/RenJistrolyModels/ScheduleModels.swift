// 日程与协同模型 (420-425)

import Foundation

// MARK: - 420: 时区冲突检测

public struct TimezoneConflictCheck: Codable, Sendable {
    public let participants: [TimeSlot]
    public let conflicts: [Conflict]

    public struct TimeSlot: Codable, Sendable, Identifiable {
        public let id: UUID
        public let name: String
        public let timezone: String
        public let proposedTime: Date

        public init(id: UUID = UUID(), name: String, timezone: String, proposedTime: Date) {
            self.id = id
            self.name = name
            self.timezone = timezone
            self.proposedTime = proposedTime
        }
    }

    public struct Conflict: Codable, Sendable {
        public let participantA: String
        public let participantB: String
        public let description: String
        public let hourDifference: Int

        public init(participantA: String, participantB: String, description: String, hourDifference: Int) {
            self.participantA = participantA
            self.participantB = participantB
            self.description = description
            self.hourDifference = hourDifference
        }
    }

    public init(participants: [TimeSlot] = [], conflicts: [Conflict] = []) {
        self.participants = participants
        self.conflicts = conflicts
    }
}

// MARK: - 421: 报价模板匹配

public struct QuoteTemplate: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let applicableStages: [SalesStageContext.Stage]
    public let minAmount: Double?
    public let maxAmount: Double?
    public let requiredClauses: [String]
    public let language: String
    public let description: String

    public init(
        id: String = UUID().uuidString,
        name: String,
        applicableStages: [SalesStageContext.Stage],
        minAmount: Double? = nil,
        maxAmount: Double? = nil,
        requiredClauses: [String] = [],
        language: String = "zh-CN",
        description: String = ""
    ) {
        self.id = id
        self.name = name
        self.applicableStages = applicableStages
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.requiredClauses = requiredClauses
        self.language = language
        self.description = description
    }

    public func matches(amount: Double, stage: SalesStageContext.Stage) -> Bool {
        guard applicableStages.contains(stage) else { return false }
        if let min = minAmount, amount < min { return false }
        if let max = maxAmount, amount > max { return false }
        return true
    }
}

// MARK: - 422: 合同审批流程

public struct ContractApprovalFlow: Codable, Sendable {
    public let contractID: String
    public let amount: Double
    public var approvalChain: [ApprovalStep]
    public var currentStep: Int
    public var status: ApprovalStatus

    public struct ApprovalStep: Codable, Sendable, Identifiable {
        public let id: UUID
        public let role: String
        public let approverName: String?
        public let isCompleted: Bool
        public let decidedAt: Date?
        public let notes: String?

        public init(
            id: UUID = UUID(),
            role: String,
            approverName: String? = nil,
            isCompleted: Bool = false,
            decidedAt: Date? = nil,
            notes: String? = nil
        ) {
            self.id = id
            self.role = role
            self.approverName = approverName
            self.isCompleted = isCompleted
            self.decidedAt = decidedAt
            self.notes = notes
        }
    }

    public enum ApprovalStatus: String, Codable, Sendable {
        case pending
        case inProgress
        case approved
        case rejected
        case needsRevision
    }

    public init(
        contractID: String,
        amount: Double,
        approvalChain: [ApprovalStep],
        currentStep: Int = 0,
        status: ApprovalStatus = .pending
    ) {
        self.contractID = contractID
        self.amount = amount
        self.approvalChain = approvalChain
        self.currentStep = currentStep
        self.status = status
    }

    public static func generateChain(amount: Double, contractID: String) -> ContractApprovalFlow {
        var steps: [ApprovalStep] = []
        steps.append(ApprovalStep(role: "销售主管"))
        if amount > 100000 {
            steps.append(ApprovalStep(role: "销售总监"))
        }
        if amount > 500000 {
            steps.append(ApprovalStep(role: "财务总监"))
        }
        if amount > 1000000 {
            steps.append(ApprovalStep(role: "CEO"))
        }
        return ContractApprovalFlow(
            contractID: contractID,
            amount: amount,
            approvalChain: steps,
            currentStep: 0,
            status: .pending
        )
    }
}

// MARK: - 423: 说话人分离

public struct SpeakerSegment: Codable, Sendable, Identifiable {
    public let id: UUID
    public let speakerID: String
    public let speakerName: String?
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    public let role: SpeakerRole

    public enum SpeakerRole: String, Codable, Sendable {
        case agent
        case customer
        case manager
        case system
    }

    public init(
        id: UUID = UUID(),
        speakerID: String,
        speakerName: String? = nil,
        startTime: TimeInterval = 0,
        endTime: TimeInterval = 0,
        text: String,
        role: SpeakerRole = .agent
    ) {
        self.id = id
        self.speakerID = speakerID
        self.speakerName = speakerName
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.role = role
    }
}

// MARK: - 424: 可靠提醒机制

public struct ReminderItem: Codable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let description: String
    public let dueDate: Date
    public let priority: ReminderPriority
    public let context: ReminderContext
    public let isCompleted: Bool
    public let createdAt: Date
    public let scheduledNotification: Bool

    public enum ReminderPriority: String, Codable, Sendable, Comparable {
        case low
        case medium
        case high
        case urgent

        public static func < (lhs: ReminderPriority, rhs: ReminderPriority) -> Bool {
            let order: [ReminderPriority] = [.low, .medium, .high, .urgent]
            return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
        }
    }

    public struct ReminderContext: Codable, Sendable {
        public let relatedEntityID: String?
        public let relatedEntityType: String?
        public let customerName: String?

        public init(relatedEntityID: String? = nil, relatedEntityType: String? = nil, customerName: String? = nil) {
            self.relatedEntityID = relatedEntityID
            self.relatedEntityType = relatedEntityType
            self.customerName = customerName
        }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        description: String,
        dueDate: Date,
        priority: ReminderPriority = .medium,
        context: ReminderContext = ReminderContext(),
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        scheduledNotification: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.priority = priority
        self.context = context
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.scheduledNotification = scheduledNotification
    }
}

// MARK: - 425: 多窗口上下文融合

public struct MultiWindowFusion: Codable, Sendable {
    public let windows: [FusedWindow]
    public let mergedContext: [String: String]
    public let contradictions: [String]

    public struct FusedWindow: Codable, Sendable, Identifiable {
        public let id: UUID
        public let appName: String
        public let windowTitle: String
        public let extractedData: [String: String]
        public let ocrText: String?

        public init(
            id: UUID = UUID(),
            appName: String,
            windowTitle: String,
            extractedData: [String: String] = [:],
            ocrText: String? = nil
        ) {
            self.id = id
            self.appName = appName
            self.windowTitle = windowTitle
            self.extractedData = extractedData
            self.ocrText = ocrText
        }
    }

    public init(
        windows: [FusedWindow] = [],
        mergedContext: [String: String] = [:],
        contradictions: [String] = []
    ) {
        self.windows = windows
        self.mergedContext = mergedContext
        self.contradictions = contradictions
    }
}
