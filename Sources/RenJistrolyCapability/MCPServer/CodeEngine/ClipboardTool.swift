import Foundation
import RenJistrolyModels

// MARK: - Clipboard Tool

public struct ClipboardTool: MCPTool {
    public let definition = ToolDefinition(
        name: "clipboard",
        description: "读写系统剪贴板。action: read 读取内容，write 写入内容",
        parameters: [
            .init(name: "action", type: .string, description: "read 或 write"),
            .init(name: "content", type: .string, description: "写入内容（action=write 时需要）", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"]?.lowercased() else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action (read/write)", isError: true)
        }

        switch action {
        case "read":
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pbpaste")
            let pipe = Pipe()
            task.standardOutput = pipe
            let content = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                task.terminationHandler = { _ in
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
                }
                do { try task.run() } catch { continuation.resume(throwing: error) }
            }
            if !content.isEmpty { Task { await AgentEventBus.shared.publish(.desktop(.textCopied(text: String(content.prefix(200))))) } }
            return ToolCallResult(id: UUID().uuidString, output: content.isEmpty ? "剪贴板为空" : content)

        case "write":
            guard let content = arguments["content"] else {
                return ToolCallResult(id: UUID().uuidString, output: "action=write 需要 content 参数", isError: true)
            }
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pbcopy")
            let inputPipe = Pipe()
            task.standardInput = inputPipe
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                task.terminationHandler = { _ in continuation.resume() }
                do {
                    try task.run()
                    if let data = content.data(using: .utf8) {
                        inputPipe.fileHandleForWriting.write(data)
                    }
                    inputPipe.fileHandleForWriting.closeFile()
                } catch { continuation.resume(throwing: error) }
            }
            return ToolCallResult(id: UUID().uuidString, output: "已写入剪贴板 (\(content.count) 字符)")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "无效 action: \(action)，请用 read 或 write", isError: true)
        }
    }
}
