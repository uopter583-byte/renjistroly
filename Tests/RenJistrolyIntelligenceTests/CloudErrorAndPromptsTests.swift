import Foundation
import XCTest
@testable import RenJistrolyIntelligence

// MARK: - CloudError

func testCloudErrorInvalidURL() {
    let err = CloudError.invalidURL
    XCTAssertTrue(String(describing: err).contains("invalidURL"))
}

func testCloudErrorInvalidResponse() {
    let err = CloudError.invalidResponse
    XCTAssertTrue(String(describing: err).contains("invalidResponse"))
}

func testCloudErrorHTTPError() {
    let err = CloudError.httpError(statusCode: 429, body: "Rate limited")
    let desc = String(describing: err)
    XCTAssertTrue(desc.contains("429"))
    XCTAssertTrue(desc.contains("Rate limited"))
}

func testCloudErrorMissingAPIKey() {
    let err = CloudError.missingAPIKey
    XCTAssertTrue(String(describing: err).contains("missingAPIKey"))
}

func testCloudErrorAllCasesDistinct() {
    let cases: [CloudError] = [
        .invalidURL, .invalidResponse, .httpError(statusCode: 500, body: "err"), .missingAPIKey
    ]
    let descriptions = Set(cases.map { String(describing: $0) })
    XCTAssertTrue(descriptions.count == 4)
}

// MARK: - ChineseAssistantPrompts

func testChineseAssistantPromptsSystemNotEmpty() {
    XCTAssertFalse(ChineseAssistantPrompts.system.isEmpty)
}

func testChineseAssistantPromptsContainsKeyPhrases() {
    let s = ChineseAssistantPrompts.system
    XCTAssertTrue(s.contains("macOS"))
    XCTAssertTrue(s.contains("语音"))
    XCTAssertTrue(s.contains("Computer Use"))
    XCTAssertTrue(s.contains("安全层"))
    XCTAssertTrue(s.contains("简短中文"))
}
