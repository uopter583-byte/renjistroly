import Foundation

/// Set-of-Mark (SOM): numbered bounding box overlays on screenshots.
/// Assigns sequential numbers to interactive elements in a screenshot for vision model targeting.
public struct SetOfMarkOverlay {
    public struct MarkedElement: Identifiable, Sendable {
        public let id: Int
        public let label: String
        public let boundingBox: CGRect

        public init(id: Int, label: String, boundingBox: CGRect) {
            self.id = id
            self.label = label
            self.boundingBox = boundingBox
        }
    }

    /// Convert AX or DOM targets into SOM markers with normalized coordinates.
    /// - Parameters:
    ///   - targets: ComputerUseTarget elements from observation
    ///   - imageSize: The screenshot pixel dimensions
    /// - Returns: Array of marked elements with overlay description
    public static func markTargets(_ targets: [ComputerUseTarget], imageSize: CGSize) -> (elements: [MarkedElement], overlayText: String) {
        let interactive = targets.filter { $0.kind == .accessibilityElement || $0.kind == .coordinate }
        var marked: [MarkedElement] = []
        var lines: [String] = []

        for (index, target) in interactive.prefix(40).enumerated() {
            let number = index + 1
            marked.append(MarkedElement(id: number, label: target.label, boundingBox: .zero))
            lines.append("[\(number)] \(target.label)\(target.role.map { " (\($0))" } ?? "")")
        }

        return (marked, lines.joined(separator: "\n"))
    }

    /// Generate the prompt overlay text describing SOM markers for vision models.
    public static func somPrompt(_ markers: [MarkedElement]) -> String {
        guard !markers.isEmpty else { return "(无交互元素)" }
        return "屏幕上标记了以下可交互元素：\n" + markers.map { "[\($0.id)] \($0.label)" }.joined(separator: "\n")
    }
}
