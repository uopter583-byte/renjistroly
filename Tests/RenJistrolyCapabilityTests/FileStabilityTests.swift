import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyCapability

// MARK: - Read File Tool

func testReadFileToolDefinition() {
    let tool = ReadFileTool()
    XCTAssertTrue(tool.definition.name == "read_file")
    XCTAssertTrue(tool.riskLevel == .low)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "path" })
}

func testReadFileToolMissingPath() async throws {
    let tool = ReadFileTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}

func testReadFileToolNotFound() async throws {
    let tool = ReadFileTool()
    let result = try await tool.execute(arguments: ["path": "/tmp/nonexistent_file_\(UUID().uuidString)"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("不存在"))
}

// MARK: - Write File Tool

func testWriteFileToolDefinition() {
    let tool = WriteFileTool()
    XCTAssertTrue(tool.definition.name == "write_file")
    XCTAssertTrue(tool.riskLevel == .high)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "path" })
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "content" })
}

func testWriteFileToolMissingParams() async throws {
    let tool = WriteFileTool()
    let result = try await tool.execute(arguments: ["path": "/tmp/test.txt"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}

func testWriteFileToolDisallowedPath() async throws {
    let tool = WriteFileTool()
    let result = try await tool.execute(arguments: [
        "path": "/System/test_write_\(UUID().uuidString.prefix(8)).txt",
        "content": "should not be written"
    ])
    XCTAssertTrue(result.isError)
}

// MARK: - List Files Tool

func testListFilesToolDefinition() {
    let tool = ListFilesTool()
    XCTAssertTrue(tool.definition.name == "list_files")
    XCTAssertTrue(tool.riskLevel == .low)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "path" })
}

func testListFilesToolMissingPath() async throws {
    let tool = ListFilesTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}

func testListFilesToolNonexistentDirectory() async throws {
    let tool = ListFilesTool()
    let result = try await tool.execute(arguments: ["path": "/tmp/nonexistent_dir_\(UUID().uuidString)"])
    XCTAssertTrue(result.isError)
}

// MARK: - Create Folder Tool

func testCreateFolderToolDefinition() {
    let tool = CreateFolderTool()
    XCTAssertTrue(tool.definition.name == "create_folder")
    XCTAssertTrue(tool.riskLevel == .medium)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "path" })
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "name" })
}

func testCreateFolderToolMissingParams() async throws {
    let tool = CreateFolderTool()
    let result = try await tool.execute(arguments: ["path": "/tmp"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}

// MARK: - Move File Tool

func testMoveFileToolDefinition() {
    let tool = MoveFileTool()
    XCTAssertTrue(tool.definition.name == "move_file")
    XCTAssertTrue(tool.riskLevel == .high)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "from" })
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "to" })
}

func testMoveFileToolMissingFrom() async throws {
    let tool = MoveFileTool()
    let result = try await tool.execute(arguments: ["to": "/tmp/dest.txt"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}

// MARK: - Copy File Tool

func testCopyFileToolDefinition() {
    let tool = CopyFileTool()
    XCTAssertTrue(tool.definition.name == "copy_file")
    XCTAssertTrue(tool.riskLevel == .medium)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "from" })
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "to" })
}

func testCopyFileToolMissingTo() async throws {
    let tool = CopyFileTool()
    let result = try await tool.execute(arguments: ["from": "/tmp/src.txt"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}

// MARK: - Delete File Tool

func testDeleteFileToolDefinition() {
    let tool = DeleteFileTool()
    XCTAssertTrue(tool.definition.name == "delete_file")
    XCTAssertTrue(tool.riskLevel == .high)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "path" })
}

func testDeleteFileToolMissingPath() async throws {
    let tool = DeleteFileTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}

// MARK: - Rename File Tool

func testRenameFileToolDefinition() {
    let tool = RenameFileTool()
    XCTAssertTrue(tool.definition.name == "rename_file")
    XCTAssertTrue(tool.riskLevel == .medium)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "path" })
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "name" })
}

func testRenameFileToolMissingName() async throws {
    let tool = RenameFileTool()
    let result = try await tool.execute(arguments: ["path": "/tmp/test.txt"])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}

// MARK: - File Info Tool

func testFileInfoToolDefinition() {
    let tool = FileInfoTool()
    XCTAssertTrue(tool.definition.name == "file_info")
    XCTAssertTrue(tool.riskLevel == .low)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "path" })
}

func testFileInfoToolMissingPath() async throws {
    let tool = FileInfoTool()
    let result = try await tool.execute(arguments: [:])
    XCTAssertTrue(result.isError)
    XCTAssertTrue(result.output.contains("缺少"))
}

// MARK: - Batch File Operations

func testBatchMoveToolDefinition() {
    let tool = BatchMoveTool()
    XCTAssertTrue(tool.definition.name == "batch_move")
    XCTAssertTrue(tool.riskLevel == .high)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "operations" })
}

func testBatchCopyToolDefinition() {
    let tool = BatchCopyTool()
    XCTAssertTrue(tool.definition.name == "batch_copy")
    XCTAssertTrue(tool.riskLevel == .medium)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "operations" })
}

func testBatchDeleteToolDefinition() {
    let tool = BatchDeleteTool()
    XCTAssertTrue(tool.definition.name == "batch_delete")
    XCTAssertTrue(tool.riskLevel == .high)
    XCTAssertTrue(tool.definition.parameters.contains { $0.name == "paths" })
}

// MARK: - FinderDriver - Conflict Detection (uses FileManager on real FS)

func testBatchMoveInvalidJSON() async throws {
    let tool = BatchMoveTool()
    let result = try await tool.execute(arguments: ["operations": "not-json"])
    XCTAssertTrue(result.isError)
}

func testBatchCopyInvalidJSON() async throws {
    let tool = BatchCopyTool()
    let result = try await tool.execute(arguments: ["operations": "invalid"])
    XCTAssertTrue(result.isError)
}

func testBatchDeleteInvalidJSON() async throws {
    let tool = BatchDeleteTool()
    let result = try await tool.execute(arguments: ["paths": "not-an-array"])
    XCTAssertTrue(result.isError)
}

// MARK: - FileOperationResult Models

func testFileOperationResultSuccess() {
    let result = FileOperationResult(
        success: true,
        verified: true,
        sourcePath: "/tmp/src.txt",
        destPath: "/tmp/dst.txt"
    )
    XCTAssertTrue(result.success)
    XCTAssertTrue(result.verified)
    XCTAssertTrue(result.sourcePath == "/tmp/src.txt")
    XCTAssertTrue(result.error == nil)
}

func testFileOperationResultConflict() {
    let conflict = FileConflict(path: "/tmp/exists.txt", kind: .exists)
    let result = FileOperationResult(
        success: false,
        verified: false,
        sourcePath: "/tmp/src.txt",
        destPath: "/tmp/exists.txt",
        conflict: conflict,
        error: "目标已存在"
    )
    XCTAssertFalse(result.success)
    XCTAssertFalse(result.verified)
    XCTAssertTrue(result.conflict?.kind == .exists)
    XCTAssertTrue(result.error == "目标已存在")
}

func testFileOperationResultMissingSource() {
    let result = FileOperationResult(
        success: false,
        verified: false,
        sourcePath: "/tmp/missing.txt",
        error: "源文件不存在"
    )
    XCTAssertFalse(result.success)
    XCTAssertTrue(result.error == "源文件不存在")
}

// MARK: - FileConflictKind

func testFileConflictKindAllCases() {
    let kinds: [FileConflictKind] = [.exists, .permissionDenied, .diskFull, .missingSource]
    XCTAssertTrue(kinds.count == 4)
}

// MARK: - ConflictStrategy

func testConflictStrategyAllCases() {
    XCTAssertTrue(ConflictStrategy.rename.rawValue == "rename")
    XCTAssertTrue(ConflictStrategy.overwrite.rawValue == "overwrite")
    XCTAssertTrue(ConflictStrategy.skip.rawValue == "skip")
}
