import AppKit
import Foundation
import RenJistrolyModels

public struct FinderDriver: AppDriver {
    public let id = "finder"
    public let displayName = "Finder"
    public let capabilities: Set<AppDriverCapability> = [.open, .search, .read, .write, .manageWindows]
    private let appleScriptBridge: AppleScriptBridge

    public init(appleScriptBridge: AppleScriptBridge = AppleScriptBridge()) {
        self.appleScriptBridge = appleScriptBridge
    }

    public func open(path: String) throws {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func reveal(path: String) throws {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func listDirectory(path: String) throws -> [String] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw NSError(domain: "FinderDriver", code: 1, userInfo: [NSLocalizedDescriptionKey: "目录不存在: \(path)"])
        }
        return try fm.contentsOfDirectory(atPath: path).sorted()
    }

    public func search(named query: String, in path: String) throws -> [String] {
        let items = try listDirectory(path: path)
        let normalized = query.lowercased()
        return items.filter { $0.lowercased().contains(normalized) }
    }

    public func createFolder(path: String, name: String) throws -> String {
        let fm = FileManager.default
        let folderPath = (path as NSString).appendingPathComponent(name)
        try fm.createDirectory(atPath: folderPath, withIntermediateDirectories: false, attributes: nil)
        return folderPath
    }

    public func moveItem(from sourcePath: String, to destPath: String) throws {
        let fm = FileManager.default
        try fm.moveItem(atPath: sourcePath, toPath: destPath)
    }

    public func copyItem(from sourcePath: String, to destPath: String) throws {
        let fm = FileManager.default
        try fm.copyItem(atPath: sourcePath, toPath: destPath)
    }

    public func deleteItem(path: String) throws {
        let url = URL(fileURLWithPath: path)
        var resultURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
    }

    public func getFileInfo(path: String) throws -> [String: String] {
        let fm = FileManager.default
        let attrs = try fm.attributesOfItem(atPath: path)
        var info: [String: String] = [:]
        if let size = attrs[.size] as? Int { info["size"] = ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file) }
        if let date = attrs[.modificationDate] as? Date { info["modified"] = ISO8601DateFormatter().string(from: date) }
        if let date = attrs[.creationDate] as? Date { info["created"] = ISO8601DateFormatter().string(from: date) }
        if let type = attrs[.type] as? String { info["type"] = type }
        if let posix = attrs[.posixPermissions] as? Int { info["permissions"] = String(posix, radix: 8) }
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: path, isDirectory: &isDir) {
            info["isDirectory"] = isDir.boolValue ? "true" : "false"
        }
        return info
    }

    public func renameItem(at sourcePath: String, to newName: String) throws {
        let parentPath = (sourcePath as NSString).deletingLastPathComponent
        let destPath = (parentPath as NSString).appendingPathComponent(newName)
        try moveItem(from: sourcePath, to: destPath)
    }

    // MARK: - Conflict Detection

    public func checkConflict(at path: String, requiredDiskSpace: Int64 = 0) -> FileConflict? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: path, isDirectory: &isDir) {
            return FileConflict(path: path, kind: .exists)
        }
        if !fm.isWritableFile(atPath: (path as NSString).deletingLastPathComponent) {
            return FileConflict(path: path, kind: .permissionDenied)
        }
        if requiredDiskSpace > 0 {
            let free = (try? diskFreeSpace(for: (path as NSString).deletingLastPathComponent)) ?? 0
            if free < requiredDiskSpace {
                return FileConflict(path: path, kind: .diskFull)
            }
        }
        return nil
    }

    public func resolveConflict(_ conflict: FileConflict, strategy: ConflictStrategy) -> String {
        switch (conflict.kind, strategy) {
        case (.exists, .rename):
            let parent = (conflict.path as NSString).deletingLastPathComponent
            let name = (conflict.path as NSString).lastPathComponent
            let stem = (name as NSString).deletingPathExtension
            let ext = (name as NSString).pathExtension
            var counter = 1
            var candidate: String
            repeat {
                let newName = ext.isEmpty ? "\(stem) \(counter)" : "\(stem) \(counter).\(ext)"
                candidate = (parent as NSString).appendingPathComponent(newName)
                counter += 1
            } while FileManager.default.fileExists(atPath: candidate)
            return candidate
        case (.exists, .overwrite):
            return conflict.path
        case (.exists, .skip):
            return conflict.path
        default:
            return conflict.path
        }
    }

    // MARK: - Verification

    public func verifyExists(path: String) -> (verified: Bool, evidence: String) {
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: path)
        if exists {
            let size = (try? fm.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
            return (true, "路径存在: \(path) (\(size) bytes)")
        }
        return (false, "路径不存在: \(path)")
    }

    public func verifyNotExists(path: String) -> (verified: Bool, evidence: String) {
        let exists = FileManager.default.fileExists(atPath: path)
        return exists ? (false, "路径仍存在: \(path)") : (true, "路径已移除: \(path)")
    }

    public func verifyRenamed(oldPath: String, newPath: String) -> (verified: Bool, evidence: String) {
        let oldExists = FileManager.default.fileExists(atPath: oldPath)
        let newExists = FileManager.default.fileExists(atPath: newPath)
        if !oldExists && newExists {
            return (true, "重命名验证通过: \(oldPath) → \(newPath)")
        }
        if oldExists && newExists {
            return (false, "源文件仍存在,目标也已存在(可能是复制): \(oldPath)")
        }
        if oldExists {
            return (false, "源文件未变更: \(oldPath)")
        }
        return (false, "目标文件不存在: \(newPath)")
    }

    // MARK: - Verified Operations

    @discardableResult
    public func createFolderVerified(path: String, name: String, conflictStrategy: ConflictStrategy = .rename) -> FileOperationResult {
        let destPath = (path as NSString).appendingPathComponent(name)
        if let conflict = checkConflict(at: destPath) {
            let resolved = resolveConflict(conflict, strategy: conflictStrategy)
            if conflictStrategy == .skip { return FileOperationResult(success: true, verified: false, sourcePath: path, destPath: destPath, resolvedDestPath: nil, conflict: conflict, error: "已跳过") }
            do {
                try FileManager.default.createDirectory(atPath: resolved, withIntermediateDirectories: false, attributes: nil)
                let v = verifyExists(path: resolved)
                return FileOperationResult(success: true, verified: v.verified, sourcePath: path, destPath: destPath, resolvedDestPath: resolved, conflict: conflict)
            } catch {
                return FileOperationResult(success: false, verified: false, sourcePath: path, destPath: destPath, resolvedDestPath: resolved, conflict: conflict, error: error.localizedDescription)
            }
        }
        do {
            try FileManager.default.createDirectory(atPath: destPath, withIntermediateDirectories: false, attributes: nil)
            let v = verifyExists(path: destPath)
            return FileOperationResult(success: true, verified: v.verified, sourcePath: path, destPath: destPath)
        } catch {
            return FileOperationResult(success: false, verified: false, sourcePath: path, destPath: destPath, error: error.localizedDescription)
        }
    }

    @discardableResult
    public func moveItemVerified(from: String, to: String, conflictStrategy: ConflictStrategy = .rename) -> FileOperationResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: from) else {
            return FileOperationResult(success: false, verified: false, sourcePath: from, destPath: to, conflict: FileConflict(path: from, kind: .missingSource), error: "源文件不存在")
        }
        if let conflict = checkConflict(at: to) {
            let resolved = resolveConflict(conflict, strategy: conflictStrategy)
            if conflictStrategy == .skip { return FileOperationResult(success: true, verified: false, sourcePath: from, destPath: to, resolvedDestPath: nil, conflict: conflict, error: "已跳过") }
            do {
                try fm.moveItem(atPath: from, toPath: resolved)
                let v = verifyRenamed(oldPath: from, newPath: resolved)
                return FileOperationResult(success: true, verified: v.verified, sourcePath: from, destPath: to, resolvedDestPath: resolved, conflict: conflict)
            } catch {
                return FileOperationResult(success: false, verified: false, sourcePath: from, destPath: to, resolvedDestPath: resolved, conflict: conflict, error: error.localizedDescription)
            }
        }
        do {
            try fm.moveItem(atPath: from, toPath: to)
            let v = verifyRenamed(oldPath: from, newPath: to)
            return FileOperationResult(success: true, verified: v.verified, sourcePath: from, destPath: to)
        } catch {
            return FileOperationResult(success: false, verified: false, sourcePath: from, destPath: to, error: error.localizedDescription)
        }
    }

    @discardableResult
    public func copyItemVerified(from: String, to: String, conflictStrategy: ConflictStrategy = .rename) -> FileOperationResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: from) else {
            return FileOperationResult(success: false, verified: false, sourcePath: from, destPath: to, conflict: FileConflict(path: from, kind: .missingSource), error: "源文件不存在")
        }
        if let conflict = checkConflict(at: to) {
            let resolved = resolveConflict(conflict, strategy: conflictStrategy)
            if conflictStrategy == .skip { return FileOperationResult(success: true, verified: false, sourcePath: from, destPath: to, resolvedDestPath: nil, conflict: conflict, error: "已跳过") }
            do {
                try fm.copyItem(atPath: from, toPath: resolved)
                let v = verifyExists(path: resolved)
                return FileOperationResult(success: true, verified: v.verified, sourcePath: from, destPath: to, resolvedDestPath: resolved, conflict: conflict)
            } catch {
                return FileOperationResult(success: false, verified: false, sourcePath: from, destPath: to, resolvedDestPath: resolved, conflict: conflict, error: error.localizedDescription)
            }
        }
        do {
            try fm.copyItem(atPath: from, toPath: to)
            let v = verifyExists(path: to)
            return FileOperationResult(success: true, verified: v.verified, sourcePath: from, destPath: to)
        } catch {
            return FileOperationResult(success: false, verified: false, sourcePath: from, destPath: to, error: error.localizedDescription)
        }
    }

    @discardableResult
    public func deleteItemVerified(path: String) -> FileOperationResult {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else {
            return FileOperationResult(success: false, verified: false, sourcePath: path, conflict: FileConflict(path: path, kind: .missingSource), error: "文件不存在")
        }
        do {
            let url = URL(fileURLWithPath: path)
            var resultURL: NSURL?
            try fm.trashItem(at: url, resultingItemURL: &resultURL)
            let v = verifyNotExists(path: path)
            let trashPath = (resultURL as URL?)?.path
            return FileOperationResult(success: true, verified: v.verified, sourcePath: path, destPath: trashPath)
        } catch {
            return FileOperationResult(success: false, verified: false, sourcePath: path, error: error.localizedDescription)
        }
    }

    @discardableResult
    public func renameItemVerified(at sourcePath: String, to newName: String, conflictStrategy: ConflictStrategy = .rename) -> FileOperationResult {
        let parentPath = (sourcePath as NSString).deletingLastPathComponent
        let destPath = (parentPath as NSString).appendingPathComponent(newName)
        let fm = FileManager.default
        guard fm.fileExists(atPath: sourcePath) else {
            return FileOperationResult(success: false, verified: false, sourcePath: sourcePath, destPath: destPath, conflict: FileConflict(path: sourcePath, kind: .missingSource), error: "源文件不存在")
        }
        if let conflict = checkConflict(at: destPath) {
            let resolved = resolveConflict(conflict, strategy: conflictStrategy)
            if conflictStrategy == .skip { return FileOperationResult(success: true, verified: false, sourcePath: sourcePath, destPath: destPath, resolvedDestPath: nil, conflict: conflict, error: "已跳过") }
            do {
                try fm.moveItem(atPath: sourcePath, toPath: resolved)
                let v = verifyRenamed(oldPath: sourcePath, newPath: resolved)
                return FileOperationResult(success: true, verified: v.verified, sourcePath: sourcePath, destPath: destPath, resolvedDestPath: resolved, conflict: conflict)
            } catch {
                return FileOperationResult(success: false, verified: false, sourcePath: sourcePath, destPath: destPath, resolvedDestPath: resolved, conflict: conflict, error: error.localizedDescription)
            }
        }
        do {
            try fm.moveItem(atPath: sourcePath, toPath: destPath)
            let v = verifyRenamed(oldPath: sourcePath, newPath: destPath)
            return FileOperationResult(success: true, verified: v.verified, sourcePath: sourcePath, destPath: destPath)
        } catch {
            return FileOperationResult(success: false, verified: false, sourcePath: sourcePath, destPath: destPath, error: error.localizedDescription)
        }
    }

    // MARK: - Batch Operations

    public func batchMove(_ pairs: [(from: String, to: String)]) -> [(from: String, to: String, error: String?)] {
        pairs.map { pair in
            do {
                try moveItem(from: pair.from, to: pair.to)
                return (pair.from, pair.to, nil)
            } catch {
                return (pair.from, pair.to, error.localizedDescription)
            }
        }
    }

    public func batchMoveVerified(_ pairs: [(from: String, to: String)], conflictStrategy: ConflictStrategy = .rename) -> [FileOperationResult] {
        pairs.map { moveItemVerified(from: $0.from, to: $0.to, conflictStrategy: conflictStrategy) }
    }

    public func batchCopyVerified(_ pairs: [(from: String, to: String)], conflictStrategy: ConflictStrategy = .rename) -> [FileOperationResult] {
        pairs.map { copyItemVerified(from: $0.from, to: $0.to, conflictStrategy: conflictStrategy) }
    }

    public func batchDeleteVerified(_ paths: [String]) -> [FileOperationResult] {
        paths.map { deleteItemVerified(path: $0) }
    }

    public func batchRenameVerified(_ items: [(at: String, to: String)], conflictStrategy: ConflictStrategy = .rename) -> [FileOperationResult] {
        items.map { renameItemVerified(at: $0.at, to: $0.to, conflictStrategy: conflictStrategy) }
    }

    // MARK: - Deep Operations

    public func searchByContent(query: String, in path: String, fileExtension: String? = nil) async throws -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        var args = ["-rl", query, path]
        if let ext = fileExtension { args.append(contentsOf: ["--include", "*.\(ext)"]) }
        process.arguments = args
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        let output = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            process.terminationHandler = { _ in
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                cont.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }
        return output.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    public func recentFiles(in path: String, limit: Int = 20) throws -> [FileInfo] {
        let fm = FileManager.default
        let urls = try fm.contentsOfDirectory(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modDate = values.contentModificationDate else { return nil }
            return FileInfo(path: url.path, name: url.lastPathComponent, size: Int64(values.fileSize ?? 0), modifiedAt: modDate)
        }
        .sorted { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
        .prefix(limit)
        .map { $0 }
    }

    public func diskFreeSpace(for path: String) throws -> Int64 {
        let values = try FileManager.default.attributesOfFileSystem(forPath: path)
        return (values[.systemFreeSize] as? Int64) ?? 0
    }

    public func currentWindowState() async throws -> FinderWindowState {
        let script = #"""
        tell application "Finder"
            if not (exists Finder window 1) then
                return ""
            end if
            set windowTitle to name of Finder window 1
            set currentPath to POSIX path of (target of Finder window 1 as alias)
            set output to windowTitle & linefeed & currentPath & linefeed
            set selectedItems to selection
            repeat with anItem in selectedItems
                set output to output & (POSIX path of (anItem as alias)) & linefeed
            end repeat
            return output
        end tell
        """#
        let result = try await appleScriptBridge.run(script)
        return Self.parseFinderWindowState(result.stringValue)
    }

    static func parseFinderWindowState(_ raw: String?) -> FinderWindowState {
        let lines = (raw ?? "").components(separatedBy: .newlines)
        let windowTitle = lines[safe: 0]?.nonEmptyValue
        let currentPath = lines[safe: 1]?.nonEmptyValue
        let selectedItems = Array(lines.dropFirst(2))
            .compactMap { $0.nonEmptyValue }
        return FinderWindowState(
            windowTitle: windowTitle,
            currentPath: currentPath,
            selectedItems: selectedItems
        )
    }
}
