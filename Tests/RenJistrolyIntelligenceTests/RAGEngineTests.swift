import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - tokenize

func testTokenizeSimple() async {
    let engine = RAGEngine()
    let tokens = await engine.tokenize("hello world foo bar")
    XCTAssertTrue(tokens.contains("hello"))
    XCTAssertTrue(tokens.contains("world"))
    XCTAssertTrue(tokens.contains("foo"))
    XCTAssertTrue(tokens.contains("bar"))
}

func testTokenizeFiltersShortTokens() async {
    let engine = RAGEngine()
    let tokens = await engine.tokenize("a b c ab bc")
    XCTAssertTrue(!tokens.contains("a"))
    XCTAssertTrue(!tokens.contains("b"))
    XCTAssertTrue(!tokens.contains("c"))
    XCTAssertTrue(tokens.contains("ab"))
    XCTAssertTrue(tokens.contains("bc"))
}

func testTokenizeChinese() async {
    let engine = RAGEngine()
    let tokens = await engine.tokenize("你好世界 测试数据 代码")
    XCTAssertTrue(tokens.contains("你好世界"))
    XCTAssertTrue(tokens.contains("测试数据"))
    XCTAssertTrue(tokens.contains("代码"))
}

func testTokenizeMixedContent() async {
    let engine = RAGEngine()
    let tokens = await engine.tokenize("func testLogin() { let x = 1 }")
    XCTAssertTrue(tokens.contains("func"))
    XCTAssertTrue(tokens.contains("testlogin"))
    XCTAssertTrue(tokens.contains("let"))
}

func testTokenizeEmpty() async {
    let engine = RAGEngine()
    let tokens = await engine.tokenize("")
    XCTAssertTrue(tokens.isEmpty)
}

// MARK: - findRelevantSnippet

func testFindRelevantSnippet() async {
    let engine = RAGEngine()
    let content = """
    line one
    line two target here
    line three
    line four
    line five
    line six
    line seven
    """
    let snippet = await engine.findRelevantSnippet(in: content, keywords: ["target"])
    XCTAssertTrue(snippet.contains("target here"))
}

func testFindRelevantSnippetNoMatch() async {
    let engine = RAGEngine()
    let content = "line one\nline two\nline three"
    let snippet = await engine.findRelevantSnippet(in: content, keywords: ["missing"])
    XCTAssertFalse(snippet.isEmpty) // always returns something
}

func testFindRelevantSnippetEmpty() async {
    let engine = RAGEngine()
    let snippet = await engine.findRelevantSnippet(in: "", keywords: ["test"])
    XCTAssertTrue(snippet.isEmpty)
}

// MARK: - isIndexableFile

func testIsIndexableSwiftFile() async {
    let engine = RAGEngine()
    let r1 = await engine.isIndexableFile("/path/to/file.swift")
    XCTAssertTrue(r1 == true)
    let r2 = await engine.isIndexableFile("/path/to/file.ts")
    XCTAssertTrue(r2 == true)
    let r3 = await engine.isIndexableFile("/path/to/file.py")
    XCTAssertTrue(r3 == true)
    let r4 = await engine.isIndexableFile("/path/to/file.go")
    XCTAssertTrue(r4 == true)
    let r5 = await engine.isIndexableFile("/path/to/file.sh")
    XCTAssertTrue(r5 == true)
}

func testIsIndexableNonIndexable() async {
    let engine = RAGEngine()
    let r1 = await engine.isIndexableFile("/path/to/file.png")
    XCTAssertTrue(r1 == false)
    let r2 = await engine.isIndexableFile("/path/to/file.pdf")
    XCTAssertTrue(r2 == false)
    let r3 = await engine.isIndexableFile("/path/to/file.dmg")
    XCTAssertTrue(r3 == false)
}

// MARK: - Search with temporary project

func testSearchAfterIndex() async throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("rag_test_\(UUID().uuidString.prefix(8))")
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let fileA = tmpDir.appendingPathComponent("AuthService.swift")
    try "class AuthService { func login() { /* handles user authentication */ } }".write(to: fileA, atomically: true, encoding: .utf8)

    let fileB = tmpDir.appendingPathComponent("DatabaseHelper.swift")
    try "class DatabaseHelper { func connect() { /* connects to the database */ } }".write(to: fileB, atomically: true, encoding: .utf8)

    let engine = RAGEngine()
    try await engine.indexProject(at: tmpDir.path)

    let results = await engine.search("authentication")
    XCTAssertFalse(results.isEmpty)
    XCTAssertTrue(results.first?.path.contains("AuthService") == true)

    let results2 = await engine.search("database connect")
    XCTAssertFalse(results2.isEmpty)
    XCTAssertTrue(results2.first?.path.contains("DatabaseHelper") == true)
}

func testSearchEmptyIndex() async {
    let engine = RAGEngine()
    let results = await engine.search("anything")
    XCTAssertTrue(results.isEmpty)
}

// MARK: - buildContext

func testBuildContextEmpty() async {
    let engine = RAGEngine()
    let ctx = await engine.buildContext("nothing")
    XCTAssertTrue(ctx.isEmpty)
}

func testBuildContextAfterIndex() async throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("rag_ctx_\(UUID().uuidString.prefix(8))")
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let file = tmpDir.appendingPathComponent("Config.swift")
    try "struct Config { let port = 8080; let host = \"localhost\" }".write(to: file, atomically: true, encoding: .utf8)

    let engine = RAGEngine()
    try await engine.indexProject(at: tmpDir.path)

    let ctx = await engine.buildContext("port host")
    XCTAssertTrue(ctx.contains("Config.swift"))
    XCTAssertTrue(ctx.contains("```"))
}

// MARK: - clear

func testClearRemovesAll() async throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("rag_clear_\(UUID().uuidString.prefix(8))")
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let file = tmpDir.appendingPathComponent("test.swift")
    try "let x = 1".write(to: file, atomically: true, encoding: .utf8)

    let engine = RAGEngine()
    try await engine.indexProject(at: tmpDir.path)
    let searchResult = await engine.search("let")
    XCTAssertTrue(searchResult.isEmpty == false)

    await engine.clear()
    let afterClear = await engine.search("let")
    XCTAssertTrue(afterClear.isEmpty)
}
