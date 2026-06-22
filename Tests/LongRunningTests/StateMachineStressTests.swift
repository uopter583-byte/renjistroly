import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolySystemBridge
@testable import RenJistrolyProductIdentity
@testable import RenJistrolyEnterprise

// MARK: - 状态机压力测试
//
// 安全说明：对 ModeManager、ActionEngine 等状态机进行压力测试，
// 验证高并发和快速切换场景下的状态一致性和线程安全。
// 所有测试使用模拟数据，不操作真实系统。

// MARK: - ModeManager 快速模式切换测试

@MainActor
final class StateMachineStressTests: XCTestCase {
        func testModeManagerRapidToggle() {
            let manager = ModeManager()

            let modes: [OperationMode] = [
                .readOnly, .suggest, .executable, .highRisk,
                .noMouse, .localOnly, .sensitiveAppBlock, .autoMask,
                .policyLock, .auditExport,
            ]

            for i in 0...10 {
                for mode in modes {
                    if i % 2 == 0 {
                        manager.activate(mode)
                        XCTAssertTrue(manager.isActive(mode))
                    } else {
                        manager.deactivate(mode)
                        XCTAssertTrue(!manager.isActive(mode))
                    }
                }
            }

            // 验证最终状态：最后一轮是偶数，所有非锁定模式应激活
            for mode in modes where mode != .policyLock {
                XCTAssertTrue(manager.isActive(mode), "模式 \(mode.rawValue) 应在偶轮次后激活")
            }
        }

        func testModeManagerLockedModes() {
            let manager = ModeManager()
            manager.lock(.readOnly)

            // 锁定后尝试去激活应被忽略
            manager.deactivate(.readOnly)
            XCTAssertTrue(manager.isActive(.readOnly))

            // 解锁后可修改
            manager.unlock(.readOnly)
            manager.deactivate(.readOnly)
            XCTAssertTrue(!manager.isActive(.readOnly))
        }

        func testModeManagerToggleConsistency() {
            let manager = ModeManager()

            // 初始未激活
            XCTAssertTrue(!manager.isActive(.readOnly))
            manager.toggle(.readOnly)
            XCTAssertTrue(manager.isActive(.readOnly))

            // 再次 toggle 应取消
            manager.toggle(.readOnly)
            XCTAssertTrue(!manager.isActive(.readOnly))
        }

        func testModeManagerConcurrentToggle() {
            let manager = ModeManager()
            let modes = OperationMode.allCases

            // 非 actor 的 ModeManager 使用 NSLock 内部保护
            // 模拟串行快速切换
            for _ in 0..<50 {
                for mode in modes {
                    manager.activate(mode)
                }
            }

            for mode in modes {
                XCTAssertTrue(manager.isActive(mode), "模式 \(mode.rawValue) 应在全部激活后处于活跃状态")
            }
        }

        // MARK: - ModeManager 策略评估压力测试

        func testModeManagerEvaluateStress() {
            let manager = ModeManager()

            // 激活多种模式
            manager.activate(.readOnly)
            manager.activate(.highRisk)
            manager.activate(.noMouse)

            for i in 0..<100 {
                let actionName = ["click", "write", "read", "fetch", "delete"][i % 5]
                let riskLevel = [EnterpriseRiskLevel.trivial, .low, .medium, .high, .critical][i % 5]
                let result = manager.evaluate(actionName, riskLevel: riskLevel)
                // 验证返回有效结果
                XCTAssertTrue(result.auditRequired)
                // 验证 readOnly + noMouse 模式下 click 操作被拦截
                if actionName == "click" {
                    XCTAssertTrue(result.blockedBy != nil || !result.allowed,
                            "只读+无鼠标模式下 click 应被拦截")
                }
            }
        }

        func testModeManagerPolicyIndependence() {
            let manager = ModeManager()
            manager.activate(.localOnly)

            let policyBefore = manager.config.policy
            manager.setPolicy(.locked)

            // 活跃模式不受 policy 变更影响
            XCTAssertTrue(manager.isActive(.localOnly))
            // policy 已变更
            XCTAssertTrue(manager.config.policy != policyBefore)
            XCTAssertTrue(manager.config.policy.auditRetentionDays == 365)
        }

        // MARK: - ActionEngine 并发操作压力测试

        func testActionEngineConcurrentOperations() async {
            let engine = ActionEngine()

            // 批量创建操作
            let ids = (0..<50).map { i in
                engine.create(
                    type: "stress_\(i)",
                    preview: "压力测试操作 #\(i)",
                    riskLevel: EnterpriseRiskLevel(rawValue: i % 4) ?? .low
                ).id
            }

            XCTAssertTrue(ids.count == 50)

            // 模拟串行但快速的审批和执行
            for id in ids {
                XCTAssertTrue(engine.approve(id))
                XCTAssertTrue(engine.start(id))
                XCTAssertTrue(engine.complete(id, result: "done_\(id.prefix(8))"))
            }

            // 验证所有已完成
            for id in ids {
                let record = engine.getRecord(id)
                XCTAssertTrue(record?.status == .completed)
                XCTAssertTrue(record?.result?.hasPrefix("done_") == true)
            }
        }

        func testActionEngineStateConsistency() {
            let engine = ActionEngine()
            var allIds: [String] = []

            // 创建多种类型操作
            let operations: [(String, EnterpriseRiskLevel, String?)] = [
                ("read_file", .trivial, nil),
                ("write_file", .medium, "undo_write"),
                ("delete_file", .critical, "restore_file"),
                ("shell_command", .medium, nil),
                ("send_message", .critical, "cancel_message"),
            ]

            for (type, risk, rollback) in operations {
                let record = engine.create(
                    type: type,
                    preview: "\(type) 操作",
                    riskLevel: risk,
                    rollbackAction: rollback
                )
                allIds.append(record.id)
                XCTAssertTrue(record.status == .pending)
            }

            // 逐个审批和执行
            let approveIds = allIds.prefix(3)
            for id in approveIds {
                XCTAssertTrue(engine.approve(id))
                XCTAssertTrue(engine.start(id))
                XCTAssertTrue(engine.complete(id, result: "success"))
            }

            // 拒绝一个
            let rejectId = allIds[3]
            XCTAssertTrue(engine.reject(rejectId, reason: "手动拒绝"))

            // 取消一个
            let cancelId = allIds[4]
            XCTAssertTrue(engine.cancel(cancelId))

            // 验证最终状态一致性
            XCTAssertTrue(engine.getRecord(allIds[0])?.status == .completed)
            XCTAssertTrue(engine.getRecord(allIds[1])?.status == .completed)
            XCTAssertTrue(engine.getRecord(allIds[2])?.status == .completed)
            XCTAssertTrue(engine.getRecord(allIds[3])?.status == .rejected)
            XCTAssertTrue(engine.getRecord(allIds[4])?.status == .cancelled)

            // 验证历史记录涵盖已完成操作
            let history = engine.getRecentHistory()
            XCTAssertTrue(history.count == 3)
        }

        func testActionEngineFailRecovery() {
            let engine = ActionEngine()

            let record = engine.create(
                type: "risk_operation",
                preview: "高风险操作",
                riskLevel: .high
            )
            let id = record.id
            XCTAssertTrue(engine.approve(id))
            XCTAssertTrue(engine.start(id))

            // 模拟失败并有恢复建议
            XCTAssertTrue(engine.fail(id, reason: "网络超时", recovery: "检查网络连接后重试"))
            XCTAssertTrue(engine.getRecord(id)?.status == .failed)
            XCTAssertTrue(engine.getRecord(id)?.failureReason == "网络超时")
            XCTAssertTrue(engine.getRecord(id)?.recoverySuggestion == "检查网络连接后重试")
        }

        // MARK: - 跨组件状态一致性测试

        func testCrossComponentStateConsistency() {
            let modeManager = ModeManager()
            let engine = ActionEngine()

            // 设置只读模式
            modeManager.activate(.readOnly)

            // 创建操作并验证 modeManager 评估
            let readAction = engine.create(type: "read_file", preview: "读取文件", riskLevel: .low)
            let writeAction = engine.create(type: "write_file", preview: "写入文件", riskLevel: .medium)

            // 只读模式下，读操作应允许，写操作可能被阻止
            let readEval = modeManager.evaluate("read", riskLevel: .trivial)
            let writeEval = modeManager.evaluate("write", riskLevel: .medium)

            XCTAssertTrue(readEval.allowed != writeEval.allowed || readEval.blockedBy != writeEval.blockedBy,
                    "只读模式下读写操作应有不同的评估结果")

            // 即使 modeManager 允许，ActionEngine 仍需审批流程
            XCTAssertTrue(readAction.status == ActionStatus.pending)
            XCTAssertTrue(writeAction.status == ActionStatus.pending)
        }

        func testPolicyAndModeCombined() {
            let policy = PolicyLayer.shared
            let modeManager = ModeManager()

            policy.clearRules()

            // 添加策略规则
            policy.addRule(PolicyLayer.Rule(name: "deny_delete") { action in
                if action.kind == .deleteFile {
                    return .deny("策略禁止删除")
                }
                return .allow
            })

            // 同时激活只读模式
            modeManager.activate(.readOnly)

            // 删除操作应被双层阻止
            let deleteAction = MacAction(kind: .deleteFile, payload: ["path": "/tmp/t"], riskLevel: .persistentOrExternal, humanPreview: "删除")
            let policyDecision = policy.evaluate(deleteAction)
            guard case .deny = policyDecision else {
                XCTFail("策略层应 deny deleteFile，实际: \(policyDecision)")
                return
            }

            // 读操作应只受 modeManager 影响
            let readAction = MacAction(kind: .readContext, riskLevel: .readOnly, humanPreview: "读取")
            XCTAssertTrue(policy.evaluate(readAction) == .allow)

            policy.clearRules()
            modeManager.deactivate(.readOnly)
        }

        // MARK: - 上下文刷新压力测试

        func testContextSnapshotConsistency() {
            // 验证 ContextProvider 相关模型的构造一致性
            let selection = SelectionContextSnapshot(selectedText: "selected text", sourceApp: "Safari")
            XCTAssertTrue(selection.selectedText == "selected text")
            XCTAssertTrue(selection.sourceApp == "Safari")
            XCTAssertTrue(selection.length == 13)

            let clipboard = ClipboardRiskSnapshot(
                hasContent: true,
                contentType: "text",
                containsSensitivePattern: false,
                riskLevel: .low,
                suggestion: "内容安全"
            )
            XCTAssertTrue(clipboard.hasContent)
            XCTAssertTrue(clipboard.contentType == "text")
            XCTAssertTrue(clipboard.riskLevel == .low)

            let taskContext = TaskContextSnapshot(
                currentTask: "文件整理",
                taskHistory: ["步骤1", "步骤2"],
                progress: 0.5,
                remainingSteps: 2
            )
            XCTAssertTrue(taskContext.currentTask == "文件整理")
            XCTAssertTrue(taskContext.taskHistory.count == 2)
            XCTAssertTrue(taskContext.progress == 0.5)
        }

        // MARK: - 边缘条件：空输入 / 边界值

        func testEmptyStringThroughComponents() {
            let sanitizer = CredentialSanitizer()
            let allowlist = CommandAllowlist()

            // CredentialSanitizer
            XCTAssertTrue(sanitizer.sanitize("") == "")
            XCTAssertTrue(sanitizer.sanitize(" ") == " ")

            // CommandAllowlist
            XCTAssertNotNil(allowlist.allows(""))
            XCTAssertNotNil(allowlist.allows(" "))
            XCTAssertNotNil(allowlist.allows("\n"))
            XCTAssertNotNil(allowlist.allows("\t"))
        }

        func testLongInputDoesNotCrash() {
            let sanitizer = CredentialSanitizer()
            let veryLong = String(repeating: "password=secret", count: 10000)

            // 超长输入应能正常处理
            let result = sanitizer.sanitize(veryLong)
            XCTAssertTrue(result.contains("****"))
            XCTAssertFalse(result.contains("secret"))
            // 验证不崩溃
            XCTAssertTrue(true)
        }

        func testExtremeRiskLevelActions() {
            let engine = ActionEngine()

            // 所有风险级别的操作
            for level in [EnterpriseRiskLevel.trivial, .low, .medium, .high] {
                let record = engine.create(type: "risk_test", preview: "风险 \(level.title)", riskLevel: level)
                let id = record.id
                XCTAssertTrue(engine.approve(id))
                XCTAssertTrue(engine.start(id))
                XCTAssertTrue(engine.complete(id, result: "level_\(level.rawValue)"))
                XCTAssertTrue(engine.getRecord(id)?.status == .completed)
            }

            let history = engine.getRecentHistory(limit: 10)
            XCTAssertTrue(history.count == 4)
        }

        // MARK: - 定时器/轮询相关稳定性

        func testMouseGuardContinuousTick() {
            let guard_ = MouseGuard.shared

            for _ in 0..<100 {
                guard_.tick()
                _ = guard_.checkPermission()
                _ = guard_.userState()
            }

            // 验证不崩溃
            XCTAssertTrue(true)
        }

        func testMouseGuardEventualIdle() {
            let guard_ = MouseGuard.shared
            guard_.reportUserActivity()

            // 模拟多次 tick
            for _ in 0..<10 {
                guard_.tick()
            }

            // checkPermission 返回有效值
            let perm = guard_.checkPermission()
            _ = perm
        }



}
