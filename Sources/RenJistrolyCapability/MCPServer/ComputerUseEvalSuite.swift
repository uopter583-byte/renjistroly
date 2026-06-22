import Foundation
import RenJistrolyModels

public struct ComputerUseEvalSuite: Sendable {
    public let tasks: [ComputerUseEvalTask]

    public init(tasks: [ComputerUseEvalTask] = ComputerUseEvalSuite.defaultTasks) {
        self.tasks = tasks
    }

    public static let defaultTasks: [ComputerUseEvalTask] = [
        ComputerUseEvalTask(
            name: "Observe frontmost app",
            category: .appNavigation,
            instruction: "Observe the current app and list UI elements.",
            expectedOutcome: "get_app_state returns at least one app or window field"
        ),
        ComputerUseEvalTask(
            name: "Open browser URL",
            category: .browser,
            instruction: "Open https://example.com in the default browser.",
            expectedOutcome: "open_url returns success"
        ),
        ComputerUseEvalTask(
            name: "List project files",
            category: .finder,
            instruction: "List files in the current project directory.",
            expectedOutcome: "list_files returns at least one file"
        ),
        // Real-world eval scenarios
        ComputerUseEvalTask(
            name: "Open Safari from Finder",
            category: .appNavigation,
            instruction: "Open Safari application using open_app tool.",
            expectedOutcome: "Safari becomes the frontmost application"
        ),
        ComputerUseEvalTask(
            name: "Web search for Swift docs",
            category: .webSearch,
            instruction: "Search for 'SwiftUI documentation' in Safari.",
            expectedOutcome: "safari_search returns success and browser shows search results"
        ),
        ComputerUseEvalTask(
            name: "Find a specific file",
            category: .finder,
            instruction: "Search for Package.swift in the project directory.",
            expectedOutcome: "finder_search returns the Package.swift path"
        ),
        ComputerUseEvalTask(
            name: "Type text and verify",
            category: .textEntry,
            instruction: "Type 'Hello RenJistroly' into the focused text field and verify.",
            expectedOutcome: "type_text returns success and value reflects typed text"
        ),
        ComputerUseEvalTask(
            name: "Run a Swift build",
            category: .codeBuild,
            instruction: "Run swift build in the project directory.",
            expectedOutcome: "Build completes with exit code 0 or known warnings"
        ),
        ComputerUseEvalTask(
            name: "Run project tests",
            category: .codeTest,
            instruction: "Run swift test with specific filter for a small test suite.",
            expectedOutcome: "Tests execute and report pass/fail counts"
        ),
        ComputerUseEvalTask(
            name: "Diagnose a build error",
            category: .codeFixBug,
            instruction: "If build fails, read the error output and identify the root cause file.",
            expectedOutcome: "Error file path and line number are extracted from compiler output"
        ),
        ComputerUseEvalTask(
            name: "Recover from stale element click",
            category: .failureRecovery,
            instruction: "Click a UI element by index, and if element not found, re-observe and remap by stable ID.",
            expectedOutcome: "Recovery strategy remapByStableID is attempted before coordinate fallback"
        ),
        ComputerUseEvalTask(
            name: "Recover from wrong browser page",
            category: .failureRecovery,
            instruction: "Open a URL, and if the browser shows wrong page, reopen with correct URL.",
            expectedOutcome: "Recovery strategy reopenBrowserPage is used when host mismatches"
        ),
        ComputerUseEvalTask(
            name: "Multi-step: observe, click, verify",
            category: .multiStepWorkflow,
            instruction: "Observe UI state, click a button by title, then verify state changed.",
            expectedOutcome: "All 3 steps succeed in sequence with verification"
        ),
        ComputerUseEvalTask(
            name: "Multi-step: search, navigate, extract",
            category: .multiStepWorkflow,
            instruction: "Search Safari for a term, navigate to first result, extract page title.",
            expectedOutcome: "Browser state shows correct search query and resulting page title"
        ),
    ]

    public func record(task: ComputerUseEvalTask, run: ComputerUseRunResult) -> ComputerUseEvalResult {
        ComputerUseEvalResult(
            task: task,
            succeeded: run.succeeded,
            attempts: run.steps.count,
            failureReason: run.succeeded ? nil : run.steps.last?.toolResult.output
        )
    }
}
