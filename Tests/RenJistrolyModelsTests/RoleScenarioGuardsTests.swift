import Foundation
import XCTest
import RenJistrolyModels

// MARK: - Finance Scenario Guard Tests (436-445)

// 436. OCR 数字校验和纠错
func testOCRDigitValidatorCorrectsCommonMistakes() {
    var validator = OCRDigitValidator(rawText: "O1Z3S8")
    validator.validate()
    let corrected = validator.correctedText
    let corrections = validator.corrections
    let isValid = validator.isValid
    XCTAssertTrue(corrected == "012358")
    XCTAssertFalse(corrections.isEmpty)
    XCTAssertTrue(isValid)
}

func testOCRDigitValidatorLowConfidence() {
    var validator = OCRDigitValidator(rawText: "HelloWorld")
    validator.validate()
    XCTAssertTrue(validator.confidence < 0.7)
    XCTAssertFalse(validator.isValid)
}

func testOCRDigitValidatorPureDigits() {
    var validator = OCRDigitValidator(rawText: "12345.67")
    validator.validate()
    XCTAssertTrue(validator.correctedText == "12345.67")
    XCTAssertTrue(validator.isValid)
}

// 437. 金额验证
func testAmountValidatorWithinRange() {
    let v = AmountValidator(detectedAmount: 500, expectedRange: 0...1000)
    XCTAssertTrue(v.isInRange)
}

func testAmountValidatorOutOfRange() {
    let v = AmountValidator(detectedAmount: 1500, expectedRange: 0...1000)
    XCTAssertFalse(v.isInRange)
}

func testAmountValidatorCustomCurrency() {
    let v = AmountValidator(detectedAmount: 100, expectedRange: 50...200, currency: "USD")
    XCTAssertTrue(v.formatted().contains("USD"))
}

// 438. 敏感数据保护
func testSensitiveDataProtectorDetectsCreditCard() {
    var protector = SensitiveDataProtector()
    protector.analyze("卡号: 6222021234561234")
    let types = protector.detectedTypes
    XCTAssertTrue(types.contains(.creditCard))
}

func testSensitiveDataProtectorDetectsPhone() {
    var protector = SensitiveDataProtector()
    protector.analyze("手机号: 13800138000")
    XCTAssertTrue(protector.detectedTypes.contains(.phoneNumber))
}

func testSensitiveDataProtectorRedacted() {
    var protector = SensitiveDataProtector()
    protector.analyze("********")
    XCTAssertTrue(protector.isProtected)
}

// 439. 付款审批流
func testPaymentApprovalFlowSmallAmount() {
    let flow = PaymentApprovalFlow(amount: 500)
    XCTAssertTrue(flow.requiredLevel == .under1000)
    XCTAssertFalse(flow.requiresDoubleConfirmation)
}

func testPaymentApprovalFlowLargeAmountNeedsMoreApprovals() {
    let flow = PaymentApprovalFlow(amount: 50000)
    XCTAssertTrue(flow.requiredLevel == .under100000)
    XCTAssertTrue(flow.requiresDoubleConfirmation)
    XCTAssertTrue(flow.needsMoreApprovals)
}

func testPaymentApprovalFlowAbove100k() {
    let flow = PaymentApprovalFlow(amount: 500000)
    XCTAssertTrue(flow.requiredLevel == .above100000)
}

// 440. Excel 公式感知
func testExcelFormulaAwarenessDetectsFormulas() {
    var awareness = ExcelFormulaAwareness()
    awareness.analyze("=SUM(A1:A10) + =IF(B1>0, B1, 0)")
    let formulas = awareness.detectedFormulas
    XCTAssertTrue(awareness.hasDetectedFormulas)
    XCTAssertTrue(formulas.contains("=SUM("))
    XCTAssertTrue(formulas.contains("=IF("))
}

func testExcelFormulaAwarenessEmpty() {
    var awareness = ExcelFormulaAwareness()
    awareness.analyze("Plain text without formulas")
    XCTAssertFalse(awareness.hasDetectedFormulas)
    XCTAssertTrue(awareness.formulaCount == 0)
}

// 441. Excel 格式保护
func testExcelFormatProtectorPreservesFormat() {
    var protector = ExcelFormatProtector()
    protector.preserveFormat(cell: "A1", format: "#,##0.00")
    XCTAssertTrue(protector.protectedFormats.contains("A1"))
}

func testExcelFormatProtectorDetectsChange() {
    var protector = ExcelFormatProtector()
    protector.preserveFormat(cell: "B2", format: "YYYY-MM-DD")
    let changed = protector.formatChanged(cell: "B2", newFormat: "DD/MM/YYYY")
    let unchanged = protector.formatChanged(cell: "C3", newFormat: "text")
    XCTAssertTrue(changed)
    XCTAssertFalse(unchanged)
}

// 442. 税务信息隔离
func testTaxInfoIsolatorClassifiesTaxData() {
    var isolator = TaxInfoIsolator()
    isolator.classify("今年的个人所得税申报")
    XCTAssertTrue(isolator.isTaxData)
    XCTAssertTrue(isolator.isolationLevel == .masked)
}

func testTaxInfoIsolatorSharing() {
    var isolator = TaxInfoIsolator(allowedRecipients: ["财务部", "税务师"])
    isolator.classify("增值税发票数据")
    XCTAssertTrue(isolator.canShare(with: "财务部张三"))
    XCTAssertTrue(!isolator.canShare(with: "外部人员"))
}

// 443. 敏感剪贴板管理
func testSensitiveClipboardManagerDetectsAccount() {
    var manager = SensitiveClipboardManager()
    manager.classify("6222021234561234")
    XCTAssertTrue(manager.isSensitive)
    XCTAssertTrue(manager.lastCopyContentType == .accountNumber)
}

func testSensitiveClipboardManagerNormal() {
    var manager = SensitiveClipboardManager()
    manager.classify("你好世界")
    XCTAssertFalse(manager.isSensitive)
    XCTAssertTrue(manager.lastCopyContentType == .normal)
}

func testSensitiveClipboardManagerWarning() {
    let manager = SensitiveClipboardManager(isSensitive: true, autoClearAfter: 30)
    let warning = manager.warningMessage
    XCTAssertTrue(warning != nil)
}

// 444. 对账误差阈值
func testReconciliationWithinThreshold() {
    let r = ReconciliationErrorThreshold(expectedAmount: 1000, actualAmount: 1000.005, threshold: 0.01)
    XCTAssertTrue(r.isWithinThreshold)
}

func testReconciliationOutOfThreshold() {
    let r = ReconciliationErrorThreshold(expectedAmount: 1000, actualAmount: 1050, threshold: 0.01)
    XCTAssertFalse(r.isWithinThreshold)
}

func testReconciliationDeviationPercent() {
    let r = ReconciliationErrorThreshold(expectedAmount: 1000, actualAmount: 1100, threshold: 0.01)
    XCTAssertTrue(r.deviationPercent == 10.0)
}

// 445. 表单提交确认
func testFormSubmitConfirmationNeedsConfirm() {
    let form = FormSubmitConfirmation(fieldCount: 5, requiresFinalCheck: true)
    XCTAssertFalse(form.isConfirmed)
    XCTAssertTrue(form.summary.contains("等待最终确认"))
}

func testFormSubmitConfirmationConfirmed() {
    let form = FormSubmitConfirmation(fieldCount: 5, requiresFinalCheck: true, isConfirmed: true)
    XCTAssertTrue(form.isConfirmed)
}

// MARK: - HR Scenario Guard Tests (446-455)

// 446. 简历数据脱敏
func testResumeDataMaskerMasksPhone() {
    let masked = ResumeDataMasker.mask("手机: 13800138000", fields: [.phone])
    XCTAssertTrue(masked == "手机: 1**********")
}

func testResumeDataMaskerMasksEmail() {
    let masked = ResumeDataMasker.mask("邮箱: test@example.com", fields: [.email])
    XCTAssertTrue(masked.contains("***@***.***"))
}

func testResumeDataMaskerAllFields() {
    var masker = ResumeDataMasker(maskedFields: [])
    let masked = masker.applyMask(to: "张三 13800138000 test@mail.com")
    XCTAssertTrue(masker.isMasked)
    XCTAssertTrue(masked.contains("1**********"))
}

// 447. Offer 薪资验证
func testOfferSalaryValidatorWithinBand() {
    let v = OfferSalaryValidator(baseSalary: 15000, bandMin: 10000, bandMax: 20000)
    XCTAssertTrue(v.isWithinBand)
}

func testOfferSalaryValidatorOutOfBand() {
    let v = OfferSalaryValidator(baseSalary: 25000, bandMin: 10000, bandMax: 20000)
    XCTAssertFalse(v.isWithinBand)
}

func testOfferSalaryValidatorTotalCompensation() {
    let v = OfferSalaryValidator(baseSalary: 20000, bandMin: 15000, bandMax: 25000, bonusPercent: 20)
    XCTAssertTrue(v.totalCompensation == 24000)
}

// 448. 候选人确认
func testCandidateConfirmerNeedsConfirmation() {
    let c = CandidateConfirmer(candidateName: "张三", position: "高级工程师")
    XCTAssertTrue(c.needsConfirmation)
}

func testCandidateConfirmerConfirmed() {
    let c = CandidateConfirmer(candidateName: "张三", position: "高级工程师", confirmedBy: ["HR"], isConfirmed: true)
    XCTAssertFalse(c.needsConfirmation)
}

// 449. HR 权限边界
func testHRPermissionBoundaryAllowsDefault() {
    let boundary = HRPermissionBoundary()
    XCTAssertTrue(boundary.canPerform(.viewPersonalInfo))
    XCTAssertTrue(boundary.canPerform(.editSalary))
}

func testHRPermissionBoundaryRestricts() {
    let boundary = HRPermissionBoundary(restrictedOperations: [.editSalary, .terminateEmployee])
    XCTAssertTrue(!boundary.canPerform(.editSalary))
    XCTAssertTrue(!boundary.canPerform(.terminateEmployee))
    XCTAssertTrue(boundary.canPerform(.viewPersonalInfo))
}

// 450. 合规语气检查
func testComplianceToneCheckerDetectsIssues() {
    var checker = ComplianceToneChecker()
    checker.analyze("你总是这么不负责任，太差了")
    let issues = checker.detectedIssues
    XCTAssertFalse(checker.isCompliant)
    XCTAssertTrue(issues.contains { $0.phrase == "你总是" })
    XCTAssertTrue(issues.contains { $0.phrase == "太差了" })
}

func testComplianceToneCheckerClean() {
    var checker = ComplianceToneChecker()
    checker.analyze("建议改进一下这个流程")
    XCTAssertTrue(checker.isCompliant)
}

// 451. 离职流程风控
func testResignationRiskControllerProgress() {
    var rc = ResignationRiskController(riskLevel: .medium)
    rc.completedSteps = ["离职面谈", "资产归还"]
    XCTAssertTrue(rc.progress == 0.25)
    XCTAssertFalse(rc.isComplete)
}

func testResignationRiskControllerCriticalWarning() {
    let rc = ResignationRiskController(riskLevel: .critical)
    XCTAssertTrue(rc.warningMessage != nil)
}

// 452. 隐私边界
func testPrivacyBoundaryGuardDetectsPII() {
    var guard_ = PrivacyBoundaryGuard()
    let hasPII = guard_.analyze("查看张三的薪资和绩效评估", purpose: "HR审批")
    let pii = guard_.detectedPII
    XCTAssertTrue(hasPII)
    XCTAssertTrue(pii.contains(.salaryInfo))
    XCTAssertTrue(pii.contains(.performanceReview))
}

// 453. 合同审查流程
func testContractReviewFlowNeedsReview() {
    let flow = ContractReviewFlow(requiresLegalReview: true)
    XCTAssertFalse(flow.canProceed)
}

func testContractReviewFlowCompleted() {
    let flow = ContractReviewFlow(requiresLegalReview: true, legalReviewCompleted: true)
    XCTAssertTrue(flow.canProceed)
}

func testContractReviewFlowNoReviewNeeded() {
    let flow = ContractReviewFlow(requiresLegalReview: false)
    XCTAssertTrue(flow.canProceed)
}

// 454. 批量发送确认
func testBatchSendConfirmerProgress() {
    var bc = BatchSendConfirmer(totalRecipients: 10)
    bc.confirmedRecipients = Array(repeating: "a", count: 5)
    XCTAssertTrue(bc.progress == 0.5)
}

func testBatchSendConfirmerWarning() {
    let bc = BatchSendConfirmer(totalRecipients: 20)
    XCTAssertTrue(bc.warningMessage != nil)
}

func testBatchSendConfirmerAllConfirmed() {
    var bc = BatchSendConfirmer(totalRecipients: 3)
    bc.confirmedRecipients = ["a", "b", "c"]
    XCTAssertTrue(bc.allConfirmed)
}

// 455. 字段验证
func testFieldValidatorRequired() {
    let fieldName = "姓名"
    var v = FieldValidator(fieldRules: [fieldName: .init(required: true)])
    let emptyResult = v.validate(field: fieldName, value: "")
    let filledResult = v.validate(field: fieldName, value: "张三")
    XCTAssertFalse(emptyResult)
    XCTAssertTrue(filledResult)
}

func testFieldValidatorMinLength() {
    let fieldName = "密码"
    var v = FieldValidator(fieldRules: [fieldName: .init(minLength: 6)])
    let shortResult = v.validate(field: fieldName, value: "123")
    let longResult = v.validate(field: fieldName, value: "123456")
    XCTAssertFalse(shortResult)
    XCTAssertTrue(longResult)
}

func testFieldValidatorPattern() {
    let fieldName = "邮箱"
    var v = FieldValidator(fieldRules: [fieldName: .init(pattern: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")])
    let invalidResult = v.validate(field: fieldName, value: "invalid")
    let validResult = v.validate(field: fieldName, value: "test@example.com")
    XCTAssertFalse(invalidResult)
    XCTAssertTrue(validResult)
}

// MARK: - Manager Scenario Guard Tests (456-465)

// 456. 进度真实性
func testProgressAuthenticityCheckerAuthentic() {
    let pc = ProgressAuthenticityChecker(reportedProgress: 50, actualProgress: 48)
    XCTAssertTrue(pc.isAuthentic)
}

func testProgressAuthenticityCheckerWarning() {
    let pc = ProgressAuthenticityChecker(reportedProgress: 80, actualProgress: 50)
    XCTAssertFalse(pc.isAuthentic)
    XCTAssertTrue(pc.warningMessage != nil)
}

// 457. 图表趋势解读
func testChartTrendInterpreterUpward() {
    var interpreter = ChartTrendInterpreter(dataPoints: [
        .init(label: "Jan", value: 10),
        .init(label: "Feb", value: 20),
        .init(label: "Mar", value: 35),
        .init(label: "Apr", value: 50),
    ])
    interpreter.analyze()
    XCTAssertTrue(interpreter.detectedTrend == .upward)
}

func testChartTrendInterpreterStable() {
    var interpreter = ChartTrendInterpreter(dataPoints: [
        .init(label: "Jan", value: 100),
        .init(label: "Feb", value: 101),
    ])
    interpreter.analyze()
    XCTAssertTrue(interpreter.detectedTrend == .stable)
}

func testChartTrendInterpreterNotEnoughData() {
    var interpreter = ChartTrendInterpreter(dataPoints: [.init(label: "Only", value: 42)])
    interpreter.analyze()
    XCTAssertTrue(interpreter.confidence == 0)
}

// 458. 周报引用溯源
func testWeeklyReportCitationTracer() {
    let tracer = WeeklyReportCitationTracer(citations: [
        .init(claim: "销售额增长20%", source: "Q2财报", isVerified: true),
        .init(claim: "用户数突破100万", source: "数据分析平台"),
    ])
    XCTAssertTrue(tracer.verifiedCount == 1)
    XCTAssertTrue(tracer.unverifiedCount == 1)
    XCTAssertFalse(tracer.isVerified)
}

// 459. 会议冲突检测
func testMeetingConflictDetectorNoConflicts() {
    let now = Date()
    let detector = MeetingConflictDetector(meetings: [
        .init(title: "早会", startTime: now, endTime: now.addingTimeInterval(3600)),
        .init(title: "评审", startTime: now.addingTimeInterval(7200), endTime: now.addingTimeInterval(10800)),
    ])
    var d = detector
    d.detect()
    XCTAssertFalse(d.hasConflicts)
}

func testMeetingConflictDetectorTimeOverlap() {
    let now = Date()
    var detector = MeetingConflictDetector(meetings: [
        .init(title: "早会", startTime: now, endTime: now.addingTimeInterval(3600)),
        .init(title: "冲突会议", startTime: now.addingTimeInterval(1800), endTime: now.addingTimeInterval(5400)),
    ])
    detector.detect()
    XCTAssertTrue(detector.hasConflicts)
}

// 460. 收件人确认
func testRecipientConfirmerAllConfirmed() {
    var rc = RecipientConfirmer(recipients: ["a@co.com", "b@co.com"])
    rc.confirmed = ["a@co.com", "b@co.com"]
    XCTAssertTrue(rc.allConfirmed)
}

func testRecipientConfirmerSuspicious() {
    var rc = RecipientConfirmer()
    rc.checkSuspicious("test@example.com")
    XCTAssertFalse(rc.suspiciousRecipients.isEmpty)
}

func testRecipientConfirmerWarning() {
    let rc = RecipientConfirmer(recipients: ["a@co.com", "b@co.com"], confirmed: ["a@co.com"])
    let warning = rc.warningMessage
    XCTAssertTrue(warning != nil)
}

// 461. 风险历史
func testRiskHistoryTrackerNoUnresolved() {
    let tracker = RiskHistoryTracker(previousRisks: [
        .init(title: "服务器宕机", severity: .high, status: .closed)
    ])
    XCTAssertFalse(tracker.hasUnresolvedRisks)
}

func testRiskHistoryTrackerHasUnresolved() {
    let tracker = RiskHistoryTracker(previousRisks: [
        .init(title: "安全漏洞", severity: .critical, status: .open)
    ])
    XCTAssertTrue(tracker.hasUnresolvedRisks)
    XCTAssertTrue(tracker.historicalContext.contains("未关闭"))
}

// 462. 决策记录
func testDecisionRecorderFindRelated() {
    let recorder = DecisionRecorder(decisions: [
        .init(title: "选择云服务商", context: "对比AWS/Azure/GCP", options: ["AWS", "Azure"], selectedOption: "AWS", rationale: "成本最优", decidedBy: "CTO"),
        .init(title: "技术栈选型", context: "前端框架", options: ["React", "Vue"], selectedOption: "React", rationale: "生态成熟", decidedBy: "技术委员会"),
    ])
    let related = recorder.findRelated(to: "云服务")
    XCTAssertTrue(related.count == 1)
    XCTAssertTrue(related[0].title == "选择云服务商")
}

// 463. 审批权限
func testApprovalPermissionModelCanApprove() {
    let model = ApprovalPermissionModel(currentApprover: "经理", requiredLevel: 3)
    XCTAssertTrue(model.canApprove)
}

func testApprovalPermissionModelCannotApprove() {
    let model = ApprovalPermissionModel(currentApprover: "员工", requiredLevel: 3)
    XCTAssertFalse(model.canApprove)
}

func testApprovalPermissionModelNeedsHigher() {
    let model = ApprovalPermissionModel(currentApprover: "主管")
    let (needs, role) = model.needsHigherApproval(for: 50000)
    XCTAssertTrue(needs)
    XCTAssertTrue(role == "总监")
}

// 464. 预算数据保护
func testBudgetDataProtectorClassifiesBudget() {
    var protector = BudgetDataProtector()
    protector.classify("查看2025年预算报告")
    XCTAssertTrue(protector.isBudgedData)
    XCTAssertTrue(protector.protectionLevel == .confidential)
}

func testBudgetDataProtectorViewerAccess() {
    var protector = BudgetDataProtector(allowedViewers: ["财务部", "CEO"])
    protector.classify("预算审批")
    XCTAssertTrue(protector.canView("财务部张三"))
    XCTAssertTrue(!protector.canView("实习生"))
}

// 465. 措辞合规检查
func testWordingComplianceCheckerDiscriminatory() {
    var checker = WordingComplianceChecker()
    checker.analyze("这个团队所有人都很无能")
    let issues = checker.detectedIssues
    XCTAssertFalse(checker.isCompliant)
    XCTAssertTrue(issues.contains { $0.category == .discriminatory })
    XCTAssertTrue(issues.contains { $0.category == .inflammatory })
}

func testWordingComplianceCheckerClean() {
    var checker = WordingComplianceChecker()
    checker.analyze("建议优化该流程以提高效率")
    XCTAssertTrue(checker.isCompliant)
}

func testWordingComplianceCheckerMultipleIssues() {
    var checker = WordingComplianceChecker()
    checker.analyze("你从来没有负责任过，最差的员工")
    let issues = checker.detectedIssues
    XCTAssertTrue(issues.count >= 2)
}
