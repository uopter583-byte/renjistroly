import Foundation
import XCTest
import RenJistrolyModels

// MARK: - FoundationHealthStatus

func testFoundationHealthStatusLabels() {
    XCTAssertTrue(FoundationHealthStatus.ok.label == "正常")
    XCTAssertTrue(FoundationHealthStatus.warning.label == "需关注")
    XCTAssertTrue(FoundationHealthStatus.failing.label == "失败")
    XCTAssertTrue(FoundationHealthStatus.notImplemented.label == "未完成")
}

// MARK: - FoundationLayer

func testFoundationLayerTitles() {
    XCTAssertTrue(FoundationLayer.feedbackLoop.title == "反馈闭环")
    XCTAssertTrue(FoundationLayer.selfOptimizationRecovery.title == "自优化与恢复")
    XCTAssertTrue(FoundationLayer.permissionIdentity.title == "权限与身份稳定")
    XCTAssertTrue(FoundationLayer.localActionExecution.title == "本地动作执行")
    XCTAssertTrue(FoundationLayer.userMemory.title == "用户记忆")
    XCTAssertTrue(FoundationLayer.realtimeVoice.title == "实时语音")
    XCTAssertTrue(FoundationLayer.providerAbstraction.title == "Provider 抽象")
    XCTAssertTrue(FoundationLayer.screenUnderstanding.title == "屏幕理解")
    XCTAssertTrue(FoundationLayer.diagnostics.title == "日志与诊断")
    XCTAssertTrue(FoundationLayer.safetyBoundary.title == "安全边界")
    XCTAssertTrue(FoundationLayer.installRelease.title == "安装与发布")
    XCTAssertTrue(FoundationLayer.operatorUI.title == "UI 操作层")
}

func testFoundationLayerBaselineRequirementsNotEmpty() {
    for layer in FoundationLayer.allCases {
        XCTAssertFalse(layer.baselineRequirement.isEmpty)
    }
}

func testFoundationLayerAllCasesCount() {
    XCTAssertTrue(FoundationLayer.allCases.count == 12)
}

// MARK: - FoundationLayerSnapshot

func testFoundationLayerSnapshotID() {
    let snap = FoundationLayerSnapshot(layer: .feedbackLoop, status: .ok, detail: "正常")
    XCTAssertTrue(snap.id == .feedbackLoop)
    XCTAssertTrue(snap.status == .ok)
}

// MARK: - FeedbackCategory

func testFeedbackCategoryTitles() {
    XCTAssertTrue(FeedbackCategory.speechRecognition.title == "语音识别")
    XCTAssertTrue(FeedbackCategory.modelResponse.title == "模型回复")
    XCTAssertTrue(FeedbackCategory.actionExecution.title == "动作执行")
    XCTAssertTrue(FeedbackCategory.permission.title == "权限")
    XCTAssertTrue(FeedbackCategory.screenUnderstanding.title == "屏幕理解")
    XCTAssertTrue(FeedbackCategory.provider.title == "Provider")
    XCTAssertTrue(FeedbackCategory.performance.title == "速度")
    XCTAssertTrue(FeedbackCategory.ui.title == "界面")
    XCTAssertTrue(FeedbackCategory.upgrade.title == "升级")
    XCTAssertTrue(FeedbackCategory.unknown.title == "未知")
}

func testFeedbackCategoryAllCasesCount() {
    XCTAssertTrue(FeedbackCategory.allCases.count == 10)
}

// MARK: - FeedbackReport

func testFeedbackReportDefaultStatus() {
    let report = FeedbackReport(
        category: .actionExecution,
        userComplaint: "点击没反应",
        diagnosticID: UUID(),
        proposedFix: "重新检查元素"
    )
    XCTAssertTrue(report.status == "待处理")
    XCTAssertTrue(report.category == .actionExecution)
}

// MARK: - UpgradePlan

func testUpgradePlanDefaults() {
    let plan = UpgradePlan(title: "修复登录", reason: "用户反馈", steps: ["检查代码", "更新测试"])
    XCTAssertTrue(plan.risk == .persistentOrExternal)
    XCTAssertTrue(plan.status == "草案")
    XCTAssertTrue(plan.steps.count == 2)
}

// MARK: - ProviderHealthSnapshot

func testProviderHealthSnapshotID() {
    let snap = ProviderHealthSnapshot(kind: .deepSeek, status: .ok, detail: "正常")
    XCTAssertTrue(snap.id == .deepSeek)
}

// MARK: - UserOperationMemory

func testUserOperationMemoryDefaults() {
    let mem = UserOperationMemory(key: "Safari", value: "浏览器", category: "app")
    XCTAssertTrue(mem.confidence == 0.5)
    XCTAssertTrue(mem.category == "app")
}

// MARK: - AssistantDiagnosticSnapshot

func testAssistantDiagnosticSnapshotEmptyPermissions() {
    let snap = AssistantDiagnosticSnapshot(
        userText: "打开Safari",
        assistantText: "已打开",
        provider: "DeepSeek"
    )
    XCTAssertTrue(snap.permissions.isEmpty)
    XCTAssertTrue(snap.error == nil)
    XCTAssertTrue(snap.latencyMilliseconds == nil)
}

// MARK: - FoundationCapabilityEvidence

func testFoundationCapabilityEvidenceDefault() {
    let evidence = FoundationCapabilityEvidence()
    XCTAssertTrue(evidence.terminalTaskCount == 0)
    XCTAssertFalse(evidence.hasRunningOrCompletedTerminalTask)
    XCTAssertFalse(evidence.lastActionWasVerified)
}
