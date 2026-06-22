import Foundation

/// Bridges to the codebase-memory-mcp statically-linked binary.
/// Launches as a subprocess and communicates via stdin/stdout JSON-RPC.
public actor CodebaseMemoryBridge {
    private let binaryPath: String
    private var process: Process?
    private var stdinPipe: Pipe?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var pendingRequests: [Int: CheckedContinuation<Data, Error>] = [:]

    public init(binaryPath: String = "codebase-memory-mcp") {
        self.binaryPath = binaryPath
    }

    public var isAvailable: Bool {
        get async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["which", binaryPath]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            do {
                let status = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Int32, Error>) in
                    task.terminationHandler = { cont.resume(returning: $0.terminationStatus) }
                    do { try task.run() } catch { cont.resume(throwing: error) }
                }
                return status == 0
            } catch {
                return false
            }
        }
    }

    // MARK: - Process lifecycle

    public func start() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["--stdio"]

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        self.process = process
        self.stdinPipe = stdinPipe
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe

        Task { await readLoop(stdoutPipe) }
    }

    public func stop() {
        process?.terminate()
        process = nil
        stdinPipe = nil
        stdoutPipe = nil
        stderrPipe = nil
    }

    // MARK: - API methods

    public func searchCode(query: String, repoPath: String? = nil, language: String? = nil, maxResults: Int = 20) async throws -> [CodebaseSearchResult] {
        let params: [String: Any] = [
            "query": query,
            "repo_path": repoPath ?? FileManager.default.currentDirectoryPath,
            "language": language ?? "",
            "max_results": maxResults,
        ]
        let response = try await sendRequest(method: "search_code", params: params)
        return try decodeResults(response)
    }

    public func getSymbolInfo(symbol: String, repoPath: String? = nil) async throws -> CodebaseSymbolInfo? {
        let params: [String: Any] = [
            "symbol": symbol,
            "repo_path": repoPath ?? FileManager.default.currentDirectoryPath,
        ]
        let response = try await sendRequest(method: "get_symbol", params: params)
        return try? decodeSingle(response)
    }

    public func listDefinitions(filePath: String, line: Int? = nil) async throws -> [CodebaseDefinition] {
        var params: [String: Any] = ["file_path": filePath]
        if let line { params["line"] = line }
        let response = try await sendRequest(method: "list_definitions", params: params)
        return try decodeResults(response)
    }

    public func listReferences(symbol: String, repoPath: String? = nil) async throws -> [CodebaseReference] {
        let params: [String: Any] = [
            "symbol": symbol,
            "repo_path": repoPath ?? FileManager.default.currentDirectoryPath,
        ]
        let response = try await sendRequest(method: "list_references", params: params)
        return try decodeResults(response)
    }

    // MARK: - JSON-RPC

    private var requestID: Int = 0

    private func sendRequest(method: String, params: [String: Any]) async throws -> Data {
        requestID += 1
        let reqID = requestID
        let request: [String: Any] = [
            "jsonrpc": "2.0",
            "id": reqID,
            "method": method,
            "params": params,
        ]
        let json = try JSONSerialization.data(withJSONObject: request)
        guard let stdinPipe else { throw CodebaseMemoryError.notStarted }

        guard let newlineData = "\n".data(using: .utf8) else {
            throw CodebaseMemoryError.encodingFailed
        }
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[reqID] = continuation
            stdinPipe.fileHandleForWriting.write(json)
            stdinPipe.fileHandleForWriting.write(newlineData)
        }
    }

    private func readLoop(_ pipe: Pipe) async {
        let handle = pipe.fileHandleForReading
        var buffer = Data()
        while process?.isRunning == true {
            let data = handle.availableData
            guard !data.isEmpty else { break }
            buffer.append(data)
            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let line = buffer[..<newlineIndex]
                buffer.removeSubrange(...newlineIndex)
                // Parse the response ID from JSON to dispatch to the correct caller
                if let responseID = extractResponseID(from: line),
                   let continuation = pendingRequests.removeValue(forKey: responseID) {
                    continuation.resume(returning: line)
                }
            }
        }
        // Process terminated; fail any remaining pending requests
        for continuation in pendingRequests.values {
            continuation.resume(throwing: CodebaseMemoryError.notStarted)
        }
        pendingRequests.removeAll()
    }

    /// Extract the `id` field from a JSON-RPC response line.
    private func extractResponseID(from data: Data) -> Int? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseID = json["id"] as? Int else {
            return nil
        }
        return responseID
    }

    private func decodeResults<T: Decodable>(_ data: Data) throws -> [T] {
        let decoder = JSONDecoder()
        let response = try decoder.decode(JSONRPCResponse.self, from: data)
        if let error = response.error {
            throw CodebaseMemoryError.rpcError(error.message)
        }
        guard let result = response.result else { return [] }
        let resultData = try JSONSerialization.data(withJSONObject: result)
        return try decoder.decode([T].self, from: resultData)
    }

    private func decodeSingle<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        let response = try decoder.decode(JSONRPCResponse.self, from: data)
        if let error = response.error {
            throw CodebaseMemoryError.rpcError(error.message)
        }
        guard let result = response.result else {
            throw CodebaseMemoryError.decodingFailed("empty result")
        }
        let resultData = try JSONSerialization.data(withJSONObject: result)
        return try decoder.decode(T.self, from: resultData)
    }

    private struct JSONRPCResponse: Decodable {
        let jsonrpc: String
        let id: Int?
        let result: Any?
        let error: JSONRPCError?

        struct JSONRPCError: Decodable {
            let code: Int
            let message: String
        }

        enum CodingKeys: String, CodingKey {
            case jsonrpc, id, result, error
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            jsonrpc = try c.decode(String.self, forKey: .jsonrpc)
            id = try c.decodeIfPresent(Int.self, forKey: .id)
            error = try c.decodeIfPresent(JSONRPCError.self, forKey: .error)
            if let raw = try? c.decodeIfPresent(AnyCodable.self, forKey: .result) {
                result = raw.value
            } else {
                result = nil
            }
        }
    }
}

// MARK: - Types

public struct CodebaseSearchResult: Codable, Sendable {
    public let filePath: String?
    public let line: Int?
    public let content: String?
    public let symbol: String?
    public let language: String?
    public let score: Double?

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case line, content, symbol, language, score
    }
}

public struct CodebaseSymbolInfo: Codable, Sendable {
    public let name: String?
    public let kind: String?
    public let filePath: String?
    public let line: Int?
    public let signature: String?
    public let docComment: String?

    enum CodingKeys: String, CodingKey {
        case name, kind
        case filePath = "file_path"
        case line, signature
        case docComment = "doc_comment"
    }
}

public struct CodebaseDefinition: Codable, Sendable {
    public let name: String?
    public let kind: String?
    public let filePath: String?
    public let line: Int?

    enum CodingKeys: String, CodingKey {
        case name, kind
        case filePath = "file_path"
        case line
    }
}

public struct CodebaseReference: Codable, Sendable {
    public let filePath: String?
    public let line: Int?
    public let content: String?

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case line, content
    }
}

public enum CodebaseMemoryError: Error, LocalizedError {
    case notStarted
    case rpcError(String)
    case decodingFailed(String)
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .notStarted: "Codebase Memory MCP 未启动"
        case .rpcError(let msg): "RPC 错误: \(msg)"
        case .decodingFailed(let detail): "解析失败: \(detail)"
        case .encodingFailed: "编码失败"
        }
    }
}

// MARK: - Helper

private struct AnyCodable: Codable {
    let value: Any
    init(_ value: Any) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let n = try? c.decode(Double.self) { value = n }
        else if let b = try? c.decode(Bool.self) { value = b }
        else if let a = try? c.decode([AnyCodable].self) { value = a.map(\.value) }
        else if let d = try? c.decode([String: AnyCodable].self) { value = d.mapValues(\.value) }
        else { value = [:] }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        if let s = value as? String { try c.encode(s) }
        else if let n = value as? Double { try c.encode(n) }
        else if let b = value as? Bool { try c.encode(b) }
        else if let a = value as? [Any] { try c.encode(a.map(AnyCodable.init)) }
        else if let d = value as? [String: Any] { try c.encode(d.mapValues(AnyCodable.init)) }
    }
}
