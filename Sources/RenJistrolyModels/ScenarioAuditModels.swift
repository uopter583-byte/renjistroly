import Foundation

public enum ScenarioDomain: String, CaseIterable, Identifiable, Sendable, Codable {
    case startupPermissions
    case voiceConversation
    case screenUnderstanding
    case appControl
    case elementControl
    case finderFiles
    case browser
    case messaging
    case terminalParallel
    case developerWorkflow
    case officeProductivity
    case mediaEntertainment
    case safetyPrivacy
    case selfOptimization
    case finance
    case hr
    case manager

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .startupPermissions: "启动/权限"
        case .voiceConversation: "语音对话"
        case .screenUnderstanding: "屏幕理解"
        case .appControl: "App 控制"
        case .elementControl: "控件操作"
        case .finderFiles: "文件/Finder"
        case .browser: "浏览器"
        case .messaging: "微信/邮件"
        case .terminalParallel: "多终端任务"
        case .developerWorkflow: "开发工作流"
        case .officeProductivity: "办公生产力"
        case .mediaEntertainment: "娱乐媒体"
        case .safetyPrivacy: "安全隐私"
        case .selfOptimization: "自优化恢复"
        case .finance: "财务"
        case .hr: "HR"
        case .manager: "管理者"
        }
    }
}

public enum ScenarioCoverageStatus: String, Sendable, Codable {
    case verified
    case implemented
    case partial
    case missing

    public var title: String {
        switch self {
        case .verified: "已实测"
        case .implemented: "已实现"
        case .partial: "部分"
        case .missing: "缺失"
        }
    }
}

public struct ScenarioAuditItem: Identifiable, Sendable, Codable, Equatable {
    public var id: String
    public var domain: ScenarioDomain
    public var title: String
    public var status: ScenarioCoverageStatus
    public var evidence: String
    public var nextFix: String

    public init(
        id: String,
        domain: ScenarioDomain,
        title: String,
        status: ScenarioCoverageStatus,
        evidence: String,
        nextFix: String
    ) {
        self.id = id
        self.domain = domain
        self.title = title
        self.status = status
        self.evidence = evidence
        self.nextFix = nextFix
    }
}

public struct ScenarioAuditSummary: Sendable, Codable, Equatable {
    public var total: Int
    public var verified: Int
    public var implemented: Int
    public var partial: Int
    public var missing: Int

    public var coveragePercent: Int {
        guard total > 0 else { return 0 }
        return Int(Double(verified + implemented) / Double(total) * 100)
    }

    public init(items: [ScenarioAuditItem]) {
        total = items.count
        verified = items.filter { $0.status == .verified }.count
        implemented = items.filter { $0.status == .implemented }.count
        partial = items.filter { $0.status == .partial }.count
        missing = items.filter { $0.status == .missing }.count
    }
}

public struct ScenarioAuditReport: Identifiable, Sendable, Codable, Equatable {
    public var id: UUID
    public var createdAt: Date
    public var summary: ScenarioAuditSummary
    public var items: [ScenarioAuditItem]

    public init(id: UUID = UUID(), createdAt: Date = Date(), items: [ScenarioAuditItem]) {
        self.id = id
        self.createdAt = createdAt
        self.items = items
        self.summary = ScenarioAuditSummary(items: items)
    }
}
