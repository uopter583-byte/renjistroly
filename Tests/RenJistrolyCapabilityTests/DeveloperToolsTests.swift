import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

// MARK: - parseDiagnosticLine

func testParseDiagnosticLineError() {
    let tool = SwiftBuildTool()
    let diag = tool.parseDiagnosticLine(
        "/path/to/File.swift:42:10: error: type 'String' has no member 'foo'",
        severity: .error
    )
    XCTAssertTrue(diag.filePath == "/path/to/File.swift")
    XCTAssertTrue(diag.line == 42)
    XCTAssertTrue(diag.column == 10)
    XCTAssertTrue(diag.severity == .error)
    XCTAssertTrue(diag.message.contains("type 'String' has no member 'foo'"))
}

func testParseDiagnosticLineWarning() {
    let tool = SwiftBuildTool()
    let diag = tool.parseDiagnosticLine(
        "/app/Source.swift:5:1: warning: variable 'x' was never mutated",
        severity: .warning
    )
    XCTAssertTrue(diag.filePath == "/app/Source.swift")
    XCTAssertTrue(diag.line == 5)
    XCTAssertTrue(diag.column == 1)
    XCTAssertTrue(diag.severity == .warning)
}

func testParseDiagnosticLineNoFile() {
    let tool = SwiftBuildTool()
    let diag = tool.parseDiagnosticLine("error: something went wrong", severity: .error)
    XCTAssertTrue(diag.filePath == nil)
    XCTAssertTrue(diag.line == nil)
    XCTAssertTrue(diag.column == nil)
    XCTAssertTrue(diag.severity == .error)
}

// MARK: - parseSwiftBuildOutput

func testParseSwiftBuildOutputSuccess() {
    let tool = SwiftBuildTool()
    let output = """
    [1/3] Compiling FileA.swift
    [2/3] Compiling FileB.swift
    [3/3] Linking app
    Build complete! (3.42s)
    """
    let result = tool.parseSwiftBuildOutput(output)
    XCTAssertTrue(result.success == true)
    XCTAssertTrue(result.errors.isEmpty)
    XCTAssertTrue(result.warnings.isEmpty)
}

func testParseSwiftBuildOutputWithError() {
    let tool = SwiftBuildTool()
    let output = """
    /src/App.swift:10:5: error: cannot find 'foo' in scope
    /src/Util.swift:20:1: warning: unused variable 'bar'
    """
    let result = tool.parseSwiftBuildOutput(output)
    XCTAssertTrue(result.success == false)
    XCTAssertTrue(result.errors.count == 1)
    XCTAssertTrue(result.warnings.count == 1)
}

func testParseSwiftBuildOutputMultipleErrors() {
    let tool = SwiftBuildTool()
    let output = """
    /a.swift:1:1: error: e1
    /b.swift:2:2: error: e2
    /c.swift:3:3: error: e3
    """
    let result = tool.parseSwiftBuildOutput(output)
    XCTAssertTrue(result.errors.count == 3)
    XCTAssertTrue(result.warnings.isEmpty)
}

func testParseSwiftBuildOutputEmpty() {
    let tool = SwiftBuildTool()
    let result = tool.parseSwiftBuildOutput("")
    XCTAssertTrue(result.success == false)
    XCTAssertTrue(result.errors.isEmpty)
}

// MARK: - formatBuildResult

func testFormatBuildResultSuccess() {
    let tool = SwiftBuildTool()
    let result = BuildResult(success: true, durationSeconds: 2.5)
    let formatted = tool.formatBuildResult(result)
    XCTAssertTrue(formatted.contains("成功"))
    XCTAssertTrue(formatted.contains("2.5s"))
}

func testFormatBuildResultFailure() {
    let tool = SwiftBuildTool()
    let errors = [
        BuildDiagnostic(filePath: "App.swift", line: 10, column: 5, message: "type not found", severity: .error),
    ]
    let result = BuildResult(success: false, errors: errors, warnings: [], durationSeconds: 0.3)
    let formatted = tool.formatBuildResult(result)
    XCTAssertTrue(formatted.contains("失败"))
    XCTAssertTrue(formatted.contains("App.swift"))
    XCTAssertTrue(formatted.contains("type not found"))
}

func testFormatBuildResultWarningsTruncated() {
    let tool = SwiftBuildTool()
    let warnings = (0..<10).map { i in
        BuildDiagnostic(message: "warning \(i)", severity: .warning)
    }
    let result = BuildResult(success: true, warnings: warnings)
    let formatted = tool.formatBuildResult(result)
    XCTAssertTrue(formatted.contains("还有 5 个警告"))
}

// MARK: - parseSwiftTestOutput

func testParseSwiftTestOutputAllPass() {
    let tool = SwiftTestTool()
    let output = """
    Test Suite 'All tests' passed at 2026-01-01 12:00:00
         Executed 42 tests, with 0 failures
    """
    let result = tool.parseSwiftTestOutput(output, elapsed: 5.0)
    XCTAssertTrue(result.success == true)
    XCTAssertTrue(result.totalCount == 42)
    XCTAssertTrue(result.passedCount == 42)
    XCTAssertTrue(result.failedCount == 0)
}

func testParseSwiftTestOutputWithFailures() {
    let tool = SwiftTestTool()
    let output = """
    Test Case 'MyTests.testFoo' failed (0.001 seconds)
    Test Case 'MyTests.testBar' failed (0.002 seconds)
         Executed 10 tests, with 2 failures
    """
    let result = tool.parseSwiftTestOutput(output, elapsed: 3.0)
    XCTAssertTrue(result.success == false)
    XCTAssertTrue(result.totalCount == 10)
    XCTAssertTrue(result.failedCount == 2)
    XCTAssertTrue(result.passedCount == 8)
    XCTAssertTrue(result.failures.count == 2)
}

func testParseSwiftTestOutputZeroTests() {
    let tool = SwiftTestTool()
    let output = "Test run with 0 tests"
    let result = tool.parseSwiftTestOutput(output, elapsed: 0.1)
    XCTAssertTrue(result.success == true)
    XCTAssertTrue(result.totalCount == 0)
}

// MARK: - formatTestResult

func testFormatTestResultSuccess() {
    let tool = SwiftTestTool()
    let result = TestResult(success: true, totalCount: 15, passedCount: 15, failedCount: 0, durationSeconds: 2.0)
    let formatted = tool.formatTestResult(result)
    XCTAssertTrue(formatted.contains("通过"))
    XCTAssertTrue(formatted.contains("15/15"))
}

func testFormatTestResultFailure() {
    let tool = SwiftTestTool()
    let failures = [
        TestFailure(testName: "testA", message: "failed"),
        TestFailure(testName: "testB", message: "failed"),
    ]
    let result = TestResult(success: false, totalCount: 10, passedCount: 8, failedCount: 2, durationSeconds: 1.0, failures: failures)
    let formatted = tool.formatTestResult(result)
    XCTAssertTrue(formatted.contains("失败"))
    XCTAssertTrue(formatted.contains("8/10"))
    XCTAssertTrue(formatted.contains("testA"))
    XCTAssertTrue(formatted.contains("testB"))
}
