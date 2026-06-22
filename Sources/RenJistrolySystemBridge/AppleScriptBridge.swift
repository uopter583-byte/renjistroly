import AppKit
import Foundation

public actor AppleScriptBridge {
    private let keystrokeAnyAppSentinel = "__any__"
    private var allowedKeystrokeApps: Set<String> = []

    public init() {}

    public func allowKeystroke(for appBundleID: String) {
        allowedKeystrokeApps.insert(appBundleID)
    }

    public func run(_ script: String) async throws -> AppleScriptResult {
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw AppleScriptError.invalidScript
        }

        let result = appleScript.executeAndReturnError(&error)
        if let error = error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? -1
            let message = error[NSAppleScript.errorMessage] as? String ?? "unknown"
            throw AppleScriptError.executionFailed(code: code, message: message)
        }

        return AppleScriptResult(
            stringValue: result.stringValue,
            intValue: result.int32Value,
            success: true
        )
    }

    // MARK: - Convenience Methods

    public func getActiveAppName() async throws -> String {
        let script = #"""
        tell application "System Events"
            set frontApp to name of first application process whose frontmost is true
            return frontApp
        end tell
        """#
        let result = try await run(script)
        return result.stringValue ?? "Unknown"
    }

    public func openApp(_ bundleID: String) async throws {
        let escaped = bundleID.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application id \"\(escaped)\" to activate"
        _ = try await run(script)
    }

    public func getRunningApps() async throws -> [String] {
        let script = #"""
        tell application "System Events"
            set appList to name of every application process whose visible is true
            return appList
        end tell
        """#
        let result = try await run(script)
        return result.stringValue?.components(separatedBy: ", ") ?? []
    }

    public func sendKeystroke(_ text: String, to app: String? = nil) async throws {
        if let app {
            guard allowedKeystrokeApps.contains(app) else {
                throw AppleScriptError.keystrokeDisabled("AppleScript keystroke to \"\(app)\" is disabled by default. Call allowKeystroke(for:) to enable for this app.")
            }
        } else {
            guard allowedKeystrokeApps.contains(keystrokeAnyAppSentinel) else {
                throw AppleScriptError.keystrokeDisabled("AppleScript keystroke with no target app is disabled by default. Call allowKeystroke(for: \"__any__\") to enable for any app.")
            }
        }
        let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedApp = app.map { $0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") }
        let target = escapedApp.map { "of process \"\($0)\"" } ?? ""
        let script = #"""
        tell application "System Events"
            keystroke "\#(escapedText)" \#(target)
        end tell
        """#
        let expectedBundleID = app ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        _ = try await run(script)
        // Verify target app unchanged after keystroke
        if let expected = expectedBundleID {
            let currentBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            guard currentBundleID == expected else {
                throw AppleScriptError.executionFailed(code: -1, message: "前台应用在 keystroke 后从 \(expected) 变为 \(currentBundleID ?? "unknown")")
            }
        }
    }

    public func getFinderSelection() async throws -> [String] {
        let script = #"""
        tell application "Finder"
            set selectedItems to selection
            set output to ""
            repeat with anItem in selectedItems
                set output to output & (POSIX path of (anItem as alias)) & ","
            end repeat
            return output
        end tell
        """#
        let result = try await run(script)
        return result.stringValue?
            .components(separatedBy: ",")
            .filter { !$0.isEmpty } ?? []
    }
}

public struct AppleScriptResult: Sendable, Hashable {
    public let stringValue: String?
    public let intValue: Int32
    public let success: Bool

    public init(stringValue: String?, intValue: Int32, success: Bool) {
        self.stringValue = stringValue
        self.intValue = intValue
        self.success = success
    }
}

public enum AppleScriptError: Error, LocalizedError, Sendable {
    case invalidScript
    case executionFailed(code: Int, message: String)
    case keystrokeDisabled(String)

    public var errorDescription: String? {
        switch self {
        case .invalidScript: "AppleScript 脚本无效。"
        case .executionFailed(let code, let message): "AppleScript 执行失败 (\(code))：\(message)"
        case .keystrokeDisabled(let reason): reason
        }
    }
}
