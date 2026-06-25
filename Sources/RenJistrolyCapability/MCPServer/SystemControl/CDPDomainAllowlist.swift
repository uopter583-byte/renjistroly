import Foundation
import RenJistrolySystemBridge

/// Domain allowlist guard for CDP operations.
/// Prevents arbitrary JS execution or cookie access on untrusted domains.
public enum CDPDomainAllowlist {

    /// Default allowed hosts (local/development only).
    public static let defaultAllowedHosts: Set<String> = [
        "localhost",
        "127.0.0.1",
        "::1",
    ]

    /// Check if a host is in the allowlist.
    public static func isAllowed(host: String) -> Bool {
        let lower = host.lowercased()
        // Exact match on local addresses
        if defaultAllowedHosts.contains(lower) { return true }
        // *.local domains (Bonjour/mDNS)
        if lower.hasSuffix(".local") { return true }
        return false
    }

    /// Check if a URL string's host is in the allowlist.
    public static func isAllowed(urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              let host = url.host(percentEncoded: false) else {
            return false
        }
        return isAllowed(host: host)
    }

    /// Check if the current CDP session's page is on an allowed domain.
    /// Throws CDPDomainError if the domain is not allowlisted.
    public static func guardDomainAllowed(session: ChromeDevToolsSession) async throws {
        let urlString: String
        do {
            urlString = try await session.getCurrentURL()
        } catch {
            throw CDPDomainError.couldNotGetURL(underlying: error.localizedDescription)
        }
        guard isAllowed(urlString: urlString) else {
            let host = URL(string: urlString)?.host(percentEncoded: false) ?? urlString
            throw CDPDomainError.domainNotAllowed(currentHost: host, url: urlString)
        }
    }
}

/// Errors thrown by CDPDomainAllowlist.
public enum CDPDomainError: LocalizedError {
    case couldNotGetURL(underlying: String)
    case domainNotAllowed(currentHost: String, url: String)

    public var errorDescription: String? {
        switch self {
        case .couldNotGetURL(let underlying):
            return "⚠️ CDP 安全限制：无法获取当前页面 URL (\(underlying))"
        case .domainNotAllowed(let host, let url):
            return """
            ⚠️ CDP 安全限制：当前页面域名「\(host)」不在安全允许列表中。
            当前页面 URL: \(url)

            CDP JavaScript 评估 / Cookie 操作仅允许在以下域名上执行：
              - localhost
              - 127.0.0.1
              - *.local 域名

            请先在允许的域名上打开页面，或使用 cdp_navigate 导航到允许的域名后重试。
            """
        }
    }
}
