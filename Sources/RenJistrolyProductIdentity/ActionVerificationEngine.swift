import Foundation
import RenJistrolyModels

/// 动作验证引擎 — 验证执行结果是否符合预期
@MainActor
public final class ActionVerificationEngine {
    public static let shared = ActionVerificationEngine()

    public enum VerificationResult: Sendable, Equatable {
        case success
        case partial(String)
        case failure(String)
        case unknown

        public var isSuccessful: Bool {
            switch self {
            case .success, .partial: true
            case .failure, .unknown: false
            }
        }
    }

    public struct VerificationReport: Sendable {
        public let actionID: UUID
        public let result: VerificationResult
        public let observedState: String
        public let expectedState: String
        public let duration: TimeInterval

        public init(
            actionID: UUID,
            result: VerificationResult,
            observedState: String,
            expectedState: String,
            duration: TimeInterval = 0
        ) {
            self.actionID = actionID
            self.result = result
            self.observedState = observedState
            self.expectedState = expectedState
            self.duration = duration
        }
    }

    public enum Strategy: Sendable {
        case reobserve
        case elementPresence
        case systemQuery
        case skip
    }

    public func verify(
        action: MacAction,
        expectedState: String,
        strategy: Strategy = .reobserve
    ) async -> VerificationReport {
        VerificationReport(
            actionID: action.id,
            result: .unknown,
            observedState: "待观察",
            expectedState: expectedState,
            duration: 0
        )
    }
}
