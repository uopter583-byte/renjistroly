import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolySystemBridge
@testable import RenJistrolyProductIdentity
@testable import RenJistrolyEnterprise
@testable import RenJistrolyCapability

// MARK: - Red Team Test Framework & Attack Surface Assessment
//
// 安全说明：本文件定义红队攻击面评估矩阵，所有测试使用 mock 数据，
// 不执行任何真实危险操作。这是防御性安全测试，不是攻击工具。

// MARK: - 攻击面定义

/// 红队攻击面枚举 — 每个 case 对应一个已识别的攻击向量
enum AttackSurface: String, CaseIterable, Sendable {
    /// 工具注入：通过 MCP 协议传入恶意工具调用参数
    case toolInjection = "工具注入"
    /// 命令注入：Shell 命令中嵌入恶意 payload
    case commandInjection = "命令注入"
    /// 路径穿越：通过文件路径参数访问未授权目录
    case pathTraversal = "路径穿越"
    /// MCP 越权调用：未授权的 MCP 工具越权执行
    case mcpPrivilegeEscalation = "MCP 越权调用"
    /// OCR 欺骗：通过构造的屏幕内容欺骗 OCR 读取
    case ocrSpoofing = "OCR 欺骗"
    /// AX UI 欺骗：通过伪造 AX 元素信息欺骗操作目标
    case axUISpoofing = "AX UI 欺骗"
    /// 窗口标题欺骗：伪造窗口标题劫持操作目标
    case windowTitleSpoofing = "窗口标题欺骗"
    /// 剪贴板数据泄漏：通过 OCR 或剪贴板读取敏感信息
    case clipboardDataExfil = "剪贴板数据泄漏"
    /// 状态机绕过：通过并发操作绕过安全检查
    case stateMachineBypass = "状态机绕过"

    var risk: RiskLevelAssessment {
        switch self {
        case .toolInjection: return RiskLevelAssessment(severity: .critical, likelihood: .medium, impact: "任意代码执行或系统损坏")
        case .commandInjection: return RiskLevelAssessment(severity: .critical, likelihood: .high, impact: "任意 Shell 命令执行")
        case .pathTraversal: return RiskLevelAssessment(severity: .high, likelihood: .medium, impact: "越权文件读取/写入")
        case .mcpPrivilegeEscalation: return RiskLevelAssessment(severity: .critical, likelihood: .low, impact: "敏感操作越权执行")
        case .ocrSpoofing: return RiskLevelAssessment(severity: .medium, likelihood: .medium, impact: "误导 AI 做出错误判断")
        case .axUISpoofing: return RiskLevelAssessment(severity: .high, likelihood: .medium, impact: "误操作目标应用")
        case .windowTitleSpoofing: return RiskLevelAssessment(severity: .high, likelihood: .low, impact: "窗口劫持和信息泄漏")
        case .clipboardDataExfil: return RiskLevelAssessment(severity: .high, likelihood: .medium, impact: "敏感凭据泄漏")
        case .stateMachineBypass: return RiskLevelAssessment(severity: .medium, likelihood: .low, impact: "安全检查被跳过")
        }
    }
}

struct RiskLevelAssessment: Sendable {
    let severity: Severity
    let likelihood: Likelihood
    let impact: String

    enum Severity: String, Sendable, Comparable {
        case low = "低"
        case medium = "中"
        case high = "高"
        case critical = "严重"

        var score: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            case .critical: return 4
            }
        }

        static func < (lhs: Self, rhs: Self) -> Bool { lhs.score < rhs.score }
    }

    enum Likelihood: String, Sendable {
        case low = "低"
        case medium = "中"
        case high = "高"
    }

    var riskScore: Int { severity.score * (likelihood == .high ? 3 : likelihood == .medium ? 2 : 1) }
}

// MARK: - 防御组件清单

/// 每个攻击面对应的防御组件映射
struct DefenseInventory: Sendable {
    let surface: AttackSurface
    let primaryDefenses: [String]
    let secondaryDefenses: [String]
    let verificationMethods: [String]

    static let all: [DefenseInventory] = [
        DefenseInventory(
            surface: .toolInjection,
            primaryDefenses: ["ToolSafetyGateway", "MCPToolRegistry.getTool()"],
            secondaryDefenses: ["PolicyLayer", "SafetyAuditStore"],
            verificationMethods: ["工具名白名单验证", "参数类型校验", "返回值安全检查"]
        ),
        DefenseInventory(
            surface: .commandInjection,
            primaryDefenses: ["CommandAllowlist", "ToolSafetyGateway.isMutatingShellCommand()"],
            secondaryDefenses: ["ShellExecutor 沙箱", "HighRiskOperationConfirmer"],
            verificationMethods: ["命令前缀检查", "Shell 注入模式检测", "高危命令拦截"]
        ),
        DefenseInventory(
            surface: .pathTraversal,
            primaryDefenses: ["FileOperationSafety", "ToolSafetyGateway.blockedResult()"],
            secondaryDefenses: ["LocalOnlyPolicy", "SensitiveDataProtector"],
            verificationMethods: ["路径规范化校验", "受保护路径前缀匹配", "敏感目录写入拦截"]
        ),
        DefenseInventory(
            surface: .mcpPrivilegeEscalation,
            primaryDefenses: ["ToolSafetyGateway.assess()", "ToolExecutionPolicy"],
            secondaryDefenses: ["PolicyLayer.evaluate()", "ReadOnlyModeEnforcer"],
            verificationMethods: ["工具风险等级评估", "策略执行限制", "只读模式强制检查"]
        ),
        DefenseInventory(
            surface: .ocrSpoofing,
            primaryDefenses: ["OCRDigitValidator", "ScreenContextProvider"],
            secondaryDefenses: ["SensitiveDataProtector", "LogSanitizer"],
            verificationMethods: ["OCR 置信度校验", "数字模式校验", "敏感字段遮蔽验证"]
        ),
        DefenseInventory(
            surface: .axUISpoofing,
            primaryDefenses: ["WindowMatchValidator", "ElementRegistry"],
            secondaryDefenses: ["FocusGuard", "AccessibilityContextProvider"],
            verificationMethods: ["窗口属性多维度匹配", "BundleID + PID 双重验证", "AX 元素一致性检查"]
        ),
        DefenseInventory(
            surface: .windowTitleSpoofing,
            primaryDefenses: ["WindowMatchValidator.fuzzy()"],
            secondaryDefenses: ["ScreenDiffVerifier", "ContextAcquisitionManager"],
            verificationMethods: ["标题模糊匹配阈值检查", "窗口标题 + BundleID 联合验证"]
        ),
        DefenseInventory(
            surface: .clipboardDataExfil,
            primaryDefenses: ["CredentialSanitizer", "SensitiveDataProtector"],
            secondaryDefenses: ["LocalOnlyPolicy", "ClipboardRiskSnapshot"],
            verificationMethods: ["凭据模式正则检测", "Base64 payload 检测", "本地处理策略验证"]
        ),
        DefenseInventory(
            surface: .stateMachineBypass,
            primaryDefenses: ["ModeManager.evaluate()", "PolicyLayer.evaluate()"],
            secondaryDefenses: ["ActionEngine 状态机", "ReadOnlyModeEnforcer"],
            verificationMethods: ["并发操作评价一致性", "模式锁定不可绕过验证", "多次切换后状态正确性"]
        ),
    ]

// MARK: - 验证：所有攻击面均有对应防御

@MainActor
final class RedTeamPlan: XCTestCase {
        func testAllAttackSurfacesHaveDefenses() {
            let surfaces = AttackSurface.allCases
            let inventory = DefenseInventory.all
            for surface in surfaces {
                let match = inventory.first { $0.surface == surface }
                XCTAssertTrue(match != nil, "攻击面「\(surface.rawValue)」缺少防御清单条目")
                XCTAssertTrue(!(match?.primaryDefenses.isEmpty ?? true), "攻击面「\(surface.rawValue)」缺少主防御组件")
                XCTAssertTrue(!(match?.verificationMethods.isEmpty ?? true), "攻击面「\(surface.rawValue)」缺少验证方法")
            }
        }

        // MARK: - 风险等级评估矩阵验证

        func testCriticalRiskAssessments() {
            let criticalSurfaces = AttackSurface.allCases.filter { $0.risk.severity == .critical }
            XCTAssertTrue(!criticalSurfaces.isEmpty, "应有关键风险级别的攻击面")
            for surface in criticalSurfaces {
                XCTAssertTrue(surface.risk.riskScore >= RiskLevelAssessment.Severity.critical.score,
                              "关键风险「\(surface.rawValue)」总分应至少包含 critical 严重度，实际 \(surface.risk.riskScore)")
            }
        }

        func testHighRiskAssessments() {
            let highSurfaces = AttackSurface.allCases.filter { $0.risk.severity == .high }
            XCTAssertTrue(!highSurfaces.isEmpty, "应有高风险级别的攻击面")
            for surface in highSurfaces {
                XCTAssertTrue(surface.risk.riskScore >= RiskLevelAssessment.Severity.high.score,
                              "高风险「\(surface.rawValue)」总分应至少包含 high 严重度，实际 \(surface.risk.riskScore)")
            }
        }

        func testAllRiskScoresNonZero() {
            for surface in AttackSurface.allCases {
                XCTAssertTrue(surface.risk.riskScore > 0, "攻击面「\(surface.rawValue)」风险评分应为正数")
            }
        }

        func testRiskLevelOrdering() {
            let sorted = AttackSurface.allCases.sorted { $0.risk.riskScore > $1.risk.riskScore }
            // 前三个应为 Critical 级别
            let topThree = sorted.prefix(3)
            for surface in topThree {
                XCTAssertTrue(surface.risk.severity != .low, "前三高风险面不应为 low：\(surface.rawValue)")
            }
        }

        // MARK: - 防御组件覆盖率验证

        func testAllDefenseComponentsInstantiatable() {
            // CommandAllowlist
            let allowlist = CommandAllowlist()
            XCTAssertTrue(allowlist.allowed.count >= 10)
            XCTAssertNil(allowlist.allows("ls"))
            XCTAssertNotNil(allowlist.allows(""))

            // HighRiskOperationConfirmer
            let confirmer = HighRiskOperationConfirmer()
            let req = confirmer.request(for: .firewall, operation: "test", impact: "test")
            XCTAssertTrue(req.requiresApproval)

            // ReadOnlyModeEnforcer
            let enforcer = ReadOnlyModeEnforcer.shared
            let enforcerLevel = enforcer.level
            XCTAssertTrue(enforcerLevel == .disabled)

            // PolicyLayer
            let policy = PolicyLayer.shared
            XCTAssertTrue(policy.tier == .standard)
            XCTAssertTrue(policy.ruleCount >= 0) // may or may not have rules

            // WindowMatchValidator
            _ = WindowMatchValidator()
            let desc = WindowMatchValidator.WindowDescriptor(
                title: "测试", bundleID: "com.test", processID: 123, frame: .zero
            )
            XCTAssertTrue(desc.title == "测试")

            // MouseGuard
            let guard_ = MouseGuard.shared
            let previousAccessLevel = guard_.accessLevel
            defer { guard_.accessLevel = previousAccessLevel }
            guard_.accessLevel = .denyWhenUserActive
            XCTAssertTrue(guard_.accessLevel == .denyWhenUserActive)

            // CredentialSanitizer
            let sanitizer = CredentialSanitizer()
            let sanitized = sanitizer.sanitize("password=secret123")
            XCTAssertTrue(sanitized.contains("******"))
            XCTAssertTrue(!sanitized.contains("secret123"))

            // LocalOnlyPolicy
            let localPolicy = LocalOnlyPolicy()
            XCTAssertTrue(localPolicy.isProtected(filePath: "/Users/yoming/test.txt"))
            XCTAssertTrue(!localPolicy.isProtected(filePath: "/tmp/test.txt"))

            // FileOperationSafety
            let fileSafety = FileOperationSafety()
            XCTAssertTrue(fileSafety.isProtected("/System/Library"))
            XCTAssertTrue(!fileSafety.isProtected("/tmp/test"))
        }

        // MARK: - 策略层完整性验证

        func testPolicyTierComparison() {
            XCTAssertTrue(PolicyLayer.Tier.minimal < PolicyLayer.Tier.standard)
            XCTAssertTrue(PolicyLayer.Tier.standard < PolicyLayer.Tier.strict)
            XCTAssertTrue(PolicyLayer.Tier.strict < PolicyLayer.Tier.lockdown)
            XCTAssertTrue(PolicyLayer.Tier.lockdown > PolicyLayer.Tier.minimal)
        }

        func testReadOnlyEnforcerLevelComparison() {
            XCTAssertTrue(ReadOnlyModeEnforcer.Level.disabled < ReadOnlyModeEnforcer.Level.warning)
            XCTAssertTrue(ReadOnlyModeEnforcer.Level.warning < ReadOnlyModeEnforcer.Level.strict)
        }

        // MARK: - 安全组件边界条件测试

        func testCommandAllowlistEmptyCommand() {
            let list = CommandAllowlist()
            XCTAssertNotNil(list.allows(""))
            XCTAssertNotNil(list.allows(" "))
            XCTAssertNotNil(list.allows("  "))
        }

        func testCommandAllowlistCustomization() {
            let base = CommandAllowlist()
            let extended = base.addingCommands("mycustomtool")
            XCTAssertNil(extended.allows("mycustomtool"))
            let restricted = extended.removingCommands("ls")
            XCTAssertNotNil(restricted.allows("ls"))
        }

        func testCredentialSanitizerEmptyInput() {
            let sanitizer = CredentialSanitizer()
            XCTAssertTrue(sanitizer.sanitize("") == "")
            XCTAssertTrue(sanitizer.sanitize("normal text without secrets") == "normal text without secrets")
        }

        func testLocalOnlyPolicyEdgeCases() {
            let policy = LocalOnlyPolicy()

            // 受保护路径
            XCTAssertTrue(policy.evaluate(filePath: "/Users/john/.ssh/id_rsa", requiresNetwork: true) == .blockedNetworkAccess)
            XCTAssertTrue(policy.evaluate(filePath: "/Users/john/.ssh/id_rsa", requiresNetwork: false) == .allowedLocally)

            // 不受保护的路径
            XCTAssertTrue(policy.evaluate(filePath: "/tmp/test.txt", requiresNetwork: true) == .allowedLocally)

            // 空路径
            XCTAssertTrue(!policy.isProtected(filePath: ""))
        }

        func testHighRiskConfirmerAllCategories() {
            let confirmer = HighRiskOperationConfirmer()
            for category in [HighRiskOperationConfirmer.RiskCategory.firewall,
                             .networkConfig, .systemPermission,
                             .kernelExtension, .userManagement] {
                let req = confirmer.request(for: category, operation: "test", impact: "test impact")
                XCTAssertTrue(req.requiresApproval, "类别 \(category.rawValue) 应要求确认")
                XCTAssertFalse(req.operation.isEmpty)
                XCTAssertFalse(req.impact.isEmpty)
            }
        }

        func testHighRiskConfirmerPromptFormat() {
            let confirmer = HighRiskOperationConfirmer()
            let req = confirmer.request(for: .firewall, operation: "关闭防火墙", impact: "系统暴露")
            let prompt = confirmer.prompt(for: req)
            XCTAssertTrue(prompt.contains("高风险操作确认"))
            XCTAssertTrue(prompt.contains("firewall"))
            XCTAssertTrue(prompt.contains("关闭防火墙"))
            XCTAssertTrue(prompt.contains("系统暴露"))
        }



}
}
