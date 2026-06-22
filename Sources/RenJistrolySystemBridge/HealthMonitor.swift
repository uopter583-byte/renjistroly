import AppKit
import Foundation
import OSLog

// MARK: - Health Monitor

/// Monitors application health: responsiveness, memory, CPU, MCP process liveness, and screen stream status.
@MainActor
public final class HealthMonitor {
    public static let shared = HealthMonitor()

    private let memoryThresholdMB: Double = 500
    private let cpuThresholdPercent: Double = 80
    private let log = OSLog(subsystem: "com.renjistroly", category: "health")
    private var monitorTask: Task<Void, Never>?
    private var screenStreamRef: ScreenStreamProvider?

    private init() {}

    /// Set a reference to the screen stream provider for health checks.
    public func setScreenStreamProvider(_ provider: ScreenStreamProvider) {
        screenStreamRef = provider
    }

    // MARK: - Snapshot

    /// Captures a point-in-time health snapshot.
    public func captureSnapshot() async -> (
        appResponsive: Bool,
        isForeground: Bool,
        memoryMB: Double,
        cpuPercent: Double,
        mcpAlive: Bool,
        streamHealthy: Bool,
        warnings: [String]
    ) {
        let appResp = true
        let fg = NSApplication.shared.isActive
        let memMB = getMemoryUsageMB()
        let cpu = getCPUUsagePercent()
        let mcp = await isMCPProcessAlive()
        let stream = await isScreenStreamHealthy()
        var warnings: [String] = []

        if memMB > memoryThresholdMB {
            let msg = String(format: "内存使用过高: %.0f MB (阈值: %.0f MB)", memMB, memoryThresholdMB)
            os_log(.fault, log: log, "%{public}@", msg)
            warnings.append(msg)
        }

        if cpu > cpuThresholdPercent {
            let msg = String(format: "CPU 使用持续过高: %.0f%% (阈值: %.0f%%)", cpu, cpuThresholdPercent)
            os_log(.fault, log: log, "%{public}@", msg)
            warnings.append(msg)
        }

        if !stream {
            warnings.append("屏幕捕获流异常")
            os_log(.fault, log: log, "屏幕捕获流异常")
        }

        if !mcp {
            warnings.append("MCP 服务进程未运行")
            os_log(.fault, log: log, "MCP 服务进程未运行")
        }

        return (appResp, fg, memMB, cpu, mcp, stream, warnings)
    }

    // MARK: - Periodic Monitoring

    /// Start periodic health checks. Call once at app launch.
    public func startPeriodicChecks() {
        stopPeriodicChecks()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                _ = await self.captureSnapshot()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    /// Stop periodic health checks.
    public func stopPeriodicChecks() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    // MARK: - Logging

    /// Log a warning message to the health subsystem.
    public func logWarning(_ message: String) {
        os_log(.fault, log: log, "%{public}@", message)
    }

    /// Produce a human-readable status report string.
    public func statusReport() async -> String {
        let snap = await captureSnapshot()
        var parts: [String] = ["=== 健康状态 ==="]
        parts.append("响应: \(snap.appResponsive ? "正常" : "无响应")")
        parts.append("前台: \(snap.isForeground ? "是" : "否")")
        parts.append(String(format: "内存: %.0f MB", snap.memoryMB))
        parts.append(String(format: "CPU: %.0f%%", snap.cpuPercent))
        parts.append("MCP: \(snap.mcpAlive ? "运行中" : "未运行")")
        parts.append("屏幕流: \(snap.streamHealthy ? "正常" : "异常")")
        if !snap.warnings.isEmpty {
            parts.append("告警: \(snap.warnings.joined(separator: "; "))")
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - Private Measurements

    private func isMCPProcessAlive() async -> Bool {
        let apps = NSWorkspace.shared.runningApplications
        return apps.contains { app in
            app.executableURL?.lastPathComponent == "RenJistrolyMCP" ||
            app.bundleIdentifier == "com.renjistroly.mcp"
        }
    }

    private func isScreenStreamHealthy() async -> Bool {
        guard let ref = screenStreamRef else { return false }
        return await ref.isActive
    }

    private func getMemoryUsageMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size) / 4
        let kr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / (1024 * 1024)
    }

    private func getCPUUsagePercent() -> Double {
        var threads: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        let kr = task_threads(mach_task_self_, &threads, &threadCount)
        guard kr == KERN_SUCCESS, let threadList = threads else { return 0 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threadList),
                          vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride))
        }

        var total: Double = 0
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size) / 4
            let kr2 = withUnsafeMutablePointer(to: &info) { ptr in
                ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                    thread_info(threadList[i], thread_flavor_t(THREAD_BASIC_INFO), intPtr, &count)
                }
            }
            if kr2 == KERN_SUCCESS {
                let infoData = info as thread_basic_info
                if infoData.flags & TH_FLAGS_IDLE == 0 {
                    total += Double(infoData.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                }
            }
        }
        return min(total, 100.0)
    }
}
