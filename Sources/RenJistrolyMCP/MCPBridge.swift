import Foundation
import AppKit
import RenJistrolyCapability
import RenJistrolySystemBridge
import RenJistrolyModels

// MARK: - MCP Server Entry Point

@main @MainActor
struct RenJistrolyMCPServer {
    static nonisolated let serverInfo: [String: String] = [
        "name": "RenJistroly",
        "version": "0.1.0",
    ]

    // File gate paths for voice tools (shared with main app)
    static nonisolated let gateDir = "/tmp/renjistroly"
    static nonisolated var speechFile: String { "\(gateDir)/speech_in.txt" }
    static nonisolated var replyFile: String { "\(gateDir)/reply_out.txt" }

    static func main() async {
        _ = NSApplication.shared
        signal(SIGPIPE, SIG_IGN)

        let client = MCPClient()
        await client.registerBuiltinTools()
        log("RenJistrolyMCP: \(await client.availableTools.count) tools registered")

        // Bridge synchronous stdin reads into an async stream
        let frameStream = AsyncStream<Data> { continuation in
            DispatchQueue.global().async {
                var buf = Data()
                var readBuf = [UInt8](repeating: 0, count: 65536)
                while true {
                    let n = Darwin.read(STDIN_FILENO, &readBuf, readBuf.count)
                    if n <= 0 {
                        if n == 0 { log("stdin closed, exiting") }
                        break
                    }
                    buf.append(contentsOf: readBuf[0..<n])
                    while let nl = buf.firstIndex(of: 10) {
                        let frame = Data(buf.prefix(upTo: nl))
                        buf.removeSubrange(...nl)
                        continuation.yield(frame)
                    }
                }
                continuation.finish()
            }
        }

        for await frame in frameStream {
            await handle(frame: frame, client: client)
        }
    }

    // MARK: - Message Dispatch

    static func handle(frame jsonData: Data, client: MCPClient) async {
        guard let msg = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let method = msg["method"] as? String
        else {
            return
        }

        let id = msg["id"]
        let params = (msg["params"] as? [String: Any]) ?? [:]

        switch method {
        case "initialize":
            respond(id: id, result: [
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": [:]],
                "serverInfo": serverInfo,
            ])

        case "notifications/initialized":
            break

        case "tools/list":
            let tools = await client.availableTools
            let mcpTools = (tools + voiceToolDefinitions).map(Self.toolDefinitionToMCP)
            respond(id: id, result: ["tools": mcpTools])

        case "tools/call":
            guard let toolName = params["name"] as? String, let jsonId = id else {
                respondError(id: id, code: -32602, message: "Missing tool name or id")
                return
            }
            let toolArgs = (params["arguments"] as? [String: Any]) ?? [:]
            let result = await executeTool(name: toolName, args: toolArgs, client: client)
            respond(id: jsonId, result: result)

        case "ping":
            if let jsonId = id { respond(id: jsonId, result: [:]) }

        default:
            respondError(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    // MARK: - Tool Execution

    static func executeTool(name: String, args: [String: Any], client: MCPClient) async -> [String: Any] {
        // Voice tools handled locally (file-based gate to main app)
        switch name {
        case "voice_listen":
            let timeoutMs = args["timeout_ms"] as? Int ?? 500
            return [
                "content": [["type": "text", "text": voiceListen(timeoutMs: timeoutMs)]],
            ]
        case "voice_speak":
            guard let text = args["text"] as? String, !text.isEmpty else {
                return [
                    "content": [["type": "text", "text": json(["success": false, "error": "missing text"])]],
                    "isError": true,
                ]
            }
            return [
                "content": [["type": "text", "text": voiceSpeak(text)]],
            ]
        default:
            break
        }

        // All other tools → MCPToolRegistry
        let stringArgs = args.compactMapValues { "\($0)" }
        let request = ToolCallRequest(
            id: UUID().uuidString,
            name: name,
            arguments: stringArgs
        )

        do {
            let result = try await client.execute(request, policy: .permissive)
            return [
                "content": [
                    ["type": "text", "text": result.output]
                ],
                "isError": result.isError,
            ]
        } catch {
            return [
                "content": [
                    ["type": "text", "text": "Tool execution failed: \(error.localizedDescription)"]
                ],
                "isError": true,
            ]
        }
    }

    // MARK: - Tool Definition → MCP format

    static nonisolated let voiceToolDefinitions: [ToolDefinition] = [
        ToolDefinition(
            name: "voice_listen",
            description: "Listen for the latest RenJistroly voice transcript through the shared voice gate.",
            parameters: [
                .init(name: "prompt", type: .string, description: "Optional prompt shown to the voice listener.", required: false),
                .init(name: "timeout_ms", type: .number, description: "Maximum time to wait for speech in milliseconds.", required: false),
            ]
        ),
        ToolDefinition(
            name: "voice_speak",
            description: "Send text to the RenJistroly voice reply gate for speech output.",
            parameters: [
                .init(name: "text", type: .string, description: "Text to speak."),
            ]
        ),
    ]

    static func toolDefinitionToMCP(_ def: ToolDefinition) -> [String: Any] {
        var properties: [String: Any] = [:]
        var required: [String] = []

        for param in def.parameters {
            let jsonType: String = switch param.type {
            case .string: "string"
            case .number: "number"
            case .boolean: "boolean"
            case .object: "object"
            case .array: "array"
            }

            properties[param.name] = [
                "type": jsonType,
                "description": param.description,
            ]

            if param.required {
                required.append(param.name)
            }
        }

        return [
            "name": def.name,
            "description": def.description,
            "inputSchema": [
                "type": "object",
                "properties": properties,
            ].merging(required.isEmpty ? [:] : ["required": required]) { _, new in new }
        ]
    }

    // MARK: - Voice Tools (file-based gate, communicates with main RenJistroly app)

    static func voiceListen(timeoutMs: Int) -> String {
        if let text = readLatestSpeech() {
            return json(["success": true, "text": text])
        }
        let start = Date()
        while Date().timeIntervalSince(start) < Double(timeoutMs) / 1000.0 {
            usleep(100_000)
            if let text = readLatestSpeech() {
                return json(["success": true, "text": text])
            }
        }
        return json(["success": true, "text": ""])
    }

    static func voiceSpeak(_ text: String) -> String {
        try? FileManager.default.createDirectory(atPath: gateDir, withIntermediateDirectories: true)
        do {
            try text.write(to: URL(fileURLWithPath: replyFile), atomically: true, encoding: .utf8)
            return json(["success": true, "message": "reply written"])
        } catch {
            return json(["success": false, "error": error.localizedDescription])
        }
    }

    static func readLatestSpeech() -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: speechFile)),
              let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty
        else { return nil }
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard let lastLine = lines.last,
              let lineData = lastLine.data(using: .utf8),
              let entry = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
              let speechText = entry["text"] as? String
        else { return nil }
        return speechText
    }

    // MARK: - JSON-RPC Helpers

    static func respond(id: Any?, result: Any) {
        respondPayload(["jsonrpc": "2.0", "id": id ?? NSNull(), "result": result])
    }

    static func respondError(id: Any?, code: Int, message: String) {
        let error: [String: Any] = ["code": code, "message": message]
        respondPayload(["jsonrpc": "2.0", "id": id ?? NSNull(), "error": error])
    }

    static func respondPayload(_ dict: [String: Any]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict) else { return }
        var frame = jsonData
        frame.append(10) // newline delimiter
        _ = frame.withUnsafeBytes { Darwin.write(STDOUT_FILENO, $0.baseAddress, frame.count) }
        fflush(stdout)
    }

    static func json(_ dict: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8)
        else { return "{}" }
        return str
    }

    // MARK: - Logging (stderr, captured by Claude Code host)

    static nonisolated func log(_ message: String) {
        let line = "[RenJistrolyMCP] \(message)\n"
        if let data = line.data(using: .utf8) {
            _ = data.withUnsafeBytes { Darwin.write(STDERR_FILENO, $0.baseAddress, data.count) }
        }
    }
}
