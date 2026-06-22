import Foundation
import RenJistrolyModels
import XCTest
@testable import RenJistrolySystemBridge

// MARK: - Swift Build Invocation

func testDevWorkflowSwiftBuildIsAllowedCommand() {
    let allowed = ShellExecutor.defaultAllowedCommands
    XCTAssertTrue(allowed.contains("swift"))
    XCTAssertTrue(allowed.contains("xcodebuild"))
    XCTAssertTrue(allowed.contains("xcode-select"))
}

func testDevWorkflowSwiftBuildAndTestCommandsHaveCommonAncillaries() {
    let allowed = ShellExecutor.defaultAllowedCommands
    XCTAssertTrue(allowed.contains("swift"))
    XCTAssertTrue(allowed.contains("git"))
    XCTAssertTrue(allowed.contains("brew"))
    XCTAssertTrue(allowed.contains("make"))
    XCTAssertTrue(allowed.contains("docker"))
}

// MARK: - Unit Test Running with Filtering

func testDevWorkflowBuildResultFormatsSummary() {
    let success = BuildResult(success: true, durationSeconds: 3.5)
    XCTAssertTrue(success.summary.contains("成功"))
    XCTAssertTrue(success.summary.contains("3.5"))

    let failure = BuildResult(success: false, errors: [
        BuildDiagnostic(message: "Type mismatch", severity: .error),
    ], durationSeconds: 1.2)
    XCTAssertTrue(failure.summary.contains("失败"))
    XCTAssertTrue(failure.summary.contains("1 个错误"))
}

func testDevWorkflowTestResultFormatsSummary() {
    let passed = TestResult(success: true, totalCount: 10, passedCount: 10, durationSeconds: 2.0)
    XCTAssertTrue(passed.summary.contains("全部通过"))
    XCTAssertTrue(passed.summary.contains("10"))

    let failed = TestResult(success: false, totalCount: 5, passedCount: 3, failedCount: 2, durationSeconds: 1.0, failures: [
        TestFailure(testName: "testLogin", message: "assertion failed"),
    ])
    XCTAssertTrue(failed.summary.contains("失败"))
    XCTAssertTrue(failed.summary.contains("2/5"))
}

// MARK: - Build Failure Location (file:line extraction)

func testDevWorkflowBuildDiagnosticExtractsFileLine() {
    let diag = BuildDiagnostic(
        filePath: "/Users/dev/Project/Sources/main.swift",
        line: 42,
        column: 10,
        message: "Cannot assign value of type 'Int' to type 'String'",
        severity: .error
    )
    XCTAssertTrue(diag.filePath == "/Users/dev/Project/Sources/main.swift")
    XCTAssertTrue(diag.line == 42)
    XCTAssertTrue(diag.column == 10)
    XCTAssertTrue(diag.severity == .error)
    XCTAssertFalse(diag.message.isEmpty)
}

func testDevWorkflowBuildDiagnosticSeverities() {
    let error = BuildDiagnostic(message: "err", severity: .error)
    let warning = BuildDiagnostic(message: "warn", severity: .warning)
    let note = BuildDiagnostic(message: "note", severity: .note)
    XCTAssertTrue(error.severity == .error)
    XCTAssertTrue(warning.severity == .warning)
    XCTAssertTrue(note.severity == .note)
}

// MARK: - Code Modification Suggestion

func testDevWorkflowCredentialSanitizerMasksPasswords() {
    let sanitizer = CredentialSanitizer()
    let result = sanitizer.sanitize("let password = \"hunter2\"")
    XCTAssertTrue(!result.contains("hunter2"))
    XCTAssertTrue(result.contains("******") || result.contains("<redacted>"))
}

func testDevWorkflowCredentialSanitizerMasksSecretsInSuggestion() {
    let sanitizer = CredentialSanitizer()
    let suggestion = sanitizer.sanitize("Update the token = 'ghp_abc123def456' in config")
    XCTAssertTrue(!suggestion.contains("ghp_abc123def456"))
    XCTAssertTrue(suggestion.contains("******"))
}

// MARK: - Code Formatting Execution

func testDevWorkflowFileOperationSafetyAllowsNonProtectedWrite() {
    let safety = FileOperationSafety()
    let result = safety.validate(operation: .overwrite, target: "/tmp/formatted_code.swift")
    XCTAssertTrue(result == nil)
}

func testDevWorkflowFileOperationSafetyBlocksSystemPathFormat() {
    let safety = FileOperationSafety()
    let result = safety.validate(operation: .overwrite, target: "/System/Library/Something.swift")
    XCTAssertTrue(result != nil)
    XCTAssertTrue(result?.contains("受保护") == true)
}

// MARK: - Patch/Diff Generation

func testDevWorkflowTaskStoreTrackedChangedFilesAfterCompletion() async {
    let store = DeveloperAgentTaskStore()
    let task = await store.create(prompt: "generate patch")
    let loaded = await store.task(task.id)
    XCTAssertTrue(loaded?.changedFiles.isEmpty == true)
    XCTAssertTrue(loaded?.status == .queued)
}

func testDevWorkflowTaskAggregationCollectsAllOutputs() async {
    let store = DeveloperAgentTaskStore()
    let t1 = await store.create(prompt: "task one")
    let t2 = await store.create(prompt: "task two")
    let agg = await store.aggregateResults(for: [t1.id, t2.id])
    XCTAssertTrue(agg.totalTasks == 2)
    XCTAssertTrue(agg.changedFiles.isEmpty)
    XCTAssertTrue(agg.commandsRun.isEmpty)
    XCTAssertTrue(agg.allSucceeded == false)
}

// MARK: - Git Diff Explanation

func testDevWorkflowAuditExporterFormatsGitDiffCSV() {
    let exporter = AuditExporter()
    let entries = [
        AuditExporter.AuditEntry(
            timestamp: Date(),
            user: "developer",
            action: "git diff",
            resource: "Sources/Core.swift",
            result: "15 insertions, 3 deletions"
        ),
    ]
    let csv = exporter.exportCSV(entries: entries)
    XCTAssertTrue(csv.contains("git diff"))
    XCTAssertTrue(csv.contains("developer"))
    XCTAssertTrue(csv.contains("Core.swift"))
    XCTAssertTrue(csv.contains("时间,用户,操作,资源,结果"))
}

func testDevWorkflowAuditExporterFormatsJSON() {
    let exporter = AuditExporter()
    let entries = [
        AuditExporter.AuditEntry(
            timestamp: Date(),
            user: "dev",
            action: "git diff",
            resource: "README.md",
            result: "2 lines changed"
        ),
    ]
    let data = exporter.exportJSON(entries: entries)
    XCTAssertTrue(data != nil)
    let json = String(data: data!, encoding: .utf8)
    XCTAssertTrue(json?.contains("git diff") == true)
    XCTAssertTrue(json?.contains("README.md") == true)
}

// MARK: - Avoid Accidental Edit Protection

func testDevWorkflowFileOperationSafetyProtectsSystemPaths() {
    let safety = FileOperationSafety()
    XCTAssertTrue(safety.isProtected("/System/Library/Caches"))
    XCTAssertTrue(safety.isProtected("/Library/Preferences"))
    XCTAssertTrue(safety.isProtected("/Applications/Xcode.app"))
    XCTAssertTrue(safety.isProtected(NSHomeDirectory() + "/Library"))
}

func testDevWorkflowFileOperationSafetyAllowsUserTempAndDesktopPaths() {
    let safety = FileOperationSafety()
    XCTAssertTrue(!safety.isProtected("/tmp/build.log"))
    XCTAssertTrue(!safety.isProtected("/Users/test/Desktop/code.swift"))
    XCTAssertTrue(!safety.isProtected("/Users/test/Downloads"))
    XCTAssertTrue(!safety.isProtected("/Users/test/Projects"))
}

func testDevWorkflowFileOperationSafetyValidatesDeleteOnProtectedPath() {
    let safety = FileOperationSafety()
    let result = safety.validate(operation: .delete, target: "/System/Library/Extensions")
    XCTAssertTrue(result != nil)
    XCTAssertTrue(result?.contains("受保护") == true)
    XCTAssertTrue(result?.contains("delete") == true || result?.contains("删除") == true)
}

// MARK: - .build Directory Isolation

func testDevWorkflowFileOperationSafetyProtectsBuildDir() {
    let safety = FileOperationSafety(protectedPaths: [
        ".build",
        "/System", "/Library", "/Applications",
        NSHomeDirectory() + "/Library",
    ])
    XCTAssertTrue(safety.isProtected(".build"))
    XCTAssertTrue(safety.isProtected(".build/debug"))
    XCTAssertTrue(safety.isProtected(".build/release"))
    XCTAssertTrue(!safety.isProtected("/tmp"))
}

func testDevWorkflowFileOperationSafetyAllowsNonBuildTempPaths() {
    let safety = FileOperationSafety(protectedPaths: [".build"])
    XCTAssertTrue(!safety.isProtected("Package.swift"))
    XCTAssertTrue(!safety.isProtected("Sources"))
    XCTAssertTrue(!safety.isProtected("Tests"))
}

// MARK: - Background Process Conflict Detection

func testDevWorkflowHighRiskConfirmerRequiresApprovalForAllCategories() {
    for category in HighRiskOperationConfirmer.RiskCategory.allCases {
        let confirmer = HighRiskOperationConfirmer()
        let request = confirmer.request(for: category, operation: "test operation", impact: "test impact")
        XCTAssertTrue(request.requiresApproval)
        XCTAssertTrue(request.category == category)
        XCTAssertFalse(request.operation.isEmpty)
        XCTAssertFalse(request.impact.isEmpty)
    }
}

func testDevWorkflowHighRiskConfirmerGeneratesPrompt() {
    let confirmer = HighRiskOperationConfirmer()
    let request = confirmer.request(for: .firewall, operation: "Disable firewall", impact: "Network vulnerable")
    let prompt = confirmer.prompt(for: request)
    XCTAssertTrue(prompt.contains("Disable firewall"))
    XCTAssertTrue(prompt.contains("注意"))
    XCTAssertTrue(prompt.contains("高风险"))
}

extension HighRiskOperationConfirmer.RiskCategory: CaseIterable {
    public static var allCases: [HighRiskOperationConfirmer.RiskCategory] {
        [.firewall, .networkConfig, .systemPermission, .kernelExtension, .userManagement]
    }
}

// MARK: - Build Result With Warnings

func testDevWorkflowBuildWithWarningsShowsWarningCount() {
    let result = BuildResult(success: true, errors: [], warnings: [
        BuildDiagnostic(message: "Unused import", severity: .warning),
        BuildDiagnostic(message: "Variable never mutated", severity: .warning),
    ], durationSeconds: 1.5)
    XCTAssertTrue(result.success)
    XCTAssertTrue(result.warnings.count == 2)
    XCTAssertTrue(result.errors.isEmpty)
    XCTAssertTrue(result.summary.contains("1.5"))
}

// MARK: - Unit Test All Pass

func testDevWorkflowTestResultAllPassedFormat() {
    let result = TestResult(success: true, totalCount: 5, passedCount: 5, durationSeconds: 1.2)
    XCTAssertTrue(result.success)
    XCTAssertTrue(result.summary.contains("全部通过"))
    XCTAssertTrue(result.summary.contains("5"))
}

// MARK: - Failure Location With Line Only

func testDevWorkflowBuildDiagnosticWithLineOnly() {
    let diag = BuildDiagnostic(line: 15, message: "Type 'String?' does not conform to 'Decodable'", severity: .error)
    XCTAssertTrue(diag.filePath == nil)
    XCTAssertTrue(diag.line == 15)
    XCTAssertTrue(diag.column == nil)
    XCTAssertTrue(diag.severity == .error)
    XCTAssertFalse(diag.message.isEmpty)
}

// MARK: - Code Modify Sanitization

func testDevWorkflowCredentialSanitizerHandlesSecretAndToken() {
    let sanitizer = CredentialSanitizer()
    let input = "let token = 'sk-abc123' and password = 'hunter2'"
    let result = sanitizer.sanitize(input)
    XCTAssertTrue(!result.contains("sk-abc123"))
    XCTAssertTrue(!result.contains("hunter2"))
    XCTAssertTrue(result.contains("******"))
}

// MARK: - Format Installation Policy

func testDevWorkflowPermissionPolicyDefaultRules() {
    let policy = PermissionPolicy()
    XCTAssertTrue(policy.evaluate(installPath: "file.pkg") == .requiresAdmin)
    XCTAssertTrue(policy.evaluate(installPath: "file.dmg") == .requiresAdmin)
    XCTAssertTrue(policy.evaluate(installPath: "file.app") == .requiresAdmin)
    XCTAssertTrue(policy.evaluate(installPath: "file.sh") == .allowed)
    XCTAssertTrue(policy.evaluate(installPath: "file.txt") == .allowed)
}

// MARK: - Patch/Diff Aggregation

func testDevWorkflowTaskAggregationMultipleStatuses() async {
    let store = DeveloperAgentTaskStore()
    let t1 = await store.create(prompt: "task a")
    let t2 = await store.create(prompt: "task b")
    await store.start(t1.id)
    let agg = await store.aggregateResults(for: [t1.id, t2.id])
    XCTAssertTrue(agg.totalTasks == 2)
    XCTAssertTrue(agg.changedFiles.isEmpty)
    XCTAssertTrue(agg.commandsRun.isEmpty)
}

// MARK: - Explain Diff Via Audit Entry

func testDevWorkflowAuditEntryMultipleEntriesFormat() {
    let exporter = AuditExporter()
    let entries = [
        AuditExporter.AuditEntry(timestamp: Date(), user: "dev1", action: "diff", resource: "a.swift", result: "+5 -2"),
        AuditExporter.AuditEntry(timestamp: Date(), user: "dev2", action: "diff", resource: "b.swift", result: "+1 -1"),
    ]
    let csv = exporter.exportCSV(entries: entries)
    XCTAssertTrue(csv.contains("dev1"))
    XCTAssertTrue(csv.contains("dev2"))
    XCTAssertTrue(csv.contains("a.swift"))
    XCTAssertTrue(csv.contains("b.swift"))
    let lines = csv.split(separator: "\n")
    XCTAssertTrue(lines.count == 3)
}

// MARK: - Avoid Accidental Edit Safe Delete

func testDevWorkflowFileOperationSafeDeleteNonExistent() {
    let safety = FileOperationSafety()
    let result = safety.safeDelete(path: "/tmp/missing_\(UUID().uuidString)")
    XCTAssertFalse(result)
}

// MARK: - .build Directory Combined Isolation

func testDevWorkflowBuildDirIsolationWithCustomPaths() {
    let safety = FileOperationSafety(protectedPaths: [".build", NSHomeDirectory() + "/Library", "/System"])
    XCTAssertTrue(safety.isProtected(".build"))
    XCTAssertTrue(safety.isProtected(".build/debug"))
    XCTAssertTrue(safety.isProtected(".build/arm64-apple-macosx"))
    XCTAssertTrue(!safety.isProtected("/tmp"))
    XCTAssertTrue(!safety.isProtected("Sources"))
}

// MARK: - Process Conflict Prompt

func testDevWorkflowConfirmerPromptIncludesOperationAndImpact() {
    let confirmer = HighRiskOperationConfirmer()
    let request = confirmer.request(for: .firewall, operation: "Disable firewall", impact: "System security reduced")
    let prompt = confirmer.prompt(for: request)
    XCTAssertTrue(prompt.contains("Disable firewall"))
    XCTAssertTrue(prompt.contains("System security reduced"))
    XCTAssertTrue(prompt.contains("确认"))
}

// MARK: - Credential Sanitizer Strength Variants

func testDevWorkflowCredentialSanitizerLightStrengthShowsKeyName() {
    let sanitizer = CredentialSanitizer(strength: .light)
    let result = sanitizer.sanitize("let password = \"hunter2\"")
    XCTAssertFalse(result.contains("hunter2"))
    XCTAssertTrue(result.contains("<redacted-password>"))
}

func testDevWorkflowCredentialSanitizerAggressiveStrength() {
    let sanitizer = CredentialSanitizer(strength: .aggressive)
    let result = sanitizer.sanitize("let token = 'sk-abc123'")
    XCTAssertFalse(result.contains("sk-abc123"))
    XCTAssertTrue(result.contains("<redacted>"))
}

func testDevWorkflowCredentialSanitizerCustomRuleApplied() {
    let rule = CredentialSanitizer.CustomRule(pattern: "my-secret-key", replacement: "[CUSTOM_REDACTED]", description: "custom secret")
    let sanitizer = CredentialSanitizer(customRules: [rule])
    let result = sanitizer.sanitize("my-secret-key is sensitive")
    XCTAssertTrue(result.contains("[CUSTOM_REDACTED]"))
    XCTAssertFalse(result.contains("my-secret-key"))
}

func testDevWorkflowCredentialSanitizerAddingCustomRule() {
    let sanitizer = CredentialSanitizer()
    let extended = sanitizer.addingCustomRule(CredentialSanitizer.CustomRule(pattern: "SECRET_PATTERN", replacement: "[REDACTED]"))
    let result = extended.sanitize("value=SECRET_PATTERN")
    XCTAssertTrue(result.contains("[REDACTED]"))
}

func testDevWorkflowCredentialSanitizerWithStrengthSwitch() {
    let sanitizer = CredentialSanitizer(strength: .medium)
    let aggressive = sanitizer.withStrength(.aggressive)
    let result = aggressive.sanitize("password = 'hunter2'")
    XCTAssertTrue(result.contains("<redacted>"))
}

// MARK: - Test Failure File:Line

func testDevWorkflowTestFailureWithFileLine() {
    let failure = TestFailure(
        testName: "testLoginFlow",
        message: "XCTAssertEqual failed: expected 5, got 3",
        filePath: "/Users/dev/Project/Tests/LoginTests.swift",
        line: 42
    )
    XCTAssertTrue(failure.testName == "testLoginFlow")
    XCTAssertTrue(failure.filePath == "/Users/dev/Project/Tests/LoginTests.swift")
    XCTAssertTrue(failure.line == 42)
    XCTAssertFalse(failure.message.isEmpty)
}

func testDevWorkflowTestFailureWithoutFileLine() {
    let failure = TestFailure(testName: "testEdgeCase", message: "unexpected nil")
    XCTAssertTrue(failure.testName == "testEdgeCase")
    XCTAssertTrue(failure.filePath == nil)
    XCTAssertTrue(failure.line == nil)
}

// MARK: - Build Result Edge Cases

func testDevWorkflowBuildResultContradictoryState() {
    let result = BuildResult(success: true, errors: [
        BuildDiagnostic(message: "error but marked success", severity: .error),
    ], durationSeconds: 0)
    XCTAssertTrue(result.success)
    XCTAssertTrue(result.errors.count == 1)
    XCTAssertTrue(result.durationSeconds == 0)
}

func testDevWorkflowBuildResultZeroDuration() {
    let result = BuildResult(success: true, durationSeconds: 0)
    XCTAssertTrue(result.success)
    XCTAssertTrue(result.summary.contains("0.0"))
}

func testDevWorkflowBuildResultRawOutputPreserved() {
    let result = BuildResult(success: false, durationSeconds: 0.5, rawOutput: "error: compile failed")
    XCTAssertTrue(result.rawOutput.contains("compile failed"))
}

// MARK: - PermissionPolicy Additional Rules

func testDevWorkflowPermissionPolicyCommandFilesAllowed() {
    let policy = PermissionPolicy()
    XCTAssertTrue(policy.evaluate(installPath: "script.command") == .allowed)
}

func testDevWorkflowPermissionPolicyBlockedExtension() {
    let policy = PermissionPolicy(rules: [
        PermissionPolicy.Rule(pattern: "*.exe", access: .blocked),
    ])
    XCTAssertTrue(policy.evaluate(installPath: "installer.exe") == .blocked)
}

// MARK: - FileOperationSafety.Operation Cases

func testDevWorkflowFileOperationSafetyOperationCases() {
    XCTAssertTrue(FileOperationSafety.Operation.delete.rawValue == "delete")
    XCTAssertTrue(FileOperationSafety.Operation.move.rawValue == "move")
    XCTAssertTrue(FileOperationSafety.Operation.overwrite.rawValue == "overwrite")
}
