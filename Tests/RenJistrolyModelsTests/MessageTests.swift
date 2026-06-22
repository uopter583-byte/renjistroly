import XCTest
@testable import RenJistrolyModels

func testMessageTextContent() {
    let message = Message(
        role: .user,
        content: [.text("你好"), .text("世界")]
    )
    XCTAssertTrue(message.textContent == "你好\n世界")
}

func testConversationCreation() {
    let conv = Conversation(title: "测试对话")
    XCTAssertTrue(conv.title == "测试对话")
    XCTAssertTrue(conv.messages.isEmpty)
    XCTAssertTrue(conv.metadata.isPinned == false)
}

func testLLMProviderLocal() {
    XCTAssertTrue(LLMProvider.localMLX.isLocal == true)
    XCTAssertTrue(LLMProvider.anthropic.isLocal == false)
    XCTAssertTrue(LLMProvider.localMLX.requiresAPIKey == false)
}

func testVoiceInputStateTransitions() {
    XCTAssertTrue(VoiceInputState.idle.canStartListening)
    XCTAssertTrue(VoiceInputState.failed.canStartListening)
    XCTAssertFalse(VoiceInputState.requestingPermission.canStartListening)

    XCTAssertTrue(VoiceInputState.listening.canFinishListening)
    XCTAssertTrue(VoiceInputState.lockedListening.canFinishListening)
    XCTAssertTrue(VoiceInputState.transcribing.canFinishListening)
    XCTAssertFalse(VoiceInputState.processing.canFinishListening)

    XCTAssertTrue(VoiceInputState.listening.isCapturingAudio)
    XCTAssertTrue(VoiceInputState.lockedListening.isCapturingAudio)
    XCTAssertTrue(VoiceInputState.transcribing.isCapturingAudio)
    XCTAssertFalse(VoiceInputState.speaking.isCapturingAudio)
}

@MainActor
func testDefaultVoiceInputUsesAccessibilityVoiceInput() {
    let state = AppState()

    XCTAssertTrue(state.voiceInputMode == .accessibilityVoiceInput)
}

func testToolDefinition() {
    let tool = ToolDefinition(
        name: "test_tool",
        description: "测试工具",
        parameters: [
            .init(name: "arg1", type: .string, description: "参数1", required: true)
        ]
    )
    XCTAssertTrue(tool.name == "test_tool")
    XCTAssertTrue(tool.parameters.count == 1)
}
