import Foundation

@main
struct RenJistrolyGateApp {
    static let gateDir = "/tmp/renjistroly"
    static var speechFile: String { "\(gateDir)/speech_in.txt" }
    static var replyFile: String { "\(gateDir)/reply_out.txt" }

    static func main() {
        let args = CommandLine.arguments
        guard args.count >= 2 else {
            printUsage()
            exit(1)
        }

        do {
            try FileManager.default.createDirectory(atPath: gateDir, withIntermediateDirectories: true)
        } catch {
            fputs("gate: cannot create \(gateDir): \(error)\n", stderr)
            exit(1)
        }

        switch args[1] {
        case "watch":
            watch()
        case "reply":
            let text = args.dropFirst(2).joined(separator: " ")
            guard !text.isEmpty else { fputs("gate: reply needs text\n", stderr); exit(1) }
            reply(text)
        case "clear":
            clear()
        case "status":
            status()
        case "help", "--help", "-h":
            printUsage()
        default:
            fputs("gate: unknown command '\(args[1])'\n", stderr)
            printUsage()
            exit(1)
        }
    }

    // watch: tail -f equivalent. Prints new speech entries as they arrive.
    static func watch() {
        // Create file if not exist
        if !FileManager.default.fileExists(atPath: speechFile) {
            FileManager.default.createFile(atPath: speechFile, contents: nil)
        }

        guard let handle = FileHandle(forReadingAtPath: speechFile) else {
            fputs("gate: cannot open speech file\n", stderr)
            exit(1)
        }
        defer { handle.closeFile() }

        // Seek to end to only get new messages
        handle.seekToEndOfFile()

        fputs("gate: watching \(speechFile)\n", stderr)

        while true {
            let data = handle.readData(ofLength: 65536)
            if data.isEmpty {
                usleep(300_000) // 300ms poll
                continue
            }
            if let text = String(data: data, encoding: .utf8) {
                let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
                for line in lines {
                    print(line)
                    fflush(stdout)
                }
            }
        }
    }

    // reply: write reply text to reply_out.txt
    static func reply(_ text: String) {
        do {
            try text.write(to: URL(fileURLWithPath: replyFile), atomically: true, encoding: .utf8)
            print("{\"success\":true,\"message\":\"reply written\"}")
        } catch {
            print("{\"success\":false,\"error\":\"\(error.localizedDescription)\"}")
            exit(1)
        }
    }

    // clear: clear both speech and reply files
    static func clear() {
        do {
            try "".write(to: URL(fileURLWithPath: speechFile), atomically: true, encoding: .utf8)
            try "".write(to: URL(fileURLWithPath: replyFile), atomically: true, encoding: .utf8)
            print("{\"success\":true,\"message\":\"gate files cleared\"}")
        } catch {
            print("{\"success\":false,\"error\":\"\(error.localizedDescription)\"}")
        }
    }

    // status: show current gate state
    static func status() {
        var speechText = ""
        var replyText = ""
        if FileManager.default.fileExists(atPath: speechFile),
           let data = try? Data(contentsOf: URL(fileURLWithPath: speechFile)) {
            speechText = String(data: data, encoding: .utf8) ?? ""
        }
        if FileManager.default.fileExists(atPath: replyFile),
           let data = try? Data(contentsOf: URL(fileURLWithPath: replyFile)) {
            replyText = String(data: data, encoding: .utf8) ?? ""
        }
        let info: [String: Any] = [
            "success": true,
            "speechPending": !speechText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "replyPending": !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "speechFile": speechFile,
            "replyFile": replyFile,
        ]
        if let data = try? JSONSerialization.data(withJSONObject: info, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    static func printUsage() {
        print("""
        renjistroly-gate <command> [args]

        Commands:
          watch       Watch speech_in.txt for new entries (prints each line)
          reply <text> Write a reply to reply_out.txt (app speaks it)
          clear       Clear both speech and reply files
          status      Show current gate state
          help        Show this help

        Gate files:
          Speech:  \(speechFile)   (App writes transcribed text here)
          Reply:   \(replyFile)   (Write replies here, App reads and speaks)
        """)
    }
}
