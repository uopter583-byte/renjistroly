import Foundation
@testable import RenJistrolyModels

// MARK: - MockScrollBridge

actor MockScrollBridge {
    var scrollCallCount: Int = 0
    var recordedArgs: [(deltaY: Int, deltaX: Int, lines: Int)] = []
    let shouldThrow: Bool

    init(shouldThrow: Bool = false) {
        self.shouldThrow = shouldThrow
    }
}

extension MockScrollBridge: AccessibilityScrolling {
    func scroll(deltaY: Int, deltaX: Int, lines: Int) async throws {
        scrollCallCount += 1
        recordedArgs.append((deltaY, deltaX, lines))
        if shouldThrow { throw MockScrollError.failed }
    }
}

enum MockScrollError: Error {
    case failed
}
