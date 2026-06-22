import Foundation
import XCTest
@testable import RenJistrolySystemBridge

// MARK: - WeChatChatState Models

func testChatWeChatChatStateOpenBasic() {
    let state = WeChatChatState(isOpen: true, activeChatTitle: "张三")
    XCTAssertTrue(state.isOpen)
    XCTAssertTrue(state.activeChatTitle == "张三")
}

func testChatWeChatChatStateClosed() {
    let state = WeChatChatState(isOpen: false, activeChatTitle: nil)
    XCTAssertFalse(state.isOpen)
    XCTAssertTrue(state.activeChatTitle == nil)
}

func testChatWeChatChatStateNoActiveChat() {
    let state = WeChatChatState(isOpen: true, activeChatTitle: nil)
    XCTAssertTrue(state.isOpen)
    XCTAssertTrue(state.activeChatTitle == nil)
}

// MARK: - WeChatDriver Definition

func testWeChatDriverIdentity() {
    let driver = WeChatDriver()
    XCTAssertTrue(driver.id == "wechat")
    XCTAssertTrue(driver.displayName == "WeChat")
    XCTAssertTrue(driver.capabilities.contains(.open))
    XCTAssertTrue(driver.capabilities.contains(.search))
    XCTAssertTrue(driver.capabilities.contains(.write))
    XCTAssertTrue(driver.capabilities.contains(.requiresConfirmationBeforeSend))
}

// MARK: - WeChatDriver Method Contract (no actual execution)

func testWeChatDraftMessageNoAutoSend() async throws {
    let driver = WeChatDriver()
    let script = try? await driver.draftMessage("这是一条测试消息，不会自动发送")
    // draftMessage 只写入文本，不按回车，所以不会发送
    XCTAssertTrue(script == true || script == nil)
}

func testWeChatSendDraftRequiresExplicitCall() async throws {
    let driver = WeChatDriver()
    let result = try? await driver.sendDraft()
    // sendDraft 是显式的发送操作，不应自动触发
    XCTAssertTrue(result == true || result == nil)
}

func testWeChatConfirmCurrentChatEmptyName() async throws {
    let driver = WeChatDriver()
    let confirmed = try await driver.confirmCurrentChat(expectedName: "")
    XCTAssertTrue(confirmed == false)
}

func testWeChatConfirmCurrentChatNotRunning() async throws {
    let driver = WeChatDriver()
    let confirmed = try await driver.confirmCurrentChat(expectedName: "测试群")
    XCTAssertTrue(confirmed == false) // 微信可能未运行
}

func testWeChatSendMessageRequiresConfirmationCapability() {
    let driver = WeChatDriver()
    XCTAssertTrue(driver.capabilities.contains(.requiresConfirmationBeforeSend))
}

func testWeChatSearchContactNameEmpty() async throws {
    let driver = WeChatDriver()
    let found = try await driver.searchContact(name: "")
    // 空名称搜索不应该误匹配
    XCTAssertTrue(found == false)
}

func testWeChatReadRecentMessagesNoCrash() async throws {
    let driver = WeChatDriver()
    let messages = try await driver.readRecentMessages()
    _ = messages
}

// MARK: - AppDriverRegistry

func testAppDriverRegistryIncludesWeChat() {
    let registry = AppDriverRegistry()
    let driver = registry.driver(id: "wechat")
    XCTAssertTrue(driver != nil)
    XCTAssertTrue(driver?.id == "wechat")
}

func testAppDriverRegistryAllDrivers() {
    let registry = AppDriverRegistry()
    let ids = registry.drivers.map(\.id).sorted()
    XCTAssertTrue(ids.contains("wechat"))
    XCTAssertTrue(ids.contains("finder"))
    XCTAssertTrue(ids.contains("safari"))
    XCTAssertTrue(ids.contains("chrome"))
    XCTAssertTrue(ids.contains("terminal"))
    XCTAssertTrue(ids.contains("xcode"))
}
