import Foundation

public struct BuildResult: Codable, Sendable, Hashable {
    public let success: Bool
    public let errors: [BuildDiagnostic]
    public let warnings: [BuildDiagnostic]
    public let durationSeconds: Double
    public let rawOutput: String
    public let timestamp: Date

    public init(
        success: Bool,
        errors: [BuildDiagnostic] = [],
        warnings: [BuildDiagnostic] = [],
        durationSeconds: Double = 0,
        rawOutput: String = "",
        timestamp: Date = Date()
    ) {
        self.success = success
        self.errors = errors
        self.warnings = warnings
        self.durationSeconds = durationSeconds
        self.rawOutput = rawOutput
        self.timestamp = timestamp
    }

    public var summary: String {
        if success {
            "构建成功 (\(String(format: "%.1f", durationSeconds))s)"
        } else {
            "构建失败: \(errors.count) 个错误, \(warnings.count) 个警告"
        }
    }
}

public struct BuildDiagnostic: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let filePath: String?
    public let line: Int?
    public let column: Int?
    public let message: String
    public let severity: Severity

    public enum Severity: String, Codable, Sendable, Hashable {
        case error
        case warning
        case note
    }

    public init(
        id: String = UUID().uuidString,
        filePath: String? = nil,
        line: Int? = nil,
        column: Int? = nil,
        message: String,
        severity: Severity
    ) {
        self.id = id
        self.filePath = filePath
        self.line = line
        self.column = column
        self.message = message
        self.severity = severity
    }
}

public struct TestResult: Codable, Sendable, Hashable {
    public let success: Bool
    public let totalCount: Int
    public let passedCount: Int
    public let failedCount: Int
    public let durationSeconds: Double
    public let failures: [TestFailure]
    public let rawOutput: String
    public let timestamp: Date

    public init(
        success: Bool,
        totalCount: Int = 0,
        passedCount: Int = 0,
        failedCount: Int = 0,
        durationSeconds: Double = 0,
        failures: [TestFailure] = [],
        rawOutput: String = "",
        timestamp: Date = Date()
    ) {
        self.success = success
        self.totalCount = totalCount
        self.passedCount = passedCount
        self.failedCount = failedCount
        self.durationSeconds = durationSeconds
        self.failures = failures
        self.rawOutput = rawOutput
        self.timestamp = timestamp
    }

    public var summary: String {
        if success {
            "\(totalCount) 个测试全部通过 (\(String(format: "%.1f", durationSeconds))s)"
        } else {
            "\(failedCount)/\(totalCount) 失败 (\(String(format: "%.1f", durationSeconds))s)"
        }
    }
}

public struct TestFailure: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let testName: String
    public let message: String
    public let filePath: String?
    public let line: Int?

    public init(
        id: String = UUID().uuidString,
        testName: String,
        message: String,
        filePath: String? = nil,
        line: Int? = nil
    ) {
        self.id = id
        self.testName = testName
        self.message = message
        self.filePath = filePath
        self.line = line
    }
}

public struct DevModeState: Codable, Sendable, Hashable {
    public var isEnabled: Bool
    public var lastBuildResult: BuildResult?
    public var lastTestResult: TestResult?
    public var projectPath: String?
    public var claudeCodePath: String?

    public static let disabled = DevModeState(isEnabled: false)

    public init(
        isEnabled: Bool = false,
        lastBuildResult: BuildResult? = nil,
        lastTestResult: TestResult? = nil,
        projectPath: String? = nil,
        claudeCodePath: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.lastBuildResult = lastBuildResult
        self.lastTestResult = lastTestResult
        self.projectPath = projectPath
        self.claudeCodePath = claudeCodePath
    }
}
