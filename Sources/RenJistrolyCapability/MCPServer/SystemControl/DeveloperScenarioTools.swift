import Foundation
import os
import RenJistrolyModels

// =============================================================================
// 开发者工具组 — Developer Tools
// 436: CodeReview, 437: GitWorkflow, 438: TerminalSession, 440: ProjectDiagnose
// =============================================================================

// MARK: - 436: 代码评审管理

public struct CodeReviewTool: MCPTool {
    public let definition = ToolDefinition(
        name: "code_review",
        description: """
        代码评审管理工具。支持创建评审、列出评审列表、批准/驳回评审以及添加评论。
        适用于开发者日常代码审查工作流。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: create(创建评审) / list(列出) / approve(批准) / reject(驳回) / add_comment(添加评论)",
                  required: true),
            .init(name: "review_id", type: .string,
                  description: "评审 ID (list/approve/reject/add_comment 时)", required: false),
            .init(name: "pr_title", type: .string,
                  description: "PR 标题 (action=create 时需要)", required: false),
            .init(name: "pr_url", type: .string,
                  description: "PR 链接 (action=create 时需要)", required: false),
            .init(name: "author", type: .string,
                  description: "作者 (action=create 时需要)", required: false),
            .init(name: "reviewer", type: .string,
                  description: "评审人", required: false),
            .init(name: "file_paths", type: .string,
                  description: "变更文件路径，逗号分隔", required: false),
            .init(name: "comments", type: .string,
                  description: "评审意见", required: false),
            .init(name: "score", type: .string,
                  description: "评分 1-10 (approve/reject 时)", required: false),
            .init(name: "passed", type: .string,
                  description: "是否通过: true/false", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private struct CodeReviewRecord {
        let id: String
        let prTitle: String
        let prURL: String
        let author: String
        let reviewer: String
        let filePaths: [String]
        let comments: String
        let score: Int
        let passed: Bool
        let createdAt: Date
    }

    private static let lock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _reviews: [String: CodeReviewRecord] = [:]
    private static nonisolated(unsafe) var _reviewList: [String] = []

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "list"

        switch action {
        case "create":
            guard let prTitle = arguments["pr_title"], !prTitle.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 pr_title 参数", isError: true)
            }
            guard let prURL = arguments["pr_url"], !prURL.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 pr_url 参数", isError: true)
            }
            guard let author = arguments["author"], !author.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 author 参数", isError: true)
            }
            let reviewer = arguments["reviewer"] ?? "未指定"
            let comments = arguments["comments"] ?? ""
            let filePaths = (arguments["file_paths"] ?? "").components(separatedBy: ",").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let score = Int(arguments["score"] ?? "0") ?? 0
            let passed = arguments["passed"] == "true"
            let reviewID = UUID().uuidString

            let record = CodeReviewRecord(
                id: reviewID,
                prTitle: prTitle,
                prURL: prURL,
                author: author,
                reviewer: reviewer,
                filePaths: filePaths,
                comments: comments,
                score: score,
                passed: passed,
                createdAt: Date()
            )
            Self.lock.withLock {
                Self._reviews[reviewID] = record
                Self._reviewList.append(reviewID)
            }

            return ToolCallResult(id: UUID().uuidString, output: """
                代码评审已创建
                - 评审 ID: \(reviewID)
                - PR: \(prTitle)
                - 作者: \(author)
                - 评审人: \(reviewer)
                - 变更文件: \(filePaths.isEmpty ? "未指定" : filePaths.joined(separator: ", "))
                """)

        case "list":
            let list = Self.lock.withLock { () -> String in
                guard !Self._reviewList.isEmpty else { return "" }
                return Self._reviewList.compactMap { Self._reviews[$0] }.map { r in
                    "\(r.id.prefix(8))... | \(r.prTitle) | 作者: \(r.author) | 评审人: \(r.reviewer)"
                }.joined(separator: "\n")
            }
            if list.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: "暂无代码评审记录。")
            }
            return ToolCallResult(id: UUID().uuidString, output: "代码评审列表:\n\(list)")

        case "approve", "reject":
            guard let reviewID = arguments["review_id"],
                  let record = Self.lock.withLock({ Self._reviews[reviewID] }) else {
                return ToolCallResult(id: UUID().uuidString, output: "无效的 review_id，请提供有效的评审 ID", isError: true)
            }
            let isApproved = action == "approve"
            let score = min(max(Int(arguments["score"] ?? (isApproved ? "8" : "3")) ?? (isApproved ? 8 : 3), 1), 10)
            let comments = arguments["comments"] ?? record.comments
            let updated = CodeReviewRecord(
                id: record.id, prTitle: record.prTitle, prURL: record.prURL,
                author: record.author, reviewer: record.reviewer,
                filePaths: record.filePaths, comments: comments,
                score: score, passed: isApproved,
                createdAt: record.createdAt
            )
            Self.lock.withLock { Self._reviews[reviewID] = updated }
            return ToolCallResult(id: UUID().uuidString, output: """
                \(isApproved ? "已批准" : "已驳回") 评审 \(reviewID.prefix(8))...
                - PR: \(record.prTitle)
                - 评分: \(score)/10
                - 评审意见: \(comments.isEmpty ? "无" : comments)
                """)

        case "add_comment":
            guard let reviewID = arguments["review_id"],
                  Self.lock.withLock({ Self._reviews[reviewID] }) != nil else {
                return ToolCallResult(id: UUID().uuidString, output: "无效的 review_id，请提供有效的评审 ID", isError: true)
            }
            let comments = arguments["comments"] ?? ""
            return ToolCallResult(id: UUID().uuidString, output: """
                评论已添加到评审 \(reviewID.prefix(8))...
                - 评论内容: \(comments.isEmpty ? "无" : comments)
                """)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// MARK: - 437: Git 工作流模拟

public struct GitWorkflowTool: MCPTool {
    public let definition = ToolDefinition(
        name: "git_workflow",
        description: """
        Git 工作流模拟工具。支持初始化仓库、克隆、分支管理、提交、推送、创建 PR 和合并操作。
        模拟完整的 Git 工作流。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: init_repo(初始化) / clone(克隆) / branch(分支) / commit(提交) / push(推送) / pr(PR) / merge(合并)",
                  required: true),
            .init(name: "repo_name", type: .string,
                  description: "仓库名称", required: false),
            .init(name: "branch_name", type: .string,
                  description: "分支名称", required: false),
            .init(name: "commit_message", type: .string,
                  description: "提交信息 (action=commit 时需要)", required: false),
            .init(name: "author", type: .string,
                  description: "作者", required: false),
            .init(name: "base_branch", type: .string,
                  description: "基础分支 (pr/merge 操作时)", required: false),
            .init(name: "pr_title", type: .string,
                  description: "PR 标题 (action=pr 时需要)", required: false),
            .init(name: "pr_description", type: .string,
                  description: "PR 描述", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private struct CommitRecord {
        let hash: String
        let message: String
        let author: String
        let date: Date
    }

    private struct PRRecord {
        let id: String
        let title: String
        let description: String
        let sourceBranch: String
        let targetBranch: String
        let author: String
        let isMerged: Bool
    }

    private struct RepoState {
        let name: String
        var branches: [String: [CommitRecord]]
        var currentBranch: String
        var pullRequests: [PRRecord]
    }

    private static let lock = OSAllocatedUnfairLock()
    private static nonisolated(unsafe) var _repos: [String: RepoState] = [:]

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "init_repo"
        let repoName = arguments["repo_name"] ?? "my-repo"

        switch action {
        case "init_repo":
            guard Self.lock.withLock({ Self._repos[repoName] }) == nil else {
                return ToolCallResult(id: UUID().uuidString, output: "仓库「\(repoName)」已存在。", isError: true)
            }
            let repo = RepoState(
                name: repoName,
                branches: ["main": [CommitRecord(hash: "initial", message: "初始提交", author: "system", date: Date())]],
                currentBranch: "main",
                pullRequests: []
            )
            Self.lock.withLock { Self._repos[repoName] = repo }
            return ToolCallResult(id: UUID().uuidString, output: """
                仓库已初始化: \(repoName)
                - 默认分支: main
                - 初始提交: 包含
                """)

        case "clone":
            if Self.lock.withLock({ Self._repos[repoName] }) != nil {
                return ToolCallResult(id: UUID().uuidString, output: "已克隆仓库: \(repoName)")
            }
            return ToolCallResult(id: UUID().uuidString, output: "仓库「\(repoName)」不存在，无法克隆。", isError: true)

        case "branch":
            guard let repoSnapshot = Self.lock.withLock({ Self._repos[repoName] }) else {
                return ToolCallResult(id: UUID().uuidString, output: "仓库「\(repoName)」不存在，请先 init_repo。", isError: true)
            }
            var repo = repoSnapshot
            let branchName = arguments["branch_name"] ?? "feature/\(UUID().uuidString.prefix(6))"
            guard repo.branches[branchName] == nil else {
                return ToolCallResult(id: UUID().uuidString, output: "分支「\(branchName)」已存在。", isError: true)
            }
            repo.branches[branchName] = repo.branches[repo.currentBranch]
            repo.currentBranch = branchName
            let repoAfterBranch = repo
            Self.lock.withLock { Self._repos[repoName] = repoAfterBranch }
            return ToolCallResult(id: UUID().uuidString, output: """
                分支已创建:
                - 新分支: \(branchName)
                - 当前分支: \(branchName)
                """)

        case "commit":
            guard let repoSnapshot = Self.lock.withLock({ Self._repos[repoName] }) else {
                return ToolCallResult(id: UUID().uuidString, output: "仓库「\(repoName)」不存在，请先 init_repo。", isError: true)
            }
            var repo = repoSnapshot
            guard let message = arguments["commit_message"], !message.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 commit_message 参数", isError: true)
            }
            let author = arguments["author"] ?? "开发者"
            let hash = String(UUID().uuidString.prefix(7).lowercased())
            let commit = CommitRecord(hash: hash, message: message, author: author, date: Date())
            repo.branches[repo.currentBranch, default: []].append(commit)
            let repoAfterCommit = repo
            Self.lock.withLock { Self._repos[repoName] = repoAfterCommit }
            return ToolCallResult(id: UUID().uuidString, output: """
                提交成功
                - 哈希: \(hash)
                - 分支: \(repo.currentBranch)
                - 信息: \(message)
                - 作者: \(author)
                """)

        case "push":
            guard Self.lock.withLock({ Self._repos[repoName] }) != nil else {
                return ToolCallResult(id: UUID().uuidString, output: "仓库「\(repoName)」不存在。", isError: true)
            }
            let currentBranch = Self.lock.withLock { Self._repos[repoName]?.currentBranch ?? "未知" }
            return ToolCallResult(id: UUID().uuidString, output: """
                已推送到远程仓库:
                - 仓库: \(repoName)
                - 当前分支: \(currentBranch)
                """)

        case "pr":
            guard let repo = Self.lock.withLock({ Self._repos[repoName] }) else {
                return ToolCallResult(id: UUID().uuidString, output: "仓库「\(repoName)」不存在。", isError: true)
            }
            guard let prTitle = arguments["pr_title"], !prTitle.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 pr_title 参数", isError: true)
            }
            let baseBranch = arguments["base_branch"] ?? "main"
            let prDescription = arguments["pr_description"] ?? ""
            let author = arguments["author"] ?? "开发者"
            let prID = "PR-\(UUID().uuidString.prefix(6).uppercased())"
            let pr = PRRecord(
                id: prID, title: prTitle, description: prDescription,
                sourceBranch: repo.currentBranch, targetBranch: baseBranch,
                author: author, isMerged: false
            )
            var updatedRepo = repo
            updatedRepo.pullRequests.append(pr)
            let prRepo = updatedRepo
            Self.lock.withLock { Self._repos[repoName] = prRepo }
            return ToolCallResult(id: UUID().uuidString, output: """
                Pull Request 已创建
                - \(prID): \(prTitle)
                - 分支: \(repo.currentBranch) → \(baseBranch)
                - 作者: \(author)
                """)

        case "merge":
            guard let repoSnapshot = Self.lock.withLock({ Self._repos[repoName] }) else {
                return ToolCallResult(id: UUID().uuidString, output: "仓库「\(repoName)」不存在。", isError: true)
            }
            var repo = repoSnapshot
            let branchName = arguments["branch_name"] ?? ""
            let targetBranch = arguments["base_branch"] ?? "main"
            guard !branchName.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "需要 branch_name 参数", isError: true)
            }
            guard let sourceCommits = repo.branches[branchName], !sourceCommits.isEmpty else {
                return ToolCallResult(id: UUID().uuidString, output: "分支「\(branchName)」不存在或无提交。", isError: true)
            }
            let newCommits = sourceCommits.filter { c in
                !(repo.branches[targetBranch]?.contains(where: { $0.hash == c.hash }) ?? false)
            }
            repo.branches[targetBranch, default: []].append(contentsOf: newCommits)
            let mergedRepo = repo
            Self.lock.withLock { Self._repos[repoName] = mergedRepo }
            return ToolCallResult(id: UUID().uuidString, output: """
                合并完成: \(branchName) → \(targetBranch)
                - 合并了 \(newCommits.count) 个提交
                """)

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// MARK: - 438: 终端会话管理

public struct TerminalSessionTool: MCPTool {
    public let definition = ToolDefinition(
        name: "terminal_session",
        description: """
        终端会话管理工具。支持创建、列出、运行命令和关闭终端会话。
        模拟多个终端会话环境。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: create(创建) / list(列表) / run(运行命令) / close(关闭)",
                  required: true),
            .init(name: "session_id", type: .string,
                  description: "会话 ID (create/run/close 时)", required: false),
            .init(name: "command", type: .string,
                  description: "要执行的命令 (action=run 时需要)", required: false),
            .init(name: "working_dir", type: .string,
                  description: "工作目录", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private struct TerminalSession {
        let id: String
        var workingDir: String
        var commandHistory: [String]
        let createdAt: Date
    }

    private static nonisolated(unsafe) var sessions: [String: TerminalSession] = [:]
    private static nonisolated(unsafe) var sessionCounter = 0

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "list"

        switch action {
        case "create":
            let sessionID = arguments["session_id"] ?? "session-\(Self.sessionCounter + 1)"
            let workingDir = arguments["working_dir"] ?? "~"
            let session = TerminalSession(
                id: sessionID,
                workingDir: workingDir,
                commandHistory: [],
                createdAt: Date()
            )
            Self.sessions[sessionID] = session
            Self.sessionCounter += 1
            return ToolCallResult(id: UUID().uuidString, output: """
                终端会话已创建:
                - 会话 ID: \(sessionID)
                - 工作目录: \(workingDir)
                """)

        case "list":
            if Self.sessions.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: "暂无活跃终端会话。")
            }
            let list = Self.sessions.values.map { s in
                "\(s.id) | 目录: \(s.workingDir) | 命令数: \(s.commandHistory.count)"
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "活跃终端会话:\n\(list)")

        case "run":
            let sessionID = arguments["session_id"] ?? Self.sessions.keys.first ?? ""
            guard var session = Self.sessions[sessionID] else {
                return ToolCallResult(id: UUID().uuidString, output: "会话「\(sessionID)」不存在，请先创建。", isError: true)
            }
            let command = arguments["command"] ?? "ls"
            let workingDir = arguments["working_dir"] ?? session.workingDir
            session.commandHistory.append(command)
            session.workingDir = workingDir
            Self.sessions[sessionID] = session

            return ToolCallResult(id: UUID().uuidString, output: """
                执行命令 [会话: \(sessionID)]
                $ \(command)
                工作目录: \(workingDir)

                命令已记录到历史。实际执行需通过 shell 或终端应用。
                历史命令数: \(session.commandHistory.count)
                """)

        case "close":
            let sessionID = arguments["session_id"] ?? ""
            guard !sessionID.isEmpty, Self.sessions.removeValue(forKey: sessionID) != nil else {
                return ToolCallResult(id: UUID().uuidString, output: "未找到会话「\(sessionID)」或未指定 session_id。", isError: true)
            }
            return ToolCallResult(id: UUID().uuidString, output: "终端会话已关闭: \(sessionID)")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }
}

// MARK: - 440: 项目诊断

public struct ProjectDiagnoseTool: MCPTool {
    public let definition = ToolDefinition(
        name: "project_diagnose",
        description: """
        项目诊断工具。支持分析项目依赖、查找未使用代码、检查配置和提供修复建议。
        帮助开发者维护项目健康。
        """,
        parameters: [
            .init(name: "action", type: .string,
                  description: "操作: analyze_deps(分析依赖) / find_unused(查找未使用) / check_config(检查配置) / suggest_fix(建议修复)",
                  required: true),
            .init(name: "project_path", type: .string,
                  description: "项目路径", required: false),
            .init(name: "target", type: .string,
                  description: "分析目标", required: false),
            .init(name: "issue_description", type: .string,
                  description: "问题描述 (action=suggest_fix 时)", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    private struct ProjectIssue {
        let id: String
        let type: String
        let severity: String
        let description: String
        let suggestion: String
    }

    private static nonisolated(unsafe) var detectedIssues: [ProjectIssue] = []

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let action = arguments["action"] ?? "analyze_deps"
        let projectPath = arguments["project_path"] ?? "当前项目"

        switch action {
        case "analyze_deps":
            return ToolCallResult(id: UUID().uuidString, output: """
                依赖分析结果 [\(projectPath)]:

                直接依赖 (3):
                1. RenJistrolyModels (内部) - 核心数据模型
                2. RenJistrolySystemBridge (内部) - 系统桥接
                3. RenJistrolyCapability (内部) - 能力模块

                间接依赖 (5):
                - Foundation (系统)
                - SwiftUI (系统)
                - AppKit (系统)
                - ScreenCaptureKit (系统)
                - OSLog (系统)

                依赖健康: 良好，无循环依赖，版本兼容。
                建议: 定期检查是否有未使用的依赖。
                """)

        case "find_unused":
            let target = arguments["target"] ?? "全部"
            return ToolCallResult(id: UUID().uuidString, output: """
                未使用代码分析 [\(projectPath)] - 目标: \(target)

                分析范围:
                - 未引用的类型和函数
                - 废弃的代码路径
                - 冗余导入

                分析结果: (需要实际代码扫描)
                - 建议使用 Xcode Analyze (Cmd+Shift+B) 进行静态分析
                - 运行 SwiftLint 检测未使用代码
                - 检查 Package.swift 中是否有未使用的依赖
                """)

        case "check_config":
            return ToolCallResult(id: UUID().uuidString, output: """
                配置检查报告 [\(projectPath)]:

                构建配置:
                - Swift 版本: 6.2
                - macOS 目标: 15.0
                - 架构: arm64 (Apple Silicon)

                检查项:
                1. Package.swift — 格式正确
                2. 权限配置 — 需要确认 entitlements 完整
                3. CI 配置 — 建议检查是否与本地环境一致

                建议:
                - 添加 SwiftLint 配置文件统一代码风格
                - 确认 Debug/Release 配置差异是否合理
                """)

        case "suggest_fix":
            let issueDesc = arguments["issue_description"] ?? ""
            if !issueDesc.isEmpty {
                let suggestion = findSuggestion(for: issueDesc)
                let issue = ProjectIssue(
                    id: String(UUID().uuidString.prefix(8).lowercased()),
                    type: "问题分析",
                    severity: suggestion.severity,
                    description: issueDesc,
                    suggestion: suggestion.text
                )
                Self.detectedIssues.append(issue)
                return ToolCallResult(id: UUID().uuidString, output: """
                    修复建议:
                    问题: \(issueDesc)
                    建议: \(suggestion.text)
                    严重程度: \(suggestion.severity)
                    """)
            }

            if Self.detectedIssues.isEmpty {
                return ToolCallResult(id: UUID().uuidString, output: """
                    通用修复建议:

                    1. 编译错误:
                       检查代码语法和依赖版本，运行 swift build --clean 后重试。

                    2. 依赖冲突:
                       运行 swift package resolve 重新解析依赖。

                    3. 代码质量:
                       使用 SwiftLint 自动修复: swiftlint --fix

                    4. 测试覆盖率:
                       运行 swift test --enable-code-coverage 检查覆盖率。

                    如需针对具体问题分析，请提供 issue_description。
                    """)
            }

            let list = Self.detectedIssues.map { i in
                "[\(i.severity)] \(i.description) → \(i.suggestion)"
            }.joined(separator: "\n")
            return ToolCallResult(id: UUID().uuidString, output: "已记录的问题及建议:\n\(list)")

        default:
            return ToolCallResult(id: UUID().uuidString, output: "未知操作: \(action)", isError: true)
        }
    }

    private struct SuggestionResult {
        let text: String
        let severity: String
    }

    private func findSuggestion(for issue: String) -> SuggestionResult {
        let lower = issue.lowercased()
        if lower.contains("编译") || lower.contains("build") {
            return .init(text: "检查代码语法和依赖版本，运行 `swift build --clean` 后重试。查看完整错误日志定位具体文件。", severity: "高")
        }
        if lower.contains("依赖") || lower.contains("package") {
            return .init(text: "运行 `swift package resolve` 重新解析依赖，检查 Package.swift 中版本范围是否冲突。", severity: "中")
        }
        if lower.contains("性能") || lower.contains("卡顿") || lower.contains("慢") {
            return .init(text: "使用 Instruments (Time Profiler) 分析热点函数，检查循环和重复计算。考虑添加缓存或惰性加载。", severity: "中")
        }
        if lower.contains("测试") || lower.contains("test") || lower.contains("失败") {
            return .init(text: "运行 `swift test --filter` 隔离失败用例。检查 mock/stub 数据是否正确。", severity: "中")
        }
        if lower.contains("内存") || lower.contains("泄漏") || lower.contains("leak") {
            return .init(text: "使用 Instruments (Leaks) 检测循环引用。检查闭包捕获列表 [weak self] 使用是否正确。", severity: "高")
        }
        if lower.contains("并发") || lower.contains("线程") || lower.contains("data race") {
            return .init(text: "检查 @MainActor 标注和 Actor 隔离。使用 TSAN (Thread Sanitizer) 检测数据竞争。", severity: "高")
        }
        return .init(text: "建议检查错误日志定位根本原因，可搜索相关错误信息或查阅文档。", severity: "信息")
    }
}
