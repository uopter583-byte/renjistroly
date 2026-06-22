import ApplicationServices
import Foundation
import AppKit
import OSLog
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - Open App Tool

public struct OpenAppTool: MCPTool {
    public let definition = ToolDefinition(
        name: "open_app",
        description: "打开或激活 macOS 应用程序",
        parameters: [
            .init(name: "app_name", type: .string, description: "应用名称或 Bundle ID"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let name = arguments["app_name"]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: app_name", isError: true)
        }

        guard AXIsProcessTrusted() else {
            return ToolCallResult(id: UUID().uuidString, output: "需要辅助功能权限（辅助功能→允许应用控制电脑）", isError: true)
        }

        let provider = AccessibilityContextProvider()
        let success = await provider.openApplication(named: name)
        if success {
            Task { await AgentEventBus.shared.publish(.desktop(.appActivated(bundleID: name, name: name))) }
            return ToolCallResult(id: UUID().uuidString, output: "已打开: \(name)")
        }
        return ToolCallResult(id: UUID().uuidString, output: "未找到应用: \(name)", isError: true)
    }
}

// MARK: - System Info Tool

public struct SystemInfoTool: MCPTool {
    public let definition = ToolDefinition(
        name: "system_info",
        description: "获取 macOS 系统信息（版本、CPU、内存等）",
        parameters: [
            .init(name: "info_type", type: .string, description: "信息类型: version, cpu, memory, disk, all"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let type = arguments["info_type"] ?? "all"

        var output = ""
        let processInfo = ProcessInfo.processInfo

        if type == "all" || type == "version" {
            let version = processInfo.operatingSystemVersionString
            output += "macOS: \(version)\n"
            output += "主机名: \(processInfo.hostName)\n"
        }
        if type == "all" || type == "cpu" {
            output += "CPU 核心数: \(processInfo.processorCount)\n"
            output += "活跃核心数: \(processInfo.activeProcessorCount)\n"
        }
        if type == "all" || type == "memory" {
            let physicalMemory = processInfo.physicalMemory
            output += "物理内存: \(ByteCountFormatter.string(fromByteCount: Int64(physicalMemory), countStyle: .memory))\n"
        }
        if type == "all" || type == "disk" {
            if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()) {
                if let total = attrs[.systemSize] as? Int64,
                   let free = attrs[.systemFreeSize] as? Int64 {
                    output += "磁盘总量: \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))\n"
                    output += "磁盘可用: \(ByteCountFormatter.string(fromByteCount: free, countStyle: .file))\n"
                }
            }
        }

        return ToolCallResult(id: UUID().uuidString, output: output)
    }
}

// MARK: - Running Apps Tool

public struct RunningAppsTool: MCPTool {
    public let definition = ToolDefinition(
        name: "running_apps",
        description: "获取当前运行的应用程序列表",
        parameters: [
            .init(name: "filter", type: .string, description: "可选过滤关键词", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let filter = arguments["filter"]?.lowercased()
        let runningApplications = await MainActor.run { NSWorkspace.shared.runningApplications }
        var apps = runningApplications
            .filter { filter != nil || $0.activationPolicy == .regular }
            .compactMap { app -> String? in
                guard let name = app.localizedName else { return nil }
                if let filter, !name.lowercased().contains(filter) { return nil }
                return "\(name) (\(app.bundleIdentifier ?? "N/A"))"
            }

        if apps.isEmpty, let filter {
            apps = runningApplications.compactMap { app -> String? in
                let name = app.localizedName ?? ""
                let bundleID = app.bundleIdentifier ?? ""
                guard name.lowercased().contains(filter) || bundleID.lowercased().contains(filter) else { return nil }
                return "\(name.isEmpty ? "Unknown" : name) (\(bundleID.isEmpty ? "N/A" : bundleID))"
            }
        }

        let output = apps.joined(separator: "\n")
        return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "无运行中的应用" : output)
    }
}

// MARK: - Open URL Tool

public struct OpenURLTool: MCPTool {
    public let definition = ToolDefinition(
        name: "open_url",
        description: "使用系统默认浏览器打开 URL",
        parameters: [
            .init(name: "url", type: .string, description: "要打开的网址"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let raw = arguments["url"], let url = URL(string: raw) else {
            return ToolCallResult(id: UUID().uuidString, output: "URL 无效", isError: true)
        }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return ToolCallResult(id: UUID().uuidString, output: "仅允许 http/https URL", isError: true)
        }
        _ = await MainActor.run { NSWorkspace.shared.open(url) }
        Task { await AgentEventBus.shared.publish(.browser(.pageLoaded(url: raw, title: nil))) }
        return ToolCallResult(id: UUID().uuidString, output: "已打开 URL: \(raw)")
    }
}
