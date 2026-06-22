import Foundation
import XCTest
import RenJistrolyModels
import RenJistrolySystemBridge
@testable import RenJistrolyIntelligence

// MARK: - Mocks for LocalRealtimeSession

private final class MockAudioCaptureService: NSObject, AudioCaptureService {
    func start() async throws -> AsyncStream<AudioFrame> {
        AsyncStream { $0.finish() }
    }
    func stop() async {}
}

private final class MockASRProvider: NSObject, ASRProvider {
    var name: String { "Mock ASR" }
    func transcribe(_ frames: AsyncStream<AudioFrame>) async throws -> AsyncStream<TranscriptEvent> {
        AsyncStream { $0.finish() }
    }
}

// MARK: - OpenAIRealtimeSession

func testOpenAIRealtimeInitWithoutKey() async {
    let session = OpenAIRealtimeSession(apiKey: nil)
    let name = await session.name
    XCTAssertEqual(name, "OpenAI Realtime")
}

func testOpenAIRealtimeInitWithKey() async {
    let session = OpenAIRealtimeSession(apiKey: "sk-test")
    let name = await session.name
    XCTAssertEqual(name, "OpenAI Realtime")
}

func testOpenAIRealtimeUpdateAPIKey() async {
    let session = OpenAIRealtimeSession(apiKey: nil)
    await session.updateAPIKey("sk-new")
    // No crash, just verifies the method works
}

func testOpenAIRealtimeConnectWithoutKey() async throws {
    let session = OpenAIRealtimeSession(apiKey: nil)
    let config = RealtimeConfig(instructions: "test")
    let stream = try await session.connect(config: config)

    var events: [RealtimeEvent] = []
    for await event in stream {
        events.append(event)
    }
    XCTAssertTrue(events.count == 2)
    XCTAssertTrue(events[0] == .sessionStarted)
    if case .failed(let msg) = events[1] {
        XCTAssertTrue(msg.contains("未配置") || msg.contains("API Key"))
    } else {
        XCTFail("Expected .failed event")
    }
}

func testOpenAIRealtimeDisconnect() async {
    let session = OpenAIRealtimeSession(apiKey: nil)
    await session.disconnect()
    // Should not crash even without active connection
}

func testOpenAIRealtimeSendTextWithoutConnect() async {
    let session = OpenAIRealtimeSession(apiKey: nil)
    do {
        try await session.sendText("hello")
    } catch {
        // May throw or no-op; just verify it doesn't crash
    }
}

func testOpenAIRealtimeSendAudioWithoutConnect() async {
    let session = OpenAIRealtimeSession(apiKey: nil)
    let frame = AudioFrame(data: Data(), sampleRate: 16000, channelCount: 1)
    do {
        try await session.sendAudio(frame)
    } catch {
        // Expected or no-op
    }
}

// MARK: - LocalRealtimeSession

private func makeRealtimeSession(backend: LocalMLXBackend = LocalMLXBackend()) -> LocalRealtimeSession {
    LocalRealtimeSession(
        captureService: MockAudioCaptureService(),
        asrProvider: MockASRProvider(),
        llmBackend: backend
    )
}

func testLocalRealtimeInit() async {
    let session = makeRealtimeSession()
    let name = await session.name
    XCTAssertEqual(name, "Local Pipeline Realtime")
}

func testLocalRealtimeConnect() async throws {
    let session = makeRealtimeSession()
    let config = RealtimeConfig(instructions: "test instructions")
    let stream = try await session.connect(config: config)

    var events: [RealtimeEvent] = []
    for await event in stream {
        events.append(event)
    }
    XCTAssertTrue(events.count == 1)
    XCTAssertTrue(events[0] == .sessionStarted)
}

func testLocalRealtimeDisconnect() async {
    let session = makeRealtimeSession()
    await session.disconnect()
}

func testLocalRealtimeSendTextWithoutConnect() async {
    let session = makeRealtimeSession()
    do {
        try await session.sendText("hello")
    } catch {
        // Expected no-op or error
    }
}

func testLocalRealtimeUpdateInstructions() async {
    let session = makeRealtimeSession()
    do {
        try await session.updateInstructions("new instructions")
    } catch {
        // May fail without connect, should not crash
    }
}

// MARK: - RealtimeConfig

func testRealtimeConfigDefaultValues() {
    let config = RealtimeConfig(instructions: "test")
    XCTAssertTrue(config.model == "gpt-realtime-2")
    XCTAssertTrue(config.voice == "marin")
    XCTAssertTrue(config.instructions == "test")
}

func testRealtimeConfigCustomValues() {
    let config = RealtimeConfig(model: "custom-model", voice: "alloy", instructions: "custom")
    XCTAssertTrue(config.model == "custom-model")
    XCTAssertTrue(config.voice == "alloy")
    XCTAssertTrue(config.instructions == "custom")
}

func testRealtimeConfigEquatable() {
    let a = RealtimeConfig(instructions: "a")
    let b = RealtimeConfig(instructions: "a")
    let c = RealtimeConfig(instructions: "c")
    XCTAssertTrue(a == b)
    XCTAssertTrue(a != c)
}

// MARK: - RealtimeEvent

func testRealtimeEventEquatable() {
    XCTAssertTrue(RealtimeEvent.sessionStarted == .sessionStarted)
    XCTAssertTrue(RealtimeEvent.transcriptDelta("hi") == .transcriptDelta("hi"))
    XCTAssertTrue(RealtimeEvent.transcriptDelta("hi") != .transcriptDelta("bye"))
    XCTAssertTrue(RealtimeEvent.failed("err") == .failed("err"))
}

func testRealtimeEventAllCases() {
    let events: [RealtimeEvent] = [
        .sessionStarted,
        .transcriptDelta("hello"),
        .assistantTextDelta("world"),
        .assistantAudioDelta(Data([0x00])),
        .interrupted,
        .completed,
        .failed("error"),
    ]
    XCTAssertTrue(events.count == 7)
}

// MARK: - VoiceSessionState

func testVoiceSessionStateDefault() {
    let state = VoiceSessionState()
    XCTAssertFalse(state.isListening)
    XCTAssertFalse(state.isSpeaking)
    XCTAssertFalse(state.isConversationMode)
    XCTAssertFalse(state.isThinking)
    XCTAssertTrue(state.latestTranscript.isEmpty)
    XCTAssertTrue(state.latestAssistantText.isEmpty)
}

func testVoiceSessionStateCustom() {
    let state = VoiceSessionState(
        isListening: true,
        isSpeaking: false,
        isConversationMode: true,
        isThinking: true,
        latestTranscript: "hello",
        latestAssistantText: "hi there"
    )
    XCTAssertTrue(state.isListening)
    XCTAssertFalse(state.isSpeaking)
    XCTAssertTrue(state.isConversationMode)
    XCTAssertTrue(state.isThinking)
    XCTAssertTrue(state.latestTranscript == "hello")
    XCTAssertTrue(state.latestAssistantText == "hi there")
}
