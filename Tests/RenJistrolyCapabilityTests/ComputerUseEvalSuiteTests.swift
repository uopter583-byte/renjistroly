import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

func testComputerUseEvalSuiteHasDefaultTasks() {
    let suite = ComputerUseEvalSuite()

    XCTAssertTrue(suite.tasks.count >= 10)
    XCTAssertTrue(suite.tasks.contains { $0.category == .browser })
    XCTAssertTrue(suite.tasks.contains { $0.category == .webSearch })
    XCTAssertTrue(suite.tasks.contains { $0.category == .codeBuild })
    XCTAssertTrue(suite.tasks.contains { $0.category == .codeTest })
    XCTAssertTrue(suite.tasks.contains { $0.category == .codeFixBug })
    XCTAssertTrue(suite.tasks.contains { $0.category == .failureRecovery })
    XCTAssertTrue(suite.tasks.contains { $0.category == .multiStepWorkflow })
}

func testEvalSuiteCoversRealWorldScenarios() {
    let suite = ComputerUseEvalSuite()
    let names = Set(suite.tasks.map(\.name))

    XCTAssertTrue(names.contains { $0.contains("Safari") })
    XCTAssertTrue(names.contains { $0.contains("Web search") })
    XCTAssertTrue(names.contains { $0.contains("Find a specific file") })
    XCTAssertTrue(names.contains { $0.contains("Type text") })
    XCTAssertTrue(names.contains { $0.contains("build") })
    XCTAssertTrue(names.contains { $0.contains("tests") })
    XCTAssertTrue(names.contains { $0.contains("Diagnose") })
    XCTAssertTrue(names.contains { $0.contains("Recover from") })
    XCTAssertTrue(names.contains { $0.contains("Multi-step") })
}

func testEvalTaskCategoriesAreAllSearchable() {
    let categories = ComputerUseEvalTask.Category.allCases
    XCTAssertTrue(categories.contains(.webSearch))
    XCTAssertTrue(categories.contains(.codeBuild))
    XCTAssertTrue(categories.contains(.codeTest))
    XCTAssertTrue(categories.contains(.codeFixBug))
    XCTAssertTrue(categories.contains(.failureRecovery))
    XCTAssertTrue(categories.contains(.multiStepWorkflow))
}

func testSafetyGatewayCategorizesDriverTools() async {
    let registry = MCPToolRegistry()
    await registry.register(ListAppDriversTool())
    await registry.register(OpenPathTool())
    await registry.register(FinderSearchTool())
    await registry.register(SafariSearchTool())
    await registry.register(TerminalRunTool())
    let gateway = ToolSafetyGateway(registry: registry, policyProvider: { .default })

    let listAssessment = await gateway.assess(ToolCallRequest(id: "1", name: "list_app_drivers", arguments: [:]))
    let openAssessment = await gateway.assess(ToolCallRequest(id: "2", name: "open_path", arguments: ["path": "/tmp"]))
    let finderSearchAssessment = await gateway.assess(ToolCallRequest(id: "3", name: "finder_search", arguments: ["query": "foo", "path": "/tmp"]))
    let safariSearchAssessment = await gateway.assess(ToolCallRequest(id: "4", name: "safari_search", arguments: ["query": "RenJistroly"]))
    let terminalRunAssessment = await gateway.assess(ToolCallRequest(id: "5", name: "terminal_run", arguments: ["command": "git status"]))

    XCTAssertTrue(listAssessment.actionCategory == .observe)
    XCTAssertTrue(openAssessment.actionCategory == .localNavigation)
    XCTAssertTrue(finderSearchAssessment.actionCategory == .observe)
    XCTAssertTrue(safariSearchAssessment.actionCategory == .localNavigation)
    XCTAssertTrue(terminalRunAssessment.actionCategory == .shellRead)
}

func testRecoveryStrategiesPreferStableIDRemapForStaleSnapshots() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "click", arguments: ["element_index": "e1"])
    )
    let remapped = ComputerUseAction(
        toolCall: ToolCallRequest(id: "1", name: "click", arguments: ["element_index": "e9"])
    )
    let failedResult = ToolCallResult(id: "1", output: "找不到 UI 元素: e1", isError: true)

    let strategies = ComputerUseRuntime.recoveryStrategies(
        action: action,
        app: nil,
        refreshed: nil,
        browserState: nil,
        failedResult: failedResult,
        remapped: remapped
    )

    XCTAssertTrue(strategies.first == .remapByStableID)
    XCTAssertTrue(strategies.contains(.reobserveAndRetry))
    XCTAssertTrue(strategies.contains(.coordinateClickFallback))
}

func testRecoveryStrategiesActivateTargetAppWhenFocusIsWrong() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "2", name: "click", arguments: ["element_index": "e2"]),
        verificationGoal: VerificationGoal(expectedApp: "Safari")
    )
    let refreshed = ComputerUseAppState(activeAppName: "Finder")
    let failedResult = ToolCallResult(id: "2", output: "ok")

    let strategies = ComputerUseRuntime.recoveryStrategies(
        action: action,
        app: "Safari",
        refreshed: refreshed,
        browserState: nil,
        failedResult: failedResult,
        remapped: nil
    )

    XCTAssertTrue(strategies.contains(.activateTargetApp))
    XCTAssertTrue(strategies.first == .activateTargetApp)
}

func testRecoveryStrategiesPreferHigherHistoricalSuccessRate() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "3", name: "click", arguments: ["element_index": "e3"])
    )
    let remapped = ComputerUseAction(
        toolCall: ToolCallRequest(id: "3", name: "click", arguments: ["element_index": "e8"])
    )
    let failedResult = ToolCallResult(id: "3", output: "找不到 UI 元素: e3", isError: true)

    let strategies = ComputerUseRuntime.recoveryStrategies(
        action: action,
        app: nil,
        refreshed: nil,
        browserState: nil,
        failedResult: failedResult,
        remapped: remapped,
        recoveryScoreByStrategy: [
            "reobserveAndRetry": 0.9,
            "remapByStableID": 0.2
        ]
    )

    XCTAssertTrue(strategies.first == .reobserveAndRetry)
}

func testBrowserRecoveryStrategiesReopenWhenHostMismatches() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "browser-1", name: "open_url", arguments: ["url": "https://platform.openai.com/docs"]),
        verificationGoal: VerificationGoal(
            expectedText: "platform.openai.com",
            expectedApp: "Safari",
            expectedWindowTitle: "platform.openai.com"
        )
    )

    let strategies = ComputerUseRuntime.recoveryStrategies(
        action: action,
        app: "Safari",
        refreshed: ComputerUseAppState(activeAppName: "Safari"),
        browserState: BrowserPageState(
            browserName: "Safari",
            windowTitle: "Example Domain",
            tabTitle: "Example Domain",
            url: "https://example.com",
            host: "example.com"
        ),
        failedResult: ToolCallResult(id: "browser-1", output: "ok"),
        remapped: nil
    )

    XCTAssertTrue(strategies.contains(.reopenBrowserPage))
}

func testBrowserRecoveryStrategiesReopenWhenSearchQueryMismatches() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "browser-2", name: "safari_search", arguments: ["query": "openai codex cli"]),
        verificationGoal: VerificationGoal(expectedText: "openai codex cli", expectedApp: "Safari")
    )

    let strategies = ComputerUseRuntime.recoveryStrategies(
        action: action,
        app: "Safari",
        refreshed: ComputerUseAppState(activeAppName: "Safari"),
        browserState: BrowserPageState(
            browserName: "Safari",
            windowTitle: "Google Search",
            tabTitle: "weather shanghai - Google Search",
            url: "https://www.google.com/search?q=weather+shanghai",
            host: "google.com",
            searchQuery: "weather shanghai"
        ),
        failedResult: ToolCallResult(id: "browser-2", output: "ok"),
        remapped: nil
    )

    XCTAssertTrue(strategies.contains(.reopenBrowserPage))
}

func testOpenAppVerificationDoesNotRequireStateDeltaWhenAppMatches() async {
    let client = MCPClient()
    let runtime = ComputerUseRuntime(client: client)
    let verify = await runtime.debugVerify(
        action: ComputerUseAction(
            toolCall: ToolCallRequest(id: "1", name: "open_app", arguments: ["app_name": "Safari"]),
            verificationGoal: VerificationGoal(expectedApp: "Safari")
        ),
        before: ComputerUseAppState(activeAppName: "Safari"),
        state: ComputerUseAppState(activeAppName: "Safari"),
        result: ToolCallResult(id: "1", output: "已打开 Safari")
    )

    XCTAssertTrue(verify)
}

func testTypeTextVerificationUsesTypedTextAsImplicitGoal() async {
    let client = MCPClient()
    let runtime = ComputerUseRuntime(client: client)
    let verify = await runtime.debugVerify(
        action: ComputerUseAction(
            toolCall: ToolCallRequest(id: "2", name: "type_text", arguments: ["text": "RenJistroly agent"])
        ),
        before: ComputerUseAppState(activeAppName: "Notes"),
        state: ComputerUseAppState(
            activeAppName: "Notes",
            elements: [
                ComputerUseElement(
                    elementIndex: "e1",
                    role: "AXTextField",
                    value: "RenJistroly agent",
                    focused: true,
                    depth: 1,
                    childPath: [0]
                )
            ]
        ),
        result: ToolCallResult(id: "2", output: "已输入: RenJistroly agent")
    )

    XCTAssertTrue(verify)
}

func testSetValueVerificationUsesValueAndAppAsImplicitGoal() async {
    let client = MCPClient()
    let runtime = ComputerUseRuntime(client: client)
    let verify = await runtime.debugVerify(
        action: ComputerUseAction(
            toolCall: ToolCallRequest(
                id: "3",
                name: "set_value",
                arguments: ["app": "Safari", "element_index": "e2", "value": "OpenAI docs"]
            )
        ),
        before: ComputerUseAppState(activeAppName: "Safari"),
        state: ComputerUseAppState(
            activeAppName: "Safari",
            elements: [
                ComputerUseElement(
                    elementIndex: "e2",
                    role: "AXTextField",
                    value: "OpenAI docs",
                    depth: 1,
                    childPath: [1]
                )
            ]
        ),
        result: ToolCallResult(id: "3", output: "已设置元素 e2")
    )

    XCTAssertTrue(verify)
}

func testFocusWindowVerificationUsesTitleAsImplicitGoal() async {
    let client = MCPClient()
    let runtime = ComputerUseRuntime(client: client)
    let verify = await runtime.debugVerify(
        action: ComputerUseAction(
            toolCall: ToolCallRequest(id: "4", name: "focus_window", arguments: ["title": "Preferences"])
        ),
        before: ComputerUseAppState(activeAppName: "Safari", focusedWindowTitle: "Downloads"),
        state: ComputerUseAppState(activeAppName: "Safari", focusedWindowTitle: "Preferences"),
        result: ToolCallResult(id: "4", output: "已聚焦窗口: Preferences")
    )

    XCTAssertTrue(verify)
}

func testClickElementVerificationUsesTitleAndRoleAsImplicitGoal() async {
    let client = MCPClient()
    let runtime = ComputerUseRuntime(client: client)
    let verify = await runtime.debugVerify(
        action: ComputerUseAction(
            toolCall: ToolCallRequest(
                id: "5",
                name: "click_element",
                arguments: ["title": "OK", "role": "AXButton"]
            )
        ),
        before: ComputerUseAppState(
            activeAppName: "System Settings",
            elements: [
                ComputerUseElement(
                    elementIndex: "e1",
                    role: "AXStaticText",
                    title: "Before",
                    depth: 1,
                    childPath: [0]
                )
            ]
        ),
        state: ComputerUseAppState(
            activeAppName: "System Settings",
            elements: [
                ComputerUseElement(
                    elementIndex: "e2",
                    role: "AXButton",
                    title: "OK",
                    depth: 1,
                    childPath: [1]
                )
            ]
        ),
        result: ToolCallResult(id: "5", output: "已点击: OK")
    )

    XCTAssertTrue(verify)
}

func testPressKeyVerificationEvidenceUsesObservedStateChange() async {
    let client = MCPClient()
    let runtime = ComputerUseRuntime(client: client)
    let evidence = await runtime.debugVerificationEvidence(
        action: ComputerUseAction(
            toolCall: ToolCallRequest(id: "6", name: "press_key", arguments: ["key": "tab"])
        ),
        before: ComputerUseAppState(
            activeAppName: "Safari",
            elements: [
                ComputerUseElement(
                    elementIndex: "e1",
                    role: "AXTextField",
                    title: "Search",
                    focused: true,
                    depth: 1,
                    childPath: [0]
                )
            ]
        ),
        state: ComputerUseAppState(
            activeAppName: "Safari",
            elements: [
                ComputerUseElement(
                    elementIndex: "e2",
                    role: "AXButton",
                    title: "Cancel",
                    focused: true,
                    depth: 1,
                    childPath: [1]
                )
            ]
        ),
        result: ToolCallResult(id: "6", output: "已按下: tab")
    )

    XCTAssertTrue(evidence.contains(where: { $0.contains("状态变化") }))
}

func testPressKeyTabVerificationFailsWithoutFocusChange() async {
    let client = MCPClient()
    let runtime = ComputerUseRuntime(client: client)
    let verify = await runtime.debugVerify(
        action: ComputerUseAction(
            toolCall: ToolCallRequest(id: "6b", name: "press_key", arguments: ["key": "tab"])
        ),
        before: ComputerUseAppState(
            activeAppName: "Safari",
            elements: [
                ComputerUseElement(
                    elementIndex: "e1",
                    role: "AXTextField",
                    title: "Search",
                    focused: true,
                    depth: 1,
                    childPath: [0]
                )
            ]
        ),
        state: ComputerUseAppState(
            activeAppName: "Safari",
            elements: [
                ComputerUseElement(
                    elementIndex: "e1",
                    role: "AXTextField",
                    title: "Search",
                    focused: true,
                    depth: 1,
                    childPath: [0]
                )
            ]
        ),
        result: ToolCallResult(id: "6b", output: "已按下: tab")
    )

    XCTAssertFalse(verify)
}

func testActivateMenuVerificationUsesObservedStateChange() async {
    let client = MCPClient()
    let runtime = ComputerUseRuntime(client: client)
    let evidence = await runtime.debugVerificationEvidence(
        action: ComputerUseAction(
            toolCall: ToolCallRequest(id: "6c", name: "activate_menu", arguments: ["path": "File/New Window"])
        ),
        before: ComputerUseAppState(activeAppName: "Safari", focusedWindowTitle: "Start Page"),
        state: ComputerUseAppState(activeAppName: "Safari", focusedWindowTitle: "New Window"),
        result: ToolCallResult(id: "6c", output: "已执行菜单: File/New Window")
    )

    XCTAssertTrue(evidence.contains(where: { $0.contains("File/New Window") }))
    XCTAssertTrue(evidence.contains(where: { $0.contains("焦点窗口变化") }))
}

func testOpenURLVerificationUsesBrowserHostEvidence() async {
    let client = MCPClient()
    let runtime = ComputerUseRuntime(client: client)
    let verify = await runtime.debugVerify(
        action: ComputerUseAction(
            toolCall: ToolCallRequest(id: "7", name: "open_url", arguments: ["url": "https://platform.openai.com/docs"]),
            verificationGoal: VerificationGoal(
                expectedText: "platform.openai.com",
                expectedApp: "Safari",
                expectedWindowTitle: "platform.openai.com"
            )
        ),
        before: ComputerUseAppState(activeAppName: "Safari"),
        state: ComputerUseAppState(activeAppName: "Safari", focusedWindowTitle: "Blank Start Page"),
        browserState: BrowserPageState(
            browserName: "Safari",
            windowTitle: "OpenAI Platform",
            tabTitle: "Function calling",
            url: "https://platform.openai.com/docs/guides/function-calling",
            host: "platform.openai.com"
        ),
        result: ToolCallResult(id: "7", output: "已打开网址")
    )

    XCTAssertTrue(verify)
}

func testSafariSearchVerificationUsesBrowserQueryEvidence() async {
    let client = MCPClient()
    let runtime = ComputerUseRuntime(client: client)
    let evidence = await runtime.debugVerificationEvidence(
        action: ComputerUseAction(
            toolCall: ToolCallRequest(id: "8", name: "safari_search", arguments: ["query": "openai codex cli"]),
            verificationGoal: VerificationGoal(expectedText: "openai codex cli", expectedApp: "Safari")
        ),
        before: ComputerUseAppState(activeAppName: "Safari"),
        state: ComputerUseAppState(activeAppName: "Safari"),
        browserState: BrowserPageState(
            browserName: "Safari",
            windowTitle: "Google Search",
            tabTitle: "openai codex cli - Google Search",
            url: "https://www.google.com/search?q=openai%20codex%20cli",
            host: "google.com",
            searchQuery: "openai codex cli"
        ),
        result: ToolCallResult(id: "8", output: "已在 Safari 中搜索: openai codex cli")
    )

    XCTAssertTrue(evidence.contains(where: { $0.contains("浏览器页面包含 openai codex cli") }))
}

func testOpenURLVerificationFailureUsesBrowserMismatchReason() async {
    let client = MCPClient()
    let runtime = ComputerUseRuntime(client: client)
    let evidence = await runtime.debugVerificationEvidence(
        action: ComputerUseAction(
            toolCall: ToolCallRequest(id: "9", name: "open_url", arguments: ["url": "https://platform.openai.com/docs"]),
            verificationGoal: VerificationGoal(
                expectedText: "platform.openai.com",
                expectedApp: "Safari",
                expectedWindowTitle: "platform.openai.com"
            )
        ),
        before: ComputerUseAppState(activeAppName: "Safari"),
        state: ComputerUseAppState(activeAppName: "Safari", focusedWindowTitle: "Example Domain"),
        browserState: BrowserPageState(
            browserName: "Safari",
            windowTitle: "Example Domain",
            tabTitle: "Example Domain",
            url: "https://example.com",
            host: "example.com"
        ),
        result: ToolCallResult(id: "9", output: "已打开网址")
    )

    XCTAssertTrue(evidence.contains(where: { $0.contains("当前页面域名是 example.com") }))
}

func testBrowserRecoveryReasonExplainsQueryMismatch() {
    let action = ComputerUseAction(
        toolCall: ToolCallRequest(id: "10", name: "safari_search", arguments: ["query": "openai codex cli"]),
        verificationGoal: VerificationGoal(expectedText: "openai codex cli", expectedApp: "Safari")
    )

    let reason = ComputerUseRuntime.browserRecoveryReason(
        action: action,
        browserState: BrowserPageState(
            browserName: "Safari",
            windowTitle: "Google Search",
            tabTitle: "weather shanghai - Google Search",
            url: "https://www.google.com/search?q=weather+shanghai",
            host: "google.com",
            searchQuery: "weather shanghai"
        )
    )

    XCTAssertTrue(reason?.contains("当前搜索词是 weather shanghai") == true)
    XCTAssertTrue(reason?.contains("未命中目标 openai codex cli") == true)
}
