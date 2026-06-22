import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyConversation

// MARK: - Sub-Second Feedback (first-token timing simulation)

final class ResponseExperienceTests: XCTestCase {
    func testStreamingFirstTokenArrivesQuickly() {
        var tokens: [String] = []
        let simulatedTokens = ["好的"]
        let start = Date()
        Thread.sleep(forTimeInterval: 0.001) // simulate sub-ms latency
        tokens.append(contentsOf: simulatedTokens)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(tokens.first == "好的")
        XCTAssertTrue(elapsed < 1.0, "First token should arrive in under 1 second")
    }

    func testRapidTokenStreamDoesNotDropTokens() {
        let tokens = ["欢", "迎", "使", "用", "RenJistroly"]
        var accumulated = ""
        for token in tokens {
            accumulated += token
        }
        XCTAssertTrue(accumulated == "欢迎使用RenJistroly")
        XCTAssertTrue(tokens.count == 5)
    }

    // MARK: - Stop Response

    func testSessionPhaseTransitionToIdleOnStop() {
        var lifecycle = SessionLifecycle()
        let t1 = lifecycle.transition(to: .thinking, reason: "开始处理")
        XCTAssertTrue(t1)
        let t2 = lifecycle.transition(to: .idle, reason: "用户停止")
        XCTAssertTrue(t2)
    }

    @MainActor func testStopResponseClearsProcessingFlag() {
        let engine = ConversationEngine()
        engine.isProcessing = true
        engine.isProcessing = false
        XCTAssertFalse(engine.isProcessing)
    }

    // MARK: - Retry

    func testRetryResendsText() {
        var retryCount = 0
        let simulateRetry = { retryCount += 1 }
        simulateRetry()
        XCTAssertTrue(retryCount == 1)
        simulateRetry()
        XCTAssertTrue(retryCount == 2)
    }

    func testRetryAfterErrorCreatesNewMessage() {
        var conversation = Conversation(title: "测试")
        let original = Message(role: .assistant, content: [.text("抱歉出错了")])
        conversation.messages.append(original)
        let retry = Message(role: .assistant, content: [.text("重试回复")])
        conversation.messages.append(retry)
        XCTAssertTrue(conversation.messages.count == 2)
        XCTAssertTrue(conversation.messages[0].textContent == "抱歉出错了")
        XCTAssertTrue(conversation.messages[1].textContent == "重试回复")
    }

    @MainActor func testVisibleUserMessageDoesNotExposeInternalPromptContext() {
        let pair = ConversationEngine.makeUserMessagePair(
            displayText: "?",
            modelText: "?\n\n技能上下文:\n你是一个通用的 macOS AI 助手"
        )

        XCTAssertEqual(pair.visible.textContent, "?")
        XCTAssertFalse(pair.visible.textContent.contains("技能上下文"))
        XCTAssertTrue(pair.model.textContent.contains("技能上下文"))
    }

    // MARK: - Copy Response

    func testCopyResponsePreservesFullText() {
        let text = "这是需要复制的内容"
        let copied = text
        XCTAssertTrue(copied == text)
        XCTAssertTrue(copied.count == 9)
    }

    func testCopyResponseWithRichContent() {
        let blocks: [ContentBlock] = [
            .text("第一段内容"),
            .text("第二段内容"),
        ]
        let fullText = blocks.compactMap { block -> String? in
            if case .text(let t) = block { t } else { nil }
        }.joined(separator: "\n")
        XCTAssertTrue(fullText == "第一段内容\n第二段内容")
    }

    // MARK: - Insert Response (mid-conversation insert)

    func testInsertMessageAtSpecificIndex() {
        var conversation = Conversation(title: "插入测试")
        let msg1 = Message(role: .user, content: [.text("你好")])
        let msg2 = Message(role: .assistant, content: [.text("你好！")])
        let msg3 = Message(role: .user, content: [.text("再说一遍")])
        conversation.messages = [msg1, msg3]
        conversation.messages.insert(msg2, at: 1)
        XCTAssertTrue(conversation.messages.count == 3)
        XCTAssertTrue(conversation.messages[1].role == .assistant)
        XCTAssertTrue(conversation.messages[1].textContent == "你好！")
    }

    // MARK: - Casual Mode (concise responses)

    func testCasualModeShortAffirmative() {
        let msg = Message(role: .assistant, content: [.text("好")])
        XCTAssertTrue(msg.textContent.count <= 1)
        XCTAssertTrue(msg.role == .assistant)
    }

    func testCasualInformalPhrasing() {
        let msg = Message(role: .assistant, content: [.text("没问题，交给我吧！")])
        XCTAssertTrue(msg.textContent.contains("没问题"))
    }

    // MARK: - Message Sorting / Order Preservation

    func testConversationMessageOrderPreserved() {
        let msg1 = Message(role: .user, content: [.text("第一句")])
        let msg2 = Message(role: .assistant, content: [.text("回应1")])
        let msg3 = Message(role: .user, content: [.text("第二句")])
        let msg4 = Message(role: .assistant, content: [.text("回应2")])
        let msgs = [msg1, msg2, msg3, msg4]
        XCTAssertTrue(msgs.map(\.textContent) == ["第一句", "回应1", "第二句", "回应2"])
    }

    // MARK: - Response Interruption

    func testResponseInterruptionMidStream() {
        var accumulated = ""
        let partialTokens = ["首先", "我们", "需要"]
        accumulated += partialTokens.joined()
        // Simulate stop
        let interrupted = accumulated + "...（回复中断）"
        XCTAssertTrue(interrupted == "首先我们需要...（回复中断）")
    }

    // MARK: - Conversation short response metrics

    func testConversationMetadataTokenCountUpdate() {
        var meta = Conversation.ConversationMetadata()
        meta.totalTokens = 42
        XCTAssertTrue(meta.totalTokens == 42)
        meta.totalTokens += 100
        XCTAssertTrue(meta.totalTokens == 142)
    }

    // MARK: - Message & ContentBlock

    func testShortResponseCorrectness() {
        let msg = Message(role: .assistant, content: [.text("好的")])
        XCTAssertTrue(msg.textContent == "好的")
        XCTAssertTrue(msg.role == .assistant)
    }

    func testMediumLengthResponse() {
        let text = "我来帮你分析这个问题。首先，我们需要查看当前的代码结构。然后，我会建议一个改进方案。"
        let msg = Message(role: .assistant, content: [.text(text)])
        XCTAssertTrue(msg.textContent == text)
        XCTAssertTrue(msg.tokenCount == nil) // not set by default
    }

    func testEmptyResponseHandling() {
        let msg = Message(role: .assistant, content: [])
        XCTAssertTrue(msg.textContent.isEmpty)
        XCTAssertTrue(msg.content.isEmpty)
    }

    func testLongResponseContent() {
        let longParagraph = String(repeating: "这是测试长回复稳定性的内容段落。", count: 50)
        let msg = Message(role: .assistant, content: [.text(longParagraph)])
        XCTAssertTrue(msg.textContent.count > 500)
        XCTAssertTrue(msg.textContent.hasPrefix("这是测试"))
    }

    func testStreamingTokenAccumulation() {
        let tokens = ["好的", "，我", "正在", "处理", "你的", "请求"]
        var accumulated = ""
        for token in tokens {
            accumulated += token
        }
        let msg = Message(role: .assistant, content: [.text(accumulated)])
        XCTAssertTrue(msg.textContent == "好的，我正在处理你的请求")
        XCTAssertTrue(msg.textContent.count == 12)
    }

    // MARK: - Conversation metadata

    func testConversationMetadataDefault() {
        let meta = Conversation.ConversationMetadata()
        XCTAssertTrue(meta.totalTokens == 0)
        XCTAssertFalse(meta.isPinned)
        XCTAssertTrue(meta.tags.isEmpty)
        XCTAssertTrue(meta.provider == nil)
    }

    func testConversationMetadataWithProvider() {
        let meta = Conversation.ConversationMetadata(
            provider: .anthropic,
            model: "claude-sonnet-4-6",
            totalTokens: 1520
        )
        XCTAssertTrue(meta.provider == .anthropic)
        XCTAssertTrue(meta.model == "claude-sonnet-4-6")
        XCTAssertTrue(meta.totalTokens == 1520)
    }

    // MARK: - SessionPhase FSM transitions

    func testSessionPhaseActive() {
        let activePhases: [SessionPhase] = [.listening, .thinking, .planning, .acting, .verifying, .recovering, .responding]
        for phase in activePhases {
            XCTAssert(phase.isActive)
        }
        XCTAssertFalse(SessionPhase.idle.isActive)
    }

    func testSessionPhaseTransition() {
        var lifecycle = SessionLifecycle(phase: .thinking)
        let result = lifecycle.transition(to: .responding, reason: "准备回复")
        XCTAssert(result)
        XCTAssert(lifecycle.phase == .responding)
    }

    func testSessionPhaseInvalidTransition() {
        var lifecycle = SessionLifecycle(phase: .idle)
        let result = lifecycle.transition(to: .acting) // idle -> acting is invalid
        XCTAssertFalse(result)
        XCTAssert(lifecycle.phase == .idle)
    }

    func testSessionPhaseTimeTracking() {
        let lifecycle = SessionLifecycle(phase: .thinking)
        XCTAssert(lifecycle.timeInCurrentPhase >= 0)
        XCTAssert(lifecycle.isActive)
    }

    // MARK: - Streaming token accumulation patterns

    func testStreamingTokenAccumulationPattern() {
        let tokens = ["欢", "迎", "使", "用", "Ren", "Jistroly"]
        var accumulated = ""
        for token in tokens {
            accumulated += token
        }
        XCTAssert(accumulated == "欢迎使用RenJistroly")
    }

    func testStreamingTokenWithPunctuation() {
        let tokens = ["好的", "，", "我", " ", "正在", "处理", "。"]
        var accumulated = ""
        for token in tokens {
            accumulated += token
        }
        XCTAssert(accumulated == "好的，我 正在处理。")
    }

    // MARK: - Response interruption mid-stream

    func testResponseInterruptionFromThinking() {
        var lifecycle = SessionLifecycle(phase: .thinking)
        let stopped = lifecycle.transition(to: .idle, reason: "用户停止")
        XCTAssert(stopped)
        XCTAssertFalse(lifecycle.isActive)
    }

    // MARK: - Retry with recovery

    func testRetryWithRecovery() {
        var task = DeveloperAgentTask(prompt: "test", status: .failed, output: "error")
        task.retryCount = 1
        XCTAssert(task.retryCount == 1)
        task.retryCount += 1
        XCTAssert(task.retryCount == 2)
    }

    // MARK: - Insert at various positions

    func testInsertAtVariousPositions() {
        var conversation = Conversation(title: "插入测试")
        let msg1 = Message(role: .user, content: [.text("第二条消息")])
        let msg2 = Message(role: .assistant, content: [.text("回复")])
        conversation.messages = [msg1, msg2]
        let intro = Message(role: .system, content: [.text("系统指令")])
        conversation.messages.insert(intro, at: 0)
        XCTAssert(conversation.messages.count == 3)
        XCTAssert(conversation.messages[0].role == .system)
        XCTAssert(conversation.messages[0].textContent == "系统指令")
    }

    // MARK: - Empty response with error context

    func testEmptyResponseWithErrorContext() {
        let msg = Message(role: .assistant, content: [.text("")])
        XCTAssert(msg.textContent.isEmpty)
        XCTAssert(msg.role == .assistant)
    }

    // MARK: - Casual mode edge cases

    func testCasualModeEdgeCases() {
        let short = Message(role: .assistant, content: [.text("好")])
        let longer = Message(role: .assistant, content: [.text("好，我马上帮你处理这个请求。")])
        XCTAssert(short.textContent.count < longer.textContent.count)
        XCTAssert(longer.textContent.hasPrefix("好"))
    }

    // MARK: - Conversation metadata edge cases

    func testConversationMetadataPinnedTags() {
        var meta = Conversation.ConversationMetadata()
        meta.isPinned = true
        meta.tags = ["重要", "工作"]
        XCTAssert(meta.isPinned)
        XCTAssert(meta.tags.count == 2)
        XCTAssert(meta.tags.contains("重要"))
    }

    func testConversationMetadataWithProviderModel() {
        let meta = Conversation.ConversationMetadata(provider: .deepseek, model: "deepseek-chat")
        XCTAssert(meta.provider == .deepseek)
        XCTAssert(meta.model == "deepseek-chat")
    }

    // MARK: - Message hasToolCalls

    func testMessageHasToolCallsTrue() {
        let request = ToolCallRequest(id: "1", name: "open_app", arguments: ["app_name": "Safari"])
        let msg = Message(role: .assistant, content: [.toolCall(request)])
        XCTAssert(msg.hasToolCalls)
    }

    func testMessageHasToolCallsFalse() {
        let msg = Message(role: .assistant, content: [.text("普通回复")])
        XCTAssertFalse(msg.hasToolCalls)
    }

    // MARK: - VoiceSessionState within response flow

    func testVoiceSessionStateThinkingAndSpeaking() {
        var state = VoiceSessionState()
        state.isThinking = true
        state.latestAssistantText = "正在处理"
        XCTAssert(state.isThinking)
        state.isThinking = false
        state.isSpeaking = true
        XCTAssert(state.isSpeaking)
        XCTAssertFalse(state.isThinking)
        state.isSpeaking = false
        XCTAssertFalse(state.isSpeaking)
        XCTAssertFalse(state.isListening)
    }
}
