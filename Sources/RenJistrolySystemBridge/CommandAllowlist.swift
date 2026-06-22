import Foundation

/// 高危命令参数模式 — 用于检测危险参数组合
public struct BlockedCommandPattern: Sendable, Hashable {
    public let commandPrefix: String?
    public let pattern: String
    public let description: String

    public init(commandPrefix: String? = nil, pattern: String, description: String) {
        self.commandPrefix = commandPrefix
        self.pattern = pattern
        self.description = description
    }

    /// 检查命令是否匹配该危险模式
    public func matches(_ command: String) -> Bool {
        if let prefix = commandPrefix {
            guard command.hasPrefix(prefix) else { return false }
        }
        return command.localizedStandardContains(pattern)
    }
}

/// 命令白名单 — 验证命令是否在许可列表中，同时检测高危参数组合
public struct CommandAllowlist: Sendable {
    public let allowed: Set<String>
    public let allowedPrefixes: [String]
    public let blockedPatterns: [BlockedCommandPattern]
    public let systemCommandPaths: Set<String>

    public init(
        allowed: Set<String> = defaultAdminCommands,
        allowedPrefixes: [String] = defaultAllowedPrefixes,
        blockedPatterns: [BlockedCommandPattern] = defaultBlockedPatterns,
        systemCommandPaths: Set<String> = defaultSystemPaths
    ) {
        self.allowed = allowed
        self.allowedPrefixes = allowedPrefixes
        self.blockedPatterns = blockedPatterns
        self.systemCommandPaths = systemCommandPaths
    }

    /// 默认管理员安全命令集（不包括纯执行器如 bash/python/node）
    public static let defaultAdminCommands: Set<String> = [
        "ls", "cat", "head", "tail", "echo", "grep", "find", "sort",
        "wc", "cut", "tr", "uniq", "diff", "file", "stat",
        "ping", "nslookup", "dig", "curl", "wget",
        "swift",
        "mkdir", "touch", "cp", "mv", "rm", "chmod", "chown",
        "ln", "tar", "gzip", "gunzip", "zip", "unzip",
        "kill", "pkill", "ps", "top",
        "date", "df", "du", "pwd", "whoami", "id",
        "open", "osascript",
    ]

    public static let defaultAllowedPrefixes: [String] = [
        "docker",
        "brew",
        "npm",
        "git",
        "system_profiler",
        "sw_vers",
        "defaults",
        "plutil",
    ]

    /// 默认高危参数模式
    public static let defaultBlockedPatterns: [BlockedCommandPattern] = [
        // 递归强制删除
        BlockedCommandPattern(commandPrefix: "rm", pattern: "-rf", description: "递归强制删除"),
        BlockedCommandPattern(commandPrefix: "rm", pattern: "-rf ", description: "递归强制删除"),
        BlockedCommandPattern(commandPrefix: "rm", pattern: "-fr ", description: "递归强制删除"),
        BlockedCommandPattern(commandPrefix: "rm", pattern: "--recursive", description: "递归删除"),
        BlockedCommandPattern(commandPrefix: "rm", pattern: "/*", description: "尝试删除根目录"),

        // dd 危险操作
        BlockedCommandPattern(commandPrefix: "dd", pattern: "if=", description: "磁盘级读取"),
        BlockedCommandPattern(commandPrefix: "dd", pattern: "of=", description: "磁盘级写入"),

        // sudo 高风险组合
        BlockedCommandPattern(pattern: "sudo rm", description: "以 sudo 执行删除"),
        BlockedCommandPattern(pattern: "sudo dd", description: "以 sudo 执行 dd"),
        BlockedCommandPattern(pattern: "sudo chmod", description: "以 sudo 修改权限"),
        BlockedCommandPattern(pattern: "sudo chown", description: "以 sudo 修改所有者"),
        BlockedCommandPattern(pattern: "sudo mkfs", description: "以 sudo 格式化磁盘"),
        BlockedCommandPattern(pattern: "sudo fdisk", description: "以 sudo 操作分区"),
        BlockedCommandPattern(pattern: "sudo diskutil", description: "以 sudo 操作磁盘"),

        // chmod 危险组合
        BlockedCommandPattern(pattern: "chmod 777", description: "设置过度开放的权限"),
        BlockedCommandPattern(pattern: "chmod -R 777", description: "递归设置过度开放的权限"),
        BlockedCommandPattern(pattern: "chmod 000", description: "移除所有权限"),
        BlockedCommandPattern(pattern: "chmod 0 ", description: "移除所有权限"),

        // 磁盘操作
        BlockedCommandPattern(pattern: "mkfs.", description: "格式化文件系统"),
        BlockedCommandPattern(pattern: "fdisk", description: "分区表操作"),
        BlockedCommandPattern(pattern: "diskutil erase", description: "擦除磁盘"),
        BlockedCommandPattern(pattern: "diskutil unmountDisk", description: "卸载磁盘"),
        BlockedCommandPattern(pattern: "diskutil zeroDisk", description: "擦除磁盘数据"),

        // 管道到 shell
        BlockedCommandPattern(pattern: "| sh", description: "管道到 sh"),
        BlockedCommandPattern(pattern: "| bash", description: "管道到 bash"),
        BlockedCommandPattern(pattern: "| zsh", description: "管道到 zsh"),
        BlockedCommandPattern(pattern: "| python3", description: "管道到 python"),
        BlockedCommandPattern(pattern: "| node", description: "管道到 node"),

        // 内联执行
        BlockedCommandPattern(pattern: "$(", description: "命令替换执行"),
        BlockedCommandPattern(pattern: "`", description: "反引号命令替换"),
        BlockedCommandPattern(pattern: "&>", description: "重定向所有输出"),

        // 覆盖系统文件
        BlockedCommandPattern(pattern: "> /etc/", description: "覆盖系统配置"),
        BlockedCommandPattern(pattern: "> /System/", description: "覆盖系统文件"),

        // 危险 chown
        BlockedCommandPattern(pattern: "chown -R", description: "递归修改所有者"),
        BlockedCommandPattern(pattern: "chown root", description: "将文件所有者改为 root"),
        BlockedCommandPattern(pattern: "chown 0:", description: "将文件所有者改为 root"),

        // Fork 炸弹
        BlockedCommandPattern(pattern: ":(){", description: "Fork 炸弹"),
        BlockedCommandPattern(pattern: "() {", description: "疑似 Fork 炸弹"),

        // 内核操作
        BlockedCommandPattern(pattern: "sysctl -w", description: "修改内核参数"),
        BlockedCommandPattern(pattern: "kldload", description: "加载内核模块"),
        BlockedCommandPattern(pattern: "kextload", description: "加载内核扩展"),
        BlockedCommandPattern(pattern: "kextutil", description: "加载内核扩展"),

        // 网络代理重定向
        BlockedCommandPattern(pattern: "networksetup -setwebproxy", description: "更改系统代理"),
        BlockedCommandPattern(pattern: "networksetup -setsecurewebproxy", description: "更改系统安全代理"),

        // 文件系统卸载/挂载
        BlockedCommandPattern(pattern: "umount ", description: "卸载文件系统"),
        BlockedCommandPattern(pattern: "mount -t", description: "挂载文件系统"),
    ]

    /// 常见系统命令路径
    public static let defaultSystemPaths: Set<String> = [
        "/bin/", "/usr/bin/", "/sbin/", "/usr/sbin/",
        "/opt/homebrew/bin/", "/usr/local/bin/",
    ]

    /// 验证命令是否可以被执行
    /// - Returns: nil 表示允许，非 nil 表示被拒绝的原因
    public func allows(_ command: String) -> String? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "命令为空" }
        if trimmed.contains("\n") || trimmed.contains("\r") || trimmed.contains("\0") {
            return "命令包含不允许的控制字符"
        }

        // 提取命令名（第一个词）
        guard let first = trimmed.components(separatedBy: .whitespacesAndNewlines).first(where: { !$0.isEmpty }) else {
            return "无法解析命令"
        }
        let commandName = URL(fileURLWithPath: first).lastPathComponent
        let remainder = trimmed.dropFirst(first.count)
        let normalizedCommand = commandName + remainder

        // 1. 检查是否在白名单中（精确匹配）
        let allowedExact = allowed.contains(commandName)

        // 2. 检查是否在白名单前缀中（前缀匹配）
        let allowedPrefix = allowedPrefixes.contains { commandName.hasPrefix($0) }

        if first.contains("/") && !isSystemCommand(first) {
            return "命令路径「\(first)」不在允许的系统路径中"
        }

        if !allowedExact && !allowedPrefix {
            return "命令「\(commandName)」不在允许列表中"
        }

        // 3. 检查高危参数模式
        for pattern in blockedPatterns {
            if pattern.matches(trimmed) || pattern.matches(normalizedCommand) {
                return "检测到高危操作「\(pattern.description)」，已阻止执行：\(pattern.pattern)"
            }
        }

        // 4. 额外安全检查：curl/wget 管道到 bash 的检测
        // 有些命令组合可能绕过简单模式匹配，如 curl -s url | while read; do eval $REPLY; done
        if containsDangerousPipeline(trimmed) {
            return "检测到危险管道操作"
        }

        return nil
    }

    /// 检测危险管道（curl/wget 配合 shell 执行）
    private func containsDangerousPipeline(_ command: String) -> Bool {
        let lower = command.lowercased()
        let hasNetworkFetch = lower.contains("curl ") || lower.contains("wget ") || lower.contains("fetch ")
        guard hasNetworkFetch else { return false }

        // 检测各种危险的后续处理方式
        let dangerousSuffixes = [
            "| sh", "| bash", "| zsh", "| /bin/sh", "| /bin/bash", "| /bin/zsh",
            "| source", "| . ",
            "| python", "| python3", "| node",
            "`", "$(",
            "| while read", "| while IFS",
            "| eval",
            "| tee /dev/", // tee 到设备文件
        ]
        for suffix in dangerousSuffixes {
            if lower.contains(suffix) { return true }
        }
        return false
    }

    /// 判断命令是否为系统命令（来自标准系统路径）
    public func isSystemCommand(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.components(separatedBy: .whitespacesAndNewlines).first(where: { !$0.isEmpty }) else {
            return false
        }
        // 如果命令包含路径分隔符，检查是否在系统路径下
        if first.contains("/") {
            return systemCommandPaths.contains { first.hasPrefix($0) }
        }
        // 无路径的命令通常是系统命令
        return true
    }

    /// 判断命令是否为自定义脚本（非系统标准命令或路径）
    public func isScriptCommand(_ command: String) -> Bool {
        !isSystemCommand(command)
    }

    /// 添加允许的命令
    public func addingCommands(_ commands: String...) -> CommandAllowlist {
        CommandAllowlist(
            allowed: allowed.union(commands),
            allowedPrefixes: allowedPrefixes,
            blockedPatterns: blockedPatterns,
            systemCommandPaths: systemCommandPaths
        )
    }

    /// 移除允许的命令
    public func removingCommands(_ commands: String...) -> CommandAllowlist {
        CommandAllowlist(
            allowed: allowed.subtracting(commands),
            allowedPrefixes: allowedPrefixes,
            blockedPatterns: blockedPatterns,
            systemCommandPaths: systemCommandPaths
        )
    }

    /// 添加危险模式
    public func addingBlockedPatterns(_ patterns: BlockedCommandPattern...) -> CommandAllowlist {
        var newPatterns = blockedPatterns
        newPatterns.append(contentsOf: patterns)
        return CommandAllowlist(
            allowed: allowed,
            allowedPrefixes: allowedPrefixes,
            blockedPatterns: newPatterns,
            systemCommandPaths: systemCommandPaths
        )
    }

    /// 添加白名单前缀
    public func addingPrefixes(_ prefixes: String...) -> CommandAllowlist {
        CommandAllowlist(
            allowed: allowed,
            allowedPrefixes: allowedPrefixes + prefixes,
            blockedPatterns: blockedPatterns,
            systemCommandPaths: systemCommandPaths
        )
    }
}
