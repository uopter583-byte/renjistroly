import Foundation
import XCTest
@testable import RenJistrolyCapability

func testSkillRegistryInit() async {
    let registry = SkillRegistry()
    let skills = await registry.allSkills()
    XCTAssertTrue(skills.isEmpty)
}

func testSkillRegistryParseSkillMDFrontmatter() async throws {
    let registry = SkillRegistry()
    let content = """
    ---
    name: Web Search Skill
    description: Allows the agent to search the web
    category: internet
    version: 1.0
    tags: search, web, internet
    ---

    # Web Search Skill

    This skill enables web search capabilities.
    """
    let parsed = try await registry.parseSkillMD(content)
    XCTAssertTrue(parsed.metadata.title == "Web Search Skill")
    XCTAssertTrue(parsed.metadata.description == "Allows the agent to search the web")
    XCTAssertTrue(parsed.metadata.category == "internet")
    XCTAssertTrue(parsed.metadata.version == "1.0")
    XCTAssertTrue(parsed.metadata.tags?.contains("search") == true)
    XCTAssertTrue(parsed.body.contains("Web Search Skill"))
}

func testSkillRegistryParseSkillMDMarkdownHeaders() async throws {
    let registry = SkillRegistry()
    let content = """
    # Code Review Skill

    > Analyze code changes for potential issues

    This skill performs code review.
    """
    let parsed = try await registry.parseSkillMD(content)
    XCTAssertTrue(parsed.metadata.title == "Code Review Skill")
    XCTAssertTrue(parsed.metadata.description == "Analyze code changes for potential issues")
}

func testSkillRegistryParseSkillMDNoMetadata() async throws {
    let registry = SkillRegistry()
    let content = """
    Just some instructions for the agent.

    Do this, then that.
    """
    let parsed = try await registry.parseSkillMD(content)
    XCTAssertTrue(parsed.metadata.title == nil)
    XCTAssertTrue(parsed.metadata.description == nil)
    XCTAssertFalse(parsed.body.isEmpty)
}

func testSkillRegistryLoadSingleSkill() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("skill-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let skillMD = """
    ---
    name: Test Skill
    description: A test skill
    category: testing
    ---

    # Test Skill

    This is a test skill body.
    """
    try skillMD.write(to: tempDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

    let registry = SkillRegistry()
    let skill = try await registry.loadSingleSkill(at: tempDir.path)
    XCTAssertTrue(skill.id == tempDir.lastPathComponent)
    XCTAssertTrue(skill.metadata.title == "Test Skill")
    XCTAssertTrue(skill.body.contains("test skill body"))
}

func testSkillRegistrySkillDirectoryIndex() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("skills-dir-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    for name in ["web-search", "code-review"] {
        let dir = tempDir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try """
        ---
        name: \(name)
        description: Skill \(name)
        tags: test
        ---

        # \(name)
        Body of \(name).
        """.write(to: dir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }

    let registry = SkillRegistry()
    try await registry.load(from: tempDir.path)
    let index = await registry.skillDirectoryIndex()
    XCTAssertTrue(index.contains("web-search"))
    XCTAssertTrue(index.contains("code-review"))
}

func testSkillRegistryFindSkillsMatching() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("skills-find-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    for name in ["web-search", "code-review", "file-tools"] {
        let dir = tempDir.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try """
        ---
        name: \(name)
        description: A \(name) skill
        tags: \(name == "web-search" ? "internet" : "code")
        ---

        # \(name)
        """.write(to: dir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }

    let registry = SkillRegistry()
    try await registry.load(from: tempDir.path)
    let results = await registry.findSkills(matching: "web")
    XCTAssertTrue(results.count == 1)
    XCTAssertTrue(results.first?.id == "web-search")
}

func testSkillRegistrySkillSystemPrompt() async throws {
    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("skills-prompt-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let dir = tempDir.appendingPathComponent("test-skill")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try """
    ---
    name: Test Skill
    description: For testing
    ---

    Do this.
    """.write(to: dir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

    let registry = SkillRegistry()
    try await registry.load(from: tempDir.path)
    let prompt = await registry.skillSystemPrompt()
    XCTAssertTrue(prompt.contains("Test Skill"))
    XCTAssertTrue(prompt.contains("Do this"))
}

func testSkillErrorDescriptions() {
    XCTAssertTrue(SkillError.directoryNotFound("/tmp/missing").errorDescription?.contains("未找到") == true)
    XCTAssertTrue(SkillError.skillFileNotFound("/tmp/missing").errorDescription?.contains("未找到") == true)
    XCTAssertTrue(SkillError.parseError("bad yaml").errorDescription?.contains("解析错误") == true)
}
