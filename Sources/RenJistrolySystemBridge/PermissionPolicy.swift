import Foundation

/// 权限策略 — 安装软件需要管理员权限策略
public struct PermissionPolicy: Sendable {
    public enum Access: String, Sendable {
        case allowed, requiresAdmin, blocked
    }

    public struct Rule: Sendable {
        public let pattern: String
        public let access: Access
    }

    /// 访问规则列表
    public let rules: [Rule]

    public init(rules: [Rule] = defaultRules) {
        self.rules = rules
    }

    public static let defaultRules: [Rule] = [
        Rule(pattern: "*.pkg", access: .requiresAdmin),
        Rule(pattern: "*.dmg", access: .requiresAdmin),
        Rule(pattern: "*.app", access: .requiresAdmin),
        Rule(pattern: "*.sh", access: .allowed),
        Rule(pattern: "*.command", access: .allowed),
    ]

    /// 评估安装路径的访问权限
    public func evaluate(installPath: String) -> Access {
        for rule in rules {
            let ext = "*." + (installPath as NSString).pathExtension
            if rule.pattern == ext {
                return rule.access
            }
        }
        return .allowed
    }
}
