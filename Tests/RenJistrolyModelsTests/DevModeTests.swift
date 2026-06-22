import XCTest
import RenJistrolyModels

struct DevModeTests {

func testBuildResultSuccess() {
        let result = BuildResult(success: true, durationSeconds: 2.5)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertTrue(result.summary.contains("2.5"))
    }

func testBuildResultFailure() {
        let errors = [BuildDiagnostic(message: "type mismatch", severity: .error)]
        let result = BuildResult(success: false, errors: errors, warnings: [])
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.errors.count == 1)
        XCTAssertTrue(result.summary.contains("1 个错误"))
    }

func testBuildDiagnosticFields() {
        let diag = BuildDiagnostic(
            filePath: "/src/main.swift",
            line: 42,
            column: 10,
            message: "Cannot find type 'Foo'",
            severity: .error
        )
        XCTAssertTrue(diag.filePath == "/src/main.swift")
        XCTAssertTrue(diag.line == 42)
        XCTAssertTrue(diag.column == 10)
        XCTAssertTrue(diag.severity == .error)
    }

func testTestResultSuccess() {
        let result = TestResult(success: true, totalCount: 15, passedCount: 15, durationSeconds: 3.0)
        XCTAssertTrue(result.success)
        XCTAssertTrue(result.totalCount == 15)
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertTrue(result.summary.contains("15"))
    }

func testTestResultFailure() {
        let failures = [TestFailure(testName: "testFoo", message: "expected true, got false")]
        let result = TestResult(
            success: false,
            totalCount: 15,
            passedCount: 14,
            failedCount: 1,
            failures: failures
        )
        XCTAssertFalse(result.success)
        XCTAssertTrue(result.failedCount == 1)
        XCTAssertTrue(result.summary.contains("1/15"))
    }

func testDevModeStateDefault() {
        let state = DevModeState.disabled
        XCTAssertFalse(state.isEnabled)
        XCTAssertTrue(state.lastBuildResult == nil)
        XCTAssertTrue(state.lastTestResult == nil)
    }

func testDevModeStateEnabled() {
        var state = DevModeState(isEnabled: true, projectPath: "/Users/test/project")
        XCTAssertTrue(state.isEnabled)
        XCTAssertTrue(state.projectPath == "/Users/test/project")

        let buildResult = BuildResult(success: true)
        state.lastBuildResult = buildResult
        XCTAssertTrue(state.lastBuildResult?.success == true)
    }
}
