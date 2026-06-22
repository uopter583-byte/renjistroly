import Foundation
import XCTest
@testable import RenJistrolyIntelligence
import RenJistrolyModels

func testLMCacheInit() async {
    let cache = LMCache()
    let stats = await cache.tierStats
    XCTAssertTrue(stats.contains("Tier1"))
    XCTAssertTrue(stats.contains("Tier2"))
    XCTAssertTrue(stats.contains("Tier3"))
}

func testLMCacheSetAndGet() async {
    let cache = LMCache()
    let response = CachedResponse(text: "Hello", provider: "test", model: "test-model")
    await cache.set(key: "test-key", value: response)
    let retrieved = await cache.get(key: "test-key")
    XCTAssertTrue(retrieved?.text == "Hello")
    XCTAssertTrue(retrieved?.provider == "test")
}

func testLMCacheGetMiss() async {
    let cache = LMCache()
    let result = await cache.get(key: "nonexistent")
    XCTAssertTrue(result == nil)
}

func testLMCacheCacheKey() async {
    let cache = LMCache()
    let messages = [Message(role: .user, content: [.text("Hello")])]
    let config = LLMConfiguration(provider: .anthropic, model: "claude-4")
    let key1 = await cache.cacheKey(messages: messages, config: config)
    let key2 = await cache.cacheKey(messages: messages, config: config)
    XCTAssertTrue(key1 == key2)
}

func testLMCacheCacheKeyDifferentMessages() async {
    let cache = LMCache()
    let msg1 = [Message(role: .user, content: [.text("Hello")])]
    let msg2 = [Message(role: .user, content: [.text("World")])]
    let config = LLMConfiguration(provider: .anthropic, model: "claude-4")
    let key1 = await cache.cacheKey(messages: msg1, config: config)
    let key2 = await cache.cacheKey(messages: msg2, config: config)
    XCTAssertTrue(key1 != key2)
}

func testLMCacheInvalidate() async {
    let cache = LMCache()
    await cache.set(key: "to-delete", value: CachedResponse(text: "temp", provider: "test", model: "m"))
    let before = await cache.get(key: "to-delete")
    XCTAssertTrue(before != nil)
    await cache.invalidate(key: "to-delete")
    let after = await cache.get(key: "to-delete")
    XCTAssertTrue(after == nil)
}

func testLMCacheWarmTier1() async {
    let cache = LMCache()
    await cache.warmTier1(key: "hot-key", value: CachedResponse(text: "hot", provider: "test", model: "m"))
    let result = await cache.get(key: "hot-key")
    XCTAssertTrue(result?.text == "hot")
}

func testLMCachePrune() async {
    let cache = LMCache(config: .init(tier1MaxEntries: 5, tier2MaxEntries: 10, tier3MaxSizeMB: 1, ttlSeconds: 0))
    await cache.set(key: "expired", value: CachedResponse(text: "old", provider: "test", model: "m"))
    try? await Task.sleep(for: .seconds(1))
    await cache.prune()
    let result = await cache.get(key: "expired")
    XCTAssertTrue(result == nil)
}

func testCachedResponseInit() {
    let response = CachedResponse(text: "test", provider: "anthropic", model: "claude-4", totalTokens: 100)
    XCTAssertTrue(response.text == "test")
    XCTAssertTrue(response.provider == "anthropic")
    XCTAssertTrue(response.totalTokens == 100)
}
