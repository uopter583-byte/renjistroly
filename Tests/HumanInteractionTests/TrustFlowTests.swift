import Foundation
import XCTest
@testable import RenJistrolyModels
@testable import RenJistrolySystemBridge

// MARK: - TrustFlowTests

/// 信任流程测试。
/// 验证操作确认、信任边界、风险分级、状态恢复等机制的正确性。
final class TrustFlowTests: XCTestCase {

    // MARK: - 点击预览确认

    func testClickPreviewInitialState() {
        let preview = ClickPreview()
        XCTAssertNil(preview.pendingClick)
        XCTAssertTrue(preview.previewEnabled)
        XCTAssertTrue(preview.requireConfirmation)
        XCTAssertFalse(preview.needsConfirmation)
    }

    func testClickPreviewSetAndConfirm() {
        var preview = ClickPreview()
        let target = ClickPreview.ClickTarget(
            targetDescription: "确定按钮",
            targetApp: "Safari",
            elementRole: "AXButton",
            elementLabel: "确定",
            screenPosition: "x:500,y:300",
            actionDescription: "点击确定"
        )

        preview.setPendingClick(target)
        XCTAssertNotNil(preview.pendingClick)
        XCTAssertTrue(preview.needsConfirmation)
        XCTAssertNotNil(preview.promptMessage)
        XCTAssertTrue(preview.promptMessage!.contains("确定"))

        preview.confirm()
        XCTAssertTrue(preview.pendingClick?.isConfirmed == true)
        XCTAssertFalse(preview.needsConfirmation)
    }

    func testClickPreviewReject() {
        var preview = ClickPreview()
        let target = ClickPreview.ClickTarget(
            targetDescription: "删除按钮",
            targetApp: "Finder",
            actionDescription: "删除文件"
        )

        preview.setPendingClick(target)
        XCTAssertTrue(preview.needsConfirmation)

        preview.reject()
        XCTAssertNil(preview.pendingClick)
        XCTAssertFalse(preview.needsConfirmation)
    }

    func testClickPreviewConfirmationDisabled() {
        var preview = ClickPreview(requireConfirmation: false)
        let target = ClickPreview.ClickTarget(
            targetDescription: "OK",
            actionDescription: "Click OK"
        )

        preview.setPendingClick(target)
        XCTAssertFalse(preview.needsConfirmation, "requireConfirmation=false 时无需确认")
    }

    func testClickPreviewSummary() {
        let target = ClickPreview.ClickTarget(
            targetDescription: "打开链接",
            targetApp: "Safari",
            elementLabel: "了解更多",
            screenPosition: "center",
            actionDescription: "点击了解更多链接"
        )
        let summary = target.previewSummary
        XCTAssertTrue(summary.contains("了解更多"))
        XCTAssertTrue(summary.contains("Safari"))
        XCTAssertTrue(summary.contains("center"))
    }

    // MARK: - 发送预览确认

    func testSendPreviewInitial() {
        let preview = SendPreview()
        XCTAssertNil(preview.pendingSend)
        XCTAssertFalse(preview.needsConfirmation)
    }

    func testSendPreviewConfirmFlow() {
        var preview = SendPreview()
        let pending = SendPreview.PendingSend(
            channelDescription: "Slack",
            recipients: ["@zhangsan"],
            subject: "周报",
            bodyPreview: "本周完成了..."
        )

        preview.setPendingSend(pending)
        XCTAssertTrue(preview.needsConfirmation)

        preview.confirm()
        XCTAssertTrue(preview.pendingSend?.isConfirmed == true)
    }

    func testSendPreviewReject() {
        var preview = SendPreview()
        preview.setPendingSend(SendPreview.PendingSend(
            channelDescription: "邮件",
            recipients: ["test@example.com"],
            bodyPreview: "机密信息"
        ))

        XCTAssertNotNil(preview.promptMessage)

        preview.reject()
        XCTAssertNil(preview.pendingSend)
    }

    // MARK: - 删除保护

    func testDeleteTrashProtectionInitial() {
        let protection = DeleteTrashProtection()
        XCTAssertNil(protection.pendingDelete)
        XCTAssertTrue(protection.forceTrashOnly)
        XCTAssertTrue(protection.requireConfirmation)
    }

    func testDeleteTrashConfirm() {
        var protection = DeleteTrashProtection()
        let request = DeleteTrashProtection.DeleteRequest(
            filePaths: ["/tmp/test.txt"],
            totalSizeBytes: 1024
        )

        protection.setPendingDelete(request)
        XCTAssertTrue(protection.needsConfirmation)
        XCTAssertNotNil(protection.promptMessage)

        protection.confirm()
        XCTAssertTrue(protection.canExecute)
        XCTAssertTrue(protection.pendingDelete?.isMovedToTrash == true)
    }

    func testDeleteTrashReject() {
        var protection = DeleteTrashProtection()
        protection.setPendingDelete(DeleteTrashProtection.DeleteRequest(
            filePaths: ["/tmp/important.doc"],
            totalSizeBytes: 10_000_000
        ))

        protection.reject()
        XCTAssertNil(protection.pendingDelete)
        XCTAssertFalse(protection.canExecute)
    }

    func testDeleteTrashSizeFormatting() {
        let request = DeleteTrashProtection.DeleteRequest(
            filePaths: ["/tmp/big_file.bin"],
            totalSizeBytes: 1_000_000_000
        )
        let formatted = request.sizeFormatted
        XCTAssertTrue(formatted.contains("MB") || formatted.contains("GB"))
    }

    func testDeleteTrashSummary() {
        let request = DeleteTrashProtection.DeleteRequest(
            filePaths: ["/tmp/a.txt", "/tmp/b.txt"],
            totalSizeBytes: 2048
        )
        let summary = request.summary
        XCTAssertTrue(summary.contains("2 个"))
    }

    // MARK: - 决策点确认

    func testDecisionPointInitial() {
        let dp = DecisionPointConfirmation()
        XCTAssertNil(dp.pendingDecision)
        XCTAssertFalse(dp.needsDecision)
    }

    func testDecisionPointFullFlow() {
        var dp = DecisionPointConfirmation()
        let decision = DecisionPointConfirmation.DecisionPoint(
            title: "是否删除",
            description: "确定要删除这个文件吗？",
            options: [
                DecisionPointConfirmation.DecisionOption(label: "是", description: "删除文件", isRecommended: false),
                DecisionPointConfirmation.DecisionOption(label: "否", description: "取消操作", isRecommended: true),
            ],
            context: "文件位于桌面"
        )

        dp.presentDecision(decision)
        XCTAssertTrue(dp.needsDecision)
        XCTAssertNotNil(dp.prompt)
        XCTAssertTrue(dp.prompt!.contains("是否删除"))

        dp.selectOption("否")
        XCTAssertFalse(dp.needsDecision)
        XCTAssertEqual(dp.decisionHistory.count, 1)
    }

    func testDecisionPointReject() {
        var dp = DecisionPointConfirmation()
        dp.presentDecision(DecisionPointConfirmation.DecisionPoint(
            title: "高风险操作",
            description: "此操作不可撤销",
            options: []
        ))

        dp.reject()
        XCTAssertNil(dp.pendingDecision)
    }

    func testDecisionHistoryTracking() {
        var dp = DecisionPointConfirmation()

        let d1 = DecisionPointConfirmation.DecisionPoint(
            title: "决策1", description: "第一个决策",
            options: [DecisionPointConfirmation.DecisionOption(label: "A", description: "选项A")]
        )
        let d2 = DecisionPointConfirmation.DecisionPoint(
            title: "决策2", description: "第二个决策",
            options: [DecisionPointConfirmation.DecisionOption(label: "B", description: "选项B")]
        )

        dp.presentDecision(d1)
        dp.selectOption("A")
        dp.presentDecision(d2)
        dp.selectOption("B")

        XCTAssertEqual(dp.decisionHistory.count, 2)
        XCTAssertEqual(dp.decisionHistory[0].title, "决策1")
        XCTAssertEqual(dp.decisionHistory[1].title, "决策2")
    }

    // MARK: - 操作验证记录

    func testOperationVerifierInitial() {
        let verifier = OperationVerifier()
        XCTAssertTrue(verifier.records.isEmpty)
        XCTAssertTrue(verifier.allPassed)
        XCTAssertEqual(verifier.passRate, 1.0)
    }

    func testOperationVerifierAddRecord() {
        var verifier = OperationVerifier()
        let record = OperationVerifier.VerificationRecord(
            operationDescription: "点击按钮",
            method: .elementExist,
            expectedResult: "按钮可见",
            actualResult: "按钮已找到",
            passed: true
        )
        verifier.addRecord(record)
        XCTAssertEqual(verifier.records.count, 1)
        XCTAssertTrue(verifier.allPassed)

        let summary = verifier.evidenceSummary
        XCTAssertTrue(summary.contains("1/1"))
    }

    func testOperationVerifierPartialPass() {
        var verifier = OperationVerifier()

        verifier.addRecord(OperationVerifier.VerificationRecord(
            operationDescription: "打开应用", method: .stateChange, expectedResult: "应用运行", passed: true
        ))
        verifier.addRecord(OperationVerifier.VerificationRecord(
            operationDescription: "输入文字", method: .textContains, expectedResult: "文字显示", passed: false
        ))

        XCTAssertFalse(verifier.allPassed)
        XCTAssertEqual(verifier.passRate, 0.5)
        XCTAssertEqual(verifier.lastRecord?.operationDescription, "输入文字")
    }

    // MARK: - 风险级别

    func testActionRiskLevelOrdering() {
        XCTAssertLessThan(ActionRiskLevel.readOnly, .reversibleInput)
        XCTAssertLessThan(ActionRiskLevel.reversibleInput, .persistentOrExternal)
        XCTAssertLessThan(ActionRiskLevel.persistentOrExternal, .destructiveOrSensitive)
    }

    func testActionRiskLevelTitles() {
        XCTAssertEqual(ActionRiskLevel.readOnly.title, "只读")
        XCTAssertEqual(ActionRiskLevel.destructiveOrSensitive.title, "破坏性或敏感")
    }

    // MARK: - MacAction 风险关联

    func testClickActionLowRisk() {
        let action = MockActionScenario.click(at: CGPoint(x: 100, y: 100), risk: .readOnly)
        XCTAssertEqual(action.riskLevel, .readOnly)
        XCTAssertEqual(action.humanPreview, "点击 (100, 100)")
    }

    func testCloseWindowHighRisk() {
        let action = MockActionScenario.closeWindow(risk: .destructiveOrSensitive)
        XCTAssertEqual(action.riskLevel, .destructiveOrSensitive)
    }

    func testOpenAppMediumRisk() {
        let action = MockActionScenario.openApp("Terminal")
        XCTAssertEqual(action.riskLevel, .persistentOrExternal)
    }

    // MARK: - 数据脱敏

    func testDataMaskingInitialState() {
        let engine = DataMaskingEngine()
        XCTAssertTrue(engine.isEnabled)
        XCTAssertFalse(engine.enabledCategories.isEmpty)
    }

    func testDataMaskingEmail() {
        var engine = DataMaskingEngine()
        let masked = engine.mask("请联系 support@example.com 获取帮助")
        XCTAssertTrue(masked.contains("***@example.com") || !masked.contains("support@example.com"),
                      "邮箱应被脱敏")
        XCTAssertGreaterThan(engine.lastMaskedCount, 0)
    }

    func testDataMaskingPhone() {
        var engine = DataMaskingEngine()
        let masked = engine.mask("电话 13800138000")
        XCTAssertTrue(masked.contains("138****8000") || !masked.contains("13800138000"),
                      "手机号应被部分脱敏")
    }

    func testDataMaskingDisabled() {
        var engine = DataMaskingEngine(isEnabled: false)
        let original = "邮箱 test@test.com"
        let masked = engine.mask(original)
        XCTAssertEqual(masked, original, "禁用时不应脱敏")
        XCTAssertEqual(engine.lastMaskedCount, 0)
    }

    func testDataMaskingSensitiveKeys() {
        var engine = DataMaskingEngine()
        let dict = ["apiKey": "sk-1234567890abcdef", "name": "张三"]
        let masked = engine.maskSensitiveKeys(in: dict)
        XCTAssertNotEqual(masked["apiKey"], dict["apiKey"], "apiKey 应被脱敏")
        XCTAssertEqual(masked["name"], dict["name"], "普通 key 不应被脱敏")
    }

    // MARK: - 决策选项

    func testDecisionOptionRecommended() {
        let option = DecisionPointConfirmation.DecisionOption(
            label: "推荐方案",
            description: "这是推荐的操作",
            riskLevel: "low",
            isRecommended: true
        )
        XCTAssertTrue(option.isRecommended)
        XCTAssertEqual(option.label, "推荐方案")
    }
}
