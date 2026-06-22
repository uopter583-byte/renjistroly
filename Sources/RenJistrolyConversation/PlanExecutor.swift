import Foundation
import RenJistrolyModels
import RenJistrolyIntelligence
import RenJistrolyCapability

@MainActor
public final class PlanExecutor {
    private let sessionManager: SessionManager
    private let agentOrchestrator: AgentOrchestrator
    private let mcpClient: MCPClient
    private let contextCompiler: ContextCompiler
    private let computerUseRuntime: ComputerUseRuntime
    private let toolExecutionService: ToolExecutionService
    private let workflowMemoryStore: WorkflowMemoryStore
    private let planGenerator = PlanGenerator()

    public var onRecoveryProfileChanged: ((RecoveryProfileSnapshot) -> Void)?

    public init(
        sessionManager: SessionManager,
        agentOrchestrator: AgentOrchestrator,
        mcpClient: MCPClient,
        contextCompiler: ContextCompiler,
        computerUseRuntime: ComputerUseRuntime,
        toolExecutionService: ToolExecutionService,
        workflowMemoryStore: WorkflowMemoryStore = WorkflowMemoryStore()
    ) {
        self.sessionManager = sessionManager
        self.agentOrchestrator = agentOrchestrator
        self.mcpClient = mcpClient
        self.contextCompiler = contextCompiler
        self.computerUseRuntime = computerUseRuntime
        self.toolExecutionService = toolExecutionService
        self.workflowMemoryStore = workflowMemoryStore
    }

    public func approvePlan(appState: AppState?) async {
        guard var plan = appState?.activePlan else { return }
        guard plan.status == .pendingApproval else { return }

        plan.status = .approved
        appState?.activePlan = plan
        await executePlan(appState: appState)
    }

    public func cancelPlan(appState: AppState?) {
        guard var plan = appState?.activePlan else { return }
        plan.status = .cancelled
        appState?.activePlan = plan

        let cancelMsg = Message(role: .assistant, content: [.text("已取消计划。")])
        if let id = sessionManager.activeConversationID {
            sessionManager.appendMessage(cancelMsg, to: id)
        }
    }

    public func executePlan(appState: AppState?) async {
        guard var plan = appState?.activePlan else { return }
        guard let conversationID = sessionManager.activeConversationID else { return }

        toolExecutionService.updatePolicy(appState?.toolExecutionPolicy ?? .default)
        plan.status = .executing
        appState?.activePlan = plan

        let context = await contextCompiler.compileContext()
        let tools = await mcpClient.availableTools
        var stepResults: [String] = []
        var consecutiveFailures = 0

        for i in plan.steps.indices {
            let stepResult = await executeStep(
                index: i,
                plan: &plan,
                appState: appState,
                conversationID: conversationID,
                context: context,
                tools: tools,
                consecutiveFailures: &consecutiveFailures
            )
            stepResults.append(stepResult)
            appState?.activePlan = plan
        }

        plan.status = .completed
        appState?.activePlan = plan

        let summary = "执行完成:\n" + stepResults.joined(separator: "\n")
        let summaryMsg = Message(role: .assistant, content: [.text(summary)])
        sessionManager.appendMessage(summaryMsg, to: conversationID)
    }

    // MARK: - Step Execution

    private func executeStep(
        index i: Int,
        plan: inout ExecutionPlan,
        appState: AppState?,
        conversationID: UUID,
        context: ProjectContext,
        tools: [ToolDefinition],
        consecutiveFailures: inout Int
    ) async -> String {
        let maxRecoveryPerStep = 3
        var recoveryAttempt = 0
        var stepSucceeded = false
        var result = ""

        while recoveryAttempt <= maxRecoveryPerStep && !stepSucceeded {
            plan.steps[i].status = .executing
            plan.currentStepIndex = i
            appState?.activePlan = plan

            let recoveryContext = await recoveryContextString(attempt: recoveryAttempt)
            let stepPrompt = "[步骤 \(i + 1)/\(plan.steps.count)] \(plan.steps[i].description)\(recoveryContext)"
            let stepMessage = Message(role: .user, content: [.text(stepPrompt)])
            sessionManager.appendMessage(stepMessage, to: conversationID)

            result = await attemptStep(
                index: i,
                plan: &plan,
                appState: appState,
                conversationID: conversationID,
                context: context,
                tools: tools,
                stepPrompt: stepPrompt,
                recoveryAttempt: &recoveryAttempt,
                maxRecoveryPerStep: maxRecoveryPerStep,
                stepSucceeded: &stepSucceeded,
                consecutiveFailures: &consecutiveFailures
            )
        }

        // Dynamic re-planning on consecutive failures
        if consecutiveFailures >= 2, i + 1 < plan.steps.count {
            await rePlanRemainingSteps(
                plan: &plan,
                from: i,
                context: context,
                tools: tools,
                consecutiveFailures: &consecutiveFailures
            )
        }

        return result
    }

    private func attemptStep(
        index i: Int,
        plan: inout ExecutionPlan,
        appState: AppState?,
        conversationID: UUID,
        context: ProjectContext,
        tools: [ToolDefinition],
        stepPrompt: String,
        recoveryAttempt: inout Int,
        maxRecoveryPerStep: Int,
        stepSucceeded: inout Bool,
        consecutiveFailures: inout Int
    ) async -> String {
        do {
            let messages = sessionManager.activeConversation?.messages ?? []
            let response = try await agentOrchestrator.execute(
                messages: messages,
                context: context,
                availableTools: tools,
                toolExecutor: { [weak self] request in
                    guard let self else {
                        return ToolCallResult(id: request.id, output: "引擎已释放", isError: true)
                    }
                    return try await self.toolExecutionService.executeWithAudit(request, appState: appState)
                },
                computerUseExecutor: { [computerUseRuntime] actions, app, policy in
                    await computerUseRuntime.run(actions: actions, app: app, policy: policy)
                }
            )
            plan.steps[i].status = .completed
            plan.steps[i].result = response.finalMessage.textContent
            let resultLine = "✓ \(plan.steps[i].description): \(response.finalMessage.textContent.prefix(100))"
            let respMsg = Message(role: .assistant, content: [.text(response.finalMessage.textContent)])
            sessionManager.appendMessage(respMsg, to: conversationID)
            consecutiveFailures = 0
            stepSucceeded = true

            if recoveryAttempt > 0 {
                await workflowMemoryStore.remember(
                    task: plan.steps[i].description,
                    steps: ["strategy: retry", "tool: agent_orchestrator", "recovery: success after \(recoveryAttempt) attempts"],
                    success: true,
                    learnedWorkflow: "recovery: retry-after-\(recoveryAttempt)-attempts"
                )
            }
            return resultLine
        } catch let confirmation as ToolNeedsConfirmationError {
            return await handleConfirmationError(
                confirmation: confirmation,
                index: i,
                plan: &plan,
                appState: appState,
                recoveryAttempt: &recoveryAttempt,
                stepSucceeded: &stepSucceeded,
                consecutiveFailures: &consecutiveFailures
            )
        } catch {
            return await handleGenericError(
                error: error,
                index: i,
                plan: &plan,
                recoveryAttempt: &recoveryAttempt,
                maxRecoveryPerStep: maxRecoveryPerStep,
                stepSucceeded: &stepSucceeded,
                consecutiveFailures: &consecutiveFailures
            )
        }
    }

    private func handleConfirmationError(
        confirmation: ToolNeedsConfirmationError,
        index i: Int,
        plan: inout ExecutionPlan,
        appState: AppState?,
        recoveryAttempt: inout Int,
        stepSucceeded: inout Bool,
        consecutiveFailures: inout Int
    ) async -> String {
        let approved = await toolExecutionService.requestConfirmation(
            assessment: confirmation.assessment, appState: appState
        )
        if approved {
            await toolExecutionService.recordSafetyAudit(
                assessment: confirmation.assessment, decision: .allowedOnce
            )
            if let result = try? await mcpClient.executePreAssessed(confirmation.request) {
                toolExecutionService.recordExecution(
                    toolName: confirmation.request.name,
                    riskLevel: confirmation.assessment.riskLevel,
                    arguments: confirmation.request.arguments,
                    outcome: .confirmed(result.output),
                    appState: appState
                )
                plan.steps[i].status = .completed
                plan.steps[i].result = result.output
                let resultLine = "✓ \(plan.steps[i].description): \(result.output.prefix(100))"
                consecutiveFailures = 0
                stepSucceeded = true
                return resultLine
            } else {
                toolExecutionService.recordExecution(
                    toolName: confirmation.request.name,
                    riskLevel: confirmation.assessment.riskLevel,
                    arguments: confirmation.request.arguments,
                    outcome: .failed("执行失败"),
                    appState: appState
                )
                recoveryAttempt += 1
            }
        } else {
            await toolExecutionService.recordSafetyAudit(
                assessment: confirmation.assessment, decision: .denied, note: "User rejected plan step"
            )
            toolExecutionService.recordExecution(
                toolName: confirmation.request.name,
                riskLevel: confirmation.assessment.riskLevel,
                arguments: confirmation.request.arguments,
                outcome: .rejected,
                appState: appState
            )
            plan.steps[i].status = .skipped
            let resultLine = "⊘ \(plan.steps[i].description): 已跳过"
            stepSucceeded = true // Don't retry skipped steps
            return resultLine
        }
        return ""
    }

    private func handleGenericError(
        error: Error,
        index i: Int,
        plan: inout ExecutionPlan,
        recoveryAttempt: inout Int,
        maxRecoveryPerStep: Int,
        stepSucceeded: inout Bool,
        consecutiveFailures: inout Int
    ) async -> String {
        recoveryAttempt += 1
        if recoveryAttempt > maxRecoveryPerStep {
            plan.steps[i].status = .failed
            plan.steps[i].result = error.localizedDescription
            let resultLine = "✗ \(plan.steps[i].description): \(error.localizedDescription.prefix(80))"
            consecutiveFailures += 1
            await workflowMemoryStore.remember(
                task: plan.steps[i].description,
                steps: ["strategy: retry", "tool: agent_orchestrator", "recovery: failed after \(maxRecoveryPerStep) attempts"],
                success: false,
                failureReason: error.localizedDescription
            )
            return resultLine
        }
        return ""
    }

    private func rePlanRemainingSteps(
        plan: inout ExecutionPlan,
        from failedIndex: Int,
        context: ProjectContext,
        tools: [ToolDefinition],
        consecutiveFailures: inout Int
    ) async {
        let remaining = plan.steps[(failedIndex + 1)...].map { $0.description }
        let failureContext = plan.steps[failedIndex].result ?? "未知错误"
        let rePlanPrompt = """
        以下计划步骤连续失败，请重新规划剩余步骤：
        失败步骤: \(plan.steps[failedIndex].description)
        失败原因: \(failureContext)
        剩余步骤: \(remaining.joined(separator: ", "))
        请根据失败原因提供调整后的步骤列表。
        """
        if let newPlan = try? await planGenerator.generatePlan(
            userMessage: rePlanPrompt,
            context: context,
            toolDefinitions: tools
        ) {
            plan.steps.removeSubrange((failedIndex + 1)...)
            plan.steps.append(contentsOf: newPlan.steps)
            consecutiveFailures = 0
        }
    }

    // MARK: - Helpers

    private func recoveryContextString(attempt: Int) async -> String {
        guard attempt > 0 else { return "" }
        let profile = await workflowMemoryStore.bestRecoveryStrategyProfile(
            appName: nil,
            toolName: nil
        )
        let strategies = profile.scores
            .sorted { $0.value.successRate > $1.value.successRate }
            .prefix(3)
        let strategyHints = strategies.map { "  - \($0.key) (成功率: \(Int($0.value.successRate * 100))%)" }.joined(separator: "\n")
        return """

        第 \(attempt) 次恢复尝试。
        历史恢复策略参考:
        \(strategyHints)
        请尝试与上次不同的方法完成此步骤。
        """
    }
}
