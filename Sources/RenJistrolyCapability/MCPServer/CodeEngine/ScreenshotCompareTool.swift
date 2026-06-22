import Foundation
import RenJistrolyModels

// MARK: - Screenshot Compare Tool

public struct ScreenshotCompareTool: MCPTool {
    public let definition = ToolDefinition(
        name: "screenshot_compare",
        description: "对比两张截图，返回文件大小、尺寸差异和字节级差异百分比",
        parameters: [
            .init(name: "before_path", type: .string, description: "操作前截图路径"),
            .init(name: "after_path", type: .string, description: "操作后截图路径"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let beforePath = arguments["before_path"],
              let afterPath = arguments["after_path"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少 before_path 或 after_path", isError: true)
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: beforePath) else {
            return ToolCallResult(id: UUID().uuidString, output: "before 截图不存在: \(beforePath)", isError: true)
        }
        guard fm.fileExists(atPath: afterPath) else {
            return ToolCallResult(id: UUID().uuidString, output: "after 截图不存在: \(afterPath)", isError: true)
        }

        var lines: [String] = []

        // File size comparison
        let beforeSize = (try? fm.attributesOfItem(atPath: beforePath)[.size] as? Int) ?? 0
        let afterSize = (try? fm.attributesOfItem(atPath: afterPath)[.size] as? Int) ?? 0
        let sizeDiff = afterSize - beforeSize
        lines.append("文件大小: before=\(ByteCountFormatter.string(fromByteCount: Int64(beforeSize), countStyle: .file)) after=\(ByteCountFormatter.string(fromByteCount: Int64(afterSize), countStyle: .file)) (差 \(ByteCountFormatter.string(fromByteCount: Int64(abs(sizeDiff)), countStyle: .file)))")

        // Image dimensions via sips
        let beforeDims = await imageDimensions(at: beforePath)
        let afterDims = await imageDimensions(at: afterPath)
        if let bd = beforeDims { lines.append("before 尺寸: \(bd)") }
        if let ad = afterDims { lines.append("after 尺寸: \(ad)") }

        // Byte-level comparison for same-size files
        if beforeSize == afterSize,
           let beforeData = try? Data(contentsOf: URL(fileURLWithPath: beforePath)),
           let afterData = try? Data(contentsOf: URL(fileURLWithPath: afterPath)) {
            var diffBytes = 0
            let count = min(beforeData.count, afterData.count)
            for i in 0..<count {
                if beforeData[i] != afterData[i] { diffBytes += 1 }
            }
            let diffPercent = Double(diffBytes) / Double(max(count, 1)) * 100
            if diffBytes == 0 {
                lines.append("结果: 完全一致")
            } else {
                lines.append("结果: \(String(format: "%.2f", diffPercent))% 字节不同 (\(diffBytes)/\(count))")
            }
        } else if beforeSize != afterSize {
            lines.append("结果: 文件大小不同，截图有变化")
        }

        // Check for identical files using cmp
        let cmpTask = Process()
        cmpTask.executableURL = URL(fileURLWithPath: "/usr/bin/cmp")
        cmpTask.arguments = ["-s", beforePath, afterPath]
        let cmpStatus = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, Error>) in
            cmpTask.terminationHandler = { _ in continuation.resume(returning: cmpTask.terminationStatus) }
            do { try cmpTask.run() } catch { continuation.resume(throwing: error) }
        }
        if cmpStatus == 0 {
            lines.append("cmp: 文件完全一致")
        } else {
            lines.append("cmp: 文件有差异")
        }

        return ToolCallResult(id: UUID().uuidString, output: lines.joined(separator: "\n"))
    }

    private func imageDimensions(at path: String) async -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        task.arguments = ["-g", "pixelWidth", "-g", "pixelHeight", path]
        let pipe = Pipe()
        task.standardOutput = pipe
        return try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            task.terminationHandler = { _ in
                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let width = output.split(separator: "\n")
                    .first(where: { $0.contains("pixelWidth") })?
                    .replacingOccurrences(of: "pixelWidth: ", with: "")
                    .trimmingCharacters(in: .whitespaces) ?? "?"
                let height = output.split(separator: "\n")
                    .first(where: { $0.contains("pixelHeight") })?
                    .replacingOccurrences(of: "pixelHeight: ", with: "")
                    .trimmingCharacters(in: .whitespaces) ?? "?"
                continuation.resume(returning: "\(width)x\(height)")
            }
            do { try task.run() } catch { continuation.resume(throwing: error) }
        }
    }
}
