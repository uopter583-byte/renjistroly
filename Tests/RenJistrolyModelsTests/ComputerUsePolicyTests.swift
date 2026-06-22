import Foundation
import XCTest
import RenJistrolyModels

// MARK: - ComputerUseConfirmationMode

func testComputerUseConfirmationModeTitles() {
    XCTAssertTrue(ComputerUseConfirmationMode.noConfirmation.title == "无需确认")
    XCTAssertTrue(ComputerUseConfirmationMode.preApprovalWorks.title == "预授权可执行")
    XCTAssertTrue(ComputerUseConfirmationMode.alwaysConfirm.title == "执行前确认")
    XCTAssertTrue(ComputerUseConfirmationMode.handOffRequired.title == "必须用户接管")
}

// MARK: - ComputerUsePolicyCatalog

func testComputerUsePolicyCatalogNotEmpty() {
    XCTAssertFalse(ComputerUsePolicyCatalog.rules.isEmpty)
}

func testComputerUsePolicyCatalogAlwaysConfirmRules() {
    let confirmRules = ComputerUsePolicyCatalog.rules.filter { $0.mode == .alwaysConfirm }
    XCTAssertTrue(confirmRules.count >= 7) // 删除、账号、验证码、安装、消息、金融、系统设置
}

func testComputerUsePolicyCatalogBasicUINoConfirmation() {
    let basicUI = ComputerUsePolicyCatalog.rules.first { $0.id == "basic-ui" }
    XCTAssertTrue(basicUI != nil)
    XCTAssertTrue(basicUI?.mode == .noConfirmation)
}

func testComputerUsePolicyCatalogBrowserSafetyHandOff() {
    let rule = ComputerUsePolicyCatalog.rules.first { $0.id == "browser-safety" }
    XCTAssertTrue(rule != nil)
    XCTAssertTrue(rule?.mode == .handOffRequired)
}

func testComputerUsePolicyCatalogUniqueIDs() {
    let ids = ComputerUsePolicyCatalog.rules.map(\.id)
    XCTAssertTrue(Set(ids).count == ids.count)
}

// MARK: - ComputerUsePolicyRule

func testComputerUsePolicyRuleDetails() {
    let rule = ComputerUsePolicyRule(
        id: "test-rule",
        title: "测试规则",
        mode: .alwaysConfirm,
        detail: "测试用规则"
    )
    XCTAssertTrue(rule.id == "test-rule")
    XCTAssertTrue(rule.title == "测试规则")
    XCTAssertTrue(rule.mode == .alwaysConfirm)
}
