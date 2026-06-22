import Foundation
import XCTest
import RenJistrolyModels

// MARK: - BrowserPageState

func testBrowserPageStateMinimalInit() {
    let state = BrowserPageState(browserName: "Safari")
    XCTAssertTrue(state.browserName == "Safari")
    XCTAssertTrue(state.windowTitle == nil)
    XCTAssertTrue(state.tabTitle == nil)
    XCTAssertTrue(state.url == nil)
    XCTAssertTrue(state.host == nil)
    XCTAssertTrue(state.searchQuery == nil)
}

func testBrowserPageStateFullInit() {
    let state = BrowserPageState(
        browserName: "Chrome",
        windowTitle: "GitHub",
        tabTitle: "Pull Request",
        url: "https://github.com/user/repo/pull/1",
        host: "github.com",
        searchQuery: "pr"
    )
    XCTAssertTrue(state.browserName == "Chrome")
    XCTAssertTrue(state.windowTitle == "GitHub")
    XCTAssertTrue(state.tabTitle == "Pull Request")
    XCTAssertTrue(state.url == "https://github.com/user/repo/pull/1")
    XCTAssertTrue(state.host == "github.com")
    XCTAssertTrue(state.searchQuery == "pr")
}

// MARK: - BrowserDOMElement

func testBrowserDOMElementMinimalInit() {
    let el = BrowserDOMElement(tag: "button")
    XCTAssertTrue(el.tag == "button")
    XCTAssertTrue(el.text == nil)
    XCTAssertTrue(el.value == nil)
    XCTAssertTrue(el.href == nil)
    XCTAssertTrue(el.visible == true)
    XCTAssertTrue(el.rect == nil)
}

func testBrowserDOMElementExplicitVisible() {
    let hidden = BrowserDOMElement(tag: "div", visible: false)
    XCTAssertFalse(hidden.visible)
}

func testBrowserDOMElementFullInit() {
    let rect = BrowserDOMRect(x: 10, y: 20, w: 100, h: 30)
    let el = BrowserDOMElement(
        tag: "a",
        text: "click here",
        value: "link",
        href: "https://example.com",
        visible: true,
        rect: rect
    )
    XCTAssertTrue(el.tag == "a")
    XCTAssertTrue(el.text == "click here")
    XCTAssertTrue(el.value == "link")
    XCTAssertTrue(el.href == "https://example.com")
    XCTAssertTrue(el.visible)
    XCTAssertTrue(el.rect?.x == 10)
    XCTAssertTrue(el.rect?.y == 20)
    XCTAssertTrue(el.rect?.w == 100)
    XCTAssertTrue(el.rect?.h == 30)
}

// MARK: - BrowserDOMRect

func testBrowserDOMRectInit() {
    let rect = BrowserDOMRect(x: 0, y: 0, w: 300, h: 200)
    XCTAssertTrue(rect.x == 0)
    XCTAssertTrue(rect.y == 0)
    XCTAssertTrue(rect.w == 300)
    XCTAssertTrue(rect.h == 200)
}

func testBrowserDOMRectEquatable() {
    let a = BrowserDOMRect(x: 0, y: 0, w: 100, h: 50)
    let b = BrowserDOMRect(x: 0, y: 0, w: 100, h: 50)
    let c = BrowserDOMRect(x: 1, y: 0, w: 100, h: 50)
    XCTAssertTrue(a == b)
    XCTAssertTrue(a != c)
}
