import XCTest
@testable import RenJistrolyModels

func testComputerUseAppStateOmitsScreenshotWhenRequested() {
    let state = ComputerUseAppState(
        activeAppBundleID: "com.apple.TextEdit",
        activeAppName: "TextEdit",
        focusedWindowTitle: "Notes",
        elements: [
            ComputerUseElement(
                elementIndex: "e1",
                role: "AXButton",
                title: "Done",
                frame: CodableRect(x: 10, y: 20, width: 100, height: 30),
                depth: 1,
                childPath: [0]
            )
        ],
        screenshotPNGBase64: "secret-image"
    )

    let redacted = state.jsonString(includeScreenshot: false)
    let included = state.jsonString(includeScreenshot: true)

    XCTAssertTrue(redacted.contains("\"activeAppName\" : \"TextEdit\""))
    XCTAssertTrue(redacted.contains("\"elementIndex\" : \"e1\""))
    XCTAssertTrue(!redacted.contains("secret-image"))
    XCTAssertTrue(included.contains("secret-image"))
}

func testComputerUseElementCompactLabelPrefersVisibleText() {
    let element = ComputerUseElement(
        elementIndex: "e2",
        role: "AXTextField",
        title: nil,
        value: "Search",
        depth: 2,
        childPath: [0, 1]
    )

    XCTAssertTrue(element.compactLabel == "Search")
}

func testComputerUseElementStableIDUsesPathAndLabel() {
    let element = ComputerUseElement(
        elementIndex: "e3",
        role: "AXButton",
        title: "Send Message",
        depth: 2,
        childPath: [0, 4, 1]
    )

    XCTAssertTrue(element.stableID == "axbutton:0.4.1:send-message")
}

func testComputerUseStateDeltaDetectsVisibleTextChange() {
    let before = ComputerUseAppState(
        activeAppName: "Notes",
        focusedWindowTitle: "Draft",
        elements: [
            ComputerUseElement(
                elementIndex: "e1",
                role: "AXStaticText",
                title: "Before",
                depth: 1,
                childPath: [0]
            )
        ]
    )
    let after = ComputerUseAppState(
        activeAppName: "Notes",
        focusedWindowTitle: "Draft",
        elements: [
            ComputerUseElement(
                elementIndex: "e1",
                role: "AXStaticText",
                title: "After",
                depth: 1,
                childPath: [0]
            )
        ]
    )

    let delta = ComputerUseStateDelta(before: before, after: after)

    XCTAssertTrue(delta.visibleTextChanged)
    XCTAssertTrue(delta.hasMeaningfulChange)
    XCTAssertTrue(delta.changeDescriptions.contains("可见文本变化"))
    XCTAssertTrue(delta.summary.contains("可见文本变化"))
}

func testComputerUseStateDeltaTreatsIdenticalStateAsNoMeaningfulChange() {
    let state = ComputerUseAppState(
        activeAppName: "Finder",
        focusedWindowTitle: "Downloads",
        elements: [
            ComputerUseElement(
                elementIndex: "e1",
                role: "AXButton",
                title: "Open",
                focused: true,
                depth: 1,
                childPath: [0]
            )
        ]
    )

    let delta = ComputerUseStateDelta(before: state, after: state)

    XCTAssertFalse(delta.activeAppChanged)
    XCTAssertFalse(delta.focusedWindowChanged)
    XCTAssertFalse(delta.focusedElementChanged)
    XCTAssertFalse(delta.elementCountChanged)
    XCTAssertFalse(delta.visibleTextChanged)
    XCTAssertFalse(delta.hasMeaningfulChange)
}
