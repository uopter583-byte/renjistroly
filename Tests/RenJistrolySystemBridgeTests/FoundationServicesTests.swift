import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolySystemBridge

// MARK: - FeedbackCenter.classify

func testClassifySpeechRecognition() async {
    let store = FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("foundation_test_\(UUID().uuidString.prefix(8))"))
    let center = FeedbackCenter(store: store)
    let r1 = await center.classify("听不懂你在说什么")
    XCTAssertTrue(r1 == .speechRecognition)
    let r2 = await center.classify("没听懂")
    XCTAssertTrue(r2 == .speechRecognition)
    let r3 = await center.classify("识别错了")
    XCTAssertTrue(r3 == .speechRecognition)
    let r4 = await center.classify("转写错误")
    XCTAssertTrue(r4 == .speechRecognition)
}

func testClassifyModelResponse() async {
    let store = FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("foundation_test_\(UUID().uuidString.prefix(8))"))
    let center = FeedbackCenter(store: store)
    let r1 = await center.classify("没回答我的问题")
    XCTAssertTrue(r1 == .modelResponse)
    let r2 = await center.classify("回答错了")
    XCTAssertTrue(r2 == .modelResponse)
    let r3 = await center.classify("胡说八道")
    XCTAssertTrue(r3 == .modelResponse)
    let r4 = await center.classify("这个不对")
    XCTAssertTrue(r4 == .modelResponse)
}

func testClassifyActionExecution() async {
    let store = FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("foundation_test_\(UUID().uuidString.prefix(8))"))
    let center = FeedbackCenter(store: store)
    let r1 = await center.classify("打不开 Safari")
    XCTAssertTrue(r1 == .actionExecution)
    let r2 = await center.classify("没打开文件")
    XCTAssertTrue(r2 == .actionExecution)
    let r3 = await center.classify("没执行命令")
    XCTAssertTrue(r3 == .actionExecution)
    let r4 = await center.classify("不能控制")
    XCTAssertTrue(r4 == .actionExecution)
    let r5 = await center.classify("无法帮我打开")
    XCTAssertTrue(r5 == .actionExecution)
}

func testClassifyPermission() async {
    let store = FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("foundation_test_\(UUID().uuidString.prefix(8))"))
    let center = FeedbackCenter(store: store)
    let r1 = await center.classify("授权失败")
    XCTAssertTrue(r1 == .permission)
    let r2 = await center.classify("权限不够")
    XCTAssertTrue(r2 == .permission)
    let r3 = await center.classify("未授权")
    XCTAssertTrue(r3 == .permission)
}

func testClassifyScreenUnderstanding() async {
    let store = FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("foundation_test_\(UUID().uuidString.prefix(8))"))
    let center = FeedbackCenter(store: store)
    let r1 = await center.classify("看不到屏幕内容")
    XCTAssertTrue(r1 == .screenUnderstanding)
    let r2 = await center.classify("读屏不准")
    XCTAssertTrue(r2 == .screenUnderstanding)
    let r3 = await center.classify("屏幕识别有问题")
    XCTAssertTrue(r3 == .screenUnderstanding)
    let r4 = await center.classify("ocr 不行")
    XCTAssertTrue(r4 == .screenUnderstanding)
}

func testClassifyProvider() async {
    let store = FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("foundation_test_\(UUID().uuidString.prefix(8))"))
    let center = FeedbackCenter(store: store)
    let r1 = await center.classify("deepseek 连不上")
    XCTAssertTrue(r1 == .provider)
    let r2 = await center.classify("openai key 无效")
    XCTAssertTrue(r2 == .provider)
    let r3 = await center.classify("qwen 模型")
    XCTAssertTrue(r3 == .provider)
    let r4 = await center.classify("api 超时")
    XCTAssertTrue(r4 == .provider)
}

func testClassifyPerformance() async {
    let store = FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("foundation_test_\(UUID().uuidString.prefix(8))"))
    let center = FeedbackCenter(store: store)
    let r1 = await center.classify("太慢了")
    XCTAssertTrue(r1 == .performance)
    let r2 = await center.classify("很卡")
    XCTAssertTrue(r2 == .performance)
    let r3 = await center.classify("延迟很高")
    XCTAssertTrue(r3 == .performance)
}

func testClassifyUI() async {
    let store = FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("foundation_test_\(UUID().uuidString.prefix(8))"))
    let center = FeedbackCenter(store: store)
    let r1 = await center.classify("按钮点不了")
    XCTAssertTrue(r1 == .ui)
    let r2 = await center.classify("界面很乱")
    XCTAssertTrue(r2 == .ui)
    let r3 = await center.classify("快捷键不好用")
    XCTAssertTrue(r3 == .ui)
}

func testClassifyUpgrade() async {
    let store = FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("foundation_test_\(UUID().uuidString.prefix(8))"))
    let center = FeedbackCenter(store: store)
    let r1 = await center.classify("升级失败")
    XCTAssertTrue(r1 == .upgrade)
    let r2 = await center.classify("恢复不了")
    XCTAssertTrue(r2 == .upgrade)
    let r3 = await center.classify("回滚")
    XCTAssertTrue(r3 == .upgrade)
    let r4 = await center.classify("发布")
    XCTAssertTrue(r4 == .upgrade)
}

func testClassifyUnknown() async {
    let store = FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("foundation_test_\(UUID().uuidString.prefix(8))"))
    let center = FeedbackCenter(store: store)
    let r1 = await center.classify("今天天气不错")
    XCTAssertTrue(r1 == .unknown)
    let r2 = await center.classify("hello world")
    XCTAssertTrue(r2 == .unknown)
    let r3 = await center.classify("")
    XCTAssertTrue(r3 == .unknown)
}

func testClassifyFirstMatchWins() async {
    let store = FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("foundation_test_\(UUID().uuidString.prefix(8))"))
    let center = FeedbackCenter(store: store)
    let r1 = await center.classify("听不懂而且很慢")
    XCTAssertTrue(r1 == .speechRecognition)
}

// MARK: - FoundationHealthCenter.snapshots

func testSnapshotsAllOK() async {
    let center = FoundationHealthCenter()
    let permissions: [PermissionSnapshot] = [
        PermissionSnapshot(kind: .microphone, status: .granted),
        PermissionSnapshot(kind: .speechRecognition, status: .granted),
        PermissionSnapshot(kind: .accessibility, status: .granted),
        PermissionSnapshot(kind: .screenRecording, status: .granted),
    ]
    let evidence = FoundationCapabilityEvidence(
        terminalTaskCount: 1,
        hasRunningOrCompletedTerminalTask: true,
        lastObservationTargetCount: 15,
        lastObservationAccessibilityTargetCount: 10,
        lastActionWasVerified: true,
        memoryCount: 5,
        providerHealthCount: 3
    )
    let snapshots = await center.snapshots(
        permissions: permissions,
        provider: "Anthropic",
        hasBaseBackup: true,
        lastDiagnostic: nil,
        isConversationMode: true,
        evidence: evidence
    )
    XCTAssertTrue(snapshots.count == FoundationLayer.allCases.count)
    XCTAssertTrue(snapshots.first(where: { $0.layer == .localActionExecution })?.status == .ok)
    XCTAssertTrue(snapshots.first(where: { $0.layer == .userMemory })?.status == .ok)
    XCTAssertTrue(snapshots.first(where: { $0.layer == .providerAbstraction })?.status == .ok)
}

func testSnapshotsWarnings() async {
    let center = FoundationHealthCenter()
    let snapshots = await center.snapshots(
        permissions: [],
        provider: "OpenAI",
        hasBaseBackup: false,
        lastDiagnostic: nil,
        isConversationMode: false,
        evidence: FoundationCapabilityEvidence()
    )
    XCTAssertTrue(snapshots.first(where: { $0.layer == .selfOptimizationRecovery })?.status == .warning)
    XCTAssertTrue(snapshots.first(where: { $0.layer == .realtimeVoice })?.status == .warning)
    XCTAssertTrue(snapshots.first(where: { $0.layer == .userMemory })?.status == .warning)
    XCTAssertTrue(snapshots.first(where: { $0.layer == .feedbackLoop })?.status == .warning)
}

func testSnapshotsFailingPermissions() async {
    let center = FoundationHealthCenter()
    let capabilities: [FullAccessCapabilitySnapshot] = [
        FullAccessCapabilitySnapshot(kind: .stableIdentity, status: .failing, detail: "签名不匹配"),
    ]
    let snapshots = await center.snapshots(
        permissions: [],
        fullAccessCapabilities: capabilities,
        provider: "Anthropic",
        hasBaseBackup: true,
        lastDiagnostic: nil,
        isConversationMode: false,
        evidence: FoundationCapabilityEvidence()
    )
    XCTAssertTrue(snapshots.first(where: { $0.layer == .permissionIdentity })?.status == .failing)
}

func testSnapshotsWithDiagnostic() async {
    let center = FoundationHealthCenter()
    let diagnostic = AssistantDiagnosticSnapshot(
        userText: "测试输入",
        assistantText: "测试回复",
        provider: "Anthropic"
    )
    let snapshots = await center.snapshots(
        permissions: [],
        provider: "Anthropic",
        hasBaseBackup: true,
        lastDiagnostic: diagnostic,
        isConversationMode: false,
        evidence: FoundationCapabilityEvidence()
    )
    XCTAssertTrue(snapshots.first(where: { $0.layer == .feedbackLoop })?.status == .ok)
    XCTAssertTrue(snapshots.first(where: { $0.layer == .diagnostics })?.status == .ok)
}

func testSnapshotsScreenUnderstandingWithAX() async {
    let center = FoundationHealthCenter()
    let evidence = FoundationCapabilityEvidence(
        lastObservationTargetCount: 12,
        lastObservationAccessibilityTargetCount: 8
    )
    let snapshots = await center.snapshots(
        permissions: [],
        provider: "Anthropic",
        hasBaseBackup: true,
        lastDiagnostic: nil,
        isConversationMode: false,
        evidence: evidence
    )
    let screen = snapshots.first(where: { $0.layer == .screenUnderstanding })
    XCTAssertTrue(screen?.status == .ok)
}

func testSnapshotsScreenUnderstandingNoAX() async {
    let center = FoundationHealthCenter()
    let snapshots = await center.snapshots(
        permissions: [],
        provider: "Anthropic",
        hasBaseBackup: true,
        lastDiagnostic: nil,
        isConversationMode: false,
        evidence: FoundationCapabilityEvidence(lastObservationTargetCount: 5)
    )
    let screen = snapshots.first(where: { $0.layer == .screenUnderstanding })
    XCTAssertTrue(screen?.status == .warning)
}

// MARK: - ScenarioAuditEngine.audit

func testAuditBasicScenarios() {
    let engine = ScenarioAuditEngine()
    let permissions: [PermissionSnapshot] = [
        PermissionSnapshot(kind: .microphone, status: .granted),
        PermissionSnapshot(kind: .speechRecognition, status: .granted),
        PermissionSnapshot(kind: .accessibility, status: .granted),
        PermissionSnapshot(kind: .screenRecording, status: .granted),
    ]
    let report = engine.audit(
        permissions: permissions,
        fullAccessCapabilities: [FullAccessCapabilitySnapshot(kind: .stableIdentity, status: .ok, detail: "身份稳定")],
        evidence: FoundationCapabilityEvidence(lastObservationTargetCount: 10, lastObservationAccessibilityTargetCount: 5),
        diagnostics: [],
        terminalTasks: [],
        providerHealth: []
    )
    XCTAssertFalse(report.items.isEmpty)
    XCTAssertTrue(report.items.contains(where: { $0.id == "startup.identity" }))
    XCTAssertTrue(report.items.contains(where: { $0.id == "voice.asr" }))
    XCTAssertTrue(report.items.contains(where: { $0.id == "screen.ax" }))
}

func testAuditWithTerminalProof() {
    let engine = ScenarioAuditEngine()
    let task = TerminalTaskRecord(
        name: "swift test", command: "swift test", workingDirectory: "/tmp",
        status: .succeeded, exitCode: 0
    )
    let report = engine.audit(
        permissions: [],
        fullAccessCapabilities: [],
        evidence: FoundationCapabilityEvidence(),
        diagnostics: [],
        terminalTasks: [task],
        providerHealth: []
    )
    let terminalItem = report.items.first(where: { $0.id == "terminal.tasks" })
    XCTAssertTrue(terminalItem?.status == .verified)
}

func testAuditWithDiagnostics() {
    let engine = ScenarioAuditEngine()
    let diagnostic = AssistantDiagnosticSnapshot(userText: "test", assistantText: "reply", provider: "Anthropic")
    let report = engine.audit(
        permissions: [],
        fullAccessCapabilities: [],
        evidence: FoundationCapabilityEvidence(),
        diagnostics: [diagnostic],
        terminalTasks: [],
        providerHealth: []
    )
    let selfDiag = report.items.first(where: { $0.id == "self.diagnostics" })
    XCTAssertTrue(selfDiag?.status == .verified)
}

// MARK: - FoundationStore CRUD

func testFoundationStoreLoadDefault() async {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fs_test_\(UUID().uuidString.prefix(8))")
    let store = FoundationStore(directory: dir)
    let defaultMemories: [UserOperationMemory] = [
        UserOperationMemory(key: "default", value: "v", category: "test"),
    ]
    let loaded = await store.load([UserOperationMemory].self, from: "nonexistent.json", default: defaultMemories)
    XCTAssertTrue(loaded.count == 1)
    XCTAssertTrue(loaded[0].key == "default")
}

func testFoundationStoreSaveAndLoad() async {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fs_test_\(UUID().uuidString.prefix(8))")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = FoundationStore(directory: dir)
    let memories: [UserOperationMemory] = [
        UserOperationMemory(key: "k1", value: "v1", category: "test"),
        UserOperationMemory(key: "k2", value: "v2", category: "test"),
    ]
    await store.save(memories, to: "test.json")
    let loaded = await store.load([UserOperationMemory].self, from: "test.json", default: [])
    XCTAssertTrue(loaded.count == 2)
    XCTAssertTrue(loaded[0].key == "k1")
}

func testFoundationStoreAppend() async {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fs_test_\(UUID().uuidString.prefix(8))")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = FoundationStore(directory: dir)
    let m1 = UserOperationMemory(key: "a", value: "1", category: "t")
    let m2 = UserOperationMemory(key: "b", value: "2", category: "t")
    await store.append(m1, to: "append_test.json")
    await store.append(m2, to: "append_test.json")
    let loaded = await store.load([UserOperationMemory].self, from: "append_test.json", default: [])
    XCTAssertTrue(loaded.count == 2)
    XCTAssertTrue(loaded[0].key == "b") // newest first
}

func testFoundationStoreAppendRespectsLimit() async {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fs_test_\(UUID().uuidString.prefix(8))")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = FoundationStore(directory: dir)
    for i in 0..<10 {
        await store.append(UserOperationMemory(key: "k\(i)", value: "v", category: "t"), to: "limit_test.json", keeping: 3)
    }
    let loaded = await store.load([UserOperationMemory].self, from: "limit_test.json", default: [])
    XCTAssertTrue(loaded.count == 3)
}

// MARK: - UserOperationMemoryStore

func testMemoryRememberAndRecall() async {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mem_test_\(UUID().uuidString.prefix(8))")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = FoundationStore(directory: dir)
    let memStore = UserOperationMemoryStore(store: store)

    await memStore.remember(key: "Safari", value: "浏览器", category: "app")
    let recalled = await memStore.recall(key: "safari")
    XCTAssertTrue(recalled != nil)
    XCTAssertTrue(recalled?.value == "浏览器")
    XCTAssertTrue(recalled?.category == "app")
}

func testMemoryRecallNoMatch() async {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mem_test_\(UUID().uuidString.prefix(8))")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = FoundationStore(directory: dir)
    let memStore = UserOperationMemoryStore(store: store)

    await memStore.remember(key: "Chrome", value: "浏览器", category: "app")
    let recalled = await memStore.recall(key: "Safari")
    XCTAssertTrue(recalled == nil)
}

func testMemoryRememberUpserts() async {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mem_test_\(UUID().uuidString.prefix(8))")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = FoundationStore(directory: dir)
    let memStore = UserOperationMemoryStore(store: store)

    await memStore.remember(key: "Finder", value: "文件管理", category: "app", confidence: 0.5)
    await memStore.remember(key: "Finder", value: "文件管理器v2", category: "app", confidence: 0.9)
    let all = await memStore.all()
    XCTAssertTrue(all.count == 1)
    XCTAssertTrue(all[0].value == "文件管理器v2")
    XCTAssertTrue(all[0].confidence == 0.9)
}

func testMemoryRecallWithCategoryFilter() async {
    let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("mem_test_\(UUID().uuidString.prefix(8))")
    defer { try? FileManager.default.removeItem(at: dir) }
    let store = FoundationStore(directory: dir)
    let memStore = UserOperationMemoryStore(store: store)

    await memStore.remember(key: "login", value: "admin", category: "credentials")
    await memStore.remember(key: "login", value: "user", category: "profile")

    let cred = await memStore.recall(key: "login", category: "credentials")
    XCTAssertTrue(cred?.value == "admin")

    let prof = await memStore.recall(key: "login", category: "profile")
    XCTAssertTrue(prof?.value == "user")

    // No category filter returns first match
    let any = await memStore.recall(key: "login")
    XCTAssertTrue(any != nil)
}
