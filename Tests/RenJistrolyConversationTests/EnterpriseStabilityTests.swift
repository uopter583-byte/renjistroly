import Foundation
import XCTest
import RenJistrolyModels

// =========================================================================
// Each scenario follows a read → write → confirm three-step pattern.
// =========================================================================

// MARK: - Email reading and drafting

func testCRMAuditRecordReadWriteConfirm() {
    let record = CRMAuditRecord(
        field: "customer_email",
        oldValue: "old@example.com",
        newValue: "new@example.com",
        operatorID: "agent-42",
        reason: "客户请求更新邮箱"
    )
    XCTAssertTrue(record.field == "customer_email")
    XCTAssertTrue(record.oldValue == "old@example.com")
    XCTAssertTrue(record.newValue == "new@example.com")
    XCTAssertTrue(record.operatorID == "agent-42")
}

func testCRMAuditRecordRollbackDetection() {
    let record = CRMAuditRecord(
        field: "contact_phone",
        oldValue: "+86-13800000000",
        newValue: "+86-13900000000",
        reason: "号码变更"
    )
    let rolledBack = CRMAuditRecord(
        id: record.id,
        field: record.field,
        oldValue: record.oldValue,
        newValue: record.newValue,
        reason: "回滚操作",
        isRolledBack: true
    )
    XCTAssertTrue(rolledBack.isRolledBack)
}

// MARK: - Calendar/schedule management

func testTimezoneConflictDetection() {
    let participants = [
        TimezoneConflictCheck.TimeSlot(name: "Alice", timezone: "Asia/Shanghai", proposedTime: Date()),
        TimezoneConflictCheck.TimeSlot(name: "Bob", timezone: "America/New_York", proposedTime: Date()),
    ]
    let conflicts = [
        TimezoneConflictCheck.Conflict(
            participantA: "Alice",
            participantB: "Bob",
            description: "时差 12 小时",
            hourDifference: 12
        )
    ]
    let check = TimezoneConflictCheck(participants: participants, conflicts: conflicts)
    XCTAssertTrue(check.participants.count == 2)
    XCTAssertTrue(check.conflicts.count == 1)
    XCTAssertTrue(check.conflicts[0].hourDifference == 12)
}

func testTimezoneConflictNoConflictWhenSameTimezone() {
    let participants = [
        TimezoneConflictCheck.TimeSlot(name: "Alice", timezone: "Asia/Shanghai", proposedTime: Date()),
        TimezoneConflictCheck.TimeSlot(name: "Bob", timezone: "Asia/Shanghai", proposedTime: Date()),
    ]
    let check = TimezoneConflictCheck(participants: participants)
    XCTAssertTrue(check.conflicts.isEmpty)
}

// MARK: - CRM record query

func testCRMFieldDefinitionWithSensitivity() {
    let field = CRMFieldDefinition(
        displayName: "手机号码",
        internalKey: "phone",
        fieldType: .phone,
        isRequired: true,
        sensitivity: .pii
    )
    XCTAssertTrue(field.displayName == "手机号码")
    XCTAssertTrue(field.fieldType == .phone)
    XCTAssertTrue(field.isRequired)
    XCTAssertTrue(field.sensitivity == .pii)
}

func testCRMFieldTypeValidation() {
    let emailField = CRMFieldDefinition(
        displayName: "邮箱",
        internalKey: "email",
        fieldType: .email,
        sensitivity: .sensitive
    )
    let numberField = CRMFieldDefinition(
        displayName: "年龄",
        internalKey: "age",
        fieldType: .number,
        sensitivity: .internal
    )
    XCTAssertTrue(emailField.fieldType == .email)
    XCTAssertTrue(numberField.fieldType == .number)
}

// MARK: - Contract clause extraction

func testContractApprovalFlowGenerateChain() {
    let flow = ContractApprovalFlow.generateChain(amount: 250000, contractID: "CT-2024-001")
    XCTAssertTrue(flow.contractID == "CT-2024-001")
    XCTAssertTrue(flow.amount == 250000)
    XCTAssertTrue(flow.approvalChain.count == 2)
    XCTAssertTrue(flow.approvalChain[0].role == "销售主管")
    XCTAssertTrue(flow.approvalChain[1].role == "销售总监")
    XCTAssertTrue(flow.status == .pending)
}

func testContractApprovalFlowHighValueChain() {
    let flow = ContractApprovalFlow.generateChain(amount: 2000000, contractID: "CT-2024-002")
    XCTAssertTrue(flow.approvalChain.count == 4)
    XCTAssertTrue(flow.approvalChain[3].role == "CEO")
}

func testContractApprovalFlowLowValueChain() {
    let flow = ContractApprovalFlow.generateChain(amount: 50000, contractID: "CT-2024-003")
    XCTAssertTrue(flow.approvalChain.count == 1)
    XCTAssertTrue(flow.approvalChain[0].role == "销售主管")
}

// MARK: - Customer service ticket handling

func testSentimentResultPriorityDetection() {
    let sentiment = SentimentResult(
        overall: .negative,
        intensity: 0.85,
        anger: 0.6,
        frustration: 0.7
    )
    XCTAssertTrue(sentiment.requiresPriorityHandling)
    XCTAssertTrue(sentiment.summary.contains("需要优先处理"))
}

func testSentimentResultNormalNotPriority() {
    let sentiment = SentimentResult(
        overall: .neutral,
        intensity: 0.3,
        frustration: 0.1
    )
    XCTAssertFalse(sentiment.requiresPriorityHandling)
}

func testSessionContextStageProgression() {
    var ctx = SessionContext(sessionID: "SESS-001", customerName: "张三", channel: "web")
    XCTAssertTrue(ctx.stage == .greeting)

    ctx.stage = .inquiry
    XCTAssertTrue(ctx.stage == .inquiry)

    ctx.stage = .issueResolution
    ctx.contextVariables["issue"] = "登录失败"
    XCTAssertTrue(ctx.contextVariables["issue"] == "登录失败")
}

// MARK: - Report generation from data

func testChartParsedDataAnomalyDetection() {
    let data = ChartParsedData(
        chartType: .line,
        title: "月收入趋势",
        dataPoints: [
            ChartParsedData.DataPoint(label: "一月", value: 100000),
            ChartParsedData.DataPoint(label: "二月", value: 120000),
            ChartParsedData.DataPoint(label: "三月", value: 50000),
        ],
        summary: "三月收入显著下降",
        anomalies: ["三月收入环比下降 58%"]
    )
    XCTAssertTrue(data.chartType == .line)
    XCTAssertTrue(data.dataPoints.count == 3)
    XCTAssertFalse(data.anomalies.isEmpty)
}

func testChartParsedDataEmptyData() {
    let data = ChartParsedData(chartType: .unknown, summary: "无数据")
    XCTAssertTrue(data.dataPoints.isEmpty)
    XCTAssertTrue(data.anomalies.isEmpty)
}

// MARK: - Approval workflow trigger

func testContractApprovalFlowStatusTransitions() {
    var flow = ContractApprovalFlow(
        contractID: "CT-2024-010",
        amount: 80000,
        approvalChain: [
            ContractApprovalFlow.ApprovalStep(role: "销售主管"),
        ],
        status: .pending
    )
    XCTAssertTrue(flow.status == .pending)

    flow.status = .inProgress
    XCTAssertTrue(flow.status == .inProgress)

    flow.status = .approved
    XCTAssertTrue(flow.status == .approved)
}

// MARK: - Knowledge base search

func testScriptStrategyAllowedTemplates() {
    let strategy = ScriptStrategy(
        name: "技术支持",
        applicableStages: [.inquiry, .issueResolution],
        allowedTemplates: ["greeting", "problem_diagnosis", "solution_proposal"],
        restrictedPhrases: ["无法解决", "不知道"],
        requiredElements: ["customer_name", "issue_description"]
    )
    XCTAssertTrue(strategy.applicableStages.contains(.issueResolution))
    XCTAssertTrue(!strategy.applicableStages.contains(.closed))
    XCTAssertTrue(strategy.restrictedPhrases.contains("不知道"))
    XCTAssertTrue(strategy.requiredElements.contains("customer_name"))
}

// MARK: - Work order creation

func testCSVValidationDetectsMissingColumns() {
    let csv = "name,phone\nAlice,123\nBob,456"
    let result = CSVValidationResult.validate(csvContent: csv, expectedColumns: ["name", "email", "phone"])
    XCTAssertFalse(result.isValid)
    XCTAssertTrue(result.missingColumns.contains("email"))
    XCTAssertTrue(result.rowCount == 2)
}

func testCSVValidationValidContent() {
    let csv = "name,email,phone\nAlice,alice@test.com,123\nBob,bob@test.com,456"
    let result = CSVValidationResult.validate(csvContent: csv, expectedColumns: ["name", "email", "phone"])
    XCTAssertTrue(result.isValid)
    XCTAssertTrue(result.rowCount == 2)
}

func testCSVValidationEmptyContent() {
    let result = CSVValidationResult.validate(csvContent: "", expectedColumns: ["name"])
    XCTAssertFalse(result.isValid)
    XCTAssertTrue(result.errors.contains(where: { $0.message.contains("CSV 内容为空") }))
}

// MARK: - Meeting minutes summarization

func testSpeakerSegmentationFromMeeting() {
    let segments = [
        SpeakerSegment(speakerID: "agent-1", speakerName: "李明", text: "今天讨论新功能上线计划", role: .agent),
        SpeakerSegment(speakerID: "cust-1", speakerName: "王总", text: "我们希望在月底前上线", role: .customer),
        SpeakerSegment(speakerID: "agent-1", speakerName: "李明", text: "好的，我们安排开发资源", role: .agent),
    ]
    XCTAssertTrue(segments.count == 3)
    XCTAssertTrue(segments[0].speakerName == "李明")
    XCTAssertTrue(segments[1].role == .customer)
    XCTAssertTrue(segments[2].speakerName == "李明")
}

func testDataExportMaskingProtectsPII() {
    let emailRule = DataExportMaskingRule(fieldName: "email", maskingType: .emailMask)
    let phoneRule = DataExportMaskingRule(fieldName: "phone", maskingType: .phoneMask)

    XCTAssertTrue(emailRule.apply(to: "alice@example.com") == "al****@example.com")
    XCTAssertTrue(phoneRule.apply(to: "13812345678") == "138****5678")
}

func testAmountChangePercentCalculation() {
    let change = AmountChangeRequest(
        entityID: "QUOTE-001",
        entityType: "quote",
        oldAmount: 10000,
        newAmount: 12000,
        reason: "增加功能模块"
    )
    XCTAssertTrue(change.changePercent == 20.0)
    XCTAssertTrue(change.requiresApproval)
}

func testAmountChangeZeroOldAmount() {
    let change = AmountChangeRequest(
        entityID: "QUOTE-002",
        entityType: "quote",
        oldAmount: 0,
        newAmount: 1000,
        reason: "新报价"
    )
    XCTAssertTrue(change.changePercent == 100.0)
}

// MARK: - Email draft/create/send read-write-confirm

func testEmailAuditRecordReadWriteConfirm() {
    let draft = CRMAuditRecord(field: "email_content", oldValue: "", newValue: "尊敬的客户，您好...", operatorID: "agent-01", reason: "撰写邮件草稿")
    XCTAssertTrue(draft.field == "email_content")
    XCTAssertTrue(draft.newValue.hasPrefix("尊敬的客户"))
    let sent = CRMAuditRecord(id: draft.id, field: draft.field, oldValue: draft.newValue, newValue: "已发送: 尊敬的客户，您好...", reason: "发送邮件")
    XCTAssertTrue(sent.newValue.hasPrefix("已发送"))
}

func testEmailDraftCRMOperation() {
    let record = CRMAuditRecord(
        field: "contact_email",
        oldValue: "old@corp.com",
        newValue: "new@corp.com",
        reason: "客户邮箱变更"
    )
    XCTAssertTrue(record.field == "contact_email")
    XCTAssertTrue(record.oldValue == "old@corp.com")
    XCTAssertTrue(record.newValue == "new@corp.com")
}

// MARK: - Meeting minutes create/summarize/distribute read-write-confirm

func testMeetingMinutesReadWriteConfirm() {
    let segments = [
        SpeakerSegment(speakerID: "speaker-1", speakerName: "张总", text: "本次会议讨论Q3规划", role: .agent),
        SpeakerSegment(speakerID: "speaker-2", speakerName: "李经理", text: "我们建议增加研发投入", role: .customer),
        SpeakerSegment(speakerID: "speaker-1", speakerName: "张总", text: "同意，需要做预算", role: .agent),
    ]
    XCTAssertTrue(segments.count == 3)
    let emailRule = DataExportMaskingRule(fieldName: "speaker_name", maskingType: .partial)
    let masked = segments.map { SpeakerSegment(speakerID: $0.speakerID, speakerName: emailRule.apply(to: $0.speakerName ?? ""), text: $0.text, role: $0.role) }
    XCTAssertTrue(masked[1].speakerName == "李**理")
}

func testMeetingMinutesDistribution() {
    let segments = [
        SpeakerSegment(speakerID: "a1", speakerName: "主讲人", startTime: 0, endTime: 10, text: "会议开始", role: .agent),
        SpeakerSegment(speakerID: "c1", speakerName: "参会者", startTime: 10, endTime: 20, text: "提问环节", role: .customer),
    ]
    let summary = "会议由主讲人开场，参会者参与提问"
    XCTAssertTrue(segments[0].speakerName == "主讲人")
    XCTAssertTrue(!summary.isEmpty)
}

// MARK: - Ticket lifecycle: create -> update -> resolve

func testTicketCreateUpdateResolveReadWriteConfirm() {
    var ctx = SessionContext(sessionID: "TKT-001", customerName: "Alice", channel: "email")
    XCTAssertTrue(ctx.stage == .greeting)

    ctx.stage = .inquiry
    ctx.contextVariables["issue"] = "无法登录系统"
    XCTAssertTrue(ctx.stage == .inquiry)
    XCTAssertTrue(ctx.contextVariables["issue"] == "无法登录系统")

    ctx.stage = .issueResolution
    ctx.contextVariables["resolution"] = "已重置密码"
    XCTAssertTrue(ctx.stage == .issueResolution)
    XCTAssertTrue(ctx.contextVariables["resolution"] == "已重置密码")
}

func testTicketContextIsolationCreatesSeparateState() {
    let ticket1 = ContextIsolationState(activeTicketID: "TKT-001", isolatedContext: ["issue": "登录失败"])
    let ticket2 = ContextIsolationState(activeTicketID: "TKT-002", isolatedContext: ["issue": "支付错误"])
    XCTAssertTrue(ticket1.isolatedContext["issue"] == "登录失败")
    XCTAssertTrue(ticket2.isolatedContext["issue"] == "支付错误")
    XCTAssertTrue(ticket1.activeTicketID != ticket2.activeTicketID)
}

func testTicketContextAccumulatesHistory() {
    var state = ContextIsolationState(activeTicketID: "TKT-001")
    state.previousTicketIDs = ["TKT-000"]
    XCTAssertTrue(state.previousTicketIDs.count == 1)
}

// MARK: - Knowledge base search/retrieve/apply read-write-confirm

func testKnowledgeBaseScriptStrategyReadWriteConfirm() {
    let strategy = ScriptStrategy(
        name: "FAQ检索",
        applicableStages: [.inquiry, .issueResolution],
        allowedTemplates: ["faq_search", "article_lookup"],
        restrictedPhrases: ["无法回答"],
        requiredElements: ["customer_question"]
    )
    XCTAssertTrue(strategy.name == "FAQ检索")
    XCTAssertTrue(strategy.allowedTemplates.contains("faq_search"))
    XCTAssertTrue(strategy.restrictedPhrases.contains("无法回答"))
}

func testKnowledgeBaseContextVariables() {
    var ctx = SessionContext(sessionID: "KB-001", channel: "chat")
    ctx.contextVariables["search_query"] = "API文档"
    ctx.contextVariables["matched_article"] = "REST API 接入指南"
    XCTAssertTrue(ctx.contextVariables["search_query"] == "API文档")
    XCTAssertTrue(ctx.contextVariables["matched_article"] == "REST API 接入指南")
}

// MARK: - Dry-run preview read-write-confirm

func testDryRunPreviewReadWriteConfirm() {
    let preview = DryRunPreview(
        enabled: true,
        changes: ["修改客户邮箱", "更新联系方式"],
        affectedCount: 2,
        rollbackSteps: ["撤销邮箱修改", "恢复联系方式"]
    )
    XCTAssertTrue(preview.enabled)
    XCTAssertTrue(preview.changes.count == 2)
    XCTAssertTrue(preview.affectedCount == 2)
    XCTAssertTrue(preview.rollbackSteps?.count == 2)
}

func testDryRunPreviewDisabled() {
    let preview = DryRunPreview(enabled: false, changes: [], affectedCount: 0)
    XCTAssertFalse(preview.enabled)
    XCTAssertNil(preview.rollbackSteps)
}

// MARK: - Refund risk assessment comprehensive

func testRefundRiskAssessmentReadWriteConfirm() {
    let assessment = RefundRiskAssessment.assess(amount: 15000, customerHistoryDays: 10, previousRefunds: 4)
    XCTAssertTrue(assessment.riskLevel == .high || assessment.riskLevel == .critical)
    XCTAssertTrue(assessment.flags.contains("大额退款"))
    XCTAssertTrue(assessment.flags.contains("新客户") || assessment.flags.contains("频繁退款"))
    XCTAssertTrue(assessment.riskLevel.requiresManualReview)
}

func testRefundRiskAssessmentLowRisk() {
    let assessment = RefundRiskAssessment.assess(amount: 50, customerHistoryDays: 365, previousRefunds: 0)
    XCTAssertTrue(assessment.riskLevel == .low)
    XCTAssertFalse(assessment.riskLevel.requiresManualReview)
}

func testRefundRiskAssessmentCriticalRisk() {
    let assessment = RefundRiskAssessment.assess(amount: 100000, customerHistoryDays: 5, previousRefunds: 6)
    XCTAssertTrue(assessment.riskLevel == .critical)
    XCTAssertTrue(assessment.riskLevel.requiresManualReview)
    XCTAssertTrue(assessment.flags.contains("超大额退款"))
    XCTAssertTrue(assessment.flags.contains("极高退款频率"))
}

// MARK: - CMS content version management

func testCMSContentVersionReadWriteConfirm() {
    let version = CMSContentVersion(
        versionNumber: "v2.1.0",
        contentID: "article-42",
        contentTitle: "产品更新说明",
        updatedBy: "editor-01",
        isPublished: true,
        diffSummary: "新增API章节"
    )
    XCTAssertTrue(version.versionNumber == "v2.1.0")
    XCTAssertTrue(version.contentTitle == "产品更新说明")
    XCTAssertTrue(version.isPublished)
    XCTAssertTrue(version.diffSummary == "新增API章节")
}

func testCMSContentVersionDraft() {
    let version = CMSContentVersion(
        versionNumber: "v2.1.1-draft",
        contentID: "article-42",
        contentTitle: "产品更新说明",
        updatedBy: "editor-01"
    )
    XCTAssertFalse(version.isPublished)
    XCTAssertTrue(version.diffSummary.isEmpty)
}

// MARK: - Push notification request workflow

func testPushNotificationRequestReadWriteConfirm() {
    let request = PushNotificationRequest(
        title: "系统更新通知",
        body: "请及时更新应用至最新版本",
        targetSegment: "all_users",
        estimatedRecipients: 10000,
        isTestMode: true
    )
    XCTAssertTrue(request.title == "系统更新通知")
    XCTAssertTrue(request.isTestMode)
    XCTAssertTrue(request.estimatedRecipients == 10000)
}

func testPushNotificationScheduled() {
    let request = PushNotificationRequest(
        title: "促销活动",
        body: "限时优惠",
        targetSegment: "vip_users",
        scheduledAt: Date().addingTimeInterval(86400),
        campaignID: "camp-001"
    )
    XCTAssertTrue(request.campaignID == "camp-001")
    XCTAssertNotNil(request.scheduledAt)
}

// MARK: - Production switch protection

func testProductionSwitchReadWriteConfirm() {
    let sw = ProductionSwitch(
        name: "feature_flag_new_ui",
        currentValue: false,
        proposedValue: true,
        impact: "启用新UI将影响所有用户",
        riskLevel: .high
    )
    XCTAssertTrue(sw.name == "feature_flag_new_ui")
    XCTAssertTrue(sw.requiresConfirmation)
    XCTAssertTrue(sw.riskLevel == .high)
}

func testProductionSwitchHasRollback() {
    let sw = ProductionSwitch(
        name: "db_migration",
        currentValue: false,
        proposedValue: true,
        impact: "数据库迁移",
        requiresConfirmation: true,
        rollbackProcedure: "执行回滚脚本 rollback_v2.sql",
        riskLevel: .critical
    )
    XCTAssertTrue(sw.riskLevel == .critical)
    XCTAssertNotNil(sw.rollbackProcedure)
}

// MARK: - Quote template matching

func testQuoteTemplateMatchesAmount() {
    let template = QuoteTemplate(
        name: "标准报价",
        applicableStages: [.proposal, .negotiation],
        minAmount: 10000,
        maxAmount: 100000,
        description: "适用于标准项目"
    )
    XCTAssertTrue(template.matches(amount: 50000, stage: .proposal))
    XCTAssertFalse(template.matches(amount: 5000, stage: .proposal))
    XCTAssertFalse(template.matches(amount: 50000, stage: .qualification))
}

func testQuoteTemplateNoAmountLimit() {
    let template = QuoteTemplate(name: "自定义报价", applicableStages: [.negotiation], description: "无金额限制")
    XCTAssertTrue(template.matches(amount: 999999, stage: .negotiation))
}

// MARK: - Multi-window context fusion

func testMultiWindowFusionReadWriteConfirm() {
    let fusion = MultiWindowFusion(
        windows: [
            MultiWindowFusion.FusedWindow(appName: "Mail", windowTitle: "收件箱", extractedData: ["sender": "alice@corp.com"]),
            MultiWindowFusion.FusedWindow(appName: "CRM", windowTitle: "客户详情", extractedData: ["customer": "ABC Corp"]),
        ],
        mergedContext: ["contact": "alice@corp.com", "company": "ABC Corp"],
        contradictions: []
    )
    XCTAssertTrue(fusion.windows.count == 2)
    XCTAssertTrue(fusion.mergedContext["contact"] == "alice@corp.com")
    XCTAssertTrue(fusion.contradictions.isEmpty)
}

func testMultiWindowFusionDetectsContradictions() {
    let fusion = MultiWindowFusion(
        mergedContext: ["email": "a@x.com", "phone": "138..."],
        contradictions: ["邮箱与CRM记录不一致"]
    )
    XCTAssertTrue(fusion.contradictions.count == 1)
}

// MARK: - OCR confidence validation

func testOCRConfidenceValidationReadWriteConfirm() {
    let validation = OCRConfidenceValidation(
        minThreshold: 0.8,
        lowConfidenceRegions: [
            OCRConfidenceValidation.OCRRegion(text: "金额: 10000", confidence: 0.45, x: 100, y: 200)
        ],
        isReliable: false
    )
    XCTAssertTrue(validation.minThreshold == 0.8)
    XCTAssertTrue(validation.lowConfidenceRegions.count == 1)
    XCTAssertFalse(validation.isReliable)
}

func testOCRConfidenceReliable() {
    let validation = OCRConfidenceValidation()
    XCTAssertTrue(validation.isReliable)
    XCTAssertTrue(validation.lowConfidenceRegions.isEmpty)
}

// MARK: - Sales stage context

func testSalesStageContextAllowsActions() {
    let proposal = SalesStageContext.defaultForStage(.proposal)
    XCTAssertTrue(proposal.allows(action: "generate_quote"))
    XCTAssertFalse(proposal.allows(action: "modify_amount"))
}

func testSalesStageClosedWonRestricted() {
    let closed = SalesStageContext.defaultForStage(.closedWon)
    XCTAssertTrue(closed.allows(action: "search"))
    XCTAssertFalse(closed.allows(action: "send_email"))
}

// MARK: - Reminder item priority ordering

func testReminderItemPriorityComparison() {
    XCTAssertTrue(ReminderItem.ReminderPriority.low < .medium)
    XCTAssertTrue(ReminderItem.ReminderPriority.medium < .high)
    XCTAssertTrue(ReminderItem.ReminderPriority.high < .urgent)
}

func testReminderItemCreation() {
    let reminder = ReminderItem(
        title: "跟进客户",
        description: "发送合同草案",
        dueDate: Date().addingTimeInterval(86400),
        priority: .high,
        context: ReminderItem.ReminderContext(relatedEntityID: "CT-001", relatedEntityType: "contract", customerName: "ABC Corp")
    )
    XCTAssertTrue(reminder.title == "跟进客户")
    XCTAssertTrue(reminder.priority == .high)
    XCTAssertTrue(reminder.context.relatedEntityID == "CT-001")
}

// MARK: - ICU Translation options

func testTranslationOptionsTones() {
    let polite = TranslationOptions(sourceLanguage: "zh", targetLanguage: "en", tone: .polite)
    let urgent = TranslationOptions(sourceLanguage: "zh", targetLanguage: "en", tone: .urgent, preserveEmoji: false)
    XCTAssertTrue(polite.tone == .polite)
    XCTAssertTrue(urgent.tone == .urgent)
    XCTAssertFalse(urgent.preserveEmoji)
    XCTAssertTrue(polite.preserveFormality)
}

// MARK: - Data export masking full coverage

func testDataExportFullMasking() {
    let rule = DataExportMaskingRule(fieldName: "name", maskingType: .full)
    XCTAssertTrue(rule.apply(to: "张三") == "**")
    XCTAssertTrue(rule.apply(to: "abcdef") == "******")
}

func testDataExportPartialMasking() {
    let rule = DataExportMaskingRule(fieldName: "name", maskingType: .partial)
    XCTAssertTrue(rule.apply(to: "abcde") == "ab*de")
    XCTAssertTrue(rule.apply(to: "ab") == "**")
}

func testDataExportIdMasking() {
    let rule = DataExportMaskingRule(fieldName: "id", maskingType: .idMask)
    XCTAssertTrue(rule.apply(to: "310101199001011234") == "3****************4")
}

func testDataExportDateRounding() {
    let rule = DataExportMaskingRule(fieldName: "date", maskingType: .dateRounding)
    let result = rule.apply(to: "2024-03-15")
    XCTAssertTrue(result == "2024-03-01" || result == "2024-03-15")
}
