import Foundation
import XCTest
import RenJistrolyModels

// MARK: - HotkeyPreset

func testHotkeyPresetTitles() {
    XCTAssertTrue(HotkeyPreset.controlOptionSpace.title == "⌃⌥Space")
    XCTAssertTrue(HotkeyPreset.optionCommandSpace.title == "⌥⌘Space")
    XCTAssertTrue(HotkeyPreset.commandShiftSpace.title == "⇧⌘Space")
    XCTAssertTrue(HotkeyPreset.controlSpace.title == "⌃Space")
    XCTAssertTrue(HotkeyPreset.optionSpace.title == "⌥Space")
}

func testHotkeyPresetWarnings() {
    XCTAssertTrue(HotkeyPreset.controlOptionSpace.warning == nil)
    XCTAssertTrue(HotkeyPreset.optionCommandSpace.warning != nil)
    XCTAssertTrue(HotkeyPreset.commandShiftSpace.warning != nil)
    XCTAssertTrue(HotkeyPreset.controlSpace.warning != nil)
    XCTAssertTrue(HotkeyPreset.optionSpace.warning != nil)
}

func testHotkeyPresetSelectableCases() {
    let selectable = HotkeyPreset.selectableCases
    XCTAssertTrue(selectable.count == 3)
    XCTAssertTrue(selectable.contains(.controlOptionSpace))
    XCTAssertTrue(selectable.contains(.optionCommandSpace))
    XCTAssertTrue(selectable.contains(.commandShiftSpace))
    XCTAssertTrue(!selectable.contains(.controlSpace))
    XCTAssertTrue(!selectable.contains(.optionSpace))
}

// MARK: - VoiceSubmitMode

func testVoiceSubmitModeTitles() {
    XCTAssertTrue(VoiceSubmitMode.manual.title == "手动停止发送")
    XCTAssertTrue(VoiceSubmitMode.automatic.title == "停顿自动发送")
}

// MARK: - VoiceSessionState

func testVoiceSessionStateDefaults() {
    let state = VoiceSessionState()
    XCTAssertFalse(state.isListening)
    XCTAssertFalse(state.isSpeaking)
    XCTAssertFalse(state.isConversationMode)
    XCTAssertFalse(state.isThinking)
    XCTAssertTrue(state.latestTranscript.isEmpty)
    XCTAssertTrue(state.latestAssistantText.isEmpty)
}

func testVoiceSessionStateMutability() {
    var state = VoiceSessionState()
    state.isListening = true
    state.latestTranscript = "hello"
    XCTAssertTrue(state.isListening)
    XCTAssertTrue(state.latestTranscript == "hello")
}

// MARK: - TranscriptEvent

func testTranscriptEventEquality() {
    let p1 = TranscriptEvent.partial("he")
    let p2 = TranscriptEvent.partial("he")
    let p3 = TranscriptEvent.partial("hel")
    XCTAssertTrue(p1 == p2)
    XCTAssertTrue(p1 != p3)
}

// MARK: - AudioFrame

func testAudioFrameProperties() {
    let data = Data([0x01, 0x02])
    let frame = AudioFrame(data: data, sampleRate: 16000, channelCount: 1)
    XCTAssertTrue(frame.sampleRate == 16000)
    XCTAssertTrue(frame.channelCount == 1)
    XCTAssertTrue(frame.data.count == 2)
}

// MARK: - RealtimeEvent

func testRealtimeEventCases() {
    let events: [RealtimeEvent] = [
        .sessionStarted,
        .transcriptDelta("hi"),
        .assistantTextDelta("hello"),
        .assistantAudioDelta(Data()),
        .toolCallRequested(MacAction(kind: .openApplication, payload: [:], riskLevel: .reversibleInput, humanPreview: "打开")),
        .interrupted,
        .completed,
        .failed("error"),
    ]
    XCTAssertTrue(events.count == 8)
}

// MARK: - TurnEvent

func testTurnEventCases() {
    let events: [TurnEvent] = [.started, .speechDetected, .ended, .cancelled]
    XCTAssertTrue(events.count == 4)
}
