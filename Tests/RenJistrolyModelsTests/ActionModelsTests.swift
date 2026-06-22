import Foundation
import XCTest
import RenJistrolyModels

// MARK: - ActionRiskLevel

func testActionRiskLevelTitles() {
    XCTAssertTrue(ActionRiskLevel.readOnly.title == "只读")
    XCTAssertTrue(ActionRiskLevel.reversibleInput.title == "可撤销输入")
    XCTAssertTrue(ActionRiskLevel.persistentOrExternal.title == "持久或外部影响")
    XCTAssertTrue(ActionRiskLevel.destructiveOrSensitive.title == "破坏性或敏感")
}

func testActionRiskLevelOrdering() {
    XCTAssertTrue(ActionRiskLevel.readOnly < ActionRiskLevel.reversibleInput)
    XCTAssertTrue(ActionRiskLevel.reversibleInput < ActionRiskLevel.persistentOrExternal)
    XCTAssertTrue(ActionRiskLevel.persistentOrExternal < ActionRiskLevel.destructiveOrSensitive)
}

// MARK: - PolicyDecision

func testPolicyDecisionAllow() {
    let d = PolicyDecision.allow
    XCTAssertTrue(d == .allow)
}

func testPolicyDecisionRequireConfirmation() {
    let d = PolicyDecision.requireConfirmation("需要确认")
    if case .requireConfirmation(let msg) = d {
        XCTAssertTrue(msg == "需要确认")
    } else {
        XCTFail("unexpected false")
    }
}

func testPolicyDecisionDeny() {
    let d = PolicyDecision.deny("不允许")
    if case .deny(let reason) = d {
        XCTAssertTrue(reason == "不允许")
    } else {
        XCTFail("unexpected false")
    }
}

func testPolicyDecisionDeveloperModeOnly() {
    let d = PolicyDecision.developerModeOnly("仅开发者模式")
    if case .developerModeOnly(let msg) = d {
        XCTAssertTrue(msg == "仅开发者模式")
    } else {
        XCTFail("unexpected false")
    }
}

// MARK: - MacAction

func testMacActionInitWithDefaults() {
    let action = MacAction(kind: .openApplication, riskLevel: .reversibleInput, humanPreview: "打开 Safari")
    XCTAssertTrue(action.kind == .openApplication)
    XCTAssertTrue(action.payload.isEmpty)
    XCTAssertTrue(action.riskLevel == .reversibleInput)
    XCTAssertTrue(action.humanPreview == "打开 Safari")
}

func testMacActionInitWithPayload() {
    let action = MacAction(
        kind: .clickAt,
        payload: ["x": "100", "y": "200"],
        riskLevel: .readOnly,
        humanPreview: "点击 (100, 200)"
    )
    XCTAssertTrue(action.payload["x"] == "100")
    XCTAssertTrue(action.payload["y"] == "200")
}

func testMacActionIdentifiableByID() {
    let a1 = MacAction(kind: .openApplication, riskLevel: .reversibleInput, humanPreview: "A")
    let a2 = MacAction(kind: .openApplication, riskLevel: .reversibleInput, humanPreview: "A")
    XCTAssertTrue(a1.id != a2.id)
}

// MARK: - ActionResult

func testActionResultSuccess() {
    let result = ActionResult(actionID: UUID(), success: true, message: "完成")
    XCTAssertTrue(result.success)
    XCTAssertTrue(result.message == "完成")
}

func testActionResultFailure() {
    let result = ActionResult(actionID: UUID(), success: false, message: "失败")
    XCTAssertFalse(result.success)
}
