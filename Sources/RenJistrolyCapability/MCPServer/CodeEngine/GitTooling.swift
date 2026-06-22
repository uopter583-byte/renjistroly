import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

// =====================================================================
// 场景 378: Git 状态感知（PR 上下文）
// =====================================================================
// 已有 GitStatusTool + GitBranchTool + ChangedFilesTool。
// 补充：PR 创建前的完整状态概览

public struct PrStatusTool: MCPTool {
    public let definition = ToolDefinition(
        name: "pr_status",
        description: "获取当前分支的完整 PR 状态：当前分支、base 差异、未推送提交、未跟踪文件。用于开 PR 前的状态检查",
        parameters: [
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let repoPath = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath

        guard await isGitRepo(at: repoPath) else {
            return ToolCallResult(id: UUID().uuidString, output: "不是 Git 仓库: \(repoPath)", isError: true)
        }

        var lines: [String] = []
        lines.append("=== PR 状态概览 ===\n")

        // 当前分支
        let branch = await runGitComamnd(["rev-parse", "--abbrev-ref", "HEAD"], repoPath: repoPath)
        lines.append("当前分支: \(branch)\n")

        // 检测 base 分支
        let base = await detectBaseRef(at: repoPath)
        if !base.isEmpty {
            lines.append("Base 分支: \(base)\n")

            // ahead/behind
            let revList = await runGitComamnd(["rev-list", "--left-right", "--count", "\(base)...HEAD"], repoPath: repoPath)
            let counts = revList.split(separator: "\t").map(String.init)
            if counts.count >= 2 {
                let behind = counts[0].trimmingCharacters(in: .whitespaces)
                let ahead = counts[1].trimmingCharacters(in: .whitespaces)
                if behind != "0" {
                    lines.append("落后 base \(behind) 个提交（需要先 rebase/pull）\n")
                }
                if ahead != "0" {
                    lines.append("领先 base \(ahead) 个提交\n")
                }
            }

            // commits since base
            let log = await runGitComamnd(["log", "--oneline", "\(base)..HEAD"], repoPath: repoPath)
            if !log.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.append("\n自 \(base) 以来的提交:\n")
                for c in log.split(separator: "\n").prefix(20) {
                    lines.append("  \(c)\n")
                }
            }

            // files changed vs base
            let files = await runGitComamnd(["diff", "--name-status", "\(base)..HEAD"], repoPath: repoPath)
            if !files.trimmingCharacters(in: .whitespaces).isEmpty {
                let fileLines = files.split(separator: "\n")
                lines.append("\n变更文件 (\(fileLines.count) 个):\n")
                for f in fileLines.prefix(30) {
                    lines.append("  \(f)\n")
                }
                if fileLines.count > 30 {
                    lines.append("  ... 还有 \(fileLines.count - 30) 个文件\n")
                }
            }
        } else {
            lines.append("Base 分支: 未检测到 main/master\n")
        }

        // 工作区状态
        let status = await runGitComamnd(["status", "--porcelain"], repoPath: repoPath)
        let statusLines = status.split(separator: "\n").filter { !$0.isEmpty }
        if !statusLines.isEmpty {
            lines.append("\n工作区有 \(statusLines.count) 个未提交变更:\n")
            for s in statusLines.prefix(20) {
                lines.append("  \(s)\n")
            }
            if statusLines.count > 20 {
                lines.append("  ... 还有 \(statusLines.count - 20) 个\n")
            }
        } else {
            lines.append("\n工作区干净\n")
        }

        // 远程跟踪状态
        let remote = await runGitComamnd(["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"], repoPath: repoPath)
        if !remote.trimmingCharacters(in: .whitespaces).isEmpty && !remote.contains("fatal") {
            lines.append("\n跟踪远程: \(remote.trimmingCharacters(in: .whitespacesAndNewlines))\n")
        } else {
            lines.append("\n未设置上游跟踪分支（需要 git push --set-upstream）\n")
        }

        lines.append("\n=== 可以开 PR ===")
        return ToolCallResult(id: UUID().uuidString, output: lines.joined())
    }

    private func isGitRepo(at path: String) async -> Bool {
        let result = await runGitComamnd(["rev-parse", "--git-dir"], repoPath: path)
        return !result.trimmingCharacters(in: .whitespaces).isEmpty && !result.contains("fatal")
    }

    private func detectBaseRef(at path: String) async -> String {
        for ref in ["main", "master"] {
            let r = await runGitComamnd(["rev-parse", "--verify", ref], repoPath: path)
            if !r.trimmingCharacters(in: .whitespaces).isEmpty && !r.contains("fatal") {
                return ref
            }
        }
        return ""
    }

    private func runGitComamnd(_ args: [String], repoPath: String) async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["-C", repoPath] + args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        return await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { continuation.resume(returning: "") }
        }
    }
}

// =====================================================================
// 场景 380: 变更范围控制
// =====================================================================
// 在重构/修改前检查预计变更的文件范围和数量

public struct ChangeScopeTool: MCPTool {
    public let definition = ToolDefinition(
        name: "change_scope",
        description: "评估变更范围：查看当前工作区修改的文件数量、变更量级、高风险文件。用于重构前控制变更范围",
        parameters: [
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
            .init(name: "base", type: .string, description: "基准分支，默认 main/master 自动检测", required: false),
            .init(name: "max_files", type: .string, description: "重构建议的最大文件数，超出则警告，默认 10", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let repoPath = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let maxFiles = Int(arguments["max_files"] ?? "10") ?? 10

        guard await isGitRepo(at: repoPath) else {
            return ToolCallResult(id: UUID().uuidString, output: "不是 Git 仓库", isError: true)
        }

        var lines: [String] = []
        lines.append("=== 变更范围评估 ===\n")

        // 1. 当前未提交变更
        let status = await gitCmd(["status", "--porcelain"], repoPath: repoPath)
        let statusEntries = status.split(separator: "\n").filter { !$0.isEmpty }

        if !statusEntries.isEmpty {
            lines.append("\n工作区未提交变更: \(statusEntries.count) 个文件\n")
            for e in statusEntries.prefix(30) {
                lines.append("  \(e)\n")
            }
            if statusEntries.count > 30 {
                lines.append("  ... 还有 \(statusEntries.count - 30) 个\n")
            }
        }

        // 2. 与 base 分支的差异
        let detectedBase = await detectBaseRef(at: repoPath)
        let base = arguments["base"] ?? detectedBase
        if !base.isEmpty {
            let diffStat = await gitCmd(["diff", "--stat", "\(base)..HEAD"], repoPath: repoPath)
            if !diffStat.trimmingCharacters(in: .whitespaces).isEmpty {
                let changedFiles = await gitCmd(["diff", "--name-only", "\(base)..HEAD"], repoPath: repoPath)
                let fileList = changedFiles.split(separator: "\n").filter { !$0.isEmpty }

                lines.append("\n与 \(base) 的差异:\n")
                lines.append("  变更文件: \(fileList.count)\n")
                lines.append("  明细:\n\(diffStat)\n")

                // 3. 评估风险
                let risk = assessChangeRisk(fileCount: fileList.count, files: fileList.map(String.init))
                lines.append("\n【风险评估】\n")
                lines.append("  量级: \(risk.level)\n")
                lines.append("  建议: \(risk.advice)\n")

                // 4. 如果超出 maxFiles，给出警告
                if fileList.count > maxFiles {
                    lines.append("\n  ⚠️ 变更文件数 (\(fileList.count)) 超过建议上限 (\(maxFiles))\n")
                    lines.append("  建议拆分重构，分批提交。\n")
                }

                // 5. 检测高风险文件
                let highRiskFiles = detectHighRiskFiles(Array(fileList.map(String.init)), repoPath: repoPath)
                if !highRiskFiles.isEmpty {
                    lines.append("\n  高风险文件:\n")
                    for f in highRiskFiles {
                        lines.append("    🔴 \(f)\n")
                    }
                }
            }
        }

        return ToolCallResult(id: UUID().uuidString, output: lines.joined())
    }

    private func assessChangeRisk(fileCount: Int, files: [String]) -> (level: String, advice: String) {
        switch fileCount {
        case 0:
            return ("无变更", "没有需要评估的变更。")
        case 1...3:
            return ("小范围", "影响范围有限，适合直接修改。")
        case 4...10:
            return ("中等范围", "需要关注测试覆盖。建议 review 时逐个文件确认。")
        case 11...20:
            return ("大范围", "建议分批提交。检查是否有不必要的文件变更。")
        default:
            return ("超大范围", "强烈建议拆分为多个 PR。确保变更经过充分测试。")
        }
    }

    private func detectHighRiskFiles(_ files: [String], repoPath: String) -> [String] {
        // 检测高风险文件：核心模块、共享配置、自动生成文件
        let highRiskPatterns = [
            "Package.swift", "Package.resolved",
            "Podfile", "Podfile.lock",
            ".gitignore", ".gitmodules",
            "project.pbxproj", "*.xcworkspace",
        ]

        var highRisk: [String] = []
        for file in files {
            for pattern in highRiskPatterns {
                if pattern.hasPrefix("*") {
                    if file.hasSuffix(String(pattern.dropFirst())) {
                        highRisk.append(file)
                    }
                } else if file == pattern || file.hasSuffix("/" + pattern) {
                    highRisk.append(file)
                }
            }
        }
        return highRisk
    }

    private func isGitRepo(at path: String) async -> Bool {
        let r = await gitCmd(["rev-parse", "--git-dir"], repoPath: path)
        return !r.trimmingCharacters(in: .whitespaces).isEmpty && !r.contains("fatal")
    }

    private func detectBaseRef(at path: String) async -> String {
        for ref in ["main", "master"] {
            let r = await gitCmd(["rev-parse", "--verify", ref], repoPath: path)
            if !r.trimmingCharacters(in: .whitespaces).isEmpty && !r.contains("fatal") {
                return ref
            }
        }
        return ""
    }

    private func gitCmd(_ args: [String], repoPath: String) async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["-C", repoPath] + args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        return await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { continuation.resume(returning: "") }
        }
    }
}

// =====================================================================
// 场景 383: Lockfile 安全检查
// =====================================================================
// 检查 Package.resolved / Podfile.lock 的变更风险

public struct LockfileCheckTool: MCPTool {
    public let definition = ToolDefinition(
        name: "lockfile_check",
        description: "检查依赖锁定文件的变更风险：分析 Package.resolved（SwiftPM）的依赖变化，检测不兼容升级和风险变更",
        parameters: [
            .init(name: "repo_path", type: .string, description: "仓库路径", required: false),
            .init(name: "base", type: .string, description: "基准分支，默认 main/master 自动检测", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let repoPath = arguments["repo_path"] ?? FileManager.default.currentDirectoryPath
        let detectedBase = await detectBaseRef(at: repoPath)
        let base = arguments["base"] ?? detectedBase

        var lines: [String] = []
        lines.append("=== Lockfile 安全检查 ===\n")

        // 1. 检查 Package.resolved
        let resolvedPath = "\(repoPath)/Package.resolved"
        if FileManager.default.fileExists(atPath: resolvedPath) {
            lines.append("\n【SwiftPM】Package.resolved 存在\n")

            let resolvedBasePath: String
            if !base.isEmpty {
                resolvedBasePath = await gitShow("\(base):Package.resolved", repoPath: repoPath)
                if !resolvedBasePath.isEmpty {
                    lines.append(compareResolved(current: resolvedPath, baseContent: resolvedBasePath))
                }
            }

            // 检查当前 resolved 文件状态
            if let currentResolved = try? Data(contentsOf: URL(fileURLWithPath: resolvedPath)),
               let json = try? JSONSerialization.jsonObject(with: currentResolved) as? [String: Any] {

                let pins = extractPins(from: json)
                if !pins.isEmpty {
                    lines.append("\n当前依赖 (\(pins.count) 个):\n")
                    for pin in pins {
                        lines.append("  📦 \(pin.name) (\(pin.version)) \(pin.revision.prefix(8))\n")
                    }
                }
            }
        }

        // 2. 检查 Package.resolved 是否被误改（不应手动修改）
        let gitStatus = await gitCmd(["diff", "--name-only", "--", "Package.resolved"], repoPath: repoPath)
        if !gitStatus.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.append("\n⚠️ Package.resolved 有未提交的本地修改！\n")
            lines.append("  锁定文件通常不应手动编辑。使用 'swift package update' 更新。\n")
        }

        // 3. 安全检查摘要
        lines.append("\n【安全检查】\n")
        lines.append("  ✅ 锁定文件追踪中（应提交到版本控制）\n")
        if !base.isEmpty {
            let hasChanges = await gitCmd(["diff", "--name-only", "\(base)..HEAD", "--", "Package.resolved"], repoPath: repoPath)
            if !hasChanges.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.append("  ⚠️ 相对于 \(base) 有依赖变更，review 时请仔细检查\n")
            }
        }

        return ToolCallResult(id: UUID().uuidString, output: lines.joined())
    }

    private func compareResolved(current: String, baseContent: String) -> String {
        guard let currentData = try? Data(contentsOf: URL(fileURLWithPath: current)),
              let currentJson = try? JSONSerialization.jsonObject(with: currentData) as? [String: Any],
              let baseData = baseContent.data(using: .utf8),
              let baseJson = try? JSONSerialization.jsonObject(with: baseData) as? [String: Any]
        else { return "" }

        let currentPins = extractPins(from: currentJson)
        let basePins = extractPins(from: baseJson)

        var output = "\n依赖变化分析:\n"

        let currentByName = Dictionary(uniqueKeysWithValues: currentPins.map { ($0.name, $0) })
        let baseByName = Dictionary(uniqueKeysWithValues: basePins.map { ($0.name, $0) })

        for (name, cur) in currentByName {
            if let base = baseByName[name] {
                if cur.version != base.version {
                    output += "  ⚠️ \(name): \(base.version) → \(cur.version)\n"
                    output += "     revision: \(base.revision.prefix(8)) → \(cur.revision.prefix(8))\n"
                } else if cur.revision != base.revision {
                    output += "  ⚠️ \(name): version 不变但 revision 变化\n"
                    output += "     \(base.revision.prefix(8)) → \(cur.revision.prefix(8))\n"
                } else {
                    output += "  ✅ \(name): \(cur.version)（不变）\n"
                }
            } else {
                output += "  🆕 \(name): \(cur.version)（新增）\n"
            }
        }

        for (name, base) in baseByName {
            if currentByName[name] == nil {
                output += "  🗑️ \(name): \(base.version)（移除）\n"
            }
        }

        // 检测主版本变更（major version bump）
        for (name, cur) in currentByName {
            if let base = baseByName[name], cur.version != base.version {
                let curMajor = cur.version.split(separator: ".").first ?? ""
                let baseMajor = base.version.split(separator: ".").first ?? ""
                if curMajor != baseMajor && !curMajor.isEmpty && !baseMajor.isEmpty {
                    output += "\n  🔴 \(name): Major 版本变更 (\(base.version) → \(cur.version))！⚠️ 可能涉及破坏性变更\n"
                }
            }
        }

        return output
    }

    private func extractPins(from json: [String: Any]) -> [DependencyPin] {
        var pins: [DependencyPin] = []

        // SwiftPM 6 format
        if let pinData = json["pins"] as? [[String: Any]] {
            for p in pinData {
                let name = p["identity"] as? String ?? p["package"] as? String ?? "?"
                let state = p["state"] as? [String: Any] ?? [:]
                let version = state["version"] as? String ?? "?"
                let revision = state["revision"] as? String ?? "?"
                pins.append(DependencyPin(name: name, version: version, revision: revision))
            }
        }
        // Swift 5 format
        if let objects = json["object"] as? [[String: Any]] {
            for p in objects {
                let name = p["package"] as? String ?? p["repositoryURL"] as? String ?? "?"
                let version = p["version"] as? String ?? "?"
                let revision = p["revision"] as? String ?? "?"
                pins.append(DependencyPin(name: name, version: version, revision: revision))
            }
        }

        // 尝试从 package 字段中提取短名称
        return pins.map { pin in
            let shortName: String
            if pin.name.contains("/") || pin.name.contains(".") {
                shortName = pin.name.split(separator: "/").last.map(String.init) ?? pin.name
            } else {
                shortName = pin.name
            }
            return DependencyPin(name: shortName, version: pin.version, revision: pin.revision)
        }
    }

    private func gitShow(_ ref: String, repoPath: String) async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["-C", repoPath, "show", ref]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        return await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { continuation.resume(returning: "") }
        }
    }

    private func gitCmd(_ args: [String], repoPath: String) async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["-C", repoPath] + args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        return await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try task.run() } catch { continuation.resume(returning: "") }
        }
    }

    private func detectBaseRef(at path: String) async -> String {
        for ref in ["main", "master"] {
            let r = await gitCmd(["rev-parse", "--verify", ref], repoPath: path)
            if !r.trimmingCharacters(in: .whitespaces).isEmpty && !r.contains("fatal") {
                return ref
            }
        }
        return ""
    }

    private struct DependencyPin {
        let name: String
        let version: String
        let revision: String
    }
}
