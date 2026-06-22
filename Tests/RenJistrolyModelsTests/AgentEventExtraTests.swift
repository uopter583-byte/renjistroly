import Foundation
import XCTest
import RenJistrolyModels

// MARK: - LifecycleEvent all cases

func testLifecycleEventAllCasesExist() {
    let events: [LifecycleEvent] = [
        .thinkingStarted(reason: "user asked"),
        .thinkingCompleted,
        .planningStarted(goal: "build feature"),
        .planningCompleted(steps: 3),
        .actingStarted(action: "click", tool: "click_at"),
        .actingCompleted(action: "click", success: true),
        .verifyingStarted(action: "click"),
        .verifyingCompleted(action: "click", passed: true),
        .recoveringStarted(action: "click", strategy: "retry"),
        .recoveringCompleted(action: "click", success: true),
        .taskDelegated(to: "code-agent", reason: "specialized"),
        .routeSelected(provider: "smart-router", confidence: 0.95),
        .providerFellback(from: "anthropic", to: "openai", reason: "rate limit"),
        .taskResumed(reason: "user approved"),
        .taskRetry(attempt: 1),
        .approvalRequired(prompt: "delete file?"),
        .taskStatusUpdate(summary: "working on it"),
        .contextObserved(detail: "Safari window"),
        .modelFirstToken,
        .observingStarted(action: "read_context"),
        .turnCompleted(duration: 2.5),
        .turnFailed(error: "network error"),
    ]
    XCTAssertTrue(events.count == 22)
}

// MARK: - AgentEvent cases

func testAgentEventDomainsDistinct() {
    let voiceEvent: AgentEvent = .voice(.listeningStarted)
    let desktopEvent: AgentEvent = .desktop(.appActivated(bundleID: "com.test", name: "Test"))
    let lifecycleEvent: AgentEvent = .lifecycle(.thinkingStarted(reason: "test"))
    XCTAssertTrue(voiceEvent.id != desktopEvent.id)
    XCTAssertTrue(desktopEvent.id != lifecycleEvent.id)
}
