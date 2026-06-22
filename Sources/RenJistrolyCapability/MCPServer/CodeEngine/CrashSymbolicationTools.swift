import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

// =====================================================================
// 场景 382: Crash 日志符号化
// =====================================================================
// 使用 atos 将 crash log 中的地址符号化

public struct CrashSymbolicateTool: MCPTool {
    public let definition = ToolDefinition(
        name: "crash_symbolicate",
        description: "符号化 macOS/iOS crash log：解析崩溃地址、使用 dSYM 或可执行文件符号化。支持 atos 和系统崩溃报告格式",
        parameters: [
            .init(name: "crash_log", type: .string, description: "crash log 内容或路径（若以 / 开头则作为文件路径读取）"),
            .init(name: "dsym_path", type: .string, description: "dSYM 文件路径（可选，自动搜索 .app 同目录下的 dSYM）", required: false),
            .init(name: "binary_path", type: .string, description: "可执行文件路径（可选，用于符号化）", required: false),
            .init(name: "load_address", type: .string, description: "加载地址（可选，如未提供则从 crash log 自动提取）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let crashLog = arguments["crash_log"], !crashLog.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: crash_log", isError: true)
        }

        // 如果以 / 开头，作为文件路径读取
        let content: String
        if crashLog.hasPrefix("/"), FileManager.default.fileExists(atPath: crashLog) {
            content = (try? String(contentsOfFile: crashLog, encoding: .utf8)) ?? crashLog
        } else {
            content = crashLog
        }

        var output = "=== Crash 符号化分析 ===\n\n"

        // 1. 解析 crash log 结构
        let parsed = parseCrashLog(content)
        output += "【基本信息】\n"
        output += "  进程: \(parsed.processName) (\(parsed.bundleID))\n"
        output += "  版本: \(parsed.version)\n"
        output += "  平台: \(parsed.platform)\n"
        output += "  时间: \(parsed.crashTime)\n\n"

        if !parsed.exceptionType.isEmpty {
            output += "  异常类型: \(parsed.exceptionType) (\(parsed.exceptionCode))\n"
        }
        if !parsed.signalInfo.isEmpty {
            output += "  信号: \(parsed.signalInfo)\n"
        }
        if !parsed.terminatingReason.isEmpty {
            output += "  终止原因: \(parsed.terminatingReason)\n\n"
        }

        // 2. 符号化调用栈
        if !parsed.stackFrames.isEmpty {
            output += "【调用栈】\(parsed.stackFrames.count) 帧\n\n"

            for frame in parsed.stackFrames.prefix(50) {
                let symbol = frame.symbol.isEmpty ? "?" : frame.symbol
                output += "  \(frame.index)  \(frame.binary)  0x\(frame.address)  \(symbol)\n"
            }
            if parsed.stackFrames.count > 50 {
                output += "  ... 还有 \(parsed.stackFrames.count - 50) 帧\n"
            }
            output += "\n"
        }

        // 3. 尝试 atos 符号化（如果有 binary 路径和未符号化的地址）
        if let binaryPath = arguments["binary_path"] {
            let loadAddr = arguments["load_address"]
            let unsymbolized = parsed.stackFrames.filter { $0.symbol.contains("0x") || $0.symbol == "?" }

            if !unsymbolized.isEmpty {
                output += "【atos 符号化结果】\n\n"

                // 对每个未符号化的帧运行 atos
                for frame in unsymbolized.prefix(20) {
                    var atosArgs = ["-o", binaryPath, "-l", loadAddr ?? "0x0", frame.address]
                    if let dsymPath = arguments["dsym_path"] {
                        atosArgs = ["-o", binaryPath, "-d", dsymPath, "-l", loadAddr ?? "0x0", frame.address]
                    }
                    let symbolicated = await runProcess("/usr/bin/atos", args: atosArgs)
                    if !symbolicated.trimmingCharacters(in: .whitespaces).isEmpty {
                        let sym = symbolicated.trimmingCharacters(in: .whitespacesAndNewlines)
                        output += "  \(frame.index)  \(sym)\n"
                    }
                }
                output += "\n"
            }
        }

        // 4. 分析可能的崩溃原因
        if !parsed.exceptionType.isEmpty || !parsed.terminatingReason.isEmpty {
            output += "【崩溃分析】\n"
            output += analyzeCrash(parsed: parsed) + "\n"
        }

        return ToolCallResult(id: UUID().uuidString, output: output)
    }

    private func parseCrashLog(_ content: String) -> ParsedCrashLog {
        var processName = "?"
        var bundleID = "?"
        var version = "?"
        var platform = "?"
        var crashTime = "?"
        var exceptionType = ""
        var exceptionCode = ""
        var signalInfo = ""
        var terminatingReason = ""
        var stackFrames: [CrashFrame] = []
        var inStack = false

        for line in content.split(separator: "\n") {
            let text = String(line)

            if text.contains("Process:") {
                if let m = try? Regex(#"Process:\s+(.+?)\s*\["#).firstMatch(in: text) {
                    processName = String(m.output[1].substring ?? "?")
                }
            }
            if text.contains("Bundle id") || text.contains("Identifier:") {
                if let m = try? Regex(#"(?:Bundle id|Identifier):\s*(\S+)"#).firstMatch(in: text) {
                    bundleID = String(m.output[1].substring ?? "?")
                }
            }
            if text.contains("Version:") {
                if let m = try? Regex(#"Version:\s*(\S+)"#).firstMatch(in: text) {
                    version = String(m.output[1].substring ?? "?")
                }
            }
            if text.contains("Code Type:") {
                if let m = try? Regex(#"Code Type:\s*(.+)$"#).firstMatch(in: text) {
                    platform = String(m.output[1].substring ?? "?").trimmingCharacters(in: .whitespaces)
                }
            }
            if text.contains("Date/Time:") {
                if let m = try? Regex(#"Date/Time:\s*(.+)$"#).firstMatch(in: text) {
                    crashTime = String(m.output[1].substring ?? "?").trimmingCharacters(in: .whitespaces)
                }
            }
            if text.contains("Exception Type:") {
                let parts = text.split(separator: ":", maxSplits: 1)
                if parts.count >= 2 {
                    let val = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    if let m = try? Regex(#"^(\S+)\s*\((.+)\)"#).firstMatch(in: val) {
                        exceptionType = String(m.output[1].substring ?? "")
                        exceptionCode = String(m.output[2].substring ?? "")
                    } else {
                        exceptionType = val
                    }
                }
            }
            if text.contains("Signal:") {
                if let m = try? Regex(#"Signal:\s*(.+)$"#).firstMatch(in: text) {
                    signalInfo = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                }
            }
            if text.contains("Terminating Reason:") {
                if let m = try? Regex(#"Terminating Reason:\s*(.+)$"#).firstMatch(in: text) {
                    terminatingReason = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                }
            }

            // 栈帧解析 - 支持多种格式
            if inStack {
                // 标准 crash 格式: 0   binary   0x12345678  0x1234 + 123
                if text.trimmingCharacters(in: .whitespaces).isEmpty {
                    inStack = false
                    continue
                }
                if let m = try? Regex(#"^\s*(\d+)\s+(\S+)\s+(0x[0-9a-fA-F]+)\s+(.+)"#).firstMatch(in: text) {
                    stackFrames.append(CrashFrame(
                        index: String(m.output[1].substring ?? ""),
                        binary: String(m.output[2].substring ?? ""),
                        address: String(m.output[3].substring ?? ""),
                        symbol: String(m.output[4].substring ?? "").trimmingCharacters(in: .whitespaces)
                    ))
                }
            } else if text.contains("Stack") || text.contains("Backtrace") {
                inStack = true
            }
        }

        return ParsedCrashLog(
            processName: processName,
            bundleID: bundleID,
            version: version,
            platform: platform,
            crashTime: crashTime,
            exceptionType: exceptionType,
            exceptionCode: exceptionCode,
            signalInfo: signalInfo,
            terminatingReason: terminatingReason,
            stackFrames: stackFrames
        )
    }

    private func analyzeCrash(parsed: ParsedCrashLog) -> String {
        let exc = parsed.exceptionType.lowercased()
        let reason = parsed.terminatingReason.lowercased()
        let topFrame = parsed.stackFrames.first?.symbol ?? ""

        var analysis: [String] = []

        if exc.contains("exc_bad_access") || exc.contains("sigsegv") || exc.contains("sigbus") {
            analysis.append("🔴 内存访问错误: 访问了无效内存地址。常见原因：")
            analysis.append("  - 访问已释放的对象（use-after-free）")
            analysis.append("  - 空指针解引用")
            analysis.append("  - 缓冲区溢出")
            analysis.append("  - 在 dealloc 后继续使用对象")
            if !topFrame.isEmpty {
                analysis.append("  顶部帧: \(topFrame)")
            }
        } else if exc.contains("exc_breakpoint") || exc.contains("sigtrap") {
            analysis.append("🔴 断点/陷阱: 触发了断点或 fatalError。常见原因：")
            analysis.append("  - 调用了 fatalError() 或 preconditionFailure()")
            analysis.append("  - 运行时断言失败")
            analysis.append("  - 可选项强制解包遇到 nil")
            if reason.contains("fatal error") {
                analysis.append("  - Swift 运行时错误: \(parsed.terminatingReason)")
            }
        } else if exc.contains("exc_crash") || exc.contains("sigabrt") {
            analysis.append("🔴 崩溃/终止: 进程主动终止。常见原因：")
            analysis.append("  - 未捕获的异常")
            analysis.append("  - 调用 abort() 或 assertion 失败")
            analysis.append("  - 发送了无法处理的消息")
        } else if exc.contains("exc_arithmetic") || exc.contains("sigfpe") {
            analysis.append("🔴 算术错误: 除零或浮点异常")
        } else if exc.contains("exc_software") {
            analysis.append("🔴 软件异常")
        } else {
            analysis.append("🟡 未知异常类型: \(parsed.exceptionType)")
        }

        if !parsed.signalInfo.isEmpty {
            analysis.append("\n信号: \(parsed.signalInfo)")
        }
        if !parsed.terminatingReason.isEmpty {
            analysis.append("\n终止原因: \(parsed.terminatingReason)")
        }

        return analysis.joined(separator: "\n")
    }

    private func runProcess(_ exec: String, args: [String]) async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: exec)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        return await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { continuation.resume(returning: "") }
        }
    }

    private struct CrashFrame {
        let index: String
        let binary: String
        let address: String
        let symbol: String
    }

    private struct ParsedCrashLog {
        let processName: String
        let bundleID: String
        let version: String
        let platform: String
        let crashTime: String
        let exceptionType: String
        let exceptionCode: String
        let signalInfo: String
        let terminatingReason: String
        let stackFrames: [CrashFrame]
    }
}
