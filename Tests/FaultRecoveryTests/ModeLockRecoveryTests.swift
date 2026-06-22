import XCTest
@testable import RenJistrolyEnterprise
@testable import RenJistrolyModels

// MARK: - Mock 模式锁定

private struct ModeLockRecord: Equatable {
    let attemptedMode: OperationMode
    let rejected: Bool
    let reason: String?
}

private struct AuditState {
    var isEnabled: Bool
    var isForcedByPolicy: Bool
}

/// 模拟模式锁定恢复管理器
private final class MockModeLockManager {
    /// 当前激活的模式集合
    private var activeModes: Set<OperationMode> = [.executable]
    /// 管理员锁定的模式（不可切换）
    var lockedModes: Set<OperationMode> = []
    /// 审计导出是否启用
    var auditExportEnabled: Bool = false
    /// 审计导出是否被策略强制保持
    var auditExportForced: Bool = false
    /// 当前生效的最高策略级别
    var highestPolicyLevel: Int = 0

    private(set) var lockRecords: [ModeLockRecord] = []
    private(set) var rejectedSwitches: [OperationMode] = []

    private let modePriority: [OperationMode: Int] = [
        .readOnly: 1,
        .suggest: 2,
        .executable: 3,
        .highRisk: 4,
        .noMouse: 5,
        .localOnly: 6,
        .sensitiveAppBlock: 7,
        .autoMask: 8,
        .policyLock: 9,
        .auditExport: 10,
    ]

    /// 请求模式切换
    func requestSwitch(to newMode: OperationMode) -> Bool {
        // 检查是否处于策略锁定状态
        if activeModes.contains(.policyLock) && newMode != .policyLock {
            let record = ModeLockRecord(attemptedMode: newMode, rejected: true, reason: "管理员策略锁定中，无法切换模式")
            lockRecords.append(record)
            rejectedSwitches.append(newMode)
            return false
        }

        // 检查切换的目标是否被锁定
        if lockedModes.contains(newMode) {
            let record = ModeLockRecord(attemptedMode: newMode, rejected: true, reason: "模式「\(newMode.title)」已被管理员锁定")
            lockRecords.append(record)
            rejectedSwitches.append(newMode)
            return false
        }

        // 检查策略锁定状态下，是否尝试关闭审计导出
        if auditExportForced && newMode != .auditExport {
            let record = ModeLockRecord(attemptedMode: newMode, rejected: true, reason: "审计导出模式已强制开启，无法切换到其他模式")
            lockRecords.append(record)
            rejectedSwitches.append(newMode)
            return false
        }

        activeModes.insert(newMode)
        let record = ModeLockRecord(attemptedMode: newMode, rejected: false, reason: nil)
        lockRecords.append(record)
        return true
    }

    /// 尝试关闭审计导出
    func requestDisableAudit() -> (success: Bool, message: String?) {
        guard activeModes.contains(.auditExport) || auditExportEnabled else {
            return (true, nil)
        }

        if auditExportForced || activeModes.contains(.policyLock) {
            return (false, "审计导出已被策略锁定，无法关闭")
        }

        auditExportEnabled = false
        activeModes.remove(.auditExport)
        return (true, nil)
    }

    /// 处理双重锁定冲突，返回最高级别
    func resolveLockConflict(modes: [OperationMode]) -> OperationMode? {
        modes.max(by: { (modePriority[$0] ?? 0) < (modePriority[$1] ?? 0) })
    }

    /// 检查是否有任何锁定生效
    var hasActiveLock: Bool {
        !lockedModes.isEmpty || activeModes.contains(.policyLock)
    }

    func reset() {
        activeModes = [.executable]
        lockedModes.removeAll()
        auditExportEnabled = false
        auditExportForced = false
        lockRecords.removeAll()
        rejectedSwitches.removeAll()
    }
}

// MARK: - ModeLockRecoveryTests

final class ModeLockRecoveryTests: XCTestCase {

    /// 管理员锁定的模式被用户尝试切换 → 拒绝 + 日志
    func testSwitchingToLockedModeRejected() {
        let manager = MockModeLockManager()
        manager.lockedModes = [.noMouse, .sensitiveAppBlock]

        let noMouseResult = manager.requestSwitch(to: .noMouse)
        let sensitiveResult = manager.requestSwitch(to: .sensitiveAppBlock)
        let executableResult = manager.requestSwitch(to: .executable)

        XCTAssertFalse(noMouseResult, "切换到锁定模式 .noMouse 应被拒绝")
        XCTAssertFalse(sensitiveResult, "切换到锁定模式 .sensitiveAppBlock 应被拒绝")
        XCTAssertTrue(executableResult, "切换到非锁定模式 .executable 应被允许")

        XCTAssertEqual(manager.rejectedSwitches.count, 2, "应有 2 次拒绝记录")
        let rejectedReasons = manager.lockRecords.filter { $0.rejected }
        XCTAssertEqual(rejectedReasons.count, 2)
        XCTAssertTrue(rejectedReasons.allSatisfy { $0.reason?.contains("锁定") ?? false })
    }

    /// 策略 locked 后尝试关闭审计 → 强制保持
    func testDisablingAuditWhenPolicyLockedIsForced() {
        let manager = MockModeLockManager()
        manager.auditExportForced = true
        manager.auditExportEnabled = true

        let result = manager.requestDisableAudit()

        XCTAssertFalse(result.success, "策略锁定状态下关闭审计应被拒绝")
        XCTAssertEqual(result.message, "审计导出已被策略锁定，无法关闭")
    }

    /// 策略 locked 后尝试切换模式 → 拒绝
    func testModeSwitchWhenPolicyLockedIsRejected() {
        let manager = MockModeLockManager()
        // 激活 policyLock 模式
        let policyLockResult = manager.requestSwitch(to: .policyLock)
        XCTAssertTrue(policyLockResult, "切到 policyLock 应成功")

        // 尝试切换到其他模式
        let switchResult = manager.requestSwitch(to: .executable)
        XCTAssertFalse(switchResult, "策略锁定状态下切换到其他模式应被拒绝")

        let rejectRecord = manager.lockRecords.last
        XCTAssertEqual(rejectRecord?.attemptedMode, .executable)
        XCTAssertTrue(rejectRecord?.rejected ?? false)
    }

    /// 双重锁定冲突 → 最高级别生效
    func testDualLockConflictResolvesToHighestPriority() {
        let manager = MockModeLockManager()

        let modes: [OperationMode] = [.noMouse, .sensitiveAppBlock]
        let highest = manager.resolveLockConflict(modes: modes)

        XCTAssertEqual(highest, .sensitiveAppBlock, "sensitiveAppBlock 的优先级应高于 noMouse")
    }

    /// 多个模式中最高优先级生效
    func testMultipleLockResolvesHighest() {
        let manager = MockModeLockManager()

        let modes: [OperationMode] = [.readOnly, .suggest, .executable, .highRisk, .noMouse]
        let highest = manager.resolveLockConflict(modes: modes)

        XCTAssertEqual(highest, .noMouse, "noMouse 应为多个模式中最高优先级")
    }

    /// 无锁定状态正常切换
    func testNormalSwitchWhenNoLock() {
        let manager = MockModeLockManager()

        XCTAssertTrue(manager.requestSwitch(to: .executable), "无锁定时允许切到 executable")
        XCTAssertTrue(manager.requestSwitch(to: .highRisk), "无锁定时允许切到 highRisk")
        XCTAssertEqual(manager.rejectedSwitches.count, 0, "不应有拒绝记录")
    }
}
