import Foundation
import CoreGraphics

/// 窗口匹配验证 — 防止贴错窗口
public struct WindowMatchValidator {
    public struct WindowDescriptor: Sendable, Equatable {
        public var title: String
        public var bundleID: String
        public var processID: pid_t
        public var frame: CGRect

        public init(title: String, bundleID: String, processID: pid_t, frame: CGRect) {
            self.title = title
            self.bundleID = bundleID
            self.processID = processID
            self.frame = frame
        }
    }

    public struct MatchResult: Sendable {
        public let matched: Bool
        public let confidence: Double
        public let reasons: [String]

        public init(matched: Bool, confidence: Double, reasons: [String] = []) {
            self.matched = matched
            self.confidence = confidence
            self.reasons = reasons
        }

        public static let noMatch = MatchResult(matched: false, confidence: 0, reasons: ["无匹配窗口"])
    }

    public enum MatchStrategy: Sendable {
        case exact
        case fuzzy
        case pid
    }

    public func validate(
        target: WindowDescriptor,
        candidates: [WindowDescriptor],
        strategy: MatchStrategy = .exact
    ) -> MatchResult {
        switch strategy {
        case .exact:
            for c in candidates where c.title == target.title && c.bundleID == target.bundleID {
                return MatchResult(matched: true, confidence: 1.0, reasons: ["精确匹配"])
            }
            return .noMatch

        case .fuzzy:
            var best: (score: Double, reasons: [String])?
            for c in candidates {
                var score: Double = 0
                var reasons: [String] = []
                if c.title.contains(target.title) || target.title.contains(c.title) {
                    score += 0.5; reasons.append("标题模糊匹配")
                }
                if c.bundleID == target.bundleID { score += 0.4; reasons.append("BundleID 匹配") }
                if c.processID == target.processID { score += 0.1; reasons.append("PID 匹配") }
                if score > (best?.score ?? 0) { best = (score, reasons) }
            }
            guard let best else { return .noMatch }
            return MatchResult(matched: best.score > 0.6, confidence: best.score, reasons: best.reasons)

        case .pid:
            for c in candidates where c.processID == target.processID {
                return MatchResult(matched: true, confidence: 0.9, reasons: ["PID 匹配"])
            }
            return .noMatch
        }
    }
}
