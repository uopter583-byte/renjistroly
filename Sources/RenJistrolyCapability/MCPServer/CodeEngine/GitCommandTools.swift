import Foundation
import RenJistrolyModels

// MARK: - Shared Git Helpers

private func gitCmd(_ arguments: [String], repoPath: String = FileManager.default.currentDirectoryPath) async -> (stdout: String, stderr: String, status: Int32) {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    var args = ["-C", repoPath]
    args.append(contentsOf: arguments)
    task.arguments = args
    let outPipe = Pipe()
    let errPipe = Pipe()
    task.standardOutput = outPipe
    task.standardError = errPipe
    return await withCheckedContinuation { (cont: CheckedContinuation<(stdout: String, stderr: String, status: Int32), Never>) in
        task.terminationHandler = { _ in
            let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            cont.resume(returning: (out, err, task.terminationStatus))
        }
        do { try task.run() } catch {
            cont.resume(returning: ("", "启动失败: \(error.localizedDescription)", -1))
        }
    }
}

// MARK: - Git Blame Tool

public struct GitBlameTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_blame",
        description: "查看文件中每一行的最后修改者和提交信息",
        parameters: [
            .init(name: "file_path", type: .string, description: "文件路径"),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
            .init(name: "start_line", type: .string, description: "起始行号", required: false),
            .init(name: "end_line", type: .string, description: "结束行号", required: false),
            .init(name: "since", type: .string, description: "起始时间，如 '1.week' 或 '2024-01-01'", required: false),
            .init(name: "author", type: .string, description: "按作者邮箱过滤", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let filePath = arguments["file_path"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: file_path", isError: true)
        }
        let repoPath = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath

        var range: String?
        if let start = arguments["start_line"], let end = arguments["end_line"] {
            range = "\(start),\(end)"
        } else if let start = arguments["start_line"] {
            range = "\(start),+10"
        }

        var args = ["-C", repoPath, "blame", "--show-name", "--date=short"]
        args.append(contentsOf: ["--show-email"])
        if let since = arguments["since"] { args.append("--since=\(since)") }
        if let range { args.append(contentsOf: ["-L", range]) }
        args.append("--")
        args.append(filePath)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        var output = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { cont.resume(throwing: error) }
        }
        if let author = arguments["author"] {
            output = output.split(separator: "\n")
                .filter { $0.localizedCaseInsensitiveContains(author) }
                .joined(separator: "\n")
        }
        // Format: hash (author date line) content
        let formatted = formatBlame(output)
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: "blame", result: formatted.prefix(100).description))) }
        return ToolCallResult(id: UUID().uuidString, output: formatted.isEmpty ? "无结果" : formatted)
    }

    func formatBlame(_ raw: String) -> String {
        let lines = raw.split(separator: "\n")
        var result: [String] = []
        for line in lines.prefix(200) {
            let text = String(line)
            // Extract commit hash (first 8 chars), author, date
            if let m = try? Regex(#"^\^?([0-9a-f]{7,})\s+\(([^)]+)\)"#).firstMatch(in: text) {
                let hash = String(m.output[1].substring ?? "").prefix(8)
                let meta = m.output[2].substring ?? ""
                let rest = text.dropFirst(1 + (m.output[0].substring?.count ?? 0))
                result.append("[\(hash)] \(meta) |\(rest)")
            } else {
                result.append(text)
            }
        }
        return result.joined(separator: "\n")
    }
}

// MARK: - Git Branch Tool

public struct GitBranchTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_branch",
        description: "Git 分支操作：list(列出分支)、current(当前分支)、create(创建)、switch(切换)、delete(删除)",
        parameters: [
            .init(name: "action", type: .string, description: "list/current/create/switch/delete"),
            .init(name: "name", type: .string, description: "分支名（create/switch/delete 时需要）", required: false),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"]?.lowercased() else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action (list/current/create/switch/delete)", isError: true)
        }
        let repoPath = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.currentDirectoryURL = URL(fileURLWithPath: repoPath)

        switch action {
        case "list":
            task.arguments = ["-C", repoPath, "branch", "-a", "--sort=-committerdate"]
        case "current":
            task.arguments = ["-C", repoPath, "branch", "--show-current"]
        case "create":
            guard let name = arguments["name"] else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: name (分支名)", isError: true)
            }
            task.arguments = ["-C", repoPath, "checkout", "-b", name]
        case "switch":
            guard let name = arguments["name"] else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: name (分支名)", isError: true)
            }
            task.arguments = ["-C", repoPath, "checkout", name]
        case "delete":
            guard let name = arguments["name"] else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: name (分支名)", isError: true)
            }
            task.arguments = ["-C", repoPath, "branch", "-d", name]
        default:
            return ToolCallResult(id: UUID().uuidString, output: "无效 action: \(action)", isError: true)
        }

        let pipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errPipe
        let (output, errOutput) = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, String), Error>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: (String(data: data, encoding: .utf8) ?? "", String(data: errData, encoding: .utf8) ?? ""))
            }
            do { try task.run() } catch { cont.resume(throwing: error) }
        }

        if task.terminationStatus != 0 {
            return ToolCallResult(id: UUID().uuidString, output: errOutput.isEmpty ? "执行失败" : errOutput, isError: true)
        }
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: "branch-\(action)", result: output))) }
        return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "完成" : output)
    }

}

// MARK: - Git Commit Tool

public struct GitCommitTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_commit",
        description: "创建 Git 提交。stage_all=true 时自动 git add -A，amend=true 时修正上次提交",
        parameters: [
            .init(name: "message", type: .string, description: "提交信息"),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
            .init(name: "stage_all", type: .string, description: "是否 stage 所有变更：true/false", required: false),
            .init(name: "amend", type: .string, description: "是否为修正提交：true/false", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let amend = (arguments["amend"] ?? "false").lowercased() == "true"
        let message = arguments["message"] ?? ""

        if !amend {
            guard !message.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: message", isError: true)
            }
        }
        let repoPath = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath

        if (arguments["stage_all"] ?? "false").lowercased() == "true" {
            let addTask = Process()
            addTask.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            addTask.arguments = ["-C", repoPath, "add", "-A"]
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                addTask.terminationHandler = { _ in cont.resume() }
                do { try addTask.run() } catch { cont.resume(throwing: error) }
            }
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        if amend {
            if message.isEmpty {
                task.arguments = ["-C", repoPath, "commit", "--amend", "--no-edit"]
            } else {
                task.arguments = ["-C", repoPath, "commit", "--amend", "-m", message]
            }
        } else {
            task.arguments = ["-C", repoPath, "commit", "-m", message]
        }
        let pipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errPipe
        let (output, errOutput) = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, String), Error>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: (String(data: data, encoding: .utf8) ?? "", String(data: errData, encoding: .utf8) ?? ""))
            }
            do { try task.run() } catch { cont.resume(throwing: error) }
        }

        if task.terminationStatus != 0 {
            return ToolCallResult(id: UUID().uuidString, output: errOutput.isEmpty ? "提交失败" : errOutput, isError: true)
        }
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: amend ? "commit-amend" : "commit", result: output))) }
        return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "提交成功" : output)
    }
}

// MARK: - Git Stash Tool

public struct GitStashTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_stash",
        description: "Git 暂存操作：save(暂存)/pop(弹出)/apply(应用)/list(列表)/drop(删除)",
        parameters: [
            .init(name: "action", type: .string, description: "save/pop/apply/list/drop"),
            .init(name: "message", type: .string, description: "暂存说明（仅 save 时有效）", required: false),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"]?.lowercased() else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action", isError: true)
        }
        let repo = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let (out, err, status) = await gitCmd(["stash", action] + (arguments["message"].map { ["-m", $0] } ?? []), repoPath: repo)
        if status != 0 {
            let msg = err.isEmpty ? "操作失败" : err
            return ToolCallResult(id: UUID().uuidString, output: msg, isError: true)
        }
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: "stash-\(action)", result: out))) }
        return ToolCallResult(id: UUID().uuidString, output: out.isEmpty ? "已执行 stash \(action)" : out)
    }
}

// MARK: - Git Push/Pull/Fetch Tool

public struct GitPushPullTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_push_pull",
        description: "Git 远程同步：push(推送)/pull(拉取)/fetch(获取)",
        parameters: [
            .init(name: "action", type: .string, description: "push/pull/fetch"),
            .init(name: "remote", type: .string, description: "远程仓库名，默认 origin", required: false),
            .init(name: "branch", type: .string, description: "分支名，默认当前分支", required: false),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"]?.lowercased() else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action", isError: true)
        }
        let repo = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let remote = arguments["remote"] ?? "origin"
        var args = [action, remote]
        if let branch = arguments["branch"] { args.append(branch) }
        if action == "push" { args.append("--set-upstream") }

        let (out, err, status) = await gitCmd(args, repoPath: repo)
        if status != 0 {
            return ToolCallResult(id: UUID().uuidString, output: err.isEmpty ? "操作失败" : err, isError: true)
        }
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: action, result: out))) }
        return ToolCallResult(id: UUID().uuidString, output: out.isEmpty ? "已执行 git \(action)" : out)
    }
}

// MARK: - Git Remote Tool

public struct GitRemoteTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_remote",
        description: "管理 Git 远程仓库：list(列出)/add(添加)/remove(删除)/show(查看URL)",
        parameters: [
            .init(name: "action", type: .string, description: "list/add/remove/show"),
            .init(name: "name", type: .string, description: "远程名（add/remove/show 时需要）", required: false),
            .init(name: "url", type: .string, description: "远程URL（add 时需要）", required: false),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"]?.lowercased() else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action", isError: true)
        }
        let repo = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        var args = ["remote"]
        switch action {
        case "list", "show":
            args.append("-v")
            if let name = arguments["name"] { args.append(name) }
        case "add":
            guard let name = arguments["name"], let url = arguments["url"] else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: name, url", isError: true)
            }
            args.append(contentsOf: ["add", name, url])
        case "remove":
            guard let name = arguments["name"] else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: name", isError: true)
            }
            args.append(contentsOf: ["remove", name])
        default:
            return ToolCallResult(id: UUID().uuidString, output: "无效 action: \(action)", isError: true)
        }
        let (out, err, status) = await gitCmd(args, repoPath: repo)
        if status != 0 {
            return ToolCallResult(id: UUID().uuidString, output: err.isEmpty ? "操作失败" : err, isError: true)
        }
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: "remote-\(action)", result: out))) }
        return ToolCallResult(id: UUID().uuidString, output: out)
    }
}

// MARK: - Git Reset Tool

public struct GitResetTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_reset",
        description: "重置当前分支到指定提交。默认 --soft，可选 --mixed 或 --hard",
        parameters: [
            .init(name: "commit", type: .string, description: "目标提交 ref，默认 HEAD~1", required: false),
            .init(name: "mode", type: .string, description: "soft/mixed/hard，默认 soft", required: false),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let commit = arguments["commit"] ?? "HEAD~1"
        let mode = arguments["mode"] ?? "soft"
        guard ["soft", "mixed", "hard"].contains(mode) else {
            return ToolCallResult(id: UUID().uuidString, output: "无效 mode: \(mode)，应为 soft/mixed/hard", isError: true)
        }
        let repo = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let (out, err, status) = await gitCmd(["reset", "--\(mode)", commit], repoPath: repo)
        if status != 0 {
            return ToolCallResult(id: UUID().uuidString, output: err.isEmpty ? "reset 失败" : err, isError: true)
        }
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: "reset-\(mode)", result: out))) }
        return ToolCallResult(id: UUID().uuidString, output: out.isEmpty ? "已重置到 \(commit) (--\(mode))" : out)
    }
}

// MARK: - Git Merge/Rebase Tool

public struct GitMergeRebaseTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_merge_rebase",
        description: "Git 合并与变基：merge/rebase/abort(中止)",
        parameters: [
            .init(name: "action", type: .string, description: "merge/rebase/abort"),
            .init(name: "branch", type: .string, description: "目标分支名（merge/rebase 时需要）", required: false),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"]?.lowercased() else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action", isError: true)
        }
        let repo = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let args: [String]
        switch action {
        case "merge":
            guard let branch = arguments["branch"] else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: branch", isError: true)
            }
            args = ["merge", branch]
        case "rebase":
            guard let branch = arguments["branch"] else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: branch", isError: true)
            }
            args = ["rebase", branch]
        case "abort":
            args = ["merge", "--abort"]
        default:
            return ToolCallResult(id: UUID().uuidString, output: "无效 action: \(action)", isError: true)
        }
        let (out, err, status) = await gitCmd(args, repoPath: repo)
        if status != 0 {
            return ToolCallResult(id: UUID().uuidString, output: err.isEmpty ? "操作失败" : err, isError: true)
        }
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: action, result: out))) }
        return ToolCallResult(id: UUID().uuidString, output: out.isEmpty ? "已执行 \(action)" : out)
    }
}

// MARK: - Git Tag Tool

public struct GitTagTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_tag",
        description: "管理 Git 标签：list(列出)/create(创建)/delete(删除)",
        parameters: [
            .init(name: "action", type: .string, description: "list/create/delete"),
            .init(name: "name", type: .string, description: "标签名（create/delete 时需要）", required: false),
            .init(name: "message", type: .string, description: "标签说明（create 时可选）", required: false),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"]?.lowercased() else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action", isError: true)
        }
        let repo = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let args: [String]
        switch action {
        case "list":
            args = ["tag", "--sort=-creatordate"]
        case "create":
            guard let name = arguments["name"] else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: name", isError: true)
            }
            if let msg = arguments["message"] { args = ["tag", "-a", name, "-m", msg] }
            else { args = ["tag", name] }
        case "delete":
            guard let name = arguments["name"] else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: name", isError: true)
            }
            args = ["tag", "-d", name]
        default:
            return ToolCallResult(id: UUID().uuidString, output: "无效 action: \(action)", isError: true)
        }
        let (out, err, status) = await gitCmd(args, repoPath: repo)
        if status != 0 {
            return ToolCallResult(id: UUID().uuidString, output: err.isEmpty ? "操作失败" : err, isError: true)
        }
        let truncated = String(out.split(separator: "\n").prefix(50).joined(separator: "\n"))
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: "tag-\(action)", result: out))) }
        return ToolCallResult(id: UUID().uuidString, output: truncated.isEmpty ? "已执行 tag \(action)" : truncated)
    }
}

// MARK: - Git Show Tool

public struct GitShowTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_show",
        description: "查看提交详情、diff 内容或文件内容。默认 HEAD，可指定 commit 或 ref",
        parameters: [
            .init(name: "ref", type: .string, description: "提交 hash、分支名或 ref（默认 HEAD）", required: false),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let ref = arguments["ref"] ?? "HEAD"
        let repo = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let (out, err, _) = await gitCmd(["show", "--stat", "--max-count=1", ref], repoPath: repo)
        if !err.isEmpty, out.isEmpty {
            return ToolCallResult(id: UUID().uuidString, output: err, isError: true)
        }
        return ToolCallResult(id: UUID().uuidString, output: out.isEmpty ? "(空提交)" : out)
    }
}

// MARK: - Git Cherry-Pick Tool

public struct GitCherryPickTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_cherry_pick",
        description: "挑选指定提交应用到当前分支：pick(挑选)/abort(中止)",
        parameters: [
            .init(name: "action", type: .string, description: "pick/abort"),
            .init(name: "commit", type: .string, description: "提交 hash（pick 时需要）", required: false),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let action = arguments["action"]?.lowercased() else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: action", isError: true)
        }
        let repo = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let args: [String]
        switch action {
        case "pick":
            guard let commit = arguments["commit"] else {
                return ToolCallResult(id: UUID().uuidString, output: "缺少参数: commit", isError: true)
            }
            args = ["cherry-pick", commit]
        case "abort":
            args = ["cherry-pick", "--abort"]
        default:
            return ToolCallResult(id: UUID().uuidString, output: "无效 action: \(action)", isError: true)
        }
        let (out, err, status) = await gitCmd(args, repoPath: repo)
        if status != 0 {
            return ToolCallResult(id: UUID().uuidString, output: err.isEmpty ? "操作失败" : err, isError: true)
        }
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: "cherry-pick-\(action)", result: out))) }
        return ToolCallResult(id: UUID().uuidString, output: out.isEmpty ? "已执行 cherry-pick \(action)" : out)
    }
}

// MARK: - Git Revert Tool

public struct GitRevertTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_revert",
        description: "撤销指定提交，生成新提交。支持 revert 和 abort",
        parameters: [
            .init(name: "commit", type: .string, description: "要撤销的提交 hash"),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let commit = arguments["commit"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: commit", isError: true)
        }
        let repo = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let (out, err, status) = await gitCmd(["revert", "--no-edit", commit], repoPath: repo)
        if status != 0 {
            return ToolCallResult(id: UUID().uuidString, output: err.isEmpty ? "revert 失败" : err, isError: true)
        }
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: "revert", result: out))) }
        return ToolCallResult(id: UUID().uuidString, output: out.isEmpty ? "已撤销 \(commit)" : out)
    }
}

// MARK: - Git Clean Tool

public struct GitCleanTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_clean",
        description: "清理未跟踪的文件。默认 dry-run（预览），force=true 时真正执行",
        parameters: [
            .init(name: "force", type: .string, description: "true/false。false 时仅预览，默认 false", required: false),
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let repo = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let force = (arguments["force"] ?? "false").lowercased() == "true"
        let (out, err, status) = await gitCmd(force ? ["clean", "-fd"] : ["clean", "-n", "-d"], repoPath: repo)
        if status != 0 {
            return ToolCallResult(id: UUID().uuidString, output: err.isEmpty ? "操作失败" : err, isError: true)
        }
        let label = force ? "已清理" : "将清理（dry-run）：\n"
        Task { await AgentEventBus.shared.publish(.code(.gitOperation(op: force ? "clean" : "clean-dryrun", result: out))) }
        return ToolCallResult(id: UUID().uuidString, output: out.isEmpty ? "\(label)(无文件)" : label + out)
    }
}
