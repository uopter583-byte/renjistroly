import Foundation

/// 条款匹配引擎 — 审合同时定位相关条款
public struct ContractClauseMatcher: Sendable {
    public struct Clause: Sendable, Equatable {
        public let id: String
        public let title: String
        public let keywords: [String]
    }

    public let clauses: [Clause]

    public init(clauses: [Clause] = []) {
        self.clauses = clauses
    }

    /// 从文本中匹配已知条款
    public func match(in text: String) -> [(clause: Clause, relevance: Double)] {
        let lower = text.lowercased()
        return clauses.compactMap { clause in
            let hits = clause.keywords.filter { lower.contains($0.lowercased()) }.count
            guard hits > 0 else { return nil }
            return (clause, Double(hits) / Double(clause.keywords.count))
        }.sorted { $0.relevance > $1.relevance }
    }
}
