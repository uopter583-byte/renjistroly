import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

extension CommandParser {
    // MARK: - Git Operations

    static func parseGitOps(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        let lower = text.lowercased()
        if toolNames.contains("git_status"),
           lower == "git status" || lower.contains("git status") ||
           ((text.contains("状态") || lower.contains("status")) && lower.contains("git")) {
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: UUID().uuidString, name: "git_status", arguments: [:])],
                response: "正在查看 git 状态..."
            )
        }
        if toolNames.contains("git_log"),
           lower == "git log" || lower.contains("git log") ||
           ((text.contains("日志") || text.contains("历史") || lower.contains("log")) && lower.contains("git")) {
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: UUID().uuidString, name: "git_log", arguments: [:])],
                response: "正在查看 git 日志..."
            )
        }

        guard toolNames.contains("shell_command") else { return nil }
        let gitPatterns = [
            #"^(?:git|git的|执行git)\s+(.+)"#,
            #"(?:^|\s)(?:执行|运行|做)(?:一个)?git\s+(.+?)$"#,
        ]
        for p in gitPatterns {
            if let m = try? Regex(p).firstMatch(in: text) {
                let cmd = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                guard !cmd.isEmpty, "git \(cmd)".count < 2000 else { return nil }
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "shell_command", arguments: ["command": "git \(cmd)"])],
                    response: "git \(cmd)"
                )
            }
        }
        return nil
    }

    // MARK: - Git Blame

    static func parseGitBlame(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("git_blame") || toolNames.contains("shell_command") else { return nil }
        let patterns = [
            #"(?:git\s+)?blame\s+[''"』]?(\S+)[''"』]?"#,
            #"(?:谁|who)\s*(?:改的|写的|修改的|编辑的)\s*(.*)"#,
            #"(?:查看|显示|看)?\s*(?:提交|commit)?\s*历史\s*(?:of|for)?\s*(.*)"#,
        ]
        for p in patterns {
            if let m = try? Regex(p).firstMatch(in: text) {
                let file = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                guard !file.isEmpty else { return nil }
                let id = UUID().uuidString
                if toolNames.contains("git_blame") {
                    return ParsedCommand(
                        toolCalls: [ToolCallRequest(id: id, name: "git_blame", arguments: ["file_path": file])],
                        response: "正在查看 \(file) 的提交历史..."
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Git Branch

    static func parseGitBranch(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("git_branch") || toolNames.contains("shell_command") else { return nil }
        let actionPatterns: [(String, String)] = [
            (#"(?:列出|查看|显示|list)\s*(?:所有)?\s*(?:分支|branch)"#, "list"),
            (#"创建\s*(?:分支)?\s*[''"』]?(\S+)[''"』]?"#, "create"),
            (#"切换\s*(?:到)?\s*(?:分支)?\s*[''"』]?(\S+)[''"』]?"#, "switch"),
            (#"删除\s*(?:分支)?\s*[''"』]?(\S+)[''"』]?"#, "delete"),
            (#"(?:当前|current)\s*(?:分支|branch)"#, "current"),
        ]
        for (pattern, action) in actionPatterns {
            if let m = try? Regex(pattern).firstMatch(in: text) {
                let id = UUID().uuidString
                if toolNames.contains("git_branch") {
                    var args: [String: String] = ["action": action]
                    if m.output.count > 1, let name = m.output[1].substring {
                        args["name"] = String(name).trimmingCharacters(in: .whitespaces)
                    }
                    return ParsedCommand(
                        toolCalls: [ToolCallRequest(id: id, name: "git_branch", arguments: args)],
                        response: action == "list" ? "正在获取分支列表..." : "正在执行分支操作..."
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Git Commit

    static func parseGitCommit(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("git_commit") || toolNames.contains("shell_command") else { return nil }
        let patterns = [
            #"(?:提交|commit)\s*[：:]?\s*(.+)"#,
        ]
        for p in patterns {
            if let m = try? Regex(p).firstMatch(in: text) {
                let msg = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                guard !msg.isEmpty else { return nil }
                let id = UUID().uuidString
                if toolNames.contains("git_commit") {
                    return ParsedCommand(
                        toolCalls: [ToolCallRequest(id: id, name: "git_commit", arguments: ["message": msg, "stage_all": "true"])],
                        response: "正在提交: \(msg)"
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Git Advanced

    static func parseGitAdvanced(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        if parseGitStash(text, toolNames: toolNames) != nil { return parseGitStash(text, toolNames: toolNames) }
        if parseGitPushPull(text, toolNames: toolNames) != nil { return parseGitPushPull(text, toolNames: toolNames) }
        if parseGitRemote(text, toolNames: toolNames) != nil { return parseGitRemote(text, toolNames: toolNames) }
        if parseGitReset(text, toolNames: toolNames) != nil { return parseGitReset(text, toolNames: toolNames) }
        if parseGitMergeRebase(text, toolNames: toolNames) != nil { return parseGitMergeRebase(text, toolNames: toolNames) }
        if parseGitTag(text, toolNames: toolNames) != nil { return parseGitTag(text, toolNames: toolNames) }
        if parseGitShow(text, toolNames: toolNames) != nil { return parseGitShow(text, toolNames: toolNames) }
        if parseGitCherryPick(text, toolNames: toolNames) != nil { return parseGitCherryPick(text, toolNames: toolNames) }
        if parseGitRevert(text, toolNames: toolNames) != nil { return parseGitRevert(text, toolNames: toolNames) }
        if parseGitClean(text, toolNames: toolNames) != nil { return parseGitClean(text, toolNames: toolNames) }
        if parseGitRestore(text, toolNames: toolNames) != nil { return parseGitRestore(text, toolNames: toolNames) }

        return nil
    }

    static func parseGitStash(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("git_stash") else { return nil }
        let lower = text.lowercased()
        if lower.contains("stash") || lower.contains("暂存") {
            for (p, action) in [
                (#"(?:pop|弹出|恢复|应用)"#, "pop"),
                (#"(?:apply|应用)"#, "apply"),
                (#"(?:list|列出)"#, "list"),
                (#"(?:drop|删除)"#, "drop"),
            ] {
                if (try? Regex(p).firstMatch(in: text)) != nil {
                    let id = UUID().uuidString
                    return ParsedCommand(
                        toolCalls: [ToolCallRequest(id: id, name: "git_stash", arguments: ["action": action])],
                        response: "正在执行 stash \(action)..."
                    )
                }
            }
            let patterns = [
                #"(?:stash|暂存|贮藏)\s*(?:save|push|保存)?\s*(?:[''"』])?(.+?)[''"』]?$"#,
            ]
            for p in patterns {
                if let m = try? Regex(p).firstMatch(in: text) {
                    let name = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                    let id = UUID().uuidString
                    var args: [String: String] = ["action": "save"]
                    if !name.isEmpty { args["message"] = name }
                    return ParsedCommand(
                        toolCalls: [ToolCallRequest(id: id, name: "git_stash", arguments: args)],
                        response: !name.isEmpty ? "stash 保存: \(name)" : "正在暂存..."
                    )
                }
            }
            let actionPatterns: [(String, String)] = [
                (#"(?:pop|弹出|恢复|应用)"#, "pop"),
                (#"(?:apply|应用)"#, "apply"),
                (#"(?:list|列出)"#, "list"),
                (#"(?:drop|删除)"#, "drop"),
            ]
            for (p, action) in actionPatterns {
                if (try? Regex(p).firstMatch(in: text)) != nil {
                    let id = UUID().uuidString
                    return ParsedCommand(
                        toolCalls: [ToolCallRequest(id: id, name: "git_stash", arguments: ["action": action])],
                        response: "正在执行 stash \(action)..."
                    )
                }
            }
        }
        return nil
    }

    static func parseGitPushPull(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("git_push_pull") else { return nil }
        if (try? Regex(#"(?:push|推送|上传)"#).firstMatch(in: text)) != nil {
            let id = UUID().uuidString
            var args: [String: String] = ["action": "push"]
            if let remoteM = try? Regex(#"(?:到|to)\s+(\S+)"#).firstMatch(in: text) {
                args["remote"] = String(remoteM.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
            }
            if let branchM = try? Regex(#"(?:分支|branch)\s+(\S+)"#).firstMatch(in: text) {
                args["branch"] = String(branchM.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
            }
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "git_push_pull", arguments: args)],
                response: "正在推送..."
            )
        }
        if (try? Regex(#"(?:pull|拉取|更新|fetch)"#).firstMatch(in: text)) != nil {
            let id = UUID().uuidString
            let action = text.localizedCaseInsensitiveContains("fetch") ? "fetch" : "pull"
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "git_push_pull", arguments: ["action": action])],
                response: action == "fetch" ? "正在获取..." : "正在拉取..."
            )
        }
        return nil
    }

    static func parseGitRemote(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("git_remote") else { return nil }
        if (try? Regex(#"(?:remote|远程)"#).firstMatch(in: text)) != nil {
            let id = UUID().uuidString
            var args: [String: String] = ["action": "list"]
            if let m = try? Regex(#"(?:添加|add)\s+(\S+)\s+(\S+)"#).firstMatch(in: text) {
                args["action"] = "add"
                if m.output.count > 1, let name = m.output[1].substring {
                    args["name"] = String(name).trimmingCharacters(in: .whitespaces)
                }
                if m.output.count > 2, let url = m.output[2].substring {
                    args["url"] = String(url).trimmingCharacters(in: .whitespaces)
                }
            }
            if let rm = try? Regex(#"(?:移除|删除|remove|rm)\s+(\S+)"#).firstMatch(in: text) {
                args["action"] = "remove"
                args["name"] = String(rm.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
            }
            if let sm = try? Regex(#"(?:查看|show|info)\s+(\S+)"#).firstMatch(in: text) {
                args["action"] = "show"
                args["name"] = String(sm.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
            }
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "git_remote", arguments: args)],
                response: args["action"] == "list" ? "正在查看远程仓库..." : "正在执行..."
            )
        }
        return nil
    }

    static func parseGitReset(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("git_reset") else { return nil }
        if let m = try? Regex(#"(?:reset|重置)\s*(?:--(?:hard|soft|mixed))?\s*(?:到|至|to)?\s*(\S+)"#).firstMatch(in: text) {
            let target = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
            let id = UUID().uuidString
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "git_reset", arguments: ["ref": target.isEmpty ? "HEAD~1" : target])],
                response: "正在 reset 到 \(target.isEmpty ? "HEAD~1" : target)..."
            )
        }
        return nil
    }

    static func parseGitMergeRebase(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("git_merge_rebase") else { return nil }
        if let m = try? Regex(#"(?:merge|合并)\s+(\S+)"#).firstMatch(in: text) {
            let branch = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
            let id = UUID().uuidString
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "git_merge_rebase", arguments: ["action": "merge", "branch": branch])],
                response: "正在合并 \(branch)..."
            )
        }
        if let m = try? Regex(#"(?:rebase|变基)\s+(\S+)"#).firstMatch(in: text) {
            let branch = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
            let id = UUID().uuidString
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "git_merge_rebase", arguments: ["action": "rebase", "branch": branch])],
                response: "正在 rebase \(branch)..."
            )
        }
        return nil
    }

    static func parseGitTag(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("git_tag") else { return nil }
        if (try? Regex(#"(?:列出|查看|list)\s*(?:标签|tag)"#).firstMatch(in: text)) != nil ||
           (try? Regex(#"git\s+tag"#).firstMatch(in: text)) != nil {
            let id = UUID().uuidString
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "git_tag", arguments: ["action": "list"])],
                response: "正在获取标签列表..."
            )
        }
        if let m = try? Regex(#"(?:创建|create|添加)\s*(?:标签)?\s*[''"』]?(\S+)[''"』]?"#).firstMatch(in: text) {
            let name = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
            let id = UUID().uuidString
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "git_tag", arguments: ["action": "create", "name": name])],
                response: "正在创建标签: \(name)"
            )
        }
        if let m = try? Regex(#"(?:删除|delete|移除)\s*(?:标签)?\s*[''"』]?(\S+)[''"』]?"#).firstMatch(in: text) {
            let name = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
            let id = UUID().uuidString
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "git_tag", arguments: ["action": "delete", "name": name])],
                response: "正在删除标签: \(name)"
            )
        }
        return nil
    }

    static func parseGitShow(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("git_show") else { return nil }
        let patterns = [
            #"(?:show|查看|显示)\s*(?:提交|commit)?\s*[''"』]?(\S+)[''"』]?"#,
            #"git\s+show\s+(\S+)"#,
        ]
        for p in patterns {
            if let m = try? Regex(p).firstMatch(in: text) {
                let ref = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                guard !ref.isEmpty else { return nil }
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "git_show", arguments: ["ref": ref])],
                    response: "查看提交: \(ref)"
                )
            }
        }
        return nil
    }

    static func parseGitCherryPick(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("git_cherry_pick") else { return nil }
        let patterns = [
            #"(?:cherry-pick|挑选)\s+(\S+)"#,
        ]
        for p in patterns {
            if let m = try? Regex(p).firstMatch(in: text) {
                let commit = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                guard !commit.isEmpty else { return nil }
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "git_cherry_pick", arguments: ["action": "pick", "commit": commit])],
                    response: "正在 cherry-pick: \(commit)"
                )
            }
        }
        return nil
    }

    static func parseGitRevert(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("git_revert") else { return nil }
        let patterns = [
            #"(?:revert|撤销|还原)\s*(?:提交)?\s*(\S+)"#,
        ]
        for p in patterns {
            if let m = try? Regex(p).firstMatch(in: text) {
                let commit = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                guard !commit.isEmpty else { return nil }
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "git_revert", arguments: ["commit": commit])],
                    response: "正在撤销: \(commit)"
                )
            }
        }
        return nil
    }

    static func parseGitClean(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("git_clean") else { return nil }
        if (try? Regex(#"(?:预览|dry\s*run|--dry-run)"#).firstMatch(in: text)) != nil {
            let id = UUID().uuidString
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "git_clean", arguments: ["dry_run": "true"])],
                response: "正在预览清理未跟踪文件..."
            )
        }
        if (try? Regex(#"(?:clean|清理|清除)\s*(?:未跟踪)?"#).firstMatch(in: text)) != nil {
            let id = UUID().uuidString
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "git_clean", arguments: [:])],
                response: "正在清理未跟踪文件..."
            )
        }
        return nil
    }

    static func parseGitRestore(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        let patterns = [
            #"(?:restore|还原|恢复)\s+(\S+)"#,
        ]
        for p in patterns {
            if let m = try? Regex(p).firstMatch(in: text) {
                let file = String(m.output[1].substring ?? "").trimmingCharacters(in: .whitespaces)
                guard !file.isEmpty else { return nil }
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "shell_command", arguments: ["command": "git restore \(file)"])],
                    response: "正在还原: \(file)"
                )
            }
        }
        return nil
    }
}
