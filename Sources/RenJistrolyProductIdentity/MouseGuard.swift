import Foundation
import os

/// 防止抢鼠标 — 企业级部署保护，尊重用户主导权
public final class MouseGuard: @unchecked Sendable {
    public static let shared = MouseGuard()

    public enum AccessLevel: Sendable {
        case allowWithPermission
        case denyWhenUserActive
        case denyAlways
    }

    public enum UserState: Sendable {
        case idle
        case active
        case critical
    }

    private let lock = OSAllocatedUnfairLock()

    public var accessLevel: AccessLevel {
        get { lock.withLock { _accessLevel } }
        set { lock.withLock { _accessLevel = newValue } }
    }
    private var _accessLevel: AccessLevel = .denyWhenUserActive

    private var _isActive: Bool = false
    private var _lastActivity: Date = .distantPast
    private let activeThreshold: TimeInterval = 5

    public func checkPermission() -> Bool {
        lock.withLock {
            if _accessLevel == .denyWhenUserActive,
               Date().timeIntervalSince(_lastActivity) > activeThreshold {
                _isActive = false
            }
            switch _accessLevel {
            case .allowWithPermission:
                return true
            case .denyAlways:
                return false
            case .denyWhenUserActive:
                return !_isActive
            }
        }
    }

    public func reportUserActivity() {
        lock.withLock {
            _isActive = true
            _lastActivity = Date()
        }
    }

    public func tick() {
        lock.withLock {
            if Date().timeIntervalSince(_lastActivity) > activeThreshold {
                _isActive = false
            }
        }
    }

    public func reset() {
        lock.withLock {
            _isActive = false
            _lastActivity = .distantPast
        }
    }

    public func userState() -> UserState {
        lock.withLock {
            guard _isActive else { return UserState.idle }
            let elapsed = Date().timeIntervalSince(_lastActivity)
            if elapsed < 1 { return .critical }
            return .active
        }
    }
}
