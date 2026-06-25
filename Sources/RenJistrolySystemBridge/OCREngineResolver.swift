import Foundation
import RenJistrolyModels

public struct OCREngineResolver: Sendable {
    public let ppocrAvailable: Bool


    public init(ppocrAvailable: Bool = PPOCRv6Service().isAvailable) {
        self.ppocrAvailable = ppocrAvailable
    }

    public func resolve(preferred: OCREngine) -> OCREngine {
        switch preferred {
        case .appleVision:
            return .appleVision
        case .ppocrV6:
            return ppocrAvailable ? .ppocrV6 : .appleVision
        case .both:
            return ppocrAvailable ? .both : .appleVision
        }
    }

    public var bestAvailable: OCREngine {
        .appleVision
    }
}
