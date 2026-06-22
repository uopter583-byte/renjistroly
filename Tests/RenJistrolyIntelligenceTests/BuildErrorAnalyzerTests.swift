import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - Build result analysis (no-error paths)

func testAnalyzeBuildSuccess() async throws {
    let analyzer = BuildErrorAnalyzer()
    let result = BuildResult(success: true, errors: [], warnings: [])
    let analysis = try await analyzer.analyze(buildResult: result, projectPath: nil)
    XCTAssertTrue(analysis == "构建通过，没有错误。")
}

func testAnalyzeBuildFailureNoErrors() async throws {
    let analyzer = BuildErrorAnalyzer()
    let result = BuildResult(success: false, errors: [], warnings: [])
    let analysis = try await analyzer.analyze(buildResult: result, projectPath: nil)
    XCTAssertTrue(analysis == "没有可分析的错误信息。")
}

func testAnalyzeBuildWithWarningsOnly() async throws {
    let analyzer = BuildErrorAnalyzer()
    let warnings = [BuildDiagnostic(message: "unused variable", severity: .warning)]
    let result = BuildResult(success: true, errors: [], warnings: warnings)
    let analysis = try await analyzer.analyze(buildResult: result, projectPath: nil)
    XCTAssertTrue(analysis == "构建通过，没有错误。")
}

// MARK: - Test result analysis (no-error paths)

func testAnalyzeTestSuccess() async throws {
    let analyzer = BuildErrorAnalyzer()
    let result = TestResult(success: true, totalCount: 10, passedCount: 10, failedCount: 0, failures: [])
    let analysis = try await analyzer.analyze(testResult: result, projectPath: nil)
    XCTAssertTrue(analysis == "所有测试通过。")
}

func testAnalyzeTestFailureNoFailures() async throws {
    let analyzer = BuildErrorAnalyzer()
    let result = TestResult(success: false, totalCount: 10, passedCount: 5, failedCount: 5, failures: [])
    let analysis = try await analyzer.analyze(testResult: result, projectPath: nil)
    XCTAssertTrue(analysis == "没有可分析的失败信息。")
}

// BuildDiagnostic / TestFailure field checks

func testBuildDiagnosticFields() {
    let d = BuildDiagnostic(filePath: "App.swift", line: 42, column: 5, message: "type not found", severity: .error)
    XCTAssertTrue(d.filePath == "App.swift")
    XCTAssertTrue(d.line == 42)
    XCTAssertTrue(d.column == 5)
    XCTAssertTrue(d.message == "type not found")
    XCTAssertTrue(d.severity == .error)
}

func testTestFailureFields() {
    let f = TestFailure(testName: "testLogin", message: "assertion failed", filePath: "Test.swift", line: 10)
    XCTAssertTrue(f.testName == "testLogin")
    XCTAssertTrue(f.message == "assertion failed")
    XCTAssertTrue(f.filePath == "Test.swift")
    XCTAssertTrue(f.line == 10)
}

func testBuildDiagnosticSeverityAllCases() {
    for s in [BuildDiagnostic.Severity.error, .warning, .note] {
        XCTAssertTrue(s.rawValue.isEmpty == false)
    }
}
