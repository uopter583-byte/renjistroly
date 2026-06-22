import Foundation
import XCTest
@testable import RenJistrolySystemBridge

// MARK: - shellQuoted

func testShellQuotedSimple() async {
    let store = TerminalTaskStore(store: FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tts_\(UUID().uuidString.prefix(8))")))
    let result = await store.shellQuoted("hello")
    XCTAssertTrue(result == "'hello'")
}

func testShellQuotedWithSingleQuote() async {
    let store = TerminalTaskStore(store: FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tts_\(UUID().uuidString.prefix(8))")))
    let result = await store.shellQuoted("it's")
    XCTAssertTrue(result == "'it'\\''s'")
}

func testShellQuotedWithSpaces() async {
    let store = TerminalTaskStore(store: FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tts_\(UUID().uuidString.prefix(8))")))
    let result = await store.shellQuoted("/path/with spaces/file.txt")
    XCTAssertTrue(result.hasPrefix("'"))
    XCTAssertTrue(result.hasSuffix("'"))
}

// MARK: - tail

func testTailFile() async throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("tts_test_\(UUID().uuidString.prefix(8))")
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let store = TerminalTaskStore(
        store: FoundationStore(directory: tmpDir),
        taskDirectory: tmpDir
    )
    let file = tmpDir.appendingPathComponent("test.log")
    let content = String(repeating: "a", count: 100) + "\nlast line here\n"
    try content.write(to: file, atomically: true, encoding: .utf8)

    let tail = await store.tail(path: file.path)
    XCTAssertTrue(tail?.contains("last line here") == true)
}

func testTailNonexistentFile() async {
    let store = TerminalTaskStore(store: FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tts_\(UUID().uuidString.prefix(8))")))
    let result = await store.tail(path: "/nonexistent/file.log")
    XCTAssertTrue(result == nil)
}

// MARK: - readTrimmed

func testReadTrimmed() async throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("tts_test_\(UUID().uuidString.prefix(8))")
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let store = TerminalTaskStore(
        store: FoundationStore(directory: tmpDir),
        taskDirectory: tmpDir
    )
    let file = tmpDir.appendingPathComponent("exit.txt")
    try "  0  \n".write(to: file, atomically: true, encoding: .utf8)

    let result = await store.readTrimmed(file.path)
    XCTAssertTrue(result == "0")
}

func testReadTrimmedFileNotFound() async {
    let store = TerminalTaskStore(store: FoundationStore(directory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("tts_\(UUID().uuidString.prefix(8))")))
    let result = await store.readTrimmed("/nonexistent/file.txt")
    XCTAssertTrue(result == nil)
}

func testReadTrimmedWhitespaceOnly() async throws {
    let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("tts_test_\(UUID().uuidString.prefix(8))")
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    let store = TerminalTaskStore(
        store: FoundationStore(directory: tmpDir),
        taskDirectory: tmpDir
    )
    let file = tmpDir.appendingPathComponent("blank.txt")
    try "   \n  ".write(to: file, atomically: true, encoding: .utf8)

    let result = await store.readTrimmed(file.path)
    XCTAssertTrue(result == nil) // whitespace-only becomes nil
}
