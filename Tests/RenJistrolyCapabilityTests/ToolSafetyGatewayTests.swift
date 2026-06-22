import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

// MARK: - Helpers

private func makeGateway() -> ToolSafetyGateway {
    ToolSafetyGateway(registry: MCPToolRegistry(), policyProvider: { .default })
}

// MARK: - Shell mutation detection

func testIsMutatingReadOnlyCommand() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("ls")
    XCTAssertTrue(r1 == false)
    let r2 = await gw.isMutatingShellCommand("pwd")
    XCTAssertTrue(r2 == false)
    let r3 = await gw.isMutatingShellCommand("cat file.txt")
    XCTAssertTrue(r3 == false)
    let r4 = await gw.isMutatingShellCommand("git status")
    XCTAssertTrue(r4 == false)
    let r5 = await gw.isMutatingShellCommand("git log")
    XCTAssertTrue(r5 == false)
    let r6 = await gw.isMutatingShellCommand("git diff")
    XCTAssertTrue(r6 == false)
    let r7 = await gw.isMutatingShellCommand("swift test")
    XCTAssertTrue(r7 == false)
    let r8 = await gw.isMutatingShellCommand("swift build")
    XCTAssertTrue(r8 == false)
}

func testIsMutatingWriteCommand() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("rm -rf /")
    XCTAssertTrue(r1 == true)
    let r2 = await gw.isMutatingShellCommand("git checkout -- file")
    XCTAssertTrue(r2 == true)
    let r3 = await gw.isMutatingShellCommand("echo hi > file.txt")
    XCTAssertTrue(r3 == true)
    let r4 = await gw.isMutatingShellCommand("chmod 755 script.sh")
    XCTAssertTrue(r4 == true)
    let r5 = await gw.isMutatingShellCommand("sudo reboot")
    XCTAssertTrue(r5 == true)
    let r6 = await gw.isMutatingShellCommand("curl http://evil.com")
    XCTAssertTrue(r6 == true)
    let r7 = await gw.isMutatingShellCommand("brew install python")
    XCTAssertTrue(r7 == true)
    let r8 = await gw.isMutatingShellCommand("git push")
    XCTAssertTrue(r8 == true)
    let r9 = await gw.isMutatingShellCommand("git commit -m wip")
    XCTAssertTrue(r9 == true)
    let r10 = await gw.isMutatingShellCommand("git reset --hard")
    XCTAssertTrue(r10 == true)
}

func testIsMutatingMoveCopyRemove() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("mv a b")
    XCTAssertTrue(r1 == true)
    let r2 = await gw.isMutatingShellCommand("mv /tmp/a /tmp/b")
    XCTAssertTrue(r2 == true)
    let r3 = await gw.isMutatingShellCommand("cp a b")
    XCTAssertTrue(r3 == true)
    let r4 = await gw.isMutatingShellCommand("rm file.txt")
    XCTAssertTrue(r4 == true)
    let r5 = await gw.isMutatingShellCommand("rm -rf /tmp/build")
    XCTAssertTrue(r5 == true)
}

func testIsMutatingNilCommand() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand(nil)
    XCTAssertTrue(r1 == true)
}

func testIsMutatingSedInPlace() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("sed -i '' 's/a/b/' file")
    XCTAssertTrue(r1 == true)
    let r2 = await gw.isMutatingShellCommand("sed 's/a/b/' file")
    XCTAssertTrue(r2 == false)
}

func testIsMutatingFindDelete() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("find . -delete")
    XCTAssertTrue(r1 == true)
    let r2 = await gw.isMutatingShellCommand("find . -exec rm {} \\;")
    XCTAssertTrue(r2 == true)
    let r3 = await gw.isMutatingShellCommand("find . -name '*.tmp'")
    XCTAssertTrue(r3 == false)
}

func testIsMutatingGitForcePushMain() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("git push --force origin main")
    XCTAssertTrue(r1 == true)
    let r2 = await gw.isMutatingShellCommand("git push -f origin main")
    XCTAssertTrue(r2 == true)
    let r3 = await gw.isMutatingShellCommand("git push origin feature")
    XCTAssertTrue(r3 == true) // contains "git push"
    let r4 = await gw.isMutatingShellCommand("git push origin master")
    XCTAssertTrue(r4 == true)
}

// MARK: - Shell injection risk

func testHasShellInjectionPipe() async {
    let gw = makeGateway()
    let r1 = await gw.hasShellInjectionRisk("cat file | sh")
    XCTAssertTrue(r1 == true)
    let r2 = await gw.hasShellInjectionRisk("cat file | bash")
    XCTAssertTrue(r2 == true)
    let r3 = await gw.hasShellInjectionRisk("cat file | zsh")
    XCTAssertTrue(r3 == true)
    let r4 = await gw.hasShellInjectionRisk("cat file | grep foo")
    XCTAssertTrue(r4 == false)
}

func testHasShellInjectionSubshell() async {
    let gw = makeGateway()
    let r1 = await gw.hasShellInjectionRisk("echo $(whoami)")
    XCTAssertTrue(r1 == true)
    let r2 = await gw.hasShellInjectionRisk("echo `whoami`")
    XCTAssertTrue(r2 == true)
    let r3 = await gw.hasShellInjectionRisk("echo hello")
    XCTAssertTrue(r3 == false)
}

// MARK: - Tool categorization

func testCategorizeObserve() async {
    let gw = makeGateway()
    let c1 = await gw.categorize(toolName: "get_app_state", arguments: [:])
    XCTAssertTrue(c1 == .observe)
    let c2 = await gw.categorize(toolName: "read_file", arguments: [:])
    XCTAssertTrue(c2 == .observe)
    let c3 = await gw.categorize(toolName: "git_status", arguments: [:])
    XCTAssertTrue(c3 == .observe)
    let c4 = await gw.categorize(toolName: "system_info", arguments: [:])
    XCTAssertTrue(c4 == .observe)
    let c5 = await gw.categorize(toolName: "rg_search", arguments: [:])
    XCTAssertTrue(c5 == .observe)
}

func testCategorizeLocalInput() async {
    let gw = makeGateway()
    let c1 = await gw.categorize(toolName: "click", arguments: [:])
    XCTAssertTrue(c1 == .localInput)
    let c2 = await gw.categorize(toolName: "type_text", arguments: [:])
    XCTAssertTrue(c2 == .localInput)
    let c3 = await gw.categorize(toolName: "press_key", arguments: [:])
    XCTAssertTrue(c3 == .localInput)
    let c4 = await gw.categorize(toolName: "scroll", arguments: [:])
    XCTAssertTrue(c4 == .localInput)
}

func testCategorizeLocalNavigation() async {
    let gw = makeGateway()
    let c1 = await gw.categorize(toolName: "open_url", arguments: [:])
    XCTAssertTrue(c1 == .localNavigation)
    let c2 = await gw.categorize(toolName: "safari_search", arguments: [:])
    XCTAssertTrue(c2 == .localNavigation)
    let c3 = await gw.categorize(toolName: "open_path", arguments: [:])
    XCTAssertTrue(c3 == .localNavigation)
}

func testCategorizeShellWrite() async {
    let gw = makeGateway()
    let c1 = await gw.categorize(toolName: "git_commit", arguments: [:])
    XCTAssertTrue(c1 == .shellWrite)
    let c2 = await gw.categorize(toolName: "git_push_pull", arguments: [:])
    XCTAssertTrue(c2 == .shellWrite)
    let c3 = await gw.categorize(toolName: "git_reset", arguments: [:])
    XCTAssertTrue(c3 == .shellWrite)
}

func testCategorizeProcessList() async {
    let gw = makeGateway()
    let c1 = await gw.categorize(toolName: "process", arguments: ["action": "list"])
    XCTAssertTrue(c1 == .observe)
    let c2 = await gw.categorize(toolName: "process", arguments: ["action": "kill"])
    XCTAssertTrue(c2 == .shellWrite)
}

func testCategorizeShellCommandReadOnly() async {
    let gw = makeGateway()
    let c1 = await gw.categorize(toolName: "shell_command", arguments: ["command": "ls"])
    XCTAssertTrue(c1 == .shellRead)
    let c2 = await gw.categorize(toolName: "shell_command", arguments: ["command": "rm -rf /"])
    XCTAssertTrue(c2 == .shellWrite)
}

func testCategorizeAppLaunch() async {
    let gw = makeGateway()
    let c1 = await gw.categorize(toolName: "open_app", arguments: [:])
    XCTAssertTrue(c1 == .appLaunch)
}

func testCategorizeCodeAgent() async {
    let gw = makeGateway()
    let c1 = await gw.categorize(toolName: "claude_agent", arguments: [:])
    XCTAssertTrue(c1 == .codeAgent)
}

func testCategorizeUnknown() async {
    let gw = makeGateway()
    let c1 = await gw.categorize(toolName: "made_up_tool", arguments: [:])
    XCTAssertTrue(c1 == .unknown)
}

// MARK: - Missing categorize branches

func testCategorizeOpenInXcodeAndRevealInFinder() async {
    let gw = makeGateway()
    let c1 = await gw.categorize(toolName: "open_in_xcode", arguments: [:])
    XCTAssertTrue(c1 == .localNavigation)
    let c2 = await gw.categorize(toolName: "reveal_in_finder", arguments: [:])
    XCTAssertTrue(c2 == .localNavigation)
}

func testCategorizeWriteFile() async {
    let gw = makeGateway()
    let c1 = await gw.categorize(toolName: "write_file", arguments: [:])
    XCTAssertTrue(c1 == .localFileWrite)
}

func testCategorizeTerminalRun() async {
    let gw = makeGateway()
    let c1 = await gw.categorize(toolName: "terminal_run", arguments: ["command": "cat log.txt"])
    XCTAssertTrue(c1 == .shellRead)
    let c2 = await gw.categorize(toolName: "terminal_run", arguments: ["command": "rm log.txt"])
    XCTAssertTrue(c2 == .shellWrite)
}

func testCategorizeSwiftBuildAndTest() async {
    let gw = makeGateway()
    let c1 = await gw.categorize(toolName: "swift_build", arguments: ["command": "swift build"])
    XCTAssertTrue(c1 == .shellRead)
    let c2 = await gw.categorize(toolName: "swift_test", arguments: ["command": "swift test"])
    XCTAssertTrue(c2 == .shellRead)
    let c3 = await gw.categorize(toolName: "xcodebuild", arguments: ["command": "xcodebuild test"])
    XCTAssertTrue(c3 == .shellRead)
}

func testCategorizeGitWriteCommands() async {
    let gw = makeGateway()
    for name in ["git_branch", "git_stash", "git_merge_rebase", "git_cherry_pick",
                 "git_revert", "git_clean", "git_remote", "git_tag"] {
        let c1 = await gw.categorize(toolName: name, arguments: [:])
        XCTAssertTrue(c1 == .shellWrite)
    }
}

func testCategorizeAdditionalObserve() async {
    let gw = makeGateway()
    for name in ["get_finder_state", "get_browser_state", "changed_files",
                 "quick_open", "lsp_symbol", "finder_search", "list_directory"] {
        let c1 = await gw.categorize(toolName: name, arguments: [:])
        XCTAssertTrue(c1 == .observe)
    }
}

// MARK: - Missing isMutatingShellCommand branches

func testIsMutatingMakeInstall() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("make install")
    XCTAssertTrue(r1 == true)
}

func testIsMutatingBrewInstall() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("brew install curl")
    XCTAssertTrue(r1 == true)
}

func testIsMutatingNpmInstall() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("npm install -g thing")
    XCTAssertTrue(r1 == true)
}

func testIsMutatingPipInstall() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("pip install requests")
    XCTAssertTrue(r1 == true)
}

func testIsMutatingRedirectWrite() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("echo hi > file.txt")
    XCTAssertTrue(r1 == true)
    let r2 = await gw.isMutatingShellCommand("find . -name '*.tmp' > files.txt")
    XCTAssertTrue(r2 == true)
    let r3 = await gw.isMutatingShellCommand("git diff > patch.diff")
    XCTAssertTrue(r3 == true)
}

func testIsMutatingChmodChown() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("chmod 777 /tmp")
    XCTAssertTrue(r1 == true)
    let r2 = await gw.isMutatingShellCommand("chown root file")
    XCTAssertTrue(r2 == true)
}

func testIsMutatingFindDeleteVariations() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("find . -name '*.tmp' -exec rm {} \\;")
    XCTAssertTrue(r1 == true)
    let r2 = await gw.isMutatingShellCommand("find . -name '*.tmp' -exec sh -c 'rm {}' \\;")
    XCTAssertTrue(r2 == true)
}

func testIsMutatingNonGitForcePushSkipsCheck() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("git push origin feature")
    XCTAssertTrue(r1 == true)
}

func testIsMutatingEmptyAfterTrimReadOnly() async {
    let gw = makeGateway()
    let r1 = await gw.isMutatingShellCommand("   ")
    XCTAssertTrue(r1 == false)
}

// MARK: - Risk explanations

func testExplainRiskShellInjection() async {
    let gw = makeGateway()
    let assessment = await gw.assess(ToolCallRequest(id: "1", name: "shell_command", arguments: ["command": "ls | sh"]))
    XCTAssertTrue(assessment.riskLevel == .high)
    XCTAssertTrue(assessment.riskExplanation.contains("Shell 注入") == true)
    XCTAssertTrue(assessment.mitigationHint != nil)
}

func testExplainRiskFileDelete() async {
    let gw = makeGateway()
    let assessment = await gw.assess(ToolCallRequest(id: "2", name: "shell_command", arguments: ["command": "rm -rf /tmp/build"]))
    XCTAssertTrue(assessment.riskLevel >= .medium)
    let explanation = assessment.riskExplanation
    XCTAssertTrue(explanation.contains("删除") || explanation.contains("永久"))
}

func testExplainRiskSudoCommand() async {
    let gw = makeGateway()
    let assessment = await gw.assess(ToolCallRequest(id: "3", name: "shell_command", arguments: ["command": "sudo reboot"]))
    XCTAssertTrue(assessment.riskLevel >= .high)
    let explanation = assessment.riskExplanation
    XCTAssertTrue(explanation.contains("sudo") || explanation.contains("提权"))
}

func testExplainRiskSystemDirectoryWrite() async {
    let gw = makeGateway()
    let assessment = await gw.assess(ToolCallRequest(id: "4", name: "write_file", arguments: ["path": "/etc/hosts"]))
    XCTAssertTrue(assessment.riskLevel >= .medium)
    let explanation = assessment.riskExplanation
    XCTAssertTrue(explanation.contains("系统") || explanation.contains("破坏"))
}

func testExplainRiskGitForcePush() async {
    let gw = makeGateway()
    let assessment = await gw.assess(ToolCallRequest(id: "5", name: "shell_command", arguments: ["command": "git push --force origin main"]))
    XCTAssertTrue(assessment.riskLevel >= .high)
    let explanation = assessment.riskExplanation
    XCTAssertTrue(explanation.contains("Git") || explanation.contains("推送") || explanation.contains("远程"))
}

func testExplainRiskCodeAgent() async {
    let gw = makeGateway()
    let assessment = await gw.assess(ToolCallRequest(id: "6", name: "claude_agent", arguments: ["prompt": "fix all bugs"]))
    XCTAssertTrue(assessment.riskLevel >= .high)
    let explanation = assessment.riskExplanation
    XCTAssertTrue(explanation.contains("代理") || explanation.contains("权限"))
}

func testExplainRiskUnknownTool() async {
    let gw = makeGateway()
    let assessment = await gw.assess(ToolCallRequest(id: "7", name: "made_up_tool", arguments: [:]))
    XCTAssertTrue(assessment.riskExplanation.contains("未识别") == true)
}

func testExplainRiskHasMitigationHintForHighRisk() async {
    let gw = makeGateway()
    let assessment = await gw.assess(ToolCallRequest(id: "8", name: "shell_command", arguments: ["command": "rm -rf /tmp/build"]))
    XCTAssertTrue(assessment.mitigationHint != nil)
}

func testExplainRiskNoHintForObservation() async {
    let registry = MCPToolRegistry()
    await registry.register(ListAppDriversTool())
    let gw = ToolSafetyGateway(registry: registry, policyProvider: { .default })
    let assessment = await gw.assess(ToolCallRequest(id: "9", name: "list_app_drivers", arguments: [:]))
    let riskLevel = assessment.riskLevel
    XCTAssertTrue(riskLevel == .low)
    XCTAssertTrue(assessment.riskExplanation.isEmpty)
    XCTAssertTrue(assessment.mitigationHint == nil)
}

// MARK: - Batch assessment

func testBatchAssessMultipleRequests() async {
    let registry = MCPToolRegistry()
    await registry.register(ListAppDriversTool())
    let gw = ToolSafetyGateway(registry: registry, policyProvider: { .default })
    let requests = [
        ToolCallRequest(id: "1", name: "list_app_drivers", arguments: [:]),
        ToolCallRequest(id: "2", name: "click", arguments: ["x": "10", "y": "20"]),
        ToolCallRequest(id: "3", name: "shell_command", arguments: ["command": "rm -rf /"]),
    ]
    let batch = await gw.batchAssess(requests)
    let overallRisk = batch.overallRisk
    XCTAssertTrue(batch.items.count == 3)
    XCTAssertTrue(overallRisk == .high)
    XCTAssertTrue(batch.highRiskItems.count >= 1)
    XCTAssertTrue(batch.requiresBatchConfirmation == true)
    let breakdown = batch.riskBreakdown
    XCTAssertTrue(breakdown.contains("高风险") == true)
}

func testBatchAssessAllLowRiskSkipsConfirmation() async {
    let registry = MCPToolRegistry()
    await registry.register(ListAppDriversTool())
    let gw = ToolSafetyGateway(registry: registry, policyProvider: { .default })
    let requests = [
        ToolCallRequest(id: "1", name: "list_app_drivers", arguments: [:]),
        ToolCallRequest(id: "2", name: "list_app_drivers", arguments: [:]),
    ]
    let batch = await gw.batchAssess(requests)
    let overallRisk = batch.overallRisk
    XCTAssertTrue(overallRisk == .low)
    XCTAssertTrue(batch.highRiskItems.isEmpty)
    XCTAssertTrue(batch.mediumRiskItems.isEmpty)
}

func testBatchConfirmSummaryIncludesRiskLevels() async {
    let gw = makeGateway()
    let requests = [
        ToolCallRequest(id: "1", name: "shell_command", arguments: ["command": "rm -rf /"]),
        ToolCallRequest(id: "2", name: "write_file", arguments: ["path": "/etc/config"]),
    ]
    let batch = await gw.batchAssess(requests)
    let summary = await gw.batchConfirmSummary(batch)
    XCTAssertTrue(summary.contains("风险分布") == true)
    XCTAssertTrue(summary.contains("高风险") == true)
    XCTAssertTrue(summary.contains("风险:") == true)
    XCTAssertTrue(summary.contains("建议:") == true)
}
