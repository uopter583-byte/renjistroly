import Foundation
import XCTest
import RenJistrolyModels

// MARK: - ToolActionCategory

func testToolActionCategoryDefaultRiskLevelLow() {
    XCTAssertTrue(ToolActionCategory.observe.defaultRiskLevel == .low)
    XCTAssertTrue(ToolActionCategory.localFileRead.defaultRiskLevel == .low)
    XCTAssertTrue(ToolActionCategory.shellRead.defaultRiskLevel == .low)
}

func testToolActionCategoryDefaultRiskLevelMedium() {
    XCTAssertTrue(ToolActionCategory.localInput.defaultRiskLevel == .medium)
    XCTAssertTrue(ToolActionCategory.localNavigation.defaultRiskLevel == .medium)
    XCTAssertTrue(ToolActionCategory.localFileWrite.defaultRiskLevel == .medium)
    XCTAssertTrue(ToolActionCategory.appLaunch.defaultRiskLevel == .medium)
}

func testToolActionCategoryDefaultRiskLevelHigh() {
    XCTAssertTrue(ToolActionCategory.localFileDelete.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.shellWrite.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.codeAgent.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.systemSetting.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.externalCommunication.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.sensitiveDataTransmission.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.credentialOrAccount.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.financial.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.installSoftware.defaultRiskLevel == .high)
    XCTAssertTrue(ToolActionCategory.unknown.defaultRiskLevel == .high)
}

func testToolActionCategoryRequiresConfirmationTrue() {
    XCTAssertTrue(ToolActionCategory.localFileDelete.requiresActionTimeConfirmation)
    XCTAssertTrue(ToolActionCategory.systemSetting.requiresActionTimeConfirmation)
    XCTAssertTrue(ToolActionCategory.externalCommunication.requiresActionTimeConfirmation)
    XCTAssertTrue(ToolActionCategory.sensitiveDataTransmission.requiresActionTimeConfirmation)
    XCTAssertTrue(ToolActionCategory.credentialOrAccount.requiresActionTimeConfirmation)
    XCTAssertTrue(ToolActionCategory.financial.requiresActionTimeConfirmation)
    XCTAssertTrue(ToolActionCategory.installSoftware.requiresActionTimeConfirmation)
}

func testToolActionCategoryRequiresConfirmationFalse() {
    XCTAssertFalse(ToolActionCategory.observe.requiresActionTimeConfirmation)
    XCTAssertFalse(ToolActionCategory.localInput.requiresActionTimeConfirmation)
    XCTAssertFalse(ToolActionCategory.localNavigation.requiresActionTimeConfirmation)
    XCTAssertFalse(ToolActionCategory.localFileRead.requiresActionTimeConfirmation)
    XCTAssertFalse(ToolActionCategory.localFileWrite.requiresActionTimeConfirmation)
    XCTAssertFalse(ToolActionCategory.shellRead.requiresActionTimeConfirmation)
    XCTAssertFalse(ToolActionCategory.shellWrite.requiresActionTimeConfirmation)
    XCTAssertFalse(ToolActionCategory.codeAgent.requiresActionTimeConfirmation)
    XCTAssertFalse(ToolActionCategory.appLaunch.requiresActionTimeConfirmation)
    XCTAssertFalse(ToolActionCategory.unknown.requiresActionTimeConfirmation)
}

func testToolActionCategoryAllCasesCount() {
    XCTAssertTrue(ToolActionCategory.allCases.count == 17)
}

// MARK: - ToolRiskAssessment default

func testToolRiskAssessmentDefaultCategory() {
    let assessment = ToolRiskAssessment(
        toolName: "test",
        riskLevel: .low,
        arguments: [:],
        summary: "test"
    )
    XCTAssertTrue(assessment.actionCategory == .unknown)
}

// MARK: - ToolRejectedError

func testToolRejectedError() {
    let error = ToolRejectedError(toolName: "delete_file")
    XCTAssertTrue(error.toolName == "delete_file")
}

// MARK: - ToolExecutionRecord outcome cases

func testToolExecutionOutcomeConfirmed() {
    let record = ToolExecutionRecord(
        id: "1",
        toolName: "write_file",
        riskLevel: .medium,
        arguments: [:],
        outcome: .confirmed("用户已确认")
    )
    if case .confirmed(let msg) = record.outcome {
        XCTAssertTrue(msg == "用户已确认")
    } else {
        XCTFail("unexpected false")
    }
}

func testToolExecutionOutcomeFailed() {
    let record = ToolExecutionRecord(
        id: "2",
        toolName: "run_shell",
        riskLevel: .high,
        arguments: [:],
        outcome: .failed("权限不足")
    )
    if case .failed(let msg) = record.outcome {
        XCTAssertTrue(msg == "权限不足")
    } else {
        XCTFail("unexpected false")
    }
}

// MARK: - ToolRiskLevel

func testToolRiskLevelAllCases() {
    let all = ToolRiskLevel.allCases
    XCTAssertTrue(all.count == 3)
    XCTAssertTrue(all.contains(.low))
    XCTAssertTrue(all.contains(.medium))
    XCTAssertTrue(all.contains(.high))
}
