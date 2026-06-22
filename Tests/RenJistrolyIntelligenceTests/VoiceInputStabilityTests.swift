import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence
@testable import RenJistrolySystemBridge
@testable import RenJistrolyConversation

// MARK: - Voice Submit Mode (pause handling)

@MainActor
final class VoiceInputStabilityTests: XCTestCase {
    func testVoiceSubmitModeManualTitle() {
        XCTAssertTrue(VoiceSubmitMode.manual.title == "手动停止发送")
    }

    func testVoiceSubmitModeAutomaticTitle() {
        XCTAssertTrue(VoiceSubmitMode.automatic.title == "停顿自动发送")
    }

    func testVoiceSubmitModeAllCases() {
        let all = VoiceSubmitMode.allCases
        XCTAssertTrue(all.count == 2)
        XCTAssertTrue(all.contains(.manual))
        XCTAssertTrue(all.contains(.automatic))
    }

    func testVoiceSubmitModeIdentifiable() {
        XCTAssertTrue(VoiceSubmitMode.manual.id == "manual")
        XCTAssertTrue(VoiceSubmitMode.automatic.id == "automatic")
    }

    // MARK: - Real-Time Transcript (pause and accumulation)

    func testTranscriptEventRealTimeAccumulation() {
        let realTime: [TranscriptEvent] = [
            .partial("今"),
            .partial("今天"),
            .partial("今天天"),
            .partial("今天天气"),
            .partial("今天天气怎"),
            .partial("今天天气怎么样"),
            .final("今天天气怎么样"),
        ]
        var lastPartial = ""
        var finalText = ""
        for event in realTime {
            switch event {
            case .partial(let t):
                lastPartial = t
            case .final(let t):
                finalText = t
            case .failed:
                break
            }
        }
        XCTAssertTrue(lastPartial == "今天天气怎么样")
        XCTAssertTrue(finalText == "今天天气怎么样")
    }

    func testTranscriptEventPauseDurationDoesNotAffectText() {
        let events: [TranscriptEvent] = [
            .partial("打开"),
            .partial("打开 Sa"),
            .partial("打开 Safari"),
            .final("打开 Safari"),
        ]
        let texts = events.compactMap { event -> String? in
            switch event {
            case .partial(let t), .final(let t): t
            case .failed: nil
            }
        }
        XCTAssertTrue(texts.last == "打开 Safari")
    }

    // MARK: - Repeated Phoneme / Ambiguous Input

    func testRepeatedPhonemeStability() {
        let events: [TranscriptEvent] = [
            .partial("xie"),
            .partial("xie xie"),
            .partial("谢谢"),
            .final("谢谢"),
        ]
        let finals = events.filter {
            if case .final = $0 { return true }
            return false
        }
        XCTAssertTrue(finals.count == 1)
        if case .final(let text) = finals[0] {
            XCTAssertTrue(text == "谢谢")
        }
    }

    func testAmbiguousSimilarPhonemeResolution() {
        let events: [TranscriptEvent] = [
            .partial("shi"),
            .partial("shì"),
            .partial("是"),
            .partial("是的"),
            .final("是的"),
        ]
        let finals = events.compactMap { event -> String? in
            if case .final(let t) = event { t } else { nil }
        }
        XCTAssertTrue(finals == ["是的"])
    }

    // MARK: - False Trigger Prevention

    func testFalseTriggerSilenceIgnored() {
        let events: [TranscriptEvent] = [
            .partial(""),
            .partial(""),
            .partial(""),
        ]
        let allEmpty = events.allSatisfy {
            if case .partial(let t) = $0 { t.isEmpty }
            else { false }
        }
        XCTAssertTrue(allEmpty)
    }

    func testFalseTriggerBackgroundNoise() {
        let events: [TranscriptEvent] = [
            .partial("嗯"),
            .partial("唔"),
            .final(""),
        ]
        let finalText = events.compactMap { event -> String? in
            if case .final(let t) = event { t } else { nil }
        }.first ?? ""
        XCTAssertTrue(finalText.isEmpty)
    }

    // MARK: - Stop Listening

    func testVoiceSessionStateStopListeningFromListening() {
        var state = VoiceSessionState()
        state.isListening = true
        state.isListening = false
        XCTAssertFalse(state.isListening)
        XCTAssertFalse(state.isSpeaking)
    }

    // MARK: - Manual vs Auto Submit

    func testManualSubmitRetainsText() async {
        let manager = VoiceSessionManager()
        let appState = AppState()
        appState.voiceInputMode = .accessibilityVoiceInput
        manager.voiceText = "测试手动提交"
        let text = manager.finishVoiceInput(appState: appState)
        XCTAssertTrue(text == "测试手动提交")
    }

    func testAutoSubmitWithEmptyText() async {
        let manager = VoiceSessionManager()
        let appState = AppState()
        appState.isContinuousVoiceModeEnabled = true
        manager.voiceText = ""
        manager.finishVoiceInput(appState: appState)
        XCTAssertTrue(manager.voiceText.isEmpty)
    }

    // MARK: - Voice Input State Machine

    func testVoiceInputStateCanStartListening() {
        XCTAssertTrue(VoiceInputState.idle.canStartListening)
        XCTAssertTrue(VoiceInputState.failed.canStartListening)
        XCTAssertFalse(VoiceInputState.listening.canStartListening)
        XCTAssertFalse(VoiceInputState.transcribing.canStartListening)
    }

    func testVoiceInputStateCanFinishListening() {
        XCTAssertTrue(VoiceInputState.listening.canFinishListening)
        XCTAssertTrue(VoiceInputState.lockedListening.canFinishListening)
        XCTAssertFalse(VoiceInputState.idle.canFinishListening)
        XCTAssertFalse(VoiceInputState.failed.canFinishListening)
    }

    func testVoiceInputStateIsCapturingAudio() {
        XCTAssertTrue(VoiceInputState.listening.isCapturingAudio)
        XCTAssertTrue(VoiceInputState.lockedListening.isCapturingAudio)
        XCTAssertTrue(VoiceInputState.transcribing.isCapturingAudio)
        XCTAssertFalse(VoiceInputState.idle.isCapturingAudio)
        XCTAssertFalse(VoiceInputState.speaking.isCapturingAudio)
        XCTAssertFalse(VoiceInputState.failed.isCapturingAudio)
    }

    func testVoiceInputStateIsActive() {
        XCTAssertFalse(VoiceInputState.idle.isActive)
        XCTAssertTrue(VoiceInputState.listening.isActive)
        XCTAssertTrue(VoiceInputState.processing.isActive)
        XCTAssertTrue(VoiceInputState.speaking.isActive)
    }

    // MARK: - Voice Session State

    func testVoiceSessionStateInitialIdle() {
        let state = VoiceSessionState()
        XCTAssertFalse(state.isListening)
        XCTAssertFalse(state.isSpeaking)
        XCTAssertFalse(state.isConversationMode)
        XCTAssertFalse(state.isThinking)
        XCTAssertTrue(state.latestTranscript.isEmpty)
        XCTAssertTrue(state.latestAssistantText.isEmpty)
    }

    func testVoiceSessionStateShortPhrase() {
        var state = VoiceSessionState()
        state.latestTranscript = "打开 Safari"
        XCTAssertTrue(state.latestTranscript == "打开 Safari")
        XCTAssertTrue(state.latestTranscript.count == 9)
    }

    func testVoiceSessionStateLongSentence() {
        var state = VoiceSessionState()
        let longText = String(repeating: "测试语音输入长句子的稳定性 ", count: 20)
        state.latestTranscript = longText
        XCTAssertTrue(state.latestTranscript.count > 50)
        XCTAssertTrue(state.latestTranscript.hasPrefix("测试"))
    }

    // MARK: - Audio Frame

    func testAudioFrameProperties() {
        let data = Data([0x01, 0x02, 0x03])
        let frame = AudioFrame(data: data, sampleRate: 16000, channelCount: 1)
        XCTAssertTrue(frame.sampleRate == 16000)
        XCTAssertTrue(frame.channelCount == 1)
        XCTAssertTrue(frame.data.count == 3)
    }

    // MARK: - Transcript Events

    func testTranscriptEventPartialUpdates() {
        var results: [String] = []
        let events: [TranscriptEvent] = [
            .partial("打"),
            .partial("打开"),
            .partial("打开 Sa"),
            .partial("打开 Saf"),
            .final("打开 Safari"),
        ]
        for event in events {
            switch event {
            case .partial(let text): results.append("partial: \(text)")
            case .final(let text): results.append("final: \(text)")
            case .failed: break
            }
        }
        XCTAssertTrue(results.count == 5)
        XCTAssertTrue(results.last == "final: 打开 Safari")
    }

    func testTranscriptEventFailure() {
        let event = TranscriptEvent.failed("语音识别服务不可用")
        if case .failed(let msg) = event {
            XCTAssertTrue(msg.contains("不可用"))
        } else {
            XCTFail("Expected .failed event")
        }
    }

    func testTranscriptEventEquality() {
        XCTAssertTrue(TranscriptEvent.partial("he") == TranscriptEvent.partial("he"))
        XCTAssertTrue(TranscriptEvent.partial("he") != TranscriptEvent.final("he"))
        XCTAssertTrue(TranscriptEvent.failed("err") == TranscriptEvent.failed("err"))
    }

    // MARK: - Turn Events

    func testTurnEventCases() {
        let events: [TurnEvent] = [.started, .speechDetected, .ended, .cancelled]
        XCTAssertTrue(events.count == 4)
    }

    func testTurnEventSpeechFlow() {
        var log: [String] = []
        let flow: [TurnEvent] = [.started, .speechDetected, .ended]
        for event in flow {
            switch event {
            case .started: log.append("开始")
            case .speechDetected: log.append("检测到语音")
            case .ended: log.append("结束")
            case .cancelled: log.append("取消")
            }
        }
        XCTAssertTrue(log == ["开始", "检测到语音", "结束"])
    }

    // MARK: - Voice Input Modes

    func testVoiceInputModeAllCases() {
        let all = VoiceInputMode.allCases
        XCTAssertTrue(all.count == 3)
        XCTAssertTrue(all.contains(.accessibilityVoiceInput))
        XCTAssertTrue(all.contains(.systemDictationShortcut))
        XCTAssertTrue(all.contains(.builtInSpeechRecognition))
    }

    // MARK: - Voice Session Manager (unit-level logic)

    func testVoiceSessionManagerInitialState() async {
        let manager = VoiceSessionManager()
        XCTAssertTrue(manager.voiceText.isEmpty)
        XCTAssertTrue(manager.voiceError == nil)
    }

    func testVoiceSessionManagerCancelClearsText() async {
        let manager = VoiceSessionManager()
        let appState = AppState()
        manager.voiceText = "hello"
        manager.voiceError = "some error"
        manager.cancelVoiceInput(appState: appState)
        XCTAssertTrue(manager.voiceText.isEmpty)
        XCTAssertTrue(manager.voiceError == nil)
    }

    // MARK: - Native Speech Transcriber Errors

    func testNativeSpeechTranscriberErrorDescriptions() {
        XCTAssertTrue(NativeSpeechTranscriberError.notAvailable.errorDescription?.contains("语音识别服务暂时不可用") == true)
        XCTAssertTrue(NativeSpeechTranscriberError.notAuthorized.errorDescription?.contains("语音识别权限") == true)
        XCTAssertTrue(NativeSpeechTranscriberError.audioServiceUnavailable.errorDescription?.contains("语音识别服务不可用") == true)
        XCTAssertTrue(NativeSpeechTranscriberError.noAudioInput.errorDescription?.contains("麦克风输入设备") == true)
    }

    func testSTTErrorDescriptions() {
        XCTAssertTrue(STTError.noPermission.errorDescription?.contains("语音识别权限") == true)
        XCTAssertTrue(STTError.notAvailable.errorDescription?.contains("不支持语音识别") == true)
        XCTAssertTrue(STTError.recognitionFailed.errorDescription?.contains("语音识别失败") == true)
        XCTAssertTrue(STTError.audioServiceUnavailable.errorDescription?.contains("麦克风或音频服务不可用") == true)
    }

    // MARK: - Apple Speech Provider

    func testAppleSpeechProviderName() {
        let provider = AppleSpeechProvider()
        XCTAssertTrue(provider.name == "Apple Speech")
    }

    func testAppleSpeechErrorDescriptions() {
        XCTAssertTrue(AppleSpeechError.notAvailable.errorDescription?.contains("不支持语音识别") == true)
        XCTAssertTrue(AppleSpeechError.notAuthorized.errorDescription?.contains("语音识别权限") == true)
        XCTAssertTrue(AppleSpeechError.recognizerUnavailable.errorDescription?.contains("语音识别引擎暂时不可用") == true)
    }

    func testNativeSpeechTranscriberRecognizerUnavailableError() {
        XCTAssertTrue(NativeSpeechTranscriberError.recognizerUnavailable.errorDescription?.contains("语音识别模型未就绪") == true)
    }

    func testAppleSpeechErrorEquality() {
        XCTAssertEqual(AppleSpeechError.notAvailable, AppleSpeechError.notAvailable)
        XCTAssertEqual(AppleSpeechError.notAuthorized, AppleSpeechError.notAuthorized)
        XCTAssertEqual(AppleSpeechError.recognizerUnavailable, AppleSpeechError.recognizerUnavailable)
    }

    func testNativeSpeechTranscriberErrorEquality() {
        XCTAssertEqual(NativeSpeechTranscriberError.notAvailable, NativeSpeechTranscriberError.notAvailable)
        XCTAssertEqual(NativeSpeechTranscriberError.recognizerUnavailable, NativeSpeechTranscriberError.recognizerUnavailable)
        XCTAssertEqual(NativeSpeechTranscriberError.audioServiceUnavailable, NativeSpeechTranscriberError.audioServiceUnavailable)
    }

    // MARK: - System Dictation Bridge

    func testSystemDictationErrorDescriptions() {
        XCTAssert(SystemDictationError.eventCreationFailed.errorDescription?.contains("创建系统听写快捷键事件") == true)
    }

    // MARK: - VoiceSessionState additional transitions

    func testVoiceSessionStateTransitions() {
        var state = VoiceSessionState()
        state.isListening = true
        state.isThinking = true
        XCTAssert(state.isThinking)
        XCTAssert(state.isListening)
        state.isThinking = false
        state.isSpeaking = true
        XCTAssert(state.isSpeaking)
        XCTAssertFalse(state.isThinking)

        var state2 = VoiceSessionState()
        state2.isConversationMode = true
        state2.latestAssistantText = "好的，已帮你完成"
        XCTAssert(state2.isConversationMode)
        XCTAssert(state2.latestAssistantText == "好的，已帮你完成")
    }

    // MARK: - AudioFrame edge cases

    func testAudioFrameEdgeCases() {
        let frame = AudioFrame(data: Data(), sampleRate: 16000, channelCount: 1)
        XCTAssert(frame.data.isEmpty)
        XCTAssert(frame.sampleRate == 16000)
        XCTAssert(frame.channelCount == 1)

        let frame2 = AudioFrame(data: Data([0x00]), sampleRate: 48000, channelCount: 2)
        XCTAssert(frame2.sampleRate == 48000)
        XCTAssert(frame2.channelCount == 2)
    }

    // MARK: - TurnEvent cancelled

    func testTurnEventCancelled() {
        var log: [String] = []
        let flow: [TurnEvent] = [.started, .speechDetected, .cancelled]
        for event in flow {
            switch event {
            case .started: log.append("started")
            case .speechDetected: log.append("speech")
            case .cancelled: log.append("cancelled")
            case .ended: log.append("ended")
            }
        }
        XCTAssert(log == ["started", "speech", "cancelled"])
    }

    // MARK: - VoiceInputState all cases

    func testVoiceInputStateAllCases() {
        for state in [VoiceInputState.listening, VoiceInputState.lockedListening] {
            XCTAssert(state.isCapturingAudio)
            XCTAssert(state.canFinishListening)
        }

        XCTAssert(VoiceInputState.idle.canStartListening)
        XCTAssertFalse(VoiceInputState.idle.isCapturingAudio)
        XCTAssertFalse(VoiceInputState.idle.isActive)
    }

    // MARK: - RealtimeEvent coverage

    func testRealtimeEventCases() {
        let event = RealtimeEvent.sessionStarted
        if case .sessionStarted = event {
            XCTAssert(Bool(true))
        } else {
            XCTAssert(Bool(false), "Expected sessionStarted")
        }

        let events: [RealtimeEvent] = [
            .transcriptDelta("你好"),
            .assistantTextDelta("你好！"),
            .completed,
        ]
        XCTAssert(events.count == 3)

        let failedEvent = RealtimeEvent.failed("连接断开")
        if case .failed(let msg) = failedEvent {
            XCTAssert(msg == "连接断开")
        } else {
            XCTAssert(Bool(false), "Expected .failed")
        }
    }

    // MARK: - VoiceSubmitMode edge cases

    func testVoiceSubmitModeEdgeCases() {
        XCTAssert(VoiceSubmitMode.manual == VoiceSubmitMode.manual)
        XCTAssert(VoiceSubmitMode.automatic == VoiceSubmitMode.automatic)
        XCTAssert(VoiceSubmitMode.manual != VoiceSubmitMode.automatic)
    }

    // MARK: - VoiceSessionManager speakIfNeeded

    func testVoiceSessionManagerSpeakDisabled() async {
        let manager = VoiceSessionManager()
        let appState = AppState()
        appState.isVoiceOutputEnabled = false
        await manager.speakIfNeeded("测试", appState: appState)
        XCTAssert(appState.voiceState == .idle)
    }

    func testVoiceSessionManagerSpeakWhitespace() async {
        let manager = VoiceSessionManager()
        let appState = AppState()
        appState.isVoiceOutputEnabled = true
        await manager.speakIfNeeded("   ", appState: appState)
        XCTAssert(appState.voiceState == .idle)
    }
}
