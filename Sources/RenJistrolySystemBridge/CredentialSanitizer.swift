import Foundation

/// 凭据脱敏 — 配置 VPN 等操作时防止泄漏凭据
public struct CredentialSanitizer: Sendable {
    /// 脱敏强度
    public enum RedactionStrength: String, Sendable {
        case light    // 保留长度指示: ******(12)
        case medium   // 统一替换: ******
        case aggressive // 完全隐藏: <redacted>
    }

    /// 自定义脱敏规则
    public struct CustomRule: Sendable {
        public let pattern: String
        public let replacement: String
        public let description: String

        public init(pattern: String, replacement: String, description: String = "") {
            self.pattern = pattern
            self.replacement = replacement
            self.description = description
        }
    }

    public let strength: RedactionStrength
    public let customRules: [CustomRule]

    public init(strength: RedactionStrength = .medium, customRules: [CustomRule] = []) {
        self.strength = strength
        self.customRules = customRules
    }

    /// 通用凭据模式（key: value 格式）
    private static let credentialKeyValuePatterns: [(pattern: String, key: String)] = [
        // 基本密码类
        ("(?i)(password\\s*[:=]\\s*)", "password"),
        ("(?i)(passwd\\s*[:=]\\s*)", "passwd"),
        ("(?i)(pwd\\s*[:=]\\s*)", "pwd"),
        ("(?i)(secret\\s*[:=]\\s*)", "secret"),
        ("(?i)(token\\s*[:=]\\s*)", "token"),

        // API 密钥类
        ("(?i)(api[_-]?key\\s*[:=]\\s*)", "api_key"),
        ("(?i)(api[_-]?secret\\s*[:=]\\s*)", "api_secret"),
        ("(?i)(access[_-]?key\\s*[:=]\\s*)", "access_key"),
        ("(?i)(access[_-]?secret\\s*[:=]\\s*)", "access_secret"),
        ("(?i)(secret[_-]?key\\s*[:=]\\s*)", "secret_key"),
        ("(?i)(client[_-]?secret\\s*[:=]\\s*)", "client_secret"),
        ("(?i)(client[_-]?id\\s*[:=]\\s*)", "client_id"),

        // 令牌类
        ("(?i)(auth[_-]?token\\s*[:=]\\s*)", "auth_token"),
        ("(?i)(session[_-]?token\\s*[:=]\\s*)", "session_token"),
        ("(?i)(refresh[_-]?token\\s*[:=]\\s*)", "refresh_token"),
        ("(?i)(id[_-]?token\\s*[:=]\\s*)", "id_token"),
        ("(?i)(access[_-]?token\\s*[:=]\\s*)", "access_token"),
        ("(?i)(bearer\\s*[:=]\\s*)", "bearer"),

        // SSH/密钥类
        ("(?i)(private[_-]?key\\s*[:=]\\s*)", "private_key"),
        ("(?i)(ssh[_-]?key\\s*[:=]\\s*)", "ssh_key"),
        ("(?i)(ssh[_-]?private[_-]?key\\s*[:=]\\s*)", "ssh_private_key"),

        // 其他
        ("(?i)(encryption[_-]?key\\s*[:=]\\s*)", "encryption_key"),
        ("(?i)(master[_-]?key\\s*[:=]\\s*)", "master_key"),
        ("(?i)(slack[_-]?token\\s*[:=]\\s*)", "slack_token"),
        ("(?i)(github[_-]?token\\s*[:=]\\s*)", "github_token"),
        ("(?i)(jwt[_-]?secret\\s*[:=]\\s*)", "jwt_secret"),
        ("(?i)(signing[_-]?key\\s*[:=]\\s*)", "signing_key"),
    ]

    /// 对文本中的凭据信息进行脱敏
    public func sanitize(_ text: String) -> String {
        var result = text

        // 1. 脱敏 Base64 编码的凭据（长编码字符串）
        result = sanitizeBase64(result)

        // 2. 脱敏 key=value 格式的凭据
        for (pattern, key) in Self.credentialKeyValuePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern + #"(?!["'<])([^\s&,"'}\]]+)"#) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result, range: range,
                withTemplate: "$1\(redactedSuffix(for: key))"
            )
        }

        // 3. 脱敏值部分（key 之后的非空白字符，用于 key:value 无空格格式）
        result = sanitizeInlineCredentials(result)
        result = sanitizeDelimitedCredentials(result)

        // 4. 脱敏 Authorization 头部
        result = sanitizeAuthorizationHeader(result)

        // 5. 脱敏 JWT 令牌（保留头部和载荷的格式，隐藏签名）
        result = sanitizeJWT(result)

        // 6. 脱敏 URL 中嵌入的凭据
        result = sanitizeURLCredentials(result)

        // 7. 应用自定义规则（用户提供的模式可能不合法，静默跳过）
        for rule in customRules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { continue }
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result),
                withTemplate: rule.replacement
            )
        }

        return result
    }

    /// 添加自定义脱敏规则
    public func addingCustomRule(_ rule: CustomRule) -> CredentialSanitizer {
        CredentialSanitizer(strength: strength, customRules: customRules + [rule])
    }

    /// 添加多个自定义规则
    public func addingCustomRules(_ rules: [CustomRule]) -> CredentialSanitizer {
        CredentialSanitizer(strength: strength, customRules: customRules + rules)
    }

    /// 切换脱敏强度
    public func withStrength(_ strength: RedactionStrength) -> CredentialSanitizer {
        CredentialSanitizer(strength: strength, customRules: customRules)
    }

    // MARK: - Private Helpers

    /// 根据脱敏强度和模式生成替换后缀
    private func redactedSuffix(for key: String) -> String {
        switch strength {
        case .light:
            return "<redacted-\(key)>"
        case .medium:
            return "******"
        case .aggressive:
            return "<redacted>"
        }
    }

    /// 脱敏内联凭据（如 key=value 格式）
    private func sanitizeInlineCredentials(_ text: String) -> String {
        let patterns = [
            "(?i)(password|passwd|pwd|secret|token|api[_-]?key|api[_-]?secret|access[_-]?key|access[_-]?secret|client[_-]?secret|auth[_-]?token|session[_-]?token|refresh[_-]?token|endpoint[_-]?secret|private[_-]?key|ssh[_-]?key|bearer|jwt[_-]?secret)=(?!<)[^\\s&'\"]+",
            "(?i)\\bkey[_-]?=(?!<)[^\\s&'\"]+",
        ]
        var result = text
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1=\(redactedSuffix(for: "credential"))"
            )
        }
        return result
    }

    /// 脱敏 JSON/XML 等带分隔符和引号的凭据值。
    private func sanitizeDelimitedCredentials(_ text: String) -> String {
        let credentialKey = #"password|passwd|pwd|secret|token|api[_-]?key|apiKey|api[_-]?secret|access[_-]?key|access[_-]?secret|client[_-]?secret|clientSecret|auth[_-]?token|session[_-]?token|refresh[_-]?token|endpoint[_-]?secret|private[_-]?key|ssh[_-]?key|bearer|jwt[_-]?secret"#
        let patterns = [
            #"(?i)\b("# + credentialKey + #")\b(["']?)(\s*[:=]\s*)(")([^"]+?)(")"#,
            #"(?i)\b("# + credentialKey + #")\b(["']?)(\s*[:=]\s*)(')([^']+?)(')"#,
        ]
        var result = text
        let replacement = strength == .medium ? "<redacted>" : redactedSuffix(for: "credential")
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1$2$3$4\(replacement)$6"
            )
        }
        return result
    }

    /// 脱敏 Authorization 头部
    private func sanitizeAuthorizationHeader(_ text: String) -> String {
        let patterns = [
            "(?i)(Authorization:\\s*Bearer\\s+)\\S+",
            "(?i)(Authorization:\\s*Basic\\s+)\\S+",
            "(?i)(Authorization:\\s*Digest\\s+)\\S+",
            "(?i)(Authorization:\\s*)[^\\s]+",
            "(?i)(Proxy-Authorization:\\s*)\\S+",
            "(?i)(X-API-Key:\\s*)\\S+",
            "(?i)(X-Auth-Token:\\s*)\\S+",
        ]
        var result = text
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            result = regex.stringByReplacingMatches(
                in: result, range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1<redacted-credentials>"
            )
        }
        return result
    }

    /// 脱敏 JWT 令牌（保留头部，隐藏载荷和签名）
    private func sanitizeJWT(_ text: String) -> String {
        // JWT: header.payload.signature，各部分是 base64url
        guard let firstDot = text.firstIndex(of: "."),
              text[text.index(after: firstDot)...].contains(".") else {
            return text
        }

        let jwtPattern = #"(?<![A-Za-z0-9_-])[A-Za-z0-9_-]{1,4096}\.[A-Za-z0-9_-]{1,4096}\.[A-Za-z0-9_-]{1,4096}(?![A-Za-z0-9_-])"#
        guard let regex = try? NSRegularExpression(pattern: jwtPattern) else { return text }
        var result = text
        let range = NSRange(result.startIndex..., in: result)
        result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "<jwt-redacted>")
        return result
    }

    /// 脱敏 URL 中嵌入的凭据
    private func sanitizeURLCredentials(_ text: String) -> String {
        // https://user:password@host 或 http://user:pass@host
        let urlCredPattern = "(?<=://)[^:@/]+:[^@/]+@"
        guard let regex = try? NSRegularExpression(pattern: urlCredPattern) else { return text }
        var result = text
        let range = NSRange(result.startIndex..., in: result)
        result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "<user>:<password>@")
        return result
    }

    /// 脱敏 Base64 编码的凭据
    private func sanitizeBase64(_ text: String) -> String {
        // 较长的 base64 可能是凭据编码
        // 排除 JWT（已单独处理），只匹配 40 字符以上的纯 base64
        let b64Pattern = "(?<![A-Za-z0-9_.-])[A-Za-z0-9+/]{40,}={0,2}"
        guard let regex = try? NSRegularExpression(pattern: b64Pattern) else { return text }
        var result = text
        let range = NSRange(result.startIndex..., in: result)
        switch strength {
        case .light:
            // 保留长度指示
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "<base64:\(makeLengthPlaceholder())>")
        case .medium, .aggressive:
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "<redacted-base64>")
        }
        return result
    }

    private func makeLengthPlaceholder() -> String {
        "\(Int.random(in: 32...64))chars"
    }
}
