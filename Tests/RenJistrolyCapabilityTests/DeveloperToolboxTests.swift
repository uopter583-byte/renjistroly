import Foundation
import XCTest
@testable import RenJistrolyCapability

// MARK: - formatBlame

func testFormatBlameWithCommitInfo() {
    let tool = GitBlameTool()
    let input = """
    ^abc12345 (John Doe  2024-01-15 1) func main() {
    def67890 (Jane Smith 2024-03-20 2)     print("hello")
    """
    let result = tool.formatBlame(input)
    XCTAssertTrue(result.contains("[abc12345]"))
    XCTAssertTrue(result.contains("John Doe"))
    XCTAssertTrue(result.contains("func main()"))
    XCTAssertTrue(result.contains("[def67890]"))
}

func testFormatBlamePlainLine() {
    let tool = GitBlameTool()
    let input = "just some text without commit info"
    let result = tool.formatBlame(input)
    XCTAssertTrue(result.contains("just some text"))
}

func testFormatBlameEmpty() {
    let tool = GitBlameTool()
    XCTAssertTrue(tool.formatBlame("").isEmpty)
}

// MARK: - deduplicateSymbolResults

func testDeduplicateSymbolResultsRgHeading() {
    let tool = FindSymbolTool()
    let input = """
    /path/to/File.swift
    10:func testFunc() {
    /path/to/File.swift
    10:func testFunc() {
    /path/to/Other.swift
    5:class TestClass {
    """
    let result = tool.deduplicateSymbolResults(input)
    let lines = result.split(separator: "\n")
    // Should have: heading, one "10:func", heading, one "5:class" = 4 lines
    XCTAssertTrue(lines.count == 4)
}

func testDeduplicateSymbolResultsGrepFormat() {
    let tool = FindSymbolTool()
    let input = """
    File.swift:10:func testFunc() {
    File.swift:10:func testFunc() {
    File.swift:15:func otherFunc() {
    """
    let result = tool.deduplicateSymbolResults(input)
    let lines = result.split(separator: "\n")
    XCTAssertTrue(lines.count == 2) // dedup by file:line
}

func testDeduplicateSymbolResultsEmpty() {
    let tool = FindSymbolTool()
    XCTAssertTrue(tool.deduplicateSymbolResults("").isEmpty)
}
