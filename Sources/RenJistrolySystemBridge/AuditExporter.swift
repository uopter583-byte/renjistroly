import Foundation

/// 审计导出 — 将权限审计结果导出为可读报告
public struct AuditExporter: Sendable {
    public struct AuditEntry: Sendable {
        public let timestamp: Date
        public let user: String
        public let action: String
        public let resource: String
        public let result: String
    }

    /// 导出为 CSV 格式
    public func exportCSV(entries: [AuditEntry]) -> String {
        var csv = "时间,用户,操作,资源,结果\n"
        let formatter = ISO8601DateFormatter()
        for entry in entries {
            csv += "\(formatter.string(from: entry.timestamp)),\(entry.user),\(entry.action),\(entry.resource),\(entry.result)\n"
        }
        return csv
    }

    /// 导出为 JSON 格式
    public func exportJSON(entries: [AuditEntry]) -> Data? {
        let dicts = entries.map { entry -> [String: Any] in
            [
                "timestamp": ISO8601DateFormatter().string(from: entry.timestamp),
                "user": entry.user,
                "action": entry.action,
                "resource": entry.resource,
                "result": entry.result,
            ]
        }
        return try? JSONSerialization.data(withJSONObject: dicts, options: [.prettyPrinted])
    }
}
