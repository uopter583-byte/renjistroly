import Foundation

/// 环境区分 — 响应告警时区分生产/测试环境
public struct EnvironmentDistinguisher: Sendable {
    public enum Environment: String, Sendable {
        case production, staging, development, testing
    }

    /// 根据主机名或配置判断当前环境
    public func detect() -> Environment {
        let host = ProcessInfo.processInfo.hostName.lowercased()
        if host.contains("prod") || host.contains("production") { return .production }
        if host.contains("staging") || host.contains("stage") { return .staging }
        if host.contains("dev") || host.contains("develop") { return .development }
        return .development
    }

    /// 检查是否允许在生产环境执行操作
    public func allowProduction(operation: String) -> Bool {
        // 只有明确标记的操作才能在生产环境执行
        let safeOps = ["read", "monitor", "report"]
        return safeOps.contains { operation.lowercased().contains($0) }
    }

    /// 返回环境标签（用于告警消息前缀）
    public func label(for env: Environment) -> String {
        switch env {
        case .production: return "🔴 PRODUCTION"
        case .staging: return "🟡 STAGING"
        case .development: return "🟢 DEVELOPMENT"
        case .testing: return "🔵 TESTING"
        }
    }
}
