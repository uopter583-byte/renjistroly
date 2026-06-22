import Foundation
import AppKit
import RenJistrolyModels
import RenJistrolySystemBridge

public actor ComputerUseRuntime {
    struct VerificationEvaluation {
        var verified: Bool
        var evidence: [String]
    }

    private let client: MCPClient
    private let coordinator: ComputerUseCoordinator?
    private let screenDiff: ScreenDiffVerifier?
    private let recoveryDecider: RecoveryDecider
    private var cancelled = false
    private var domSnapshotsBefore: [String] = []
    private var domSnapshotsAfter: [String] = []

    public init(client: MCPClient, coordinator: ComputerUseCoordinator? = nil, screenContextProvider: ScreenContextProvider? = nil, recoveryDecider: RecoveryDecider = RecoveryDecider()) {
        self.client = client
        self.coordinator = coordinator
        self.screenDiff = screenContextProvider.map { ScreenDiffVerifier(screen: $0) }
        self.recoveryDecider = recoveryDecider
    }

    public func cancel() { cancelled = true }

    public func run(
        actions: [ComputerUseAction],
        app: String? = nil,
        policy: ToolExecutionPolicy = .default,
        maxRecoveryAttempts: Int = 1,
        recoveryScoreByStrategy: [String: Double] = [:],
        onStepUpdate: (@Sendable (ComputerUseRunResult) async -> Void)? = nil,
        onTraceEvent: (@Sendable (ComputerUseTraceEvent) async -> Void)? = nil,
        onStepVoiceFeedback: (@Sendable (String) async -> Void)? = nil
    ) async -> ComputerUseRunResult {
        cancelled = false
        let startedAt = Date()
        var stepResults: [ComputerUseStepResult] = []

        for (index, action) in actions.enumerated() {
            if cancelled { break }
            if let onTraceEvent {
                await onTraceEvent(ComputerUseTraceEvent(
                    phase: "observing",
                    stepIndex: index,
                    toolName: action.toolCall.name,
                    summary: "观察执行前界面状态"
                ))
            }
            let observingName = action.toolCall.name
            Task.detached { await AgentEventBus.shared.publish(.lifecycle(.observingStarted(action: observingName))) }
            let before = await observe(app: app)
            let ocrBefore = await screenDiff?.captureBefore()
            // Capture DOM snapshot before the action (for browser actions)
            let browserForAction = inferredBrowserApp(for: action)
            let domBefore = await captureDOMSnapshot(browserApp: browserForAction)
            if let onTraceEvent {
                await onTraceEvent(ComputerUseTraceEvent(
                    phase: "acting",
                    stepIndex: index,
                    toolName: action.toolCall.name,
                    summary: "执行工具动作"
                ))
            }
            let actingName = action.toolCall.name
            Task.detached { await AgentEventBus.shared.publish(.lifecycle(.actingStarted(action: actingName, tool: actingName))) }
            let toolResult = await execute(action.toolCall, policy: policy)
            let after = await observe(app: app)
            let domAfter = await captureDOMSnapshot(browserApp: browserForAction)
            var browserState = await observeBrowserState(for: action)
            let ocrDiff = await screenDiff?.captureAfterAndDiff(
                beforeText: ocrBefore ?? "",
                expectedKeywords: action.verificationGoal?.expectedText.map { [$0] } ?? []
            )
            var evaluation = await evaluateVerification(
                action: action,
                before: before,
                state: after,
                browserState: browserState,
                result: toolResult,
                ocrDiff: ocrDiff
            )
            // DOM snapshot diff verification (for browser actions)
            if let domBefore, let domAfter {
                let domDiff = DOMVerification.diff(before: domBefore, after: domAfter)
                if domDiff.hasChange {
                    evaluation.evidence.append(contentsOf: domDiff.changes.prefix(3).map { "DOM: \($0)" })
                    if evaluation.verified == false {
                        evaluation.verified = true
                    }
                }
            }
            var verified = evaluation.verified
            var finalResult = toolResult
            var finalAfter = after
            var recoveryAttempted = false
            var finalRecoveryStrategy: RecoveryStrategy?
            var recoverySummary: String?
            var finalDelta = stateDelta(before: before, after: after)

            if (!verified || toolResult.isError), maxRecoveryAttempts > 0 {
                recoveryAttempted = true
                if let onTraceEvent {
                    await onTraceEvent(ComputerUseTraceEvent(
                        phase: "recovering",
                        stepIndex: index,
                        toolName: action.toolCall.name,
                        summary: toolResult.isError ? "动作失败，尝试恢复" : "动作未验证，尝试恢复"
                    ))
                }
                let recoveringName = action.toolCall.name
                let recoveringStrategy = toolResult.isError ? "动作失败, 尝试恢复" : "动作未验证, 尝试恢复"
                Task.detached { await AgentEventBus.shared.publish(.lifecycle(.recoveringStarted(action: recoveringName, strategy: recoveringStrategy))) }

                let dynamicScores = await recoveryDecider.scores(
                    for: action.toolCall.name,
                    appName: app,
                    failure: toolResult.output
                )
                let mergedScores = recoveryScoreByStrategy.merging(dynamicScores) { (param, _) in param }

                let recovery = await recover(
                    action: action,
                    app: app,
                    before: before,
                    after: after,
                    failedResult: toolResult,
                    policy: policy,
                    recoveryScoreByStrategy: mergedScores
                )
                finalRecoveryStrategy = recovery.strategy
                recoverySummary = recovery.summary

                await recoveryDecider.record(
                    toolName: action.toolCall.name,
                    appName: app,
                    failure: toolResult.output,
                    strategy: recovery.strategy?.rawValue ?? "none",
                    success: recovery.result != nil && !(recovery.result?.isError ?? true)
                )
                if let recoveredResult = recovery.result {
                    finalResult = recoveredResult
                    finalAfter = await observe(app: app)
                    let recoveryDomAfter = await captureDOMSnapshot(browserApp: browserForAction)
                    browserState = await observeBrowserState(for: action)
                    finalDelta = stateDelta(before: before, after: finalAfter)
                    evaluation = await evaluateVerification(
                        action: action,
                        before: before,
                        state: finalAfter,
                        browserState: browserState,
                        result: recoveredResult,
                        ocrDiff: ocrDiff
                    )
                    if let recoveryDomAfter, let domBefore {
                        let domDiff = DOMVerification.diff(before: domBefore, after: recoveryDomAfter)
                        if domDiff.hasChange {
                            evaluation.evidence.append(contentsOf: domDiff.changes.prefix(3).map { "DOM: \($0)" })
                            if !evaluation.verified { evaluation.verified = true }
                        }
                    }
                    verified = evaluation.verified
                } else {
                    finalAfter = recovery.observedState ?? after
                    browserState = await observeBrowserState(for: action)
                    finalDelta = stateDelta(before: before, after: finalAfter)
                    evaluation = await evaluateVerification(
                        action: action,
                        before: before,
                        state: finalAfter,
                        browserState: browserState,
                        result: finalResult,
                        ocrDiff: ocrDiff
                    )
                    if let domBefore, let domAfter {
                        let domDiff = DOMVerification.diff(before: domBefore, after: domAfter)
                        if domDiff.hasChange {
                            evaluation.evidence.append(contentsOf: domDiff.changes.prefix(3).map { "DOM: \($0)" })
                            if !evaluation.verified { evaluation.verified = true }
                        }
                    }
                    verified = evaluation.verified
                }
            }

            if let onTraceEvent {
                await onTraceEvent(ComputerUseTraceEvent(
                    phase: "verifying",
                    stepIndex: index,
                    toolName: action.toolCall.name,
                    summary: verified ? "验证通过" : "验证未通过"
                ))
            }
            let verifyingName = action.toolCall.name
            let verifyingPassed = verified
            Task.detached { await AgentEventBus.shared.publish(.lifecycle(.verifyingCompleted(action: verifyingName, passed: verifyingPassed))) }

            let backend = lastBackendForToolCall[action.toolCall.id]
            let permError = lastPermissionErrorForToolCall[action.toolCall.id]
            let recoveryFrom = lastRecoveryFromForToolCall[action.toolCall.id]
            stepResults.append(ComputerUseStepResult(
                action: action,
                beforeState: before,
                toolResult: finalResult,
                afterState: finalAfter,
                stateDelta: finalDelta,
                verified: verified,
                verificationEvidence: evaluation.evidence,
                recoveryAttempted: recoveryAttempted,
                recoveryStrategy: finalRecoveryStrategy?.rawValue,
                recoverySummary: recoverySummary,
                backendUsed: backend,
                recoveryFromBackend: recoveryFrom,
                permissionError: permError
            ))

            if let onStepUpdate {
                await onStepUpdate(ComputerUseRunResult(startedAt: startedAt, steps: stepResults))
            }

            if let onStepVoiceFeedback {
                let fb = stepVoiceFeedback(
                    action: action, verified: verified, recoveryAttempted: recoveryAttempted,
                    recoveryStrategy: finalRecoveryStrategy, recoverySummary: recoverySummary,
                    toolResult: finalResult, isLast: index == actions.count - 1 || (finalResult.isError || !verified)
                )
                await onStepVoiceFeedback(fb)
            }

            if finalResult.isError || !verified {
                break
            }
        }

        let result = ComputerUseRunResult(startedAt: startedAt, steps: stepResults)
        let duration = Date().timeIntervalSince(startedAt)
        if result.succeeded {
            Task.detached { await AgentEventBus.shared.publish(.lifecycle(.turnCompleted(duration: duration))) }
        } else if !stepResults.isEmpty {
            let lastError = stepResults.last?.toolResult.output ?? "未知错误"
            Task.detached { await AgentEventBus.shared.publish(.lifecycle(.turnFailed(error: lastError))) }
        }
        return result
    }

    private func stepVoiceFeedback(
        action: ComputerUseAction, verified: Bool, recoveryAttempted: Bool,
        recoveryStrategy: RecoveryStrategy?, recoverySummary: String?,
        toolResult: ToolCallResult, isLast: Bool
    ) -> String {
        let name = actionDisplayName(action.toolCall.name)
        if recoveryAttempted {
            if verified {
                return "恢复成功: \(name) — \(recoverySummary ?? "已通过验证")"
            }
            return "恢复失败: \(name) — \(recoverySummary ?? toolResult.output.prefix(80).description)"
        }
        if verified {
            return isLast ? "完成: \(name) 已验证" : "\(name) 已完成"
        }
        return "\(name) 未验证: \(toolResult.output.prefix(60).description)"
    }

    private func actionDisplayName(_ toolName: String) -> String {
        switch toolName {
        case "click", "click_element": return "点击"
        case "type_text", "set_value": return "输入文本"
        case "press_key": return "按键"
        case "scroll": return "滚动"
        case "drag": return "拖拽"
        case "open_app", "activate_app": return "打开应用"
        case "open_url": return "打开网页"
        case "open_path": return "打开文件夹"
        case "activate_menu": return "菜单操作"
        case "read_focused_text": return "读取文本"
        case "read_screen": return "读取屏幕"
        case "ui_tree": return "扫描界面"
        case "create_folder": return "新建文件夹"
        case "move_file": return "移动文件"
        case "copy_file": return "复制文件"
        case "delete_file": return "删除文件"
        case "safari_search": return "网页搜索"
        case "get_app_state": return "获取状态"
        case "get_browser_state": return "读取浏览器"
        case "get_finder_state": return "读取 Finder"
        default: return toolName
        }
    }

    private func observe(app: String?) async -> ComputerUseAppState? {
        let args = app.map { ["app": $0, "depth": "5"] } ?? ["depth": "5"]
        let request = ToolCallRequest(id: UUID().uuidString, name: "get_app_state", arguments: args)
        guard let result = try? await client.executeLowRisk(request),
              !result.isError,
              let data = result.output.data(using: .utf8)
        else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ComputerUseAppState.self, from: data)
    }

    private func observeBrowserState(for action: ComputerUseAction) async -> BrowserPageState? {
        guard let browserApp = inferredBrowserApp(for: action) else { return nil }
        let request = ToolCallRequest(
            id: UUID().uuidString,
            name: "get_browser_state",
            arguments: ["app": browserApp]
        )
        guard let result = try? await client.execute(request, policy: .permissive),
              !result.isError,
              let data = result.output.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(BrowserPageState.self, from: data)
    }

    /// Capture a DOM snapshot via JavaScript injection into the active browser.
    private func captureDOMSnapshot(browserApp: String?) async -> String? {
        guard let browserApp else { return nil }
        let js = DOMVerification.snapshotScript()
        let result: String
        do {
            switch browserApp.lowercased() {
            case "chrome", "google chrome":
                result = try await ChromeDriver().executeJavaScript(js)
            default:
                result = try await SafariDriver().executeJavaScript(js)
            }
        } catch {
            return nil
        }
        guard !result.isEmpty else { return nil }
        return result
    }

    private static let computerUseToolNames: Set<String> = [
        "click", "click_element", "type_text", "set_value", "press_key",
        "scroll", "drag", "open_app", "open_url", "safari_search",
        "click_element", "focus_window", "activate_menu",
    ]

    /// Track the last backend used per tool call ID (from Coordinator).
    private var lastBackendForToolCall: [String: String] = [:]
    /// Track the last permission error per tool call ID.
    private var lastPermissionErrorForToolCall: [String: String] = [:]
    /// Track recovery chain (which backend was first attempted) per tool call ID.
    private var lastRecoveryFromForToolCall: [String: String] = [:]

    private func execute(_ request: ToolCallRequest, policy: ToolExecutionPolicy) async -> ToolCallResult {
        // Route computer-use tools through Coordinator for multi-backend dispatch (incl. Vision fallback)
        if let coordinator, Self.computerUseToolNames.contains(request.name) {
            let result = await coordinator.execute(toolCall: request, policy: policy)
            // Track backend info from coordinator
            let backend = await coordinator.lastBackendByToolCallID[request.id]
            lastBackendForToolCall[request.id] = backend.map { ComputerUseCoordinator.backendDisplayName($0) }
            let permErr = await coordinator.lastPermissionErrorByToolCallID[request.id]
            lastPermissionErrorForToolCall[request.id] = permErr
            let recoveryFrom = await coordinator.lastRecoveryFromByToolCallID[request.id]
            lastRecoveryFromForToolCall[request.id] = recoveryFrom.map { ComputerUseCoordinator.backendDisplayName($0) }
            return result
        }
        // Non-CU tools go through MCPClient as before
        do {
            return try await client.execute(request, policy: policy)
        } catch let confirmation as ToolNeedsConfirmationError {
            return ToolCallResult(
                id: request.id,
                output: "需要确认: \(confirmation.assessment.summary)",
                isError: true
            )
        } catch {
            return ToolCallResult(
                id: request.id,
                output: "执行失败: \(error.localizedDescription)",
                isError: true
            )
        }
    }

    private static let browserToolNames: Set<String> = [
        "open_url",
        "safari_search",
        "get_browser_state",
    ]

    private func stateDelta(before: ComputerUseAppState?, after: ComputerUseAppState?) -> ComputerUseStateDelta? {
        guard let before, let after else { return nil }
        return ComputerUseStateDelta(before: before, after: after)
    }

    private func evaluateVerification(
        action: ComputerUseAction,
        before: ComputerUseAppState?,
        state: ComputerUseAppState?,
        browserState: BrowserPageState?,
        result: ToolCallResult,
        ocrDiff: ScreenDiffResult?
    ) async -> VerificationEvaluation {
        guard let goal = action.verificationGoal else {
            return VerificationEvaluation(verified: !result.isError, evidence: [])
        }

        var evidence: [String] = []

        if let expectedApp = goal.expectedApp {
            if state?.activeAppName?.localizedCaseInsensitiveContains(expectedApp) == true ||
               state?.activeAppBundleID?.localizedCaseInsensitiveContains(expectedApp) == true {
                evidence.append("应用匹配: \(expectedApp)")
            }
        }

        if let expectedWindow = goal.expectedWindowTitle {
            if state?.focusedWindowTitle?.localizedCaseInsensitiveContains(expectedWindow) == true {
                evidence.append("窗口标题匹配: \(expectedWindow)")
            }
        }

        if let expectedText = goal.expectedText {
            if let ocrDiff, ocrDiff.hasExpectedChange {
                evidence.append("OCR 检测到预期变化: \(expectedText)")
            }
            if let browserState {
                if browserState.tabTitle?.localizedCaseInsensitiveContains(expectedText) == true {
                    evidence.append("浏览器标签匹配: \(expectedText)")
                }
                if browserState.searchQuery?.localizedCaseInsensitiveContains(expectedText) == true {
                    evidence.append("浏览器搜索词匹配: \(expectedText)")
                }
            }
            if let ocrDiff, ocrDiff.afterText.localizedCaseInsensitiveContains(expectedText) {
                evidence.append("OCR 文字匹配: \(expectedText)")
            }
        }

        if result.isError {
            evidence.append("工具执行错误: \(result.output)")
        }

        let verified = !result.isError && (
            goal.expectedText == nil ||
            evidence.contains(where: { $0.contains("OCR") || $0.contains("屏幕文字") || $0.contains("浏览器") })
        )

        return VerificationEvaluation(verified: verified, evidence: evidence)
    }

    // MARK: - Debug helpers (test support)

    public func debugVerify(
        action: ComputerUseAction,
        before: ComputerUseAppState?,
        state: ComputerUseAppState?,
        browserState: BrowserPageState? = nil,
        result: ToolCallResult
    ) async -> Bool {
        let eval = await evaluateVerification(
            action: action,
            before: before,
            state: state,
            browserState: browserState,
            result: result,
            ocrDiff: nil
        )
        return eval.verified
    }

    public func debugVerificationEvidence(
        action: ComputerUseAction,
        before: ComputerUseAppState?,
        state: ComputerUseAppState?,
        browserState: BrowserPageState? = nil,
        result: ToolCallResult
    ) async -> [String] {
        let eval = await evaluateVerification(
            action: action,
            before: before,
            state: state,
            browserState: browserState,
            result: result,
            ocrDiff: nil
        )
        return eval.evidence
    }

    private func inferredBrowserApp(for action: ComputerUseAction) -> String? {
        if let app = action.verificationGoal?.expectedApp {
            if app.localizedCaseInsensitiveContains("chrome") {
                return "Chrome"
            }
            if app.localizedCaseInsensitiveContains("safari") {
                return "Safari"
            }
        }

        switch action.toolCall.name {
        case "open_url", "safari_search":
            return "Safari"
        default:
            return nil
        }
    }

    private struct RecoveryOutcome: Sendable {
        let result: ToolCallResult?
        let observedState: ComputerUseAppState?
        let strategy: RecoveryStrategy?
        let summary: String
    }

    enum RecoveryStrategy: String, Sendable, CaseIterable {
        case reobserveAndRetry
        case remapByStableID
        case coordinateClickFallback
        case activateTargetApp
        case reopenBrowserPage

        var priority: Int {
            switch self {
            case .remapByStableID: 0
            case .reopenBrowserPage: 1
            case .reobserveAndRetry: 2
            case .activateTargetApp: 3
            case .coordinateClickFallback: 4
            }
        }
    }

    private func recover(
        action: ComputerUseAction,
        app: String?,
        before: ComputerUseAppState?,
        after: ComputerUseAppState?,
        failedResult: ToolCallResult,
        policy: ToolExecutionPolicy,
        recoveryScoreByStrategy: [String: Double]
    ) async -> RecoveryOutcome {
        let refreshed = await observe(app: app)
        let refreshedBrowserState = await observeBrowserState(for: action)
        let remapped = remapActionByStableID(action, before: before, after: after, refreshed: refreshed)
        let strategies = Self.recoveryStrategies(
            action: action,
            app: app,
            refreshed: refreshed,
            browserState: refreshedBrowserState,
            failedResult: failedResult,
            remapped: remapped,
            recoveryScoreByStrategy: recoveryScoreByStrategy
        )

        for strategy in strategies {
            switch strategy {
            case .reobserveAndRetry:
                let retry = await execute(action.toolCall, policy: policy)
                return RecoveryOutcome(
                    result: retry,
                    observedState: refreshed,
                    strategy: strategy,
                    summary: "重新观察 UI 快照后重试原动作"
                )
            case .reopenBrowserPage:
                guard let browserApp = inferredBrowserApp(for: action) else { continue }
                let open = ToolCallRequest(
                    id: UUID().uuidString,
                    name: "open_app",
                    arguments: ["app_name": browserApp]
                )
                let openResult = await execute(open, policy: policy)
                guard !openResult.isError else {
                    return RecoveryOutcome(
                        result: openResult,
                        observedState: refreshed,
                        strategy: strategy,
                        summary: "尝试重新激活浏览器失败"
                    )
                }
                let retry = await execute(action.toolCall, policy: policy)
                return RecoveryOutcome(
                    result: retry,
                    observedState: await observe(app: app),
                    strategy: strategy,
                    summary: {
                        let reason = refreshedBrowserState.flatMap { Self.browserRecoveryReason(action: action, browserState: $0) }
                        if let reason, !reason.isEmpty {
                            return "\(reason)，重新激活浏览器后重试"
                        }
                        return action.toolCall.name == "safari_search"
                            ? "检测到搜索结果页未命中目标，重新激活浏览器后重试搜索"
                            : "检测到浏览器页面未到达目标地址，重新激活浏览器后重试打开网址"
                    }()
                )
            case .remapByStableID:
                guard let remapped else { continue }
                let retry = await execute(remapped.toolCall, policy: policy)
                return RecoveryOutcome(
                    result: retry,
                    observedState: refreshed,
                    strategy: strategy,
                    summary: "重新观察 UI 快照后按 stableID 重定位元素并重试"
                )
            case .coordinateClickFallback:
                guard action.toolCall.name == "click",
                      let index = (remapped?.toolCall.arguments["element_index"] ?? action.toolCall.arguments["element_index"]),
                      let element = refreshed?.elements.first(where: { $0.elementIndex == index }),
                      let frame = element.frame else {
                    continue
                }
                let x = frame.x + frame.width / 2
                let y = frame.y + frame.height / 2
                let fallback = ToolCallRequest(
                    id: UUID().uuidString,
                    name: "click",
                    arguments: [
                        "x": String(x),
                        "y": String(y),
                        "click_count": action.toolCall.arguments["click_count"] ?? "1",
                    ]
                )
                let retry = await execute(fallback, policy: policy)
                return RecoveryOutcome(
                    result: retry,
                    observedState: refreshed,
                    strategy: strategy,
                    summary: remapped == nil
                        ? "元素点击失败，使用元素 frame 中心坐标重试"
                        : "元素点击失败，先按 stableID 重定位，再使用元素 frame 中心坐标重试"
                )
            case .activateTargetApp:
                guard let expectedApp = action.verificationGoal?.expectedApp ?? app else { continue }
                let open = ToolCallRequest(
                    id: UUID().uuidString,
                    name: "open_app",
                    arguments: ["app_name": expectedApp]
                )
                let openResult = await execute(open, policy: policy)
                guard !openResult.isError else {
                    return RecoveryOutcome(result: openResult, observedState: refreshed, strategy: strategy, summary: "尝试激活目标应用失败")
                }
                let retry = await execute(action.toolCall, policy: policy)
                return RecoveryOutcome(
                    result: retry,
                    observedState: await observe(app: app),
                    strategy: strategy,
                    summary: "先激活目标应用，再重试原动作"
                )
            }
        }

        return RecoveryOutcome(
            result: nil,
            observedState: refreshed,
            strategy: nil,
            summary: "已重新观察，但没有可用恢复策略"
        )
    }

    static func recoveryStrategies(
        action: ComputerUseAction,
        app: String?,
        refreshed: ComputerUseAppState?,
        browserState: BrowserPageState?,
        failedResult: ToolCallResult,
        remapped: ComputerUseAction?,
        recoveryScoreByStrategy: [String: Double] = [:]
    ) -> [RecoveryStrategy] {
        var strategies: [RecoveryStrategy] = []
        let failureText = failedResult.output
        let snapshotStale = failureText.localizedCaseInsensitiveContains("快照已过期")
            || failureText.localizedCaseInsensitiveContains("找不到 UI 元素")

        if snapshotStale {
            if remapped != nil {
                strategies.append(.remapByStableID)
            }
            strategies.append(.reobserveAndRetry)
        }

        if browserNeedsReopen(action: action, browserState: browserState) {
            strategies.append(.reopenBrowserPage)
        }

        if let expectedApp = action.verificationGoal?.expectedApp ?? app,
           refreshed?.activeAppName?.localizedCaseInsensitiveContains(expectedApp) != true,
           refreshed?.activeAppBundleID?.localizedCaseInsensitiveContains(expectedApp) != true {
            strategies.append(.activateTargetApp)
        }

        if action.toolCall.name == "click" {
            strategies.append(.coordinateClickFallback)
        }

        if !snapshotStale, remapped != nil {
            strategies.append(.remapByStableID)
        }

        var seen: Set<RecoveryStrategy> = []
        return strategies
            .sorted {
                let leftScore = recoveryScoreByStrategy[$0.rawValue] ?? -1
                let rightScore = recoveryScoreByStrategy[$1.rawValue] ?? -1
                if leftScore == rightScore {
                    return $0.priority < $1.priority
                }
                return leftScore > rightScore
            }
            .filter { seen.insert($0).inserted }
    }

    private func remapActionByStableID(
        _ action: ComputerUseAction,
        before: ComputerUseAppState?,
        after: ComputerUseAppState?,
        refreshed: ComputerUseAppState?
    ) -> ComputerUseAction? {
        guard let index = action.toolCall.arguments["element_index"],
              let refreshed else { return nil }

        let previousElement = after?.elements.first(where: { $0.elementIndex == index })
            ?? before?.elements.first(where: { $0.elementIndex == index })
        guard let stableID = previousElement?.stableID,
              let remappedElement = refreshed.elements.first(where: { $0.stableID == stableID }),
              remappedElement.elementIndex != index
        else {
            return nil
        }

        var arguments = action.toolCall.arguments
        arguments["element_index"] = remappedElement.elementIndex
        return ComputerUseAction(
            id: action.id,
            toolCall: ToolCallRequest(
                id: action.toolCall.id,
                name: action.toolCall.name,
                arguments: arguments
            ),
            verificationGoal: action.verificationGoal
        )
    }

    static func browserNeedsReopen(action: ComputerUseAction, browserState: BrowserPageState?) -> Bool {
        guard Self.browserToolNames.contains(action.toolCall.name) else { return false }
        guard let browserState else { return true }

        switch action.toolCall.name {
        case "open_url":
            if let expected = action.verificationGoal?.expectedText?.lowercased(),
               let host = browserState.host?.lowercased() {
                return !host.contains(expected)
            }
            if let url = action.toolCall.arguments["url"]?.lowercased(),
               let currentURL = browserState.url?.lowercased() {
                return !currentURL.contains(url)
            }
            return false
        case "safari_search":
            guard let expected = action.verificationGoal?.expectedText?.lowercased(),
                  !expected.isEmpty else {
                return false
            }
            let query = browserState.searchQuery?.lowercased() ?? ""
            let title = browserState.tabTitle?.lowercased() ?? ""
            return !query.contains(expected) && !title.contains(expected)
        default:
            return false
        }
    }

    static func browserRecoveryReason(action: ComputerUseAction, browserState: BrowserPageState?) -> String? {
        guard Self.browserToolNames.contains(action.toolCall.name) else { return nil }
        guard let browserState else { return "未读到浏览器页面状态" }

        switch action.toolCall.name {
        case "open_url":
            let expectedHost = action.verificationGoal?.expectedText
                ?? action.verificationGoal?.expectedWindowTitle
                ?? URL(string: action.toolCall.arguments["url"] ?? "")?.host?.replacingOccurrences(of: "www.", with: "")
            guard let expectedHost, !expectedHost.isEmpty else { return nil }
            let actualHost = browserState.host ?? "未知域名"
            if actualHost.localizedCaseInsensitiveContains(expectedHost) {
                return nil
            }
            return "当前页面域名是 \(actualHost)，未到达目标 \(expectedHost)"
        case "safari_search":
            let expectedQuery = action.verificationGoal?.expectedText
                ?? action.toolCall.arguments["query"]
            guard let expectedQuery, !expectedQuery.isEmpty else { return nil }
            let actualQuery = browserState.searchQuery ?? browserState.tabTitle ?? "未知页面"
            if actualQuery.localizedCaseInsensitiveContains(expectedQuery) {
                return nil
            }
            return "当前搜索词是 \(actualQuery)，未命中目标 \(expectedQuery)"
        default:
            return nil
        }
    }

    // MARK: - Test helpers

    func extractExitCode(from output: String) -> Int? {
        let patterns = [
            #"exit(?:ed)?\s+with\s+(?:exit\s+)?code:?\s+(\d+)"#,
            #"terminated\s+with\s+code\s+(\d+)"#,
            #"exit\s+code:\s+(\d+)"#,
        ]
        for pattern in patterns {
            if let match = try? Regex(pattern).firstMatch(in: output),
               let code = match.last?.substring.flatMap({ Int($0) }) {
                return code
            }
        }
        return nil
    }

    func normalizedExpectedText(from text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(80))
    }

    func effectiveVerificationGoal(for action: ComputerUseAction) async -> VerificationGoal? {
        if let explicit = action.verificationGoal { return explicit }
        let args = action.toolCall.arguments
        switch action.toolCall.name {
        case "type_text":
            return args["text"].flatMap {
                normalizedExpectedText(from: $0).map { VerificationGoal(expectedText: $0) }
            }
        case "set_value":
            let text = normalizedExpectedText(from: args["value"])
            let app = args["app"]
            return text.map { VerificationGoal(expectedText: $0, expectedApp: app) }
        case "focus_window":
            return args["title"].map { VerificationGoal(expectedWindowTitle: $0) }
        case "click_element":
            let text = normalizedExpectedText(from: args["title"])
            let role = args["role"]
            return text.map { VerificationGoal(expectedText: $0, expectedElementRole: role) }
        default:
            return nil
        }
    }

    func verifyPressKeyAction(key: String, modifiers: String, delta: ComputerUseStateDelta) -> VerificationEvaluation {
        var evidence: [String] = []
        if key == "tab" {
            if delta.focusedElementChanged {
                evidence.append("焦点变化")
            }
        } else {
            if delta.activeAppChanged {
                evidence.append("应用切换")
            }
        }
        return VerificationEvaluation(verified: !evidence.isEmpty, evidence: evidence)
    }

    func verifyActivateMenuAction(path: String, delta: ComputerUseStateDelta) -> VerificationEvaluation {
        var evidence: [String] = []
        if delta.activeAppChanged {
            evidence.append("应用变化")
        }
        if delta.focusedWindowChanged {
            evidence.append("窗口变化")
        }
        if delta.focusedElementChanged {
            evidence.append("焦点变化")
        }
        return VerificationEvaluation(verified: !evidence.isEmpty, evidence: evidence)
    }

    func verifyClickElementAction(
        action: ComputerUseAction,
        before: ComputerUseAppState?,
        state: ComputerUseAppState?,
        accumulatedEvidence: [String]
    ) async -> VerificationEvaluation? {
        guard let state else { return VerificationEvaluation(verified: false, evidence: accumulatedEvidence) }
        let targetTitle = action.verificationGoal?.expectedText ?? action.toolCall.arguments["title"]
        if let title = targetTitle {
            let focused = state.elements.contains { $0.focused == true && $0.title == title }
            if focused {
                var evidence = accumulatedEvidence
                evidence.append("元素已聚焦: \(title)")
                return VerificationEvaluation(verified: true, evidence: evidence)
            }
        }
        return VerificationEvaluation(verified: false, evidence: accumulatedEvidence)
    }

    func verifyFileOperation(toolName: String, path: String, result: ToolCallResult) async -> VerificationEvaluation? {
        switch toolName {
        case "write_file":
            let exists = FileManager.default.fileExists(atPath: path)
            return VerificationEvaluation(verified: exists, evidence: exists ? ["文件已存在: \(path)"] : [])
        case "read_file":
            let exists = FileManager.default.fileExists(atPath: path)
            return VerificationEvaluation(verified: exists, evidence: exists ? ["文件可读取"] : [])
        default:
            return nil
        }
    }
}
