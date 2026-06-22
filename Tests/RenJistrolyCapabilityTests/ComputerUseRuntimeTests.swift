import Foundation
import XCTest
import RenJistrolyModels
import RenJistrolySystemBridge
@testable import RenJistrolyCapability

// MARK: - Helpers

private func makeRuntime() -> ComputerUseRuntime {
    ComputerUseRuntime(client: MCPClient(registry: MCPToolRegistry()))
}

private func makeState(appName: String? = nil, windowTitle: String? = nil, elements: [ComputerUseElement] = []) -> ComputerUseAppState {
    ComputerUseAppState(
        activeAppName: appName,
        focusedWindowTitle: windowTitle,
        elements: elements
    )
}

private func makeElement(index: String, role: String = "AXButton", title: String? = nil, value: String? = nil, focused: Bool? = nil, frame: CodableRect? = nil, stableID: String? = nil) -> ComputerUseElement {
    ComputerUseElement(
        elementIndex: index,
        stableID: stableID,
        role: role,
        title: title,
        value: value,
        frame: frame,
        focused: focused,
        depth: 1,
        childPath: [0]
    )
}

private func makeDelta(before: ComputerUseAppState, after: ComputerUseAppState) -> ComputerUseStateDelta {
    ComputerUseStateDelta(before: before, after: after)
}

// MARK: - extractExitCode

func testExtractExitCodeZero() async {
    let runtime = makeRuntime()
    let r1 = await runtime.extractExitCode(from: "Process exited with exit code: 0")
    XCTAssertTrue(r1 == 0)
    let r2 = await runtime.extractExitCode(from: "Command exited with code 0 and output")
    XCTAssertTrue(r2 == 0)
    let r3 = await runtime.extractExitCode(from: "terminated with code 0")
    XCTAssertTrue(r3 == 0)
}

func testExtractExitCodeNonZero() async {
    let runtime = makeRuntime()
    let r1 = await runtime.extractExitCode(from: "exited with code 1")
    XCTAssertTrue(r1 == 1)
    let r2 = await runtime.extractExitCode(from: "exit code: 127")
    XCTAssertTrue(r2 == 127)
    let r3 = await runtime.extractExitCode(from: "terminated with code 255")
    XCTAssertTrue(r3 == 255)
}

func testExtractExitCodeNoMatch() async {
    let runtime = makeRuntime()
    let r1 = await runtime.extractExitCode(from: "Build complete!")
    XCTAssertTrue(r1 == nil)
    let r2 = await runtime.extractExitCode(from: "")
    XCTAssertTrue(r2 == nil)
}

// MARK: - normalizedExpectedText

func testNormalizedExpectedText() async {
    let runtime = makeRuntime()
    let r1 = await runtime.normalizedExpectedText(from: "  hello  ")
    XCTAssertTrue(r1 == "hello")
    let r2 = await runtime.normalizedExpectedText(from: "")
    XCTAssertTrue(r2 == nil)
    let r3 = await runtime.normalizedExpectedText(from: nil)
    XCTAssertTrue(r3 == nil)
}

func testNormalizedExpectedTextTruncatesLong() async {
    let runtime = makeRuntime()
    let long = String(repeating: "a", count: 100)
    let result = await runtime.normalizedExpectedText(from: long)
    XCTAssertTrue(result?.count == 80)
}

// MARK: - effectiveVerificationGoal

func testEffectiveVerificationGoalTypeText() async {
    let runtime = makeRuntime()
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "type_text", arguments: ["text": "hello world"])
    )
    let goal = await runtime.effectiveVerificationGoal(for: action)
    XCTAssertTrue(goal?.expectedText == "hello world")
}

func testEffectiveVerificationGoalSetValue() async {
    let runtime = makeRuntime()
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "set_value", arguments: ["value": "test", "app": "Notes"])
    )
    let goal = await runtime.effectiveVerificationGoal(for: action)
    XCTAssertTrue(goal?.expectedText == "test")
    XCTAssertTrue(goal?.expectedApp == "Notes")
}

func testEffectiveVerificationGoalFocusWindow() async {
    let runtime = makeRuntime()
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "focus_window", arguments: ["title": "Settings"])
    )
    let goal = await runtime.effectiveVerificationGoal(for: action)
    XCTAssertTrue(goal?.expectedWindowTitle == "Settings")
}

func testEffectiveVerificationGoalClickElement() async {
    let runtime = makeRuntime()
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "click_element", arguments: ["title": "OK", "role": "AXButton"])
    )
    let goal = await runtime.effectiveVerificationGoal(for: action)
    XCTAssertTrue(goal?.expectedText == "OK")
    XCTAssertTrue(goal?.expectedElementRole == "AXButton")
}

func testEffectiveVerificationGoalExplicit() async {
    let runtime = makeRuntime()
    let explicitGoal = VerificationGoal(expectedText: "explicit", expectedApp: "Safari")
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:]),
        verificationGoal: explicitGoal
    )
    let goal = await runtime.effectiveVerificationGoal(for: action)
    XCTAssertTrue(goal?.expectedText == "explicit")
}

func testEffectiveVerificationGoalUnknownTool() async {
    let runtime = makeRuntime()
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "unknown_tool", arguments: [:])
    )
    let goal = await runtime.effectiveVerificationGoal(for: action)
    XCTAssertTrue(goal == nil)
}

// MARK: - verifyPressKeyAction

func testVerifyPressKeyTabWithFocusChange() async {
    let runtime = makeRuntime()
    let before = makeState()
    let after = makeState(elements: [
        makeElement(index: "0", role: "AXTextField", focused: true),
    ])
    let delta = makeDelta(before: before, after: after)
    let result = await runtime.verifyPressKeyAction(key: "tab", modifiers: "", delta: delta)
    XCTAssertTrue(result.verified == true)
}

func testVerifyPressKeyTabNoFocusChange() async {
    let runtime = makeRuntime()
    let el = makeElement(index: "0")
    let before = makeState(elements: [el])
    let after = makeState(elements: [el])
    let delta = makeDelta(before: before, after: after)
    let result = await runtime.verifyPressKeyAction(key: "tab", modifiers: "", delta: delta)
    XCTAssertTrue(result.verified == false)
}

func testVerifyPressKeyReturnWithChange() async {
    let runtime = makeRuntime()
    let before = makeState(appName: "Safari")
    let after = makeState(appName: "Finder")
    let delta = makeDelta(before: before, after: after)
    let result = await runtime.verifyPressKeyAction(key: "return", modifiers: "", delta: delta)
    XCTAssertTrue(result.verified == true)
}

func testVerifyPressKeyReturnNoChange() async {
    let runtime = makeRuntime()
    let state = makeState()
    let delta = makeDelta(before: state, after: state)
    let result = await runtime.verifyPressKeyAction(key: "return", modifiers: "", delta: delta)
    XCTAssertTrue(result.verified == false)
}

func testVerifyPressKeyShortcutWithChange() async {
    let runtime = makeRuntime()
    let before = makeState(appName: "Safari")
    let after = makeState(appName: "Finder")
    let delta = makeDelta(before: before, after: after)
    let result = await runtime.verifyPressKeyAction(key: "l", modifiers: "cmd", delta: delta)
    XCTAssertTrue(result.verified == true)
}

func testVerifyPressKeyShortcutNoChange() async {
    let runtime = makeRuntime()
    let state = makeState()
    let delta = makeDelta(before: state, after: state)
    let result = await runtime.verifyPressKeyAction(key: "l", modifiers: "cmd", delta: delta)
    XCTAssertTrue(result.verified == false)
}

// MARK: - verifyActivateMenuAction

func testVerifyActivateMenuWithChange() async {
    let runtime = makeRuntime()
    let before = makeState(appName: "Safari")
    let after = makeState(appName: "Finder")
    let delta = makeDelta(before: before, after: after)
    let result = await runtime.verifyActivateMenuAction(path: "File/New Window", delta: delta)
    XCTAssertTrue(result.verified == true)
}

func testVerifyActivateMenuNoChange() async {
    let runtime = makeRuntime()
    let state = makeState()
    let delta = makeDelta(before: state, after: state)
    let result = await runtime.verifyActivateMenuAction(path: "Edit/Copy", delta: delta)
    XCTAssertTrue(result.verified == false)
}

// MARK: - recoveryStrategies

func testRecoveryStrategiesSnapshotStale() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "click", arguments: ["element_index": "0"])
    )
    let failedResult = ToolCallResult(id: "1", output: "找不到 UI 元素，快照已过期", isError: true)
    let strategies = ComputerUseRuntime.recoveryStrategies(
        action: action,
        app: nil,
        refreshed: nil,
        browserState: nil,
        failedResult: failedResult,
        remapped: nil
    )
    XCTAssertTrue(strategies.contains(.reobserveAndRetry))
}

func testRecoveryStrategiesBrowserNeedsReopen() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "open_url", arguments: ["url": "https://example.com"]),
        verificationGoal: VerificationGoal(expectedText: "example")
    )
    let failedResult = ToolCallResult(id: "1", output: "timeout", isError: true)
    let browserState = BrowserPageState(browserName: "Safari", host: "other.com")
    let strategies = ComputerUseRuntime.recoveryStrategies(
        action: action,
        app: nil,
        refreshed: nil,
        browserState: browserState,
        failedResult: failedResult,
        remapped: nil
    )
    XCTAssertTrue(strategies.contains(.reopenBrowserPage))
}

func testRecoveryStrategiesActivateTargetApp() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "click", arguments: ["element_index": "0"]),
        verificationGoal: VerificationGoal(expectedApp: "Safari")
    )
    let failedResult = ToolCallResult(id: "1", output: "timeout", isError: true)
    let refreshed = makeState(appName: "Finder")
    let strategies = ComputerUseRuntime.recoveryStrategies(
        action: action,
        app: nil,
        refreshed: refreshed,
        browserState: nil,
        failedResult: failedResult,
        remapped: nil
    )
    XCTAssertTrue(strategies.contains(.activateTargetApp))
}

func testRecoveryStrategiesClikHasCoordinateFallback() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "click", arguments: ["element_index": "0"])
    )
    let failedResult = ToolCallResult(id: "1", output: "some error", isError: true)
    let strategies = ComputerUseRuntime.recoveryStrategies(
        action: action,
        app: nil,
        refreshed: nil,
        browserState: nil,
        failedResult: failedResult,
        remapped: nil
    )
    XCTAssertTrue(strategies.contains(.coordinateClickFallback))
}

// MARK: - browserNeedsReopen

func testBrowserNeedsReopenMissingState() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "open_url", arguments: ["url": "https://example.com"])
    )
    XCTAssertTrue(ComputerUseRuntime.browserNeedsReopen(action: action, browserState: nil) == true)
}

func testBrowserNeedsReopenNonBrowserTool() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:])
    )
    XCTAssertTrue(ComputerUseRuntime.browserNeedsReopen(action: action, browserState: nil) == false)
}

func testBrowserNeedsReopenOpenURLMismatch() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "open_url", arguments: ["url": "https://target.com"]),
        verificationGoal: VerificationGoal(expectedText: "target")
    )
    let state = BrowserPageState(browserName: "Safari", host: "other.com")
    XCTAssertTrue(ComputerUseRuntime.browserNeedsReopen(action: action, browserState: state) == true)
}

func testBrowserNeedsReopenOpenURLMatch() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "open_url", arguments: ["url": "https://example.com"]),
        verificationGoal: VerificationGoal(expectedText: "example")
    )
    let state = BrowserPageState(browserName: "Safari", host: "example.com")
    XCTAssertTrue(ComputerUseRuntime.browserNeedsReopen(action: action, browserState: state) == false)
}

func testBrowserNeedsReopenSafariSearchMismatch() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "safari_search", arguments: ["query": "Swift"]),
        verificationGoal: VerificationGoal(expectedText: "Swift")
    )
    let state = BrowserPageState(browserName: "Safari", tabTitle: "Python", searchQuery: "Python")
    XCTAssertTrue(ComputerUseRuntime.browserNeedsReopen(action: action, browserState: state) == true)
}

func testBrowserNeedsReopenSafariSearchMatch() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "safari_search", arguments: ["query": "Swift"]),
        verificationGoal: VerificationGoal(expectedText: "Swift")
    )
    let state = BrowserPageState(browserName: "Safari", tabTitle: "Swift Programming")
    XCTAssertTrue(ComputerUseRuntime.browserNeedsReopen(action: action, browserState: state) == false)
}

// MARK: - browserRecoveryReason

func testBrowserRecoveryReasonOpenURL() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "open_url", arguments: ["url": "https://example.com"]),
        verificationGoal: VerificationGoal(expectedText: "example.com")
    )
    let state = BrowserPageState(browserName: "Safari", host: "other.com")
    let reason = ComputerUseRuntime.browserRecoveryReason(action: action, browserState: state)
    XCTAssertTrue(reason?.contains("other.com") == true)
    XCTAssertTrue(reason?.contains("example.com") == true)
}

func testBrowserRecoveryReasonOpenURLMatch() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "open_url", arguments: ["url": "https://example.com"]),
        verificationGoal: VerificationGoal(expectedText: "example")
    )
    let state = BrowserPageState(browserName: "Safari", host: "example.com")
    XCTAssertTrue(ComputerUseRuntime.browserRecoveryReason(action: action, browserState: state) == nil)
}

func testBrowserRecoveryReasonSafariSearchMismatch() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "safari_search", arguments: ["query": "weather"]),
        verificationGoal: VerificationGoal(expectedText: "weather")
    )
    let state = BrowserPageState(browserName: "Safari", tabTitle: "News", searchQuery: "news")
    let reason = ComputerUseRuntime.browserRecoveryReason(action: action, browserState: state)
    XCTAssertTrue(reason?.contains("news") == true)
    XCTAssertTrue(reason?.contains("weather") == true)
}

// MARK: - debugVerify (E2E verification through internal API)

func testDebugVerifyObservationTool() async {
    let runtime = makeRuntime()
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "get_app_state", arguments: [:])
    )
    let result = ToolCallResult(id: "1", output: "ok")
    let verified = await runtime.debugVerify(action: action, before: nil, state: nil, result: result)
    XCTAssertTrue(verified == true)
}

func testDebugVerifyErrorResult() async {
    let runtime = makeRuntime()
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:])
    )
    let result = ToolCallResult(id: "1", output: "execution failed", isError: true)
    let verified = await runtime.debugVerify(action: action, before: nil, state: nil, result: result)
    XCTAssertTrue(verified == false)
}

func testDebugVerifyAppMismatch() async {
    let runtime = makeRuntime()
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "open_app", arguments: ["app_name": "Safari"]),
        verificationGoal: VerificationGoal(expectedApp: "Safari")
    )
    let result = ToolCallResult(id: "1", output: "已打开")
    let state = makeState(appName: "Finder")
    let verified = await runtime.debugVerify(action: action, before: nil, state: state, result: result)
    XCTAssertTrue(verified == false)
}

func testDebugVerifyAppMatch() async {
    let runtime = makeRuntime()
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "open_app", arguments: ["app_name": "Safari"]),
        verificationGoal: VerificationGoal(expectedApp: "Safari")
    )
    let result = ToolCallResult(id: "1", output: "已打开")
    let state = makeState(appName: "Safari")
    let verified = await runtime.debugVerify(action: action, before: nil, state: state, result: result)
    XCTAssertTrue(verified == true)
}

func testDebugVerifyTextInState() async {
    let runtime = makeRuntime()
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "click", arguments: [:]),
        verificationGoal: VerificationGoal(expectedText: "Settings")
    )
    let result = ToolCallResult(id: "1", output: "ok")
    let element = makeElement(index: "0", role: "AXButton", title: "Settings")
    let state = makeState(appName: "System Preferences", elements: [element])
    let verified = await runtime.debugVerify(action: action, before: nil, state: state, result: result)
    XCTAssertTrue(verified == true)
}

func testDebugVerifyWindowTitleMismatch() async {
    let runtime = makeRuntime()
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "focus_window", arguments: ["title": "Terminal"]),
        verificationGoal: VerificationGoal(expectedWindowTitle: "Terminal")
    )
    let result = ToolCallResult(id: "1", output: "ok")
    let state = makeState(appName: "Terminal", windowTitle: "Safari")
    let verified = await runtime.debugVerify(action: action, before: nil, state: state, result: result)
    XCTAssertTrue(verified == false)
}

// MARK: - verifyClickElementAction

func testVerifyClickElementFocusedAfterClick() async {
    let runtime = makeRuntime()
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "click_element", arguments: ["title": "OK"])
    )
    let before = makeState()
    let after = makeState(elements: [
        makeElement(index: "0", role: "AXButton", title: "OK", focused: true),
    ])
    let result = await runtime.verifyClickElementAction(action: action, before: before, state: after, accumulatedEvidence: [])
    XCTAssertTrue(result?.verified == true)
}

func testVerifyClickElementNoState() async {
    let runtime = makeRuntime()
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "click_element", arguments: [:]),
        verificationGoal: VerificationGoal(expectedText: "OK")
    )
    let result = await runtime.verifyClickElementAction(action: action, before: nil, state: nil, accumulatedEvidence: [])
    XCTAssertTrue(result?.verified == false)
}

// MARK: - verifyFileOp

func testVerifyFileOpWriteFileExists() async {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("cru_test_\(UUID().uuidString.prefix(8))")
    try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let runtime = makeRuntime()
    let path = tmpDir.appendingPathComponent("test.txt").path
    try? "hello".write(toFile: path, atomically: true, encoding: .utf8)

    let result = await runtime.verifyFileOperation(toolName: "write_file", path: path, result: ToolCallResult(id: "1", output: "ok"))
    XCTAssertTrue(result?.verified == true)
}

func testVerifyFileOpWriteFileMissing() async {
    let runtime = makeRuntime()
    let result = await runtime.verifyFileOperation(toolName: "write_file", path: "/nonexistent/path.txt", result: ToolCallResult(id: "1", output: "ok"))
    XCTAssertTrue(result?.verified == false)
}

func testVerifyFileOpUnknownTool() async {
    let runtime = makeRuntime()
    let result = await runtime.verifyFileOperation(toolName: "delete_file", path: "/tmp", result: ToolCallResult(id: "1", output: "ok"))
    XCTAssertTrue(result == nil)
}
