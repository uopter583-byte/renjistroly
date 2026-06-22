import Foundation
import XCTest
import RenJistrolyModels

// MARK: - TraceEventKind

func testTraceEventKindLabels() {
    XCTAssertTrue(TraceEventKind.inputStarted.label == "输入开始")
    XCTAssertTrue(TraceEventKind.speechPartial.label == "语音部分")
    XCTAssertTrue(TraceEventKind.speechFinal.label == "语音结束")
    XCTAssertTrue(TraceEventKind.contextObserved.label == "上下文采集")
    XCTAssertTrue(TraceEventKind.routeSelected.label == "路由选择")
    XCTAssertTrue(TraceEventKind.modelFirstToken.label == "首个 Token")
    XCTAssertTrue(TraceEventKind.toolStarted.label == "工具执行")
    XCTAssertTrue(TraceEventKind.verifyDone.label == "验证完成")
    XCTAssertTrue(TraceEventKind.ttsStarted.label == "朗读开始")
    XCTAssertTrue(TraceEventKind.turnComplete.label == "回合完成")
    XCTAssertTrue(TraceEventKind.turnFailed.label == "回合失败")
}

func testTraceEventKindAllCasesCount() {
    XCTAssertTrue(TraceEventKind.allCases.count == 11)
}

// MARK: - TraceEvent

func testTraceEventDefaultDetail() {
    let event = TraceEvent(kind: .inputStarted)
    XCTAssertTrue(event.kind == .inputStarted)
    XCTAssertTrue(event.detail.isEmpty)
}

func testTraceEventWithDetail() {
    let event = TraceEvent(kind: .routeSelected, detail: "claudeCode")
    XCTAssertTrue(event.kind == .routeSelected)
    XCTAssertTrue(event.detail == "claudeCode")
}

func testTraceEventUniqueIDs() {
    let e1 = TraceEvent(kind: .inputStarted)
    let e2 = TraceEvent(kind: .inputStarted)
    XCTAssertTrue(e1.id != e2.id)
}

// MARK: - InteractionTrace

func testInteractionTraceInitialState() {
    let trace = InteractionTrace()
    XCTAssertTrue(trace.events.isEmpty)
    XCTAssertTrue(trace.completedAt == nil)
    XCTAssertTrue(trace.totalDuration == nil)
}

func testInteractionTraceAppend() {
    var trace = InteractionTrace()
    trace.append(.inputStarted)
    trace.append(.speechFinal, detail: "hello")
    XCTAssertTrue(trace.events.count == 2)
    XCTAssertTrue(trace.events[0].kind == .inputStarted)
    XCTAssertTrue(trace.events[1].kind == .speechFinal)
    XCTAssertTrue(trace.events[1].detail == "hello")
}

func testInteractionTraceCompletedAt() {
    var trace = InteractionTrace()
    XCTAssertTrue(trace.completedAt == nil)
    trace.append(.turnComplete)
    XCTAssertTrue(trace.completedAt != nil)
}

func testInteractionTraceCompletedAtFailed() {
    var trace = InteractionTrace()
    trace.append(.turnFailed)
    XCTAssertTrue(trace.completedAt != nil)
}

func testInteractionTraceTotalDuration() async throws {
    var trace = InteractionTrace()
    trace.append(.inputStarted)
    try await Task.sleep(for: .milliseconds(10))
    trace.append(.turnComplete)
    XCTAssertTrue(trace.totalDuration != nil)
    XCTAssertTrue(trace.totalDuration! >= 0.01)
}

func testInteractionTraceDurationBetween() {
    var trace = InteractionTrace()
    trace.append(.inputStarted)
    trace.append(.speechFinal)
    trace.append(.ttsStarted)
    let d = trace.duration(from: .inputStarted, to: .ttsStarted)
    XCTAssertTrue(d != nil)
    XCTAssertTrue(d! >= 0)
}

func testInteractionTraceDurationMissingKind() {
    var trace = InteractionTrace()
    trace.append(.inputStarted)
    XCTAssertTrue(trace.duration(from: .inputStarted, to: .turnComplete) == nil)
}

// MARK: - TraceLatencySummary

func testTraceLatencySummaryEmptyTrace() {
    let trace = InteractionTrace()
    let summary = TraceLatencySummary(from: trace)
    XCTAssertTrue(summary.asrMs == nil)
    XCTAssertTrue(summary.totalMs == nil)
    XCTAssertTrue(summary.eventCount == 0)
}

func testTraceLatencySummaryFullTrace() {
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
    XCTAssertTrue(summary.totalMs != nil)
    XCTAssertTrue(summary.asrMs != nil)
    XCTAssertTrue(summary.observeMs != nil)
    XCTAssertTrue(summary.routingMs != nil)
    XCTAssertTrue(summary.firstTokenMs != nil)
    XCTAssertTrue(summary.toolMs != nil)
    XCTAssertTrue(summary.ttsMs != nil)
}

func testTraceLatencySummaryMissingPhases() {
    var trace = InteractionTrace()
    trace.append(.inputStarted)
    trace.append(.turnComplete)
    let summary = TraceLatencySummary(from: trace)
    XCTAssertTrue(summary.asrMs == nil)
    XCTAssertTrue(summary.observeMs == nil)
    XCTAssertTrue(summary.eventCount == 2)
    XCTAssertTrue(summary.totalMs != nil)
}
