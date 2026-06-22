import Foundation

/// 屏幕稳定检测 — 如果不能稳定看屏幕就降级
@MainActor
public final class ScreenStabilityMonitor {
    public static let shared = ScreenStabilityMonitor()

    public enum StabilityLevel: Int, Sendable, Comparable {
        case stable = 2
        case unstable = 1
        case blind = 0

        public static func < (lhs: StabilityLevel, rhs: StabilityLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        public var title: String {
            switch self {
            case .stable: "稳定"
            case .unstable: "不稳定"
            case .blind: "盲操作"
            }
        }
    }

    public struct StabilityResult: Sendable {
        public let level: StabilityLevel
        public let confidence: Double
        public let message: String

        public init(level: StabilityLevel, confidence: Double, message: String) {
            self.level = level
            self.confidence = confidence
            self.message = message
        }
    }

    private var consecutiveFailures: Int = 0
    private let maxFailuresBeforeDegrade = 3

    public func checkStability() -> StabilityResult {
        if consecutiveFailures >= maxFailuresBeforeDegrade {
            return StabilityResult(level: .blind, confidence: 0.0, message: "多次截图失败，已降级为盲操作模式")
        }
        if consecutiveFailures >= maxFailuresBeforeDegrade - 1 {
            return StabilityResult(level: .unstable, confidence: 0.3, message: "截图连续失败，屏幕不稳定")
        }
        if consecutiveFailures > 0 {
            return StabilityResult(level: .unstable, confidence: 0.6, message: "检测到屏幕不稳定")
        }
        return StabilityResult(level: .stable, confidence: 1.0, message: "屏幕稳定")
    }

    public func recordFailure() -> StabilityLevel {
        consecutiveFailures += 1
        if consecutiveFailures >= maxFailuresBeforeDegrade {
            return .blind
        }
        if consecutiveFailures >= maxFailuresBeforeDegrade - 1 {
            return .unstable
        }
        return .stable
    }

    public func reset() {
        consecutiveFailures = 0
    }
}
