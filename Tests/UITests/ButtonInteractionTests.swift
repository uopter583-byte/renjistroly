import Foundation
import XCTest
@testable import RenJistrolyModels
@testable import RenJistrolySystemBridge
@testable import RenJistrolyCapability
@testable import RenJistrolyEnterprise

// MARK: - VoiceInputState 状态机属性测试
//
// VoiceButton 的 pushToTalk (onLongPressGesture) 和 alwaysOn (Button)
// 依赖 VoiceInputState 的 computed properties 来决定行为。
// 本测试验证所有状态的属性正确性。

final class VoiceInputStatePropertyTests: XCTestCase {

    // MARK: - isCapturingAudio

    func testIsCapturingAudio_listening() {
        XCTAssertTrue(VoiceInputState.listening.isCapturingAudio)
    }

    func testIsCapturingAudio_lockedListening() {
        XCTAssertTrue(VoiceInputState.lockedListening.isCapturingAudio)
    }

    func testIsCapturingAudio_transcribing() {
        XCTAssertTrue(VoiceInputState.transcribing.isCapturingAudio)
    }

    func testIsCapturingAudio_idle() {
        XCTAssertFalse(VoiceInputState.idle.isCapturingAudio)
    }

    func testIsCapturingAudio_requestingPermission() {
        XCTAssertFalse(VoiceInputState.requestingPermission.isCapturingAudio)
    }

    func testIsCapturingAudio_processing() {
        XCTAssertFalse(VoiceInputState.processing.isCapturingAudio)
    }

    func testIsCapturingAudio_speaking() {
        XCTAssertFalse(VoiceInputState.speaking.isCapturingAudio)
    }

    func testIsCapturingAudio_failed() {
        XCTAssertFalse(VoiceInputState.failed.isCapturingAudio)
    }

    // MARK: - canStartListening

    func testCanStartListening_idle() {
        XCTAssertTrue(VoiceInputState.idle.canStartListening)
    }

    func testCanStartListening_failed() {
        XCTAssertTrue(VoiceInputState.failed.canStartListening,
                       "从失败状态可恢复开始监听")
    }

    func testCanStartListening_listening() {
        XCTAssertFalse(VoiceInputState.listening.canStartListening)
    }

    func testCanStartListening_lockedListening() {
        XCTAssertFalse(VoiceInputState.lockedListening.canStartListening)
    }

    func testCanStartListening_transcribing() {
        XCTAssertFalse(VoiceInputState.transcribing.canStartListening)
    }

    func testCanStartListening_processing() {
        XCTAssertFalse(VoiceInputState.processing.canStartListening)
    }

    func testCanStartListening_speaking() {
        XCTAssertFalse(VoiceInputState.speaking.canStartListening)
    }

    func testCanStartListening_requestingPermission() {
        XCTAssertFalse(VoiceInputState.requestingPermission.canStartListening)
    }

    // MARK: - canFinishListening

    func testCanFinishListening_listening() {
        XCTAssertTrue(VoiceInputState.listening.canFinishListening)
    }

    func testCanFinishListening_lockedListening() {
        XCTAssertTrue(VoiceInputState.lockedListening.canFinishListening)
    }

    func testCanFinishListening_transcribing() {
        XCTAssertTrue(VoiceInputState.transcribing.canFinishListening)
    }

    func testCanFinishListening_idle() {
        XCTAssertFalse(VoiceInputState.idle.canFinishListening)
    }

    func testCanFinishListening_requestingPermission() {
        XCTAssertFalse(VoiceInputState.requestingPermission.canFinishListening)
    }

    func testCanFinishListening_processing() {
        XCTAssertFalse(VoiceInputState.processing.canFinishListening)
    }

    func testCanFinishListening_speaking() {
        XCTAssertFalse(VoiceInputState.speaking.canFinishListening)
    }

    func testCanFinishListening_failed() {
        XCTAssertFalse(VoiceInputState.failed.canFinishListening)
    }

    // MARK: - isActive

    func testIsActive_idle() {
        XCTAssertFalse(VoiceInputState.idle.isActive)
    }

    func testIsActive_listening() {
        XCTAssertTrue(VoiceInputState.listening.isActive)
    }

    func testIsActive_lockedListening() {
        XCTAssertTrue(VoiceInputState.lockedListening.isActive)
    }

    func testIsActive_transcribing() {
        XCTAssertTrue(VoiceInputState.transcribing.isActive)
    }

    func testIsActive_processing() {
        XCTAssertTrue(VoiceInputState.processing.isActive)
    }

    func testIsActive_speaking() {
        XCTAssertTrue(VoiceInputState.speaking.isActive)
    }

    func testIsActive_failed() {
        XCTAssertTrue(VoiceInputState.failed.isActive, "failed 仍是活跃状态")
    }

    func testIsActive_requestingPermission() {
        XCTAssertTrue(VoiceInputState.requestingPermission.isActive)
    }

    // MARK: - RawRepresentable

    func testAllStatesRoundtripViaRawValue() {
        let all: [VoiceInputState] = [
            .idle, .requestingPermission, .listening, .lockedListening,
            .transcribing, .processing, .speaking, .failed
        ]
        for state in all {
            let raw = state.rawValue
            let restored = VoiceInputState(rawValue: raw)
            XCTAssertEqual(restored, state, "rawValue 往返失败: \(raw)")
        }
    }

    // MARK: - Codable

    func testAllStatesCodableRoundtrip() throws {
        let all: [VoiceInputState] = [
            .idle, .requestingPermission, .listening, .lockedListening,
            .transcribing, .processing, .speaking, .failed
        ]
        let data = try JSONEncoder().encode(all)
        let decoded = try JSONDecoder().decode([VoiceInputState].self, from: data)
        XCTAssertEqual(decoded, all)
    }
}

// MARK: - AppState 按钮操作测试

@MainActor
final class AppStateButtonActionTests: XCTestCase {

    // MARK: - completeOnboarding

    func testCompleteOnboardingSetsState() {
        let appState = AppState()
        appState.hasCompletedOnboarding = false

        appState.completeOnboarding()

        XCTAssertTrue(appState.hasCompletedOnboarding,
                      "completeOnboarding 后 hasCompletedOnboarding 应为 true")
    }

    func testCompleteOnboardingPersistsToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "appstate.onboarding")

        let appState = AppState()
        appState.completeOnboarding()

        XCTAssertTrue(defaults.bool(forKey: "appstate.onboarding"),
                      "completeOnboarding 应持久化到 UserDefaults")
    }

    // MARK: - PermissionGrant

    func testPermissionGrantAllFalseByDefault() {
        let grant = AppState.PermissionGrant()
        XCTAssertFalse(grant.accessibility)
        XCTAssertFalse(grant.microphone)
        XCTAssertFalse(grant.speechRecognition)
        XCTAssertFalse(grant.screenRecording)
        XCTAssertFalse(grant.appleEvents)
        XCTAssertFalse(grant.allGranted)
    }

    func testPermissionGrantAllGrantedRequiresAll() {
        var grant = AppState.PermissionGrant()
        grant.accessibility = true
        grant.microphone = true
        grant.speechRecognition = true
        grant.screenRecording = true
        grant.appleEvents = true
        XCTAssertTrue(grant.allGranted)
    }

    func testPermissionGrantPartialNotAllGranted() {
        var grant = AppState.PermissionGrant()
        grant.accessibility = true
        grant.microphone = false
        grant.speechRecognition = true
        grant.screenRecording = false
        grant.appleEvents = true
        XCTAssertFalse(grant.allGranted, "部分授权不应返回 allGranted")
    }

    func testPermissionGrantCodableRoundtrip() throws {
        var grant = AppState.PermissionGrant()
        grant.accessibility = true
        grant.screenRecording = true

        let data = try JSONEncoder().encode(grant)
        let decoded = try JSONDecoder().decode(AppState.PermissionGrant.self, from: data)

        XCTAssertTrue(decoded.accessibility)
        XCTAssertFalse(decoded.microphone)
        XCTAssertTrue(decoded.screenRecording)
        XCTAssertFalse(decoded.appleEvents)
    }

    func testPermissionGrantHashable() {
        let a = AppState.PermissionGrant()
        let b = AppState.PermissionGrant()
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - isPermissionGranted button-driven change

    func testAppStatePermissionToggleSequence() {
        let appState = AppState()
        XCTAssertFalse(appState.isPermissionGranted.allGranted)

        // 模拟用户逐一授权
        appState.isPermissionGranted.accessibility = true
        XCTAssertFalse(appState.isPermissionGranted.allGranted)

        appState.isPermissionGranted.microphone = true
        appState.isPermissionGranted.speechRecognition = true
        appState.isPermissionGranted.screenRecording = true
        appState.isPermissionGranted.appleEvents = true

        XCTAssertTrue(appState.isPermissionGranted.allGranted,
                      "所有权限授权后 allGranted 应为 true")
    }

    // MARK: - AppMode defaults

    func testAppStateInitialMode() {
        let appState = AppState()
        XCTAssertEqual(appState.mode, .compact, "初始模式应为 compact")
    }

    func testAppStateModeTransitionCompactToExpanded() {
        let appState = AppState()
        appState.mode = .expanded
        XCTAssertEqual(appState.mode, .expanded)
    }

    func testAppStateModeTransitionExpandedToImmersive() {
        let appState = AppState()
        appState.mode = .expanded
        appState.mode = .immersive
        XCTAssertEqual(appState.mode, .immersive)
    }
}

// MARK: - VoiceInteractionMode 枚举测试
//
// SettingsPanel 使用 VoiceInteractionMode 的 picker 来控制
// VoiceButton 的交互方式（push-to-talk vs always-on）。

final class VoiceInteractionModeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(VoiceInteractionMode.allCases.count, 2)
        XCTAssertTrue(VoiceInteractionMode.allCases.contains(.pushToTalk))
        XCTAssertTrue(VoiceInteractionMode.allCases.contains(.alwaysOn))
    }

    func testTitlePushToTalk() {
        XCTAssertEqual(VoiceInteractionMode.pushToTalk.title, "按键录音")
    }

    func testTitleAlwaysOn() {
        XCTAssertEqual(VoiceInteractionMode.alwaysOn.title, "一直录音")
    }

    func testIdentifiable() {
        XCTAssertEqual(VoiceInteractionMode.pushToTalk.id, "pushToTalk")
        XCTAssertEqual(VoiceInteractionMode.alwaysOn.id, "alwaysOn")
    }

    func testCodableRoundtrip() throws {
        let all = VoiceInteractionMode.allCases
        let data = try JSONEncoder().encode(all)
        let decoded = try JSONDecoder().decode([VoiceInteractionMode].self, from: data)
        XCTAssertEqual(decoded, all)
    }

    func testSendable() {
        // 编译时检查：Sendable 类型可以跨 actor 传递
        let mode: VoiceInteractionMode = .pushToTalk
        let expectation = self.expectation(description: "sendable")
        Task {
            let copy = mode
            XCTAssertEqual(copy, .pushToTalk)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}

// MARK: - VoiceSubmitMode 枚举测试
//
// SettingsPanel 使用 VoiceSubmitMode 的 segmented picker 控制发送方式。

final class VoiceSubmitModeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(VoiceSubmitMode.allCases.count, 2)
        XCTAssertTrue(VoiceSubmitMode.allCases.contains(.manual))
        XCTAssertTrue(VoiceSubmitMode.allCases.contains(.automatic))
    }

    func testTitleManual() {
        XCTAssertEqual(VoiceSubmitMode.manual.title, "手动停止发送")
    }

    func testTitleAutomatic() {
        XCTAssertEqual(VoiceSubmitMode.automatic.title, "停顿自动发送")
    }

    func testIdentifiable() {
        XCTAssertEqual(VoiceSubmitMode.manual.id, "manual")
        XCTAssertEqual(VoiceSubmitMode.automatic.id, "automatic")
    }

    func testCodableRoundtrip() throws {
        let all = VoiceSubmitMode.allCases
        let data = try JSONEncoder().encode(all)
        let decoded = try JSONDecoder().decode([VoiceSubmitMode].self, from: data)
        XCTAssertEqual(decoded, all)
    }
}

// MARK: - HotkeyPreset 枚举测试
//
// SettingsPanel 使用 HotkeyPreset 的 segmented picker。

final class HotkeyPresetTests: XCTestCase {

    func testAllCases() {
        let all = HotkeyPreset.allCases
        XCTAssertEqual(all.count, 5)
    }

    func testSelectableCasesOnlyShowsThree() {
        let selectable = HotkeyPreset.selectableCases
        XCTAssertEqual(selectable.count, 3)
        XCTAssertTrue(selectable.contains(.controlOptionSpace))
        XCTAssertTrue(selectable.contains(.optionCommandSpace))
        XCTAssertTrue(selectable.contains(.commandShiftSpace))
        XCTAssertFalse(selectable.contains(.controlSpace))
        XCTAssertFalse(selectable.contains(.optionSpace))
    }

    func testTitleForAllCases() {
        for preset in HotkeyPreset.allCases {
            XCTAssertFalse(preset.title.isEmpty, "title 不应为空: \(preset)")
        }
    }

    func testTitleControlOptionSpace() {
        XCTAssertEqual(HotkeyPreset.controlOptionSpace.title, "⌃⌥Space")
    }

    func testTitleOptionCommandSpace() {
        XCTAssertEqual(HotkeyPreset.optionCommandSpace.title, "⌥⌘Space")
    }

    func testTitleCommandShiftSpace() {
        XCTAssertEqual(HotkeyPreset.commandShiftSpace.title, "⇧⌘Space")
    }

    func testIdentifiable() {
        for preset in HotkeyPreset.allCases {
            XCTAssertEqual(preset.id, preset.rawValue, "Identifiable id 应与 rawValue 一致")
        }
    }

    func testCodableRoundtrip() throws {
        let all = HotkeyPreset.allCases
        let data = try JSONEncoder().encode(all)
        let decoded = try JSONDecoder().decode([HotkeyPreset].self, from: data)
        XCTAssertEqual(decoded, all)
    }
}

// MARK: - OCREngine 枚举测试
//
// AppState 和 SettingsPanel 通过 OCREngine 控制 OCR 引擎选择。

final class OCREngineTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(OCREngine.allCases.count, 3)
        XCTAssertTrue(OCREngine.allCases.contains(.appleVision))
        XCTAssertTrue(OCREngine.allCases.contains(.ppocrV6))
        XCTAssertTrue(OCREngine.allCases.contains(.both))
    }

    func testDisplayNameAppleVision() {
        XCTAssertEqual(OCREngine.appleVision.displayName, "Apple Vision")
    }

    func testDisplayNamePPOCR() {
        XCTAssertEqual(OCREngine.ppocrV6.displayName, "PP-OCRv6 (ONNX)")
    }

    func testDisplayNameBoth() {
        XCTAssertEqual(OCREngine.both.displayName, "双引擎合并")
    }

    func testCodableRoundtrip() throws {
        let all = OCREngine.allCases
        let data = try JSONEncoder().encode(all)
        let decoded = try JSONDecoder().decode([OCREngine].self, from: data)
        XCTAssertEqual(decoded, all)
    }
}

// MARK: - LLMProvider 枚举测试
//
// 影响 ModeControlPanel 和 SettingsPanel 中的 LLM 选择器。

final class LLMProviderTests: XCTestCase {

    func testAllCases() {
        let providers = LLMProvider.allCases
        // 核心 16+ providers
        XCTAssertGreaterThanOrEqual(providers.count, 16)
        XCTAssertTrue(providers.contains(.claudeCodeCLI))
        XCTAssertTrue(providers.contains(.anthropic))
        XCTAssertTrue(providers.contains(.openAI))
        XCTAssertTrue(providers.contains(.google))
    }

    func testDisplayNameForAllCases() {
        for provider in LLMProvider.allCases {
            XCTAssertFalse(provider.displayName.isEmpty,
                           "displayName 不应为空: \(provider)")
        }
    }

    func testDisplayNameClaudeCodeCLI() {
        XCTAssertEqual(LLMProvider.claudeCodeCLI.displayName, "Claude Code")
    }

    func testCodableRoundtrip() throws {
        let all = LLMProvider.allCases
        let data = try JSONEncoder().encode(all)
        let decoded = try JSONDecoder().decode([LLMProvider].self, from: data)
        XCTAssertEqual(decoded, all)
    }
}

// MARK: - AppMode 枚举测试

final class AppModeTests: XCTestCase {

    func testAllCases() {
        XCTAssertEqual(AppMode.compact.rawValue, "compact")
        XCTAssertEqual(AppMode.expanded.rawValue, "expanded")
        XCTAssertEqual(AppMode.immersive.rawValue, "immersive")
    }

    func testRawRepresentable() {
        XCTAssertEqual(AppMode.compact.rawValue, "compact")
        XCTAssertEqual(AppMode.expanded.rawValue, "expanded")
        XCTAssertEqual(AppMode.immersive.rawValue, "immersive")

        XCTAssertEqual(AppMode(rawValue: "compact"), .compact)
        XCTAssertEqual(AppMode(rawValue: "expanded"), .expanded)
        XCTAssertEqual(AppMode(rawValue: "immersive"), .immersive)
        XCTAssertNil(AppMode(rawValue: "unknown"))
    }

    func testHashable() {
        let set: Set<AppMode> = [.compact, .expanded, .immersive, .compact]
        XCTAssertEqual(set.count, 3, "重复的 compact 不应增加集合大小")
    }

    func testCodableRoundtrip() throws {
        let all: [AppMode] = [.compact, .expanded, .immersive]
        let data = try JSONEncoder().encode(all)
        let decoded = try JSONDecoder().decode([AppMode].self, from: data)
        XCTAssertEqual(decoded, all)
    }
}

// MARK: - ActionRiskLevel 比较测试
//
// ModeControlPanel 使用 RiskLevel 评估模式卡片风险等级。

final class ActionRiskLevelTests: XCTestCase {

    func testAllLevels() {
        XCTAssertEqual(ActionRiskLevel.readOnly.rawValue, 0)
        XCTAssertEqual(ActionRiskLevel.reversibleInput.rawValue, 1)
        XCTAssertEqual(ActionRiskLevel.persistentOrExternal.rawValue, 2)
        XCTAssertEqual(ActionRiskLevel.destructiveOrSensitive.rawValue, 3)
    }

    func testComparisonReadOnlyIsLowest() {
        XCTAssertLessThan(ActionRiskLevel.readOnly, .reversibleInput)
        XCTAssertLessThan(ActionRiskLevel.readOnly, .persistentOrExternal)
        XCTAssertLessThan(ActionRiskLevel.readOnly, .destructiveOrSensitive)
    }

    func testComparisonDestructiveIsHighest() {
        XCTAssertGreaterThan(ActionRiskLevel.destructiveOrSensitive, .persistentOrExternal)
        XCTAssertGreaterThan(ActionRiskLevel.destructiveOrSensitive, .reversibleInput)
        XCTAssertGreaterThan(ActionRiskLevel.destructiveOrSensitive, .readOnly)
    }

    func testStrictOrdering() {
        let levels: [ActionRiskLevel] = [
            .readOnly, .reversibleInput,
            .persistentOrExternal, .destructiveOrSensitive
        ]
        let sorted = levels.sorted()
        XCTAssertEqual(sorted, [.readOnly, .reversibleInput, .persistentOrExternal, .destructiveOrSensitive])
    }

    func testComparisonConsistency() {
        // 传递性检查
        let a = ActionRiskLevel.readOnly
        let b = ActionRiskLevel.reversibleInput
        let c = ActionRiskLevel.persistentOrExternal
        XCTAssertTrue(a < b && b < c && a < c, "比较应满足传递性")
    }
}

// MARK: - MockModeManager 按钮模拟测试
//
// 验证 ModeControlPanel 中 toggle 按钮触发的模式切换行为。

final class MockModeManagerButtonSimulationTests: XCTestCase {

    private var manager: MockModeManager!

    override func setUp() {
        super.setUp()
        manager = MockModeManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    // MARK: - 模拟按钮点击切换

    func testModeToggleButtonCompactToExpanded() {
        // 模拟点击 "扩展" 按钮
        let result = manager.switchTo(.expanded)
        XCTAssertTrue(result)
        XCTAssertEqual(manager.currentMode, .expanded)
        XCTAssertEqual(manager.transitionCount, 1)
    }

    func testModeToggleButtonExpandedToImmersive() {
        manager.switchTo(.expanded)
        let result = manager.switchTo(.immersive)

        XCTAssertTrue(result)
        XCTAssertEqual(manager.currentMode, .immersive)
        XCTAssertEqual(manager.transitionCount, 2)
    }

    func testModeToggleButtonFullCycle() {
        // 模拟用户连续点击切换按钮
        // compact → expanded → immersive → compact
        XCTAssertTrue(manager.switchTo(.expanded))
        XCTAssertEqual(manager.currentMode, .expanded)

        XCTAssertTrue(manager.switchTo(.immersive))
        XCTAssertEqual(manager.currentMode, .immersive)

        XCTAssertTrue(manager.switchTo(.compact))
        XCTAssertEqual(manager.currentMode, .compact)

        XCTAssertEqual(manager.transitionCount, 3)
        XCTAssertEqual(manager.successCount, 3)
    }

    // MARK: - 快速切换（防抖测试）

    func testRapidModeToggleDoesNotCrash() {
        for _ in 0..<20 {
            _ = manager.switchTo(.expanded)
            _ = manager.switchTo(.compact)
        }
        XCTAssertEqual(manager.transitionCount, 40)
        XCTAssertEqual(manager.successCount, 40)
    }

    func testRapidModeToggleToSameMode() {
        manager.switchTo(.expanded)
        manager.switchTo(.expanded) // 相同模式

        // 允许"切换"被记录，但 validateTransitionSequence 会检测到重复
        XCTAssertEqual(manager.transitionCount, 2)
        XCTAssertFalse(manager.validateTransitionSequence(),
                       "重复切换同一模式应使序列无效")
    }

    // MARK: - 按钮禁用测试

    func testModeButtonWhenDisabled() {
        manager.canSwitch = false

        // 点击模式按钮应无效
        XCTAssertFalse(manager.switchTo(.expanded))
        XCTAssertEqual(manager.currentMode, .compact)
    }

    func testModeButtonEnableAfterDisable() {
        manager.canSwitch = false
        _ = manager.switchTo(.expanded)

        manager.canSwitch = true
        let result = manager.switchTo(.expanded)

        XCTAssertTrue(result)
        XCTAssertEqual(manager.currentMode, .expanded)
        XCTAssertEqual(manager.transitionCount, 2) // 失败的 + 成功的
    }

    func testModeButtonWithAllowedTransitionsReset() {
        // 限制只允许 compact 和 expanded
        manager.allowedTransitions = [.compact, .expanded]
        XCTAssertTrue(manager.switchTo(.expanded))
        XCTAssertFalse(manager.switchTo(.immersive), "immersive 不在允许列表中")

        // 恢复全部允许
        manager.allowedTransitions = [.compact, .expanded, .immersive]
        XCTAssertTrue(manager.switchTo(.immersive))
        XCTAssertEqual(manager.currentMode, .immersive)
    }

    // MARK: - 模式切换场景

    func testStandardCycleScenario() throws {
        try MockModeScenario.standardCycle(manager: manager)
        XCTAssertEqual(manager.currentMode, .compact)
        XCTAssertEqual(manager.successCount, 3)
    }

    func testRejectedTransitionScenario() throws {
        try MockModeScenario.rejectedTransition(manager: manager)
        XCTAssertEqual(manager.currentMode, .expanded)
    }

    func testFailureScenario() throws {
        try MockModeScenario.failureScenario(manager: manager)
        XCTAssertEqual(manager.currentMode, .compact)
    }

    // MARK: - 重置

    func testModeButtonAfterReset() {
        manager.switchTo(.expanded)
        manager.reset()

        // 重置后 compact → expanded 仍应成功
        XCTAssertTrue(manager.switchTo(.expanded))
        XCTAssertEqual(manager.currentMode, .expanded)
        XCTAssertEqual(manager.transitionCount, 1) // 重置后历史已清空
    }
}

// MARK: - MockActionEngine 按钮动作模拟测试
//
// 验证按钮触发的动作执行流程：模拟 PermissionsView/ModeControlPanel 中的按钮。

final class MockActionEngineButtonSimulationTests: XCTestCase {

    private var engine: MockActionEngine!

    override func setUp() {
        super.setUp()
        engine = MockActionEngine()
    }

    override func tearDown() {
        engine = nil
        super.tearDown()
    }

    // MARK: - 按钮触发动作

    func testReadContextButtonTriggersAction() async {
        // 模拟 "读取上下文" 按钮点击
        let action = MockActionScenario.readContext()
        let result = await engine.execute(action)

        XCTAssertTrue(result.success)
        XCTAssertEqual(engine.totalExecutions, 1)
    }

    func testClickButtonTriggersAction() async {
        // 模拟 "点击" 按钮操作
        let action = MockActionScenario.click(at: CGPoint(x: 500, y: 300))
        let result = await engine.execute(action)

        XCTAssertTrue(result.success)
        let records = engine.records(for: .clickAt)
        XCTAssertEqual(records.count, 1)
    }

    func testTypeTextButtonTriggersAction() async {
        // 模拟 "输入文字" 按钮操作
        let action = MockActionScenario.typeText("Hello World")
        let result = await engine.execute(action)

        XCTAssertTrue(result.success)
        let records = engine.records(for: .insertText)
        XCTAssertEqual(records.count, 1)
    }

    // MARK: - 多按钮序列

    func testTypicalSessionButtonSequence() async {
        // 模拟用户依次点击多个按钮
        let actions = MockActionScenario.typicalSession()
        for action in actions {
            let result = await engine.execute(action)
            XCTAssertTrue(result.success, "按钮 \(action.kind) 应执行成功")
        }

        XCTAssertEqual(engine.totalExecutions, 4)
        XCTAssertEqual(engine.successCount, 4)
    }

    func testButtonWithDeniedAction() async {
        // 模拟按钮在禁用模式下被点击
        engine.allowedActions = [.readContext]

        let clickAction = MockActionScenario.click(at: CGPoint.zero)
        let clickResult = await engine.execute(clickAction)

        XCTAssertFalse(clickResult.success)
        XCTAssertTrue(clickResult.message.contains("not allowed"))
    }

    func testButtonThenRecover() async {
        // 模拟按钮执行失败后重试
        let action = MockActionScenario.click(at: CGPoint(x: 100, y: 200))
        engine.stub(.clickAt, result: ActionResult(
            actionID: action.id, success: false, message: "模拟失败"
        ))

        let firstResult = await engine.execute(action)
        XCTAssertFalse(firstResult.success)

        // 清除失败预设，重试
        engine.presetResults.removeValue(forKey: .clickAt)
        let retryResult = await engine.execute(action)
        XCTAssertTrue(retryResult.success)
    }

    // MARK: - 执行历史

    func testButtonClickHistory() async {
        let actions = MockActionScenario.typicalSession()
        for action in actions {
            _ = await engine.execute(action)
        }

        // 检查执行历史
        let recent = engine.recentRecords(2)
        XCTAssertEqual(recent.count, 2)
        XCTAssertEqual(recent[0].action.kind, .insertText)
        XCTAssertEqual(recent[1].action.kind, .openApplication)
    }

    func testButtonMixedSuccessAndFailure() async {
        let read = MockActionScenario.readContext()
        let close = MockActionScenario.closeWindow()

        engine.stub(.closeWindow, result: ActionResult(
            actionID: close.id, success: false, message: "窗口关闭被拒绝"
        ))

        _ = await engine.execute(read)
        _ = await engine.execute(close)

        XCTAssertEqual(engine.totalExecutions, 2)
        XCTAssertEqual(engine.successCount, 1)
        XCTAssertEqual(engine.failureCount, 1)
    }

    func testButtonExecuteAndVerify() async {
        let action = MockActionScenario.readContext()
        let (result, verified) = await engine.executeAndVerify(
            action, expectedState: "context loaded"
        )

        XCTAssertTrue(result.success)
        XCTAssertTrue(verified)
    }

    // MARK: - 按钮动作重置

    func testButtonHistoryReset() async {
        _ = await engine.execute(MockActionScenario.readContext())
        _ = await engine.execute(MockActionScenario.readContext())

        XCTAssertEqual(engine.totalExecutions, 2)

        engine.reset()
        XCTAssertEqual(engine.totalExecutions, 0)
        XCTAssertTrue(engine.executionHistory.isEmpty)
    }

    func testButtonDefaultResultCustomization() async {
        let customEngine = MockActionEngine(
            defaultResult: ActionResult(
                actionID: UUID(),
                success: false,
                message: "自定义默认结果"
            )
        )

        let action = MockActionScenario.readContext()
        let result = await customEngine.execute(action)

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.message, "自定义默认结果")
    }
}

// MARK: - AccessibilityBridge 按钮交互测试
//
// 验证可访问性桥接的按钮操作记录。

final class AccessibilityBridgeButtonTests: XCTestCase {

    private var mockBridge: MockAccessibilityBridge!

    override func setUp() {
        super.setUp()
        mockBridge = MockAccessibilityBridge(
            isTrusted: true,
            mockFocusedBundleID: "com.apple.Safari",
            mockFocusedWindowTitle: "Safari 测试窗口"
        )
    }

    override func tearDown() {
        mockBridge = nil
        super.tearDown()
    }

    // MARK: - 按钮点击

    func testClickButtonRecordsAction() async throws {
        try await mockBridge.click(at: CGPoint(x: 100, y: 200))

        let actions = await mockBridge.recordedActions
        let lastAction = actions.last
        XCTAssertNotNil(lastAction)
        XCTAssertTrue(lastAction?.contains("click") == true)
    }

    func testClickThenTypeButtonSequence() async throws {
        try await mockBridge.click(at: CGPoint(x: 100, y: 100))
        try await mockBridge.typeText("Hello")

        let actions = await mockBridge.recordedActions
        let clickCount = actions.filter { $0.hasPrefix("click") }.count
        let typeCount = actions.filter { $0.hasPrefix("typeText") }.count
        XCTAssertEqual(clickCount, 1)
        XCTAssertEqual(typeCount, 1)
    }

    func testFocusWindowButton() async throws {
        try await mockBridge.focusWindow(title: "测试窗口")

        let actions = await mockBridge.recordedActions
        let lastAction = actions.last
        XCTAssertNotNil(lastAction)
        XCTAssertTrue(lastAction?.contains("focusWindow") == true)
        XCTAssertTrue(lastAction?.contains("测试窗口") == true)
    }

    func testButtonActionsReset() async throws {
        try await mockBridge.click(at: .zero)
        try await mockBridge.typeText("test")
        let countBefore = await mockBridge.recordedActions.count
        XCTAssertGreaterThan(countBefore, 0)

        await mockBridge.resetActions()
        let actions = await mockBridge.recordedActions
        XCTAssertTrue(actions.isEmpty, "resetActions 后记录应清空")
    }

    // MARK: - 权限控制

    func testPermissionDeniedForButtons() async {
        let untrusted = MockAccessibilityBridge(isTrusted: false)

        do {
            try await untrusted.click(at: .zero)
            XCTFail("无权限时点击应抛出")
        } catch {
            XCTAssertTrue(error is AccessibilityError)
        }
    }
}

// MARK: - MockActionRecorder 按钮记录测试

final class MockActionRecorderButtonTests: XCTestCase {

    func testRecordButtonAction() async {
        let recorder = MockActionRecorder(shouldSucceed: true)
        let action = MockActionScenario.readContext()

        let result = await recorder.execute(action)
        XCTAssertTrue(result.success)
        let count = await recorder.count
        XCTAssertEqual(count, 1)
    }

    func testMultipleButtonActionsRecorded() async {
        let recorder = MockActionRecorder(shouldSucceed: true)

        for action in MockActionScenario.typicalSession() {
            _ = await recorder.execute(action)
        }

        let count = await recorder.count
        XCTAssertEqual(count, 4)
    }

    func testButtonActionFailureRecording() async {
        let recorder = MockActionRecorder(shouldSucceed: false)
        let action = MockActionScenario.click(at: CGPoint(x: 10, y: 10))

        let result = await recorder.execute(action)
        XCTAssertFalse(result.success)

        let actions = await recorder.safeActions
        XCTAssertEqual(actions.count, 1)
    }

    func testButtonRecordingReset() async {
        let recorder = MockActionRecorder(shouldSucceed: true)

        _ = await recorder.execute(MockActionScenario.readContext())
        let before = await recorder.count
        XCTAssertEqual(before, 1)

        await recorder.reset()
        let after = await recorder.count
        XCTAssertEqual(after, 0)
    }
}
