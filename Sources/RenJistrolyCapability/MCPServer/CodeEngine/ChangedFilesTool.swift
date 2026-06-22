import Foundation
import RenJistrolyModels

public struct ChangedFilesTool: MCPTool {
    public let definition = ToolDefinition(
        name: "changed_files",
        description: "查看自某个分支/提交以来的变更文件列表，以及未跟踪、已修改未暂存、已暂存未提交的文件",
        parameters: [
            .init(name: "base", type: .string, description: "基准分支/提交，默认 main/master 自动检测", required: false),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let path = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        var lines: [String] = []

        // 1. Detect base ref
        let base: String
        if let explicitBase = arguments["base"] {
            base = explicitBase
        } else {
            base = await detectBaseRef(at: path)
        }
        let hasBase = !base.isEmpty

        if hasBase {
            // Committed changes: base..HEAD
            let (diffOut, _, diffStatus) = await runGit(["diff", "--name-only", "--diff-filter=ACMR", "\(base)..HEAD"], repoPath: path)
            let committedFiles = diffOut.split(separator: "\n").filter { !$0.isEmpty }
            if diffStatus == 0 {
                if committedFiles.isEmpty {
                    lines.append("## 已提交变更 (\(base)..HEAD):\n(无)")
                } else {
                    lines.append("## 已提交变更 (\(base)..HEAD):")
                    lines.append(contentsOf: committedFiles.map { "  \($0)" })
                }
            } else {
                lines.append("## 已提交变更: (无法获取，检查 base ref 是否正确)")
            }
        } else {
            lines.append("## 已提交变更: (未检测到 base 分支)")
        }

        // 2. Working tree state via git status --porcelain
        let (statusOut, _, _) = await runGit(["status", "--porcelain"], repoPath: path)
        let statusLines = statusOut.split(separator: "\n").filter { !$0.isEmpty }

        // Parse porcelain output:
        //   XY filename
        //   X=index state, Y=working tree state
        //   M  = staged modified, A  = staged added, ?? = untracked
        //    M = unstaged modified,  D = unstaged deleted, etc.
        var staged: [String] = []
        var unstaged: [String] = []
        var untracked: [String] = []

        for line in statusLines {
            let raw = String(line)
            guard raw.count >= 3 else { continue }
            let index = raw[raw.startIndex]
            let workTree = raw[raw.index(after: raw.startIndex)]
            let filePart = String(raw[raw.index(raw.startIndex, offsetBy: 3)...])

            if index == "?" && workTree == "?" {
                untracked.append(filePart)
            } else if index != " " {
                staged.append(raw)
            } else if workTree != " " {
                unstaged.append(raw)
            }
        }

        if !staged.isEmpty {
            lines.append("\n## 已暂存待提交:")
            lines.append(contentsOf: staged.map { "  \($0)" })
        }

        if !unstaged.isEmpty {
            lines.append("\n## 未暂存修改:")
            lines.append(contentsOf: unstaged.map { "  \($0)" })
        }

        if !untracked.isEmpty {
            lines.append("\n## 未跟踪文件:")
            lines.append(contentsOf: untracked.map { "  \($0)" })
        }

        if staged.isEmpty && unstaged.isEmpty && untracked.isEmpty {
            lines.append("\n## 工作区状态: 干净")
        }

        return ToolCallResult(id: UUID().uuidString, output: lines.joined(separator: "\n"))
    }

    private func detectBaseRef(at path: String) async -> String {
        let candidates = ["main", "master"]
        for ref in candidates {
            let (out, _, status) = await runGit(["rev-parse", "--verify", ref], repoPath: path)
            if status == 0 && !out.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return ref
            }
        }
        return ""
    }

    private func runGit(_ args: [String], repoPath: String) async -> (stdout: String, stderr: String, status: Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["-C", repoPath] + args
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        let result = try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, String, Int32), Error>) in
            task.terminationHandler = { proc in
                let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                cont.resume(returning: (out, err, proc.terminationStatus))
            }
            do { try task.run() } catch { cont.resume(throwing: error) }
        }
        return result ?? ("", "", -1)
    }
}
