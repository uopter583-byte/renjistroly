// 销售场景模型 (413-418)

import Foundation

// MARK: - 413: CRM 操作审计

public struct CRMAuditRecord: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let field: String
    public let oldValue: String
    public let newValue: String
    public let operatorID: String?
    public let reason: String
    public let isRolledBack: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        field: String,
        oldValue: String,
        newValue: String,
        operatorID: String? = nil,
        reason: String,
        isRolledBack: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.field = field
        self.oldValue = oldValue
        self.newValue = newValue
        self.operatorID = operatorID
        self.reason = reason
        self.isRolledBack = isRolledBack
    }
}

// MARK: - 414: 风险分级拦截

public struct RefundRiskAssessment: Codable, Sendable {
    public let refundAmount: Double
    public let riskScore: Float
    public let riskLevel: RefundRiskLevel
    public let flags: [String]

    public enum RefundRiskLevel: String, Codable, Sendable, Comparable {
        case low
        case medium
        case high
        case critical

        public var requiresManualReview: Bool {
            self == .high || self == .critical
        }

        public static func < (lhs: RefundRiskLevel, rhs: RefundRiskLevel) -> Bool {
            let order: [RefundRiskLevel] = [.low, .medium, .high, .critical]
            return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
        }
    }

    public init(
        refundAmount: Double,
        riskScore: Float,
        riskLevel: RefundRiskLevel,
        flags: [String] = []
    ) {
        self.refundAmount = refundAmount
        self.riskScore = riskScore
        self.riskLevel = riskLevel
        self.flags = flags
    }

    public static func assess(amount: Double, customerHistoryDays: Int, previousRefunds: Int) -> RefundRiskAssessment {
        var score: Float = 0
        var flags: [String] = []

        if amount > 10000 { score += 0.3; flags.append("大额退款") }
        if amount > 50000 { score += 0.2; flags.append("超大额退款") }
        if customerHistoryDays < 30 { score += 0.2; flags.append("新客户") }
        if previousRefunds > 3 { score += 0.2; flags.append("频繁退款") }
        if previousRefunds > 5 { score += 0.15; flags.append("极高退款频率") }
        if amount < 100 { score = min(score, 0.1) }

        let level: RefundRiskLevel
        switch score {
        case ..<0.2: level = .low
        case ..<0.4: level = .medium
        case ..<0.6: level = .high
        default: level = .critical
        }

        return RefundRiskAssessment(
            refundAmount: amount,
            riskScore: min(score, 1.0),
            riskLevel: level,
            flags: flags
        )
    }
}

// MARK: - 415: OCR 置信度校验

public struct OCRConfidenceValidation: Codable, Sendable {
    public let minThreshold: Float
    public let lowConfidenceRegions: [OCRRegion]
    public let isReliable: Bool

    public struct OCRRegion: Codable, Sendable {
        public let text: String
        public let confidence: Float
        public let x: Float
        public let y: Float

        public init(text: String, confidence: Float, x: Float, y: Float) {
            self.text = text
            self.confidence = confidence
            self.x = x
            self.y = y
        }
    }

    public init(
        minThreshold: Float = 0.6,
        lowConfidenceRegions: [OCRRegion] = [],
        isReliable: Bool = true
    ) {
        self.minThreshold = minThreshold
        self.lowConfidenceRegions = lowConfidenceRegions
        self.isReliable = isReliable
    }
}

// MARK: - 416: CRM 字段语义映射

public struct CRMFieldDefinition: Codable, Sendable {
    public let displayName: String
    public let internalKey: String
    public let fieldType: CRMFieldType
    public let isRequired: Bool
    public let validationRules: [String]
    public let sensitivity: DataSensitivity

    public enum CRMFieldType: String, Codable, Sendable {
        case text
        case number
        case date
        case email
        case phone
        case currency
        case dropdown
        case multiSelect
    }

    public enum DataSensitivity: String, Codable, Sendable {
        case `public`
        case `internal`
        case sensitive
        case pii
    }

    public init(
        displayName: String,
        internalKey: String,
        fieldType: CRMFieldType = .text,
        isRequired: Bool = false,
        validationRules: [String] = [],
        sensitivity: DataSensitivity = .internal
    ) {
        self.displayName = displayName
        self.internalKey = internalKey
        self.fieldType = fieldType
        self.isRequired = isRequired
        self.validationRules = validationRules
        self.sensitivity = sensitivity
    }
}

// MARK: - 417: 销售阶段感知

public struct SalesStageContext: Codable, Sendable {
    public let stage: Stage
    public let probability: Int
    public let allowedActions: [String]
    public let requiredDocuments: [String]

    public enum Stage: String, Codable, Sendable, CaseIterable {
        case prospecting
        case qualification
        case needsAnalysis
        case proposal
        case negotiation
        case closedWon
        case closedLost

        public var title: String {
            switch self {
            case .prospecting: return "潜在客户"
            case .qualification: return "资格确认"
            case .needsAnalysis: return "需求分析"
            case .proposal: return "方案报价"
            case .negotiation: return "商务谈判"
            case .closedWon: return "已成交"
            case .closedLost: return "已流失"
            }
        }
    }

    public init(
        stage: Stage = .prospecting,
        probability: Int = 10,
        allowedActions: [String] = [],
        requiredDocuments: [String] = []
    ) {
        self.stage = stage
        self.probability = probability
        self.allowedActions = allowedActions
        self.requiredDocuments = requiredDocuments
    }

    public func allows(action: String) -> Bool {
        allowedActions.contains { $0.lowercased() == action.lowercased() }
    }

    public static func defaultForStage(_ stage: Stage) -> SalesStageContext {
        switch stage {
        case .prospecting:
            return .init(stage: stage, probability: 10,
                         allowedActions: ["search", "view", "add_note"],
                         requiredDocuments: [])
        case .qualification:
            return .init(stage: stage, probability: 20,
                         allowedActions: ["search", "view", "add_note", "send_email"],
                         requiredDocuments: ["qualification_form"])
        case .needsAnalysis:
            return .init(stage: stage, probability: 35,
                         allowedActions: ["search", "view", "add_note", "send_email", "schedule_meeting"],
                         requiredDocuments: ["needs_assessment"])
        case .proposal:
            return .init(stage: stage, probability: 50,
                         allowedActions: ["search", "view", "add_note", "send_email", "schedule_meeting", "generate_quote"],
                         requiredDocuments: ["proposal_template", "pricing_sheet"])
        case .negotiation:
            return .init(stage: stage, probability: 70,
                         allowedActions: ["search", "view", "add_note", "send_email", "schedule_meeting", "generate_quote", "modify_amount"],
                         requiredDocuments: ["contract_template"])
        case .closedWon:
            return .init(stage: stage, probability: 100,
                         allowedActions: ["search", "view"],
                         requiredDocuments: ["signed_contract"])
        case .closedLost:
            return .init(stage: stage, probability: 0,
                         allowedActions: ["search", "view"],
                         requiredDocuments: ["loss_reason"])
        }
    }
}

// MARK: - 418: 金额修改确认

public struct AmountChangeRequest: Codable, Sendable {
    public let entityID: String
    public let entityType: String
    public let oldAmount: Double
    public let newAmount: Double
    public let currency: String
    public let reason: String
    public let requiresApproval: Bool

    public init(
        entityID: String,
        entityType: String,
        oldAmount: Double,
        newAmount: Double,
        currency: String = "CNY",
        reason: String,
        requiresApproval: Bool = true
    ) {
        self.entityID = entityID
        self.entityType = entityType
        self.oldAmount = oldAmount
        self.newAmount = newAmount
        self.currency = currency
        self.reason = reason
        self.requiresApproval = requiresApproval
    }

    public var changePercent: Double {
        guard oldAmount > 0 else { return newAmount > 0 ? 100 : 0 }
        return (newAmount - oldAmount) / oldAmount * 100
    }
}
