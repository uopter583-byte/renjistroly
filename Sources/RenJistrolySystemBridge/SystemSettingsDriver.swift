import AppKit
import Foundation
import RenJistrolyModels

public struct SystemSettingsDriver: AppDriver {
    public let id = "system-settings"
    public let displayName = "System Settings"
    public let capabilities: Set<AppDriverCapability> = [.open, .read, .requiresConfirmationBeforeSend]

    public init() {}

    public func open(pane: SystemSettingsPane) throws {
        if let url = pane.url {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback: open System Settings app
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
        }
    }

    public func openSystemSettings() throws {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    public func readSetting(domain: String, key: String) async throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", domain, key]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        let (output, _) = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, Int32), Error>) in
            process.terminationHandler = { proc in
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: (String(data: data, encoding: .utf8) ?? "", proc.terminationStatus))
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum SystemSettingsPane: String, Sendable, CaseIterable {
    case wifi = "Wi-Fi"
    case bluetooth = "Bluetooth"
    case network = "Network"
    case notifications = "Notifications"
    case sound = "Sound"
    case focus = "Focus"
    case screenTime = "Screen Time"
    case general = "General"
    case appearance = "Appearance"
    case accessibility = "Accessibility"
    case controlCenter = "Control Center"
    case siri = "Siri & Spotlight"
    case privacy = "Privacy & Security"
    case desktop = "Desktop & Dock"
    case displays = "Displays"
    case wallpaper = "Wallpaper"
    case screenSaver = "Screen Saver"
    case battery = "Battery"
    case mouse = "Mouse"
    case trackpad = "Trackpad"
    case keyboard = "Keyboard"
    case printers = "Printers & Scanners"
    case storage = "General/Storage"
    case softwareUpdate = "General/Software Update"
    case timeMachine = "General/Time Machine"
    case startupDisk = "General/Startup Disk"
    case users = "Users & Groups"
    case passwords = "Passwords"
    case internetAccounts = "Internet Accounts"
    case gameCenter = "Game Center"
    case wallet = "Wallet & Apple Pay"

    public var url: URL? {
        switch self {
        case .wifi: URL(string: "x-apple.systempreferences:com.apple.preference.network?Wi-Fi")
        case .bluetooth: URL(string: "x-apple.systempreferences:com.apple.preferences.Bluetooth")
        case .notifications: URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
        case .sound: URL(string: "x-apple.systempreferences:com.apple.preference.sound")
        case .general: URL(string: "x-apple.systempreferences:com.apple.systempreferences")
        case .appearance: URL(string: "x-apple.systempreferences:com.apple.preferences.Appearance")
        case .accessibility: URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess")
        case .desktop: URL(string: "x-apple.systempreferences:com.apple.preferences.DesktopScreenEffectsPref")
        case .displays: URL(string: "x-apple.systempreferences:com.apple.preference.displays")
        case .battery: URL(string: "x-apple.systempreferences:com.apple.preference.battery")
        case .keyboard: URL(string: "x-apple.systempreferences:com.apple.preference.keyboard")
        case .trackpad: URL(string: "x-apple.systempreferences:com.apple.preference.trackpad")
        case .mouse: URL(string: "x-apple.systempreferences:com.apple.preference.mouse")
        case .privacy: URL(string: "x-apple.systempreferences:com.apple.preference.security")
        case .softwareUpdate: URL(string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension")
        case .passwords: URL(string: "x-apple.systempreferences:com.apple.Passwords")
        default: nil
        }
    }
}
