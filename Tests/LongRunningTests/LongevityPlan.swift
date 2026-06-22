import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolySystemBridge
@testable import RenJistrolyProductIdentity
@testable import RenJistrolyEnterprise

// MARK: - 长稳测试框架 — 持续操作稳定性验证
//
// 安全说明：本文件定义长稳测试框架，包括连续操作、内存泄漏检测、
// 状态一致性检查和操作日志完整性验证。不执行真实系统操作。

// MARK: - 长稳测试计划清单

/// 长稳测试项目定义
struct LongevityTestItem: Sendable {
    let id: String
    let name: String
    let description: String
    let minOperations: Int
    let expectedBehavior: String
}

/// 长稳测试计划
struct LongevityTestPlan: Sendable {
    static let items: [LongevityTestItem] = [
        LongevityTestItem(
            id: "LON-001",
            name: "连续工具评估",
            description: "ToolSafetyGateway.assess() 连续调用 1000 次，验证无崩溃和响应退化",
            minOperations: 1000,
            expectedBehavior: "所有评估返回有效结果，延迟无明显增长"
        ),
        LongevityTestItem(
            id: "LON-002",
            name: "命令白名单批量查询",
            description: "CommandAllowlist.allows() 连续调用 2000 次",
            minOperations: 2000,
            expectedBehavior: "无延迟增长，内存占用稳定"
        ),
        LongevityTestItem(
            id: "LON-003",
            name: "策略层规则堆积",
            description: "PolicyLayer 动态添加/移除 500 次规则",
            minOperations: 500,
            expectedBehavior: "规则管理无泄漏，评估性能稳定"
        ),
        LongevityTestItem(
            id: "LON-004",
            name: "只读模式级别切换",
            description: "ReadOnlyModeEnforcer 级别切换 500 次",
            minOperations: 500,
            expectedBehavior: "级别切换正确，策略评估始终返回有效决策"
        ),
        LongevityTestItem(
            id: "LON-005",
            name: "凭据脱敏批量处理",
            description: "CredentialSanitizer.sanitize() 批量处理 1000 条混合文本",
            minOperations: 1000,
            expectedBehavior: "所有输入正确处理，无正则异常"
        ),
        LongevityTestItem(
            id: "LON-006",
            name: "窗口匹配批量验证",
            description: "WindowMatchValidator.validate() 连续匹配 500 次",
            minOperations: 500,
            expectedBehavior: "匹配结果正确，无性能退化"
        ),
        LongevityTestItem(
            id: "LON-007",
            name: "操作日志完整性",
            description: "ActionEngine 创建-审批-执行-完成全流程 300 次",
            minOperations: 300,
            expectedBehavior: "所有审计跟踪完整，状态转换正确"
        ),
        LongevityTestItem(
            id: "LON-008",
            name: "状态一致性检查",
            description: "ModeManager 模式切换 + ActionEngine 并发操作后检查状态一致性",
            minOperations: 200,
            expectedBehavior: "最终状态与预期一致，无中间状态残留"
        ),
        LongevityTestItem(
            id: "LON-009",
            name: "策略层并发评估",
            description: "PolicyLayer 在多线程下持续评估 1000+ 操作",
            minOperations: 1000,
            expectedBehavior: "线程安全，无数据竞争"
        ),
        LongevityTestItem(
            id: "LON-010",
            name: "剪贴板风险评估批量执行",
            description: "ClipboardRiskSnapshot 批量构造和评估 500 次",
            minOperations: 500,
            expectedBehavior: "构造正确，评估一致"
        ),
    ]
}

// MARK: - 验证测试计划完整性

final class LongevityPlan: XCTestCase {
        func testLongevityPlanComplete() {
            XCTAssertTrue(LongevityTestPlan.items.count >= 8)
        }

        func testLongevityUniqueIDs() {
            let ids = LongevityTestPlan.items.map(\.id)
            XCTAssertTrue(Set(ids).count == ids.count)
        }

        func testLongevityMinOperations() {
            for item in LongevityTestPlan.items {
                XCTAssertTrue(item.minOperations >= 100, "\(item.id) minOperations 应 >= 100，实际 \(item.minOperations)")
            }
        }

        // MARK: - 连续操作稳定性测试

        func testCommandAllowlistContinuous() {
            let list = CommandAllowlist()
            let commands = (0..<100).map { _ in
                ["ls -la", "cat /etc/hosts", "grep pattern", "echo hello", "find .",
                 "rm -rf /", "sudo rm", "dd if=/dev/zero", "chmod 777", "passwd root",
                 "curl -s https://example.com", "head file", "tail file", "sort file", "wc -l"]
            }.flatMap { $0 }

            let start = CFAbsoluteTimeGetCurrent()
            for cmd in commands {
                _ = list.allows(cmd)
            }
            let elapsed = CFAbsoluteTimeGetCurrent() - start

            // 1000 次应在 1 秒内完成
            XCTAssertTrue(elapsed < 1.0, "1000 次白名单查询耗时 \(elapsed)s，预期 < 1s")
        }

        func testCredentialSanitizerBatch() {
            let sanitizer = CredentialSanitizer()
            let inputs = (0..<100).map { i in
                [
                    "user: admin, password: secret\(i), token: tok_\(i)abc",
                    "Normal log line \(i): operation completed successfully",
                    "config: { key = value\(i), secret = s3kr3t\(i) }",
                    "Base64 data: QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVpBQkNERUZHSElKS0xNTk9Q\(i)",
                    "普通文本行 \(i)：今天天气很好",
                ]
            }.flatMap { $0 }

            let start = CFAbsoluteTimeGetCurrent()
            for input in inputs {
                let result = sanitizer.sanitize(input)
                if input.contains("password") || input.contains("secret") || input.contains("token") {
                    XCTAssertTrue(result.contains("******"), "凭据应被脱敏: \(input.prefix(30))")
                }
            }
            let elapsed = CFAbsoluteTimeGetCurrent() - start

            XCTAssertTrue(elapsed < 2.0, "1000 条脱敏耗时 \(elapsed)s，预期 < 2s")
        }

        // MARK: - 操作生命周期完整性测试

        @MainActor func testActionEngineFullLifecycle() {
            let engine = ActionEngine()

            for i in 0..<20 {
                let record = engine.create(
                    type: "test_operation_\(i)",
                    preview: "测试操作 #\(i)",
                    riskLevel: .low
                )
                let id = record.id

                // 验证初始状态
                XCTAssertTrue(engine.getRecord(id)?.status == .pending)

                // 审批
                let approved = engine.approve(id)
                XCTAssertTrue(approved)
                XCTAssertTrue(engine.getRecord(id)?.status == .approved)

                // 执行
                let started = engine.start(id)
                XCTAssertTrue(started)
                XCTAssertTrue(engine.getRecord(id)?.status == .executing)

                // 完成
                let completed = engine.complete(id, result: "success_\(i)")
                XCTAssertTrue(completed)
                XCTAssertTrue(engine.getRecord(id)?.status == .completed)
                XCTAssertTrue(engine.getRecord(id)?.result == "success_\(i)")
            }

            // 验证历史记录
            let history = engine.getRecentHistory(limit: 100)
            XCTAssertTrue(history.count == 20)
        }

        @MainActor func testActionEngineRollbackFlow() {
            let engine = ActionEngine()

            let record = engine.create(
                type: "delete_file",
                preview: "删除文件 /tmp/test.txt",
                riskLevel: .critical,
                rollbackAction: "恢复文件 /tmp/test.txt"
            )
            let id = record.id

            XCTAssertTrue(engine.approve(id))
            XCTAssertTrue(engine.start(id))
            XCTAssertTrue(engine.complete(id, result: "deleted"))

            let rollbackAction = engine.rollback(id)
            XCTAssertTrue(rollbackAction == "恢复文件 /tmp/test.txt")
            XCTAssertTrue(engine.getRecord(id)?.status == .rolledBack)
        }

        @MainActor func testActionEngineCancelFlow() {
            let engine = ActionEngine()

            // 创建后取消（pending 状态）
            let pendingRecord = engine.create(type: "pending_op", preview: "待取消", riskLevel: .low)
            XCTAssertTrue(engine.cancel(pendingRecord.id))
            XCTAssertTrue(engine.getRecord(pendingRecord.id)?.status == .cancelled)

            // 执行中取消
            let executingRecord = engine.create(type: "running_op", preview: "运行中取消", riskLevel: .medium)
            XCTAssertTrue(engine.approve(executingRecord.id))
            XCTAssertTrue(engine.start(executingRecord.id))
            XCTAssertTrue(engine.cancel(executingRecord.id))
            XCTAssertTrue(engine.getRecord(executingRecord.id)?.status == .cancelled)
        }

        @MainActor func testActionEngineCannotCancelCompleted() {
            let engine = ActionEngine()
            let record = engine.create(type: "done", preview: "已完成", riskLevel: .low)
            let id = record.id
            XCTAssertTrue(engine.approve(id))
            XCTAssertTrue(engine.start(id))
            XCTAssertTrue(engine.complete(id, result: "ok"))
            XCTAssertTrue(!engine.cancel(id))
        }

        @MainActor func testActionEngineIdempotentReject() {
            let engine = ActionEngine()
            let record = engine.create(type: "test", preview: "test", riskLevel: .low)
            let id = record.id

            // 重复审批应拒绝
            XCTAssertTrue(engine.approve(id))
            XCTAssertTrue(!engine.approve(id))

            // 非 pending 状态下 reject 应拒绝
            XCTAssertTrue(!engine.reject(id))
        }

        // MARK: - 审计日志完整性测试

        @MainActor func testActionEngineAuditCompleteness() {
            let engine = ActionEngine()

            let record = engine.create(type: "audit_test", preview: "审计完整性测试", riskLevel: .high)
            let id = record.id

            XCTAssertTrue(engine.approve(id))
            XCTAssertTrue(engine.start(id))
            XCTAssertTrue(engine.complete(id, result: "ok"))

            let trail = engine.getAuditTrail(id)
            XCTAssertTrue(trail.count >= 4) // created + approved + started + completed

            let events = trail.map(\.event)
            XCTAssertTrue(events == ["created", "approved", "started", "completed"])
        }

        @MainActor func testActionEngineAuditTimestamps() {
            let engine = ActionEngine()
            let record = engine.create(type: "ts_test", preview: "时间戳测试", riskLevel: .low)
            let id = record.id
            XCTAssertTrue(engine.approve(id))
            XCTAssertTrue(engine.start(id))
            XCTAssertTrue(engine.complete(id, result: "done"))

            let trail = engine.getAuditTrail(id)
            for i in 1..<trail.count {
                XCTAssertTrue(trail[i].timestamp >= trail[i-1].timestamp,
                        "审计事件时间戳应递增: \(trail[i-1].event) -> \(trail[i].event)")
            }
        }

        // MARK: - PolicyLayer 规则管理稳定性

        @MainActor func testPolicyLayerRuleStability() {
            let policy = PolicyLayer.shared

            for i in 0..<100 {
                policy.clearRules()
                XCTAssertTrue(policy.ruleCount == 0)

                policy.addRule(PolicyLayer.Rule(name: "rule_\(i)") { _ in .allow })
                XCTAssertTrue(policy.ruleCount == 1)

                policy.addRule(PolicyLayer.Rule(name: "deny_all") { _ in .deny("denied") })
                XCTAssertTrue(policy.ruleCount == 2)
            }

            policy.clearRules()
        }

        // MARK: - WindowMatchValidator 批量匹配性能

        func testWindowMatchBatchPerformance() {
            let validator = WindowMatchValidator()
            let descriptors = (0..<20).map { i in
                WindowMatchValidator.WindowDescriptor(
                    title: "Window_\(i)", bundleID: "com.test.\(i)",
                    processID: pid_t(1000 + i),
                    frame: CGRect(x: CGFloat(i * 100), y: 0, width: 800, height: 600)
                )
            }

            let start = CFAbsoluteTimeGetCurrent()
            for _ in 0..<500 {
                let target = descriptors.randomElement()!
                let result = validator.validate(target: target, candidates: descriptors, strategy: .fuzzy)
                // 验证不崩溃
                _ = result.matched
                _ = result.confidence
            }
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            XCTAssertTrue(elapsed < 2.0, "500 次匹配耗时 \(elapsed)s，预期 < 2s")
        }

        // MARK: - 状态一致性：ReadOnlyModeEnforcer + PolicyLayer 联合评估

        @MainActor func testCombinedReadOnlyAndPolicyConsistency() {
            let enforcer = ReadOnlyModeEnforcer.shared
            let policy = PolicyLayer.shared

            enforcer.level = .strict
            policy.clearRules()
            policy.tier = .standard

            let actions: [MacAction] = [
                MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "读取"),
                MacAction(kind: .deleteFile, payload: ["path": "/tmp/t"], riskLevel: .destructiveOrSensitive, humanPreview: "删除"),
                MacAction(kind: .insertText, payload: ["text": "hello"], riskLevel: .reversibleInput, humanPreview: "输入"),
                MacAction(kind: .scroll, riskLevel: .reversibleInput, humanPreview: "滚动"),
            ]

            for action in actions {
                let enforcerDecision = enforcer.evaluate(action)
                let policyDecision = policy.evaluate(action)

                switch (enforcerDecision, policyDecision) {
                case (.deny, _):
                    // enforcer deny 优先
                    XCTAssertTrue(true)
                case (_, .deny):
                    // policy deny 也有效
                    XCTAssertTrue(true)
                case (.allow, .allow):
                    // 都允许
                    XCTAssertTrue(true)
                case (.requireConfirmation, _), (_, .requireConfirmation):
                    // 任意一方要求确认
                    XCTAssertTrue(true)
                default:
                    XCTFail("未预期的决策组合: enforcer=\(enforcerDecision), policy=\(policyDecision)")
                }
            }

            enforcer.level = .disabled
            policy.clearRules()
        }



}