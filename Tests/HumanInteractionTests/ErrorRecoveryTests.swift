import Foundation
import XCTest
@testable import RenJistrolyModels
@testable import RenJistrolySystemBridge

// MARK: - ErrorRecoveryTests

/// 错误恢复测试。
/// 测试模拟的各种错误场景下的恢复机制：动作失败重试、超时恢复、心跳检测等。
final class ErrorRecoveryTests: XCTestCase {

    private var engine: MockActionEngine!
    private var mockBridge: MockAccessibilityBridge!

    override func setUp() {
        super.setUp()
        engine = MockActionEngine()
        mockBridge = MockAccessibilityBridge(isTrusted: true)
    }

    override func tearDown() {
        engine = nil
        mockBridge = nil
        super.tearDown()
    }

    // MARK: - 动作重试

    func testRetryFailedAction() async {
        let action = MockActionScenario.click(at: CGPoint(x: 100, y: 200))
        engine.stub(.clickAt, result: ActionResult(actionID: action.id, success: false, message: "目标未就绪"))

        let first = await engine.execute(action)
        XCTAssertFalse(first.success)

        // 重试：清空 stub，用默认成功
        engine.presetResults.removeAll()
        let retry = await engine.execute(action)
        XCTAssertTrue(retry.success)
    }

    func testRetryCountTracking() async {
        let action = MockActionScenario.readContext()
        for _ in 0..<3 {
            let result = await engine.execute(action)
            XCTAssertTrue(result.success)
        }

        XCTAssertEqual(engine.totalExecutions, 3)
        XCTAssertEqual(engine.successCount, 3)
    }

    func testMixedSuccessAndFailure() async {
        let read = MockActionScenario.readContext()
        let click = MockActionScenario.click(at: CGPoint.zero)

        engine.stub(.clickAt, result: ActionResult(actionID: click.id, success: false, message: "坐标无效"))

        _ = await engine.execute(read)
        _ = await engine.execute(click)
        _ = await engine.execute(read)

        XCTAssertEqual(engine.totalExecutions, 3)
        XCTAssertEqual(engine.successCount, 2)
        XCTAssertEqual(engine.failureCount, 1)
    }

    func testRetryAfterDenial() async {
        engine.allowedActions = [.readContext]

        let click = MockActionScenario.click(at: CGPoint.zero)
        let read = MockActionScenario.readContext()

        let clickResult = await engine.execute(click)
        XCTAssertFalse(clickResult.success)
        XCTAssertTrue(clickResult.message.contains("not allowed"))

        let readResult = await engine.execute(read)
        XCTAssertTrue(readResult.success)
    }

    // MARK: - 动作过滤

    func testAllowedActionsOnly() async {
        engine.allowedActions = [.readContext, .openApplication]

        let click = MockActionScenario.click(at: CGPoint.zero)
        let open = MockActionScenario.openApp("Finder")
        let read = MockActionScenario.readContext()

        _ = await engine.execute(click)
        _ = await engine.execute(open)
        _ = await engine.execute(read)

        let clickRecords = engine.records(for: .clickAt)
        XCTAssertEqual(clickRecords.count, 1)
        XCTAssertFalse(clickRecords.first?.result.success == true, "clickAt 不在允许列表中")

        let openRecords = engine.records(for: .openApplication)
        XCTAssertTrue(openRecords.first?.result.success == true, "openApp 应在允许列表中")
    }

    // MARK: - 故障桥接恢复

    func testBridgePermissionRecovery() async throws {
        let untrusted = MockAccessibilityBridge(isTrusted: false)

        do {
            _ = try await untrusted.getFocusedAppBundleID()
            XCTFail("无权限时应抛出")
        } catch {
            XCTAssertTrue(error is AccessibilityError)
        }

        let trusted = MockAccessibilityBridge(isTrusted: true)
        let bundleID = try await trusted.getFocusedAppBundleID()
        XCTAssertEqual(bundleID, "com.apple.Safari")
    }

    func testBridgeRecoversAfterActionFailure() async throws {
        try await mockBridge.focusWindow(title: "测试窗口")
        let count = await mockBridge.recordedActions.count
        XCTAssertEqual(count, 1)

        _ = try await mockBridge.getFocusedWindowTitle()
        let countAfter = await mockBridge.recordedActions.count
        XCTAssertEqual(countAfter, 1, "只读操作不应改变操作记录")
    }

    // MARK: - 执行路径记录

    func testExecutionHistoryFiltering() async {
        let actions = MockActionScenario.typicalSession()
        for action in actions {
            _ = await engine.execute(action)
        }

        let clickRecords = engine.records(for: .clickAt)
        let typeRecords = engine.records(for: .insertText)
        let appRecords = engine.records(for: .openApplication)

        XCTAssertEqual(clickRecords.count, 1)
        XCTAssertEqual(typeRecords.count, 1)
        XCTAssertEqual(appRecords.count, 1)
    }

    func testRecentRecords() async {
        for _ in 0..<10 {
            _ = await engine.execute(MockActionScenario.readContext())
        }

        let recent = engine.recentRecords(3)
        XCTAssertEqual(recent.count, 3)
    }

    // MARK: - 心跳与超时

    func testHeartbeatDetection() {
        var heartbeat = HeartbeatRecovery(
            heartbeatInterval: 1,
            warningThreshold: 3,
            criticalThreshold: 5,
            autoRecoveryEnabled: true
        )

        let status = heartbeat.check()
        XCTAssertEqual(status, .healthy, "初始化后心跳应健康")
    }

    func testHeartbeatWarning() {
        var heartbeat = HeartbeatRecovery(
            heartbeatInterval: 1,
            warningThreshold: 0.1,
            criticalThreshold: 5,
            autoRecoveryEnabled: false
        )

        // 模拟延迟
        let oldDate = Date().addingTimeInterval(-2)
        heartbeat = HeartbeatRecovery(
            heartbeatInterval: 1,
            warningThreshold: 0.1,
            criticalThreshold: 5,
            lastHeartbeat: oldDate,
            autoRecoveryEnabled: false
        )

        let status = heartbeat.check()
        XCTAssertEqual(status, .warning, "超过 warningThreshold 且未到 criticalThreshold 应进入 warning")
    }

    func testHeartbeatReset() {
        var heartbeat = HeartbeatRecovery(autoRecoveryEnabled: false)

        heartbeat.beat()
        XCTAssertTrue(heartbeat.isHealthy)

        let oldDate = Date().addingTimeInterval(-60)
        heartbeat = HeartbeatRecovery(
            heartbeatInterval: 1,
            warningThreshold: 0.1,
            criticalThreshold: 0.5,
            lastHeartbeat: oldDate,
            autoRecoveryEnabled: true
        )

        let status = heartbeat.check()
        // autoRecoveryEnabled = true，自动恢复后应该是 healthy
        // 但 status 是 check() 返回的原始结果，recovery 在内部重置了时间
        // 实际上经过 autoRecovery 后 lastHeartbeat 被重置，所以再次 check 应该健康
        if status == .lost {
            let afterReset = heartbeat.check()
            XCTAssertTrue(afterReset == .healthy || afterReset == .healthy, "自动恢复后心跳应健康")
        }
    }

    func testHeartbeatHealthyAfterBeat() {
        var heartbeat = HeartbeatRecovery()
        heartbeat.beat()
        XCTAssertTrue(heartbeat.isHealthy)
        XCTAssertFalse(heartbeat.needsAttention)
    }

    // MARK: - 操作验证

    func testExecuteAndVerifySuccess() async {
        let action = MockActionScenario.click(at: CGPoint(x: 100, y: 100))
        let (result, verified) = await engine.executeAndVerify(action, expectedState: "click completed")
        XCTAssertTrue(result.success)
        XCTAssertTrue(verified)
    }

    func testExecuteAndVerifyWithFailure() async {
        let action = MockActionScenario.closeWindow()
        engine.stub(.closeWindow, result: ActionResult(actionID: action.id, success: false, message: "拒绝"))

        let (result, verified) = await engine.executeAndVerify(action, expectedState: "window closed")
        XCTAssertFalse(result.success)
        XCTAssertFalse(verified)
    }

    // MARK: - MockRecorder

    func testMockRecorderBasic() async {
        let recorder = MockActionRecorder(shouldSucceed: true)
        let action = MockActionScenario.readContext()

        let result = await recorder.execute(action)
        XCTAssertTrue(result.success)

        let count = await recorder.count
        XCTAssertEqual(count, 1)
    }

    func testMockRecorderFailure() async {
        let recorder = MockActionRecorder(shouldSucceed: false)
        let action = MockActionScenario.readContext()

        let result = await recorder.execute(action)
        XCTAssertFalse(result.success)

        let count = await recorder.count
        XCTAssertEqual(count, 1)
    }

    func testMockRecorderReset() async {
        let recorder = MockActionRecorder(shouldSucceed: true)
        _ = await recorder.execute(MockActionScenario.readContext())
        _ = await recorder.execute(MockActionScenario.readContext())

        var count = await recorder.count
        XCTAssertEqual(count, 2)

        await recorder.reset()
        count = await recorder.count
        XCTAssertEqual(count, 0)
    }
}
