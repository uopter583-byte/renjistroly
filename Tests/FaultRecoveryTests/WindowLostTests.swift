import XCTest
@testable import RenJistrolySystemBridge
@testable import RenJistrolyModels

// MARK: - Mock 窗口状态

private struct WindowSnapshot: Equatable {
    let title: String
    let bundleID: String
    let windowID: UInt32
}

private enum WindowRecoveryAction: Equatable {
    case retryOperation
    case rematchWindow(String)
    case promptUser(String)
    case relocateWindow(String)
}

private struct WindowRecoveryResult {
    let recovered: Bool
    let actions: [WindowRecoveryAction]
    let message: String?
}

/// 模拟窗口丢失恢复管理器
private final class MockWindowRecoveryManager {
    /// 初始窗口快照
    var initialWindows: [WindowSnapshot] = []
    /// 当前可用的窗口快照（模拟实时状态）
    var currentWindows: [WindowSnapshot] = []
    /// 目标窗口标题
    var targetWindowTitle: String = "测试窗口"
    /// 目标 app bundle ID
    var targetAppBundleID: String = "com.example.TestApp"
    /// 最大重试次数
    var maxRetries: Int = 3

    private(set) var retryCount: Int = 0
    private(set) var recoveryLog: [WindowRecoveryAction] = []

    /// 在操作期间检查窗口状态并尝试恢复
    func checkAndRecover() async -> WindowRecoveryResult {
        if currentWindows.isEmpty {
            retryCount += 1
            let retryAction = WindowRecoveryAction.retryOperation
            recoveryLog.append(retryAction)
            return WindowRecoveryResult(
                recovered: false,
                actions: [retryAction],
                message: retryCount >= maxRetries ? "重试次数耗尽" : "窗口不可见，第\(retryCount)次重试"
            )
        }

        // 检测目标 app 是否还在
        let appStillRunning = currentWindows.contains { $0.bundleID == targetAppBundleID }
        if !appStillRunning {
            let action = WindowRecoveryAction.promptUser("目标应用已退出，请重新打开后重试")
            recoveryLog.append(action)
            return WindowRecoveryResult(
                recovered: false,
                actions: [action],
                message: "目标应用已退出"
            )
        }

        // 检测目标窗口是否还在
        let sameBundleWindows = currentWindows.filter { $0.bundleID == targetAppBundleID }
        if initialWindows.count > 1 && sameBundleWindows.count == 1 {
            let current = sameBundleWindows[0]
            let matchingInitial = initialWindows.first { $0.title == current.title && $0.bundleID == current.bundleID }
            if matchingInitial?.windowID != current.windowID {
                let relocateAction = WindowRecoveryAction.relocateWindow("窗口已合并到单个窗口")
                recoveryLog.append(relocateAction)
                return WindowRecoveryResult(
                    recovered: true,
                    actions: [relocateAction],
                    message: "多窗口已合并，重新定位到剩余窗口"
                )
            }
        }

        let targetWindowStillExists = currentWindows.contains { $0.title == targetWindowTitle }
        if !targetWindowStillExists {
            // 检查窗口标题是否变化（内容还在但标题改了）
            if sameBundleWindows.count == 1 {
                // 窗口标题已变化 → 重新匹配
                let newTitle = sameBundleWindows[0].title
                let matchAction = WindowRecoveryAction.rematchWindow(newTitle)
                recoveryLog.append(matchAction)
                targetWindowTitle = newTitle
                return WindowRecoveryResult(
                    recovered: true,
                    actions: [matchAction],
                    message: "窗口标题已变为「\(newTitle)」，已重新匹配"
                )
            }

            retryCount += 1
            return WindowRecoveryResult(
                recovered: false,
                actions: [.retryOperation],
                message: nil
            )
        }

        // 窗口正常存在
        return WindowRecoveryResult(
            recovered: true,
            actions: [],
            message: nil
        )
    }

    func resetRetries() {
        retryCount = 0
        recoveryLog.removeAll()
    }
}

// MARK: - WindowLostTests

final class WindowLostTests: XCTestCase {

    /// 操作期间窗口被关闭 → 检测 + 重试
    func testWindowClosedDuringOperationTriggersRetry() async {
        let manager = MockWindowRecoveryManager()
        manager.targetWindowTitle = "文档编辑"
        manager.initialWindows = [
            WindowSnapshot(title: "文档编辑", bundleID: "com.example.TextEdit", windowID: 1),
        ]
        manager.currentWindows = [] // 窗口被关闭

        let result = await manager.checkAndRecover()

        XCTAssertFalse(result.recovered, "窗口关闭后首次应未恢复")
        XCTAssertEqual(manager.retryCount, 1, "应触发一次重试")
        XCTAssertEqual(result.actions.first, .retryOperation)
    }

    /// 窗口标题变化 → 重新匹配
    func testWindowTitleChangeTriggersRematch() async {
        let manager = MockWindowRecoveryManager()
        manager.targetWindowTitle = "旧标题"
        manager.initialWindows = [
            WindowSnapshot(title: "旧标题", bundleID: "com.example.TestApp", windowID: 1),
        ]
        manager.currentWindows = [
            WindowSnapshot(title: "新标题", bundleID: "com.example.TestApp", windowID: 1),
        ]

        let result = await manager.checkAndRecover()

        XCTAssertTrue(result.recovered, "标题变化后应成功重新匹配")
        XCTAssertEqual(result.actions.first, .rematchWindow("新标题"))
        XCTAssertEqual(manager.targetWindowTitle, "新标题", "应更新目标窗口标题")
    }

    /// 目标 app 退出 → 检测 + 提示
    func testTargetAppExitsPromptsUser() async {
        let manager = MockWindowRecoveryManager()
        manager.targetAppBundleID = "com.example.TargetApp"
        manager.initialWindows = [
            WindowSnapshot(title: "工作窗口", bundleID: "com.example.TargetApp", windowID: 1),
        ]
        manager.currentWindows = [
            WindowSnapshot(title: "其他窗口", bundleID: "com.example.OtherApp", windowID: 2),
        ]

        let result = await manager.checkAndRecover()

        XCTAssertFalse(result.recovered, "应用退出后无法自动恢复")
        XCTAssertTrue(result.message?.contains("已退出") ?? false, "应提示应用已退出")
        XCTAssertEqual(result.actions.first, .promptUser("目标应用已退出，请重新打开后重试"))
    }

    /// 多窗口合并（两个窗口变一个）→ 重新定位
    func testMultiWindowMergeRelocates() async {
        let manager = MockWindowRecoveryManager()
        manager.targetWindowTitle = "主窗口"
        manager.initialWindows = [
            WindowSnapshot(title: "主窗口", bundleID: "com.example.TestApp", windowID: 1),
            WindowSnapshot(title: "副窗口", bundleID: "com.example.TestApp", windowID: 2),
        ]
        manager.currentWindows = [
            WindowSnapshot(title: "主窗口", bundleID: "com.example.TestApp", windowID: 3), // 合并后新 ID
        ]

        let result = await manager.checkAndRecover()

        XCTAssertTrue(result.recovered, "窗口合并后应重新定位")
        XCTAssertEqual(result.actions.first, .relocateWindow("窗口已合并到单个窗口"))
    }

    /// 多次重试后恢复
    func testRetryExhaustion() async {
        let manager = MockWindowRecoveryManager()
        manager.maxRetries = 2
        manager.targetWindowTitle = "临时窗口"
        manager.currentWindows = []

        // 第一次重试
        var result = await manager.checkAndRecover()
        XCTAssertFalse(result.recovered)
        XCTAssertEqual(manager.retryCount, 1)

        // 第二次重试（耗尽）
        result = await manager.checkAndRecover()
        XCTAssertFalse(result.recovered)
        XCTAssertEqual(manager.retryCount, 2)

        // 超过最大重试
        result = await manager.checkAndRecover()
        XCTAssertFalse(result.recovered)
        XCTAssertTrue(result.message?.contains("耗尽") ?? false, "应提示重试次数耗尽")
    }
}
