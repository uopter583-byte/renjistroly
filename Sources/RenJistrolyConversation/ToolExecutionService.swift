import Foundation
import RenJistrolyModels
import RenJistrolyCapability
import RenJistrolySystemBridge

@MainActor
public final class ToolExecutionService {
    private let mcpClient: MCPClient
    private let safetyAuditStore: SafetyAuditStore
    private var confirmationContinuation: CheckedContinuation<Bool, Never>?
    private let screenDiff: ScreenDiffVerifier?

    public private(set) var currentPolicy: ToolExecutionPolicy = .default
    public private(set) var safetyAuditRecords: [SafetyAuditRecord] = []

    public init(
        mcpClient: MCPClient = MCPClient(),
        safetyAuditStore: SafetyAuditStore = SafetyAuditStore(),
        screenContextProvider: ScreenContextProvider? = nil
    ) {
        self.mcpClient = mcpClient
        self.safetyAuditStore = safetyAuditStore
        self.screenDiff = screenContextProvider.map { ScreenDiffVerifier(screen: $0) }
        Task {
            safetyAuditRecords = await safetyAuditStore.recent()
        }
    }

    public func updatePolicy(_ policy: ToolExecutionPolicy) {
        currentPolicy = policy
    }

    // MARK: - Tool Execution

    public func executeWithAudit(_ request: ToolCallRequest, appState: AppState?) async throws -> ToolCallResult {
        let assessment = await mcpClient.assessRisk(request)
        let policy = appState?.toolExecutionPolicy ?? currentPolicy
        if !policy.canAutoExecute(assessment.riskLevel) {
            let approved = await requestConfirmation(assessment: assessment, appState: appState)
            guard approved else {
                await recordSafetyAudit(assessment: assessment, decision: .denied, note: "User rejected")
                recordExecution(toolName: request.name, riskLevel: assessment.riskLevel, arguments: request.arguments, outcome: .rejected, appState: appState)
                return ToolCallResult(id: request.id, output: "已取消: \(assessment.summary)", isError: true)
            }
            await recordSafetyAudit(assessment: assessment, decision: .allowedOnce)
        } else {
            await recordSafetyAudit(assessment: assessment, decision: .autoAllowed)
        }

        do {
            let ocrBefore = needsVisualVerification(request.name) ? await screenDiff?.captureBefore() : nil
            let result = try await mcpClient.executePreAssessed(request)
            var output = result.output
            if let ocrBefore, let screenDiff {
                let expectedKeywords = extractExpectedKeywords(from: request)
                let diff = await screenDiff.captureAfterAndDiff(beforeText: ocrBefore, expectedKeywords: expectedKeywords)
                let verificationLine = "[验证] \(diff.summary)"
                output = output.hasSuffix("\n") ? "\(output)\(verificationLine)" : "\(output)\n\(verificationLine)"
            }
            recordExecution(
                toolName: request.name,
                riskLevel: assessment.riskLevel,
                arguments: request.arguments,
                outcome: result.isError ? .failed(output) : .autoExecuted(output),
                appState: appState
            )
            return ToolCallResult(id: result.id, output: output, isError: result.isError)
        } catch {
            recordExecution(toolName: request.name, riskLevel: assessment.riskLevel, arguments: request.arguments, outcome: .failed(error.localizedDescription), appState: appState)
            return ToolCallResult(id: request.id, output: "执行失败: \(error.localizedDescription)", isError: true)
        }
    }

    // MARK: - Safety Audit

    public func recordSafetyAudit(
        assessment: ToolRiskAssessment,
        decision: SafetyAuditRecord.Decision,
        note: String? = nil
    ) async {
        await safetyAuditStore.record(assessment: assessment, decision: decision, note: note)
        safetyAuditRecords = await safetyAuditStore.recent()
    }

    public func recordExecution(
        toolName: String,
        riskLevel: ToolRiskLevel,
        arguments: [String: String],
        outcome: ToolExecutionRecord.Outcome,
        appState: AppState?
    ) {
        let record = ToolExecutionRecord(
            id: UUID().uuidString,
            toolName: toolName,
            riskLevel: riskLevel,
            arguments: arguments,
            outcome: outcome
        )
        appState?.toolAuditLog.insert(record, at: 0)
    }

    // MARK: - Confirmation

    public func requestConfirmation(assessment: ToolRiskAssessment, appState: AppState?) async -> Bool {
        appState?.pendingConfirmation = assessment
        // If a previous confirmation is pending, reject it to avoid orphaned continuation.
        confirmationContinuation?.resume(returning: false)
        confirmationContinuation = nil
        return await withTaskCancellationHandler {
            await withCheckedContinuation { cont in
                confirmationContinuation = cont
            }
        } onCancel: {
            Task { @MainActor in
                if let cont = self.confirmationContinuation {
                    self.confirmationContinuation = nil
                    cont.resume(returning: false)
                }
            }
        }
    }

    public func resolveConfirmation(approved: Bool, appState: AppState?) {
        appState?.pendingConfirmation = nil
        confirmationContinuation?.resume(returning: approved)
        confirmationContinuation = nil
    }

    // MARK: - Visual verification

    func needsVisualVerification(_ toolName: String) -> Bool {
        Self.visuallyVerifiedTools.contains(toolName)
    }

    private static let visuallyVerifiedTools: Set<String> = [
        "click", "click_element", "type_text", "set_value", "press_key",
        "activate_menu", "open_app", "open_url", "open_path",
        "safari_search", "focus_window", "scroll", "drag",
        "reveal_in_finder", "open_in_xcode",
        "dom_click", "dom_fill", "dom_submit",
        "create_folder", "move_file", "copy_file", "delete_file",
    ]

    func extractExpectedKeywords(from request: ToolCallRequest) -> [String] {
        var keywords: [String] = []
        if let text = request.arguments["text"] ?? request.arguments["value"] {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { keywords.append(trimmed) }
        }
        if let query = request.arguments["query"] {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { keywords.append(trimmed) }
        }
        if let title = request.arguments["title"] ?? request.arguments["label"] {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { keywords.append(trimmed) }
        }
        if let path = request.arguments["path"] {
            let lastComponent = (path as NSString).lastPathComponent
            if !lastComponent.isEmpty { keywords.append(lastComponent) }
        }
        if let app = request.arguments["app"] ?? request.arguments["app_name"] {
            let trimmed = app.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { keywords.append(trimmed) }
        }
        return keywords
    }
}
