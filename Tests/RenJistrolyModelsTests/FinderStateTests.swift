import Foundation
import XCTest
@testable import RenJistrolyModels

// MARK: - FinderWindowState

func testFinderWindowStateEmptyInit() {
    let state = FinderWindowState()
    XCTAssertTrue(state.windowTitle == nil)
    XCTAssertTrue(state.currentPath == nil)
    XCTAssertTrue(state.selectedItems.isEmpty)
}

func testFinderWindowStatePartialInit() {
    let state = FinderWindowState(currentPath: "/tmp")
    XCTAssertTrue(state.currentPath == "/tmp")
    XCTAssertTrue(state.windowTitle == nil)
    XCTAssertTrue(state.selectedItems.isEmpty)
}

func testFinderWindowStateFullInit() {
    let state = FinderWindowState(
        windowTitle: "Downloads",
        currentPath: "/Users/yoming/Downloads",
        selectedItems: ["/Users/yoming/Downloads/file.zip"]
    )
    XCTAssertTrue(state.windowTitle == "Downloads")
    XCTAssertTrue(state.currentPath == "/Users/yoming/Downloads")
    XCTAssertTrue(state.selectedItems.count == 1)
    XCTAssertTrue(state.selectedItems[0] == "/Users/yoming/Downloads/file.zip")
}

func testFinderWindowStateWithMultipleSelectedItems() {
    let state = FinderWindowState(
        currentPath: "/tmp",
        selectedItems: ["/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt"]
    )
    XCTAssertTrue(state.selectedItems.count == 3)
}

func testFinderWindowStateAllOptionalInit() {
    let state = FinderWindowState(windowTitle: nil, currentPath: nil, selectedItems: [])
    XCTAssertTrue(state.windowTitle == nil)
    XCTAssertTrue(state.currentPath == nil)
    XCTAssertTrue(state.selectedItems.isEmpty)
}

func testFinderWindowStateNoWindowTitle() {
    let state = FinderWindowState(currentPath: "/tmp", selectedItems: ["/tmp/a.txt"])
    XCTAssertTrue(state.windowTitle == nil)
    XCTAssertTrue(state.currentPath == "/tmp")
    XCTAssertTrue(state.selectedItems == ["/tmp/a.txt"])
}
