import Foundation

/// 证据引用 — 生成报告时引用原文证据
public struct EvidenceReferencer: Sendable {
    public struct Evidence: Sendable {
        public let source: String
        public let excerpt: String
        public let timestamp: Date?
    }

    public struct ReportSection: Sendable {
        public let claim: String
        public let evidences: [Evidence]
    }

    /// 为报告中的每条结论附上证据
    public func buildReport(sections: [ReportSection]) -> String {
        var report = "# 审计报告\n\n"
        for section in sections {
            report += "## \(section.claim)\n\n"
            for evidence in section.evidences {
                report += "- 来源: \(evidence.source)\n"
                report += "  原文: 「\(evidence.excerpt)」\n"
                report += "\n"
            }
        }
        return report
    }

    /// 验证证据是否有效
    public func validate(_ evidence: Evidence) -> Bool {
        !evidence.source.trimmingCharacters(in: .whitespaces).isEmpty &&
        !evidence.excerpt.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
