import XCTest
import RenJistrolyModels

struct ToolSafetyTests {

func testRiskLevelOrdering() {
        XCTAssertTrue(ToolRiskLevel.low < ToolRiskLevel.medium)
        XCTAssertTrue(ToolRiskLevel.medium < ToolRiskLevel.high)
        XCTAssertTrue(ToolRiskLevel.low < ToolRiskLevel.high)
        XCTAssertTrue(ToolRiskLevel.high > ToolRiskLevel.low)
    }

func testDefaultPolicy() {
        let policy = ToolExecutionPolicy.default
        XCTAssertTrue(policy.canAutoExecute(.low))
        XCTAssertTrue(!policy.canAutoExecute(.medium))
        XCTAssertTrue(!policy.canAutoExecute(.high))
    }

func testPermissivePolicy() {
        let policy = ToolExecutionPolicy.permissive
        XCTAssertTrue(policy.canAutoExecute(.low))
        XCTAssertTrue(policy.canAutoExecute(.medium))
        XCTAssertTrue(!policy.canAutoExecute(.high))
    }

func testStrictPolicy() {
        let policy = ToolExecutionPolicy.strict
        XCTAssertTrue(!policy.canAutoExecute(.low))
        XCTAssertTrue(!policy.canAutoExecute(.medium))
        XCTAssertTrue(!policy.canAutoExecute(.high))
    }

func testPolicyEquality() {
        let a = ToolExecutionPolicy.default
        let b = ToolExecutionPolicy(autoApproveLow: true, autoApproveMedium: false, autoApproveHigh: false)
        XCTAssertTrue(a == b)
        XCTAssertTrue(a != ToolExecutionPolicy.permissive)
    }

func testRiskAssessmentFields() {
        let assessment = ToolRiskAssessment(
            toolName: "shell_command",
            riskLevel: .high,
            arguments: ["command": "ls"],
            summary: "执行 Shell 命令: ls"
        )
        XCTAssertTrue(assessment.toolName == "shell_command")
        XCTAssertTrue(assessment.riskLevel == .high)
        XCTAssertTrue(assessment.arguments["command"] == "ls")
        XCTAssertFalse(assessment.summary.isEmpty)
    }

func testToolNeedsConfirmationError() {
        let assessment = ToolRiskAssessment(
            toolName: "write_file",
            riskLevel: .high,
            arguments: ["path": "/tmp/test"],
            summary: "写入文件: /tmp/test"
        )
        let request = ToolCallRequest(id: "1", name: "write_file", arguments: ["path": "/tmp/test"])
        let error = ToolNeedsConfirmationError(assessment: assessment, request: request)
        XCTAssertTrue(error.assessment.toolName == "write_file")
        XCTAssertTrue(error.request.name == "write_file")
    }

func testExecutionRecordOutcome() {
        let record = ToolExecutionRecord(
            id: "1",
            toolName: "read_file",
            riskLevel: .low,
            arguments: [:],
            outcome: .autoExecuted("ok")
        )
        XCTAssertTrue(record.toolName == "read_file")
        XCTAssertTrue(record.riskLevel == .low)

        let rejectedRecord = ToolExecutionRecord(
            id: "2",
            toolName: "shell_command",
            riskLevel: .high,
            arguments: [:],
            outcome: .rejected
        )
        if case .rejected = rejectedRecord.outcome {
            // expected
        } else {
            XCTFail("outcome should be rejected")
        }
    }

func testCustomPolicy() {
        var policy = ToolExecutionPolicy.default
        XCTAssertTrue(policy.canAutoExecute(.low))

        policy.autoApproveHigh = true
        XCTAssertTrue(policy.canAutoExecute(.high))
        XCTAssertTrue(!policy.canAutoExecute(.medium))
    }
}
