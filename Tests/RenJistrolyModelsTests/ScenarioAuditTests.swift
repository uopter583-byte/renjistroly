import Foundation
import XCTest
import RenJistrolyModels

// MARK: - ScenarioAuditSummary

func testScenarioAuditSummaryEmpty() {
    let summary = ScenarioAuditSummary(items: [])
    XCTAssertTrue(summary.total == 0)
    XCTAssertTrue(summary.verified == 0)
    XCTAssertTrue(summary.implemented == 0)
    XCTAssertTrue(summary.partial == 0)
    XCTAssertTrue(summary.missing == 0)
    XCTAssertTrue(summary.coveragePercent == 0)
}

func testScenarioAuditSummaryMixed() {
    let items: [ScenarioAuditItem] = [
        ScenarioAuditItem(id: "1", domain: .voiceConversation, title: "语音识别", status: .verified, evidence: "通过", nextFix: ""),
        ScenarioAuditItem(id: "2", domain: .voiceConversation, title: "TTS", status: .verified, evidence: "通过", nextFix: ""),
        ScenarioAuditItem(id: "3", domain: .appControl, title: "打开App", status: .implemented, evidence: "实现", nextFix: "增加验证"),
        ScenarioAuditItem(id: "4", domain: .appControl, title: "关闭App", status: .partial, evidence: "部分", nextFix: "补充驱动"),
        ScenarioAuditItem(id: "5", domain: .browser, title: "搜索", status: .missing, evidence: "未实现", nextFix: "实现浏览器驱动"),
    ]
    let summary = ScenarioAuditSummary(items: items)
    XCTAssertTrue(summary.total == 5)
    XCTAssertTrue(summary.verified == 2)
    XCTAssertTrue(summary.implemented == 1)
    XCTAssertTrue(summary.partial == 1)
    XCTAssertTrue(summary.missing == 1)
    XCTAssertTrue(summary.coveragePercent == 60) // (2+1)/5 * 100
}

func testScenarioAuditSummaryAllVerified() {
    let items: [ScenarioAuditItem] = (0..<4).map { i in
        ScenarioAuditItem(id: "\(i)", domain: .screenUnderstanding, title: "T\(i)", status: .verified, evidence: "OK", nextFix: "")
    }
    let summary = ScenarioAuditSummary(items: items)
    XCTAssertTrue(summary.coveragePercent == 100)
}

func testScenarioAuditSummaryAllMissing() {
    let items: [ScenarioAuditItem] = (0..<3).map { i in
        ScenarioAuditItem(id: "\(i)", domain: .safetyPrivacy, title: "T\(i)", status: .missing, evidence: "", nextFix: "TODO")
    }
    let summary = ScenarioAuditSummary(items: items)
    XCTAssertTrue(summary.coveragePercent == 0)
}

// MARK: - ScenarioAuditReport

func testScenarioAuditReportCreatesSummary() {
    let items: [ScenarioAuditItem] = [
        ScenarioAuditItem(id: "1", domain: .startupPermissions, title: "权限检查", status: .verified, evidence: "OK", nextFix: ""),
    ]
    let report = ScenarioAuditReport(items: items)
    XCTAssertTrue(report.summary.total == 1)
    XCTAssertTrue(report.summary.coveragePercent == 100)
}

// MARK: - ScenarioCoverageStatus

func testScenarioCoverageStatusTitles() {
    XCTAssertTrue(ScenarioCoverageStatus.verified.title == "已实测")
    XCTAssertTrue(ScenarioCoverageStatus.implemented.title == "已实现")
    XCTAssertTrue(ScenarioCoverageStatus.partial.title == "部分")
    XCTAssertTrue(ScenarioCoverageStatus.missing.title == "缺失")
}

// MARK: - ScenarioDomain

func testScenarioDomainTitles() {
    XCTAssertTrue(ScenarioDomain.startupPermissions.title == "启动/权限")
    XCTAssertTrue(ScenarioDomain.voiceConversation.title == "语音对话")
    XCTAssertTrue(ScenarioDomain.screenUnderstanding.title == "屏幕理解")
    XCTAssertTrue(ScenarioDomain.appControl.title == "App 控制")
    XCTAssertTrue(ScenarioDomain.elementControl.title == "控件操作")
    XCTAssertTrue(ScenarioDomain.finderFiles.title == "文件/Finder")
    XCTAssertTrue(ScenarioDomain.browser.title == "浏览器")
    XCTAssertTrue(ScenarioDomain.messaging.title == "微信/邮件")
    XCTAssertTrue(ScenarioDomain.terminalParallel.title == "多终端任务")
    XCTAssertTrue(ScenarioDomain.developerWorkflow.title == "开发工作流")
    XCTAssertTrue(ScenarioDomain.officeProductivity.title == "办公生产力")
    XCTAssertTrue(ScenarioDomain.mediaEntertainment.title == "娱乐媒体")
    XCTAssertTrue(ScenarioDomain.safetyPrivacy.title == "安全隐私")
    XCTAssertTrue(ScenarioDomain.selfOptimization.title == "自优化恢复")
}

func testScenarioDomainAllCasesCount() {
    XCTAssertTrue(ScenarioDomain.allCases.count == 17)
}
