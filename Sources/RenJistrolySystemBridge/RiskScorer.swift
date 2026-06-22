import Foundation

/// 风险等级评估 — 为总结提供依据
public struct RiskScorer: Sendable {
    public enum Level: String, Sendable, Comparable {
        case low, medium, high, critical

        public static func < (lhs: Level, rhs: Level) -> Bool {
            let order: [Level] = [.low, .medium, .high, .critical]
            return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
        }
    }

    public struct Assessment: Sendable {
        public let level: Level
        public let score: Int
        public let reasons: [String]
    }

    /// 根据风险因子清单进行评估
    public func assess(factors: [(description: String, severity: Level)]) -> Assessment {
        let scoreMap: [Level: Int] = [.low: 1, .medium: 3, .high: 6, .critical: 10]
        let total = factors.reduce(0) { $0 + (scoreMap[$1.severity] ?? 0) }
        let reasons = factors.filter { $0.severity >= .medium }.map { $0.description }

        let level: Level = total >= 20 ? .critical : total >= 10 ? .high : total >= 4 ? .medium : .low
        return Assessment(level: level, score: total, reasons: reasons)
    }
}
