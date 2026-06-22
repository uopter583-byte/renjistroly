import Foundation

/// 语义变更检测 — 评估条款修改是否改变了法律含义
public struct SemanticChangeDetector: Sendable {
    public enum ChangeLevel: String, Sendable, Comparable {
        case none, stylistic, minor, significant, material

        public static func < (lhs: ChangeLevel, rhs: ChangeLevel) -> Bool {
            let order: [ChangeLevel] = [.none, .stylistic, .minor, .significant, .material]
            return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
        }
    }

    public struct ChangeReport: Sendable {
        public let level: ChangeLevel
        public let summary: String
        public let affectedTerms: [String]
    }

    /// 对比两个版本，返回语义变更报告
    public func compare(original: String, modified: String) -> ChangeReport {
        if original == modified { return ChangeReport(level: .none, summary: "无变更", affectedTerms: []) }

        let origWords = Set(original.split(separator: " ").map(String.init))
        let modWords = Set(modified.split(separator: " ").map(String.init))
        let added = modWords.subtracting(origWords)
        let removed = origWords.subtracting(modWords)
        let changeCount = added.count + removed.count
        let totalWords = max(origWords.count, 1)

        let ratio = Double(changeCount) / Double(totalWords)
        let level: ChangeLevel = ratio > 0.3 ? .material : ratio > 0.15 ? .significant : ratio > 0.05 ? .minor : .stylistic

        return ChangeReport(
            level: level,
            summary: level == .material ? "⚠️ 大幅度修改，建议法务审查" : "\(changeCount) 处词汇变更",
            affectedTerms: Array(added.union(removed)).sorted()
        )
    }
}
