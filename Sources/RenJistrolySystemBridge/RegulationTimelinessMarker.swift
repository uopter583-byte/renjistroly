import Foundation

/// 法规时效标记 — 追踪法规的最新修订时间和状态
public struct RegulationTimelinessMarker: Sendable {
    public enum Status: String, Sendable {
        case current, updated, repealed, pending
    }

    public struct Regulation: Sendable {
        public let name: String
        public let effectiveDate: Date
        public let lastAmended: Date?
        public let status: Status
    }

    /// 检查法规是否仍为最新版本
    public func timeliness(of regulation: Regulation, asOf date: Date = Date()) -> (status: Status, daysSinceUpdate: Int) {
        guard let amended = regulation.lastAmended else {
            let daysSince = Calendar.current.dateComponents([.day], from: regulation.effectiveDate, to: date).day ?? 0
            return (regulation.status, daysSince)
        }
        let daysSince = Calendar.current.dateComponents([.day], from: amended, to: date).day ?? 0
        return (regulation.status, daysSince)
    }

    /// 生成时效提示
    public func advisory(for regulation: Regulation) -> String {
        let (status, days) = timeliness(of: regulation)
        switch status {
        case .current:
            return days > 365 ? "距上次修订已 \(days) 天，建议核查是否有新版本" : "现行有效"
        case .updated:
            return "⚠️ 已更新，请使用最新版本"
        case .repealed:
            return "❌ 已废止"
        case .pending:
            return "⏳ 尚未生效（生效日期：\(regulation.effectiveDate)）"
        }
    }
}
