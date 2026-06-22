import Foundation
import XCTest
import RenJistrolyModels
import RenJistrolyCapability
@testable import RenJistrolyConversation

// MARK: - needsVisualVerification

@MainActor func testNeedsVisualVerificationClick() {
    let service = ToolExecutionService()
    XCTAssertTrue(service.needsVisualVerification("click") == true)
    XCTAssertTrue(service.needsVisualVerification("type_text") == true)
    XCTAssertTrue(service.needsVisualVerification("open_app") == true)
}

@MainActor func testNeedsVisualVerificationReadOnly() {
    let service = ToolExecutionService()
    XCTAssertTrue(service.needsVisualVerification("get_app_state") == false)
    XCTAssertTrue(service.needsVisualVerification("read_file") == false)
    XCTAssertTrue(service.needsVisualVerification("unknown") == false)
}

// MARK: - extractExpectedKeywords

@MainActor func testExtractExpectedKeywordsFromText() {
    let service = ToolExecutionService()
    let req = ToolCallRequest(id: "1", name: "type_text", arguments: ["text": "Hello World  "])
    let keywords = service.extractExpectedKeywords(from: req)
    XCTAssertTrue(keywords.contains("Hello World"))
}

@MainActor func testExtractExpectedKeywordsFromValue() {
    let service = ToolExecutionService()
    let req = ToolCallRequest(id: "1", name: "set_value", arguments: ["value": "admin"])
    let keywords = service.extractExpectedKeywords(from: req)
    XCTAssertTrue(keywords.contains("admin"))
}

@MainActor func testExtractExpectedKeywordsFromQuery() {
    let service = ToolExecutionService()
    let req = ToolCallRequest(id: "1", name: "safari_search", arguments: ["query": "weather forecast"])
    let keywords = service.extractExpectedKeywords(from: req)
    XCTAssertTrue(keywords.contains("weather forecast"))
}

@MainActor func testExtractExpectedKeywordsFromTitle() {
    let service = ToolExecutionService()
    let req = ToolCallRequest(id: "1", name: "click", arguments: ["title": "OK", "label": "Cancel"])
    let keywords = service.extractExpectedKeywords(from: req)
    XCTAssertTrue(keywords.contains("OK"))
    XCTAssertTrue(!keywords.contains("Cancel")) // title wins via ??, label not reached
}

@MainActor func testExtractExpectedKeywordsFromPath() {
    let service = ToolExecutionService()
    let req = ToolCallRequest(id: "1", name: "open_path", arguments: ["path": "/Users/test/Documents/file.txt"])
    let keywords = service.extractExpectedKeywords(from: req)
    XCTAssertTrue(keywords.contains("file.txt"))
}

@MainActor func testExtractExpectedKeywordsFromApp() {
    let service = ToolExecutionService()
    let req = ToolCallRequest(id: "1", name: "open_app", arguments: ["app_name": "Safari"])
    let keywords = service.extractExpectedKeywords(from: req)
    XCTAssertTrue(keywords.contains("Safari"))
}

@MainActor func testExtractExpectedKeywordsEmptyText() {
    let service = ToolExecutionService()
    let req = ToolCallRequest(id: "1", name: "type_text", arguments: ["text": "   "])
    let keywords = service.extractExpectedKeywords(from: req)
    XCTAssertTrue(keywords.isEmpty)
}

@MainActor func testExtractExpectedKeywordsMultipleArgs() {
    let service = ToolExecutionService()
    let req = ToolCallRequest(id: "1", name: "click", arguments: [
        "text": "hello",
        "title": "Submit",
        "app_name": "Finder",
    ])
    let keywords = service.extractExpectedKeywords(from: req)
    XCTAssertTrue(keywords.contains("hello"))
    XCTAssertTrue(keywords.contains("Submit"))
    XCTAssertTrue(keywords.contains("Finder"))
}
