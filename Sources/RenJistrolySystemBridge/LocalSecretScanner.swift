import Foundation

/// 本地密钥扫描 — 在文件中检测密钥/令牌泄露
public struct LocalSecretScanner: Sendable {
    public struct SecretMatch: Sendable {
        public let filePath: String
        public let lineNumber: Int
        public let matchedPattern: String
        public let context: String
    }

    /// 常见密钥模式
    public static let commonPatterns: [String] = [
        "(?i)api[_-]?key\\s*[:=]\\s*['\"]?[A-Za-z0-9_\\-]{16,}",
        "(?i)secret\\s*[:=]\\s*['\"]?[A-Za-z0-9_\\-]{8,}",
        "(?i)token\\s*[:=]\\s*['\"]?[A-Za-z0-9_\\-]{8,}",
        "(?i)password\\s*[:=]\\s*['\"]?[^'\"]{4,}",
        "AKIA[0-9A-Z]{16}",              // AWS Access Key
        "sk-[A-Za-z0-9]{32,}",            // OpenAI key
        "ghp_[A-Za-z0-9]{36}",            // GitHub PAT
    ]

    /// 扫描文件内容中的密钥
    public func scan(content: String, filePath: String) -> [SecretMatch] {
        var results: [SecretMatch] = []
        let lines = content.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            for pattern in Self.commonPatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, range: range) != nil {
                    results.append(SecretMatch(
                        filePath: filePath,
                        lineNumber: index + 1,
                        matchedPattern: pattern,
                        context: String(line.prefix(80))
                    ))
                    break
                }
            }
        }
        return results
    }
}
