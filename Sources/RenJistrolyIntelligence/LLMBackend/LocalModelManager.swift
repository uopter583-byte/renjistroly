import Foundation

public struct LocalModelInfo: Sendable, Hashable {
    public let name: String
    public let path: String
    public let format: ModelFormat
    public let sizeBytes: UInt64?

    public enum ModelFormat: String, Sendable, Hashable {
        case mlx
        case gguf
        case safetensors
        case unknown
    }
}

public actor LocalModelManager {
    private var _models: [LocalModelInfo]?
    private var _mlxCLIAvailable: Bool?

    public init() {}

    // MARK: - Model discovery

    public var models: [LocalModelInfo] {
        get async {
            if let cached = _models { return cached }
            let discovered = await discoverModels()
            _models = discovered
            return discovered
        }
    }

    public var isMLXCLIAvailable: Bool {
        get async {
            if let cached = _mlxCLIAvailable { return cached }
            let available = await checkMLXCLI()
            _mlxCLIAvailable = available
            return available
        }
    }

    public var canRunInference: Bool {
        get async {
            let cli = await isMLXCLIAvailable
            let ml = await models
            return cli && !ml.isEmpty
        }
    }

    public func refresh() async {
        _models = nil
        _mlxCLIAvailable = nil
    }

    // MARK: - Inference

    public func generate(
        model: LocalModelInfo,
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "mlx_lm.generate",
            "--model", model.path,
            "--prompt", prompt,
            "--max-tokens", "\(maxTokens)",
            "--temp", "\(temperature)",
        ]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let (stdout, stderr) = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, String), Error>) in
            process.terminationHandler = { _ in
                let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                cont.resume(returning: (stdout, stderr))
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }

        guard process.terminationStatus == 0 else {
            throw LocalModelError.inferenceFailed(stderr)
        }
        return stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    private static let searchPaths: [String] = [
        ("~/.cache/huggingface/hub" as NSString).expandingTildeInPath,
        ("~/.cache/mlx_models" as NSString).expandingTildeInPath,
        ("~/.mlx" as NSString).expandingTildeInPath,
        ("~/mlx_models" as NSString).expandingTildeInPath,
        ("~/.local/share/mlx" as NSString).expandingTildeInPath,
    ]

    private func discoverModels() async -> [LocalModelInfo] {
        var found: [LocalModelInfo] = []
        let fm = FileManager.default

        for searchPath in Self.searchPaths {
            guard fm.fileExists(atPath: searchPath) else { continue }
            guard let contents = try? fm.contentsOfDirectory(atPath: searchPath) else { continue }

            for item in contents {
                let fullPath = (searchPath as NSString).appendingPathComponent(item)
                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      attrs[.type] as? FileAttributeType != .typeDirectory else {
                    // Recurse one level for huggingface cache structure (models__author__name)
                    guard let subContents = try? fm.contentsOfDirectory(atPath: fullPath) else { continue }
                    for subItem in subContents {
                        let subPath = (fullPath as NSString).appendingPathComponent(subItem)
                        if let info = modelInfo(path: subPath, name: "\(item)/\(subItem)", fm: fm) {
                            found.append(info)
                        }
                    }
                    continue
                }
                if let info = modelInfo(path: fullPath, name: item, fm: fm) {
                    found.append(info)
                }
            }
        }
        return found
    }

    private func modelInfo(path: String, name: String, fm: FileManager) -> LocalModelInfo? {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return nil }

        guard let contents = try? fm.contentsOfDirectory(atPath: path) else { return nil }
        let files = Set(contents)

        let format: LocalModelInfo.ModelFormat
        if files.contains(where: { $0.hasSuffix(".safetensors") || $0.hasSuffix(".safetensors.index.json") }) {
            format = .safetensors
        } else if files.contains(where: { $0.hasSuffix(".gguf") }) {
            format = .gguf
        } else if files.contains(where: { $0.hasSuffix(".npz") }) || files.contains("config.json") {
            format = .mlx
        } else {
            return nil
        }

        let sizeBytes: UInt64? = contents.reduce(0) { sum, file in
            let fp = (path as NSString).appendingPathComponent(file)
            let attrs = try? fm.attributesOfItem(atPath: fp)
            return sum + (attrs?[.size] as? UInt64 ?? 0)
        }

        return LocalModelInfo(name: name, path: path, format: format, sizeBytes: sizeBytes)
    }

    private func checkMLXCLI() async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["mlx_lm.generate", "--help"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        return (try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<Int32, Error>) in
            process.terminationHandler = { cont.resume(returning: $0.terminationStatus) }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }) == 0
    }
}

public enum LocalModelError: Error, LocalizedError, Sendable {
    case noModelsFound
    case inferenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noModelsFound: "未找到本地 MLX 模型。"
        case .inferenceFailed(let detail): "MLX 推理失败: \(detail)"
        }
    }
}
