import Foundation

/// 同意确认 — 远程协助用户前必须获得用户明确同意
public struct RemoteAssistConsent: Sendable {
    public enum ConsentState: String, Sendable {
        case notRequested, pending, granted, denied
    }

    public struct ConsentRecord: Sendable {
        public let sessionId: String
        public let state: ConsentState
        public let timestamp: Date
        public let durationMinutes: Int
    }

    /// 请求用户同意
    public func requestConsent(assistantName: String, purpose: String) -> ConsentRecord {
        ConsentRecord(
            sessionId: UUID().uuidString,
            state: .pending,
            timestamp: Date(),
            durationMinutes: 0
        )
    }

    /// 用户同意后更新记录
    public func grant(_ record: ConsentRecord) -> ConsentRecord {
        ConsentRecord(
            sessionId: record.sessionId,
            state: .granted,
            timestamp: record.timestamp,
            durationMinutes: 30
        )
    }

    /// 用户拒绝
    public func deny(_ record: ConsentRecord) -> ConsentRecord {
        ConsentRecord(
            sessionId: record.sessionId,
            state: .denied,
            timestamp: record.timestamp,
            durationMinutes: 0
        )
    }

    /// 检查是否已过期
    public func isExpired(_ record: ConsentRecord) -> Bool {
        guard record.state == .granted else { return true }
        let elapsed = Date().timeIntervalSince(record.timestamp)
        return elapsed > Double(record.durationMinutes * 60)
    }
}
