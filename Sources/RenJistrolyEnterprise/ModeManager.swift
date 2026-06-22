import Foundation
import RenJistrolyModels
import os

// MARK: - Operation Mode (516-525)

public enum OperationMode: String, CaseIterable, Identifiable, Sendable, Codable, Hashable {
    case readOnly
    case suggest
    case executable
    case highRisk
    case noMouse
    case localOnly
    case sensitiveAppBlock
    case autoMask
    case policyLock
    case auditExport

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .readOnly: "只读"
        case .suggest: "建议"
        case .executable: "可执行"
        case .highRisk: "高风险确认"
        case .noMouse: "禁止鼠标"
        case .localOnly: "本地模式"
        case .sensitiveAppBlock: "敏感 App 防护"
        case .autoMask: "自动遮蔽"
        case .policyLock: "策略锁定"
        case .auditExport: "审计导出"
        }
    }

    public var description: String {
        switch self {
        case .readOnly: "所有写操作被拦截，仅允许读取"
        case .suggest: "仅提供建议，不执行任何操作"
        case .executable: "允许执行标准操作"
        case .highRisk: "高风险操作需要用户确认"
        case .noMouse: "禁用鼠标控制相关操作"
        case .localOnly: "禁止所有网络调用"
        case .sensitiveAppBlock: "禁止读取敏感应用的内容"
        case .autoMask: "敏感字段（密码、密钥等）自动遮蔽"
        case .policyLock: "管理员策略锁定，不可修改"
        case .auditExport: "操作记录导出模式"
        }
    }
}

public struct ModePolicy: Sendable, Codable, Equatable {
    public var requiresConfirmation: Bool
    public var requiresApproval: Bool
    public var allowedDomains: [String]
    public var blockedDomains: [String]
    public var allowedApps: [String]
    public var blockedApps: [String]
    public var maxRiskLevel: EnterpriseRiskLevel
    public var auditRetentionDays: Int

    public static let `default` = ModePolicy(
        requiresConfirmation: false,
        requiresApproval: false,
        allowedDomains: [],
        blockedDomains: [],
        allowedApps: [],
        blockedApps: [],
        maxRiskLevel: .critical,
        auditRetentionDays: 90
    )

    public static let locked = ModePolicy(
        requiresConfirmation: true,
        requiresApproval: true,
        allowedDomains: [],
        blockedDomains: [],
        allowedApps: [],
        blockedApps: [],
        maxRiskLevel: .low,
        auditRetentionDays: 365
    )
}

public struct ModeConfiguration: Sendable, Codable, Equatable {
    public var activeModes: Set<OperationMode>
    public var policy: ModePolicy
    public var lockedModes: Set<OperationMode>
    public var maskingPatterns: [String]
    public var sensitiveAppBundleIDs: [String]

    private enum CodingKeys: String, CodingKey {
        case activeModes
        case policy
        case lockedModes
        case maskingPatterns
        case sensitiveAppBundleIDs
    }

    public init(
        activeModes: Set<OperationMode> = [],
        policy: ModePolicy = .default,
        lockedModes: Set<OperationMode> = [],
        maskingPatterns: [String] = [],
        sensitiveAppBundleIDs: [String] = []
    ) {
        self.activeModes = activeModes
        self.policy = policy
        self.lockedModes = lockedModes
        self.maskingPatterns = maskingPatterns
        self.sensitiveAppBundleIDs = sensitiveAppBundleIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.activeModes = try container.decodeIfPresent(Set<OperationMode>.self, forKey: .activeModes) ?? []
        self.policy = try container.decodeIfPresent(ModePolicy.self, forKey: .policy) ?? .default
        self.lockedModes = try container.decodeIfPresent(Set<OperationMode>.self, forKey: .lockedModes) ?? []
        self.maskingPatterns = try container.decodeIfPresent([String].self, forKey: .maskingPatterns) ?? []
        self.sensitiveAppBundleIDs = try container.decodeIfPresent([String].self, forKey: .sensitiveAppBundleIDs) ?? []
    }
}

// MARK: - Mode Evaluation

public struct ModeEvaluation: Sendable, Equatable {
    public let allowed: Bool
    public let blockedBy: OperationMode?
    public let requiresConfirmation: Bool
    public let effectiveRiskLevel: EnterpriseRiskLevel
    public let maskingRequired: Bool
    public let auditRequired: Bool

    public init(
        allowed: Bool,
        blockedBy: OperationMode? = nil,
        requiresConfirmation: Bool = false,
        effectiveRiskLevel: EnterpriseRiskLevel = .low,
        maskingRequired: Bool = false,
        auditRequired: Bool = true
    ) {
        self.allowed = allowed
        self.blockedBy = blockedBy
        self.requiresConfirmation = requiresConfirmation
        self.effectiveRiskLevel = effectiveRiskLevel
        self.maskingRequired = maskingRequired
        self.auditRequired = auditRequired
    }
}

public typealias ModeHandler = @Sendable (String, EnterpriseRiskLevel) -> Bool

// MARK: - Mode Manager

public final class ModeManager: @unchecked Sendable {
    private struct State {
        var config: ModeConfiguration
        var modeHandlers: [OperationMode: ModeHandler] = [:]
    }

    private let lock = OSAllocatedUnfairLock(initialState: State(config: .init()))

    private static func actionMatches(_ action: String, keywords: Set<String>) -> Bool {
        let components = action.split { $0 == "_" || $0 == "." || $0 == "/" }.map(String.init)
        return keywords.contains(action) || components.contains(where: { keywords.contains($0) })
    }

    public init(config: ModeConfiguration = .init()) {
        lock.withLock { state in
            state.config = config
            state.modeHandlers[.readOnly] = { (action: String, _: EnterpriseRiskLevel) in !Self.actionMatches(action, keywords: Self.writeActions) }
            state.modeHandlers[.suggest] = { (_: String, _: EnterpriseRiskLevel) in false }
            state.modeHandlers[.executable] = { (_: String, _: EnterpriseRiskLevel) in true }
            state.modeHandlers[.highRisk] = { (_: String, risk: EnterpriseRiskLevel) in risk < .high }
            state.modeHandlers[.noMouse] = { (action: String, _: EnterpriseRiskLevel) in !Self.actionMatches(action, keywords: Self.mouseActions) }
            state.modeHandlers[.localOnly] = { (action: String, _: EnterpriseRiskLevel) in !Self.actionMatches(action, keywords: Self.networkActions) }
            state.modeHandlers[.sensitiveAppBlock] = { (action: String, _: EnterpriseRiskLevel) in !Self.actionMatches(action, keywords: Self.sensitiveActions) }
            state.modeHandlers[.autoMask] = { (_: String, _: EnterpriseRiskLevel) in true }
            state.modeHandlers[.policyLock] = { (_: String, _: EnterpriseRiskLevel) in true }
            state.modeHandlers[.auditExport] = { (_: String, _: EnterpriseRiskLevel) in true }
        }
    }

    public var config: ModeConfiguration {
        lock.withLock { $0.config }
    }

    public func activate(_ mode: OperationMode) {
        lock.withLock { state in
            guard !state.config.lockedModes.contains(mode) else { return }
            state.config.activeModes.insert(mode)
        }
    }

    public func deactivate(_ mode: OperationMode) {
        lock.withLock { state in
            guard !state.config.lockedModes.contains(mode) else { return }
            state.config.activeModes.remove(mode)
        }
    }

    public func isActive(_ mode: OperationMode) -> Bool {
        lock.withLock { $0.config.activeModes.contains(mode) }
    }

    public func toggle(_ mode: OperationMode) {
        lock.withLock { state in
            guard !state.config.lockedModes.contains(mode) else { return }
            if state.config.activeModes.contains(mode) {
                state.config.activeModes.remove(mode)
            } else {
                state.config.activeModes.insert(mode)
            }
        }
    }

    public func setPolicy(_ policy: ModePolicy) {
        lock.withLock { $0.config.policy = policy }
    }

    public func lock(_ mode: OperationMode) {
        lock.withLock { state in
            state.config.lockedModes.insert(mode)
            state.config.activeModes.insert(mode)
        }
    }

    public func unlock(_ mode: OperationMode) {
        _ = lock.withLock { $0.config.lockedModes.remove(mode) }
    }

    public func evaluate(_ action: String, riskLevel: EnterpriseRiskLevel) -> ModeEvaluation {
        let snapshot = lock.withLock { (config: $0.config, handlers: $0.modeHandlers) }
        let blockedByMode = findBlockingMode(for: action, riskLevel: riskLevel, config: snapshot.config, handlers: snapshot.handlers)
        let needsConfirm = snapshot.config.policy.requiresConfirmation || riskLevel >= .high
        let effectiveRisk = min(riskLevel, snapshot.config.policy.maxRiskLevel)

        return ModeEvaluation(
            allowed: blockedByMode == nil,
            blockedBy: blockedByMode,
            requiresConfirmation: needsConfirm,
            effectiveRiskLevel: effectiveRisk,
            maskingRequired: snapshot.config.activeModes.contains(.autoMask),
            auditRequired: true
        )
    }

    public func registerHandler(for mode: OperationMode, handler: @escaping ModeHandler) {
        lock.withLock { $0.modeHandlers[mode] = handler }
    }

    private func findBlockingMode(for action: String, riskLevel: EnterpriseRiskLevel, config: ModeConfiguration, handlers: [OperationMode: ModeHandler]) -> OperationMode? {
        for mode in config.activeModes.sorted(by: { $0.rawValue < $1.rawValue }) {
            if let handler = handlers[mode], !handler(action, riskLevel) {
                return mode
            }
        }
        return nil
    }

    private static let writeActions: Set<String> = ["write", "create", "delete", "modify", "edit", "move", "copy", "rename", "save", "commit", "push"]
    private static let mouseActions: Set<String> = ["click", "doubleClick", "drag", "scroll", "moveMouse", "rightClick"]
    private static let networkActions: Set<String> = ["fetch", "download", "upload", "api", "webRequest", "network"]
    private static let sensitiveActions: Set<String> = ["readSensitiveApp", "captureSensitiveApp"]
}
