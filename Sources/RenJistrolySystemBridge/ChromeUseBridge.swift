import Foundation

/// chrome-use integration bridge — MCP-based anti-detection browser control.
/// chrome-use provides a standalone Rust CLI that launches Chrome with evasion flags
/// and exposes a JSON-RPC MCP server for page automation.
public enum ChromeUseBridge {
    public struct ChromeUseConfig: Sendable, Codable {
        public var executablePath: String
        public var userDataDir: String
        public var remoteDebugPort: Int
        public var headless: Bool

        public init(executablePath: String = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
                     userDataDir: String = "\(NSHomeDirectory())/Library/Application Support/Google/Chrome/Default",
                     remoteDebugPort: Int = 9222,
                     headless: Bool = false) {
            self.executablePath = executablePath
            self.userDataDir = userDataDir
            self.remoteDebugPort = remoteDebugPort
            self.headless = headless
        }
    }

    /// Chrome launch flags for anti-detection (porting from chrome-use detection-bypass flags)
    public static func antiDetectionFlags(config: ChromeUseConfig) -> [String] {
        var flags: [String] = [
            "--remote-debugging-port=\(config.remoteDebugPort)",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-sync",
            "--disable-background-networking",
            "--disable-background-timer-throttling",
            "--disable-breakpad",
            "--disable-client-side-phishing-detection",
            "--disable-component-update",
            "--disable-features=ChromeWhatsNewUI",
            "--disable-field-trial-config",
            "--disable-prompt-on-repost",
            "--disable-speech-api",
            "--disable-sync",
            "--hide-crash-restore-bubble",
            "--metrics-recording-only",
            "--no-pings",
            "--use-mock-keychain",
        ]
        if config.headless {
            flags.append("--headless=new")
        }
        return flags
    }

    /// Check if chrome-use CLI is available.
    public static var isAvailable: Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "chrome-use"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return !data.isEmpty
    }
}
