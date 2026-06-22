import Foundation
import RenJistrolyModels
import os

/// 策略层 — 工具越多越危险，策略控制一切
public final class PolicyLayer: @unchecked Sendable {
    public static let shared = PolicyLayer()

    private struct State {
        var tier: Tier = .standard
        var rules: [Rule] = []
    }

    private let lock = OSAllocatedUnfairLock(initialState: State())

    public enum Tier: Int, Sendable, Comparable {
        case minimal = 0
        case standard = 1
        case strict = 2
        case lockdown = 3

        public static func < (lhs: Tier, rhs: Tier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public var title: String {
            switch self {
            case .minimal: "最低"
            case .standard: "标准"
            case .strict: "严格"
            case .lockdown: "锁定"
            }
        }
    }

    public struct Rule: Sendable {
        public let name: String
        public let evaluate: @Sendable (MacAction) -> PolicyDecision

        public init(name: String, evaluate: @Sendable @escaping (MacAction) -> PolicyDecision) {
            self.name = name
            self.evaluate = evaluate
        }
    }

    public var tier: Tier {
        get { lock.withLock { $0.tier } }
        set { lock.withLock { $0.tier = newValue } }
    }

    public func addRule(_ rule: Rule) {
        lock.withLock { $0.rules.append(rule) }
    }

    public func evaluate(_ action: MacAction) -> PolicyDecision {
        let snapshot = lock.withLock { (tier: $0.tier, rules: $0.rules) }
        for rule in snapshot.rules {
            let decision = rule.evaluate(action)
            switch decision {
            case .deny:
                return decision
            case .requireConfirmation where snapshot.tier >= .strict:
                return decision
            default:
                continue
            }
        }
        return .allow
    }

    public func clearRules() {
        lock.withLock { $0.rules.removeAll() }
    }

    public var ruleCount: Int {
        lock.withLock { $0.rules.count }
    }
}
