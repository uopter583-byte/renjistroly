import Foundation

/// 免责声明模板 + 审批流 — 法律意见的标准化免责与审批
public struct DisclaimerTemplate: Sendable {
    public struct LegalOpinion: Sendable {
        public let title: String
        public let content: String
        public let disclaimer: String
        public let requiresApproval: Bool
        public let approvedBy: String?
    }

    /// 标准免责声明
    public static let standardDisclaimer = """
    本意见仅供参考，不构成正式法律意见。具体法律事务请咨询执业律师。
    本文件基于提供的信息生成，信息的完整性和准确性可能影响结论的可靠性。
    """

    /// 生成带标准免责声明的法律意见
    public func generateOpinion(title: String, content: String, requireApproval: Bool = true) -> LegalOpinion {
        LegalOpinion(
            title: title,
            content: content,
            disclaimer: Self.standardDisclaimer,
            requiresApproval: requireApproval,
            approvedBy: nil
        )
    }

    /// 审批法律意见
    public func approve(_ opinion: LegalOpinion, by reviewer: String) -> LegalOpinion {
        LegalOpinion(
            title: opinion.title,
            content: opinion.content,
            disclaimer: opinion.disclaimer,
            requiresApproval: opinion.requiresApproval,
            approvedBy: reviewer
        )
    }
}
