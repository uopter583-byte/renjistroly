import Foundation
import XCTest
@testable import RenJistrolyModels

// MARK: - ModeSwitchTests

/// 模式切换测试。
/// 验证 AppMode 状态机：compact → expanded → immersive 的切换合法性。
final class ModeSwitchTests: XCTestCase {

    private var manager: MockModeManager!

    override func setUp() {
        super.setUp()
        manager = MockModeManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - 基础切换

    func testInitialModeIsCompact() {
        XCTAssertEqual(manager.currentMode, .compact, "初始模式应为 compact")
    }

    func testSwitchToExpanded() {
        XCTAssertTrue(manager.switchTo(.expanded))
        XCTAssertEqual(manager.currentMode, .expanded)
    }

    func testSwitchToImmersive() {
        XCTAssertTrue(manager.switchTo(.immersive))
        XCTAssertEqual(manager.currentMode, .immersive)
    }

    func testSwitchToCompact() {
        manager.switchTo(.expanded)
        manager.switchTo(.immersive)
        XCTAssertTrue(manager.switchTo(.compact))
        XCTAssertEqual(manager.currentMode, .compact)
    }

    // MARK: - 切换历史

    func testTransitionHistoryAfterSwitch() {
        manager.switchTo(.expanded)
        XCTAssertEqual(manager.transitionCount, 1)

        let last = manager.lastTransition
        XCTAssertNotNil(last)
        XCTAssertEqual(last?.from, .compact)
        XCTAssertEqual(last?.to, .expanded)
        XCTAssertTrue(last?.success == true)
    }

    func testTransitionHistoryMultipleSwitches() throws {
        try MockModeScenario.standardCycle(manager: manager)

        XCTAssertEqual(manager.transitionCount, 3)
        XCTAssertEqual(manager.lastTransition?.to, .compact)
        XCTAssertEqual(manager.successCount, 3)
    }

    func testTransitionHistoryOrder() {
        manager.switchTo(.expanded)
        manager.switchTo(.immersive)

        let history = manager.transitionHistory
        XCTAssertEqual(history[0].from, .compact)
        XCTAssertEqual(history[0].to, .expanded)
        XCTAssertEqual(history[1].from, .expanded)
        XCTAssertEqual(history[1].to, .immersive)
    }

    // MARK: - 非法切换

    func testSwitchToDisallowedMode() {
        manager.allowedTransitions = [.compact]
        XCTAssertFalse(manager.switchTo(.expanded), "expanded 被禁用时切换应失败")
        XCTAssertEqual(manager.currentMode, .compact, "当前模式不应改变")
    }

    func testSwitchToImmersiveWhenDisallowed() throws {
        try MockModeScenario.rejectedTransition(manager: manager)
        XCTAssertEqual(manager.currentMode, .expanded, "切换被拒后应保持在 expanded")
    }

    func testFailureScenario() throws {
        try MockModeScenario.failureScenario(manager: manager)
        XCTAssertEqual(manager.transitionCount, 1)
        XCTAssertFalse(manager.lastTransition?.success == true, "故障模式下切换应失败")
    }

    // MARK: - 切换序列验证

    func testValidTransitionSequence() {
        manager.switchTo(.expanded)
        manager.switchTo(.immersive)
        manager.switchTo(.compact)

        XCTAssertTrue(manager.validateTransitionSequence(), "合法切换序列应通过验证")
    }

    func testInvalidTransitionSequence() {
        manager.switchTo(.expanded)
        manager.switchTo(.expanded) // 重复切换到同一模式

        XCTAssertFalse(manager.validateTransitionSequence(), "不合法序列应验证失败")
    }

    func testSkippedTransitionStillValid() {
        manager.switchTo(.expanded)
        manager.switchTo(.compact)

        XCTAssertTrue(manager.validateTransitionSequence(), "跳过 immersive 也是合法序列")
    }

    // MARK: - isExpanded

    func testIsExpandedCompact() {
        XCTAssertFalse(manager.isExpanded)
    }

    func testIsExpandedAfterSwitch() {
        manager.switchTo(.expanded)
        XCTAssertTrue(manager.isExpanded)
    }

    func testIsExpandedAfterImmersive() {
        manager.switchTo(.immersive)
        XCTAssertTrue(manager.isExpanded)
    }

    // MARK: - 重置

    func testReset() {
        manager.switchTo(.expanded)
        manager.switchTo(.immersive)
        XCTAssertEqual(manager.transitionCount, 2)

        manager.reset()
        XCTAssertEqual(manager.currentMode, .compact)
        XCTAssertTrue(manager.transitionHistory.isEmpty)
        XCTAssertTrue(manager.canSwitch)
    }

    // MARK: - CanSwitch 控制

    func testCanSwitchFalse() {
        manager.canSwitch = false
        XCTAssertFalse(manager.switchTo(.expanded))
        XCTAssertEqual(manager.currentMode, .compact)
    }

    func testCanSwitchToggle() {
        manager.canSwitch = false
        XCTAssertFalse(manager.switchTo(.expanded))

        manager.canSwitch = true
        XCTAssertTrue(manager.switchTo(.expanded))
        XCTAssertEqual(manager.currentMode, .expanded)
    }
}

// MARK: - VoiceInputState 状态机测试

final class VoiceStateMachineTests: XCTestCase {

    private var voiceManager: MockVoiceStateManager!

    override func setUp() {
        super.setUp()
        voiceManager = MockVoiceStateManager()
    }

    override func tearDown() {
        voiceManager = nil
        super.tearDown()
    }

    func testInitialState() {
        XCTAssertEqual(voiceManager.currentState, .idle)
        XCTAssertTrue(voiceManager.idleTime)
        XCTAssertFalse(voiceManager.isCapturing)
    }

    func testIdleToListening() {
        XCTAssertTrue(voiceManager.transition(to: .listening))
        XCTAssertEqual(voiceManager.currentState, .listening)
        XCTAssertTrue(voiceManager.isCapturing)
    }

    func testListeningToTranscribing() {
        voiceManager.transition(to: .listening)
        XCTAssertTrue(voiceManager.transition(to: .transcribing))
        XCTAssertTrue(voiceManager.isCapturing)
    }

    func testTranscribingToProcessing() {
        voiceManager.transition(to: .listening)
        voiceManager.transition(to: .transcribing)
        XCTAssertTrue(voiceManager.transition(to: .processing))
        XCTAssertFalse(voiceManager.isCapturing)
    }

    func testProcessingToSpeaking() {
        voiceManager.transition(to: .listening)
        voiceManager.transition(to: .transcribing)
        voiceManager.transition(to: .processing)
        XCTAssertTrue(voiceManager.transition(to: .speaking))
    }

    func testCompleteCycle() {
        voiceManager.transition(to: .listening)
        voiceManager.transition(to: .transcribing)
        voiceManager.transition(to: .processing)
        voiceManager.transition(to: .speaking)
        XCTAssertTrue(voiceManager.transition(to: .idle))

        XCTAssertEqual(voiceManager.currentState, .idle)
        XCTAssertEqual(voiceManager.changeCount, 6) // idle + 5 transitions
    }

    func testInvalidTransition() {
        XCTAssertFalse(voiceManager.transition(to: .speaking), "idle → speaking 非法")
        XCTAssertEqual(voiceManager.changeCount, 1, "非法切换时状态数不应增加")
    }

    func testFailedState() {
        voiceManager.transition(to: .listening)
        XCTAssertTrue(voiceManager.transition(to: .failed))
        XCTAssertEqual(voiceManager.currentState, .failed)
    }

    func testRecoverFromFailed() {
        voiceManager.transition(to: .listening)
        voiceManager.transition(to: .failed)
        XCTAssertTrue(voiceManager.transition(to: .idle), "从 failed 可以恢复到 idle")
        XCTAssertEqual(voiceManager.currentState, .idle)
    }

    func testCanStartAndFinish() {
        voiceManager.canStartListeningResult = true
        voiceManager.canFinishListeningResult = true

        XCTAssertTrue(voiceManager.canStart)
        XCTAssertFalse(voiceManager.canFinish) // 当前 idle

        voiceManager.transition(to: .listening)
        XCTAssertTrue(voiceManager.canFinish)
    }

    func testReset() {
        voiceManager.transition(to: .listening)
        voiceManager.transition(to: .transcribing)
        voiceManager.reset()

        XCTAssertEqual(voiceManager.currentState, .idle)
        XCTAssertEqual(voiceManager.changeCount, 1)
    }
}
