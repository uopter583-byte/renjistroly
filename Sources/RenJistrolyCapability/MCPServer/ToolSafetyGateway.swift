import Foundation
import RenJistrolyModels
import OSLog

public actor ToolSafetyGateway {
    private let registry: MCPToolRegistry
    private let policyProvider: @Sendable () -> ToolExecutionPolicy

    public init(
        registry: MCPToolRegistry,
        policyProvider: @escaping @Sendable () -> ToolExecutionPolicy
    ) {
        self.registry = registry
        self.policyProvider = policyProvider
    }

    public func assess(_ request: ToolCallRequest) async -> ToolRiskAssessment {
        let tool = await registry.getTool(request.name)
        let category = categorize(toolName: request.name, arguments: request.arguments)
        let level: ToolRiskLevel
        if request.name == "shell_command" || request.name == "terminal_run" {
            level = shellRiskLevel(command: request.arguments["command"], category: category)
        } else if category == .unknown {
            level = tool?.riskLevel ?? .high
        } else {
            level = max(tool?.riskLevel ?? .high, category.defaultRiskLevel)
        }
        let summary = summarize(toolName: request.name, riskLevel: level, arguments: request.arguments)
        let explanation = explainRisk(toolName: request.name, level: level, category: category, arguments: request.arguments)
        let hint = mitigationHint(toolName: request.name, level: level, category: category)
        return ToolRiskAssessment(
            toolName: request.name,
            riskLevel: level,
            actionCategory: category,
            arguments: request.arguments,
            summary: summary,
            riskExplanation: explanation,
            mitigationHint: hint
        )
    }

    public func batchAssess(_ requests: [ToolCallRequest]) async -> BatchSafetyAssessment {
        let assessments = await withTaskGroup(of: ToolRiskAssessment.self) { group in
            for req in requests { group.addTask { await self.assess(req) } }
            var results: [ToolRiskAssessment] = []
            for await result in group { results.append(result) }
            return results
        }
        let overall = assessments.map(\.riskLevel).max() ?? .low
        let topRisks = assessments.filter { $0.riskLevel >= .medium }.prefix(3)
        let summaryLines: [String] = topRisks.map { "\($0.summary) — \($0.riskExplanation)" }
        let summary = summaryLines.joined(separator: "\n")
        return BatchSafetyAssessment(
            items: assessments,
            overallRisk: overall,
            summary: summary,
            requiresBatchConfirmation: assessments.contains { !policyProvider().canAutoExecute($0.riskLevel) }
        )
    }

    public func batchConfirmSummary(_ batch: BatchSafetyAssessment) -> String {
        var lines: [String] = ["即将执行 \(batch.items.count) 个操作:"]
        for (i, item) in batch.items.enumerated() {
            let marker = item.riskLevel >= .high ? "⚠️" : (item.riskLevel >= .medium ? "⚡" : "✓")
            lines.append("  \(marker) \(i + 1). \(item.summary)")
            if !item.riskExplanation.isEmpty {
                lines.append("      风险: \(item.riskExplanation)")
            }
            if let hint = item.mitigationHint {
                lines.append("      建议: \(hint)")
            }
        }
        lines.append("\n风险分布: \(batch.riskBreakdown)")
        return lines.joined(separator: "\n")
    }

    public func needsConfirmation(_ request: ToolCallRequest) async -> Bool {
        let assessment = await assess(request)
        return !policyProvider().canAutoExecute(assessment.riskLevel)
    }

    // MARK: - 敏感路径保护

    private var sensitivePaths: [String] {
        let home = NSHomeDirectory()
        return [
            "\(home)/.ssh",
            "\(home)/.aws",
            "\(home)/.kube",
            "\(home)/.gitconfig",
            "\(home)/.zshrc",
            "\(home)/.bashrc",
            "\(home)/.bash_profile",
            "\(home)/.env",
            "\(home)/Library/Keychains",
            "\(home)/Library/Application Support",
        ]
    }

    private func isSensitiveWritePath(_ path: String) -> Bool {
        let expanded = (path as NSString).expandingTildeInPath
        let resolved = URL(fileURLWithPath: expanded).standardized.path
        return sensitivePaths.contains { resolved == $0 || resolved.hasPrefix($0 + "/") }
    }

    // MARK: - 敏感内容模式

    private static let sensitiveContentPatterns: [NSRegularExpression] = {
        let patterns = [
            // OpenAI / Anthropic API keys
            #"sk-[a-zA-Z0-9]{20,}"#,
            #"ant-[a-zA-Z0-9]{24,}"#,
            // AWS access key
            #"AKIA[0-9A-Z]{16}"#,
            // GitHub tokens
            #"ghp_[a-zA-Z0-9]{36}"#,
            #"gho_[a-zA-Z0-9]{36}"#,
            #"github_pat_[a-zA-Z0-9]{22,}"#,
            // GitLab tokens
            #"glpat-[a-zA-Z0-9\-]{20,}"#,
            // Slack tokens
            #"xox[baprs]-[a-zA-Z0-9\-]{10,}"#,
            // Generic password assignment patterns
            #""password"\s*:\s*"[^"]{6,}""#,
            #"'password'\s*:\s*'[^']{6,}'"#,
            #"password\s*[=:]\s*['\"][^'\"]{6,}['\"]"#,
            #"PASSWORD\s*=\s*['\"][^'\"]+['\"]"#,
            #"API[-_]?KEY\s*=\s*['\"][^'\"]+['\"]"#,
            #"SECRET[-_]?KEY\s*=\s*['\"][^'\"]+['\"]"#,
            #"TOKEN\s*=\s*['\"][^'\"]+['\"]"#,
            #"token\s*[=:]\s*['\"][a-zA-Z0-9._\-]{20,}['\"]"#,
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: []) }
    }()

    /// 检查工具调用是否需要直接阻止执行。
    /// 如果返回非 nil 的 ToolCallResult，调用方应直接返回该结果，不执行实际工具。
    public func blockedResult(for request: ToolCallRequest) -> ToolCallResult? {
        // 检查 shell_command 中的危险磁盘命令
        if request.name == "shell_command", let command = request.arguments["command"] {
            if isDangerousDiskCommand(command) {
                os_log(.error, "[ToolSafety] 拦截危险磁盘命令: %{public}s", command)
                return ToolCallResult(
                    id: request.id,
                    output: "⚠️ 安全限制：该命令包含危险磁盘操作，已阻止执行。\n" +
                           "检测到磁盘级写入/格式化操作，可能造成数据丢失或系统损坏。\n" +
                           "如需执行，请在终端手动操作并确认目标磁盘正确。",
                    isError: true
                )
            }
            // 如果 shell_injection 且包含关键命令
            if hasShellInjectionRisk(command) {
                let lower = command.lowercased()
                if lower.contains("curl") || lower.contains("wget") {
                    os_log(.error, "[ToolSafety] 拦截带注入风险的命令: %{public}s", command)
                    return ToolCallResult(
                        id: request.id,
                        output: "⚠️ 安全限制：该命令将网络下载内容直接 pipe 到 shell，存在代码执行风险。\n" +
                               "建议：先将下载内容保存到文件检查，再决定是否执行。",
                        isError: true
                    )
                }
            }
        }

        // 检查 file_edit 的路径保护
        if request.name == "file_edit" {
            guard let path = request.arguments["file_path"], !path.isEmpty else { return nil }
            if isSensitiveWritePath(path) {
                os_log(.error, "[ToolSafety] 拦截敏感路径写入: %{public}s", path)
                return ToolCallResult(
                    id: request.id,
                    output: "⚠️ 安全限制：禁止写入系统配置/密钥目录。如需修改，请在设置中手动调整。",
                    isError: true
                )
            }
            if let content = request.arguments["new_string"], !content.isEmpty {
                let nsContent = content as NSString
                for pattern in Self.sensitiveContentPatterns {
                    let range = NSRange(location: 0, length: nsContent.length)
                    if let match = pattern.firstMatch(in: content, range: range) {
                        let matched = nsContent.substring(with: match.range)
                        let redacted = String(matched.prefix(8)) + "..." + String(matched.suffix(4))
                        os_log(.error, "[ToolSafety] 文件内容包含密钥/凭据模式: %{public}s -> %{public}s", path, redacted)
                        return ToolCallResult(
                            id: request.id,
                            output: "⚠️ 安全限制：文件内容包含疑似密钥或凭据（'\(redacted)'），" +
                                   "禁止直接写入文件以防范意外泄露。\n" +
                                   "建议：\n" +
                                   "  1. 确认该值不是真实凭据后，手动移除或调整\n" +
                                   "  2. 使用环境变量替代硬编码凭据\n" +
                                   "  3. 将凭据放入系统的钥匙串（Keychain）管理",
                            isError: true
                        )
                    }
                }
            }
            return nil
        }

        // 检查 write_file 的路径保护
        guard request.name == "write_file" else { return nil }
        guard let path = request.arguments["path"], !path.isEmpty else { return nil }

        // 路径安全检查
        if isSensitiveWritePath(path) {
            os_log(.error, "[ToolSafety] 拦截敏感路径写入: %{public}s", path)
            return ToolCallResult(
                id: request.id,
                output: "⚠️ 安全限制：禁止写入系统配置/密钥目录。如需修改，请在设置中手动调整。",
                isError: true
            )
        }

        // 内容安全检查
        if let content = request.arguments["content"], !content.isEmpty {
            let nsContent = content as NSString
            for pattern in Self.sensitiveContentPatterns {
                let range = NSRange(location: 0, length: nsContent.length)
                if let match = pattern.firstMatch(in: content, range: range) {
                    let matched = nsContent.substring(with: match.range)
                    let redacted = String(matched.prefix(8)) + "..." + String(matched.suffix(4))
                    os_log(.error, "[ToolSafety] 文件内容包含密钥/凭据模式: %{public}s -> %{public}s", path, redacted)
                    return ToolCallResult(
                        id: request.id,
                        output: "⚠️ 安全限制：文件内容包含疑似密钥或凭据（'\(redacted)'），" +
                               "禁止直接写入文件以防范意外泄露。\n" +
                               "建议：\n" +
                               "  1. 确认该值不是真实凭据后，手动移除或调整\n" +
                               "  2. 使用环境变量替代硬编码凭据\n" +
                               "  3. 将凭据放入系统的钥匙串（Keychain）管理",
                        isError: true
                    )
                }
            }
        }

        return nil
    }

    private func summarize(toolName: String, riskLevel: ToolRiskLevel, arguments: [String: String]) -> String {
        switch toolName {
        case "shell_command":
            let cmd = arguments["command"] ?? "?"
            return "执行 Shell 命令: \(cmd.prefix(80))"
        case "write_file":
            let path = arguments["path"] ?? "?"
            return "写入文件: \(path)"
        case "type_text":
            let text = arguments["text"] ?? "?"
            return "输入文字: \(text.prefix(40))"
        case "set_value":
            return "设置 UI 元素 \(arguments["element_index"] ?? "?") 的内容"
        case "drag":
            return "拖拽操作: (\(arguments["from_x"] ?? "?") , \(arguments["from_y"] ?? "?")) → (\(arguments["to_x"] ?? "?") , \(arguments["to_y"] ?? "?"))"
        case "press_key":
            let key = arguments["key"] ?? "?"
            let mods = arguments["modifiers"] ?? ""
            return mods.isEmpty ? "按下按键: \(key)" : "按下组合键: \(mods)+\(key)"
        case "activate_menu":
            return "激活菜单: \(arguments["path"] ?? "?")"
        case "click_element":
            return "点击元素: \(arguments["title"] ?? arguments["role"] ?? "?")"
        case "click":
            if let index = arguments["element_index"] {
                return "点击 UI 元素: \(index)"
            }
            return "点击坐标: (\(arguments["x"] ?? "?"), \(arguments["y"] ?? "?"))"
        case "ocr_screen":
            return "屏幕文字识别"
        case "get_app_state":
            return "观察应用状态: \(arguments["app"] ?? "前台应用")"
        case "list_app_drivers":
            return "列出 app drivers"
        case "open_app":
            return "打开应用: \(arguments["app_name"] ?? "?")"
        case "open_path":
            return "在 Finder 打开路径: \(arguments["path"] ?? "?")"
        case "finder_search":
            return "在 Finder 搜索: \(arguments["query"] ?? "?")"
        case "list_directory":
            return "列出目录: \(arguments["path"] ?? "?")"
        case "get_finder_state":
            return "读取 Finder 当前窗口状态"
        case "open_url":
            return "打开网址: \(arguments["url"] ?? "?")"
        case "safari_search":
            return "Safari 搜索: \(arguments["query"] ?? "?")"
        case "get_browser_state":
            return "读取浏览器状态: \(arguments["app"] ?? "Safari")"
        case "terminal_run":
            return "Terminal 运行命令: \(arguments["command"] ?? "?")"
        case "scroll": return "滚动界面"
        case "focus_window": return "聚焦窗口: \(arguments["title"] ?? "?")"
        case "claude_agent":
            let prompt = arguments["prompt"] ?? "?"
            return "Claude Code: \(prompt.prefix(60))"
        default:
            return "\(toolName) [\(riskLevel.rawValue)]"
        }
    }

    func categorize(toolName: String, arguments: [String: String]) -> ToolActionCategory {
        switch toolName {
        case "get_app_state", "list_windows", "get_ui_tree", "read_focused_text",
             "running_apps", "system_info", "git_status", "git_log", "git_diff",
             "read_file", "list_files", "project_info", "read_screen",
             "ocr_screen", "screen_context", "list_app_drivers",
             "git_show", "find_symbol", "rg_search", "git_blame",
             "list_schemes", "build_settings", "code_sign_info",
             "changed_files", "quick_open", "lsp_symbol":
            return .observe
        case "open_in_xcode", "reveal_in_finder":
            return .localNavigation
        case "click", "click_element", "press_key", "type_text", "set_value",
             "activate_menu", "scroll", "focus_window", "drag":
            return .localInput
        case "open_app":
            return .appLaunch
        case "open_path":
            return .localNavigation
        case "finder_search", "list_directory":
            return .observe
        case "get_finder_state":
            return .observe
        case "open_url":
            return .localNavigation
        case "safari_search":
            return .localNavigation
        case "get_browser_state":
            return .observe
        case "terminal_run":
            return isMutatingShellCommand(arguments["command"]) ? .shellWrite : .shellRead
        case "write_file":
            return .localFileWrite
        case "shell_command", "swift_build", "swift_test", "xcodebuild":
            return isMutatingShellCommand(arguments["command"]) ? .shellWrite : .shellRead
        case "git_commit", "git_branch", "git_stash", "git_push_pull",
             "git_reset", "git_merge_rebase", "git_cherry_pick", "git_revert",
             "git_clean", "git_remote", "git_tag":
            return .shellWrite
        case "process":
            return arguments["action"] == "list" ? .observe : .shellWrite
        case "clipboard":
            if arguments["action"] == "read" {
                return .sensitiveDataTransmission
            }
            return .credentialOrAccount
        case "claude_agent":
            return .codeAgent
        // Business scenario tools (406-435)
        case "session_context", "script_strategy", "sentiment_analysis",
             "context_isolation", "translate_with_tone", "crm_field_mapping",
             "sales_stage", "quote_template", "speaker_diarization",
             "reminder", "multi_window_fusion", "data_export_mask",
             "dry_run", "chart_ocr_parse", "csv_validate", "baseline_compare":
            return .observe
        case "permission_aware", "webpage_structure", "timezone_check",
             "window_verify", "site_confirm", "ocr_confidence_check":
            return .observe
        case "high_risk_confirm", "amount_change_confirm", "push_confirm",
             "production_switch", "cms_version":
            return .systemSetting
        case "crm_audit":
            return arguments["action"] == "record" ? .localFileWrite : .observe
        case "refund_risk_assess":
            return .financial
        case "contract_approval":
            return arguments["action"] == "create" ? .financial : .observe
        default:
            return .unknown
        }
    }

    private func explainRisk(toolName: String, level: ToolRiskLevel, category: ToolActionCategory, arguments: [String: String]) -> String {
        switch category {
        case .shellWrite:
            if isDangerousDiskCommand(arguments["command"] ?? "") {
                return "高危磁盘操作命令，误执行可能导致分区表损坏或数据永久丢失"
            }
            if hasShellInjectionRisk(arguments["command"] ?? "") {
                return "命令包含潜在的 Shell 注入模式（管道到 shell 或命令替换），可能执行任意代码"
            }
            if arguments["command"]?.contains("rm ") == true || arguments["command"]?.contains("rm -") == true {
                return "删除命令将永久移除文件，无法通过废纸篓恢复"
            }
            if arguments["command"]?.contains("sudo") == true {
                return "使用 sudo 提权执行，可能绕过系统安全机制"
            }
            if arguments["command"]?.contains("git push") == true {
                return "Git 推送会修改远程仓库，影响团队协作"
            }
            return "修改性 Shell 命令可能改变系统状态或文件内容"
        case .localFileWrite:
            let path = arguments["path"] ?? ""
            if path.hasPrefix("/etc/") || path.hasPrefix("/System/") {
                return "写入系统目录 \(path) 可能破坏操作系统稳定性"
            }
            if path.hasPrefix("~/.ssh/") || path.hasPrefix("~/.aws/") || path.contains(".env") {
                return "写入凭据或配置文件 \(path) 存在安全风险"
            }
            return "写入文件将覆盖目标路径的现有内容，可能造成数据丢失"
        case .localFileDelete:
            let path = arguments["path"] ?? ""
            return "删除文件 \(path) 将永久移除内容，建议先确认文件用途"
        case .codeAgent:
            return "AI 代理将以开发者权限执行多步操作，包括读写文件、执行命令和修改代码"
        case .systemSetting:
            if toolName == "production_switch" {
                let sw = arguments["switch_name"] ?? "未知"
                return "生产开关「\(sw)」的变更会影响线上用户，误操作可能导致服务故障"
            }
            if toolName == "push_confirm" {
                let title = arguments["title"] ?? "未知"
                let recipients = arguments["estimated_recipients"] ?? "未知"
                return "推送「\(title)」将发送给 \(recipients) 名用户，推送内容无法撤回"
            }
            if toolName == "cms_version" {
                return "CMS 内容发布会影响前台展示，回滚操作需谨慎"
            }
            if toolName == "high_risk_confirm" {
                let detail = arguments["action_detail"] ?? "未知"
                return "高风险操作确认: \(detail)。此操作不可逆，请谨慎确认"
            }
            if toolName == "amount_change_confirm" {
                let oldVal = arguments["old_amount"] ?? "?"
                let newVal = arguments["new_amount"] ?? "?"
                return "金额从 \(oldVal) 修改为 \(newVal)，影响客户报价和收入核算"
            }
            return "修改系统设置可能影响全局行为，需要管理员权限或系统偏好授权"
        case .externalCommunication:
            return "可能向外部服务发送数据，请注意隐私和合规要求"
        case .sensitiveDataTransmission:
            return "涉及敏感数据传输，可能包含凭据、个人信息或内部资料"
        case .credentialOrAccount:
            return "涉及账号或凭据操作，泄漏可能导致未授权访问"
        case .financial:
            if toolName == "refund_risk_assess" {
                return "退款风险评估涉及资金变动，错误的评估可能导致资金损失"
            }
            if toolName == "contract_approval" {
                let amount = arguments["amount"] ?? "未知"
                return "合同审批涉及金额 \(amount) 的确认，审批通过后将产生法律效力"
            }
            return "涉及金融相关操作，可能导致资金损失"
        case .installSoftware:
            return "安装软件将修改系统环境，可能引入未知依赖或安全漏洞"
        case .appLaunch:
            return "启动应用会创建新进程并占用系统资源"
        case .localInput, .localNavigation:
            if toolName == "type_text", let text = arguments["text"], text.count > 100 {
                return "输入较长文本（\(text.count) 字符），可能包含不可见内容"
            }
            return "模拟用户输入会操作当前焦点界面"
        case .observe, .localFileRead, .shellRead:
            return "" // Low risk needs no explanation
        case .unknown:
            return "未识别的工具类型，无法评估具体风险"
        }
    }

    private func mitigationHint(toolName: String, level: ToolRiskLevel, category: ToolActionCategory) -> String? {
        switch category {
        case .shellWrite:
            if level >= .high {
                return "建议手动审查命令后再执行"
            }
            return "可以先加 --dry-run 或 echo 预览效果"
        case .localFileWrite:
            return "建议先备份目标文件"
        case .localFileDelete:
            return "可先移动到废纸篓（Finder）而非直接删除"
        case .codeAgent:
            return "建议限制代理的工作目录范围"
        case .systemSetting:
            return "修改前记下当前值以便回滚"
        case .externalCommunication, .sensitiveDataTransmission:
            return "检查传输目标是否为已知可信地址"
        default:
            return nil
        }
    }

    private func shellRiskLevel(command: String?, category: ToolActionCategory) -> ToolRiskLevel {
        guard let command else { return .high }
        if isDangerousDiskCommand(command) || hasShellInjectionRisk(command) {
            return .high
        }
        if category == .shellRead {
            return .low
        }
        let lower = command.lowercased()
        if lower.contains("sudo") || lower.contains("git push") || lower.contains("rm ") || lower.contains("rm -") {
            return .high
        }
        return category.defaultRiskLevel
    }

    func isMutatingShellCommand(_ command: String?) -> Bool {
        guard let command = command?.lowercased() else { return true }
        let trimmed = command.trimmingCharacters(in: .whitespaces)

        if hasShellInjectionRisk(command) { return true }

        if command.contains(">") || command.contains(">>") {
            return true
        }

        if trimmed.hasPrefix("sed") && trimmed.contains(" -i") { return true }

        if trimmed.hasPrefix("find") && (command.contains("-delete") || command.contains("-exec rm") || command.contains("-exec sh")) {
            return true
        }

        if command.contains("git push") && (command.contains("--force") || command.contains("-f")),
           command.contains("main") || command.contains("master") {
            return true
        }

        let readOnlyPrefixes = [
            "ls", "pwd", "cat", "rg", "grep", "find", "echo", "git status",
            "git log", "git diff", "swift test", "swift build"
        ]
        if readOnlyPrefixes.contains(where: { trimmed.hasPrefix($0) }) {
            return false
        }
        if trimmed.hasPrefix("sed") && !trimmed.contains(" -i") {
            return false
        }
        if trimmed.hasPrefix("rm ") || trimmed.hasPrefix("mv ") || trimmed.hasPrefix("cp ") { return true }

        let mutatingMarkers = [
            " rm ", "rm -", " mv ", " cp ", "chmod", "chown",
            "sudo", "curl", "wget", "brew install", "npm install", "pip install",
            "make install", "git push", "git commit", "git reset", "git checkout"
        ]
        return mutatingMarkers.contains { command.contains($0) }
    }

    func hasShellInjectionRisk(_ command: String) -> Bool {
        if command.contains("| sh") || command.contains("| bash") || command.contains("| zsh") { return true }
        if command.contains("$(") || command.contains("`") { return true }
        return false
    }

    /// 检查命令是否包含危险磁盘操作
    private func isDangerousDiskCommand(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespaces).lowercased()
        let diskCommands = [
            "dd ", "dd if", "dd of",        // dd 磁盘写入
            "mkfs", "mkfs.", "mke2fs",      // 格式化
            "fdisk", "gdisk", "parted",     // 分区工具
            "diskutil", "diskutil erase", "diskutil reformat", "diskutil partition",
            "diskutil zero", "diskutil random", // diskutil 破坏性操作
            "pv ", "pv -",                   // 物理卷操作
            "lvm", "vgchange", "pvcreate",  // LVM
            "hdiutil create", "hdiutil burn", // 磁盘映像写入
            "hdid",                             // 挂载映像
            "asr", "asr restore", "asr erase", // Apple Software Restore
            "flashrom",                         // BIOS/firmware 写入
        ]
        return diskCommands.contains { trimmed.hasPrefix($0) || command.contains(" " + $0.trimmingCharacters(in: .whitespaces)) }
    }
}
