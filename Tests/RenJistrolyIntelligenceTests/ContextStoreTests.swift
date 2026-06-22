import Foundation
import XCTest
@testable import RenJistrolyIntelligence

// MARK: - append & allEntries

func testAppendAndAllEntries() async {
    let store = ContextStore(fileName: "test_context_\(UUID().uuidString.prefix(8)).json")
    defer { Task { await store.clear() } }
    await store.append(ContextStore.ContextEntry(role: "user", content: "hello"))
    await store.append(ContextStore.ContextEntry(role: "assistant", content: "hi"))
    let all = await store.allEntries()
    XCTAssertTrue(all.count == 2)
    XCTAssertTrue(all[0].role == "user")
    XCTAssertTrue(all[1].role == "assistant")
}

func testAppendExchange() async {
    let store = ContextStore(fileName: "test_ctx_exchange_\(UUID().uuidString.prefix(8)).json")
    defer { Task { await store.clear() } }
    await store.appendExchange(user: "how are you", assistant: "I'm good")
    let all = await store.allEntries()
    XCTAssertTrue(all.count == 2)
    XCTAssertTrue(all[0].role == "user")
    XCTAssertTrue(all[0].content == "how are you")
    XCTAssertTrue(all[1].role == "assistant")
}

// MARK: - recentContext

func testRecentContextReturnsLastExchanges() async {
    let store = ContextStore(fileName: "test_ctx_recent_\(UUID().uuidString.prefix(8)).json")
    defer { Task { await store.clear() } }
    for i in 0..<10 {
        await store.appendExchange(user: "u\(i)", assistant: "a\(i)")
    }
    let recent = await store.recentContext()
    XCTAssertTrue(recent.count == 6) // maxRecentExchanges(3) * 2 = 6
    XCTAssertTrue(recent[0].content == "u7")
}

func testRecentContextEmpty() async {
    let store = ContextStore(fileName: "test_ctx_empty_\(UUID().uuidString.prefix(8)).json")
    defer { Task { await store.clear() } }
    let recent = await store.recentContext()
    XCTAssertTrue(recent.isEmpty)
}

// MARK: - entryCount / exchangeCount

func testCounts() async {
    let store = ContextStore(fileName: "test_ctx_counts_\(UUID().uuidString.prefix(8)).json")
    defer { Task { await store.clear() } }
    await store.appendExchange(user: "a", assistant: "b")
    await store.appendExchange(user: "c", assistant: "d")
    let ec = await store.entryCount
    let xc = await store.exchangeCount
    XCTAssertTrue(ec == 4)
    XCTAssertTrue(xc == 2)
}

// MARK: - clear

func testClear() async {
    let store = ContextStore(fileName: "test_ctx_clear_\(UUID().uuidString.prefix(8)).json")
    await store.append(ContextStore.ContextEntry(role: "user", content: "test"))
    let ec1 = await store.entryCount
    XCTAssertTrue(ec1 == 1)
    await store.clear()
    let ec2 = await store.entryCount
    XCTAssertTrue(ec2 == 0)
}
