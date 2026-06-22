import Foundation
import XCTest
@testable import RenJistrolyModels

// MARK: - ProjectType

func testProjectTypeRawValues() {
    XCTAssertTrue(ProjectContext.ProjectType.swiftPM.rawValue == "swiftPM")
    XCTAssertTrue(ProjectContext.ProjectType.xcode.rawValue == "xcode")
    XCTAssertTrue(ProjectContext.ProjectType.node.rawValue == "node")
    XCTAssertTrue(ProjectContext.ProjectType.python.rawValue == "python")
    XCTAssertTrue(ProjectContext.ProjectType.rust.rawValue == "rust")
    XCTAssertTrue(ProjectContext.ProjectType.go.rawValue == "go")
    XCTAssertTrue(ProjectContext.ProjectType.unknown.rawValue == "unknown")
}

func testProjectTypeHashable() {
    let a: Set<ProjectContext.ProjectType> = [.swiftPM, .xcode]
    XCTAssertTrue(a.contains(.swiftPM))
    XCTAssertTrue(a.contains(.xcode))
    XCTAssertTrue(!a.contains(.python))
}

// MARK: - ProjectContext

func testProjectContextEmptyInit() {
    let ctx = ProjectContext()
    XCTAssertTrue(ctx.rootPath == nil)
    XCTAssertTrue(ctx.activeFile == nil)
    XCTAssertTrue(ctx.gitBranch == nil)
    XCTAssertTrue(ctx.gitRemote == nil)
    XCTAssertTrue(ctx.projectType == nil)
    XCTAssertTrue(ctx.dependencies == nil)
    XCTAssertTrue(ctx.activeAppBundleID == nil)
    XCTAssertTrue(ctx.selectedText == nil)
    XCTAssertTrue(ctx.screenSummary == nil)
}

func testProjectContextPartialInit() {
    let ctx = ProjectContext(rootPath: "/tmp", projectType: .swiftPM)
    XCTAssertTrue(ctx.rootPath == "/tmp")
    XCTAssertTrue(ctx.projectType == .swiftPM)
    XCTAssertTrue(ctx.gitBranch == nil)
}

func testProjectContextFullInit() {
    let ctx = ProjectContext(
        rootPath: "/Users/yoming/RenJistroly",
        activeFile: "Package.swift",
        gitBranch: "main",
        gitRemote: "origin",
        projectType: .swiftPM,
        dependencies: ["Algorithms"],
        activeAppBundleID: "com.apple.Xcode",
        selectedText: "struct Foo",
        screenSummary: "Xcode window"
    )
    XCTAssertTrue(ctx.rootPath == "/Users/yoming/RenJistroly")
    XCTAssertTrue(ctx.activeFile == "Package.swift")
    XCTAssertTrue(ctx.gitBranch == "main")
    XCTAssertTrue(ctx.gitRemote == "origin")
    XCTAssertTrue(ctx.projectType == .swiftPM)
    XCTAssertTrue(ctx.dependencies == ["Algorithms"])
    XCTAssertTrue(ctx.activeAppBundleID == "com.apple.Xcode")
    XCTAssertTrue(ctx.selectedText == "struct Foo")
    XCTAssertTrue(ctx.screenSummary == "Xcode window")
}

func testProjectContextHashable() {
    let a = ProjectContext(rootPath: "/tmp", gitBranch: "main")
    let b = ProjectContext(rootPath: "/tmp", gitBranch: "main")
    XCTAssertTrue(a == b)
    XCTAssertTrue(a.hashValue == b.hashValue)
}
