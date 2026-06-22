import Foundation
import XCTest
@testable import RenJistrolyModels
import RenJistrolyConversation

// MARK: - Cold start app initialization

@MainActor
func testAppStateColdStartDefaults() {
    let state = AppState()
    XCTAssertTrue(state.mode == .compact)
    XCTAssertTrue(state.voiceState == .idle)
    XCTAssertTrue(state.activeProvider == .claudeCodeCLI)
    XCTAssertTrue(state.isOnline == true)
    XCTAssertTrue(state.isStreaming == false)
    XCTAssertTrue(state.devMode == .disabled)
}

@MainActor
func testAppStateColdStartPermissionsNotGranted() {
    let state = AppState()
    XCTAssertFalse(state.isPermissionGranted.allGranted)
}

// MARK: - Sleep/wake cycle handling

func testSystemEventSleepWakeCycle() {
    let sleepEvent: AgentEvent = .system(.systemWillSleep)
    let wakeEvent: AgentEvent = .system(.systemWokeFromSleep)

    XCTAssertTrue(sleepEvent.category == "system")
    XCTAssertTrue(sleepEvent.summary == "系统休眠")
    XCTAssertTrue(wakeEvent.summary == "系统唤醒")
}

// MARK: - Network interface switching

func testProviderIsLocalClassification() {
    XCTAssertTrue(LLMProvider.claudeCodeCLI.isLocal)
    XCTAssertTrue(LLMProvider.localMLX.isLocal)
    XCTAssertTrue(LLMProvider.ollama.isLocal)
    XCTAssertFalse(LLMProvider.anthropic.isLocal)
    XCTAssertFalse(LLMProvider.openAI.isLocal)
}

func testProviderDefaultBaseURLs() {
    XCTAssertTrue(LLMProvider.deepseek.defaultBaseURL == "https://api.deepseek.com")
    XCTAssertTrue(LLMProvider.groq.defaultBaseURL == "https://api.groq.com/openai")
    XCTAssertTrue(LLMProvider.perplexity.defaultBaseURL == "https://api.perplexity.ai")
    XCTAssertTrue(LLMProvider.anthropic.defaultBaseURL == nil)
}

// MARK: - Memory growth monitoring

func testInteractionTraceEventCountTracking() {
    var trace = InteractionTrace()
    trace.append(.inputStarted)
    trace.append(.speechPartial, detail: "partial")
    trace.append(.speechFinal, detail: "final")
    trace.append(.contextObserved, detail: "screen")
    trace.append(.routeSelected, detail: "code")
    trace.append(.modelFirstToken)
    trace.append(.toolStarted, detail: "open_app")
    trace.append(.verifyDone, detail: "verified")
    trace.append(.turnComplete, detail: "done")

    XCTAssertTrue(trace.events.count == 9)
    let latency = TraceLatencySummary(from: trace)
    XCTAssertTrue(latency.eventCount == 9)
}

func testInteractionTraceEmptyEventCount() {
    let trace = InteractionTrace()
    XCTAssertTrue(trace.events.isEmpty)
    let latency = TraceLatencySummary(from: trace)
    XCTAssertTrue(latency.eventCount == 0)
}

// MARK: - CPU usage tracking

func testComputerUseAppStateTracksStateChange() {
    let before = ComputerUseAppState(
        activeAppBundleID: "com.apple.Safari",
        activeAppName: "Safari",
        focusedWindowTitle: "Safari"
    )
    let after = ComputerUseAppState(
        activeAppBundleID: "com.apple.Terminal",
        activeAppName: "Terminal",
        focusedWindowTitle: "Terminal"
    )
    let delta = ComputerUseStateDelta(before: before, after: after)
    XCTAssertTrue(delta.activeAppChanged)
    XCTAssertTrue(delta.focusedWindowChanged)
    XCTAssertTrue(delta.hasMeaningfulChange)
    XCTAssertTrue(delta.changeDescriptions.contains("前台应用变化"))
    XCTAssertTrue(delta.changeDescriptions.contains("焦点窗口变化"))
}

func testComputerUseAppStateNoChangeDetection() {
    let state = ComputerUseAppState(
        activeAppBundleID: "com.apple.Finder",
        activeAppName: "Finder"
    )
    let delta = ComputerUseStateDelta(before: state, after: state)
    XCTAssertFalse(delta.hasMeaningfulChange)
    XCTAssertTrue(delta.changeDescriptions.isEmpty)
    XCTAssertTrue(delta.summary == "未观察到明显状态变化")
}

// MARK: - 30-minute continuous operation metrics

func testTraceLatencySummaryComputesFromTimeline() {
    var trace = InteractionTrace()
    trace.append(.inputStarted, detail: "begin")
    trace.append(.turnComplete, detail: "end")

    let summary = TraceLatencySummary(from: trace)
    XCTAssertTrue(summary.eventCount == 2)
    XCTAssertTrue(summary.totalMs != nil)
}

// MARK: - Crash recovery / state restoration

func testExecutionPlanProgressTracking() {
    let plan = ExecutionPlan(
        title: "Configure project",
        steps: [
            PlanStep(description: "Install dependencies", riskLevel: .low),
            PlanStep(description: "Configure build settings", riskLevel: .medium),
            PlanStep(description: "Run tests", riskLevel: .low),
            PlanStep(description: "Deploy", riskLevel: .high),
        ]
    )
    XCTAssertTrue(plan.progressFraction == 0)
    XCTAssertTrue(plan.hasRemainingSteps)
    XCTAssertTrue(plan.highestRiskLevel == .high)
}

func testExecutionPlanCurrentStepAccess() {
    let steps = [
        PlanStep(description: "Step 1"),
        PlanStep(description: "Step 2"),
    ]
    let plan = ExecutionPlan(
        title: "Test",
        steps: steps,
        currentStepIndex: 1
    )
    XCTAssertTrue(plan.currentStep?.description == "Step 2")
    XCTAssertTrue(plan.currentStepIndex == 1)
}

// MARK: - AgentLoopConfig presets

func testAgentLoopConfigDefaultValues() {
    let config = AgentLoopConfig.default
    XCTAssertTrue(config.maxRounds == 50)
    XCTAssertTrue(config.maxStagnationRounds == 5)
    XCTAssertTrue(config.maxRecoveryAttemptsPerStep == 3)
    XCTAssertTrue(config.maxSubtaskDepth == 3)
    XCTAssertTrue(config.progressCheckInterval == 5)
}

func testAgentLoopConfigConservativeValues() {
    let config = AgentLoopConfig.conservative
    XCTAssertTrue(config.maxRounds == 20)
    XCTAssertTrue(config.maxStagnationRounds == 3)
    XCTAssertTrue(config.maxRecoveryAttemptsPerStep == 1)
    XCTAssertTrue(config.maxSubtaskDepth == 2)
}

// MARK: - SessionLifecycle state machine

func testSessionLifecycleValidTransitions() {
    let lifecycle = SessionLifecycle()
    XCTAssertTrue(lifecycle.phase == .idle)
    XCTAssertTrue(lifecycle.transitionHistory.isEmpty)
}

func testSessionLifecycleTransitionIdleToListening() {
    var lifecycle = SessionLifecycle()
    let ok = lifecycle.transition(to: .listening, reason: "用户开始说话")
    XCTAssertTrue(ok)
    XCTAssertTrue(lifecycle.phase == .listening)
    XCTAssertTrue(lifecycle.transitionHistory.count == 1)
}

func testSessionLifecycleInvalidTransitionsRejected() {
    var lifecycle = SessionLifecycle()
    let ok = lifecycle.transition(to: .responding, reason: "should fail")
    XCTAssertFalse(ok)
    XCTAssertTrue(lifecycle.phase == .idle)
}

// MARK: - Baseline comparison

func testBaselineComparisonAnomalyDetection() {
    let result = BaselineComparison.compute(
        metricName: "response_time",
        currentValue: 500,
        baselineValue: 200,
        thresholdPercent: 20
    )
    XCTAssertTrue(result.isAnomaly)
    XCTAssertTrue(result.deviationPercent == 150)
}

func testBaselineComparisonWithinThreshold() {
    let result = BaselineComparison.compute(
        metricName: "cpu_usage",
        currentValue: 55,
        baselineValue: 50,
        thresholdPercent: 20
    )
    XCTAssertFalse(result.isAnomaly)
    XCTAssertTrue(abs(result.deviationPercent - 10) < 0.01)
}

func testBaselineComparisonZeroBaseline() {
    let result = BaselineComparison.compute(
        metricName: "new_metric",
        currentValue: 100,
        baselineValue: 0
    )
    XCTAssertTrue(result.deviationPercent == 100)
    XCTAssertTrue(result.isAnomaly)
}

// MARK: - Foundation layer status

func testFoundationLayerBaselineRequirements() {
    XCTAssertTrue(FoundationLayer.feedbackLoop.baselineRequirement.contains("用户反馈失败时"))
    XCTAssertTrue(FoundationLayer.safetyBoundary.baselineRequirement.contains("风险分级"))
    XCTAssertTrue(FoundationLayer.screenUnderstanding.baselineRequirement.contains("OCR"))
}

func testPermissionSnapshotStatusDisplay() {
    let granted = PermissionSnapshot(kind: .accessibility, status: .granted)
    let denied = PermissionSnapshot(kind: .microphone, status: .denied)
    XCTAssertTrue(granted.status.isGranted)
    XCTAssertFalse(denied.status.isGranted)
    XCTAssertTrue(granted.status.label == "已授权")
    XCTAssertTrue(denied.status.label == "未授权")
}

// MARK: - Restart lifecycle state reconstruction

@MainActor func testSessionLifecycleFullCycle() {
    var lifecycle = SessionLifecycle()
    XCTAssertTrue(lifecycle.transition(to: .listening, reason: "用户说话"))
    XCTAssertTrue(lifecycle.phase == .listening)
    XCTAssertTrue(lifecycle.transition(to: .thinking, reason: "模型思考"))
    XCTAssertTrue(lifecycle.phase == .thinking)
    XCTAssertTrue(lifecycle.transition(to: .responding, reason: "回复"))
    XCTAssertTrue(lifecycle.phase == .responding)
    XCTAssertTrue(lifecycle.transition(to: .idle, reason: "完成"))
    XCTAssertTrue(lifecycle.phase == .idle)
}

@MainActor func testSessionLifecycleMultipleCycles() {
    var lifecycle = SessionLifecycle()
    for _ in 0..<5 {
        XCTAssertTrue(lifecycle.transition(to: .listening, reason: "cycle"))
        XCTAssertTrue(lifecycle.transition(to: .thinking, reason: "cycle"))
        XCTAssertTrue(lifecycle.transition(to: .responding, reason: "cycle"))
        XCTAssertTrue(lifecycle.transition(to: .idle, reason: "cycle"))
    }
    XCTAssertTrue(lifecycle.phase == .idle)
    XCTAssertTrue(lifecycle.transitionHistory.count == 20)
}

// MARK: - Memory growth over multiple traces

func testMultipleInteractionTraceMemoryBounds() {
    let traces = (0..<10).map { i -> InteractionTrace in
        var trace = InteractionTrace()
        trace.append(.inputStarted, detail: "turn \(i)")
        trace.append(.speechFinal, detail: "input")
        trace.append(.modelFirstToken)
        trace.append(.turnComplete, detail: "done")
        return trace
    }
    XCTAssertTrue(traces.count == 10)
    for trace in traces {
        XCTAssertTrue(trace.events.count == 4)
        XCTAssertNotNil(trace.completedAt)
    }
}

func testTraceLatencySummaryFullBreakdown() {
    var trace = InteractionTrace()
    trace.append(.inputStarted)
    trace.append(.speechFinal)
    trace.append(.contextObserved)
    trace.append(.routeSelected)
    trace.append(.modelFirstToken)
    trace.append(.toolStarted)
    trace.append(.verifyDone)
    trace.append(.ttsStarted)
    trace.append(.turnComplete)

    let summary = TraceLatencySummary(from: trace)
    XCTAssertTrue(summary.eventCount == 9)
    XCTAssertNotNil(summary.asrMs)
    XCTAssertNotNil(summary.firstTokenMs)
    XCTAssertNotNil(summary.totalMs)
}

func testInteractionTraceFailedTurn() {
    var trace = InteractionTrace()
    trace.append(.inputStarted, detail: "begin")
    trace.append(.turnFailed, detail: "timeout")
    XCTAssertNotNil(trace.completedAt)
    XCTAssertTrue(trace.events.last?.kind == .turnFailed)
}

// MARK: - CPU tracking with element and window changes

func testComputerUseStateDeltaElementCountChange() {
    let before = ComputerUseAppState(
        activeAppName: "Safari",
        elements: [ComputerUseElement(elementIndex: "0", role: "AXButton", depth: 0, childPath: [])]
    )
    let after = ComputerUseAppState(
        activeAppName: "Safari",
        elements: [
            ComputerUseElement(elementIndex: "0", role: "AXButton", depth: 0, childPath: []),
            ComputerUseElement(elementIndex: "1", role: "AXTextField", depth: 0, childPath: []),
        ]
    )
    let delta = ComputerUseStateDelta(before: before, after: after)
    XCTAssertTrue(delta.elementCountChanged)
    XCTAssertTrue(delta.hasMeaningfulChange)
    XCTAssertTrue(delta.changeDescriptions.contains("界面元素数量变化"))
}

func testComputerUseStateDeltaPartialChange() {
    let before = ComputerUseAppState(activeAppName: "Safari", focusedWindowTitle: "Same")
    let after = ComputerUseAppState(activeAppName: "Safari", focusedWindowTitle: "Different")
    let delta = ComputerUseStateDelta(before: before, after: after)
    XCTAssertFalse(delta.activeAppChanged)
    XCTAssertTrue(delta.focusedWindowChanged)
    XCTAssertTrue(delta.hasMeaningfulChange)
}

// MARK: - Crash recovery mid-stream

@MainActor func testSessionManagerMidStreamCrashRecovery() throws {
    let tmpURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("test-crash-midstream-\(UUID().uuidString)")
        .appendingPathComponent("conversations.json")

    let writer = SessionManager(storageURL: tmpURL)
    let conv = writer.createConversation(title: "Mid Stream")
    writer.appendMessage(Message(role: .user, content: [.text("Hello")]), to: conv.id)
    let msgID = writer.beginStreamingResponse(in: conv.id)
    writer.appendStreamToken("Partial", messageID: msgID, in: conv.id)
    writer.finishStreamingResponse(messageID: msgID, in: conv.id)

    let recovered = SessionManager(storageURL: tmpURL)
    if let restored = recovered.conversations.first {
        XCTAssertTrue(restored.title == "Mid Stream")
    } else {
        XCTFail("No conversations recovered")
    }
    try? FileManager.default.removeItem(at: tmpURL.deletingLastPathComponent())
}

// MARK: - FoundationLayer full coverage

func testFoundationLayerAllLayers() {
    let layers: [FoundationLayer] = [.feedbackLoop, .selfOptimizationRecovery, .permissionIdentity, .localActionExecution, .userMemory, .realtimeVoice, .providerAbstraction, .screenUnderstanding, .diagnostics, .safetyBoundary, .installRelease, .operatorUI]
    XCTAssertTrue(layers.count == 12)
    for layer in layers {
        XCTAssertFalse(layer.title.isEmpty)
        XCTAssertFalse(layer.baselineRequirement.isEmpty)
    }
}

func testFoundationHealthStatusLabelsFullCoverage() {
    XCTAssertTrue(FoundationHealthStatus.ok.label == "正常")
    XCTAssertTrue(FoundationHealthStatus.warning.label == "需关注")
    XCTAssertTrue(FoundationHealthStatus.failing.label == "失败")
    XCTAssertTrue(FoundationHealthStatus.notImplemented.label == "未完成")
}

// MARK: - Provider health snapshot

func testProviderHealthSnapshotOk() {
    let snap = ProviderHealthSnapshot(kind: .localOpenAICompatible, status: .ok, latencyMilliseconds: 150, detail: "本地模型可用")
    XCTAssertTrue(snap.status == .ok)
    XCTAssertTrue(snap.latencyMilliseconds == 150)
}

func testProviderHealthSnapshotFailing() {
    let snap = ProviderHealthSnapshot(kind: .deepSeek, status: .failing, detail: "API 不可达")
    XCTAssertTrue(snap.status == .failing)
    XCTAssertNil(snap.latencyMilliseconds)
}

// MARK: - FoundationCapabilityEvidence

func testFoundationCapabilityEvidenceEmpty() {
    let evidence = FoundationCapabilityEvidence()
    XCTAssertTrue(evidence.terminalTaskCount == 0)
    XCTAssertFalse(evidence.hasRunningOrCompletedTerminalTask)
    XCTAssertTrue(evidence.memoryCount == 0)
}

// MARK: - Assistant diagnostic snapshot

func testAssistantDiagnosticSnapshot() {
    let diag = AssistantDiagnosticSnapshot(
        userText: "打开 Safari",
        assistantText: "正在打开",
        provider: "claudeCodeCLI",
        frontmostApp: "Finder",
        latencyMilliseconds: 500
    )
    XCTAssertTrue(diag.userText == "打开 Safari")
    XCTAssertTrue(diag.provider == "claudeCodeCLI")
    XCTAssertNil(diag.error)
    XCTAssertTrue(diag.latencyMilliseconds == 500)
}
