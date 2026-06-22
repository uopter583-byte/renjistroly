import Foundation
import Network

/// 受保护路径的精细定义
public struct ProtectedPath: Sendable {
    public let path: String
    public let label: String
    public let allowRead: Bool
    public let allowSubprocess: Bool

    public init(path: String, label: String = "", allowRead: Bool = true, allowSubprocess: Bool = false) {
        self.path = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        self.label = label.isEmpty ? path : label
        self.allowRead = allowRead
        self.allowSubprocess = allowSubprocess
    }
}

/// 本地处理策略 — 确保机密文件不离开本机，并支持细粒度的执行控制
public struct LocalOnlyPolicy: Sendable {
    public enum AccessDecision: String, Sendable {
        case allowedLocally
        case blockedNetworkAccess
        case requiresUserOverride
        case needsLocalOnly
    }

    /// 受保护的路径（精细定义）
    public let protectedPaths: [ProtectedPath]

    /// 网络监控器（可选，用于子进程网络检测）
    private let networkMonitor: NWPathMonitor?

    public init(protectedPaths: [ProtectedPath] = defaultProtectedPaths) {
        self.protectedPaths = protectedPaths
        self.networkMonitor = nil
    }

    /// 默认受保护路径
    public static let defaultProtectedPaths: [ProtectedPath] = [
        ProtectedPath(path: NSHomeDirectory() + "/.ssh", label: "SSH 密钥目录", allowRead: false, allowSubprocess: false),
        ProtectedPath(path: NSHomeDirectory() + "/.gnupg", label: "GPG 密钥目录", allowRead: false, allowSubprocess: false),
        ProtectedPath(path: NSHomeDirectory() + "/.aws", label: "AWS 配置", allowRead: false, allowSubprocess: false),
        ProtectedPath(path: NSHomeDirectory() + "/.kube", label: "K8s 配置", allowRead: false, allowSubprocess: false),
        ProtectedPath(path: NSHomeDirectory() + "/Library/Keychains", label: "系统钥匙串", allowRead: false, allowSubprocess: false),
        ProtectedPath(path: "/Users/", label: "用户目录", allowRead: true, allowSubprocess: false),
        ProtectedPath(path: "/private/", label: "系统私有目录", allowRead: false, allowSubprocess: false),
        ProtectedPath(path: "/etc/", label: "系统配置目录", allowRead: true, allowSubprocess: false),
    ]

    private func normalizedPath(_ filePath: String) -> String? {
        let trimmed = filePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: trimmed).resolvingSymlinksInPath().path
    }

    private func matches(_ normalized: String, protectedPath: String) -> Bool {
        guard normalized == protectedPath || normalized.hasPrefix(protectedPath) else { return false }
        if normalized.count == protectedPath.count { return true }
        if protectedPath.hasSuffix("/") { return true }
        let next = normalized[normalized.index(normalized.startIndex, offsetBy: protectedPath.count)]
        return next == "/"
    }

    private func matchingProtectedPath(for filePath: String) -> ProtectedPath? {
        guard let normalized = normalizedPath(filePath) else { return nil }
        return protectedPaths
            .filter { matches(normalized, protectedPath: $0.path) }
            .max { $0.path.count < $1.path.count }
    }

    /// 检查文件是否受本地-only 保护
    public func isProtected(filePath: String) -> Bool {
        matchingProtectedPath(for: filePath) != nil
    }

    /// 检查文件是否允许被读取
    public func isReadAllowed(filePath: String) -> Bool {
        matchingProtectedPath(for: filePath)?.allowRead ?? true
    }

    /// 检查路径是否允许被子进程访问
    public func allowsSubprocess(atPath filePath: String) -> Bool {
        matchingProtectedPath(for: filePath)?.allowSubprocess ?? true
    }

    /// 评估对文件的访问请求
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - requiresNetwork: 操作是否需要网络访问
    ///   - isSubprocess: 是否通过子进程访问
    /// - Returns: 访问决策
    public func evaluate(filePath: String, requiresNetwork: Bool, isSubprocess: Bool = false) -> AccessDecision {
        guard let normalized = normalizedPath(filePath),
              matchingProtectedPath(for: normalized) != nil
        else { return .allowedLocally }

        // 子进程访问检查
        if isSubprocess && !allowsSubprocess(atPath: normalized) {
            return .blockedNetworkAccess
        }

        // 网络访问检查
        if requiresNetwork {
            return .blockedNetworkAccess
        }

        // 只读路径检查
        if !isReadAllowed(filePath: normalized) {
            return .requiresUserOverride
        }

        return .allowedLocally
    }

    /// 强制检查并阻止网络操作（执行层面调用）
    /// - Returns: 如果操作被阻止，返回错误原因；nil 表示允许
    public func enforce(filePath: String, requiresNetwork: Bool, isSubprocess: Bool = false) -> String? {
        let decision = evaluate(filePath: filePath, requiresNetwork: requiresNetwork, isSubprocess: isSubprocess)
        switch decision {
        case .allowedLocally:
            return nil
        case .blockedNetworkAccess:
            if isSubprocess {
                return "「\(filePath)」为受保护路径，禁止通过子进程进行网络访问"
            }
            return "「\(filePath)」为本地敏感文件，禁止通过网络发送"
        case .requiresUserOverride:
            return "「\(filePath)」需要用户手动确认才能访问"
        case .needsLocalOnly:
            return "「\(filePath)」必须在本机处理"
        }
    }

    /// 同进程 vs 子进程网络检查
    /// - Returns: true 表示可以安全执行（同进程本地操作），false 表示可能泄漏
    public func allowsLocalProcessing(filePath: String, accessType: AccessType) -> Bool {
        guard let normalized = normalizedPath(filePath),
              matchingProtectedPath(for: normalized) != nil
        else { return true }

        switch accessType {
        case .inMemoryRead:
            return isReadAllowed(filePath: normalized)
        case .subprocessExecution:
            return allowsSubprocess(atPath: normalized)
        case .networkTransfer:
            return false // 受保护文件禁止网络传输
        case .localFileWrite:
            return true // 允许本地写入
        }
    }

    /// 返回处理说明
    public var policyDescription: String {
        let entries = protectedPaths.map { pp in
            let restrictions = [
                pp.allowRead ? nil : "只读",
                pp.allowSubprocess ? nil : "禁止子进程",
            ].compactMap { $0 }
            let restrictionStr = restrictions.isEmpty ? "" : "（\(restrictions.joined(separator: "、"))）"
            return "  - \(pp.label): \(pp.path)\(restrictionStr)"
        }.joined(separator: "\n")
        return """
        本地处理策略：敏感文件仅在本机处理，不会通过网络发送。
        受保护路径：
        \(entries)
        """
    }
}

/// 访问类型
public enum AccessType: String, Sendable {
    /// 同进程内存读取
    case inMemoryRead
    /// 子进程执行
    case subprocessExecution
    /// 网络传输
    case networkTransfer
    /// 本地文件写入
    case localFileWrite
}
