import Foundation

// MARK: - Dev Context Snapshots (546-555)

public struct RepoContextSnapshot: Sendable, Codable, Equatable {
    public let rootPath: String?
    public let name: String?
    public let remoteURL: String?
    public let isDirty: Bool
    public let fileCount: Int

    public init(
        rootPath: String? = nil,
        name: String? = nil,
        remoteURL: String? = nil,
        isDirty: Bool = false,
        fileCount: Int = 0
    ) {
        self.rootPath = rootPath
        self.name = name
        self.remoteURL = remoteURL
        self.isDirty = isDirty
        self.fileCount = fileCount
    }
}

public struct BranchContextSnapshot: Sendable, Codable, Equatable {
    public let currentBranch: String?
    public let baseBranch: String?
    public let aheadCount: Int
    public let behindCount: Int
    public let hasUnpushed: Bool

    public init(
        currentBranch: String? = nil,
        baseBranch: String? = nil,
        aheadCount: Int = 0,
        behindCount: Int = 0,
        hasUnpushed: Bool = false
    ) {
        self.currentBranch = currentBranch
        self.baseBranch = baseBranch
        self.aheadCount = aheadCount
        self.behindCount = behindCount
        self.hasUnpushed = hasUnpushed
    }
}

public struct DiffContextSnapshot: Sendable, Codable, Equatable {
    public let unstagedCount: Int
    public let stagedCount: Int
    public let untrackedCount: Int
    public let totalChanges: Int
    public let changedFiles: [String]
    public let diffStat: String?

    public init(
        unstagedCount: Int = 0,
        stagedCount: Int = 0,
        untrackedCount: Int = 0,
        totalChanges: Int = 0,
        changedFiles: [String] = [],
        diffStat: String? = nil
    ) {
        self.unstagedCount = unstagedCount
        self.stagedCount = stagedCount
        self.untrackedCount = untrackedCount
        self.totalChanges = totalChanges
        self.changedFiles = changedFiles
        self.diffStat = diffStat
    }
}

public struct TestStateSnapshot: Sendable, Codable, Equatable {
    public let totalTests: Int
    public let passedTests: Int
    public let failedTests: Int
    public let skippedTests: Int
    public let duration: TimeInterval?
    public let failingTestNames: [String]

    public var passRate: Double {
        guard totalTests > 0 else { return 1.0 }
        return Double(passedTests) / Double(totalTests)
    }

    public init(
        totalTests: Int = 0,
        passedTests: Int = 0,
        failedTests: Int = 0,
        skippedTests: Int = 0,
        duration: TimeInterval? = nil,
        failingTestNames: [String] = []
    ) {
        self.totalTests = totalTests
        self.passedTests = passedTests
        self.failedTests = failedTests
        self.skippedTests = skippedTests
        self.duration = duration
        self.failingTestNames = failingTestNames
    }
}

public struct BuildStateSnapshot: Sendable, Codable, Equatable {
    public let isBuilding: Bool
    public let lastBuildSuccess: Bool?
    public let lastBuildDuration: TimeInterval?
    public let errors: [String]
    public let warnings: [String]
    public let configuration: String

    public init(
        isBuilding: Bool = false,
        lastBuildSuccess: Bool? = nil,
        lastBuildDuration: TimeInterval? = nil,
        errors: [String] = [],
        warnings: [String] = [],
        configuration: String = "debug"
    ) {
        self.isBuilding = isBuilding
        self.lastBuildSuccess = lastBuildSuccess
        self.lastBuildDuration = lastBuildDuration
        self.errors = errors
        self.warnings = warnings
        self.configuration = configuration
    }
}

public struct CIStateSnapshot: Sendable, Codable, Equatable {
    public let hasActivePipeline: Bool
    public let latestStatus: String?
    public let latestRunID: String?
    public let branch: String?
    public let commitSHA: String?

    public init(
        hasActivePipeline: Bool = false,
        latestStatus: String? = nil,
        latestRunID: String? = nil,
        branch: String? = nil,
        commitSHA: String? = nil
    ) {
        self.hasActivePipeline = hasActivePipeline
        self.latestStatus = latestStatus
        self.latestRunID = latestRunID
        self.branch = branch
        self.commitSHA = commitSHA
    }
}

public struct IssueContextSnapshot: Sendable, Codable, Equatable {
    public let issueNumber: Int?
    public let title: String?
    public let state: String?
    public let assignee: String?
    public let labels: [String]
    public let url: String?

    public init(
        issueNumber: Int? = nil,
        title: String? = nil,
        state: String? = nil,
        assignee: String? = nil,
        labels: [String] = [],
        url: String? = nil
    ) {
        self.issueNumber = issueNumber
        self.title = title
        self.state = state
        self.assignee = assignee
        self.labels = labels
        self.url = url
    }
}

public struct PRContextSnapshot: Sendable, Codable, Equatable {
    public let prNumber: Int?
    public let title: String?
    public let state: String?
    public let sourceBranch: String?
    public let targetBranch: String?
    public let hasConflicts: Bool
    public let reviewStatus: String?
    public let url: String?

    public init(
        prNumber: Int? = nil,
        title: String? = nil,
        state: String? = nil,
        sourceBranch: String? = nil,
        targetBranch: String? = nil,
        hasConflicts: Bool = false,
        reviewStatus: String? = nil,
        url: String? = nil
    ) {
        self.prNumber = prNumber
        self.title = title
        self.state = state
        self.sourceBranch = sourceBranch
        self.targetBranch = targetBranch
        self.hasConflicts = hasConflicts
        self.reviewStatus = reviewStatus
        self.url = url
    }
}

public struct FileContextSnapshot: Sendable, Codable, Equatable {
    public let filePath: String?
    public let fileName: String?
    public let fileExtension: String?
    public let lineCount: Int
    public let sizeBytes: Int64
    public let language: String?
    public let isModified: Bool

    public init(
        filePath: String? = nil,
        fileName: String? = nil,
        fileExtension: String? = nil,
        lineCount: Int = 0,
        sizeBytes: Int64 = 0,
        language: String? = nil,
        isModified: Bool = false
    ) {
        self.filePath = filePath
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.lineCount = lineCount
        self.sizeBytes = sizeBytes
        self.language = language
        self.isModified = isModified
    }
}

public struct SymbolContextSnapshot: Sendable, Codable, Equatable {
    public let symbolName: String?
    public let symbolKind: String?
    public let filePath: String?
    public let lineNumber: Int
    public let columnNumber: Int

    public init(
        symbolName: String? = nil,
        symbolKind: String? = nil,
        filePath: String? = nil,
        lineNumber: Int = 0,
        columnNumber: Int = 0
    ) {
        self.symbolName = symbolName
        self.symbolKind = symbolKind
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.columnNumber = columnNumber
    }
}

// MARK: - Dev Context

public struct DevContext: Sendable, Codable, Equatable {
    public let repo: RepoContextSnapshot
    public let branch: BranchContextSnapshot
    public let diff: DiffContextSnapshot
    public let testState: TestStateSnapshot
    public let buildState: BuildStateSnapshot
    public let ciState: CIStateSnapshot
    public let issue: IssueContextSnapshot
    public let pr: PRContextSnapshot
    public let file: FileContextSnapshot
    public let symbol: SymbolContextSnapshot
    public let capturedAt: Date

    public init(
        repo: RepoContextSnapshot = .init(),
        branch: BranchContextSnapshot = .init(),
        diff: DiffContextSnapshot = .init(),
        testState: TestStateSnapshot = .init(),
        buildState: BuildStateSnapshot = .init(),
        ciState: CIStateSnapshot = .init(),
        issue: IssueContextSnapshot = .init(),
        pr: PRContextSnapshot = .init(),
        file: FileContextSnapshot = .init(),
        symbol: SymbolContextSnapshot = .init(),
        capturedAt: Date = Date()
    ) {
        self.repo = repo
        self.branch = branch
        self.diff = diff
        self.testState = testState
        self.buildState = buildState
        self.ciState = ciState
        self.issue = issue
        self.pr = pr
        self.file = file
        self.symbol = symbol
        self.capturedAt = capturedAt
    }
}

// MARK: - Dev Context Provider protocol

public protocol DevContextProviderProtocol: AnyObject, Sendable {
    func captureRepoContext() async -> RepoContextSnapshot
    func captureBranchContext() async -> BranchContextSnapshot
    func captureDiffContext() async -> DiffContextSnapshot
    func captureTestState() async -> TestStateSnapshot
    func captureBuildState() async -> BuildStateSnapshot
    func captureCIState() async -> CIStateSnapshot
    func captureIssueContext() async -> IssueContextSnapshot
    func capturePRContext() async -> PRContextSnapshot
    func captureFileContext() async -> FileContextSnapshot
    func captureSymbolContext() async -> SymbolContextSnapshot
}

// MARK: - Dev Context Manager

@MainActor
public final class DevContextManager {
    public private(set) var lastContext: DevContext?
    public var provider: DevContextProviderProtocol?

    public init(provider: DevContextProviderProtocol? = nil) {
        self.provider = provider
    }

    public func refresh() async -> DevContext {
        let p = provider
        let ctx = DevContext(
            repo: await withTimeout(seconds: 10, defaultValue: .init()) { await p?.captureRepoContext() ?? .init() },
            branch: await withTimeout(seconds: 10, defaultValue: .init()) { await p?.captureBranchContext() ?? .init() },
            diff: await withTimeout(seconds: 10, defaultValue: .init()) { await p?.captureDiffContext() ?? .init() },
            testState: await withTimeout(seconds: 10, defaultValue: .init()) { await p?.captureTestState() ?? .init() },
            buildState: await withTimeout(seconds: 10, defaultValue: .init()) { await p?.captureBuildState() ?? .init() },
            ciState: await withTimeout(seconds: 10, defaultValue: .init()) { await p?.captureCIState() ?? .init() },
            issue: await withTimeout(seconds: 10, defaultValue: .init()) { await p?.captureIssueContext() ?? .init() },
            pr: await withTimeout(seconds: 10, defaultValue: .init()) { await p?.capturePRContext() ?? .init() },
            file: await withTimeout(seconds: 10, defaultValue: .init()) { await p?.captureFileContext() ?? .init() },
            symbol: await withTimeout(seconds: 10, defaultValue: .init()) { await p?.captureSymbolContext() ?? .init() }
        )
        lastContext = ctx
        return ctx
    }

    private func withTimeout<T: Sendable>(seconds: TimeInterval, defaultValue: T, operation: @escaping @Sendable () async -> T) async -> T {
        await withTaskGroup(of: T.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return defaultValue
            }
            let result = await group.next() ?? defaultValue
            group.cancelAll()
            return result
        }
    }

    public func snapshot() -> DevContext {
        lastContext ?? DevContext()
    }

    public func summary() -> String {
        let ctx = snapshot()
        var parts: [String] = ["=== 开发上下文 ==="]
        if let name = ctx.repo.name {
            parts.append("Repo: \(name)")
        }
        if let branch = ctx.branch.currentBranch {
            parts.append("分支: \(branch)")
        }
        if ctx.diff.totalChanges > 0 {
            parts.append("变更: \(ctx.diff.totalChanges) 文件")
        }
        if ctx.testState.totalTests > 0 {
            parts.append("测试: \(ctx.testState.passedTests)/\(ctx.testState.totalTests) 通过")
        }
        if let file = ctx.file.fileName {
            parts.append("文件: \(file)")
        }
        if let sym = ctx.symbol.symbolName {
            parts.append("符号: \(sym)")
        }
        return parts.joined(separator: "\n")
    }
}
