import Foundation

/// 系统信息读取 — 查看设备状态
public struct SystemInfoReader: Sendable {
    public struct SystemInfo: Sendable {
        public let hostName: String
        public let osVersion: String
        public let kernelVersion: String
        public let processorCount: Int
        public let physicalMemory: UInt64
        public let uptime: TimeInterval
        public let modelName: String
    }

    /// 读取系统基本信息
    public func read() -> SystemInfo {
        let processInfo = ProcessInfo.processInfo
        return SystemInfo(
            hostName: processInfo.hostName,
            osVersion: processInfo.operatingSystemVersionString,
            kernelVersion: Self.shell("uname -r") ?? "",
            processorCount: processInfo.processorCount,
            physicalMemory: processInfo.physicalMemory,
            uptime: processInfo.systemUptime,
            modelName: Self.shell("sysctl -n hw.model") ?? ""
        )
    }

    /// 读取磁盘使用情况
    public func diskUsage() -> [(path: String, total: Int64, used: Int64)] {
        let keys: [URLResourceKey] = [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]
        guard let roots = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys) else { return [] }

        return roots.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  let total = values.volumeTotalCapacity,
                  let available = values.volumeAvailableCapacity
            else { return nil }
            return (url.path, Int64(total), Int64(total - available))
        }
    }

    private static func shell(_ cmd: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", cmd]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
