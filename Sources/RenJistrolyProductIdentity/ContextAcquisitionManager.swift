import Foundation
import CoreGraphics

/// 主动上下文获取管理器 — 在执行操作前自动收集环境信息
@MainActor
public final class ContextAcquisitionManager {
    public static let shared = ContextAcquisitionManager()

    public struct ContextSnapshot: Sendable, Equatable {
        public var frontmostApp: String?
        public var activeWindowTitle: String?
        public var screenStable: Bool
        public var mousePosition: CGPoint?
        public var runningApps: [String]
        public var timestamp: Date

        public init(
            frontmostApp: String? = nil,
            activeWindowTitle: String? = nil,
            screenStable: Bool = false,
            mousePosition: CGPoint? = nil,
            runningApps: [String] = [],
            timestamp: Date = Date()
        ) {
            self.frontmostApp = frontmostApp
            self.activeWindowTitle = activeWindowTitle
            self.screenStable = screenStable
            self.mousePosition = mousePosition
            self.runningApps = runningApps
            self.timestamp = timestamp
        }

        public static let empty = ContextSnapshot(timestamp: Date.distantPast)
    }

    public enum AcquisitionStrategy: Sendable, Equatable {
        case always
        case onDemand
        case cached(TimeInterval)
    }

    public var strategy: AcquisitionStrategy = .always
    private var cachedSnapshot: ContextSnapshot?

    public func acquireContext() async -> ContextSnapshot {
        let snapshot = ContextSnapshot(
            frontmostApp: nil,
            activeWindowTitle: nil,
            screenStable: true,
            mousePosition: nil,
            runningApps: [],
            timestamp: Date()
        )
        cachedSnapshot = snapshot
        return snapshot
    }

    public func needsFreshContext() -> Bool {
        switch strategy {
        case .always:
            return true
        case .onDemand:
            return true
        case .cached(let ttl):
            guard ttl > 0 else { return true }
            guard let cached = cachedSnapshot else { return true }
            return Date().timeIntervalSince(cached.timestamp) > ttl
        }
    }

    public func invalidateCache() {
        cachedSnapshot = nil
    }
}
