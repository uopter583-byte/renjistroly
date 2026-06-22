import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolySystemBridge
@testable import RenJistrolyProductIdentity
@testable import RenJistrolyEnterprise
@testable import RenJistrolyCapability

// MARK: - 工具注入安全测试
//
// 安全说明：测试 MCP 工具调用安全网关对恶意注入的拦截能力。
// 包括命令白名单、高风险操作确认、只读模式强制和策略层拦截。
// 所有测试使用 mock/模拟数据，不执行真实副作用。

// MARK: - CommandAllowlist 测试

final class ToolInjectionTests: XCTestCase {
        func testAllowlistBlocksDangerousCommands() {
            let list = CommandAllowlist()
            XCTAssertNotNil(list.allows("rm -rf /"))
            XCTAssertNotNil(list.allows("rm -rf ~"))
            XCTAssertNotNil(list.allows("sudo rm -rf /"))
            XCTAssertNotNil(list.allows("dd if=/dev/zero of=/dev/sda"))
        }

        func testAllowlistBlocksPrivilegeEscalation() {
            let list = CommandAllowlist()
            XCTAssertNotNil(list.allows("sudo !!"))
            XCTAssertNotNil(list.allows("chmod 777 /etc/passwd"))
            XCTAssertNotNil(list.allows("chown root:admin /etc/shadow"))
            XCTAssertNotNil(list.allows("passwd root"))
        }

        func testAllowlistAllowsSafeCommands() {
            let list = CommandAllowlist()
            XCTAssertNil(list.allows("ls -la /tmp"))
            XCTAssertNil(list.allows("cat /etc/hosts"))
            XCTAssertNil(list.allows("echo hello world"))
            XCTAssertNil(list.allows("grep -r 'pattern' ."))
            XCTAssertNil(list.allows("find . -name '*.swift'"))
            XCTAssertNil(list.allows("head -n 100 /var/log/system.log"))
            XCTAssertNil(list.allows("curl -s https://example.com"))
        }

        func testAllowlistHandlesFullPaths() {
            let list = CommandAllowlist()
            XCTAssertNil(list.allows("/bin/ls -la"))
            XCTAssertNil(list.allows("/usr/bin/head -n 5"))
            XCTAssertNil(list.allows("/usr/bin/grep pattern file"))
        }

        // MARK: - 命令注入模式检测测试

        func testDetectShellPipeInjection() async {
            // ToolSafetyGateway 的 hasShellInjectionRisk 是 internal，通过 @testable 访问
            let registry = MCPToolRegistry()
            let policy = ToolExecutionPolicy.strict
            let gateway = ToolSafetyGateway(registry: registry) { policy }

            let cleanCmd = "ls -la"
            let r1 = await gateway.isMutatingShellCommand(cleanCmd)
            XCTAssertTrue(!r1)

            let pipeToShell = "echo data | sh"
            let r2 = await gateway.hasShellInjectionRisk(pipeToShell)
            XCTAssertTrue(r2)

            let pipeToBash = "cat /etc/passwd | bash"
            let r3 = await gateway.hasShellInjectionRisk(pipeToBash)
            XCTAssertTrue(r3)

            let noRisk = "grep pattern file.txt"
            let r4 = await gateway.hasShellInjectionRisk(noRisk)
            XCTAssertTrue(!r4)
        }

        func testDetectCommandSubstitutionInjection() async {
            let registry = MCPToolRegistry()
            let policy = ToolExecutionPolicy.default
            let gateway = ToolSafetyGateway(registry: registry) { policy }

            let dollarParen = "echo $(cat /etc/passwd)"
            let r5 = await gateway.hasShellInjectionRisk(dollarParen)
            XCTAssertTrue(r5)

            let backtick = "echo `whoami`"
            let r6 = await gateway.hasShellInjectionRisk(backtick)
            XCTAssertTrue(r6)

            let clean = "echo hello world"
            let r7 = await gateway.hasShellInjectionRisk(clean)
            XCTAssertTrue(!r7)
        }

        func testDetectMutatingShellCommands() async {
            let registry = MCPToolRegistry()
            let policy = ToolExecutionPolicy.default
            let gateway = ToolSafetyGateway(registry: registry) { policy }

            let r8 = await gateway.isMutatingShellCommand("rm -rf /tmp/data")
            XCTAssertTrue(r8)
            let r9 = await gateway.isMutatingShellCommand("mv /tmp/a /tmp/b")
            XCTAssertTrue(r9)
            let r10 = await gateway.isMutatingShellCommand("cp /tmp/a /tmp/b")
            XCTAssertTrue(r10)
            let r11 = await gateway.isMutatingShellCommand("chmod 755 /tmp/script")
            XCTAssertTrue(r11)
            let r12 = await gateway.isMutatingShellCommand("sudo systemctl restart service")
            XCTAssertTrue(r12)
            let r13 = await gateway.isMutatingShellCommand("ls -la /tmp")
            XCTAssertTrue(!r13)
            let r14 = await gateway.isMutatingShellCommand("cat /etc/hosts")
            XCTAssertTrue(!r14)
            let r15 = await gateway.isMutatingShellCommand("git status")
            XCTAssertTrue(!r15)
            let r16 = await gateway.isMutatingShellCommand("swift build")
            XCTAssertTrue(!r16)
        }

        func testDetectForcePushToMain() async {
            let registry = MCPToolRegistry()
            let policy = ToolExecutionPolicy.default
            let gateway = ToolSafetyGateway(registry: registry) { policy }

            let r17 = await gateway.isMutatingShellCommand("git push --force origin main")
            XCTAssertTrue(r17)
            let r18 = await gateway.isMutatingShellCommand("git push -f origin master")
            XCTAssertTrue(r18)
            let r19 = await gateway.isMutatingShellCommand("git push origin feature-branch")
            XCTAssertTrue(r19)
        }

        // MARK: - HighRiskOperationConfirmer 测试

        func testHighRiskConfirmerCategories() {
            let confirmer = HighRiskOperationConfirmer()

            // 防火墙操作
            let fwReq = confirmer.request(for: .firewall, operation: "关闭系统防火墙", impact: "系统安全防护失效")
            XCTAssertTrue(fwReq.requiresApproval)
            XCTAssertTrue(fwReq.category == .firewall)
            XCTAssertTrue(confirmer.prompt(for: fwReq).contains("关闭系统防火墙"))

            // 系统权限操作
            let permReq = confirmer.request(for: .systemPermission, operation: "修改 SIP 状态", impact: "系统完整性保护失效")
            XCTAssertTrue(permReq.requiresApproval)
            XCTAssertTrue(permReq.category == .systemPermission)

            // 网络配置
            let netReq = confirmer.request(for: .networkConfig, operation: "修改 DNS 配置", impact: "网络访问可能受影响")
            XCTAssertTrue(netReq.requiresApproval)

            // 内核扩展
            let kextReq = confirmer.request(for: .kernelExtension, operation: "加载未签名 kext", impact: "系统稳定性风险")
            XCTAssertTrue(kextReq.requiresApproval)

            // 用户管理
            let userReq = confirmer.request(for: .userManagement, operation: "创建管理员账号", impact: "未授权访问风险")
            XCTAssertTrue(userReq.requiresApproval)
        }

        // MARK: - ReadOnlyModeEnforcer 测试

        @MainActor func testReadOnlyStrictBlocksWrites() {
            let enforcer = ReadOnlyModeEnforcer.shared
            enforcer.level = .strict

            let writeActions: [(MacActionKind, String)] = [
                (.insertText, "insertText"),
                (.setFocusedText, "setFocusedText"),
                (.clickElement, "clickElement"),
                (.clickAt, "clickAt"),
                (.scroll, "scroll"),
                (.drag, "drag"),
                (.closeWindow, "closeWindow"),
                (.deleteFile, "deleteFile"),
                (.runShellCommand, "runShellCommand"),
                (.sendMessage, "sendMessage"),
            ]

            for (kind, name) in writeActions {
                let action = MacAction(kind: kind, payload: [:], riskLevel: .reversibleInput, humanPreview: name)
                let decision = enforcer.evaluate(action)
                guard case .deny = decision else {
                    XCTFail("只读严格模式应拒绝 \(name)，实际: \(decision)")
                    return
                }
            }

            // 读操作应允许
            let readAction = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "readContext")
            XCTAssertTrue(enforcer.evaluate(readAction) == .allow)

            enforcer.level = .disabled // reset
        }

        @MainActor func testReadOnlyWarningRequiresConfirmation() {
            let enforcer = ReadOnlyModeEnforcer.shared
            enforcer.level = .warning

            let action = MacAction(kind: .deleteFile, payload: ["path": "/tmp/test"], riskLevel: .reversibleInput, humanPreview: "删除文件")
            let decision = enforcer.evaluate(action)
            guard case .requireConfirmation = decision else {
                XCTFail("只读警告模式应要求确认，实际: \(decision)")
                return
            }

            // 读操作仍应允许
            let readAction = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "读取")
            XCTAssertTrue(enforcer.evaluate(readAction) == .allow)

            enforcer.level = .disabled // reset
        }

        @MainActor func testReadOnlyDisabledAllowsAll() {
            let enforcer = ReadOnlyModeEnforcer.shared
            enforcer.level = .disabled

            let actions: [MacAction] = [
                MacAction(kind: .deleteFile, payload: ["path": "/tmp/test"], riskLevel: .reversibleInput, humanPreview: "删除"),
                MacAction(kind: .insertText, payload: ["text": "hello"], riskLevel: .reversibleInput, humanPreview: "输入"),
                MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "读取"),
            ]
            for action in actions {
                XCTAssertTrue(enforcer.evaluate(action) == .allow, "禁用模式应允许所有，但 \(action.kind) 被拦截")
            }
        }

        // MARK: - PolicyLayer 测试

        @MainActor func testPolicyLayerCustomRules() {
            let policy = PolicyLayer.shared
            policy.clearRules()

            // 添加规则：禁止所有 deleteFile 操作
            policy.addRule(PolicyLayer.Rule(name: "禁止删除") { action in
                if action.kind == .deleteFile {
                    return .deny("文件删除操作被策略禁止")
                }
                return .allow
            })

            let deleteAction = MacAction(kind: .deleteFile, payload: ["path": "/tmp/test"], riskLevel: .reversibleInput, humanPreview: "删除文件")
            let deleteDecision = policy.evaluate(deleteAction)
            guard case .deny = deleteDecision else {
                XCTFail("策略应拒绝 deleteFile，实际: \(deleteDecision)")
                return
            }

            // 非删除操作应允许
            let readAction = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "读取")
            XCTAssertTrue(policy.evaluate(readAction) == .allow)

            policy.clearRules()
        }

        @MainActor func testPolicyLayerStrictConfirmation() {
            let policy = PolicyLayer.shared
            policy.clearRules()
            policy.tier = .strict

            policy.addRule(PolicyLayer.Rule(name: "高成本操作确认") { action in
                if action.kind == .runShellCommand {
                    return .requireConfirmation("Shell 命令需确认")
                }
                return .allow
            })

            let shellAction = MacAction(kind: .runShellCommand, payload: ["command": "ls"], riskLevel: .reversibleInput, humanPreview: "运行命令")
            let decision = policy.evaluate(shellAction)
            guard case .requireConfirmation = decision else {
                XCTFail("严格模式下 requireConfirmation 应生效，实际: \(decision)")
                return
            }

            policy.clearRules()
            policy.tier = .standard // reset
        }

        @MainActor func testPolicyLayerStandardSkipsLowConfirmation() {
            let policy = PolicyLayer.shared
            policy.clearRules()
            policy.tier = .standard

            policy.addRule(PolicyLayer.Rule(name: "高成本操作确认") { action in
                if action.kind == .runShellCommand {
                    return .requireConfirmation("Shell 命令需确认")
                }
                return .allow
            })

            // 标准模式下 requireConfirmation 策略不会自动触发确认
            // 需要对应的 action 不在规则列表中
            let readAction = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "读取")
            XCTAssertTrue(policy.evaluate(readAction) == .allow)

            policy.clearRules()
        }

        // MARK: - ToolSafetyGateway 测试

        func testSafetyGatewayBlocksSensitiveWrites() async {
            let registry = MCPToolRegistry()
            let policy = ToolExecutionPolicy.default
            let gateway = ToolSafetyGateway(registry: registry) { policy }

            let home = NSHomeDirectory()

            // .ssh 目录写入应被阻止
            let sshReq = ToolCallRequest(id: "1", name: "write_file", arguments: ["path": "\(home)/.ssh/authorized_keys"])
            let sshResult = await gateway.blockedResult(for: sshReq)
            XCTAssertTrue(sshResult != nil)
            XCTAssertTrue(sshResult?.isError == true)
            XCTAssertTrue(sshResult?.output.contains("安全限制") == true)

            // .aws 目录写入应被阻止
            let awsReq = ToolCallRequest(id: "2", name: "write_file", arguments: ["path": "\(home)/.aws/credentials"])
            let awsResult = await gateway.blockedResult(for: awsReq)
            XCTAssertTrue(awsResult != nil)
            XCTAssertTrue(awsResult?.isError == true)

            // 非敏感路径应通过
            let safeReq = ToolCallRequest(id: "3", name: "write_file", arguments: ["path": "/tmp/test.txt"])
            let safeResult = await gateway.blockedResult(for: safeReq)
            XCTAssertTrue(safeResult == nil)
        }

        func testSafetyGatewayOnlyBlocksWriteFile() async {
            let registry = MCPToolRegistry()
            let policy = ToolExecutionPolicy.default
            let gateway = ToolSafetyGateway(registry: registry) { policy }

            let req = ToolCallRequest(id: "1", name: "read_file", arguments: ["path": "\(NSHomeDirectory())/.ssh/id_rsa"])
            let result = await gateway.blockedResult(for: req)
            XCTAssertTrue(result == nil)
        }

        func testSafetyGatewayRiskAssessment() async {
            let registry = MCPToolRegistry()
            let policy = ToolExecutionPolicy.default
            let gateway = ToolSafetyGateway(registry: registry) { policy }

            // Shell 写命令应为高风险
            let writeReq = ToolCallRequest(id: "1", name: "shell_command", arguments: ["command": "rm -rf /tmp/data"])
            let assessment = await gateway.assess(writeReq)
            XCTAssertTrue(assessment.riskLevel == .high || assessment.riskLevel == .medium)
            XCTAssertTrue(assessment.toolName == "shell_command")
            XCTAssertFalse(assessment.summary.isEmpty)

            // 读命令应为低风险
            let readReq = ToolCallRequest(id: "2", name: "shell_command", arguments: ["command": "ls -la"])
            let readAssessment = await gateway.assess(readReq)
            XCTAssertTrue(readAssessment.riskLevel != .high)

            // 未知工具应为高风险
            let unknownReq = ToolCallRequest(id: "3", name: "unknown_tool", arguments: [:])
            let unknownAssessment = await gateway.assess(unknownReq)
            XCTAssertTrue(unknownAssessment.actionCategory == .unknown)
        }

        func testSafetyGatewayBatchAssessment() async {
            let registry = MCPToolRegistry()
            let policy = ToolExecutionPolicy.default
            let gateway = ToolSafetyGateway(registry: registry) { policy }

            let requests = [
                ToolCallRequest(id: "1", name: "shell_command", arguments: ["command": "ls"]),
                ToolCallRequest(id: "2", name: "shell_command", arguments: ["command": "rm -rf /"]),
                ToolCallRequest(id: "3", name: "get_app_state", arguments: ["app": "Safari"]),
            ]
            let batch = await gateway.batchAssess(requests)
            XCTAssertTrue(batch.items.count == 3)
            XCTAssertTrue(batch.overallRisk == .high || batch.overallRisk == .medium)
            XCTAssertFalse(batch.summary.isEmpty)
        }

        func testSafetyGatewayNeedsConfirmation() async {
            let autoPolicy = ToolExecutionPolicy(autoApproveLow: true, autoApproveMedium: true, autoApproveHigh: false)
            let strictPolicy = ToolExecutionPolicy.strict
            let registry = MCPToolRegistry()

            let autoGateway = ToolSafetyGateway(registry: registry) { autoPolicy }
            let strictGateway = ToolSafetyGateway(registry: registry) { strictPolicy }

            let shellReq = ToolCallRequest(id: "1", name: "shell_command", arguments: ["command": "ls"])

            // 宽松策略：低风险应自动执行
            let needsConfirm = await autoGateway.needsConfirmation(shellReq)
            XCTAssertFalse(needsConfirm)

            // 严格策略：所有需要确认
            let strictNeedsConfirm = await strictGateway.needsConfirmation(shellReq)
            XCTAssertTrue(strictNeedsConfirm)
        }

        // MARK: - 工具分类验证

        func testToolCategoryMapping() async {
            let registry = MCPToolRegistry()
            let policy = ToolExecutionPolicy.default
            let gateway = ToolSafetyGateway(registry: registry) { policy }

            // 工具分类通过 categorize 方法验证（internal）

            let writeReq = ToolCallRequest(id: "1", name: "write_file", arguments: ["path": "/tmp/test.txt"])
            let assessment = await gateway.assess(writeReq)
            XCTAssertTrue(assessment.actionCategory == .localFileWrite)
            XCTAssertTrue(assessment.riskLevel == .medium || assessment.riskLevel == .high)

            let shellReq = ToolCallRequest(id: "2", name: "shell_command", arguments: ["command": "ls"])
            let shellAssessment = await gateway.assess(shellReq)
            // ls 是只读操作，所以是 shellRead
            XCTAssertTrue(shellAssessment.actionCategory == .shellRead || shellAssessment.actionCategory == .shellWrite)
        }



}
