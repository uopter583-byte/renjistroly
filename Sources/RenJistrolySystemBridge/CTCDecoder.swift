import Foundation

public struct CTCDecoder: Sendable {
    private let chars: [String]
    private let blankIndex: Int

    public init(chars: [String], blankIndex: Int = 0) {
        self.chars = chars
        self.blankIndex = blankIndex
    }

    public static func loadFromBundle() -> CTCDecoder? {
        guard let url = Bundle.module.url(forResource: "ppocr_chars", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        var chars = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        chars.insert("blank", at: 0)
        return CTCDecoder(chars: chars, blankIndex: 0)
    }

    public func greedyDecode(logits: [Float], timeSteps: Int, numClasses: Int) -> String {
        guard timeSteps > 0, numClasses > 0, logits.count >= timeSteps * numClasses else {
            return ""
        }

        var lastIndex = blankIndex
        var result = ""

        for t in 0..<timeSteps {
            let offset = t * numClasses
            var maxVal: Float = -Float.infinity
            var maxIdx = blankIndex

            for c in 0..<numClasses {
                let val = logits[offset + c]
                if val > maxVal {
                    maxVal = val
                    maxIdx = c
                }
            }

            if maxIdx != blankIndex && maxIdx != lastIndex {
                if maxIdx > 0 && maxIdx < chars.count {
                    result += chars[maxIdx]
                }
            }
            lastIndex = maxIdx
        }

        return result
    }

    public func confidence(logits: [Float], timeSteps: Int, numClasses: Int) -> Float {
        guard timeSteps > 0, numClasses > 0 else { return 0 }
        var sum: Float = 0
        var count: Int = 0
        for t in 0..<timeSteps {
            let offset = t * numClasses
            var maxVal: Float = -Float.infinity
            for c in 0..<numClasses {
                let val = logits[offset + c]
                if val > maxVal { maxVal = val }
            }
            sum += maxVal
            count += 1
        }
        return count > 0 ? sum / Float(count) : 0
    }
}
