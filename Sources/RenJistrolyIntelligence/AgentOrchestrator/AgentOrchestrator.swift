import Foundation
import RenJistrolyModels
import OSLog

public actor AgentOrchestrator {
    private let smartRouter: SmartRouter
    private let config: AgentLoopConfig
    private var state: AgentLoopState

    public typealias ToolExecutor = @Sendable (ToolCallRequest) async throws -> ToolCallResult
    public typealias ComputerUseExecutor = @Sendable ([ComputerUseAction], String?, ToolExecutionPolicy) async -> ComputerUseRunResult
    public typealias ScreenshotProvider = @Sendable () async -> Data?
    public typealias EventHandler = @Sendable (AgentLoopEvent) async -> Void

    private struct ToolTimeoutError: Error, Sendable {}

    public init(
        smartRouter: SmartRouter,
        config: AgentLoopConfig = .default,
        state: AgentLoopState = AgentLoopState()
    ) {
        self.smartRouter = smartRouter
        self.config = config
        self.state = state
    }

    // MARK: - Execute

    public func execute(
        messages: [Message],
        context: ProjectContext?,
        availableTools: [ToolDefinition],
        toolExecutor: ToolExecutor? = nil,
        computerUseExecutor: ComputerUseExecutor? = nil,
        screenshotProvider: ScreenshotProvider? = nil,
        onEvent: EventHandler? = nil,
        policy: ToolExecutionPolicy = .default
    ) async throws -> AgentResponse {
        state = AgentLoopState(currentPhase: .observing)
        var conversation = messages
        var toolResults: [ToolCallResult] = []
        var finalMessage: Message?
        var lastBackendProvider: LLMProvider = .anthropic

        await emit(.phaseChange(.observing, summary: "开始观察当前状态"), onEvent)

        // Main agent loop — no hard iteration cap, uses progress signals to stop
        while state.currentPhase != .completed && state.currentPhase != .failed {
            try Task.checkCancellation()

            state.roundCount += 1

            // Guard: absolute maximum to prevent infinite loops
            guard state.roundCount <= config.maxRounds else {
                await emit(.warning("Agent 循环超过最大轮次 \(config.maxRounds)"), onEvent)
                state.currentPhase = .failed
                break
            }

            // Guard: stagnation detection
            guard state.stagnationCount <= config.maxStagnationRounds else {
                await emit(.warning("Agent 循环停滞 \(config.maxStagnationRounds) 轮无进展"), onEvent)
                state.currentPhase = .failed
                break
            }

            // Execute one round: build context, call LLM, execute tool calls
            let response = try await executeStep(
                conversation: &conversation,
                toolResults: &toolResults,
                finalMessage: &finalMessage,
                lastBackendProvider: &lastBackendProvider,
                availableTools: availableTools,
                context: context,
                toolExecutor: toolExecutor,
                computerUseExecutor: computerUseExecutor,
                screenshotProvider: screenshotProvider,
                onEvent: onEvent,
                policy: policy
            )

            // nil means task completed without tool calls (finalMessage already set)
            guard let response else { break }

            // Post-step: append response, verify, check completion, auto-replan
            let shouldContinue = await collectStepResults(
                response: response,
                conversation: &conversation,
                finalMessage: &finalMessage,
                onEvent: onEvent
            )
            if !shouldContinue { break }
        }

        let final = finalMessage ?? Message(
            role: .assistant,
            content: [.text(state.currentPhase == .failed ? "任务未能完成。" : "任务已处理。")]
        )

        return AgentResponse(
            finalMessage: final,
            toolResults: toolResults,
            iterations: state.roundCount,
            backendUsed: lastBackendProvider
        )
    }

    // MARK: - Step Execution

    /// Execute one round of the agent loop: build state context, call LLM, execute tool calls.
    /// Returns the LLM response for post-processing, or nil if the task completed without tool calls.
    private func executeStep(
        conversation: inout [Message],
        toolResults: inout [ToolCallResult],
        finalMessage: inout Message?,
        lastBackendProvider: inout LLMProvider,
        availableTools: [ToolDefinition],
        context: ProjectContext?,
        toolExecutor: ToolExecutor?,
        computerUseExecutor: ComputerUseExecutor?,
        screenshotProvider: ScreenshotProvider?,
        onEvent: EventHandler?,
        policy: ToolExecutionPolicy
    ) async throws -> Message? {
        // Build system prompt with agent state context
        let stateContext = buildStateContext()
        var augmentedMessages = conversation
        if !stateContext.isEmpty, let firstSystemIdx = augmentedMessages.firstIndex(where: { $0.role == .system }) {
            let existing = augmentedMessages[firstSystemIdx]
            let augmented = Message(
                id: existing.id,
                role: .system,
                content: [.text(existing.textContent + "\n\n" + stateContext)],
                timestamp: existing.timestamp
            )
            augmentedMessages[firstSystemIdx] = augmented
        }

        // Phase: Planning (every few rounds or when needed)
        if state.roundCount == 1 || state.currentPhase == .recovering || state.currentPhase == .replanning {
            await emit(.phaseChange(.planning, summary: "正在规划下一步动作"), onEvent)
        }

        // Phase: Acting — call LLM with multi-model fallback
        await emit(.phaseChange(.acting, summary: "第 \(state.roundCount) 轮执行"), onEvent)

        // Prune conversation to prevent unbounded growth
        if conversation.count > 30 {
            let systemIdx = conversation.firstIndex(where: { $0.role == .system })
            let tail = Array(conversation.suffix(25))
            conversation = (systemIdx.map { [conversation[$0]] } ?? []) + tail
        }

        // Inject screenshot for visual context (round 1, every screenshotInterval rounds, or on recovery)
        let shouldScreenshot = screenshotProvider != nil && (
            state.roundCount == 1
            || state.currentPhase == .recovering
            || state.currentPhase == .replanning
            || state.roundCount % config.screenshotInterval == 0
        )
        if shouldScreenshot, let provider = screenshotProvider {
            if let pngData = await provider() {
                let base64 = pngData.base64EncodedString()
                let imageBlock: ContentBlock = .image(.base64(base64, mimeType: "image/png"))
                augmentedMessages.append(Message(role: .user, content: [imageBlock]))
                await emit(.screenshotInjected(pngData.count), onEvent)
            }
        }

        // Call LLM with multi-model fallback
        let response: Message
        do {
            let result = try await smartRouter.chatWithFallback(
                messages: augmentedMessages,
                tools: availableTools,
                delegate: nil,
                context: context
            )
            response = result.message
            lastBackendProvider = result.provider
            if result.attempts > 1 {
                await emit(.warning("经 \(result.attempts) 次尝试后由 \(result.provider.rawValue) 响应"), onEvent)
            }
        } catch {
            await emit(.phaseChange(.failed, summary: "LLM 调用失败: \(error.localizedDescription)"), onEvent)
            state.currentPhase = .failed
            throw error
        }

        // Check for tool calls — no tool calls means LLM is providing final answer
        guard response.hasToolCalls else {
            finalMessage = response
            state.currentPhase = .completed
            await emit(.phaseChange(.completed, summary: "任务完成"), onEvent)
            return nil
        }

        // Extract tool calls
        let toolCalls: [ToolCallRequest] = response.content.compactMap { block in
            if case .toolCall(let request) = block { return request }
            return nil
        }

        guard !toolCalls.isEmpty else {
            finalMessage = response
            state.currentPhase = .completed
            return nil
        }

        // Separate computer-use actions from regular tool calls
        let computerUseToolNames: Set<String> = [
            "click", "click_element", "type_text", "set_value", "press_key",
            "open_app", "open_url", "safari_search", "focus_window", "scroll",
            "activate_menu", "drag", "get_app_state", "get_browser_state",
        ]

        var computerUseActions: [ComputerUseAction] = []
        var regularToolCalls: [ToolCallRequest] = []

        for call in toolCalls {
            if computerUseToolNames.contains(call.name) {
                let goal = inferVerificationGoal(for: call)
                computerUseActions.append(ComputerUseAction(toolCall: call, verificationGoal: goal))
            } else {
                regularToolCalls.append(call)
            }
        }

        // Execute ComputerUse actions through the runtime
        if !computerUseActions.isEmpty, let computerUseExecutor {
            await emit(.phaseChange(.acting, summary: "执行 \(computerUseActions.count) 个桌面操作"), onEvent)
            let runResult = await computerUseExecutor(
                computerUseActions,
                computerUseActions.first?.verificationGoal?.expectedApp,
                policy
            )
            for step in runResult.steps {
                await emit(.toolCallStarted(step.action.toolCall), onEvent)
                await emit(.toolCallCompleted(step.toolResult), onEvent)
                toolResults.append(step.toolResult)
                let resultBlock: ContentBlock = .toolResult(step.toolResult)
                conversation.append(Message(role: .tool, content: [resultBlock]))
                if !step.verified {
                    await emit(.warning("步骤未验证: \(step.action.toolCall.name)"), onEvent)
                }
            }
            if runResult.succeeded {
                state.stagnationCount = 0
            } else {
                state.stagnationCount += 1
            }
        }

        // Execute regular tool calls
        for call in regularToolCalls {
            guard let toolExecutor else {
                let result = ToolCallResult(id: call.id, output: "无工具执行器", isError: true)
                toolResults.append(result)
                continue
            }

            await emit(.toolCallStarted(call), onEvent)

            var result: ToolCallResult
            var recoveryAttempts = 0
            // 重试退避策略: [0s, 1s, 3s, 3s, 3s] — 超过 5 次放弃
            let backoffSchedule: [UInt64] = [0, 1000, 3000, 3000, 3000]
            let maxRetries = 5
            // 全局工具重试上限
            let maxTotalRetries = 20

            repeat {
                // 带 30 秒超时的工具执行
                do {
                    result = try await withThrowingTaskGroup(of: ToolCallResult.self) { group in
                        group.addTask { try await toolExecutor(call) }
                        group.addTask {
                            try await Task.sleep(for: .seconds(30))
                            throw ToolTimeoutError()
                        }
                        guard let r = try await group.next() else {
                            group.cancelAll()
                            throw ToolTimeoutError()
                        }
                        group.cancelAll()
                        return r
                    }
                } catch is ToolTimeoutError {
                    result = ToolCallResult(
                        id: call.id,
                        output: "工具执行超时（30 秒），请检查操作是否卡住后重试",
                        isError: true
                    )
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    result = ToolCallResult(
                        id: call.id,
                        output: "执行失败: \(error.localizedDescription)",
                        isError: true
                    )
                }

                if result.isError {
                    // 第一次失败且不可恢复 -> 直接放弃
                    if recoveryAttempts == 0, !isRecoverableError(result.output) {
                        break
                    }
                    // 重试次数上限
                    recoveryAttempts += 1
                    guard recoveryAttempts <= maxRetries else {
                        os_log(.error, "[AgentOrchestrator] 工具 %{public}s 超过最大重试次数 %d", call.name, maxRetries)
                        break
                    }
                    // 全局重试上限
                    state.totalToolRetryCount += 1
                    guard state.totalToolRetryCount <= maxTotalRetries else {
                        os_log(.error, "[AgentOrchestrator] 全局工具重试超过 %d 次，停止重试", maxTotalRetries)
                        break
                    }

                    await emit(.recoveryAttempt(
                        "工具 \(call.name) 失败，第 \(recoveryAttempts) 次重试",
                        strategy: "reobserveAndRetry"
                    ), onEvent)
                    state.failedAttempts.append(AgentFailedAttempt(
                        toolCall: call,
                        error: result.output,
                        recoveryStrategy: "reobserveAndRetry"
                    ))

                    // 退避等待
                    let backoffMs = (recoveryAttempts - 1) < backoffSchedule.count
                        ? backoffSchedule[recoveryAttempts - 1]
                        : 3000
                    if backoffMs > 0 {
                        try await Task.sleep(for: .milliseconds(backoffMs))
                    }
                    continue
                }
                break
            } while true

            // 为失败的工具提供替代建议
            if result.isError {
                result = ToolCallResult(
                    id: call.id,
                    output: result.output + "\n\n" + fallbackSuggestion(for: call.name, arguments: call.arguments),
                    isError: true
                )
            }

            // 验证空结果
            if !result.isError {
                let trimmed = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count < 3 {
                    os_log(.default, "[AgentOrchestrator] 警告: 工具 %{public}s 返回疑似未执行: '%{public}s'", call.name, result.output)
                    await emit(.warning("工具 \(call.name) 可能未实际执行（输出为空）"), onEvent)
                }
            }

            // Runtime log
            os_log(.debug, "[AgentOrchestrator] 工具: %{public}s 结果: %{public}s", call.name, result.isError ? "失败" : "成功")

            await emit(.toolCallCompleted(result), onEvent)
            toolResults.append(result)

            let resultBlock: ContentBlock = .toolResult(result)
            conversation.append(Message(role: .tool, content: [resultBlock]))

            if result.isError {
                state.failedAttempts.append(AgentFailedAttempt(
                    toolCall: call,
                    error: result.output,
                    recoveryStrategy: recoveryAttempts > 0 ? "reobserveAndRetry" : nil,
                    wasRecovered: recoveryAttempts > 0 && !result.isError
                ))
                state.stagnationCount += 1
            } else {
                state.stagnationCount = 0
            }
        }

        return response
    }

    /// Post-step: append the LLM response to conversation, verify results, check for completion,
    /// and auto-replan on repeated failures.
    /// Returns false when the task should stop (terminal response detected).
    private func collectStepResults(
        response: Message,
        conversation: inout [Message],
        finalMessage: inout Message?,
        onEvent: EventHandler?
    ) async -> Bool {
        // Append assistant response to conversation
        conversation.append(response)

        // Phase: Verify
        await emit(.phaseChange(.verifying, summary: "检查本轮结果"), onEvent)

        // Check if task is done based on response
        let toolCalls: [ToolCallRequest] = response.content.compactMap { block in
            if case .toolCall(let request) = block { return request }
            return nil
        }

        if isTerminalResponse(response), toolCalls.isEmpty {
            finalMessage = response
            state.currentPhase = .completed
            return false
        }

        // Auto-replan if too many failures
        let recentFailures = state.failedAttempts.suffix(3)
        if recentFailures.count >= 3, recentFailures.allSatisfy({ !$0.wasRecovered }) {
            await emit(.phaseChange(.replanning, summary: "连续失败，请求 LLM 调整策略"), onEvent)
            state.currentPhase = .replanning
            let replanMsg = Message(role: .user, content: [.text(
                "前几步操作失败了。请观察当前状态，调整方法重新尝试。考虑用不同的工具或不同的参数。"
            )])
            conversation.append(replanMsg)
        }

        return true
    }

    /// Handle a step-level error by setting the phase to failed and rethrowing.
    private func handleStepError(_ error: Error, onEvent: EventHandler?) async throws {
        await emit(.phaseChange(.failed, summary: "LLM 调用失败: \(error.localizedDescription)"), onEvent)
        state.currentPhase = .failed
        throw error
    }

    // MARK: - Streaming Execute

    public func executeStreaming(
        messages: [Message],
        context: ProjectContext?,
        availableTools: [ToolDefinition],
        toolExecutor: ToolExecutor? = nil,
        computerUseExecutor: ComputerUseExecutor? = nil,
        screenshotProvider: ScreenshotProvider? = nil,
        delegate: LLMStreamingDelegate? = nil
    ) async throws -> AsyncStream<AgentLoopEvent> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    let onEvent: @Sendable (AgentLoopEvent) async -> Void = { event in
                        continuation.yield(event)
                    }
                    let response = try await execute(
                        messages: messages,
                        context: context,
                        availableTools: availableTools,
                        toolExecutor: toolExecutor,
                        computerUseExecutor: computerUseExecutor,
                        screenshotProvider: screenshotProvider,
                        onEvent: onEvent
                    )
                    continuation.yield(.completed(response))
                    continuation.finish()
                } catch {
                    if !(error is CancellationError) {
                        continuation.yield(.failed(error))
                    }
                    continuation.finish()
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    // MARK: - Sub-Agent

    public func runSubAgent(
        task: String,
        context: ProjectContext?,
        tools: [ToolDefinition],
        toolExecutor: ToolExecutor? = nil
    ) async throws -> Message {
        let prompt = Message(role: .user, content: [.text(task)])
        let (backend, config) = await smartRouter.getBestAvailableBackend(
            for: [prompt],
            context: context
        )
        return try await backend.chat(
            messages: [prompt],
            config: config,
            tools: tools,
            delegate: nil
        )
    }

    // MARK: - Public State

    public var currentState: AgentLoopState { state }

    public func resetState() {
        state = AgentLoopState()
    }

    // MARK: - Private

    /// Classify a tool error output as recoverable (network, timeout) vs permanent (invalid params, permission).
    private func isRecoverableError(_ output: String) -> Bool {
        let lower = output.lowercased()
        let permanentPatterns: [String] = [
            "permission denied", "not allowed", "unauthorized", "forbidden", "403",
            "invalid", "not found", "404", "does not exist", "no such",
            "access denied", "bad request", "400",
        ]
        if permanentPatterns.contains(where: { lower.contains($0) }) {
            return false
        }
        let recoverablePatterns: [String] = [
            "timeout", "timed out", "time-out",
            "network", "connection refused", "no route to host",
            "temporary", "try again", "rate limit", "too many requests", "429",
            "service unavailable", "502", "503", "internal server error", "500",
            "econnreset", "econnrefused", "etimedout", "enotreach",
            "interrupted", "closed",
        ]
        return recoverablePatterns.contains(where: { lower.contains($0) })
    }

    private func emit(_ event: AgentLoopEvent, _ handler: EventHandler?) async {
        guard let handler else { return }
        await handler(event)
    }

    func buildStateContext() -> String {
        var parts: [String] = ["[Agent 内部状态]"]

        if !state.observations.isEmpty {
            let latest = state.observations.suffix(2)
            parts.append("最近观察: " + latest.map(\.summary).joined(separator: " | "))
        }

        if !state.completedSubtasks.isEmpty {
            parts.append("已完成子任务: " + state.completedSubtasks.map(\.description).joined(separator: ", "))
        }

        if !state.pendingSubtasks.isEmpty {
            parts.append("待执行子任务: " + state.pendingSubtasks.map(\.description).joined(separator: ", "))
        }

        if !state.failedAttempts.isEmpty {
            let recent = state.failedAttempts.suffix(2)
            parts.append("最近失败: " + recent.map { "\($0.toolCall.name): \(String($0.error.prefix(80)))" }.joined(separator: " | "))
        }

        parts.append("当前阶段: \(state.currentPhase.rawValue)")
        parts.append("循环轮次: \(state.roundCount)")

        return parts.joined(separator: "\n")
    }

    func isTerminalResponse(_ message: Message) -> Bool {
        let text = message.textContent.lowercased()
        let terminalPhrases = [
            "已完成", "任务已完成", "完成", "done", "finished",
            "这是结果", "here is the result",
            "总结", "以上是", "以上就是",
        ]
        let isLong = text.count >= 200
        let hasTerminalPhrase = terminalPhrases.contains { text.contains($0) }
        return isLong && hasTerminalPhrase
    }

    func inferVerificationGoal(for call: ToolCallRequest) -> VerificationGoal? {
        switch call.name {
        case "open_app":
            let name = call.arguments["app_name"]
            return VerificationGoal(expectedText: name, expectedApp: name)
        case "open_url":
            let host = URL(string: call.arguments["url"] ?? "")?.host?.replacingOccurrences(of: "www.", with: "")
            return VerificationGoal(expectedText: host, expectedApp: "Safari", expectedWindowTitle: host)
        case "safari_search":
            let query = call.arguments["query"]
            return VerificationGoal(expectedText: query, expectedApp: "Safari")
        case "click", "click_element":
            let title = call.arguments["title"] ?? call.arguments["label"]
            return VerificationGoal(expectedText: title, expectedElementRole: call.arguments["role"])
        case "type_text", "set_value":
            return VerificationGoal(expectedText: call.arguments["text"] ?? call.arguments["value"])
        case "focus_window":
            return VerificationGoal(expectedWindowTitle: call.arguments["title"])
        default:
            return nil
        }
    }

    /// Provide a structured fallback suggestion when a tool fails.
    private func fallbackSuggestion(for toolName: String, arguments: [String: String]) -> String {
        let fallbacks: [String: String] = [
            "click": "请尝试使用坐标点击（指定 x/y 坐标）",
            "click_element": "请尝试使用 stable_id 或屏幕坐标点击",
            "type_text": "请尝试使用剪贴板复制+粘贴（copy_selected + office_paste）",
            "set_value": "请尝试使用剪贴板复制+粘贴",
            "press_key": "请尝试使用 AppleScript 按键模拟",
            "open_app": "请确认应用名称正确，或使用 Finder 手动打开",
            "open_url": "请确认 URL 格式正确，或使用 Safari 手动打开",
            "focus_window": "请确认窗口标题正确，或使用 activate_menu 切换窗口",
            "scroll": "请尝试使用键盘快捷键（Page Up/Down）滚动",
            "get_app_state": "请重试，或先确认目标应用已启动",
            "get_browser_state": "请重试，或先确认浏览器已打开",
            "safari_search": "请确认 Safari 已打开，或使用 open_app 先启动 Safari",
            "drag": "请尝试分两步点击（先点击起始位置，再点击目标位置）",
            "activate_menu": "请确认菜单路径正确，或使用快捷键替代",
        ]
        let suggestion = fallbacks[toolName] ?? "请尝试其他可用工具或重试。"
        return "[工具失败] \(toolName) 未能执行，建议：\(suggestion)"
    }
}

public struct AgentTask: Identifiable, Sendable, Hashable {
    public let id: UUID
    public let description: String
    public let status: AgentTaskStatus

    public init(id: UUID, description: String, status: AgentTaskStatus) {
        self.id = id
        self.description = description
        self.status = status
    }

    public enum AgentTaskStatus: String, Sendable, Hashable {
        case pending
        case running
        case completed
        case failed
    }
}

public enum AgentError: Error, Sendable {
    case noAvailableBackend(String? = nil)
    case maxIterationsReached
    case tooManyAgents
    case toolExecutionFailed(String)
}
