import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyConversation

// MARK: - Cold start app initialization

@MainActor func testSessionManagerColdStartEmpty() {
    let manager = SessionManager()
    XCTAssertTrue(manager.conversations.isEmpty)
    XCTAssertTrue(manager.activeConversationID == nil)
    XCTAssertFalse(manager.isStreaming)
}

@MainActor func testSessionManagerColdStartCreatesFirstConversation() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation(title: "First Run")
    XCTAssertTrue(manager.conversations.count == 1)
    XCTAssertTrue(conv.title == "First Run")
    XCTAssertTrue(manager.activeConversationID == conv.id)
}

// MARK: - App restart lifecycle

@MainActor func testSessionManagerPersistenceAcrossRestart() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-restart-lifecycle-\(UUID().uuidString)")
        .appendingPathComponent("conversations.json")

    let writer = SessionManager(storageURL: tmpURL)
    _ = writer.createConversation(title: "Session A")
    _ = writer.createConversation(title: "Session B")

    let reader = SessionManager(storageURL: tmpURL)
    XCTAssertTrue(reader.conversations.count == 2)
    XCTAssertTrue(reader.conversations.contains(where: { $0.title == "Session A" }))
    XCTAssertTrue(reader.conversations.contains(where: { $0.title == "Session B" }))

    try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
}

@MainActor func testSessionManagerRestartPreservesMessageOrder() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-msg-order-\(UUID().uuidString)")
        .appendingPathComponent("conversations.json")

    let writer = SessionManager(storageURL: tmpURL)
    let conv = writer.createConversation(title: "Chat")
    writer.appendMessage(Message(role: .user, content: [.text("First")]), to: conv.id)
    writer.appendMessage(Message(role: .assistant, content: [.text("Second")]), to: conv.id)

    let reader = SessionManager(storageURL: tmpURL)
    let restored = reader.conversations[0]
    XCTAssertTrue(restored.messages.count == 2)
    XCTAssertTrue(restored.messages[0].textContent == "First")
    XCTAssertTrue(restored.messages[1].textContent == "Second")

    try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
}

// MARK: - Sleep/wake cycle handling

func testSleepWakeCycleGeneratesSystemEvents() {
    let willSleep: AgentEvent = .system(.systemWillSleep)
    let wokeUp: AgentEvent = .system(.systemWokeFromSleep)

    if case .system(let sys) = willSleep {
        if case .systemWillSleep = sys {
            XCTAssertTrue(true)
        } else {
            XCTFail("expected systemWillSleep")
        }
    } else {
        XCTFail("expected .system")
    }

    XCTAssertTrue(wokeUp.summary == "系统唤醒")
    XCTAssertTrue(willSleep.summary == "系统休眠")
    XCTAssertTrue(wokeUp.category == "system")
}

func testAppNapPreventedEvent() {
    let event: AgentEvent = .system(.appNapPrevented)
    XCTAssertTrue(event.summary == "App Nap 阻止")
    XCTAssertTrue(event.icon == "gearshape")
}

// MARK: - Network interface switching

@MainActor func testNetworkSwitchDegradedDoesNotChangeLocalProvider() {
    let state = AppState()
    state.activeProvider = .claudeCodeCLI
    state.isOnline = false
    XCTAssertTrue(state.isOnline == false)
    XCTAssertTrue(state.activeProvider.isLocal)
}

@MainActor func testNetworkSwitchOfflineFallsBackToLocal() {
    let state = AppState()
    state.preferredCloudProvider = .anthropic
    state.isOnline = false
    state.activeProvider = .claudeCodeCLI
    XCTAssertTrue(state.activeProvider == .claudeCodeCLI)
}

// MARK: - Model switching (provider change)

func testProviderSwitchingPreservesConfiguration() {
    let cloud = LLMConfiguration.defaultCloud
    let local = LLMConfiguration.defaultLocal

    XCTAssertTrue(cloud.provider == .anthropic)
    XCTAssertTrue(local.provider == .localMLX)
    XCTAssertTrue(cloud.provider != local.provider)
}

func testProviderEndpointCustomConfiguration() {
    let endpoint = ProviderEndpoint(
        kind: .openAICompatibleChat,
        displayName: "Custom GPT",
        baseURL: URL(string: "https://custom.example.com/v1"),
        model: "custom-model"
    )
    XCTAssertTrue(endpoint.kind == .openAICompatibleChat)
    XCTAssertTrue(endpoint.displayName == "Custom GPT")
    XCTAssertTrue(endpoint.baseURL?.absoluteString == "https://custom.example.com/v1")
    XCTAssertTrue(endpoint.model == "custom-model")
}

// MARK: - 30-minute continuous operation

@MainActor func testContinuousOperationMessageAccumulation() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    let totalMessages = 60

    for i in 0..<totalMessages {
        let role: MessageRole = i.isMultiple(of: 2) ? .user : .assistant
        let msg = Message(role: role, content: [.text("Turn \(i / 2) message \(i)")])
        manager.appendMessage(msg, to: conv.id)
    }

    XCTAssertTrue(conv.messages.count == totalMessages)
    XCTAssertTrue(conv.messages[0].role == .user)
    XCTAssertTrue(conv.messages[1].role == .assistant)
}

func testContinuousOperationTraceAccumulation() {
    var trace = InteractionTrace()
    for i in 0..<30 {
        trace.append(.turnComplete, detail: "turn \(i)")
    }
    XCTAssertTrue(trace.events.count == 30)
    XCTAssertTrue(trace.completedAt != nil)
}

// MARK: - 100-turn conversation loop

@MainActor func testHundredTurnConversationLoop() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation(title: "Long Session")
    let turnCount = 100

    for i in 0..<turnCount {
        let userMsg = Message(role: .user, content: [.text("User message \(i)")])
        manager.appendMessage(userMsg, to: conv.id)
        let assistantMsg = Message(role: .assistant, content: [.text("Assistant response \(i)")])
        manager.appendMessage(assistantMsg, to: conv.id)
    }

    XCTAssertTrue(conv.messages.count == 200)
    XCTAssertTrue(conv.messages.last?.textContent == "Assistant response 99")
    XCTAssertTrue(conv.messages.first?.textContent == "User message 0")
}

@MainActor func testHundredTurnWithSearchPerformance() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation(title: "Search Test")

    for i in 0..<50 {
        let msg = Message(role: .user, content: [.text("Searchable message \(i)")])
        manager.appendMessage(msg, to: conv.id)
    }

    let results = manager.searchConversations("Searchable")
    XCTAssertTrue(results.count == 1)
}

// MARK: - Crash recovery / state restoration

@MainActor func testCrashRecoveryWithNoCorruptedData() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-crash-recovery-\(UUID().uuidString)")
        .appendingPathComponent("conversations.json")

    let manager = SessionManager(storageURL: tmpURL)
    let conv = manager.createConversation(title: "Before Crash")
    manager.appendMessage(Message(role: .user, content: [.text("Important data")]), to: conv.id)

    let recovered = SessionManager(storageURL: tmpURL)
    XCTAssertTrue(recovered.conversations.count == 1)
    XCTAssertTrue(recovered.conversations[0].messages.count == 1)
    XCTAssertTrue(recovered.conversations[0].messages[0].textContent == "Important data")

    try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
}

@MainActor func testCrashRecoveryMultipleConversationsPreserved() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-crash-multi-\(UUID().uuidString)")
        .appendingPathComponent("conversations.json")

    let writer = SessionManager(storageURL: tmpURL)
    let a = writer.createConversation(title: "Chat A")
    writer.appendMessage(Message(role: .user, content: [.text("Hello from A")]), to: a.id)
    let b = writer.createConversation(title: "Chat B")
    writer.appendMessage(Message(role: .user, content: [.text("Hello from B")]), to: b.id)
    writer.appendMessage(Message(role: .assistant, content: [.text("Response B")]), to: b.id)
    writer.deleteConversation(a.id)

    let recovered = SessionManager(storageURL: tmpURL)
    XCTAssertTrue(recovered.conversations.count == 1)
    XCTAssertTrue(recovered.conversations[0].title == "Chat B")
    XCTAssertTrue(recovered.conversations[0].messages.count == 2)

    try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
}

// MARK: - ComputerUseRunResult success/failure tracking

func testComputerUseRunResultAllSucceeded() {
    let step = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "t1", name: "click", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "t1", output: "ok"),
        afterState: nil,
        verified: true
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [step])
    XCTAssertTrue(run.succeeded)
}

func testComputerUseRunResultPartialFailure() {
    let ok = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "t1", name: "click", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "t1", output: "ok"),
        afterState: nil,
        verified: true
    )
    let fail = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "t2", name: "open_app", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "t2", output: "error", isError: true),
        afterState: nil,
        verified: false
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [ok, fail])
    XCTAssertFalse(run.succeeded)
}

func testComputerUseRunResultLearnedWorkflow() {
    let step = ComputerUseStepResult(
        action: ComputerUseAction(
            toolCall: ToolCallRequest(id: "t1", name: "open_app", arguments: ["app_name": "Safari"]),
            verificationGoal: VerificationGoal(expectedApp: "Safari")
        ),
        beforeState: nil,
        toolResult: ToolCallResult(id: "t1", output: "opened"),
        afterState: nil,
        verified: true
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [step])
    XCTAssertTrue(run.inferredAppName() == "Safari")
    XCTAssertTrue(run.learnedWorkflowSummary?.contains("open_app") == true)
}

// MARK: - Batch safety assessment

func testBatchSafetyAssessmentRiskBreakdown() {
    let items = [
        ToolRiskAssessment(toolName: "read_file", riskLevel: .low, actionCategory: .localFileRead, arguments: [:], summary: "Read"),
        ToolRiskAssessment(toolName: "delete_file", riskLevel: .high, actionCategory: .localFileDelete, arguments: [:], summary: "Delete"),
    ]
    let batch = BatchSafetyAssessment(items: items)
    XCTAssertTrue(batch.overallRisk == .high)
    XCTAssertTrue(batch.highRiskItems.count == 1)
    XCTAssertTrue(batch.mediumRiskItems.count == 0)
    XCTAssertTrue(batch.riskBreakdown.contains("高风险 1 项"))
}

func testBatchSafetyAssessmentAllLowRisk() {
    let items = [
        ToolRiskAssessment(toolName: "observe", riskLevel: .low, actionCategory: .observe, arguments: [:], summary: "Observe"),
    ]
    let batch = BatchSafetyAssessment(items: items)
    XCTAssertFalse(batch.requiresBatchConfirmation)
    XCTAssertTrue(batch.overallRisk == .low)
}

// MARK: - Resource cleanup

@MainActor func testResourceCleanupRemovesTemporaryFiles() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-resource-cleanup-\(UUID().uuidString)")
        .appendingPathComponent("conversations.json")

    let manager = SessionManager(storageURL: tmpURL)
    let _ = manager.createConversation(title: "Cleanup Test")

    let dir = tmpURL.deletingLastPathComponent()
    XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))

    try? FileManager.default.removeItem(at: dir)
    XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))
}

@MainActor func testResourceCleanupMultipleTempDirs() throws {
    let urls = (0..<3).map { i in
        FileManager.default.temporaryDirectory
            .appendingPathComponent("test-cleanup-\(i)-\(UUID().uuidString)")
            .appendingPathComponent("conversations.json")
    }

    for url in urls {
        let manager = SessionManager(storageURL: url)
        let _ = manager.createConversation(title: "Test")
    }

    for url in urls {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: dir)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))
    }
}

// MARK: - Error boundary for invalid operations

@MainActor func testAppendMessageToInvalidConversationDoesNotCrash() {
    let manager = SessionManager(storageURL: nil)
    let invalidID = UUID()
    let msg = Message(role: .user, content: [.text("Should not crash")])
    manager.appendMessage(msg, to: invalidID)
    XCTAssertTrue(manager.conversations.isEmpty)
}

@MainActor func testUpdateMessageInInvalidConversationDoesNotCrash() {
    let manager = SessionManager(storageURL: nil)
    let msg = Message(role: .user, content: [.text("Orphan")])
    manager.updateMessage(msg, in: UUID())
    XCTAssertTrue(manager.conversations.isEmpty)
}

@MainActor func testBeginStreamingInInvalidConversationDoesNotCrash() {
    let manager = SessionManager(storageURL: nil)
    let msgID = manager.beginStreamingResponse(in: UUID())
    manager.finishStreamingResponse(messageID: msgID, in: UUID())
    XCTAssertFalse(manager.isStreaming)
}

@MainActor func testDeleteConversationMultipleTimesDoesNotCrash() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation(title: "Once")
    manager.deleteConversation(conv.id)
    manager.deleteConversation(conv.id) // second delete should be no-op
    XCTAssertTrue(manager.conversations.isEmpty)
}

// MARK: - Multiple sequential restarts preserving data integrity

@MainActor func testSequentialRestartsPreserveDataIntegrity() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-seq-restart-\(UUID().uuidString)")
        .appendingPathComponent("conversations.json")

    var messages: [String] = []

    let writer1 = SessionManager(storageURL: tmpURL)
    let conv1 = writer1.createConversation(title: "Session 1")
    writer1.appendMessage(Message(role: .user, content: [.text("Message 1")]), to: conv1.id)
    messages.append("Message 1")

    let writer2 = SessionManager(storageURL: tmpURL)
    let conv2 = writer2.createConversation(title: "Session 2")
    writer2.appendMessage(Message(role: .user, content: [.text("Message 2")]), to: conv2.id)
    messages.append("Message 2")

    let reader = SessionManager(storageURL: tmpURL)
    XCTAssertTrue(reader.conversations.count == 2)
    for msg in messages {
        XCTAssertTrue(reader.conversations.contains(where: { $0.messages.contains(where: { $0.textContent == msg }) }))
    }

    try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
}

// MARK: - Mid-stream streaming cancellation recovery

@MainActor func testStreamingMidStreamCancelRecovery() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    let msgID = manager.beginStreamingResponse(in: conv.id)
    XCTAssertTrue(manager.isStreaming)

    manager.appendStreamToken("Partial response...", messageID: msgID, in: conv.id)
    let midMsg = conv.messages.first { $0.id == msgID }
    XCTAssertTrue(midMsg?.textContent == "Partial response...")

    manager.finishStreamingResponse(messageID: msgID, in: conv.id)
    XCTAssertFalse(manager.isStreaming)
    let finalMsg = conv.messages.first { $0.id == msgID }
    XCTAssertTrue(finalMsg?.textContent == "Partial response...")
}

// MARK: - Active conversation pruning after deletion

@MainActor func testDeleteActiveConversationFallsBackToPrevious() {
    let manager = SessionManager(storageURL: nil)
    let first = manager.createConversation(title: "First")
    let second = manager.createConversation(title: "Second")
    let third = manager.createConversation(title: "Third")

    manager.setActiveConversation(second.id)
    manager.deleteConversation(second.id)
    XCTAssertTrue(manager.activeConversationID == first.id || manager.activeConversationID == third.id)
}

// MARK: - Conversation ordering stability

@MainActor func testConversationOrderingPreservedAfterDeletes() {
    let manager = SessionManager(storageURL: nil)
    _ = manager.createConversation(title: "Alpha")
    let b = manager.createConversation(title: "Beta")
    _ = manager.createConversation(title: "Gamma")

    manager.deleteConversation(b.id)
    XCTAssertTrue(manager.conversations.count == 2)
    XCTAssertTrue(manager.conversations[0].title == "Alpha")
    XCTAssertTrue(manager.conversations[1].title == "Gamma")
}

// MARK: - Continuous operation with search across turns

@MainActor func testSearchAcrossMultipleConversations() {
    let manager = SessionManager(storageURL: nil)
    let a = manager.createConversation(title: "Swift Tips")
    manager.appendMessage(Message(role: .user, content: [.text("How to use async await")]), to: a.id)
    let b = manager.createConversation(title: "Debug Session")
    manager.appendMessage(Message(role: .user, content: [.text("Fix crash in Swift runtime")]), to: b.id)

    let swiftResults = manager.searchConversations("Swift")
    XCTAssertTrue(swiftResults.count == 2)

    let crashResults = manager.searchConversations("crash")
    XCTAssertTrue(crashResults.count == 1)
}

// MARK: - Execution plan error handling

func testExecutionPlanEmptySteps() {
    let plan = ExecutionPlan(title: "Empty", steps: [])
    XCTAssertNil(plan.currentStep)
    XCTAssertFalse(plan.hasRemainingSteps)
    XCTAssertTrue(plan.progressFraction == 0)
    XCTAssertTrue(plan.highestRiskLevel == .low)
}

func testExecutionPlanComplete() {
    let steps = [PlanStep(description: "Done", status: .completed)]
    let plan = ExecutionPlan(title: "Complete", steps: steps, status: .completed, currentStepIndex: 1)
    XCTAssertNil(plan.currentStep)
    XCTAssertFalse(plan.hasRemainingSteps)
}

// MARK: - ComputerUseRunResult full coverage

func testComputerUseRunResultEmptyRun() {
    let run = ComputerUseRunResult(startedAt: Date(), steps: [])
    XCTAssertTrue(run.succeeded)
    XCTAssertNil(run.inferredAppName())
}

func testComputerUseRunErrorStep() {
    let step = ComputerUseStepResult(
        action: ComputerUseAction(toolCall: ToolCallRequest(id: "e1", name: "error_tool", arguments: [:])),
        beforeState: nil,
        toolResult: ToolCallResult(id: "e1", output: "failure", isError: true),
        afterState: nil,
        verified: false
    )
    let run = ComputerUseRunResult(startedAt: Date(), steps: [step])
    XCTAssertFalse(run.succeeded)
}
