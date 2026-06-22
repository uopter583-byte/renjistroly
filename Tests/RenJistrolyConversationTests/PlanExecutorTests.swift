import Foundation
import XCTest
import RenJistrolyModels
import RenJistrolySystemBridge
import RenJistrolyIntelligence
import RenJistrolyCapability
@testable import RenJistrolyConversation

// MARK: - DeveloperLoop static helpers

func testBuildFixPromptFormatsErrors() {
    let errors = [
        BuildDiagnostic(filePath: "Foo.swift", line: 42, column: 10, message: "Cannot find 'Foo' in scope", severity: .error),
        BuildDiagnostic(filePath: "Bar.swift", line: 15, message: "Type 'Int' has no member 'bar'", severity: .error),
    ]
    let result = DeveloperLoop.buildFixPrompt(errors: errors, originalPrompt: "add feature")
    XCTAssertTrue(result.contains("add feature"))
    XCTAssertTrue(result.contains("Foo.swift:42"))
    XCTAssertTrue(result.contains("Cannot find 'Foo' in scope"))
    XCTAssertTrue(result.contains("Bar.swift:15"))
    XCTAssertTrue(result.contains("Type 'Int' has no member 'bar'"))
    XCTAssertTrue(result.contains("fix ALL the compilation errors"))
}

func testBuildFixPromptNoErrors() {
    let result = DeveloperLoop.buildFixPrompt(errors: [], originalPrompt: "refactor")
    XCTAssertTrue(result.contains("refactor"))
    XCTAssertTrue(result.contains("fix ALL the compilation errors"))
}

func testBuildTestFixPromptFormatsFailures() {
    let changes = [
        ClaudeCodeStructuredResult.FileChange(path: "LoginView.swift", kind: .modified),
        ClaudeCodeStructuredResult.FileChange(path: "Auth.swift", kind: .created),
    ]
    let failures = ["XCTAssertEqual failed: expected 5 got 6", "Fatal error: unexpectedly found nil"]
    let result = DeveloperLoop.buildTestFixPrompt(failures: failures, fileChanges: changes)
    XCTAssertTrue(result.contains("LoginView.swift"))
    XCTAssertTrue(result.contains("Auth.swift"))
    XCTAssertTrue(result.contains("XCTAssertEqual failed"))
    XCTAssertTrue(result.contains("unexpectedly found nil"))
    XCTAssertTrue(result.contains("fix the code to make all tests pass"))
}

func testExtractTestFailures() {
    let output = """
    Test Suite 'All tests' started
    XCTAssertEqual failed: ("42") is not equal to ("43")
    Test Case '-[FooTests testBar]' failed (0.001 seconds).
    error: use of unresolved identifier 'baz'
    Test Suite 'All tests' failed.
    """
    let failures = DeveloperLoop.extractTestFailures(from: output)
    XCTAssertTrue(failures.count == 4)
}

func testExtractTestFailuresAllPassing() {
    let output = "Test run with 42 tests passed after 3.2 seconds."
    let failures = DeveloperLoop.extractTestFailures(from: output)
    XCTAssertTrue(failures.isEmpty)
}

func testBuildSummaryNoChanges() {
    let result = DeveloperLoop.buildSummary(fileChanges: [], retryCount: 0, allOutput: "ok")
    XCTAssertTrue(result.contains("一次性通过"))
}

func testBuildSummaryWithRetries() {
    let changes = [
        ClaudeCodeStructuredResult.FileChange(path: "A.swift", kind: .modified),
        ClaudeCodeStructuredResult.FileChange(path: "B.swift", kind: .created),
    ]
    let result = DeveloperLoop.buildSummary(fileChanges: changes, retryCount: 2, allOutput: "")
    XCTAssertTrue(result.contains("1 新建"))
    XCTAssertTrue(result.contains("1 修改"))
    XCTAssertTrue(result.contains("2 次后通过"))
}

func testBuildSummaryWithOnlyCreatedFiles() {
    let changes = [
        ClaudeCodeStructuredResult.FileChange(path: "NewFile.swift", kind: .created),
    ]
    let result = DeveloperLoop.buildSummary(fileChanges: changes, retryCount: 0, allOutput: "")
    XCTAssertTrue(result.contains("1 新建"))
    XCTAssertTrue(result.contains("0 修改"))
}

// MARK: - LoopState

func testLoopStateInitialPhase() {
    let state = DeveloperLoop.LoopState()
    XCTAssertTrue(state.phase == .planning)
    XCTAssertFalse(state.isTerminal)
    XCTAssertTrue(state.retryCount == 0)
    XCTAssertTrue(state.buildErrors.isEmpty)
    XCTAssertTrue(state.testFailures.isEmpty)
}

func testLoopStateTerminalPhases() {
    var completed = DeveloperLoop.LoopState()
    completed.phase = .completed
    XCTAssertTrue(completed.isTerminal)

    var failed = DeveloperLoop.LoopState()
    failed.phase = .failed
    XCTAssertTrue(failed.isTerminal)
}

func testLoopStateNonTerminalPhases() {
    for phase: DeveloperLoop.Phase in [.planning, .building, .fixing, .testing, .verifying, .summarizing] {
        var state = DeveloperLoop.LoopState()
        state.phase = phase
        XCTAssertFalse(state.isTerminal)
    }
}

// MARK: - DeveloperLoopEvent

func testDeveloperLoopEventIsSendable() {
    let events: [DeveloperLoopEvent] = [
        .phaseChange(.planning),
        .token("hello"),
        .toolCall(name: "click"),
        .toolError(name: "click", error: "not found"),
        .llmError("timeout"),
        .buildFailed(errors: ["e1"]),
        .buildSucceeded,
        .testFailed(failures: ["f1"]),
        .testSucceeded,
        .patchApplied(summary: "fixed"),
        .verificationResult(buildPassed: true),
        .loopExhausted(reason: "too many retries"),
        .completed(summary: "done"),
    ]
    XCTAssertTrue(events.count == 13)
}

// MARK: - PlanExecutor basic logic (approval/cancellation)

@MainActor func testPlanExecutorCancelPlan() {
    let sessionManager = SessionManager()
    let mcpClient = MCPClient()
    let planExecutor = PlanExecutor(
        sessionManager: sessionManager,
        agentOrchestrator: AgentOrchestrator(smartRouter: SmartRouter()),
        mcpClient: mcpClient,
        contextCompiler: ContextCompiler(),
        computerUseRuntime: ComputerUseRuntime(client: mcpClient),
        toolExecutionService: ToolExecutionService()
    )

    let appState = AppState()
    appState.activePlan = ExecutionPlan(
        id: UUID(),
        title: "Test Plan",
        steps: [
            PlanStep(description: "Step 1", status: .pending),
            PlanStep(description: "Step 2", status: .pending),
        ]
    )

    planExecutor.cancelPlan(appState: appState)
    XCTAssertTrue(appState.activePlan?.status == .cancelled)
}

@MainActor func testPlanExecutorCancelPlanNoActivePlan() {
    let sessionManager = SessionManager()
    let mcpClient = MCPClient()
    let planExecutor = PlanExecutor(
        sessionManager: sessionManager,
        agentOrchestrator: AgentOrchestrator(smartRouter: SmartRouter()),
        mcpClient: mcpClient,
        contextCompiler: ContextCompiler(),
        computerUseRuntime: ComputerUseRuntime(client: mcpClient),
        toolExecutionService: ToolExecutionService()
    )

    let appState = AppState()
    // No active plan set — should not crash
    planExecutor.cancelPlan(appState: appState)
    XCTAssertTrue(appState.activePlan == nil)
}

// MARK: - DeveloperLoop buildFixPrompt edge cases

func testBuildFixPromptWithMixedSeverities() {
    let errors = [
        BuildDiagnostic(filePath: "A.swift", line: 1, column: 1, message: "error one", severity: .error),
        BuildDiagnostic(filePath: "A.swift", line: 5, message: "warning one", severity: .warning),
        BuildDiagnostic(filePath: nil, line: nil, message: "global error", severity: .error),
    ]
    let result = DeveloperLoop.buildFixPrompt(errors: errors, originalPrompt: "test")
    XCTAssertTrue(result.contains("unknown"))
    XCTAssertTrue(result.contains("global error"))
    XCTAssertTrue(result.contains("fix ALL the compilation errors"))
}

func testBuildFixPromptEmptyPrompt() {
    let errors = [BuildDiagnostic(filePath: "X.swift", line: 1, message: "err", severity: .error)]
    let result = DeveloperLoop.buildFixPrompt(errors: errors, originalPrompt: "")
    XCTAssertTrue(result.contains("X.swift:1"))
    XCTAssertTrue(result.contains("err"))
}

func testBuildTestFixPromptNoChanges() {
    let failures = ["test failed"]
    let result = DeveloperLoop.buildTestFixPrompt(failures: failures, fileChanges: [])
    XCTAssertTrue(result.contains("test failed"))
    XCTAssertTrue(result.contains("fix the code to make all tests pass"))
}

func testBuildTestFixPromptEmptyFailures() {
    let changes = [ClaudeCodeStructuredResult.FileChange(path: "A.swift", kind: .modified)]
    let result = DeveloperLoop.buildTestFixPrompt(failures: [], fileChanges: changes)
    XCTAssertTrue(result.contains("A.swift"))
}

// MARK: - extractTestFailures edge cases

func testExtractTestFailuresEmpty() {
    let result = DeveloperLoop.extractTestFailures(from: "")
    XCTAssertTrue(result.isEmpty)
}

func testExtractTestFailuresXCTAssertOnly() {
    let output = "XCTAssertEqual failed: expected true got false"
    let failures = DeveloperLoop.extractTestFailures(from: output)
    XCTAssertTrue(failures.count == 1)
}

func testExtractTestFailuresMixed() {
    let output = """
    error: build failed
    XCTAssertNil failed
    Test Case 'Foo' failed
    """
    let failures = DeveloperLoop.extractTestFailures(from: output)
    XCTAssertTrue(failures.count == 3)
}

// MARK: - buildSummary edge cases

func testBuildSummaryAllKinds() {
    let changes = [
        ClaudeCodeStructuredResult.FileChange(path: "New.swift", kind: .created),
        ClaudeCodeStructuredResult.FileChange(path: "Mod.swift", kind: .modified),
        ClaudeCodeStructuredResult.FileChange(path: "Del.swift", kind: .deleted),
    ]
    let result = DeveloperLoop.buildSummary(fileChanges: changes, retryCount: 3, allOutput: "")
    XCTAssertTrue(result.contains("1 新建"))
    XCTAssertTrue(result.contains("1 修改"))
    XCTAssertTrue(result.contains("3 次后通过"))
}

func testBuildSummaryZeroRetriesNoChanges() {
    let result = DeveloperLoop.buildSummary(fileChanges: [], retryCount: 0, allOutput: "")
    XCTAssertTrue(result.contains("一次性通过"))
}

func testBuildSummaryWithDeletedOnly() {
    let changes = [ClaudeCodeStructuredResult.FileChange(path: "Old.swift", kind: .deleted)]
    let result = DeveloperLoop.buildSummary(fileChanges: changes, retryCount: 0, allOutput: "")
    XCTAssertTrue(result.contains("0 新建"))
    XCTAssertTrue(result.contains("0 修改"))
}

// MARK: - LoopState tracking

func testLoopStateTracksRetries() {
    var state = DeveloperLoop.LoopState()
    XCTAssertTrue(state.retryCount == 0)
    state.retryCount = 2
    XCTAssertTrue(state.retryCount == 2)
    state.retryCount = 3
    XCTAssertTrue(state.retryCount == 3)
}

func testLoopStateTracksBuildErrors() {
    var state = DeveloperLoop.LoopState()
    state.buildErrors = [
        BuildDiagnostic(filePath: "A.swift", line: 1, message: "e1", severity: .error),
        BuildDiagnostic(filePath: "B.swift", line: 2, message: "e2", severity: .error),
    ]
    XCTAssertTrue(state.buildErrors.count == 2)
    XCTAssertTrue(state.buildErrors[0].filePath == "A.swift")
}

func testLoopStateTracksTestFailures() {
    var state = DeveloperLoop.LoopState()
    state.testFailures = ["fail1", "fail2", "fail3"]
    XCTAssertTrue(state.testFailures.count == 3)
    state.testFailures.append("fail4")
    XCTAssertTrue(state.testFailures.count == 4)
}

func testLoopStateTracksFileChanges() {
    var state = DeveloperLoop.LoopState()
    state.fileChanges = [
        .init(path: "A.swift", kind: .created),
        .init(path: "B.swift", kind: .modified),
    ]
    XCTAssertTrue(state.fileChanges.count == 2)
    XCTAssertTrue(state.fileChanges[0].path == "A.swift")
}

func testLoopStateLastPatchSummary() {
    var state = DeveloperLoop.LoopState()
    XCTAssertTrue(state.lastPatchSummary == nil)
    state.lastPatchSummary = "fixed compilation errors"
    XCTAssertTrue(state.lastPatchSummary == "fixed compilation errors")
}

func testLoopStateAllOutputAccumulates() {
    var state = DeveloperLoop.LoopState()
    XCTAssertTrue(state.allOutput.isEmpty)
    state.allOutput = "build output"
    state.allOutput += "\ntest output"
    XCTAssertTrue(state.allOutput.contains("build"))
    XCTAssertTrue(state.allOutput.contains("test"))
}

// MARK: - DeveloperLoopEvent enum

func testDeveloperLoopEventPhaseChangeValues() {
    let event = DeveloperLoopEvent.phaseChange(.building)
    if case .phaseChange(let phase) = event {
        XCTAssertTrue(phase == .building)
    } else {
        XCTFail("unexpected false")
    }
}

func testDeveloperLoopEventToolCallValues() {
    let event = DeveloperLoopEvent.toolCall(name: "Bash")
    if case .toolCall(let name) = event {
        XCTAssertTrue(name == "Bash")
    } else {
        XCTFail("unexpected false")
    }
}

func testDeveloperLoopEventBuildFailedValues() {
    let event = DeveloperLoopEvent.buildFailed(errors: ["e1", "e2"])
    if case .buildFailed(let errors) = event {
        XCTAssertTrue(errors.count == 2)
        XCTAssertTrue(errors[0] == "e1")
    } else {
        XCTFail("unexpected false")
    }
}

func testDeveloperLoopEventTestFailedValues() {
    let event = DeveloperLoopEvent.testFailed(failures: ["f1"])
    if case .testFailed(let failures) = event {
        XCTAssertTrue(failures.count == 1)
    } else {
        XCTFail("unexpected false")
    }
}

func testDeveloperLoopEventPatchAppliedValues() {
    let event = DeveloperLoopEvent.patchApplied(summary: "fixed")
    if case .patchApplied(let summary) = event {
        XCTAssertTrue(summary == "fixed")
    } else {
        XCTFail("unexpected false")
    }
}

func testDeveloperLoopEventVerificationResult() {
    let pass = DeveloperLoopEvent.verificationResult(buildPassed: true)
    if case .verificationResult(let ok) = pass {
        XCTAssertTrue(ok)
    } else {
        XCTFail("unexpected false")
    }

    let fail = DeveloperLoopEvent.verificationResult(buildPassed: false)
    if case .verificationResult(let ok) = fail {
        XCTAssertFalse(ok)
    } else {
        XCTFail("unexpected false")
    }
}

func testDeveloperLoopEventLoopExhausted() {
    let event = DeveloperLoopEvent.loopExhausted(reason: "too many retries")
    if case .loopExhausted(let reason) = event {
        XCTAssertTrue(reason.contains("retries"))
    } else {
        XCTFail("unexpected false")
    }
}

func testDeveloperLoopEventCompleted() {
    let event = DeveloperLoopEvent.completed(summary: "all done")
    if case .completed(let summary) = event {
        XCTAssertTrue(summary == "all done")
    } else {
        XCTFail("unexpected false")
    }
}

func testDeveloperLoopEventTestSucceeded() {
    let event = DeveloperLoopEvent.testSucceeded
    if case .testSucceeded = event {
        // expected
    } else {
        XCTFail("unexpected false")
    }
}

// MARK: - DeveloperLoop Phase all values

func testDeveloperLoopAllPhases() {
    let phases: [DeveloperLoop.Phase] = [.planning, .building, .fixing, .testing, .verifying, .summarizing, .completed, .failed]
    XCTAssertTrue(phases.count == 8)
    for phase in phases {
        XCTAssertFalse(phase.rawValue.isEmpty)
    }
}

func testDeveloperLoopPhaseRawValues() {
    XCTAssertTrue(DeveloperLoop.Phase.planning.rawValue == "planning")
    XCTAssertTrue(DeveloperLoop.Phase.building.rawValue == "building")
    XCTAssertTrue(DeveloperLoop.Phase.fixing.rawValue == "fixing")
    XCTAssertTrue(DeveloperLoop.Phase.testing.rawValue == "testing")
    XCTAssertTrue(DeveloperLoop.Phase.completed.rawValue == "completed")
    XCTAssertTrue(DeveloperLoop.Phase.failed.rawValue == "failed")
}
