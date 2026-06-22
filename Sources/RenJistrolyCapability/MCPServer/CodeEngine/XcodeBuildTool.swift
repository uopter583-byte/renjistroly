import Foundation
import OSLog
import RenJistrolyModels

// MARK: - Xcode Build Tool

public struct XcodeBuildTool: MCPTool {
    public let definition = ToolDefinition(
        name: "xcodebuild",
        description: "通过 xcodebuild 构建 Xcode 项目或工作空间。支持 build/test/clean/archive",
        parameters: [
            .init(name: "project_path", type: .string, description: "项目路径（含 .xcodeproj 或 .xcworkspace 的目录）", required: false),
            .init(name: "scheme", type: .string, description: "Scheme 名称", required: false),
            .init(name: "destination", type: .string, description: "目标设备，如 'platform=macOS'", required: false),
            .init(name: "action", type: .string, description: "build(默认)/test/clean/archive", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let projectPath = arguments["project_path"] ?? FileManager.default.currentDirectoryPath
        let action = arguments["action"] ?? "build"
        let destination = arguments["destination"] ?? "platform=macOS"
        var args: [String]
        if action == "archive" {
            args = ["archive", "-archivePath", "\(projectPath)/build/Archive.xcarchive", "-destination", destination]
        } else {
            args = [action, "-destination", destination]
        }

        if let scheme = arguments["scheme"] {
            args.append(contentsOf: ["-scheme", scheme])
        }

        // Auto-detect project/workspace
        if let detected = detectProject(in: projectPath) {
            args.append(contentsOf: detected)
        }

        Task { await AgentEventBus.shared.publish(.code(.buildStarted(target: arguments["scheme"]))) }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        task.arguments = args
        task.currentDirectoryURL = URL(fileURLWithPath: projectPath)

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        let output = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { cont.resume(throwing: error) }
        }
        let isError = task.terminationStatus != 0
        // Extract errors
        var result = ""
        let lines = output.split(separator: "\n")
        for line in lines {
            let text = String(line)
            if text.contains("error:") || text.contains("** BUILD FAILED") || text.contains("** TEST FAILED") ||
               text.contains("** BUILD SUCCEEDED") || text.contains("** TEST SUCCEEDED") ||
               text.contains("warning:") {
                result += text + "\n"
            }
        }
        if result.isEmpty { result = output }
        if isError {
            Task { await AgentEventBus.shared.publish(.code(.buildFailed(stderr: result.prefix(200).description))) }
        } else {
            let errorCount = result.components(separatedBy: "error:").count - 1
            let warningCount = result.components(separatedBy: "warning:").count - 1
            Task { await AgentEventBus.shared.publish(.code(.buildCompleted(exitCode: task.terminationStatus, errorCount: errorCount, warningCount: warningCount))) }
        }
        return ToolCallResult(id: UUID().uuidString, output: result, isError: isError)
    }

    private func detectProject(in path: String) -> [String]? {
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(atPath: path) {
            if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
                return ["-workspace", workspace]
            }
            if let project = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
                return ["-project", project]
            }
        }
        return nil
    }
}
