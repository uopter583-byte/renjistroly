import Foundation

public enum ToolRiskLevel: String, Codable, Sendable, Comparable, CaseIterable {
    case low
    case medium
    case high

    public static func < (lhs: ToolRiskLevel, rhs: ToolRiskLevel) -> Bool {
        let order: [ToolRiskLevel] = [.low, .medium, .high]
        return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
    }
}

public struct ToolRiskAssessment: Codable, Sendable, Hashable {
    public let toolName: String
    public let riskLevel: ToolRiskLevel
    public let actionCategory: ToolActionCategory
    public let arguments: [String: String]
    public let summary: String
    public let riskExplanation: String
    public let mitigationHint: String?

    public init(
        toolName: String,
        riskLevel: ToolRiskLevel,
        actionCategory: ToolActionCategory = .unknown,
        arguments: [String: String],
        summary: String,
        riskExplanation: String = "",
        mitigationHint: String? = nil
    ) {
        self.toolName = toolName
        self.riskLevel = riskLevel
        self.actionCategory = actionCategory
        self.arguments = arguments
        self.summary = summary
        self.riskExplanation = riskExplanation
        self.mitigationHint = mitigationHint
    }
}

public enum ToolActionCategory: String, Codable, Sendable, Hashable, CaseIterable {
    case observe
    case localInput
    case localNavigation
    case localFileRead
    case localFileWrite
    case localFileDelete
    case shellRead
    case shellWrite
    case codeAgent
    case appLaunch
    case systemSetting
    case externalCommunication
    case sensitiveDataTransmission
    case credentialOrAccount
    case financial
    case installSoftware
    case unknown

    public var defaultRiskLevel: ToolRiskLevel {
        switch self {
        case .observe, .localFileRead, .shellRead:
            return .low
        case .localInput, .localNavigation, .localFileWrite, .appLaunch:
            return .medium
        case .localFileDelete, .shellWrite, .codeAgent, .systemSetting,
             .externalCommunication, .sensitiveDataTransmission,
             .credentialOrAccount, .financial, .installSoftware, .unknown:
            return .high
        }
    }

    public var requiresActionTimeConfirmation: Bool {
        switch self {
        case .localFileDelete, .systemSetting, .externalCommunication,
             .sensitiveDataTransmission, .credentialOrAccount, .financial,
             .installSoftware:
            return true
        default:
            return false
        }
    }
}

public struct ToolExecutionPolicy: Codable, Sendable, Hashable {
    public var autoApproveLow: Bool
    public var autoApproveMedium: Bool
    public var autoApproveHigh: Bool

    public static let `default` = ToolExecutionPolicy(
        autoApproveLow: true,
        autoApproveMedium: false,
        autoApproveHigh: false
    )

    public static let permissive = ToolExecutionPolicy(
        autoApproveLow: true,
        autoApproveMedium: true,
        autoApproveHigh: false
    )

    public static let strict = ToolExecutionPolicy(
        autoApproveLow: false,
        autoApproveMedium: false,
        autoApproveHigh: false
    )

    public init(autoApproveLow: Bool, autoApproveMedium: Bool, autoApproveHigh: Bool) {
        self.autoApproveLow = autoApproveLow
        self.autoApproveMedium = autoApproveMedium
        self.autoApproveHigh = autoApproveHigh
    }

    public func canAutoExecute(_ level: ToolRiskLevel) -> Bool {
        switch level {
        case .low: return autoApproveLow
        case .medium: return autoApproveMedium
        case .high: return autoApproveHigh
        }
    }
}

public struct ToolNeedsConfirmationError: Error, Sendable {
    public let assessment: ToolRiskAssessment
    public let request: ToolCallRequest

    public init(assessment: ToolRiskAssessment, request: ToolCallRequest) {
        self.assessment = assessment
        self.request = request
    }
}

public struct BatchSafetyAssessment: Codable, Sendable {
    public let items: [ToolRiskAssessment]
    public let overallRisk: ToolRiskLevel
    public let summary: String
    public let requiresBatchConfirmation: Bool
    public let confirmedCount: Int
    public let deniedCount: Int

    public init(
        items: [ToolRiskAssessment],
        overallRisk: ToolRiskLevel? = nil,
        summary: String = "",
        requiresBatchConfirmation: Bool = false,
        confirmedCount: Int = 0,
        deniedCount: Int = 0
    ) {
        self.items = items
        self.overallRisk = overallRisk ?? items.map(\.riskLevel).max() ?? .low
        self.summary = summary
        self.requiresBatchConfirmation = requiresBatchConfirmation
        self.confirmedCount = confirmedCount
        self.deniedCount = deniedCount
    }

    public var highRiskItems: [ToolRiskAssessment] { items.filter { $0.riskLevel >= .high } }
    public var mediumRiskItems: [ToolRiskAssessment] { items.filter { $0.riskLevel == .medium } }
    public var riskBreakdown: String {
        "高风险 \(highRiskItems.count) 项, 中风险 \(mediumRiskItems.count) 项, 共 \(items.count) 项"
    }
}

public struct ToolRejectedError: Error, Sendable {
    public let toolName: String

    public init(toolName: String) {
        self.toolName = toolName
    }
}

public struct ToolExecutionRecord: Identifiable, Sendable, Hashable {
    public let id: String
    public let toolName: String
    public let riskLevel: ToolRiskLevel
    public let arguments: [String: String]
    public let outcome: Outcome
    public let timestamp: Date

    public enum Outcome: Sendable, Hashable {
        case autoExecuted(String)
        case confirmed(String)
        case rejected
        case failed(String)
    }

    public init(id: String, toolName: String, riskLevel: ToolRiskLevel, arguments: [String: String], outcome: Outcome, timestamp: Date = Date()) {
        self.id = id
        self.toolName = toolName
        self.riskLevel = riskLevel
        self.arguments = arguments
        self.outcome = outcome
        self.timestamp = timestamp
    }
}
