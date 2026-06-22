import Foundation

/// 主体匹配验证 — 防止在合同中填错法律主体
public struct EntityMatcher: Sendable {
    public struct Entity: Sendable, Equatable {
        public let fullName: String
        public let shortName: String
        public let registrationNumber: String?
    }

    public struct MatchResult: Sendable {
        public let isMatch: Bool
        public let confidence: Double
        public let suggestion: String?
    }

    /// 验证输入的主体名称是否匹配已知实体
    public func match(input: String, against entities: [Entity]) -> MatchResult {
        let lower = input.lowercased()
        for entity in entities {
            if lower == entity.fullName.lowercased() || lower == entity.shortName.lowercased() {
                return MatchResult(isMatch: true, confidence: 1.0, suggestion: nil)
            }
        }

        // 模糊匹配
        let candidates = entities.filter { entity in
            let full = entity.fullName.lowercased()
            let short = entity.shortName.lowercased()
            return full.contains(lower) || short.contains(lower) || lower.contains(full) || lower.contains(short)
        }

        if let best = candidates.first {
            return MatchResult(isMatch: false, confidence: 0.5, suggestion: "您是否指「\(best.fullName)」？")
        }
        return MatchResult(isMatch: false, confidence: 0, suggestion: "未找到匹配主体，请确认输入是否正确")
    }
}
