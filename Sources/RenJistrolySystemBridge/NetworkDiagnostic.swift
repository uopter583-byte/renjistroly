import Foundation

/// 网络诊断 — 区分 DNS/VPN/代理问题
public struct NetworkDiagnostic: Sendable {
    public enum IssueType: String, Sendable {
        case dns, vpn, proxy, connectivity, unknown
    }

    public struct DiagnosticResult: Sendable {
        public let issueType: IssueType
        public let details: String
        public let suggestions: [String]
    }

    /// 分析连通性测试结果
    public func diagnose(pingOutput: String?, dnsLookup: String?, proxySettings: [String: String]?) -> DiagnosticResult {
        // 检查 DNS
        if let dns = dnsLookup, dns.contains("connection refused") || dns.contains("failure") {
            return DiagnosticResult(
                issueType: .dns,
                details: "DNS 解析失败，无法将域名转换为 IP 地址",
                suggestions: [
                    "检查 /etc/resolv.conf 配置",
                    "尝试 nslookup 使用 8.8.8.8 进行外部 DNS 查询",
                    "检查是否有 VPN 覆盖了 DNS 设置",
                ]
            )
        }

        // 检查代理
        if let proxy = proxySettings, proxy["HTTPProxy"] != nil || proxy["HTTPSProxy"] != nil {
            return DiagnosticResult(
                issueType: .proxy,
                details: "检测到代理配置，可能存在代理连通性问题",
                suggestions: [
                    "检查代理服务器是否在线",
                    "尝试临时关闭代理测试连通性",
                    "验证代理凭据是否正确",
                ]
            )
        }

        // 检查 VPN
        if let scutil = Self.shell("scutil --nc list"),
           scutil.contains("Connected") {
            return DiagnosticResult(
                issueType: .vpn,
                details: "VPN 已连接，路由可能受影响",
                suggestions: [
                    "检查 VPN 是否影响目标地址的路由",
                    "尝试断开 VPN 后测试",
                    "检查 VPN 分流配置",
                ]
            )
        }

        // 通用连通性问题
        if let ping = pingOutput, ping.contains("timeout") || ping.contains("100.0% packet loss") {
            return DiagnosticResult(
                issueType: .connectivity,
                details: "无法到达目标主机",
                suggestions: [
                    "检查网络物理连接",
                    "检查防火墙规则",
                    "验证目标地址是否可达",
                ]
            )
        }

        return DiagnosticResult(
            issueType: .unknown,
            details: "未检测到明显问题",
            suggestions: ["尝试重启网络服务", "检查系统日志获取更多信息"]
        )
    }

    private static func shell(_ cmd: String) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", cmd]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
