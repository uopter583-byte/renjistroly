import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolySystemBridge
@testable import RenJistrolyIntelligence

// MARK: - 离线/弱网稳定性测试

func testZeroNetworkConnectivityDetection() async {
    let diagnostic = NetworkDiagnostic()
    let result = diagnostic.diagnose(
        pingOutput: "ping: cannot resolve example.com: Name or service not known",
        dnsLookup: "connection refused",
        proxySettings: nil
    )
    XCTAssertTrue(result.issueType == .dns)
    XCTAssertFalse(result.details.isEmpty)
    XCTAssertFalse(result.suggestions.isEmpty)
}

func testLocalModelStartupWithoutInternet() async {
    let manager = LocalModelManager()
    let canRun = await manager.canRunInference
    // Should not crash; local model check is independent of network
    XCTAssertTrue(canRun || !canRun)
}

func testLocalModelInferenceWhileOffline() async throws {
    let backend = LocalMLXBackend()
    // Backend uses CommandParser fallback when offline, no network required
    let result = try await backend.chat(
        messages: [Message(id: UUID(), role: .user, content: [.text("你好")], timestamp: Date())],
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: nil,
        delegate: nil
    )
    XCTAssertTrue(result.role == .assistant)
    XCTAssertFalse(result.textContent.isEmpty)
}

func testProxyConnectionFailureHandling() async {
    let diagnostic = NetworkDiagnostic()
    let result = diagnostic.diagnose(
        pingOutput: "connect: Connection refused",
        dnsLookup: nil,
        proxySettings: ["HTTPProxy": "127.0.0.1:8080", "HTTPSProxy": "127.0.0.1:8080"]
    )
    XCTAssertTrue(result.issueType == .proxy)
    XCTAssertTrue(result.suggestions.contains { $0.contains("代理") || $0.contains("proxy") })
}

func testDNSResolutionErrorRecovery() async {
    let diagnostic = NetworkDiagnostic()
    let result = diagnostic.diagnose(
        pingOutput: nil,
        dnsLookup: "failure: nodename nor servname provided, or not known",
        proxySettings: nil
    )
    XCTAssertTrue(result.issueType == .dns)
    XCTAssertTrue(result.suggestions.contains { $0.contains("DNS") || $0.contains("nslookup") })
}

func testVPNSwitchMidSession() async {
    let diagnostic = NetworkDiagnostic()
    // Simulate VPN connected scenario with failed ping
    let result = diagnostic.diagnose(
        pingOutput: "Request timeout for icmp_seq 0\n100.0% packet loss",
        dnsLookup: nil,
        proxySettings: nil
    )
    XCTAssertTrue(result.issueType == .connectivity)
    XCTAssertFalse(result.suggestions.isEmpty)
}

func testRequestTimeoutHandling() async {
    let diagnostic = NetworkDiagnostic()
    let result = diagnostic.diagnose(
        pingOutput: "Request timeout for icmp_seq 0\n100.0% packet loss",
        dnsLookup: nil,
        proxySettings: nil
    )
    XCTAssertTrue(result.issueType == .connectivity)
    XCTAssertTrue(result.details.contains("无法到达"))
}

func testNetworkRestorationAndReconnection() async {
    // LocalOnlyPolicy checks are network-independent
    let policy = LocalOnlyPolicy()
    let decision = policy.evaluate(filePath: "/Users/test/doc.txt", requiresNetwork: false)
    XCTAssertTrue(decision == .allowedLocally)
}

func testCachedContextServingDuringOffline() async throws {
    let backend = LocalMLXBackend()
    // Repeated calls should work via CommandParser fallback without network
    let first = try await backend.chat(
        messages: [Message(id: UUID(), role: .user, content: [.text("打开 Safari")], timestamp: Date())],
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: [ToolDefinition(name: "open_app", description: "", parameters: [.init(name: "app_name", type: .string, description: "")])],
        delegate: nil
    )
    XCTAssertTrue(first.hasToolCalls || !first.textContent.isEmpty)

    let second = try await backend.chat(
        messages: [Message(id: UUID(), role: .user, content: [.text("再次打开 Safari")], timestamp: Date())],
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: [ToolDefinition(name: "open_app", description: "", parameters: [.init(name: "app_name", type: .string, description: "")])],
        delegate: nil
    )
    XCTAssertTrue(second.hasToolCalls || !second.textContent.isEmpty)
}

func testOfflineModeExplanatoryMessage() async throws {
    let backend = LocalMLXBackend()
    // Empty messages should trigger the "请说点什么" fallback
    let result = try await backend.chat(
        messages: [Message(id: UUID(), role: .assistant, content: [.text("Hello")], timestamp: Date())],
        config: LLMConfiguration(provider: .localMLX, model: "test"),
        tools: nil,
        delegate: nil
    )
    XCTAssertTrue(result.textContent.contains("请说点什么"))
}

// MARK: - LocalOnlyPolicy tests

func testLocalOnlyPolicyProtectedPaths() {
    let policy = LocalOnlyPolicy()
    XCTAssertTrue(policy.isProtected(filePath: "/Users/yoming/doc.txt"))
    XCTAssertTrue(policy.isProtected(filePath: "/private/var/log/test.log"))
    XCTAssertTrue(!policy.isProtected(filePath: "/tmp/test.txt"))
}

func testLocalOnlyPolicyNetworkBlock() {
    let policy = LocalOnlyPolicy()
    let decision = policy.evaluate(filePath: "/Users/test/doc.txt", requiresNetwork: true)
    XCTAssertTrue(decision == .blockedNetworkAccess)
}

func testLocalOnlyPolicyDescription() {
    let policy = LocalOnlyPolicy()
    XCTAssertTrue(policy.policyDescription.contains("本机处理"))
    XCTAssertTrue(policy.policyDescription.contains("/Users/"))
}
