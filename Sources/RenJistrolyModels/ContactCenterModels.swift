// 客服场景模型 (406-412)

import Foundation

// MARK: - 406: 会话上下文管理

public struct SessionContext: Codable, Sendable, Hashable {
    public let sessionID: String
    public let customerID: String?
    public let customerName: String?
    public let channel: String
    public let ticketID: String?
    public var stage: SessionStage
    public var contextVariables: [String: String]

    public enum SessionStage: String, Codable, Sendable {
        case greeting
        case inquiry
        case issueResolution
        case followUp
        case closed
    }

    public init(
        sessionID: String = UUID().uuidString,
        customerID: String? = nil,
        customerName: String? = nil,
        channel: String = "chat",
        ticketID: String? = nil,
        stage: SessionStage = .greeting,
        contextVariables: [String: String] = [:]
    ) {
        self.sessionID = sessionID
        self.customerID = customerID
        self.customerName = customerName
        self.channel = channel
        self.ticketID = ticketID
        self.stage = stage
        self.contextVariables = contextVariables
    }
}

// MARK: - 407: 话术策略层

public struct ScriptStrategy: Codable, Sendable {
    public let strategyID: String
    public let name: String
    public let applicableStages: [SessionContext.SessionStage]
    public let allowedTemplates: [String]
    public let restrictedPhrases: [String]
    public let requiredElements: [String]

    public init(
        strategyID: String = UUID().uuidString,
        name: String,
        applicableStages: [SessionContext.SessionStage],
        allowedTemplates: [String],
        restrictedPhrases: [String],
        requiredElements: [String]
    ) {
        self.strategyID = strategyID
        self.name = name
        self.applicableStages = applicableStages
        self.allowedTemplates = allowedTemplates
        self.restrictedPhrases = restrictedPhrases
        self.requiredElements = requiredElements
    }
}

// MARK: - 410: 情绪分析（含强度）

public struct SentimentResult: Codable, Sendable, Equatable {
    public let overall: SentimentLabel
    public let intensity: Float
    public let anger: Float
    public let joy: Float
    public let sadness: Float
    public let fear: Float
    public let surprise: Float
    public let frustration: Float
    public let contextualKeywords: [String]

    public enum SentimentLabel: String, Codable, Sendable {
        case positive
        case neutral
        case negative
        case frustrated
        case angry
        case urgent
    }

    public init(
        overall: SentimentLabel = .neutral,
        intensity: Float = 0,
        anger: Float = 0,
        joy: Float = 0,
        sadness: Float = 0,
        fear: Float = 0,
        surprise: Float = 0,
        frustration: Float = 0,
        contextualKeywords: [String] = []
    ) {
        self.overall = overall
        self.intensity = intensity
        self.anger = anger
        self.joy = joy
        self.sadness = sadness
        self.fear = fear
        self.surprise = surprise
        self.frustration = frustration
        self.contextualKeywords = contextualKeywords
    }

    public var requiresPriorityHandling: Bool {
        intensity > 0.7 && (anger > 0.5 || frustration > 0.6)
    }

    public var summary: String {
        let priorityMark = requiresPriorityHandling ? " [需要优先处理]" : ""
        return "情绪: \(overall.rawValue), 强度: \(String(format: "%.2f", intensity)), "
            + "愤怒: \(String(format: "%.2f", anger)), 挫败感: \(String(format: "%.2f", frustration))"
            + priorityMark
    }
}

// MARK: - 411: 上下文隔离

public struct ContextIsolationState: Codable, Sendable {
    public let activeTicketID: String
    public let isolatedContext: [String: String]
    public var previousTicketIDs: [String]
    public let isolationStartedAt: Date

    public init(
        activeTicketID: String,
        isolatedContext: [String: String] = [:],
        previousTicketIDs: [String] = [],
        isolationStartedAt: Date = Date()
    ) {
        self.activeTicketID = activeTicketID
        self.isolatedContext = isolatedContext
        self.previousTicketIDs = previousTicketIDs
        self.isolationStartedAt = isolationStartedAt
    }
}

// MARK: - 412: 语气保留翻译

public struct TranslationOptions: Codable, Sendable {
    public let sourceLanguage: String
    public let targetLanguage: String
    public let tone: TranslationTone
    public let preserveFormality: Bool
    public let preserveEmoji: Bool

    public enum TranslationTone: String, Codable, Sendable {
        case polite
        case professional
        case friendly
        case casual
        case empathetic
        case urgent
    }

    public init(
        sourceLanguage: String,
        targetLanguage: String,
        tone: TranslationTone = .polite,
        preserveFormality: Bool = true,
        preserveEmoji: Bool = true
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.tone = tone
        self.preserveFormality = preserveFormality
        self.preserveEmoji = preserveEmoji
    }
}
