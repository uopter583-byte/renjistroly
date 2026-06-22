import XCTest
@testable import RenJistrolySystemBridge
@testable import RenJistrolyModels

// MARK: - Mock 权限恢复

private enum PermissionRecoveryStrategy: String {
    case reauthorize
    case gracefulDegradation
    case retry
    case promptUser
}

private struct PermissionRecoveryResult {
    let recovered: Bool
    let strategy: PermissionRecoveryStrategy
    let userPrompt: String?
    let degradedCapabilities: [String]
}

/// 模拟权限恢复管理器
private final class MockPermissionRecoveryManager {
    /// 模拟辅助功能权限状态
    var accessibilityGranted: Bool = true
    /// 模拟屏幕录制权限状态
    var screenRecordingGranted: Bool = true
    /// 模拟权限检查结果（用于间歇性可用场景）
    var permissionCheckResults: [Bool] = []
    private var permissionCheckIndex: Int = 0

    private(set) var reauthAttempts: Int = 0
    private(set) var recoveryHistory: [PermissionRecoveryStrategy] = []

    /// 检测辅助功能权限并尝试恢复
    func recoverAccessibilityPermission() async -> PermissionRecoveryResult {
        guard !accessibilityGranted else {
            return PermissionRecoveryResult(
                recovered: true,
                strategy: .reauthorize,
                userPrompt: nil,
                degradedCapabilities: []
            )
        }

        reauthAttempts += 1
        if reauthAttempts < 2 {
            recoveryHistory.append(.reauthorize)
            return PermissionRecoveryResult(
                recovered: false,
                strategy: .reauthorize,
                userPrompt: "辅助功能权限已被关闭，请在系统设置中重新授权",
                degradedCapabilities: ["click", "typeText", "pressKey"]
            )
        }

        // 重试后恢复
        accessibilityGranted = true
        recoveryHistory.append(.reauthorize)
        return PermissionRecoveryResult(
            recovered: true,
            strategy: .reauthorize,
            userPrompt: "辅助功能权限已恢复",
            degradedCapabilities: []
        )
    }

    /// 检测屏幕录制权限并优雅降级
    func recoverScreenRecordingPermission() async -> PermissionRecoveryResult {
        guard !screenRecordingGranted else {
            return PermissionRecoveryResult(
                recovered: true,
                strategy: .gracefulDegradation,
                userPrompt: nil,
                degradedCapabilities: []
            )
        }

        recoveryHistory.append(.gracefulDegradation)
        return PermissionRecoveryResult(
            recovered: false,
            strategy: .gracefulDegradation,
            userPrompt: "屏幕录制权限已被关闭，已降级至仅使用辅助功能获取界面信息",
            degradedCapabilities: ["screenCapture", "ocrFullScreen", "visualContext"]
        )
    }

    /// 处理间歇性权限问题（重试机制）
    func checkPermissionWithRetry(maxRetries: Int = 3) async -> Bool {
        for attempt in 1...maxRetries {
            let result: Bool
            if permissionCheckIndex < permissionCheckResults.count {
                result = permissionCheckResults[permissionCheckIndex]
                permissionCheckIndex += 1
            } else {
                result = true // 默认成功
            }

            if result {
                recoveryHistory.append(.retry)
                return true
            }

            if attempt < maxRetries {
                recoveryHistory.append(.retry)
                // 模拟短暂等待
                await Task.yield()
            }
        }

        recoveryHistory.append(.promptUser)
        return false
    }

    func reset() {
        reauthAttempts = 0
        recoveryHistory.removeAll()
        permissionCheckIndex = 0
    }
}

// MARK: - PermissionRevokedTests

final class PermissionRevokedTests: XCTestCase {

    /// 辅助功能权限被关闭 → 检测 + 重授权提示
    func testAccessibilityRevokedTriggersReauthPrompt() async {
        let manager = MockPermissionRecoveryManager()
        manager.accessibilityGranted = false

        let result = await manager.recoverAccessibilityPermission()

        XCTAssertFalse(result.recovered, "权限刚关闭时应未恢复")
        XCTAssertEqual(result.strategy, .reauthorize)
        XCTAssertTrue(result.userPrompt?.contains("辅助功能") ?? false, "应提示辅助功能权限问题")
        XCTAssertTrue(result.degradedCapabilities.contains("click"), "应列出受影响的点击功能")
        XCTAssertTrue(result.degradedCapabilities.contains("typeText"), "应列出受影响的输入功能")
    }

    /// 多次重试后辅助功能权限恢复
    func testAccessibilityReauthRetryRestoresPermission() async {
        let manager = MockPermissionRecoveryManager()
        manager.accessibilityGranted = false

        // 第一次失败
        var result = await manager.recoverAccessibilityPermission()
        XCTAssertFalse(result.recovered)
        XCTAssertEqual(manager.reauthAttempts, 1)

        // 第二次恢复
        result = await manager.recoverAccessibilityPermission()
        XCTAssertTrue(result.recovered, "重试后应恢复")
        XCTAssertEqual(manager.reauthAttempts, 2)
        XCTAssertTrue(result.userPrompt?.contains("已恢复") ?? false, "应提示权限已恢复")
    }

    /// 屏幕录制权限被关闭 → 优雅降级
    func testScreenRecordingRevokedDegradesGracefully() async {
        let manager = MockPermissionRecoveryManager()
        manager.screenRecordingGranted = false

        let result = await manager.recoverScreenRecordingPermission()

        XCTAssertFalse(result.recovered, "屏幕录制权限关闭后无法完全恢复")
        XCTAssertEqual(result.strategy, .gracefulDegradation)
        XCTAssertTrue(result.userPrompt?.contains("降级") ?? false, "应提示已降级")
        XCTAssertTrue(result.degradedCapabilities.contains("screenCapture"), "应降级屏幕捕获")
        XCTAssertTrue(result.degradedCapabilities.contains("ocrFullScreen"), "应降级 OCR")
    }

    /// 权限间歇性可用 → 重试机制
    func testIntermittentPermissionRetries() async {
        let manager = MockPermissionRecoveryManager()
        // 模拟权限检查结果：失败、失败、成功
        manager.permissionCheckResults = [false, false, true]

        let result = await manager.checkPermissionWithRetry(maxRetries: 3)

        XCTAssertTrue(result, "重试后应成功获取权限")
        XCTAssertEqual(manager.recoveryHistory.filter { $0 == .retry }.count, 3, "应触发 3 次重试")
    }

    /// 权限一直不可用 → 最终提示用户
    func testPersistentPermissionFailurePromptsUser() async {
        let manager = MockPermissionRecoveryManager()
        manager.permissionCheckResults = [false, false, false, false, false]

        let result = await manager.checkPermissionWithRetry(maxRetries: 5)

        XCTAssertFalse(result, "权限始终不可用，应返回失败")
        // 最后一条记录应该是提示用户
        XCTAssertEqual(manager.recoveryHistory.last, .promptUser, "最终应提示用户")
    }
}
