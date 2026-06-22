import Foundation

/// 全局取消机制 — 从任何地方中断当前操作
@MainActor
public final class CancelMechanism {
    public static let shared = CancelMechanism()

    public enum Scope: Sendable {
        case currentAction
        case currentPlan
        case all
    }

    public enum Reason: Sendable, Equatable {
        case userRequested
        case safetyViolation
        case timeout
        case error(String)
        case policyDenied(String)
    }

    public struct Event: Sendable {
        public let id: UUID
        public let scope: Scope
        public let reason: Reason
        public let timestamp: Date

        public init(id: UUID = UUID(), scope: Scope, reason: Reason, timestamp: Date = Date()) {
            self.id = id
            self.scope = scope
            self.reason = reason
            self.timestamp = timestamp
        }
    }

    public typealias Token = UUID

    private var tokens: Set<Token> = []
    private var handlers: [Token: @Sendable () -> Void] = [:]
    private var _isCancelled: Bool = false

    public func register(handler: @Sendable @escaping () -> Void) -> Token {
        let token = Token()
        tokens.insert(token)
        handlers[token] = handler
        return token
    }

    @discardableResult
    public func cancel(scope: Scope, reason: Reason) -> Event {
        let event = Event(scope: scope, reason: reason)
        _isCancelled = true
        for handler in handlers.values { handler() }
        if scope == .currentPlan || scope == .all {
            handlers.removeAll()
            tokens.removeAll()
        }
        return event
    }

    public func unregister(_ token: Token) {
        tokens.remove(token)
        handlers.removeValue(forKey: token)
    }

    public var isCancelled: Bool {
        _isCancelled
    }

    public func reset() {
        _isCancelled = false
        tokens.removeAll()
        handlers.removeAll()
    }
}
