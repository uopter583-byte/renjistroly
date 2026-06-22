import Foundation

/// 日志脱敏 — 收集日志时去除敏感信息，支持分级脱敏
public struct LogSanitizer: Sendable {
    /// 脱敏强度等级
    public enum SanitizationLevel: String, Sendable, CaseIterable {
        case light      // 仅脱敏高置信度敏感信息（密码、凭据）
        case medium     // 额外脱敏邮箱、手机号、IP、URL 凭据
        case aggressive // 额外脱敏 UUID、JWT、私钥、查询参数
    }

    /// 脱敏规则
    public struct Rule: Sendable {
        public let pattern: String
        public let replacement: String
        public let description: String
        public let level: SanitizationLevel

        public init(pattern: String, replacement: String, description: String = "", level: SanitizationLevel = .medium) {
            self.pattern = pattern
            self.replacement = replacement
            self.description = description
            self.level = level
        }
    }

    public let level: SanitizationLevel
    public var rules: [Rule]

    public init(rules: [Rule] = defaultRules, level: SanitizationLevel = .medium) {
        self.rules = rules
        self.level = level
    }

    /// 默认脱敏规则集（按等级组织）
    public static let defaultRules: [Rule] = [
        // === Light 级别 ===
        // 密码/凭据
        Rule(pattern: "(?i)(password|passwd|pwd)\\s*[:=]\\s*\\S+", replacement: "$1: ******", description: "密码", level: .light),
        Rule(pattern: "(?i)(api[_-]?key|secret|token|auth[_-]?token|bearer)\\s*[:=]\\s*\\S+", replacement: "$1: <redacted>", description: "API 密钥/令牌", level: .light),

        // SSH 私钥阻塞（以 -----BEGIN 开头）
        Rule(pattern: "-----BEGIN\\s+(RSA|DSA|EC|OPENSSH|PRIVATE)\\s+KEY-----[\\s\\S]*?-----END\\s+(RSA|DSA|EC|OPENSSH|PRIVATE)\\s+KEY-----", replacement: "<private-key-block-redacted>", description: "私钥块", level: .light),

        // === Medium 级别 ===
        // URL 嵌入凭据（必须放在邮箱前面，否则 `user:pass@` 会被邮箱规则提前匹配）
        Rule(pattern: "(?<=//)[^:]+:[^@]+@", replacement: "<credentials>@", description: "URL 凭据", level: .medium),

        // 邮箱
        Rule(pattern: "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", replacement: "<email-redacted>", description: "邮箱", level: .medium),

        // 美国 SSN
        Rule(pattern: "\\b\\d{3}-\\d{2}-\\d{4}\\b", replacement: "<ssn-redacted>", description: "SSN", level: .medium),

        // 信用卡号
        Rule(pattern: "\\b(?:\\d{4}[- ]?){3}\\d{4}\\b", replacement: "<credit-card-redacted>", description: "信用卡号", level: .medium),

        // 手机号（中国大陆 1xx xxxx xxxx）
        Rule(pattern: "(?<!\\d)1[3-9]\\d{1}[ -]?\\d{4}[ -]?\\d{4}(?!\\d)", replacement: "<phone-redacted>", description: "手机号", level: .medium),

        // 国际手机号（+86 或 +1 等）
        Rule(pattern: "\\+\\d{1,3}[ -]?\\d{4,}[ -]?\\d{3,}", replacement: "<phone-redacted>", description: "国际手机号", level: .medium),

        // IPv4 地址
        Rule(pattern: "\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b", replacement: "<ip-redacted>", description: "IPv4 地址", level: .medium),

        // IP:Port
        Rule(pattern: "\\b(?:\\d{1,3}\\.){3}\\d{1,3}:\\d{2,5}\\b", replacement: "<ip:port-redacted>", description: "IP:Port", level: .medium),

        // === Aggressive 级别 ===
        // UUID
        Rule(pattern: "[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}", replacement: "<uuid-redacted>", description: "UUID", level: .aggressive),

        // JWT 令牌
        Rule(pattern: "[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+", replacement: "<jwt-redacted>", description: "JWT 令牌", level: .aggressive),

        // 短 base64 令牌（20+ 字符，非 JWT）
        Rule(pattern: "(?<![A-Za-z0-9_\\-.]|eyJ)[A-Za-z0-9+/]{20,}(?:={1,2})?(?!\\S*[A-Za-z0-9_\\-.]|\\.[A-Za-z0-9_\\-])", replacement: "<base64-redacted>", description: "Base64 令牌", level: .aggressive),

        // URL 查询参数中的值（?key=value&token=xxx）
        Rule(pattern: "(?i)([?&](?:token|secret|key|password|passwd|pwd|api[_-]?key|access[_-]?token|auth[_-]?token|session[_-]?token|refresh[_-]?token|code|state)=)[^&]+", replacement: "$1<redacted>", description: "URL 查询参数凭据", level: .aggressive),

        // MAC 地址
        Rule(pattern: "\\b(?:[A-Fa-f0-9]{2}[:-]){5}[A-Fa-f0-9]{2}\\b", replacement: "<mac-redacted>", description: "MAC 地址", level: .aggressive),

        // 完整路径中可能包含用户名
        Rule(pattern: "/Users/([^/]+)/", replacement: "/Users/<redacted>/", description: "用户名路径", level: .aggressive),
    ]

    /// 对日志行应用脱敏规则
    public func sanitize(line: String) -> String {
        var result = line
        for rule in rules {
            guard rule.level.rawValue <= level.rawValue else { continue }
            // 使用 try? 静默跳过可能无效的自定义正则（用户添加的规则中模式可能不合法）
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { continue }
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result),
                withTemplate: rule.replacement
            )
        }
        return result
    }

    /// 批量脱敏
    public func sanitize(lines: [String]) -> [String] {
        lines.map { sanitize(line: $0) }
    }

    /// 添加自定义规则
    public func addingRule(_ rule: Rule) -> LogSanitizer {
        var newRules = rules
        newRules.append(rule)
        return LogSanitizer(rules: newRules, level: level)
    }

    /// 添加多个自定义规则
    public func addingRules(_ rules: [Rule]) -> LogSanitizer {
        var newRules = self.rules
        newRules.append(contentsOf: rules)
        return LogSanitizer(rules: newRules, level: level)
    }

    /// 切换脱敏等级
    public func withLevel(_ level: SanitizationLevel) -> LogSanitizer {
        LogSanitizer(rules: rules, level: level)
    }

    /// 获取适用于当前等级的规则
    public var activeRules: [Rule] {
        rules.filter { $0.level.rawValue <= level.rawValue }
    }
}

extension LogSanitizer.SanitizationLevel: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        let order: [Self: Int] = [.light: 0, .medium: 1, .aggressive: 2]
        return (order[lhs] ?? 0) < (order[rhs] ?? 0)
    }
}
