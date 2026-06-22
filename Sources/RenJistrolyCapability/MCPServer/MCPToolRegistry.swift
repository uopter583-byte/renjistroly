import Foundation
import RenJistrolyModels

public protocol MCPTool: Sendable {
    var definition: ToolDefinition { get }
    var riskLevel: ToolRiskLevel { get }
    func execute(arguments: [String: String]) async throws -> ToolCallResult
}

public actor MCPToolRegistry {
    private var tools: [String: any MCPTool] = [:]
    private var hooks: [String: any ToolHook] = [:]

    public init() {}

    // MARK: - Tool Registration

    public func register(_ tool: any MCPTool) {
        tools[tool.definition.name] = tool
    }

    public func registerAll(_ toolList: [any MCPTool]) {
        for tool in toolList {
            register(tool)
        }
    }

    public func getTool(_ name: String) -> (any MCPTool)? {
        tools[name]
    }

    public var allDefinitions: [ToolDefinition] {
        tools.values.map(\.definition)
    }

    public var toolCount: Int { tools.count }

    // MARK: - Hook Registration

    public func registerHook(_ hook: any ToolHook) {
        hooks[hook.name] = hook
    }

    public func registerHooks(_ hookList: [any ToolHook]) {
        for hook in hookList {
            hooks[hook.name] = hook
        }
    }

    public func unregisterHook(name: String) {
        hooks.removeValue(forKey: name)
    }

    public var allHooks: [any ToolHook] {
        hooks.values.sorted { $0.priority < $1.priority }
    }

    // MARK: - Execution

    public func executeTool(_ request: ToolCallRequest) async throws -> ToolCallResult {
        guard let tool = tools[request.name] else {
            return ToolCallResult(
                id: request.id,
                output: "未知工具: \(request.name)",
                isError: true
            )
        }

        // Fire pre-execution hooks
        await fireBeforeAll(tool: request.name, arguments: request.arguments)

        do {
            let result = try await tool.execute(arguments: request.arguments)
            // Fire post-execution hooks
            await fireAfterAll(tool: request.name, arguments: request.arguments, result: result)
            logInvocation(tool: request.name, args: request.arguments, isError: result.isError)
            return result
        } catch {
            let errorResult = ToolCallResult(
                id: request.id,
                output: "工具执行失败: \(error.localizedDescription)",
                isError: true
            )
            await fireAfterAll(tool: request.name, arguments: request.arguments, result: errorResult)
            logInvocation(tool: request.name, args: request.arguments, isError: true)
            return errorResult
        }
    }

    // MARK: - Hooks

    private func fireBeforeAll(tool: String, arguments: [String: String]) async {
        let sorted = hooks.values.sorted { $0.priority < $1.priority }
        for hook in sorted {
            await hook.onBeforeExecute(tool: tool, arguments: arguments)
        }
    }

    private func fireAfterAll(tool: String, arguments: [String: String], result: ToolCallResult) async {
        let sorted = hooks.values.sorted { $0.priority < $1.priority }
        for hook in sorted {
            await hook.onAfterExecute(tool: tool, arguments: arguments, result: result)
        }
    }

    // MARK: - Logging

    private nonisolated func logInvocation(tool: String, args: [String: String], isError: Bool) {
        let logDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/RenJistroly")
        let logFile = logDir.appendingPathComponent("tool_invocations.log")

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let highRiskTools: Set<String> = ["type_text", "press_key", "set_value", "shell_command", "write_file"]
        let displayArgs: String
        if highRiskTools.contains(tool) {
            displayArgs = args.map { "\($0)=[REDACTED \($1.count) chars]" }.joined(separator: ", ")
        } else {
            displayArgs = args.keys.joined(separator: ", ")
        }
        let status = isError ? "FAIL" : "OK"
        let line = "[\(timestamp)] \(status) \(tool) | \(displayArgs)\n"

        guard let data = line.data(using: .utf8) else { return }
        do {
            try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: logFile.path) {
                let handle = try FileHandle(forWritingTo: logFile)
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                handle.write(data)
            } else {
                try data.write(to: logFile, options: .atomic)
            }
        } catch {
            // Silent
        }
    }
}
