import Foundation

/// 红线差异对比 — 版本间逐字 diff 标记
public struct RedlineDiffComparator: Sendable {
    public struct DiffSegment: Sendable {
        public enum Kind: String, Sendable { case same, inserted, deleted }
        public let kind: Kind
        public let text: String
    }

    /// 对两个文本做逐词 diff，返回带标记的片段数组
    public func diff(original: String, modified: String) -> [DiffSegment] {
        let origWords = original.components(separatedBy: " ").filter { !$0.isEmpty }
        let modWords = modified.components(separatedBy: " ").filter { !$0.isEmpty }

        var result: [DiffSegment] = []
        var oi = 0, mi = 0

        while oi < origWords.count || mi < modWords.count {
            if oi < origWords.count && mi < modWords.count, origWords[oi] == modWords[mi] {
                result.append(DiffSegment(kind: .same, text: origWords[oi]))
                oi += 1; mi += 1
            } else {
                if mi < modWords.count {
                    result.append(DiffSegment(kind: .inserted, text: modWords[mi]))
                    mi += 1
                }
                if oi < origWords.count {
                    result.append(DiffSegment(kind: .deleted, text: origWords[oi]))
                    oi += 1
                }
            }
        }
        return result
    }
}
