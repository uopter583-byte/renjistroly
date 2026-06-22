import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

// MARK: - ChangedFilesTool

func testChangedFilesToolDefinition() {
    let tool = ChangedFilesTool()
    XCTAssertTrue(tool.definition.name == "changed_files")
    XCTAssertFalse(tool.definition.description.isEmpty)
    XCTAssertTrue(tool.riskLevel == .low)
}

// MARK: - LSPTool

func testLSPToolDefinition() {
    let tool = LSPTool()
    XCTAssertTrue(tool.definition.name == "lsp_symbol")
    XCTAssertFalse(tool.definition.description.isEmpty)
    XCTAssertTrue(tool.riskLevel == .low)
}

// MARK: - QuickOpenTool

func testQuickOpenToolDefinition() {
    let tool = QuickOpenTool()
    XCTAssertTrue(tool.definition.name == "quick_open")
    XCTAssertFalse(tool.definition.description.isEmpty)
    XCTAssertTrue(tool.riskLevel == .low)
}

// MARK: - ClaudeAgentTool

func testClaudeAgentToolDefinition() {
    let tool = ClaudeAgentTool()
    XCTAssertTrue(tool.definition.name == "claude_agent")
    XCTAssertFalse(tool.definition.description.isEmpty)
    XCTAssertTrue(tool.riskLevel == .high)
}

func testClaudeAgentArgumentsOmitUnsupportedMaxTurns() {
    let args = ClaudeAgentTool.buildArguments(prompt: "fix bug", supportsMaxTurns: false)

    XCTAssertTrue(!args.contains("--max-turns"))
}

func testClaudeAgentArgumentsUseConstrainedBashTools() {
    let args = ClaudeAgentTool.buildArguments(prompt: "fix bug", supportsMaxTurns: true)
    let allowedToolsIndex = args.firstIndex(of: "--allowedTools")
    let allowedTools = allowedToolsIndex.flatMap { index in
        args.indices.contains(index + 1) ? args[index + 1] : nil
    } ?? ""

    XCTAssertTrue(args.contains("--max-turns"))
    XCTAssertTrue(!allowedTools.contains("Bash(*)"))
    XCTAssertTrue(allowedTools.contains("Bash(git *)"))
    XCTAssertTrue(allowedTools.contains("Bash(swift *)"))
    XCTAssertTrue(allowedTools.contains("Read"))
    XCTAssertTrue(allowedTools.contains("Edit"))
}

// MARK: - ExternalMCPServer.Config

func testExternalMCPServerConfigMinimalInit() {
    let config = ExternalMCPServer.Config(name: "test-server", command: "/usr/bin/node")
    XCTAssertTrue(config.name == "test-server")
    XCTAssertTrue(config.command == "/usr/bin/node")
    XCTAssertTrue(config.args.isEmpty)
    XCTAssertTrue(config.env == nil)
}

func testExternalMCPServerConfigFullInit() {
    let config = ExternalMCPServer.Config(
        name: "my-server",
        command: "/usr/local/bin/python3",
        args: ["-m", "mcp_server"],
        env: ["API_KEY": "secret"]
    )
    XCTAssertTrue(config.name == "my-server")
    XCTAssertTrue(config.args == ["-m", "mcp_server"])
    XCTAssertTrue(config.env == ["API_KEY": "secret"])
}

func testExternalMCPServerConfigEquatable() {
    let a = ExternalMCPServer.Config(name: "a", command: "cmd")
    let b = ExternalMCPServer.Config(name: "a", command: "cmd")
    let c = ExternalMCPServer.Config(name: "b", command: "cmd")
    XCTAssertTrue(a == b)
    XCTAssertTrue(a != c)
}

func testExternalMCPServerInit() {
    let config = ExternalMCPServer.Config(name: "srv", command: "cmd")
    let server = ExternalMCPServer(config: config)
    XCTAssertTrue(server.config.name == "srv")
    XCTAssertFalse(server.id.isEmpty)
}
