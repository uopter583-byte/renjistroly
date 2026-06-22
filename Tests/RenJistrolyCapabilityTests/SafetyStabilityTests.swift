import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

// MARK: - Tool Execution Policy

func testSafetyDefaultPolicyAutoExecutesLowOnly() {
    let policy = ToolExecutionPolicy.default
    XCTAssertTrue(policy.canAutoExecute(.low) == true)
    XCTAssertTrue(policy.canAutoExecute(.medium) == false)
    XCTAssertTrue(policy.canAutoExecute(.high) == false)
}

func testSafetyPermissivePolicyAutoExecutesLowAndMedium() {
    let policy = ToolExecutionPolicy.permissive
    XCTAssertTrue(policy.canAutoExecute(.low) == true)
    XCTAssertTrue(policy.canAutoExecute(.medium) == true)
    XCTAssertTrue(policy.canAutoExecute(.high) == false)
}

func testSafetyStrictPolicyBlocksAllLevels() {
    let policy = ToolExecutionPolicy.strict
    XCTAssertTrue(policy.canAutoExecute(.low) == false)
    XCTAssertTrue(policy.canAutoExecute(.medium) == false)
    XCTAssertTrue(policy.canAutoExecute(.high) == false)
}

// MARK: - Tool Risk Level

func testSafetyRiskLevelComparableOrdering() {
    XCTAssertTrue(ToolRiskLevel.low < ToolRiskLevel.medium)
    XCTAssertTrue(ToolRiskLevel.medium < ToolRiskLevel.high)
    XCTAssertTrue(ToolRiskLevel.low < ToolRiskLevel.high)
    XCTAssertTrue(ToolRiskLevel.high > ToolRiskLevel.low)
    XCTAssertTrue(!(ToolRiskLevel.high < ToolRiskLevel.medium))
}

// MARK: - Tool Action Category

func testSafetyActionCategoryDefaultRiskLevels() {
    XCTAssertTrue(ToolActionCategory.observe.defaultRiskLevel == .low)
    XCTAssertTrue(ToolActionCategory.localFileRead.defaultRiskLevel == .low)
    XCTAssertTrue(ToolActionCategory.shellRead.defaultRiskLevel == .low)
    XCTAssertTrue(ToolActionCategory.localInput.defaultRiskLevel == .medium)
    XCTAssertTrue(ToolActionCategory.localNavigation.defaultRiskLevel == .medium)
    XCTAssertTrue(ToolActionCategory.localFileWrite.defaultRiskLevel == .medium)
    XCTAssertTrue(ToolActionCategory.appLaunch.defaultRiskLevel == .medium)
    XCTAssertTrue(ToolActionCategory.shellWrite.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.localFileDelete.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.codeAgent.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.systemSetting.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.financial.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.externalCommunication.defaultRiskLevel == .high)
}

func testSafetyActionCategoryRequiresConfirmation() {
    XCTAssertTrue(ToolActionCategory.localFileDelete.requiresActionTimeConfirmation == true)
    XCTAssertTrue(ToolActionCategory.systemSetting.requiresActionTimeConfirmation == true)
    XCTAssertTrue(ToolActionCategory.externalCommunication.requiresActionTimeConfirmation == true)
    XCTAssertTrue(ToolActionCategory.sensitiveDataTransmission.requiresActionTimeConfirmation == true)
    XCTAssertTrue(ToolActionCategory.financial.requiresActionTimeConfirmation == true)
    XCTAssertTrue(ToolActionCategory.observe.requiresActionTimeConfirmation == false)
    XCTAssertTrue(ToolActionCategory.localInput.requiresActionTimeConfirmation == false)
    XCTAssertTrue(ToolActionCategory.shellWrite.requiresActionTimeConfirmation == false)
}

// MARK: - Computer Use Confirmation Mode

func testSafetyConfirmationModeTitles() {
    XCTAssertTrue(ComputerUseConfirmationMode.noConfirmation.title == "无需确认")
    XCTAssertTrue(ComputerUseConfirmationMode.preApprovalWorks.title == "预授权可执行")
    XCTAssertTrue(ComputerUseConfirmationMode.alwaysConfirm.title == "执行前确认")
    XCTAssertTrue(ComputerUseConfirmationMode.handOffRequired.title == "必须用户接管")
}

// MARK: - Computer Use Policy Catalog

func testSafetyPolicyCatalogContainsKeyRules() {
    let rules = ComputerUsePolicyCatalog.rules
    XCTAssertTrue(rules.count >= 10)
    XCTAssertTrue(rules.contains(where: { $0.id == "delete-data" && $0.mode == .alwaysConfirm }))
    XCTAssertTrue(rules.contains(where: { $0.id == "financial" && $0.mode == .alwaysConfirm }))
    XCTAssertTrue(rules.contains(where: { $0.id == "third-party-message" && $0.mode == .alwaysConfirm }))
    XCTAssertTrue(rules.contains(where: { $0.id == "system-settings" && $0.mode == .alwaysConfirm }))
    XCTAssertTrue(rules.contains(where: { $0.id == "basic-ui" && $0.mode == .noConfirmation }))
    XCTAssertTrue(rules.contains(where: { $0.id == "browser-safety" && $0.mode == .handOffRequired }))
}

// MARK: - Safety Audit Record

func testSafetyAuditRecordCreationWithDifferentDecisions() {
    let assessment = ToolRiskAssessment(
        toolName: "shell_command",
        riskLevel: .high,
        actionCategory: .shellWrite,
        arguments: ["command": "rm -rf /tmp"],
        summary: "执行 Shell 命令: rm -rf /tmp"
    )
    let denied = SafetyAuditRecord(assessment: assessment, decision: .denied, note: "人工确认被拒绝")
    let allowed = SafetyAuditRecord(assessment: assessment, decision: .alwaysAllowed)
    let blocked = SafetyAuditRecord(assessment: assessment, decision: .blocked)

    XCTAssertTrue(denied.decision == .denied)
    XCTAssertTrue(denied.note == "人工确认被拒绝")
    XCTAssertTrue(allowed.decision == .alwaysAllowed)
    XCTAssertTrue(allowed.note == nil)
    XCTAssertTrue(blocked.decision == .blocked)
    XCTAssertTrue(blocked.assessment.toolName == "shell_command")
}

// MARK: - Tool Execution Record

func testSafetyExecutionRecordAllOutcomes() {
    let auto = ToolExecutionRecord(id: "1", toolName: "read_file", riskLevel: .low, arguments: [:], outcome: .autoExecuted("done"))
    let confirmed = ToolExecutionRecord(id: "2", toolName: "write_file", riskLevel: .medium, arguments: ["path": "/tmp/test"], outcome: .confirmed("approved"))
    let rejected = ToolExecutionRecord(id: "3", toolName: "rm", riskLevel: .high, arguments: ["path": "/tmp/x"], outcome: .rejected)
    let failed = ToolExecutionRecord(id: "4", toolName: "build", riskLevel: .low, arguments: [:], outcome: .failed("timeout"))

    XCTAssertTrue(auto.toolName == "read_file")
    XCTAssertTrue(auto.riskLevel == .low)
    XCTAssertTrue(confirmed.toolName == "write_file")
    XCTAssertTrue(confirmed.riskLevel == .medium)
    XCTAssertTrue(rejected.outcome == .rejected)
    XCTAssertTrue(failed.outcome == .failed("timeout"))
}

// MARK: - Safety Audit Store Clear

func testSafetyAuditStoreClearRemovesAll() async {
    let store = SafetyAuditStore()
    let assessment = ToolRiskAssessment(
        toolName: "open_url",
        riskLevel: .medium,
        arguments: ["url": "https://example.com"],
        summary: "打开网址"
    )
    await store.record(assessment: assessment, decision: .allowedOnce)
    await store.record(assessment: assessment, decision: .denied, note: "未授权的域名")

    var recent = await store.recent()
    XCTAssertTrue(recent.count == 2)
    XCTAssertTrue(recent[0].decision == .denied)
    XCTAssertTrue(recent[0].note == "未授权的域名")

    await store.clear()
    recent = await store.recent()
    XCTAssertTrue(recent.isEmpty)
}

// MARK: - Batch Safety Assessment

func testSafetyBatchAssessmentComputesRiskProperties() {
    let lowRisk = ToolRiskAssessment(toolName: "ls", riskLevel: .low, arguments: [:], summary: "列出目录")
    let mediumRisk = ToolRiskAssessment(toolName: "open_url", riskLevel: .medium, arguments: [:], summary: "打开网址")
    let highRisk = ToolRiskAssessment(toolName: "shell_command", riskLevel: .high, arguments: [:], summary: "执行命令")

    let batch = BatchSafetyAssessment(items: [lowRisk, mediumRisk, highRisk])
    XCTAssertTrue(batch.overallRisk == .high)
    XCTAssertTrue(batch.highRiskItems.count == 1)
    XCTAssertTrue(batch.mediumRiskItems.count == 1)
    XCTAssertTrue(batch.riskBreakdown.contains("高风险 1 项"))
    XCTAssertTrue(batch.riskBreakdown.contains("中风险 1 项"))
}

// MARK: - Tool Risk Assessment Default Args

func testSafetyRiskAssessmentDefaultValues() {
    let assessment = ToolRiskAssessment(
        toolName: "test_tool",
        riskLevel: .medium,
        arguments: [:],
        summary: "Test tool"
    )
    XCTAssertTrue(assessment.actionCategory == .unknown)
    XCTAssertTrue(assessment.riskExplanation.isEmpty)
    XCTAssertTrue(assessment.mitigationHint == nil)
    XCTAssertTrue(assessment.toolName == "test_tool")
    XCTAssertTrue(assessment.riskLevel == .medium)
}

// MARK: - High-Risk Confirmation

func testSafetyHighRiskAssessmentCreatedCorrectly() {
    let assessment = ToolRiskAssessment(toolName: "shell_command", riskLevel: .high, actionCategory: .shellWrite, arguments: ["command": "rm -rf /tmp"], summary: "高风险 Shell 命令")
    XCTAssertTrue(assessment.riskLevel == .high)
    XCTAssertTrue(assessment.actionCategory == .shellWrite)
    XCTAssertTrue(assessment.summary.contains("高风险"))
}

// MARK: - Delete Guard

func testSafetyDeleteGuardCategoryRequiresConfirmation() {
    XCTAssertTrue(ToolActionCategory.localFileDelete.requiresActionTimeConfirmation == true)
    XCTAssertTrue(ToolActionCategory.localFileDelete.defaultRiskLevel == .high)
}

// MARK: - Send Guard

func testSafetySendGuardExternalCommunication() {
    XCTAssertTrue(ToolActionCategory.externalCommunication.requiresActionTimeConfirmation == true)
    XCTAssertTrue(ToolActionCategory.externalCommunication.defaultRiskLevel == .high)
}

// MARK: - Payment Guard

func testSafetyPaymentGuardFinancialCategory() {
    XCTAssertTrue(ToolActionCategory.financial.requiresActionTimeConfirmation == true)
    XCTAssertTrue(ToolActionCategory.financial.defaultRiskLevel == .high)
}

// MARK: - System Settings Guard

func testSafetySystemSettingsGuardConfirmation() {
    XCTAssertTrue(ToolActionCategory.systemSetting.requiresActionTimeConfirmation == true)
    XCTAssertTrue(ToolActionCategory.systemSetting.defaultRiskLevel == .high)
    XCTAssertTrue(ComputerUsePolicyCatalog.rules.contains(where: { $0.id == "system-settings" && $0.mode == .alwaysConfirm }))
}

// MARK: - Shell Risk

func testSafetyShellWriteRiskIsHigh() {
    XCTAssertTrue(ToolActionCategory.shellWrite.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.shellWrite.requiresActionTimeConfirmation == false)
}

// MARK: - Cross-App Risk

func testSafetyCrossAppLaunchIsMediumRisk() {
    XCTAssertTrue(ToolActionCategory.appLaunch.defaultRiskLevel == .medium)
    XCTAssertTrue(ToolActionCategory.appLaunch.requiresActionTimeConfirmation == false)
}

// MARK: - Clipboard Protection

func testSafetySensitiveClipboardClassifiesAccountNumber() {
    var manager = SensitiveClipboardManager()
    manager.classify("6222021234567890123")
    XCTAssertTrue(manager.isSensitive)
    XCTAssertTrue(manager.lastCopyContentType == .accountNumber)
    XCTAssertTrue(manager.warningMessage != nil)
}

// MARK: - Privacy Masking

func testSafetySensitiveDataProtectorDetectsCreditCard() {
    var protector = SensitiveDataProtector()
    protector.analyze("My card is 4111111111111111")
    XCTAssertTrue(protector.detectedTypes.contains(.creditCard))
}

// MARK: - Audit Store Records

func testSafetyAuditStoreRecordsMultipleDecisions() async {
    let store = SafetyAuditStore()
    let assessment = ToolRiskAssessment(toolName: "read_file", riskLevel: .low, arguments: [:], summary: "读取文件")
    await store.record(assessment: assessment, decision: .autoAllowed)
    await store.record(assessment: assessment, decision: .allowedOnce, note: "temporary access")
    let recent = await store.recent()
    XCTAssertTrue(recent.count == 2)
    XCTAssertTrue(recent[0].note == "temporary access")
    XCTAssertTrue(recent[0].decision == .allowedOnce)
}

// MARK: - Clipboard Password Detection

func testSafetySensitiveClipboardClassifiesPassword() {
    var manager = SensitiveClipboardManager()
    manager.classify("P@ssw0rd123!")
    XCTAssertTrue(manager.isSensitive)
    XCTAssertTrue(manager.lastCopyContentType == .password)
    XCTAssertTrue(manager.warningMessage != nil)
}

func testSafetySensitiveClipboardClassifiesIdCard() {
    var manager = SensitiveClipboardManager()
    manager.classify("110101199001011234")
    XCTAssertTrue(manager.isSensitive)
    XCTAssertTrue(manager.lastCopyContentType == .idCard)
    XCTAssertTrue(manager.warningMessage != nil)
}

func testSafetySensitiveClipboardNormalContentNotSensitive() {
    var manager = SensitiveClipboardManager()
    manager.classify("Hello, how are you?")
    XCTAssertFalse(manager.isSensitive)
    XCTAssertTrue(manager.lastCopyContentType == .normal)
    XCTAssertTrue(manager.warningMessage == nil)
}

// MARK: - Privacy Masking Phone and Bank Account

func testSafetySensitiveDataProtectorDetectsPhoneNumber() {
    var protector = SensitiveDataProtector()
    protector.analyze("Call me at 13800138000")
    XCTAssertTrue(protector.detectedTypes.contains(.phoneNumber))
}

func testSafetySensitiveDataProtectorDetectsBankAccount() {
    var protector = SensitiveDataProtector()
    protector.analyze("Bank account: 6222021234567890")
    XCTAssertTrue(protector.detectedTypes.contains(.bankAccount))
}

func testSafetySensitiveDataProtectorRedactedContent() {
    var protector = SensitiveDataProtector()
    protector.analyze("Card: ★★★★1234")
    XCTAssertTrue(protector.isProtected)
    XCTAssertFalse(protector.redactedFields.isEmpty)
}

func testSafetySensitiveDataProtectorNormalTextNoDetection() {
    var protector = SensitiveDataProtector()
    protector.analyze("Hello world")
    XCTAssertTrue(protector.detectedTypes.isEmpty)
    XCTAssertFalse(protector.isProtected)
}

// MARK: - Payment Approval Flow

func testSafetyPaymentApprovalBelow1000NeedsSingleApproval() {
    var flow = PaymentApprovalFlow(amount: 500)
    XCTAssertTrue(flow.requiredLevel == .under1000)
    XCTAssertFalse(flow.requiresDoubleConfirmation)
    XCTAssertTrue(flow.needsMoreApprovals)
    flow.approvedBy.append("manager")
    XCTAssertFalse(flow.needsMoreApprovals)
}

func testSafetyPaymentApprovalAbove10000RequiresDoubleConfirmation() {
    let flow = PaymentApprovalFlow(amount: 50000)
    XCTAssertTrue(flow.requiredLevel == .under100000)
    XCTAssertTrue(flow.requiresDoubleConfirmation)
    XCTAssertTrue(flow.needsMoreApprovals)
}

func testSafetyPaymentApprovalAbove100000RequiresMaxApprovals() {
    let flow = PaymentApprovalFlow(amount: 200000)
    XCTAssertTrue(flow.requiredLevel == .above100000)
    XCTAssertTrue(flow.requiresDoubleConfirmation)
}

func testSafetyPaymentApprovalSummaryFormat() {
    let flow = PaymentApprovalFlow(amount: 5000, approvedBy: ["manager"])
    let summary = flow.summary
    XCTAssertTrue(summary.contains("5000"))
    XCTAssertTrue(summary.contains("under10000"))
}

// MARK: - ToolActionCategory Remaining Categories

func testSafetyActionCategoryCredentialOrAccountDefaults() {
    XCTAssertTrue(ToolActionCategory.credentialOrAccount.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.credentialOrAccount.requiresActionTimeConfirmation == true)
}

func testSafetyActionCategoryInstallSoftwareDefaults() {
    XCTAssertTrue(ToolActionCategory.installSoftware.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.installSoftware.requiresActionTimeConfirmation == true)
}

func testSafetyActionCategorySensitiveDataTransmissionDefaults() {
    XCTAssertTrue(ToolActionCategory.sensitiveDataTransmission.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.sensitiveDataTransmission.requiresActionTimeConfirmation == true)
}

func testSafetyActionCategoryUnknownDefaults() {
    XCTAssertTrue(ToolActionCategory.unknown.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.unknown.requiresActionTimeConfirmation == false)
}

// MARK: - BatchSafetyAssessment Empty

func testSafetyBatchAssessmentEmptyItems() {
    let batch = BatchSafetyAssessment(items: [])
    XCTAssertTrue(batch.overallRisk == .low)
    XCTAssertTrue(batch.highRiskItems.isEmpty)
    XCTAssertTrue(batch.mediumRiskItems.isEmpty)
    XCTAssertTrue(batch.riskBreakdown.contains("0 项"))
    XCTAssertFalse(batch.requiresBatchConfirmation)
}

// MARK: - SafetyAuditRecord Traceability

func testSafetyAuditRecordWithTraceabilityID() {
    let assessment = ToolRiskAssessment(toolName: "shell_command", riskLevel: .high, arguments: [:], summary: "cmd")
    let record = SafetyAuditRecord(assessment: assessment, decision: .allowedOnce, note: "approved", traceabilityID: "trace-001")
    XCTAssertTrue(record.traceabilityID == "trace-001")
}

func testSafetyAuditRecordTimestampPopulated() {
    let assessment = ToolRiskAssessment(toolName: "read_file", riskLevel: .low, arguments: [:], summary: "read")
    let record = SafetyAuditRecord(assessment: assessment, decision: .autoAllowed)
    XCTAssertTrue(record.timestamp.timeIntervalSinceNow < 1)
}

// MARK: - SafetyAuditStore Query by Decision

func testSafetyAuditStoreQueryByDecision() async {
    let store = SafetyAuditStore()
    let assessment = ToolRiskAssessment(toolName: "ls", riskLevel: .low, arguments: [:], summary: "list")
    await store.record(assessment: assessment, decision: .autoAllowed)
    await store.record(assessment: assessment, decision: .denied, note: "blocked")
    let recent = await store.recent()
    XCTAssertTrue(recent.count == 2)
    let deniedRecords = recent.filter { $0.decision == .denied }
    XCTAssertTrue(deniedRecords.count == 1)
    XCTAssertTrue(deniedRecords[0].note == "blocked")
}
