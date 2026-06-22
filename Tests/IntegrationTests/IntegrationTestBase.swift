import XCTest
import ApplicationServices
@testable import RenJistrolyModels
@testable import RenJistrolySystemBridge
@testable import RenJistrolyEnterprise

// MARK: - 集成测试基类
//
// 提供集成测试的共享基础设施：
//  - 环境设置 / 清理
//  - Mock 与服务注入
//  - 超时控制
//  - 错误收集与断言辅助
//  - 屏幕 / AX 权限检查
//
// 所有集成测试应继承此类。

// MARK: - Test Environment

public enum TestEnvironment: String, Sendable {
    case local
    case ci
    case staging
}

// MARK: - Integration Test Config

public struct IntegrationTestConfig: Sendable {
    public let environment: TestEnvironment
    public let defaultTimeout: TimeInterval
    public let actionTimeout: TimeInterval
    public let pollInterval: TimeInterval
    public let captureScreenshotOnFailure: Bool
    public let cleanupTempDir: Bool

    public static let `default` = IntegrationTestConfig(
        environment: ProcessInfo.processInfo.environment["CI"] != nil ? .ci : .local,
        defaultTimeout: 15.0,
        actionTimeout: 30.0,
        pollInterval: 0.5,
        captureScreenshotOnFailure: true,
        cleanupTempDir: true
    )

    public static let aggressive = IntegrationTestConfig(
        environment: .local,
        defaultTimeout: 5.0,
        actionTimeout: 10.0,
        pollInterval: 0.2,
        captureScreenshotOnFailure: false,
        cleanupTempDir: true
    )
}

// MARK: - Collected Error

public struct CapturedError: Identifiable, Sendable {
    public let id: String
    public let message: String
    public let file: StaticString
    public let line: UInt
    public let timestamp: Date

    public init(message: String, file: StaticString = #filePath, line: UInt = #line) {
        self.id = UUID().uuidString
        self.message = message
        self.file = file
        self.line = line
        self.timestamp = Date()
    }
}

// MARK: - Mock Registry

public final class MockRegistry: @unchecked Sendable {
    private var storage: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.renjistroly.test.mock-registry")

    public func register<T>(_ key: String, value: T) {
        queue.sync { storage[key] = value }
    }

    public func resolve<T>(_ key: String, as type: T.Type = T.self) -> T? {
        queue.sync { storage[key] as? T }
    }

    public func unregister(_ key: String) {
        _ = queue.sync { storage.removeValue(forKey: key) }
    }

    public func clear() {
        queue.sync { storage.removeAll() }
    }

    public var count: Int {
        queue.sync { storage.count }
    }
}

// MARK: - Integration Test Base

open class IntegrationTestBase: XCTestCase {

    // MARK: Configuration

    open var testConfig: IntegrationTestConfig { .default }

    // MARK: Shared Resources

    public let mockRegistry = MockRegistry()
    public private(set) var capturedErrors: [CapturedError] = []
    public private(set) var tempDirectory: URL?

    private var testStartTime: Date = .init()

    // MARK: Setup / Teardown

    open override func setUpWithError() throws {
        try super.setUpWithError()
        testStartTime = Date()
        capturedErrors = []
        mockRegistry.clear()

        // 创建临时目录
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("renjistroly-int-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: tempDirectory!,
            withIntermediateDirectories: true
        )

        try setUpEnvironment()
        try injectMocks()
    }

    open override func tearDownWithError() throws {
        if testConfig.cleanupTempDir, let tempDir = tempDirectory {
            try? FileManager.default.removeItem(at: tempDir)
        }
        tempDirectory = nil
        capturedErrors = []
        mockRegistry.clear()

        let elapsed = Date().timeIntervalSince(testStartTime)
        if elapsed > testConfig.defaultTimeout * 2 {
            print("[IntegrationTestBase] WARNING: Test took \(String(format: "%.1f", elapsed))s — consider reducing scope")
        }

        try super.tearDownWithError()
    }

    // MARK: - 环境设置

    /// 子类重写以配置测试环境
    open func setUpEnvironment() throws {
        // 默认实现 — 子类可扩展
    }

    /// 子类重写以注入 mock 对象
    open func injectMocks() throws {
        // 默认实现 — 子类可扩展
    }

    // MARK: - 超时控制

    /// 等待条件为真，带超时
    public func waitFor(
        timeout: TimeInterval? = nil,
        pollInterval: TimeInterval? = nil,
        description: String = "等待条件满足",
        condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout ?? testConfig.defaultTimeout)
        let interval = pollInterval ?? testConfig.pollInterval

        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(interval))
        }
        return condition() // 最后一次检查
    }

    /// 异步等待条件为真，带超时
    public func waitForAsync(
        timeout: TimeInterval? = nil,
        pollInterval: TimeInterval? = nil,
        description: String = "等待异步条件满足",
        condition: @escaping () async -> Bool
    ) async -> Bool {
        let deadline = DispatchTime.now() + .seconds(Int(timeout ?? testConfig.defaultTimeout))
        let intervalNs = UInt64((pollInterval ?? testConfig.pollInterval) * 1_000_000_000)

        while DispatchTime.now() < deadline {
            if await condition() { return true }
            try? await Task.sleep(nanoseconds: intervalNs)
        }
        return await condition()
    }

    // MARK: - 错误收集

    public func captureError(
        _ message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let error = CapturedError(message: message, file: file, line: line)
        capturedErrors.append(error)
    }

    /// 收集所有错误并断言无错误
    public func assertNoCapturedErrors(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if !capturedErrors.isEmpty {
            let descriptions = capturedErrors.map {
                "[\($0.timestamp)] \($0.message) (\($0.file):\($0.line))"
            }.joined(separator: "\n  ")
            XCTFail("捕获了 \(capturedErrors.count) 个错误:\n  \(descriptions)", file: file, line: line)
        }
    }

    // MARK: - Mock 辅助

    public func withMock<T>(_ key: String, value: T, block: () throws -> T?) rethrows -> T? {
        mockRegistry.register(key, value: value)
        let result = try block()
        mockRegistry.unregister(key)
        return result
    }

    // MARK: - 临时文件辅助

    public func createTempFile(
        name: String = "test-\(UUID().uuidString).tmp",
        content: Data = Data()
    ) throws -> URL {
        guard let tempDir = tempDirectory else {
            throw IntegrationTestError.missingTempDirectory
        }
        let url = tempDir.appendingPathComponent(name)
        try content.write(to: url)
        return url
    }

    public func createTempDirectory(
        name: String = "tmp-\(UUID().uuidString)"
    ) throws -> URL {
        guard let tempDir = tempDirectory else {
            throw IntegrationTestError.missingTempDirectory
        }
        let url = tempDir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - 权限检查

    /// 检查是否拥有运行集成测试所需的基本权限
    public func requireMinimalPermissions() throws {
        // 在 CI 环境跳过权限检查
        guard testConfig.environment != .ci else { return }

        let axEnabled = AXIsProcessTrusted()
        if !axEnabled {
            print("[IntegrationTestBase] WARNING: 辅助功能权限未授予 — 某些 AX 测试可能失败")
        }
    }
}

// MARK: - Errors

public enum IntegrationTestError: Error, LocalizedError {
    case missingTempDirectory
    case mockNotFound(String)
    case timeoutWaiting(String)
    case environmentNotReady(String)
    case permissionDenied(String)

    public var errorDescription: String? {
        switch self {
        case .missingTempDirectory:
            return "临时目录未创建。请确保 setUpWithError 调用了 super.setUpWithError()"
        case .mockNotFound(let key):
            return "Mock 未注册: \(key)"
        case .timeoutWaiting(let description):
            return "超时等待: \(description)"
        case .environmentNotReady(let detail):
            return "环境未就绪: \(detail)"
        case .permissionDenied(let permission):
            return "权限被拒绝: \(permission)"
        }
    }
}

// MARK: - Test Observer (用于集成测试的额外日志)

public final class IntegrationTestObserver: NSObject, XCTestObservation {
    public override init() {
        super.init()
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    deinit {
        XCTestObservationCenter.shared.removeTestObserver(self)
    }

    public func testCase(_ testCase: XCTestCase,
                         didFailWithDescription description: String,
                         inFile filePath: String?,
                         atLine lineNumber: Int) {
        print("[IntegrationTestObserver] FAIL: \(testCase.name) — \(description)")
    }
}

// MARK: - 注入扩展

extension IntegrationTestBase {
    /// 安全地解析 mock，失败时抛出
    public func requireMock<T>(_ key: String, as type: T.Type = T.self) throws -> T {
        guard let value: T = mockRegistry.resolve(key) else {
            throw IntegrationTestError.mockNotFound(key)
        }
        return value
    }
}
