import Foundation
import RenJistrolyModels

public struct ScreenDiffResult: Sendable {
    public let beforeText: String
    public let afterText: String
    public let addedLines: [String]
    public let removedLines: [String]
    public let changedLines: [(old: String, new: String)]
    public let similarity: Double
    public let hasExpectedChange: Bool

    public var summary: String {
        var parts: [String] = []
        if !addedLines.isEmpty { parts.append("+\(addedLines.count)行") }
        if !removedLines.isEmpty { parts.append("-\(removedLines.count)行") }
        if !changedLines.isEmpty { parts.append("~\(changedLines.count)行") }
        let base = parts.isEmpty ? "无变化" : parts.joined(separator: " ")
        return "\(base) (相似度: \(String(format: "%.1f", similarity * 100))%)"
    }
}

public actor ScreenDiffVerifier {
    private let screen: ScreenContextProvider

    public init(screen: ScreenContextProvider) {
        self.screen = screen
    }

    public func captureBefore() async -> String {
        let ctx = await screen.captureCurrentScreen(includeImageData: true, skipOwnWindows: true)
        return ctx.recognizedText ?? ""
    }

    public func captureAfterAndDiff(beforeText: String, expectedKeywords: [String] = []) async -> ScreenDiffResult {
        let afterCtx = await screen.captureCurrentScreen(includeImageData: true, skipOwnWindows: true)
        let afterText = afterCtx.recognizedText ?? ""
        return computeDiff(before: beforeText, after: afterText, expectedKeywords: expectedKeywords)
    }

    public func diff(before: String, after: String, expectedKeywords: [String] = []) -> ScreenDiffResult {
        computeDiff(before: before, after: after, expectedKeywords: expectedKeywords)
    }

    private func computeDiff(before: String, after: String, expectedKeywords: [String]) -> ScreenDiffResult {
        let beforeLines = before.split(separator: "\n").map(String.init)
        let afterLines = after.split(separator: "\n").map(String.init)
        let beforeSet = Set(beforeLines)
        let afterSet = Set(afterLines)

        let addedLines = afterLines.filter { !beforeSet.contains($0) }
        let removedLines = beforeLines.filter { !afterSet.contains($0) }

        var changedLines: [(old: String, new: String)] = []
        for removed in removedLines {
            if let best = findBestMatch(for: removed, in: addedLines) {
                changedLines.append((old: removed, new: best))
            }
        }

        let intersection = beforeSet.intersection(afterSet).count
        let union = beforeSet.union(afterSet).count
        let similarity = union > 0 ? Double(intersection) / Double(union) : 1.0

        let hasExpectedChange = expectedKeywords.isEmpty || expectedKeywords.contains { keyword in
            after.localizedCaseInsensitiveContains(keyword)
        }

        return ScreenDiffResult(
            beforeText: before,
            afterText: after,
            addedLines: addedLines,
            removedLines: removedLines,
            changedLines: changedLines,
            similarity: similarity,
            hasExpectedChange: hasExpectedChange
        )
    }

    private func findBestMatch(for line: String, in candidates: [String]) -> String? {
        var best: String?
        var bestScore = 0.0
        for candidate in candidates {
            let score = similarityScore(line, candidate)
            if score > 0.5 && score > bestScore {
                bestScore = score
                best = candidate
            }
        }
        return best
    }

    private func similarityScore(_ a: String, _ b: String) -> Double {
        let aWords = Set(a.split(separator: " "))
        let bWords = Set(b.split(separator: " "))
        guard !aWords.isEmpty, !bWords.isEmpty else { return 0 }
        let intersection = aWords.intersection(bWords).count
        let union = aWords.union(bWords).count
        return Double(intersection) / Double(union)
    }
}
