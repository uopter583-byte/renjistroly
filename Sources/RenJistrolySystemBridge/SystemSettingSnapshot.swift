import Foundation

/// 系统设置快照 — 修改系统设置前记录以便回滚
public struct SystemSettingSnapshot: Sendable {
    public struct Setting: Sendable {
        public let domain: String
        public let key: String
        public let value: AnySendable?
    }

    /// 可发送的值包装
    /// @unchecked Sendable: wraps non-Sendable Any value; accessed only by owning struct
    public struct AnySendable: @unchecked Sendable {
        public let value: Any
        public init(_ value: Any) { self.value = value }
    }

    private var snapshots: [String: [Setting]] = [:]

    public init() {}

    /// 使用 `defaults read` 记录当前设置
    public mutating func snapshot(domain: String) -> [Setting] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", domain]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let lines = output.components(separatedBy: "\n").filter { $0.contains("=") }
        let settings = lines.compactMap { line -> Setting? in
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return nil }
            return Setting(
                domain: domain,
                key: parts[0].trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\";")),
                value: AnySendable(parts[1].trimmingCharacters(in: .whitespaces))
            )
        }

        snapshots[domain] = settings
        return settings
    }

    /// 回滚指定域的所有设置
    public mutating func rollback(domain: String) -> Bool {
        guard let settings = snapshots[domain] else { return false }
        for setting in settings {
            guard let val = setting.value?.value as? String else { continue }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            task.arguments = ["write", setting.domain, setting.key, val]
            try? task.run()
            task.waitUntilExit()
        }
        snapshots.removeValue(forKey: domain)
        return true
    }
}
