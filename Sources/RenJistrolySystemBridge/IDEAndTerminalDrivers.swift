import AppKit
import Foundation
import RenJistrolyModels

public struct TerminalDriver: AppDriver {
    public let id = "terminal"
    public let displayName = "Terminal"
    public let capabilities: Set<AppDriverCapability> = [.open, .runCommand, .read, .manageWindows]

    public init() {}

    public func run(command: String, shell: ShellExecutor = ShellExecutor()) async throws -> ShellResult {
        try await shell.execute(command)
    }
}

public struct XcodeDriver: AppDriver {
    public let id = "xcode"
    public let displayName = "Xcode"
    public let capabilities: Set<AppDriverCapability> = [.open, .read, .runCommand, .manageWindows]
    private let appleScriptBridge: AppleScriptBridge

    public init(appleScriptBridge: AppleScriptBridge = AppleScriptBridge()) {
        self.appleScriptBridge = appleScriptBridge
    }

    public func openProject(path: String) throws {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }

    public func currentWorkspaceState() async throws -> XcodeWorkspaceState {
        let script = #"""
        tell application "Xcode"
            if not (exists front window) then
                return ""
            end if
            set windowTitle to name of front window
            set workspacePath to path of active workspace document
            set schemeName to name of active scheme
            return windowTitle & linefeed & workspacePath & linefeed & schemeName
        end tell
        """#
        let raw = try await appleScriptBridge.run(script)
        return Self.parseXcodeState(raw.stringValue)
    }

    public func getCurrentFile() async throws -> String? {
        let script = #"""
        tell application "Xcode"
            try
                set currentFile to path of document of front window
                return currentFile
            on error
                return ""
            end try
        end tell
        """#
        let result = try await appleScriptBridge.run(script)
        return result.stringValue?.nonEmptyValue
    }

    public func build() async throws -> ShellResult {
        let shell = ShellExecutor()
        let (scheme, workspaceFlag) = try await resolveBuildTarget()
        guard let scheme else {
            return ShellResult(stdout: "", stderr: "未找到 .xcodeproj 或 .xcworkspace 文件，且无法从 Xcode 获取当前 scheme", exitCode: 1)
        }
        return try await shell.execute("xcodebuild build \(workspaceFlag)-scheme \(scheme)")
    }

    public func test(filter: String? = nil) async throws -> ShellResult {
        let shell = ShellExecutor()
        let (scheme, workspaceFlag) = try await resolveBuildTarget()
        guard let scheme else {
            return ShellResult(stdout: "", stderr: "未找到构建目标", exitCode: 1)
        }
        var cmd = "xcodebuild test \(workspaceFlag)-scheme \(scheme)"
        if let filter { cmd += " -only-testing \(filter)" }
        return try await shell.execute(cmd)
    }

    public func navigateToError(file: String, line: Int) async throws {
        let script = """
        tell application "Xcode"
            activate
        end tell
        tell application "System Events"
            tell process "Xcode"
                keystroke "o" using {command down, shift down}
                delay 0.3
                keystroke "\(file)"
                delay 0.2
                keystroke return
                delay 0.2
                keystroke "l" using {command down}
                delay 0.2
                keystroke "\(line)"
                delay 0.1
                keystroke return
            end tell
        end tell
        """
        _ = try await appleScriptBridge.run(script)
        Task { await AgentEventBus.shared.publish(.code(.fileOpened(path: "\(file):\(line)"))) }
    }

    public func currentBuildDestination() async throws -> String {
        let (scheme, workspaceFlag) = try await resolveBuildTarget()
        guard let scheme else { return "unknown" }
        let shell = ShellExecutor()
        let result = try await shell.execute(
            "xcodebuild -showBuildSettings \(workspaceFlag)-scheme \(scheme) 2>/dev/null | grep -E '^\\s*PLATFORM_NAME|^\\s*ARCHS' | head -2"
        )
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: ", ")
    }

    private func resolveBuildTarget() async throws -> (scheme: String?, workspaceFlag: String) {
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath

        // 1. Try to get active scheme from Xcode front window
        if let state = try? await currentWorkspaceState(),
           let activeScheme = state.activeScheme {
            // Check if there's a workspace; prefer workspace over project
            if let wspath = state.workspacePath, wspath.hasSuffix(".xcworkspace") {
                return (activeScheme, "-workspace \(wspath) ")
            }
            return (activeScheme, "")
        }

        // 2. Fall back to scanning current directory for workspace first
        let workspaces = (try? fm.contentsOfDirectory(atPath: cwd))?.filter { $0.hasSuffix(".xcworkspace") } ?? []
        if let ws = workspaces.first {
            let scheme = (ws as NSString).deletingPathExtension
            return (scheme, "-workspace \(ws) ")
        }

        // 3. Then try project files
        let projects = (try? fm.contentsOfDirectory(atPath: cwd))?.filter { $0.hasSuffix(".xcodeproj") } ?? []
        if let project = projects.first {
            let scheme = (project as NSString).deletingPathExtension
            return (scheme, "")
        }

        return (nil, "")
    }

    public func navigateToFile(path: String, line: Int? = nil) async throws {
        let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
        var script: String
        if let line {
            script = """
            tell application "Xcode"
                activate
                open POSIX file "\(escapedPath)"
            end tell
            tell application "System Events"
                tell process "Xcode"
                    keystroke "l" using {command down}
                    delay 0.2
                    keystroke "\(line)"
                    delay 0.1
                    keystroke return
                end tell
            end tell
            """
        } else {
            script = """
            tell application "Xcode"
                activate
                open POSIX file "\(escapedPath)"
            end tell
            """
        }
        _ = try await appleScriptBridge.run(script)
    }

    public func parseBuildErrors(from output: String) -> [BuildDiagnostic] {
        Self.parseBuildDiagnostics(from: output)
    }

    public static func parseBuildDiagnostics(from output: String) -> [BuildDiagnostic] {
        let pattern = #/(.+?):(\d+):(\d+):\s+(error|warning|note):\s+(.+)/#
        var diagnostics: [BuildDiagnostic] = []
        for line in output.components(separatedBy: .newlines) {
            guard let match = try? pattern.wholeMatch(in: line) else { continue }
            diagnostics.append(BuildDiagnostic(
                id: UUID().uuidString,
                filePath: String(match.1),
                line: Int(match.2),
                column: Int(match.3),
                message: String(match.5),
                severity: {
                    switch match.4 {
                    case "error": return .error
                    case "warning": return .warning
                    default: return .note
                    }
                }()
            ))
        }
        return diagnostics
    }

    public func runTests() async throws -> ShellResult {
        let shell = ShellExecutor()
        let (scheme, workspaceFlag) = try await resolveBuildTarget()
        guard let scheme else {
            return ShellResult(stdout: "", stderr: "未找到 .xcodeproj 或 .xcworkspace 文件，且无法从 Xcode 获取当前 scheme", exitCode: 1)
        }
        return try await shell.execute("xcodebuild test \(workspaceFlag)-scheme \(scheme)")
    }

    static func parseXcodeState(_ raw: String?) -> XcodeWorkspaceState {
        let lines = (raw ?? "").components(separatedBy: .newlines)
        return XcodeWorkspaceState(
            windowTitle: lines[safe: 0]?.nonEmptyValue,
            workspacePath: lines[safe: 1]?.nonEmptyValue,
            activeScheme: lines[safe: 2]?.nonEmptyValue
        )
    }
}

public struct XcodeWorkspaceState: Codable, Sendable, Hashable {
    public let windowTitle: String?
    public let workspacePath: String?
    public let activeScheme: String?

    public init(windowTitle: String?, workspacePath: String?, activeScheme: String?) {
        self.windowTitle = windowTitle
        self.workspacePath = workspacePath
        self.activeScheme = activeScheme
    }
}
