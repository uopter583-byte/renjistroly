import Foundation

/// 状态机管理 — 防止越用越乱
@MainActor
public final class StateMachineManager {
    public static let shared = StateMachineManager()

    public enum AgentState: String, Sendable, Codable {
        case idle
        case observing
        case planning
        case executing
        case verifying
        case waitingForUser
        case cancelled
        case error

        public var title: String {
            switch self {
            case .idle: "空闲"
            case .observing: "观察中"
            case .planning: "规划中"
            case .executing: "执行中"
            case .verifying: "验证中"
            case .waitingForUser: "等待用户"
            case .cancelled: "已取消"
            case .error: "错误"
            }
        }
    }

    public struct Transition: Sendable {
        public let from: AgentState
        public let to: AgentState
        public let timestamp: Date

        public init(from: AgentState, to: AgentState, timestamp: Date = Date()) {
            self.from = from
            self.to = to
            self.timestamp = timestamp
        }
    }

    public private(set) var state: AgentState = .idle
    private var history: [Transition] = []

    private let allowed: [AgentState: Set<AgentState>] = [
        .idle: [.observing, .waitingForUser, .cancelled],
        .observing: [.planning, .idle, .cancelled, .error],
        .planning: [.executing, .idle, .cancelled, .error],
        .executing: [.verifying, .waitingForUser, .cancelled, .error],
        .verifying: [.idle, .executing, .cancelled, .error],
        .waitingForUser: [.idle, .observing, .cancelled],
        .cancelled: [.idle],
        .error: [.idle, .observing],
    ]

    @discardableResult
    public func transition(to newState: AgentState) -> Bool {
        guard let valid = allowed[state], valid.contains(newState) else {
            return false
        }
        history.append(Transition(from: state, to: newState))
        state = newState
        return true
    }

    public func recent(limit: Int = 10) -> [Transition] {
        Array(history.suffix(limit))
    }

    public func reset() {
        state = .idle
        history.removeAll()
    }
}
