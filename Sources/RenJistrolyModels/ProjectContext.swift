import Foundation

public struct ProjectContext: Codable, Sendable, Hashable {
    public let rootPath: String?
    public let activeFile: String?
    public let gitBranch: String?
    public let gitRemote: String?
    public let projectType: ProjectType?
    public let dependencies: [String]?
    public let activeAppBundleID: String?
    public let selectedText: String?
    public let screenSummary: String?

    public init(
        rootPath: String? = nil,
        activeFile: String? = nil,
        gitBranch: String? = nil,
        gitRemote: String? = nil,
        projectType: ProjectType? = nil,
        dependencies: [String]? = nil,
        activeAppBundleID: String? = nil,
        selectedText: String? = nil,
        screenSummary: String? = nil
    ) {
        self.rootPath = rootPath
        self.activeFile = activeFile
        self.gitBranch = gitBranch
        self.gitRemote = gitRemote
        self.projectType = projectType
        self.dependencies = dependencies
        self.activeAppBundleID = activeAppBundleID
        self.selectedText = selectedText
        self.screenSummary = screenSummary
    }

    public enum ProjectType: String, Codable, Sendable, Hashable {
        case swiftPM
        case xcode
        case node
        case python
        case rust
        case go
        case unknown
    }
}
