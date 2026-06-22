import XCTest
import Foundation
@testable import RenJistrolyModels

// =============================================================================
// 客服场景模型测试 (406-415)
// =============================================================================

final class BusinessScenarioModelsTests: XCTestCase {
        func testCreateSessionContext() {
            let ctx = SessionContext(
                customerID: "C001",
                customerName: "张三",
                channel: "chat",
                ticketID: "TKT-001",
                stage: .inquiry
            )
            XCTAssertTrue(ctx.sessionID.isEmpty == false)
            XCTAssertTrue(ctx.customerID == "C001")
            XCTAssertTrue(ctx.customerName == "张三")
            XCTAssertTrue(ctx.stage == .inquiry)
            XCTAssertTrue(ctx.contextVariables.isEmpty)
        }

        func testContextVariables() {
            var ctx = SessionContext(customerID: "C001", channel: "wechat")
            ctx.contextVariables["product"] = "iPhone 15"
            ctx.contextVariables["orderID"] = "ORD-123"
            XCTAssertTrue(ctx.contextVariables.count == 2)
        }

        func testSentimentCreation() {
            let result = SentimentResult(
                overall: .angry,
                intensity: 0.85,
                anger: 0.7,
                frustration: 0.8
            )
            XCTAssertTrue(result.requiresPriorityHandling)
            XCTAssertTrue(result.summary.contains("需要优先处理"))
        }

        func testPriorityDetection() {
            let low = SentimentResult(overall: .negative, intensity: 0.3)
            XCTAssertFalse(low.requiresPriorityHandling)

            let high = SentimentResult(overall: .angry, intensity: 0.8, anger: 0.6)
            XCTAssertTrue(high.requiresPriorityHandling)
        }

        func testIsolationCreation() {
            let state = ContextIsolationState(
                activeTicketID: "TKT-001",
                isolatedContext: ["customerName": "李四"],
                previousTicketIDs: ["TKT-000"]
            )
            XCTAssertTrue(state.activeTicketID == "TKT-001")
            XCTAssertTrue(state.previousTicketIDs.count == 1)
        }

        func testAuditRecord() {
            let record = CRMAuditRecord(
                field: "customer_name",
                oldValue: "张三",
                newValue: "张四",
                reason: "客户更新姓名"
            )
            XCTAssertFalse(record.isRolledBack)
            XCTAssertTrue(record.field == "customer_name")
        }

        func testAuditRollback() {
            let record = CRMAuditRecord(
                id: UUID(),
                timestamp: Date(),
                field: "email",
                oldValue: "old@test.com",
                newValue: "new@test.com",
                reason: "邮箱更新",
                isRolledBack: true
            )
            XCTAssertTrue(record.isRolledBack)
        }

        func testLowRiskRefund() {
            let assessment = RefundRiskAssessment.assess(
                amount: 50,
                customerHistoryDays: 365,
                previousRefunds: 0
            )
            XCTAssertTrue(assessment.riskLevel == .low)
            XCTAssertFalse(assessment.riskLevel.requiresManualReview)
        }

        func testHighRiskRefund() {
            let assessment = RefundRiskAssessment.assess(
                amount: 60000,
                customerHistoryDays: 10,
                previousRefunds: 5
            )
            XCTAssertTrue(assessment.riskLevel >= .high)
            XCTAssertTrue(assessment.riskLevel.requiresManualReview)
            XCTAssertFalse(assessment.flags.isEmpty)
        }

        func testFrequentRefundFlags() {
            let assessment = RefundRiskAssessment.assess(
                amount: 20000,
                customerHistoryDays: 60,
                previousRefunds: 6
            )
            XCTAssertTrue(assessment.flags.contains("极高退款频率"))
        }

    // =============================================================================
    // 销售场景模型测试 (416-425)
    // =============================================================================

        func testDefaultStages() {
            let prospecting = SalesStageContext.defaultForStage(.prospecting)
            XCTAssertTrue(prospecting.probability == 10)
            XCTAssertTrue(prospecting.allows(action: "search"))
            XCTAssertTrue(!prospecting.allows(action: "generate_quote"))

            let negotiation = SalesStageContext.defaultForStage(.negotiation)
            XCTAssertTrue(negotiation.probability == 70)
            XCTAssertTrue(negotiation.allows(action: "modify_amount"))
            XCTAssertTrue(negotiation.requiredDocuments.contains("contract_template"))
        }

        func testDisallowedAction() {
            let stage = SalesStageContext.defaultForStage(.prospecting)
            XCTAssertTrue(!stage.allows(action: "send_email"))
        }

        func testChangePercent() {
            let req = AmountChangeRequest(
                entityID: "OPP-001",
                entityType: "opportunity",
                oldAmount: 100000,
                newAmount: 150000,
                reason: "增加服务范围"
            )
            XCTAssertTrue(req.changePercent == 50)
        }

        func testZeroOldAmount() {
            let req = AmountChangeRequest(
                entityID: "OPP-001",
                entityType: "opportunity",
                oldAmount: 0,
                newAmount: 50000,
                reason: "新报价"
            )
            XCTAssertTrue(req.changePercent == 100)
        }

        func testTemplateMatching() {
            let template = QuoteTemplate(
                name: "标准报价",
                applicableStages: [.proposal, .negotiation],
                minAmount: 0,
                maxAmount: 100000,
                requiredClauses: ["价格条款"]
            )
            XCTAssertTrue(template.matches(amount: 50000, stage: .proposal))
            XCTAssertTrue(!template.matches(amount: 200000, stage: .proposal))
            XCTAssertTrue(!template.matches(amount: 50000, stage: .prospecting))
        }

        func testApprovalChain() {
            let flow = ContractApprovalFlow.generateChain(amount: 200000, contractID: "CT-001")
            XCTAssertTrue(flow.status == .pending)
            XCTAssertTrue(flow.approvalChain.count >= 2) // sales supervisor + director
        }

        func testLargeContractChain() {
            let flow = ContractApprovalFlow.generateChain(amount: 2000000, contractID: "CT-002")
            XCTAssertTrue(flow.approvalChain.count >= 4) // all levels
        }

        func testCreateReminder() {
            let reminder = ReminderItem(
                title: "跟进客户",
                description: "发送报价单",
                dueDate: Date().addingTimeInterval(86400),
                priority: .high,
                context: .init(relatedEntityID: "OPP-001", customerName: "王五")
            )
            XCTAssertFalse(reminder.isCompleted)
            XCTAssertTrue(reminder.priority == .high)
        }

        func testPriorityComparison() {
            XCTAssertTrue(ReminderItem.ReminderPriority.low < .high)
            XCTAssertTrue(ReminderItem.ReminderPriority.urgent > .medium)
        }

    // =============================================================================
    // 运营场景模型测试 (426-435)
    // =============================================================================

        func testPhoneMasking() {
            let rule = DataExportMaskingRule(fieldName: "电话", maskingType: .phoneMask)
            XCTAssertTrue(rule.apply(to: "13812345678") == "138****5678")
            XCTAssertTrue(rule.apply(to: "12345") == "*****")
        }

        func testEmailMasking() {
            let rule = DataExportMaskingRule(fieldName: "邮箱", maskingType: .emailMask)
            XCTAssertTrue(rule.apply(to: "zhangsan@test.com") == "zh******@test.com")
        }

        func testIDMasking() {
            let rule = DataExportMaskingRule(fieldName: "身份证", maskingType: .idMask)
            XCTAssertTrue(rule.apply(to: "110101199001011234") == "1****************4")
        }

        func testEmptyCSV() {
            let result = CSVValidationResult.validate(csvContent: "", expectedColumns: ["姓名", "电话"])
            XCTAssertFalse(result.isValid)
            XCTAssertTrue(result.rowCount == 0)
        }

        func testValidCSV() throws {
            let csv = "姓名,电话,邮箱\n张三,13800138000,zhang@test.com\n李四,13900139000,li@test.com"
            let result = CSVValidationResult.validate(csvContent: csv, expectedColumns: ["姓名", "电话"])
            XCTAssertTrue(result.isValid)
            XCTAssertTrue(result.rowCount == 2)
            XCTAssertTrue(result.columnCount == 3)
        }

        func testMissingColumns() {
            let csv = "姓名,电话\n张三,13800138000"
            let result = CSVValidationResult.validate(csvContent: csv, expectedColumns: ["姓名", "邮箱"])
            XCTAssertFalse(result.isValid)
            XCTAssertTrue(result.missingColumns.contains("邮箱"))
        }

        func testColumnMismatch() {
            let csv = "姓名,电话,邮箱\n张三,13800138000"
            let result = CSVValidationResult.validate(csvContent: csv, expectedColumns: ["姓名", "电话"])
            XCTAssertFalse(result.isValid)
            XCTAssertFalse(result.errors.isEmpty)
        }

        func testNormalMetric() {
            let result = BaselineComparison.compute(
                metricName: "日活跃用户",
                currentValue: 10500,
                baselineValue: 10000
            )
            XCTAssertFalse(result.isAnomaly)
            XCTAssertTrue(result.deviationPercent == 5)
        }

        func testAnomalyMetric() {
            let result = BaselineComparison.compute(
                metricName: "退款率",
                currentValue: 10,
                baselineValue: 2
            )
            XCTAssertTrue(result.isAnomaly)
            XCTAssertTrue(result.deviationPercent == 400)
        }

        func testBelowThreshold() {
            let result = BaselineComparison.compute(
                metricName: "响应时间",
                currentValue: 210,
                baselineValue: 200,
                thresholdPercent: 10
            )
            XCTAssertFalse(result.isAnomaly)
        }

}