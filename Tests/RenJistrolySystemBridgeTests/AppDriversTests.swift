import Foundation
import XCTest
@testable import RenJistrolySystemBridge

func testSafariBrowserPageStateParsingExtractsHostAndQuery() {
    let raw = """
    Google Search
    openai codex - Google Search
    https://www.google.com/search?q=openai%20codex&sourceid=chrome
    """

    let state = SafariDriver.parseBrowserPageState(raw, browserName: "Safari")

    XCTAssertTrue(state.browserName == "Safari")
    XCTAssertTrue(state.windowTitle == "Google Search")
    XCTAssertTrue(state.tabTitle == "openai codex - Google Search")
    XCTAssertTrue(state.host == "google.com")
    XCTAssertTrue(state.searchQuery == "openai codex")
}

func testSafariBrowserPageStateParsingHandlesNormalPageURL() {
    let raw = """
    OpenAI Platform
    Function calling
    https://platform.openai.com/docs/guides/function-calling
    """

    let state = SafariDriver.parseBrowserPageState(raw, browserName: "Safari")

    XCTAssertTrue(state.host == "platform.openai.com")
    XCTAssertTrue(state.searchQuery == nil)
    XCTAssertTrue(state.url == "https://platform.openai.com/docs/guides/function-calling")
}

func testFinderWindowStateParsingCapturesDirectoryAndSelection() {
    let raw = """
    Workspace
    /Users/yoming/RenJistroly/
    /Users/yoming/RenJistroly/Package.swift
    /Users/yoming/RenJistroly/Sources
    """

    let state = FinderDriver.parseFinderWindowState(raw)

    XCTAssertTrue(state.windowTitle == "Workspace")
    XCTAssertTrue(state.currentPath == "/Users/yoming/RenJistroly/")
    XCTAssertTrue(state.selectedItems == [
        "/Users/yoming/RenJistroly/Package.swift",
        "/Users/yoming/RenJistroly/Sources",
    ])
}

// MARK: - XcodeDriver parseBuildDiagnostics tests

func testParseErrorLine() {
    let output = "/path/to/file.swift:42:10: error: 'foo' is not a member of 'Bar'"
    let diagnostics = XcodeDriver.parseBuildDiagnostics(from: output)
    XCTAssertTrue(diagnostics.count == 1)
    XCTAssertTrue(diagnostics[0].filePath == "/path/to/file.swift")
    XCTAssertTrue(diagnostics[0].line == 42)
    XCTAssertTrue(diagnostics[0].column == 10)
    XCTAssertTrue(diagnostics[0].severity == .error)
    XCTAssertTrue(diagnostics[0].message == "'foo' is not a member of 'Bar'")
}

func testParseWarningLine() {
    let output = "main.swift:15:5: warning: variable 'x' was never mutated"
    let diagnostics = XcodeDriver.parseBuildDiagnostics(from: output)
    XCTAssertTrue(diagnostics.count == 1)
    XCTAssertTrue(diagnostics[0].severity == .warning)
    XCTAssertTrue(diagnostics[0].message == "variable 'x' was never mutated")
}

func testParseNoteLine() {
    let output = "App.swift:8:3: note: did you mean 'count'?"
    let diagnostics = XcodeDriver.parseBuildDiagnostics(from: output)
    XCTAssertTrue(diagnostics.count == 1)
    XCTAssertTrue(diagnostics[0].severity == .note)
    XCTAssertTrue(diagnostics[0].filePath == "App.swift")
}

func testParseMultipleDiagnostics() {
    let output = """
    foo.swift:1:1: error: type 'Foo' does not conform to protocol 'Equatable'
    bar.swift:20:5: warning: result of call is unused
    baz.swift:30:10: note: see declaration here
    """
    let diagnostics = XcodeDriver.parseBuildDiagnostics(from: output)
    XCTAssertTrue(diagnostics.count == 3)
    XCTAssertTrue(diagnostics[0].severity == .error)
    XCTAssertTrue(diagnostics[1].severity == .warning)
    XCTAssertTrue(diagnostics[2].severity == .note)
}

func testParseNoDiagnostics() {
    let output = """
    Build succeeded
    No issues found
    """
    let diagnostics = XcodeDriver.parseBuildDiagnostics(from: output)
    XCTAssertTrue(diagnostics.isEmpty)
}

func testParseEmptyString() {
    let diagnostics = XcodeDriver.parseBuildDiagnostics(from: "")
    XCTAssertTrue(diagnostics.isEmpty)
}

// MARK: - XcodeDriver parseXcodeState tests

func testParseXcodeStateComplete() {
    let raw = """
    RenJistroly — Package.swift
    /Users/yoming/Projects/RenJistroly
    RenJistroly
    """
    let state = XcodeDriver.parseXcodeState(raw)
    XCTAssertTrue(state.windowTitle == "RenJistroly — Package.swift")
    XCTAssertTrue(state.workspacePath == "/Users/yoming/Projects/RenJistroly")
    XCTAssertTrue(state.activeScheme == "RenJistroly")
}

func testParseXcodeStateNilInput() {
    let state = XcodeDriver.parseXcodeState(nil)
    XCTAssertTrue(state.windowTitle == nil)
    XCTAssertTrue(state.workspacePath == nil)
}

func testParseXcodeStateEmptyInput() {
    let state = XcodeDriver.parseXcodeState("")
    XCTAssertTrue(state.windowTitle == nil)
    XCTAssertTrue(state.workspacePath == nil)
    XCTAssertTrue(state.activeScheme == nil)
}

// MARK: - BrowserPageState parsing edge cases

func testBrowserPageStateParsingNilInput() {
    let state = SafariDriver.parseBrowserPageState(nil, browserName: "Safari")
    XCTAssertTrue(state.browserName == "Safari")
    XCTAssertTrue(state.windowTitle == nil)
    XCTAssertTrue(state.tabTitle == nil)
    XCTAssertTrue(state.url == nil)
}

func testBrowserPageStateParsingEmptyInput() {
    let state = SafariDriver.parseBrowserPageState("", browserName: "Chrome")
    XCTAssertTrue(state.browserName == "Chrome")
    XCTAssertTrue(state.host == nil)
    XCTAssertTrue(state.searchQuery == nil)
}

func testBrowserPageStateParsingPartialLines() {
    let raw = "Window Only"
    let state = SafariDriver.parseBrowserPageState(raw, browserName: "Safari")
    XCTAssertTrue(state.windowTitle == "Window Only")
    XCTAssertTrue(state.tabTitle == nil)
    XCTAssertTrue(state.url == nil)
}

// MARK: - FinderWindowState parsing edge cases

func testFinderWindowStateParsingNilInput() {
    let state = FinderDriver.parseFinderWindowState(nil)
    XCTAssertTrue(state.windowTitle == nil)
    XCTAssertTrue(state.currentPath == nil)
    XCTAssertTrue(state.selectedItems.isEmpty)
}

func testFinderWindowStateParsingEmptyInput() {
    let state = FinderDriver.parseFinderWindowState("")
    XCTAssertTrue(state.windowTitle == nil)
    XCTAssertTrue(state.currentPath == nil)
}

func testFinderWindowStateParsingNoSelection() {
    let raw = """
    Workspace
    /Users/yoming/Projects/
    """
    let state = FinderDriver.parseFinderWindowState(raw)
    XCTAssertTrue(state.windowTitle == "Workspace")
    XCTAssertTrue(state.currentPath == "/Users/yoming/Projects/")
    XCTAssertTrue(state.selectedItems.isEmpty)
}

// MARK: - SystemSettingsPane url tests

func testWifiPaneHasURL() {
    XCTAssertTrue(SystemSettingsPane.wifi.url != nil)
}

func testPasswordsPaneHasURL() {
    XCTAssertTrue(SystemSettingsPane.passwords.url != nil)
}

func testSiriPaneURLIsNil() {
    XCTAssertTrue(SystemSettingsPane.siri.url == nil)
}

// MARK: - AppDriverRegistry tests

func testRegistryContainsAllDefaultDrivers() {
    let registry = AppDriverRegistry()
    let ids = registry.drivers.map(\.id)
    XCTAssertTrue(ids.contains("finder"))
    XCTAssertTrue(ids.contains("safari"))
    XCTAssertTrue(ids.contains("chrome"))
    XCTAssertTrue(ids.contains("terminal"))
    XCTAssertTrue(ids.contains("xcode"))
    XCTAssertTrue(ids.contains("system-settings"))
    XCTAssertTrue(ids.contains("wechat"))
    XCTAssertTrue(ids.contains("system"))
}

func testRegistryLookupExistingDriver() {
    let registry = AppDriverRegistry()
    let safari = registry.driver(id: "safari")
    XCTAssertTrue(safari != nil)
    XCTAssertTrue(safari?.displayName == "Safari")
}

func testRegistryLookupMissingDriver() {
    let registry = AppDriverRegistry()
    XCTAssertTrue(registry.driver(id: "firefox") == nil)
}

// MARK: - ConsoleLogEntry / NetworkRequestEntry Codable

func testConsoleLogEntryCodable() throws {
    let json = #"{"level":"error","message":"something went wrong","ts":1718800000000}"#
    let data = Data(json.utf8)
    let entry = try JSONDecoder().decode(ConsoleLogEntry.self, from: data)
    XCTAssertTrue(entry.level == "error")
    XCTAssertTrue(entry.message == "something went wrong")
    XCTAssertTrue(entry.ts == 1718800000000)
}

func testNetworkRequestEntryCodable() throws {
    let json = #"{"method":"GET","url":"https://example.com","statusCode":200,"duration":150,"ts":1718800000000}"#
    let data = Data(json.utf8)
    let entry = try JSONDecoder().decode(NetworkRequestEntry.self, from: data)
    XCTAssertTrue(entry.method == "GET")
    XCTAssertTrue(entry.url == "https://example.com")
    XCTAssertTrue(entry.statusCode == 200)
    XCTAssertTrue(entry.duration == 150)
}

func testNetworkRequestEntryWithError() throws {
    let json = #"{"method":"POST","url":"https://api.example.com","statusCode":0,"duration":5000,"ts":1718800000000,"error":"timeout"}"#
    let data = Data(json.utf8)
    let entry = try JSONDecoder().decode(NetworkRequestEntry.self, from: data)
    XCTAssertTrue(entry.statusCode == 0)
    XCTAssertTrue(entry.error == "timeout")
}

func testNetworkRequestEntryInit() {
    let entry = NetworkRequestEntry(
        method: "PUT", url: "https://example.com", statusCode: 201, duration: 300, ts: 1000, error: nil
    )
    XCTAssertTrue(entry.method == "PUT")
    XCTAssertTrue(entry.statusCode == 201)
    XCTAssertTrue(entry.error == nil)
}
