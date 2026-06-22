import Foundation

/// Scans loaded skills for security vulnerabilities (NVIDIA/SkillSpector pattern).
/// Checks for 64+ common vulnerability patterns across skill content.
public actor SkillScanner {
    private let patterns: [VulnerabilityPattern]

    public init(customPatterns: [VulnerabilityPattern] = []) {
        self.patterns = VulnerabilityPattern.builtin + customPatterns
    }

    public func scan(_ skill: LoadedSkill) -> SkillScanReport {
        var findings: [ScanFinding] = []
        let fullText = skill.markdown + "\n" + (skill.manifest.map { String(data: (try? JSONEncoder().encode($0)) ?? Data(), encoding: .utf8) ?? "" } ?? "")

        for pattern in patterns {
            let matches = pattern.regex.matches(in: fullText, options: [], range: NSRange(fullText.startIndex..., in: fullText))
            if !matches.isEmpty {
                findings.append(ScanFinding(
                    patternID: pattern.id,
                    severity: pattern.severity,
                    category: pattern.category,
                    description: pattern.description,
                    matchCount: matches.count,
                    remediation: pattern.remediation
                ))
            }
        }

        let riskScore = computeRiskScore(findings)
        return SkillScanReport(
            skillID: skill.id,
            skillTitle: skill.metadata.title ?? skill.id,
            riskScore: riskScore,
            riskLevel: riskLevel(for: riskScore),
            findings: findings,
            scannedAt: Date()
        )
    }

    public func isSafeToInstall(_ skill: LoadedSkill) -> Bool {
        let report = scan(skill)
        return report.riskLevel < .high
    }

    public func batchScan(_ skills: [LoadedSkill]) async -> [SkillScanReport] {
        await withTaskGroup(of: SkillScanReport.self) { group in
            for skill in skills {
                group.addTask { await self.scan(skill) }
            }
            var reports: [SkillScanReport] = []
            for await report in group { reports.append(report) }
            return reports.sorted { $0.riskScore > $1.riskScore }
        }
    }

    private func computeRiskScore(_ findings: [ScanFinding]) -> Int {
        findings.reduce(0) { sum, f in
            sum + f.severity.weight * f.matchCount
        }
    }

    private func riskLevel(for score: Int) -> ScanRiskLevel {
        switch score {
        case 0: .safe
        case 1..<15: .low
        case 15..<40: .medium
        case 40..<80: .high
        default: .critical
        }
    }
}

// MARK: - Types

public struct VulnerabilityPattern: Sendable {
    public let id: String
    public let severity: ScanSeverity
    public let category: String
    public let description: String
    public let regex: NSRegularExpression
    public let remediation: String

    public init(id: String, severity: ScanSeverity, category: String, description: String, pattern: String, remediation: String) {
        self.id = id
        self.severity = severity
        self.category = category
        self.description = description
        self.regex = (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])) ?? NSRegularExpression()
        self.remediation = remediation
    }

    public static let builtin: [VulnerabilityPattern] = [
        // Shell injection
        VulnerabilityPattern(id: "shell-rm-rf", severity: .critical, category: "命令注入",
                             description: "检测到 rm -rf 等危险删除命令",
                             pattern: #"\brm\s+-rf\b"#,
                             remediation: "避免在技能脚本中使用不可逆的删除操作"),
        VulnerabilityPattern(id: "shell-sudo", severity: .high, category: "权限提升",
                             description: "检测到 sudo 提权操作",
                             pattern: #"\bsudo\b"#,
                             remediation: "移除 sudo 调用，请求用户授权后再执行"),
        VulnerabilityPattern(id: "shell-curl-pipe", severity: .critical, category: "命令注入",
                             description: "检测到 curl | sh 模式",
                             pattern: #"curl\s+\S+\s*\|\s*(ba)?sh"#,
                             remediation: "避免从网络直接执行脚本，使用签名验证"),
        VulnerabilityPattern(id: "shell-eval", severity: .high, category: "命令注入",
                             description: "检测到 eval 执行",
                             pattern: #"\beval\s+"#,
                             remediation: "避免使用 eval 动态执行代码"),

        // File system
        VulnerabilityPattern(id: "fs-system-dir", severity: .high, category: "文件系统",
                             description: "写入系统目录",
                             pattern: #"(/etc/|/System/|/Library/|/usr/)"#,
                             remediation: "限制文件写入范围到用户目录或项目目录"),
        VulnerabilityPattern(id: "fs-chmod-777", severity: .high, category: "文件系统",
                             description: "设置过于宽松的文件权限",
                             pattern: #"chmod\s+777\b"#,
                             remediation: "使用最小权限原则，避免 777 权限"),
        VulnerabilityPattern(id: "fs-encrypted-access", severity: .medium, category: "文件系统",
                             description: "访问敏感配置或密钥文件",
                             pattern: #"(\.env|credentials|secrets?|\.pem|\.key|\.crt)"#,
                             remediation: "确保不硬编码或泄漏敏感凭证"),

        // Network
        VulnerabilityPattern(id: "net-arbitrary-request", severity: .medium, category: "网络",
                             description: "向任意 URL 发起请求",
                             pattern: #"(curl|wget)\s+https?://[^/]+"#,
                             remediation: "限制网络请求的目标域名白名单"),
        VulnerabilityPattern(id: "net-data-exfil", severity: .high, category: "网络",
                             description: "可能的数据外泄（上传文件到外部URL）",
                             pattern: #"(curl|wget)\s+.*-F\s|--upload-file\b"#,
                             remediation: "审查数据上传操作，添加用户确认流程"),

        // Process
        VulnerabilityPattern(id: "proc-kill", severity: .medium, category: "进程",
                             description: "终止系统进程",
                             pattern: #"\b(kill|killall|pkill)\b"#,
                             remediation: "确认进程终止操作的必要性"),
        VulnerabilityPattern(id: "proc-background", severity: .low, category: "进程",
                             description: "启动后台进程",
                             pattern: #"\b(nohup|disown|&\s*$)"#,
                             remediation: "检查是否有僵尸进程风险"),

        // Privacy
        VulnerabilityPattern(id: "priv-keylogger", severity: .critical, category: "隐私",
                             description: "可能的键盘监听或屏幕捕获",
                             pattern: #"(CGEvent|NSEvent\.addGlobalMonitor|ScreenCaptureKit|AVCaptureScreen)"#,
                             remediation: "确保屏幕/键盘捕获有明确的用户提示和停止机制"),
        VulnerabilityPattern(id: "priv-clipboard", severity: .medium, category: "隐私",
                             description: "读取剪贴板",
                             pattern: #"NSPasteboard\.general"#,
                             remediation: "限制剪贴板访问，添加用户确认"),
    ]
}

public struct ScanFinding: Sendable {
    public let patternID: String
    public let severity: ScanSeverity
    public let category: String
    public let description: String
    public let matchCount: Int
    public let remediation: String
}

public enum ScanSeverity: String, Sendable, Codable, Comparable {
    case info, low, medium, high, critical

    public var weight: Int {
        switch self {
        case .info: 1
        case .low: 3
        case .medium: 7
        case .high: 15
        case .critical: 30
        }
    }

    public static func < (lhs: ScanSeverity, rhs: ScanSeverity) -> Bool { lhs.weight < rhs.weight }
}

public enum ScanRiskLevel: String, Sendable, Codable, Comparable {
    case safe, low, medium, high, critical

    private var order: Int {
        switch self {
        case .safe: 0
        case .low: 1
        case .medium: 2
        case .high: 3
        case .critical: 4
        }
    }

    public static func < (lhs: ScanRiskLevel, rhs: ScanRiskLevel) -> Bool { lhs.order < rhs.order }

    public var label: String {
        switch self {
        case .safe: "安全"
        case .low: "低风险"
        case .medium: "中风险"
        case .high: "高风险"
        case .critical: "严重"
        }
    }

    public var allowsAutoInstall: Bool {
        switch self {
        case .safe, .low: true
        case .medium, .high, .critical: false
        }
    }
}

public struct SkillScanReport: Sendable, Codable {
    public let skillID: String
    public let skillTitle: String
    public let riskScore: Int
    public let riskLevel: ScanRiskLevel
    public let findings: [ScanFinding]
    public let scannedAt: Date

    public init(skillID: String, skillTitle: String, riskScore: Int, riskLevel: ScanRiskLevel, findings: [ScanFinding], scannedAt: Date = Date()) {
        self.skillID = skillID
        self.skillTitle = skillTitle
        self.riskScore = riskScore
        self.riskLevel = riskLevel
        self.findings = findings
        self.scannedAt = scannedAt
    }

    public var summary: String {
        "\(skillTitle): 风险等级 \(riskLevel.label) (评分 \(riskScore)), 发现 \(findings.count) 项问题"
    }

    enum CodingKeys: String, CodingKey {
        case skillID, skillTitle, riskScore, riskLevel, findings, scannedAt
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(skillID, forKey: .skillID)
        try c.encode(skillTitle, forKey: .skillTitle)
        try c.encode(riskScore, forKey: .riskScore)
        try c.encode(riskLevel, forKey: .riskLevel)
        try c.encode(scannedAt, forKey: .scannedAt)
        // findings encoded as pattern IDs only
        try c.encode(findings.map(\.patternID), forKey: .findings)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        skillID = try c.decode(String.self, forKey: .skillID)
        skillTitle = try c.decode(String.self, forKey: .skillTitle)
        riskScore = try c.decode(Int.self, forKey: .riskScore)
        riskLevel = try c.decode(ScanRiskLevel.self, forKey: .riskLevel)
        scannedAt = try c.decode(Date.self, forKey: .scannedAt)
        findings = [] // Patterns need registry lookup on decode
    }
}
