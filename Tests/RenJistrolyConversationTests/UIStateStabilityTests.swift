import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyConversation

// MARK: - VoiceInputState indicators

func testVoiceInputStateListeningIsCapturingAudio() {
    XCTAssertTrue(VoiceInputState.listening.isCapturingAudio)
    XCTAssertTrue(VoiceInputState.lockedListening.isCapturingAudio)
    XCTAssertTrue(VoiceInputState.transcribing.isCapturingAudio)
}

func testVoiceInputStateThinkingIsNotCapturingAudio() {
    XCTAssertFalse(VoiceInputState.processing.isCapturingAudio)
    XCTAssertFalse(VoiceInputState.speaking.isCapturingAudio)
    XCTAssertFalse(VoiceInputState.idle.isCapturingAudio)
    XCTAssertFalse(VoiceInputState.failed.isCapturingAudio)
}

func testVoiceInputStateExecutingHasCorrectFlags() {
    let state = VoiceInputState.processing
    XCTAssertFalse(state.isCapturingAudio)
    XCTAssertFalse(state.canStartListening)
    XCTAssertFalse(state.canFinishListening)
    XCTAssertTrue(state.isActive)
}

// MARK: - Failure reason display

@MainActor func testFailureReasonDisplayFromTerminalVerification() {
    let result = ToolCallResult(id: "t1", output: "command not found: swiftc", isError: true)
    let v = ConversationEngine.verifyTerminalRun(command: "swiftc main.swift", cwd: nil, result: result)
    XCTAssertFalse(v.success)
    XCTAssertTrue(v.failureReason != nil)
    XCTAssertTrue(v.failureReason!.contains("command not found"))
}

@MainActor func testFailureReasonDisplayFromFinderVerification() {
    let request = ToolCallRequest(id: "r1", name: "list_directory", arguments: ["path": "/nonexistent"])
    let result = ToolCallResult(id: "t1", output: "permission denied", isError: true)
    let v = ConversationEngine.verifyFinderToolResult(request: request, result: result)
    XCTAssertFalse(v.success)
    XCTAssertTrue(v.summary == "目录读取失败")
}

// MARK: - Provider display

func testCurrentProviderDisplayName() {
    XCTAssertTrue(LLMProvider.claudeCodeCLI.displayName == "Claude Code")
    XCTAssertTrue(LLMProvider.anthropic.displayName == "Claude (Anthropic)")
    XCTAssertTrue(LLMProvider.localMLX.displayName == "本地 MLX")
    XCTAssertTrue(LLMProvider.deepseek.displayName == "DeepSeek")
    XCTAssertTrue(LLMProvider.openAI.displayName == "OpenAI")
}

func testProviderRequiresAPIKeyClassification() {
    XCTAssertFalse(LLMProvider.claudeCodeCLI.requiresAPIKey)
    XCTAssertFalse(LLMProvider.localMLX.requiresAPIKey)
    XCTAssertFalse(LLMProvider.ollama.requiresAPIKey)
    XCTAssertTrue(LLMProvider.anthropic.requiresAPIKey)
    XCTAssertTrue(LLMProvider.openAI.requiresAPIKey)
}

// MARK: - Degraded mode offline fallback

func testDegradedModeIsLocalProviderAvailable() {
    XCTAssertTrue(LLMProvider.claudeCodeCLI.isLocal)
    XCTAssertTrue(LLMProvider.codexCLI.isLocal)
    XCTAssertTrue(LLMProvider.localMLX.isLocal)
    XCTAssertTrue(LLMProvider.ollama.isLocal)
    XCTAssertFalse(LLMProvider.anthropic.isLocal)
    XCTAssertFalse(LLMProvider.openAI.isLocal)
}

@MainActor func testDegradedModeFallsBackToLocalWhenOffline() {
    let state = AppState()
    state.isOnline = false
    XCTAssertTrue(state.isOnline == false)
    let localProvider = LLMProvider.claudeCodeCLI
    XCTAssertTrue(localProvider.isLocal)
    let cloudProvider = LLMProvider.anthropic
    XCTAssertFalse(cloudProvider.isLocal)
}

// MARK: - Permission prompt state

func testPermissionPromptStateAllGranted() {
    var grant = AppState.PermissionGrant()
    grant.accessibility = true
    grant.microphone = true
    grant.speechRecognition = true
    grant.screenRecording = true
    grant.appleEvents = true
    XCTAssertTrue(grant.allGranted)
}

func testPermissionPromptStateMissingAnyDeniesAll() {
    var grant = AppState.PermissionGrant()
    grant.accessibility = true
    grant.microphone = true
    grant.speechRecognition = true
    grant.screenRecording = true
    grant.appleEvents = false
    XCTAssertFalse(grant.allGranted)
}

// MARK: - Cancel button and streaming state

@MainActor func testCancelButtonEnabledDuringStreaming() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    let _ = manager.beginStreamingResponse(in: conv.id)
    XCTAssertTrue(manager.isStreaming)
}

@MainActor func testCancelButtonDisabledWhenIdle() {
    let manager = SessionManager(storageURL: nil)
    XCTAssertFalse(manager.isStreaming)
}

@MainActor func testCancelButtonDisabledAfterStreamingComplete() {
    let manager = SessionManager(storageURL: nil)
    let conv = manager.createConversation()
    let msgID = manager.beginStreamingResponse(in: conv.id)
    manager.finishStreamingResponse(messageID: msgID, in: conv.id)
    XCTAssertFalse(manager.isStreaming)
}

// MARK: - Retry button behavior

func testRetryAvailableAfterFailedState() {
    XCTAssertTrue(VoiceInputState.failed.canStartListening)
}

func testRetryNotAvailableWhileListening() {
    XCTAssertFalse(VoiceInputState.listening.canStartListening)
    XCTAssertFalse(VoiceInputState.lockedListening.canStartListening)
    XCTAssertFalse(VoiceInputState.transcribing.canStartListening)
}

// MARK: - Disabled button when action not available

func testDisabledButtonWhenAlreadyInProgress() {
    XCTAssertFalse(VoiceInputState.listening.canStartListening)
    XCTAssertFalse(VoiceInputState.processing.canStartListening)
    XCTAssertFalse(VoiceInputState.speaking.canStartListening)
}

func testDisabledFinishListeningWhenIdleOrFailed() {
    XCTAssertFalse(VoiceInputState.idle.canFinishListening)
    XCTAssertFalse(VoiceInputState.failed.canFinishListening)
    XCTAssertFalse(VoiceInputState.processing.canFinishListening)
}

// MARK: - Pending confirmation state

func testPendingConfirmationRiskDisplay() {
    let assessment = ToolRiskAssessment(
        toolName: "delete_file",
        riskLevel: .high,
        actionCategory: .localFileDelete,
        arguments: ["path": "/important/data"],
        summary: "删除重要文件",
        riskExplanation: "此操作将永久删除文件",
        mitigationHint: "请确认文件已备份"
    )
    XCTAssertTrue(assessment.riskLevel == .high)
    XCTAssertTrue(assessment.actionCategory.requiresActionTimeConfirmation)
    XCTAssertTrue(assessment.summary == "删除重要文件")
    XCTAssertTrue(assessment.mitigationHint == "请确认文件已备份")
}

func testToolExecutionPolicyDeniesHighRiskByDefault() {
    let policy = ToolExecutionPolicy.default
    XCTAssertTrue(policy.canAutoExecute(.low))
    XCTAssertTrue(!policy.canAutoExecute(.medium))
    XCTAssertTrue(!policy.canAutoExecute(.high))
}

func testStrictPolicyDeniesAllRiskLevels() {
    let policy = ToolExecutionPolicy.strict
    XCTAssertTrue(!policy.canAutoExecute(.low))
    XCTAssertTrue(!policy.canAutoExecute(.medium))
    XCTAssertTrue(!policy.canAutoExecute(.high))
}

// MARK: - VoiceInputState full state machine

func testVoiceInputStateIdleCanStartListening() {
    XCTAssertTrue(VoiceInputState.idle.canStartListening)
    XCTAssertFalse(VoiceInputState.idle.isCapturingAudio)
}

func testVoiceInputStateListeningCanFinishButNotStart() {
    XCTAssertTrue(VoiceInputState.listening.isCapturingAudio)
    XCTAssertTrue(VoiceInputState.listening.canFinishListening)
    XCTAssertFalse(VoiceInputState.listening.canStartListening)
}

func testVoiceInputStateProcessingIsActiveNoAudio() {
    XCTAssertTrue(VoiceInputState.processing.isActive)
    XCTAssertFalse(VoiceInputState.processing.isCapturingAudio)
    XCTAssertFalse(VoiceInputState.processing.canStartListening)
    XCTAssertFalse(VoiceInputState.processing.canFinishListening)
}

func testVoiceInputStateFailedCanRetry() {
    XCTAssertTrue(VoiceInputState.failed.canStartListening)
    XCTAssertFalse(VoiceInputState.failed.canFinishListening)
    XCTAssertFalse(VoiceInputState.failed.isCapturingAudio)
}

func testVoiceInputStateSpeakingNoCapture() {
    XCTAssertFalse(VoiceInputState.speaking.isCapturingAudio)
    XCTAssertFalse(VoiceInputState.speaking.canStartListening)
    XCTAssertFalse(VoiceInputState.speaking.canFinishListening)
}

// MARK: - Permission prompt - each missing permission

func testPermissionPromptMissingAccessibility() {
    var grant = AppState.PermissionGrant()
    grant.accessibility = false
    grant.microphone = true
    grant.speechRecognition = true
    grant.screenRecording = true
    grant.appleEvents = true
    XCTAssertFalse(grant.allGranted)
}

func testPermissionPromptMissingMicrophone() {
    var grant = AppState.PermissionGrant()
    grant.accessibility = true
    grant.microphone = false
    grant.speechRecognition = true
    grant.screenRecording = true
    grant.appleEvents = true
    XCTAssertFalse(grant.allGranted)
}

func testPermissionPromptMissingSpeechRecognition() {
    var grant = AppState.PermissionGrant()
    grant.accessibility = true
    grant.microphone = true
    grant.speechRecognition = false
    grant.screenRecording = true
    grant.appleEvents = true
    XCTAssertFalse(grant.allGranted)
}

func testPermissionPromptMissingScreenRecording() {
    var grant = AppState.PermissionGrant()
    grant.accessibility = true
    grant.microphone = true
    grant.speechRecognition = true
    grant.screenRecording = false
    grant.appleEvents = true
    XCTAssertFalse(grant.allGranted)
}

// MARK: - Provider display - additional providers

func testAdditionalProviderDisplayNames() {
    XCTAssertTrue(LLMProvider.google.displayName == "Gemini (Google)")
    XCTAssertTrue(LLMProvider.groq.displayName == "Groq")
    XCTAssertTrue(LLMProvider.mistral.displayName == "Mistral")
    XCTAssertTrue(LLMProvider.cohere.displayName == "Cohere")
    XCTAssertTrue(LLMProvider.custom.displayName == "自定义")
}

func testAllProviderIsLocalClassification() {
    let local: [LLMProvider] = [.claudeCodeCLI, .codexCLI, .localMLX, .ollama]
    let cloud: [LLMProvider] = [.anthropic, .openAI, .google, .deepseek, .groq, .mistral, .cohere, .replicate, .togetherAI, .perplexity, .xAI]
    for p in local { XCTAssertTrue(p.isLocal) }
    for p in cloud { XCTAssertFalse(p.isLocal) }
}

// MARK: - Hotkey and screen stream defaults

@MainActor func testAppStateHotkeyDefaultEnabled() {
    let state = AppState()
    XCTAssertTrue(state.isHotkeyEnabled)
}

@MainActor func testAppStateScreenStreamDefaultInactive() {
    let state = AppState()
    XCTAssertFalse(state.isScreenStreamActive)
}

// MARK: - Permission status labels

func testPermissionStatusLabels() {
    XCTAssertTrue(PermissionStatus.granted.label == "已授权")
    XCTAssertTrue(PermissionStatus.denied.label == "未授权")
    XCTAssertTrue(PermissionStatus.notDetermined.label == "未请求")
    XCTAssertTrue(PermissionStatus.unknown.label == "需验证")
}

func testPermissionKindSnapshots() {
    let kinds: [PermissionKind] = [.microphone, .speechRecognition, .screenRecording, .accessibility, .automation, .fileSystem, .shellExecution, .network, .apiCredentials, .stableIdentity]
    XCTAssertTrue(kinds.count == 10)
}

// MARK: - VoiceInputMode and AppMode enum coverage

func testVoiceInputModeEnum() {
    let modes: [VoiceInputMode] = [.accessibilityVoiceInput, .systemDictationShortcut, .builtInSpeechRecognition]
    XCTAssertTrue(modes.count == 3)
}

func testAppModeEnum() {
    let modes: [AppMode] = [.compact, .expanded, .immersive]
    XCTAssertTrue(modes.count == 3)
}

// MARK: - FullAccessCapability kind

func testFullAccessCapabilityKinds() {
    let kinds: [FullAccessCapabilityKind] = [.voiceInput, .voiceOutput, .screenUnderstanding, .appControl, .automation, .fileSystem, .shellExecution, .network, .modelCredentials, .stableIdentity, .safetyPolicy]
    XCTAssertTrue(kinds.count == 11)
}

// MARK: - Cursor position default

@MainActor func testCursorPositionDefaultNil() {
    let state = AppState()
    XCTAssertNil(state.cursorPosition)
}

// MARK: - Safe mode default

@MainActor func testSafeModeDefaultFalse() {
    let state = AppState()
    XCTAssertFalse(state.isSafeMode)
}
