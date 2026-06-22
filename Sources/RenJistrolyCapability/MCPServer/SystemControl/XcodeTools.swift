import Foundation
import AppKit
import OSLog
import RenJistrolyModels
import RenJistrolySystemBridge

// MARK: - Open In Xcode Tool

public struct OpenInXcodeTool: MCPTool {
    public let definition = ToolDefinition(
        name: "open_in_xcode",
        description: "在 Xcode 中打开文件，可指定行号跳转。若无 Xcode 则用系统默认编辑器",
        parameters: [
            .init(name: "file_path", type: .string, description: "文件路径"),
            .init(name: "line", type: .string, description: "跳转到指定行号", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let filePath = arguments["file_path"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: file_path", isError: true)
        }
        let expanded = (filePath as NSString).expandingTildeInPath
        var absPath: String
        if (expanded as NSString).isAbsolutePath {
            absPath = expanded
        } else {
            absPath = FileManager.default.currentDirectoryPath + "/" + expanded
        }

        guard FileManager.default.fileExists(atPath: absPath) else {
            return ToolCallResult(id: UUID().uuidString, output: "文件不存在: \(absPath)", isError: true)
        }

        let fileURL = URL(fileURLWithPath: absPath)
        let line = arguments["line"].flatMap(Int.init)

        let hasXcode = await MainActor.run {
            NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "/Applications/Xcode.app")) != nil
        }
        if hasXcode {
            // Try xed first (Xcode CLI tool)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/xed")
            if let line {
                task.arguments = ["--line", "\(line)", absPath]
            } else {
                task.arguments = [absPath]
            }
            task.standardError = FileHandle.nullDevice
            task.standardOutput = FileHandle.nullDevice
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    task.terminationHandler = { _ in continuation.resume() }
                    do { try task.run() } catch { continuation.resume(throwing: error) }
                }
                if task.terminationStatus == 0 {
                    let lineInfo = line.map { " 第\($0)行" } ?? ""
                    Task { await AgentEventBus.shared.publish(.code(.fileOpened(path: absPath))) }
                    return ToolCallResult(id: UUID().uuidString, output: "已用 Xcode 打开: \(absPath)\(lineInfo)")
                }
            } catch {
                Logger.tools.error("[OpenInXcode] xed 失败: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Fallback: use NSWorkspace to open with default editor（无法传递行号）
        _ = await MainActor.run { NSWorkspace.shared.open(fileURL) }
        Task { await AgentEventBus.shared.publish(.code(.fileOpened(path: absPath))) }
        return ToolCallResult(id: UUID().uuidString, output: "已打开: \(absPath)")
    }
}

// MARK: - Reveal In Finder Tool

public struct RevealInFinderTool: MCPTool {
    public let definition = ToolDefinition(
        name: "reveal_in_finder",
        description: "在 Finder 中定位文件或目录",
        parameters: [
            .init(name: "path", type: .string, description: "文件或目录路径"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let path = arguments["path"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: path", isError: true)
        }
        let expanded = (path as NSString).expandingTildeInPath
        var absPath: String
        if (expanded as NSString).isAbsolutePath {
            absPath = expanded
        } else {
            absPath = FileManager.default.currentDirectoryPath + "/" + expanded
        }

        guard FileManager.default.fileExists(atPath: absPath) else {
            return ToolCallResult(id: UUID().uuidString, output: "路径不存在: \(absPath)", isError: true)
        }

        await MainActor.run { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: absPath)]) }
        await AgentEventBus.shared.publish(.desktop(.folderOpened(path: absPath)))
        return ToolCallResult(id: UUID().uuidString, output: "已在 Finder 中定位: \(absPath)")
    }
}

// MARK: - List Schemes Tool

public struct ListSchemesTool: MCPTool {
    public let definition = ToolDefinition(
        name: "list_schemes",
        description: "列出 Xcode 项目或 workspace 中可用的 schemes",
        parameters: [
            .init(name: "project_path", type: .string, description: "项目目录路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let projectPath = arguments["project_path"] ?? FileManager.default.currentDirectoryPath
        let fm = FileManager.default
        let contents = (try? fm.contentsOfDirectory(atPath: projectPath)) ?? []
        let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") })
        let project = contents.first(where: { $0.hasSuffix(".xcodeproj") })

        var out = ""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        if let ws = workspace {
            process.arguments = ["-workspace", ws, "-list"]
            out += "Workspace: \(ws)\n"
        } else if let proj = project {
            process.arguments = ["-project", proj, "-list"]
            out += "Project: \(proj)\n"
        } else {
            return ToolCallResult(id: UUID().uuidString, output: "未找到 .xcworkspace 或 .xcodeproj")
        }

        let raw = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            process.terminationHandler = { _ in
                let d = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: d, encoding: .utf8) ?? "")
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }

        var inSchemes = false
        let lines = raw.split(separator: "\n")
        for line in lines {
            let text = String(line).trimmingCharacters(in: .whitespaces)
            if text == "Schemes:" { inSchemes = true; continue }
            if inSchemes, !text.isEmpty {
                out += "  - \(text)\n"
            }
        }

        return ToolCallResult(id: UUID().uuidString, output: out.isEmpty ? raw : out)
    }
}

// MARK: - Build Settings Tool

public struct BuildSettingsTool: MCPTool {
    public let definition = ToolDefinition(
        name: "build_settings",
        description: "查看 Xcode 项目的 build settings",
        parameters: [
            .init(name: "project_path", type: .string, description: "项目目录路径", required: false),
            .init(name: "scheme", type: .string, description: "scheme 名称", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let projectPath = arguments["project_path"] ?? FileManager.default.currentDirectoryPath

        var args = ["-showBuildSettings"]
        if let scheme = arguments["scheme"] { args.append(contentsOf: ["-scheme", scheme]) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe
        let (output, errOutput) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(String, String), Error>) in
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: (String(data: data, encoding: .utf8) ?? "", String(data: errData, encoding: .utf8) ?? ""))
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }

        if process.terminationStatus != 0 {
            return ToolCallResult(id: UUID().uuidString, output: errOutput.isEmpty ? "获取失败" : errOutput, isError: true)
        }
        // Filter to key settings
        let interesting = ["SDKROOT", "SWIFT_VERSION", "PRODUCT_NAME", "BUNDLE_IDENTIFIER",
                           "DEPLOYMENT_TARGET", "SWIFT_OPTIMIZATION_LEVEL", "CODE_SIGN_IDENTITY",
                           "PROVISIONING_PROFILE", "ARCHS", "MACOSX_DEPLOYMENT_TARGET"]
        let lines = output.split(separator: "\n")
        let filtered = lines.filter { line in
            interesting.contains { line.hasPrefix("    \($0)") }
        }
        let result = filtered.map(String.init).joined(separator: "\n")
        return ToolCallResult(id: UUID().uuidString, output: result.isEmpty ? output : result)
    }
}
