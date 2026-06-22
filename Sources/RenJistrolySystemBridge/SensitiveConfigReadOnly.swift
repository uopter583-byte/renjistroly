import Foundation

/// 敏感配置只读 — 防止误改 SSO 等关键配置
public struct SensitiveConfigReadOnly: Sendable {
    public enum AccessMode: String, Sendable {
        case readOnly, readWrite
    }

    /// 敏感配置路径前缀
    public let sensitivePaths: [String]

    public init(sensitivePaths: [String] = [
        "/etc/ssh", "/etc/pam.d", "/etc/krb5",
        "/Library/Preferences/SystemConfiguration",
        "/var/db/dslocal",
    ]) {
        self.sensitivePaths = sensitivePaths
    }

    /// 检查路径是否为敏感配置
    public func isSensitive(_ path: String) -> Bool {
        sensitivePaths.contains { path.hasPrefix($0) }
    }

    /// 获取对路径的访问模式
    public func accessMode(for path: String) -> AccessMode {
        isSensitive(path) ? .readOnly : .readWrite
    }

    /// 尝试写入敏感配置时返回错误信息
    public func validateWrite(path: String) -> String? {
        guard isSensitive(path) else { return nil }
        return "「\(path)」为敏感配置，当前为只读模式，禁止修改"
    }
}
