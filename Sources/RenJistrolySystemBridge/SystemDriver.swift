import AppKit
import Foundation
import RenJistrolyModels

// MARK: - System Driver (clipboard, process, notifications)

public struct SystemDriver: AppDriver {
    public let id = "system"
    public let displayName = "System"
    public let capabilities: Set<AppDriverCapability> = [.read, .write, .runCommand]

    public init() {}

    // MARK: Clipboard

    public func readClipboard() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    public func writeClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: Process management

    public func runningProcesses(matching name: String) async -> [SysProcessInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-ax", "-o", "pid,comm"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        let output: String
        do {
            output = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                process.terminationHandler = { _ in
                    let data = stdout.fileHandleForReading.readDataToEndOfFile()
                    cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
                }
                do { try process.run() } catch { cont.resume(throwing: error) }
            }
        } catch { return [] }
        let lowerName = name.lowercased()
        return output.split(separator: "\n").dropFirst().compactMap { line in
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            guard parts.count >= 2,
                  let pid = Int32(parts[0]),
                  String(parts[1]).lowercased().contains(lowerName) else { return nil }
            return SysProcessInfo(pid: pid, name: String(parts[1]))
        }
    }

    public func killProcess(pid: Int32) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/kill")
        process.arguments = ["\(pid)"]
        let (_, status) = (try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, Int32), Error>) in
            process.terminationHandler = { proc in
                cont.resume(returning: ("", proc.terminationStatus))
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }) ?? ("", -1)
        return status == 0
    }

    // MARK: System info

    public func systemMemoryInfo() async -> (used: UInt64, total: UInt64)? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")
        let stdout = Pipe()
        process.standardOutput = stdout
        let output: String
        do {
            output = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                process.terminationHandler = { _ in
                    let data = stdout.fileHandleForReading.readDataToEndOfFile()
                    cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
                }
                do { try process.run() } catch { cont.resume(throwing: error) }
            }
        } catch { return nil }
        guard let pageSizeLine = output.split(separator: "\n").first(where: { $0.contains("page size") }),
              let pageSize = Int(pageSizeLine.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) else { return nil }
        let freeLine = output.split(separator: "\n").first(where: { $0.contains("free") }) ?? ""
        let freePages = Int(freeLine.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
        let total = UInt64(ProcessInfo.processInfo.physicalMemory)
        let used = total - UInt64(freePages * pageSize)
        return (used, total)
    }
}

public struct SysProcessInfo: Sendable, Hashable {
    public let pid: Int32
    public let name: String

    public init(pid: Int32, name: String) {
        self.pid = pid
        self.name = name
    }
}
