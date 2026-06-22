import Foundation
import AppKit
import OSLog
import IOKit
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - DarkModeTool

public struct DarkModeTool: MCPTool {
    public let definition = ToolDefinition(
        name: "dark_mode",
        description: "切换深色/浅色模式，控制 macOS 系统外观",
        parameters: [
            .init(name: "enable", type: .string, description: "true（深色）/ false（浅色）/ toggle（切换）"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let raw = arguments["enable"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: enable", isError: true)
        }

        let bridge = AppleScriptBridge()
        switch raw.lowercased() {
        case "true", "yes", "1", "on":
            _ = try await bridge.run(#"tell application "System Events" to tell appearance preferences to set dark mode to true"#)
            return ToolCallResult(id: UUID().uuidString, output: "已切换为深色模式")
        case "false", "no", "0", "off":
            _ = try await bridge.run(#"tell application "System Events" to tell appearance preferences to set dark mode to false"#)
            return ToolCallResult(id: UUID().uuidString, output: "已切换为浅色模式")
        case "toggle":
            let current = await MainActor.run { NSApp.effectiveAppearance.name }
            let isDark = current == .darkAqua
            _ = try await bridge.run(#"tell application "System Events" to tell appearance preferences to set dark mode to \#(isDark ? "false" : "true")"#)
            return ToolCallResult(id: UUID().uuidString, output: isDark ? "已从深色切换为浅色模式" : "已从浅色切换为深色模式")
        default:
            return ToolCallResult(id: UUID().uuidString, output: "无效参数: enable 应为 true/false/toggle", isError: true)
        }
    }
}

// MARK: - VolumeControlTool

public struct VolumeControlTool: MCPTool {
    public let definition = ToolDefinition(
        name: "volume_control",
        description: "音量控制，支持设置音量等级和静音切换",
        parameters: [
            .init(name: "level", type: .string, description: "音量等级 0-100", required: false),
            .init(name: "mute", type: .string, description: "true/false/toggle", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        var outputs: [String] = []
        let bridge = AppleScriptBridge()

        if let muteRaw = arguments["mute"] {
            switch muteRaw.lowercased() {
            case "true", "yes", "1", "on":
                _ = try await bridge.run(#"set volume with output muted"#)
                outputs.append("已静音")
            case "false", "no", "0", "off":
                _ = try await bridge.run(#"set volume without output muted"#)
                outputs.append("已取消静音")
            case "toggle":
                let result = try await bridge.run("output muted of (get volume settings)")
                let isMuted = result.stringValue == "true"
                if isMuted {
                    _ = try await bridge.run(#"set volume without output muted"#)
                    outputs.append("已取消静音")
                } else {
                    _ = try await bridge.run(#"set volume with output muted"#)
                    outputs.append("已静音")
                }
            default:
                return ToolCallResult(id: UUID().uuidString, output: "无效参数: mute 应为 true/false/toggle", isError: true)
            }
        }

        if let levelRaw = arguments["level"], let level = Int(levelRaw) {
            let clamped = min(max(level, 0), 100)
            _ = try await bridge.run("set volume output volume \(clamped)")
            outputs.append("音量已设为 \(clamped)")
        }

        if outputs.isEmpty {
            let result = try await bridge.run("get volume settings")
            outputs.append("当前音量: \(result.stringValue ?? "N/A")")
        }

        return ToolCallResult(id: UUID().uuidString, output: outputs.joined(separator: "，"))
    }
}

// MARK: - DisplayBrightnessTool

public struct DisplayBrightnessTool: MCPTool {
    public let definition = ToolDefinition(
        name: "display_brightness",
        description: "控制屏幕亮度，支持读取和设置亮度值",
        parameters: [
            .init(name: "level", type: .string, description: "亮度等级 0-100", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        if let levelRaw = arguments["level"], let level = Int(levelRaw) {
            let clamped = min(max(level, 0), 100)
            let normalized = Float(clamped) / 100.0
            if setBrightness(normalized) {
                return ToolCallResult(id: UUID().uuidString, output: "屏幕亮度已设为 \(clamped)")
            }
            // Fallback: try AppleScript/ioreg method
            let script = #"do shell script "ioreg -r -d 1 -k Brightness -c AppleBacklightDisplay | grep Brightness | awk '{print $NF}'""#
            _ = try? await AppleScriptBridge().run(script)
            return ToolCallResult(id: UUID().uuidString, output: "亮度设置失败：未找到内置显示器或 IOKit 写入失败，当前亮度 \(await readBrightnessString())", isError: true)
        }

        let brightness = await readBrightnessString()
        return ToolCallResult(id: UUID().uuidString, output: "当前屏幕亮度: \(brightness)")
    }

    // MARK: - Helpers

    private func readBrightnessString() async -> String {
        if let b = getBrightness() {
            let percent = Int(round(b * 100))
            return "\(percent)%"
        }
        // Fallback to ioreg
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-r", "-d", "1", "-k", "Brightness", "-c", "AppleBacklightDisplay"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            let output = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                process.terminationHandler = { _ in
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                }
                do { try process.run() } catch { continuation.resume(throwing: error) }
            }
            if let line = output.split(separator: "\n").first(where: { $0.contains("Brightness") }),
               let val = line.split(separator: "=").last?.trimmingCharacters(in: .whitespaces),
               let b = Float(val) {
                return "\(Int(round(b * 100)))%"
            }
        } catch {
            Logger.tools.error("[DisplayBrightnessTool] ioreg 失败: \(error.localizedDescription, privacy: .public)")
        }
        return "未知"
    }

    private func getBrightness() -> Float? {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleBacklightDisplay"), &iterator)
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let prop = IORegistryEntryCreateCFProperty(service, "brightness" as CFString, kCFAllocatorDefault, 0) else { return nil }
        let cfValue = prop.takeRetainedValue()
        if let v = cfValue as? Float { return v }
        if let v = cfValue as? Double { return Float(v) }
        if let v = cfValue as? Int { return Float(v) }
        return nil
    }

    private func setBrightness(_ level: Float) -> Bool {
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleBacklightDisplay"), &iterator)
        guard result == KERN_SUCCESS else { return false }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        let brightness = level as CFNumber
        return IORegistryEntrySetCFProperty(service, "brightness" as CFString, brightness) == KERN_SUCCESS
    }
}

// MARK: - NetworkInfoTool

public struct NetworkInfoTool: MCPTool {
    public let definition = ToolDefinition(
        name: "network_info",
        description: "获取网络状态信息：当前网络状态、WiFi 列表、IP 地址",
        parameters: [
            .init(name: "action", type: .string, description: "status（网络状态）/ wifi_list（WiFi 列表）/ ip（IP 地址）"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "status"

        switch action.lowercased() {
        case "status":
            return try await getNetworkStatus()
        case "wifi_list":
            return try await getWiFiList()
        case "ip":
            return try await getIPAddress()
        default:
            return ToolCallResult(id: UUID().uuidString, output: "无效参数: action 应为 status/wifi_list/ip", isError: true)
        }
    }

    private func getNetworkStatus() async throws -> ToolCallResult {
        var output = ""

        // WiFi power status
        do {
            let power = try await runProcess("/usr/sbin/networksetup", ["-getairportpower", "en0"])
            output += power.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        } catch {
            output += "WiFi: 无法获取状态\n"
        }

        // Active network interfaces
        do {
            let hardware = try await runProcess("/usr/sbin/networksetup", ["-listallhardwareports"])
            // Parse to find active interfaces
            let lines = hardware.split(separator: "\n")
            var currentPort = ""
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("Hardware Port:") {
                    currentPort = String(trimmed.dropFirst(15).trimmingCharacters(in: .whitespaces))
                } else if trimmed.hasPrefix("Device:") {
                    let device = trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces)
                    output += "接口: \(currentPort) (\(device))\n"
                }
            }
        } catch {
            output += "硬件接口: 无法获取\n"
        }

        if output.isEmpty {
            output = "无法获取网络状态"
        }
        return ToolCallResult(id: UUID().uuidString, output: output)
    }

    private func getWiFiList() async throws -> ToolCallResult {
        let airportPath = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
        do {
            let result = try await runProcess(airportPath, ["-s"])
            let lines = result.split(separator: "\n")
            guard lines.count > 1 else {
                return ToolCallResult(id: UUID().uuidString, output: "未扫描到 WiFi 网络")
            }
            // Format SSID, Signal, Security, Channel
            var output = "SSID | 信号强度 | 频道 | 安全类型\n"
            output += String(repeating: "-", count: 60) + "\n"
            // Parse each line (airport -s output: SSID, BSSID, RSSI, CHANNEL, HT, CC, SECURITY)
            for line in lines.dropFirst() {
                let parts = line.split(separator: " ", omittingEmptySubsequences: false)
                guard parts.count >= 3 else { continue }
                let ssid = parts[0]
                let rssi = parts.count > 2 ? String(parts[2]) : "N/A"
                let channel = parts.count > 3 ? String(parts[3]) : "N/A"
                let security = parts.count > 6 ? parts.dropFirst(6).joined(separator: " ") : "N/A"
                output += "\(ssid) | \(rssi) dBm | \(channel) | \(security)\n"
            }
            return ToolCallResult(id: UUID().uuidString, output: output)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "WiFi 扫描失败：\(error.localizedDescription)", isError: true)
        }
    }

    private func getIPAddress() async throws -> ToolCallResult {
        var output = ""
        do {
            let ifconfig = try await runProcess("/sbin/ifconfig", [])
            // Parse IPv4 addresses from active interfaces
            var currentInterface = ""
            for line in ifconfig.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("en") || trimmed.hasPrefix("en0") || trimmed.hasPrefix("en1") {
                    currentInterface = trimmed.split(separator: ":").first.map(String.init) ?? ""
                } else if trimmed.hasPrefix("inet ") && !currentInterface.isEmpty {
                    let ip = trimmed.dropFirst(5).split(separator: " ").first.map(String.init) ?? ""
                    output += "\(currentInterface): \(ip)\n"
                }
            }
            // Also get external IP via nat/pcp
            if output.isEmpty {
                output = "未找到活跃网络接口的 IP 地址\n"
            }
        } catch {
            output = "IP 获取失败: \(error.localizedDescription)\n"
        }
        return ToolCallResult(id: UUID().uuidString, output: output)
    }

    private func runProcess(_ executable: String, _ args: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0 {
                    continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                } else {
                    let errMsg = String(data: errData, encoding: .utf8) ?? "exit code \(process.terminationStatus)"
                    continuation.resume(throwing: NSError(domain: "NetworkInfoTool", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errMsg]))
                }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}

// MARK: - DoNotDisturbTool

public struct DoNotDisturbTool: MCPTool {
    public let definition = ToolDefinition(
        name: "do_not_disturb",
        description: "控制勿扰模式（专注模式），支持开启/关闭/切换",
        parameters: [
            .init(name: "enable", type: .string, description: "true（开启）/ false（关闭）/ toggle（切换）"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let raw = arguments["enable"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: enable", isError: true)
        }

        switch raw.lowercased() {
        case "true", "yes", "1", "on":
            try setDND(true)
            return ToolCallResult(id: UUID().uuidString, output: "勿扰模式已开启")
        case "false", "no", "0", "off":
            try setDND(false)
            return ToolCallResult(id: UUID().uuidString, output: "勿扰模式已关闭")
        case "toggle":
            let current = getDNDState()
            try setDND(!current)
            let status = !current ? "开启" : "关闭"
            return ToolCallResult(id: UUID().uuidString, output: "勿扰模式已\(status)")
        default:
            return ToolCallResult(id: UUID().uuidString, output: "无效参数: enable 应为 true/false/toggle", isError: true)
        }
    }

    private func getDNDState() -> Bool {
        do {
            let output = try runDefaults(["-currentHost", "read", "com.apple.notificationcenterui", "doNotDisturb"])
            return output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
        } catch {
            Logger.tools.error("[DoNotDisturbTool] 读取 DND 状态失败: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func setDND(_ enable: Bool) throws {
        let value = enable ? "true" : "false"
        do {
            _ = try runDefaults(["-currentHost", "write", "com.apple.notificationcenterui", "doNotDisturb", "-bool", value])
            // Apply changes by restarting notification services
            try? restartNotificationServices()
        } catch {
            Logger.tools.error("[DoNotDisturbTool] 设置 DND 失败: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func restartNotificationServices() throws {
        // Try multiple notification-related processes
        let processes = ["NotificationCenter", "usernoted"]
        for name in processes {
            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killTask.arguments = ["-HUP", name]
            killTask.standardOutput = FileHandle.nullDevice
            killTask.standardError = FileHandle.nullDevice
            try? killTask.run()
            killTask.waitUntilExit()
        }
    }

    private func runDefaults(_ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = args
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg = String(data: errData, encoding: .utf8) ?? "exit code \(process.terminationStatus)"
            throw NSError(domain: "DoNotDisturbTool", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errMsg])
        }
    }
}
