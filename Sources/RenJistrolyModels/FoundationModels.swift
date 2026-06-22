import Foundation

public enum FoundationLayer: Int, CaseIterable, Identifiable, Sendable, Codable {
    case feedbackLoop = 1
    case selfOptimizationRecovery
    case permissionIdentity
    case localActionExecution
    case userMemory
    case realtimeVoice
    case providerAbstraction
    case screenUnderstanding
    case diagnostics
    case safetyBoundary
    case installRelease
    case operatorUI

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .feedbackLoop: "反馈闭环"
        case .selfOptimizationRecovery: "自优化与恢复"
        case .permissionIdentity: "权限与身份稳定"
        case .localActionExecution: "本地动作执行"
        case .userMemory: "用户记忆"
        case .realtimeVoice: "实时语音"
        case .providerAbstraction: "Provider 抽象"
        case .screenUnderstanding: "屏幕理解"
        case .diagnostics: "日志与诊断"
        case .safetyBoundary: "安全边界"
        case .installRelease: "安装与发布"
        case .operatorUI: "UI 操作层"
        }
    }

    public var baselineRequirement: String {
        switch self {
        case .feedbackLoop: "用户反馈失败时，自动记录上下文、分类、生成修复任务。"
        case .selfOptimizationRecovery: "升级必须可审计、可测试、可回滚到基础版本。"
        case .permissionIdentity: "签名、Bundle ID、授权对象和安装路径必须稳定。"
        case .localActionExecution: "常见 Mac 动作必须本地执行，并返回明确结果。"
        case .userMemory: "常用 App、别名、偏好和失败历史必须本地可记忆。"
        case .realtimeVoice: "连续语音交流要有听、想、说、继续听的稳定状态机。"
        case .providerAbstraction: "多模型 Provider 要可配置、可诊断、可 fallback。"
        case .screenUnderstanding: "屏幕回答必须基于 OCR、窗口、控件树或视觉来源。"
        case .diagnostics: "最近一次输入、解析、请求、动作、错误必须可查看。"
        case .safetyBoundary: "动作按风险分级，高风险默认不可自动执行。"
        case .installRelease: "发布包、快捷方式、签名、备份和恢复路径必须固定。"
        case .operatorUI: "用户必须看得懂当前状态、失败原因和下一步按钮。"
        }
    }
}

public enum FoundationHealthStatus: String, Sendable, Codable {
    case ok
    case warning
    case failing
    case notImplemented

    public var label: String {
        switch self {
        case .ok: "正常"
        case .warning: "需关注"
        case .failing: "失败"
        case .notImplemented: "未完成"
        }
    }
}

public struct FoundationLayerSnapshot: Identifiable, Sendable, Codable, Equatable {
    public var id: FoundationLayer { layer }
    public var layer: FoundationLayer
    public var status: FoundationHealthStatus
    public var detail: String

    public init(layer: FoundationLayer, status: FoundationHealthStatus, detail: String) {
        self.layer = layer
        self.status = status
        self.detail = detail
    }
}

public struct FoundationCapabilityEvidence: Sendable, Codable, Equatable {
    public var terminalTaskCount: Int
    public var hasRunningOrCompletedTerminalTask: Bool
    public var lastObservationTargetCount: Int
    public var lastObservationAccessibilityTargetCount: Int
    public var lastActionWasVerified: Bool
    public var memoryCount: Int
    public var providerHealthCount: Int

    public init(
        terminalTaskCount: Int = 0,
        hasRunningOrCompletedTerminalTask: Bool = false,
        lastObservationTargetCount: Int = 0,
        lastObservationAccessibilityTargetCount: Int = 0,
        lastActionWasVerified: Bool = false,
        memoryCount: Int = 0,
        providerHealthCount: Int = 0
    ) {
        self.terminalTaskCount = terminalTaskCount
        self.hasRunningOrCompletedTerminalTask = hasRunningOrCompletedTerminalTask
        self.lastObservationTargetCount = lastObservationTargetCount
        self.lastObservationAccessibilityTargetCount = lastObservationAccessibilityTargetCount
        self.lastActionWasVerified = lastActionWasVerified
        self.memoryCount = memoryCount
        self.providerHealthCount = providerHealthCount
    }
}

public enum FeedbackCategory: String, CaseIterable, Sendable, Codable {
    case speechRecognition
    case modelResponse
    case actionExecution
    case permission
    case screenUnderstanding
    case provider
    case performance
    case ui
    case upgrade
    case unknown

    public var title: String {
        switch self {
        case .speechRecognition: "语音识别"
        case .modelResponse: "模型回复"
        case .actionExecution: "动作执行"
        case .permission: "权限"
        case .screenUnderstanding: "屏幕理解"
        case .provider: "Provider"
        case .performance: "速度"
        case .ui: "界面"
        case .upgrade: "升级"
        case .unknown: "未知"
        }
    }
}

public struct AssistantDiagnosticSnapshot: Identifiable, Sendable, Codable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var userText: String
    public var assistantText: String
    public var provider: String
    public var frontmostApp: String?
    public var windowTitle: String?
    public var focusedRole: String?
    public var screenSummary: String?
    public var parsedAction: String?
    public var actionResult: String?
    public var permissions: [String: String]
    public var error: String?
    public var latencyMilliseconds: Int?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        userText: String,
        assistantText: String,
        provider: String,
        frontmostApp: String? = nil,
        windowTitle: String? = nil,
        focusedRole: String? = nil,
        screenSummary: String? = nil,
        parsedAction: String? = nil,
        actionResult: String? = nil,
        permissions: [String: String] = [:],
        error: String? = nil,
        latencyMilliseconds: Int? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.userText = userText
        self.assistantText = assistantText
        self.provider = provider
        self.frontmostApp = frontmostApp
        self.windowTitle = windowTitle
        self.focusedRole = focusedRole
        self.screenSummary = screenSummary
        self.parsedAction = parsedAction
        self.actionResult = actionResult
        self.permissions = permissions
        self.error = error
        self.latencyMilliseconds = latencyMilliseconds
    }
}

public struct FeedbackReport: Identifiable, Sendable, Codable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var category: FeedbackCategory
    public var userComplaint: String
    public var diagnosticID: UUID?
    public var proposedFix: String
    public var status: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        category: FeedbackCategory,
        userComplaint: String,
        diagnosticID: UUID?,
        proposedFix: String,
        status: String = "待处理"
    ) {
        self.id = id
        self.createdAt = createdAt
        self.category = category
        self.userComplaint = userComplaint
        self.diagnosticID = diagnosticID
        self.proposedFix = proposedFix
        self.status = status
    }
}

public struct UserOperationMemory: Identifiable, Sendable, Codable, Equatable {
    public var id: UUID
    public var key: String
    public var value: String
    public var category: String
    public var confidence: Double
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        key: String,
        value: String,
        category: String,
        confidence: Double = 0.5,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.category = category
        self.confidence = confidence
        self.updatedAt = updatedAt
    }
}

public struct UpgradePlan: Identifiable, Sendable, Codable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var title: String
    public var reason: String
    public var steps: [String]
    public var risk: ActionRiskLevel
    public var status: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String,
        reason: String,
        steps: [String],
        risk: ActionRiskLevel = .persistentOrExternal,
        status: String = "草案"
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.reason = reason
        self.steps = steps
        self.risk = risk
        self.status = status
    }
}

public struct ProviderHealthSnapshot: Identifiable, Sendable, Codable, Equatable {
    public var id: ProviderKind { kind }
    public var kind: ProviderKind
    public var status: FoundationHealthStatus
    public var latencyMilliseconds: Int?
    public var detail: String
    public var checkedAt: Date

    public init(
        kind: ProviderKind,
        status: FoundationHealthStatus,
        latencyMilliseconds: Int? = nil,
        detail: String,
        checkedAt: Date = Date()
    ) {
        self.kind = kind
        self.status = status
        self.latencyMilliseconds = latencyMilliseconds
        self.detail = detail
        self.checkedAt = checkedAt
    }
}
