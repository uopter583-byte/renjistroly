import Foundation

public struct FinderWindowState: Codable, Sendable, Hashable {
    public let windowTitle: String?
    public let currentPath: String?
    public let selectedItems: [String]

    public init(
        windowTitle: String? = nil,
        currentPath: String? = nil,
        selectedItems: [String] = []
    ) {
        self.windowTitle = windowTitle
        self.currentPath = currentPath
        self.selectedItems = selectedItems
    }
}

// MARK: - File Operation Types

public enum ConflictStrategy: String, Codable, Sendable, CaseIterable {
    case rename
    case overwrite
    case skip
}

public enum FileConflictKind: String, Codable, Sendable {
    case exists
    case permissionDenied
    case diskFull
    case missingSource
}

public struct FileConflict: Codable, Sendable {
    public let path: String
    public let kind: FileConflictKind

    public init(path: String, kind: FileConflictKind) {
        self.path = path
        self.kind = kind
    }
}

public struct FileOperationResult: Codable, Sendable {
    public let success: Bool
    public let verified: Bool
    public let sourcePath: String
    public let destPath: String?
    public let resolvedDestPath: String?
    public let conflict: FileConflict?
    public let error: String?

    public init(
        success: Bool,
        verified: Bool,
        sourcePath: String,
        destPath: String? = nil,
        resolvedDestPath: String? = nil,
        conflict: FileConflict? = nil,
        error: String? = nil
    ) {
        self.success = success
        self.verified = verified
        self.sourcePath = sourcePath
        self.destPath = destPath
        self.resolvedDestPath = resolvedDestPath
        self.conflict = conflict
        self.error = error
    }
}
