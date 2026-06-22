import Foundation
import RenJistrolyModels

// MARK: - Streaming Delegate

// @unchecked Sendable: holds non-Sendable SessionManager and (@Sendable) closure; all methods dispatch to @MainActor
private final class StreamingDelegate: LLMStreamingDelegate, @unchecked Sendable {
    let conversationID: UUID
    let messageID: UUID
    let sessionManager: SessionManager
    let onToolCallHandler: ((ToolCallRequest) -> Void)?

    init(
        conversationID: UUID,
        messageID: UUID,
        sessionManager: SessionManager,
        onToolCallHandler: ((ToolCallRequest) -> Void)? = nil
    ) {
        self.conversationID = conversationID
        self.messageID = messageID
        self.sessionManager = sessionManager
        self.onToolCallHandler = onToolCallHandler
    }

    func onToken(_ token: String, messageID: UUID) {
        Task { @MainActor in
            sessionManager.appendStreamToken(token, messageID: messageID, in: conversationID)
        }
    }

    func onToolCall(_ request: ToolCallRequest, messageID: UUID) {
        Task { @MainActor in
            onToolCallHandler?(request)
        }
    }

    func onComplete(messageID: UUID, totalTokens: Int) {
        Task { @MainActor in
            sessionManager.finishStreamingResponse(messageID: messageID, in: conversationID)
        }
    }

    func onError(_ error: Error, messageID: UUID) {
        Task { @MainActor in
            let errorMessage = Message(
                id: messageID,
                role: .assistant,
                content: [.text("发生错误: \(error.localizedDescription)")]
            )
            sessionManager.updateMessage(errorMessage, in: conversationID)
            sessionManager.finishStreamingResponse(messageID: messageID, in: conversationID)
        }
    }
}
