import Foundation

public enum OCREngine: String, Codable, Sendable, Hashable, CaseIterable {
    case appleVision
    case ppocrV6
    case both

    public var displayName: String {
        switch self {
        case .appleVision: "Apple Vision"
        case .ppocrV6: "PP-OCRv6 (ONNX)"
        case .both: "双引擎合并"
        }
    }
}

public struct OCRResult: Sendable, Hashable {
    public let text: String
    public let confidence: Float
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let engine: OCREngine

    public init(text: String, confidence: Float, x: Double, y: Double, width: Double, height: Double, engine: OCREngine) {
        self.text = text
        self.confidence = confidence
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.engine = engine
    }
}
