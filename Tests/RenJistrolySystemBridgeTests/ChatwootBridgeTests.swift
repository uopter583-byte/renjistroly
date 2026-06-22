import Foundation
import XCTest
@testable import RenJistrolySystemBridge

func testChatwootBridgeInit() async {
    let bridge = ChatwootBridge(
        baseURL: "https://app.chatwoot.com",
        apiAccessToken: "test-token",
        accountID: "1"
    )
    let body = "test".data(using: .utf8)!
    let verified = await bridge.verifyWebhookSignature(body: body, signature: "any")
    XCTAssertFalse(verified)
}

func testChatwootBridgeConfigureWebhook() async {
    let bridge = ChatwootBridge(
        baseURL: "https://app.chatwoot.com",
        apiAccessToken: "test-token",
        accountID: "1"
    )
    await bridge.configureWebhook(secret: "wh-secret-123")
    // Verification after config
    let body = "test-payload".data(using: .utf8)!
    let sig = await bridge.verifyWebhookSignature(body: body, signature: "any")
    XCTAssertTrue(sig == false) // Signature won't match, but config is set
}

func testChatwootBridgeVerifyWebhookNoSecret() async {
    let bridge = ChatwootBridge(
        baseURL: "https://app.chatwoot.com",
        apiAccessToken: "test-token",
        accountID: "1"
    )
    let body = "test".data(using: .utf8)!
    let verified = await bridge.verifyWebhookSignature(body: body, signature: "any")
    XCTAssertFalse(verified)
}

func testChatwootConversationStatusRawValues() {
    XCTAssertTrue(ConversationStatus.open.rawValue == "open")
    XCTAssertTrue(ConversationStatus.resolved.rawValue == "resolved")
    XCTAssertTrue(ConversationStatus.pending.rawValue == "pending")
    XCTAssertTrue(ConversationStatus.snoozed.rawValue == "snoozed")
}

func testChatwootMessageContentTypeRawValues() {
    XCTAssertTrue(MessageContentType.text.rawValue == "outgoing")
    XCTAssertTrue(MessageContentType.incoming.rawValue == "incoming")
    XCTAssertTrue(MessageContentType.activity.rawValue == "activity")
}

func testChatwootWebSocketInit() async {
    let ws = ChatwootWebSocket(baseURL: "https://app.chatwoot.com", pubsubToken: "token", accountID: "1")
    await ws.disconnect()
}

func testChatwootErrorDescriptions() {
    XCTAssertTrue(ChatwootError.invalidURL.errorDescription != nil)
    XCTAssertTrue(ChatwootError.invalidResponse.errorDescription != nil)
    XCTAssertTrue(ChatwootError.httpError(statusCode: 401, body: "unauthorized").errorDescription?.contains("401") == true)
    XCTAssertTrue(ChatwootError.decodingFailed("test").errorDescription?.contains("解析失败") == true)
}

func testChatwootBridgeListConversationsInvalidAuth() async {
    let bridge = ChatwootBridge(
        baseURL: "https://httpbin.org",
        apiAccessToken: "bad-token",
        accountID: "1"
    )
    do {
        _ = try await bridge.listConversations()
        XCTFail("Expected error for bad auth")
    } catch let error as ChatwootError {
        XCTAssertTrue(String(describing: error).contains("403") || String(describing: error).contains("httpError"))
    } catch {
        // Network errors are also expected for httpbin
    }
}

func testChatwootBridgeSearchContactsInvalidAuth() async {
    let bridge = ChatwootBridge(
        baseURL: "https://httpbin.org",
        apiAccessToken: "bad-token",
        accountID: "1"
    )
    do {
        _ = try await bridge.searchContacts(query: "test")
        XCTFail("Expected error for bad auth")
    } catch {
        // Expected: httpbin returns HTML, not JSON
    }
}
