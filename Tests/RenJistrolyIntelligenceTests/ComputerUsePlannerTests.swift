import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - parseShortcut

func testParseShortcutEnter() {
    let cp = ComputerUsePlanner()
    let r = cp.parseShortcut("回车")
    XCTAssertTrue(r?["key"] == "return")
    XCTAssertTrue(r?["modifiers"] == "")
}

func testParseShortcutConfirm() {
    let cp = ComputerUsePlanner()
    let r = cp.parseShortcut("确认")
    XCTAssertTrue(r?["key"] == "return")
}

func testParseShortcutCopy() {
    let cp = ComputerUsePlanner()
    let r = cp.parseShortcut("复制")
    XCTAssertTrue(r?["key"] == "c")
    XCTAssertTrue(r?["modifiers"] == "cmd")
}

func testParseShortcutPaste() {
    let cp = ComputerUsePlanner()
    let r = cp.parseShortcut("粘贴")
    XCTAssertTrue(r?["key"] == "v")
    XCTAssertTrue(r?["modifiers"] == "cmd")
}

func testParseShortcutSelectAll() {
    let cp = ComputerUsePlanner()
    let r = cp.parseShortcut("全选")
    XCTAssertTrue(r?["key"] == "a")
}

func testParseShortcutUndo() {
    let cp = ComputerUsePlanner()
    let r = cp.parseShortcut("撤销")
    XCTAssertTrue(r?["key"] == "z")
}

func testParseShortcutSave() {
    let cp = ComputerUsePlanner()
    let r = cp.parseShortcut("保存")
    XCTAssertTrue(r?["key"] == "s")
}

func testParseShortcutUnknown() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.parseShortcut("删除") == nil)
    XCTAssertTrue(cp.parseShortcut("hello") == nil)
}

// MARK: - parseSingleKey

func testParseSingleKeyEnter() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.parseSingleKey("按回车") == "return")
    XCTAssertTrue(cp.parseSingleKey("按确认") == "return")
}

func testParseSingleKeyEscape() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.parseSingleKey("按esc") == "escape")
    XCTAssertTrue(cp.parseSingleKey("按escape") == "escape")
    XCTAssertTrue(cp.parseSingleKey("退出弹窗") == "escape")
    XCTAssertTrue(cp.parseSingleKey("取消") == "escape")
}

func testParseSingleKeyTab() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.parseSingleKey("按tab") == "tab")
    XCTAssertTrue(cp.parseSingleKey("下一个") == "tab")
}

func testParseSingleKeySpace() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.parseSingleKey("空格") == "space")
}

func testParseSingleKeyUnknown() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.parseSingleKey("删除") == nil)
    XCTAssertTrue(cp.parseSingleKey("hello") == nil)
}

// MARK: - parseMediaCommand

func testParseMediaPlayPause() {
    let cp = ComputerUsePlanner()
    for cmd in ["播放", "暂停", "继续播放", "停止播放"] {
        let r = cp.parseMediaCommand(cmd)
        XCTAssertTrue(r?["key"] == "space")
    }
}

func testParseMediaNext() {
    let cp = ComputerUsePlanner()
    let r = cp.parseMediaCommand("下一首")
    XCTAssertTrue(r?["key"] == "right")
    XCTAssertTrue(r?["modifiers"] == "cmd")
}

func testParseMediaPrevious() {
    let cp = ComputerUsePlanner()
    let r = cp.parseMediaCommand("上一首")
    XCTAssertTrue(r?["key"] == "left")
    XCTAssertTrue(r?["modifiers"] == "cmd")
}

func testParseMediaForward() {
    let cp = ComputerUsePlanner()
    let r = cp.parseMediaCommand("快进")
    XCTAssertTrue(r?["key"] == "right")
    XCTAssertTrue(r?["modifiers"] == "")
}

func testParseMediaBackward() {
    let cp = ComputerUsePlanner()
    let r = cp.parseMediaCommand("后退")
    XCTAssertTrue(r?["key"] == "left")
    XCTAssertTrue(r?["modifiers"] == "")
}

func testParseMediaFullscreen() {
    let cp = ComputerUsePlanner()
    let r = cp.parseMediaCommand("全屏")
    XCTAssertTrue(r?["key"] == "f")
    XCTAssertTrue(r?["modifiers"] == "cmd+ctrl")
}

func testParseMediaCommandUnknown() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.parseMediaCommand("静音") == nil)
}

// MARK: - parseBrowserCommand

func testParseBrowserNewTab() {
    let cp = ComputerUsePlanner()
    for cmd in ["新建标签", "新建标签页"] {
        let r = cp.parseBrowserCommand(cmd)
        XCTAssertTrue(r?["key"] == "t")
        XCTAssertTrue(r?["modifiers"] == "cmd")
    }
}

func testParseBrowserCloseTab() {
    let cp = ComputerUsePlanner()
    for cmd in ["关闭标签", "关闭标签页"] {
        let r = cp.parseBrowserCommand(cmd)
        XCTAssertTrue(r?["key"] == "w")
    }
}

func testParseBrowserRefresh() {
    let cp = ComputerUsePlanner()
    for cmd in ["刷新页面", "刷新"] {
        let r = cp.parseBrowserCommand(cmd)
        XCTAssertTrue(r?["key"] == "r")
    }
}

func testParseBrowserBack() {
    let cp = ComputerUsePlanner()
    let r = cp.parseBrowserCommand("后退")
    XCTAssertTrue(r?["key"] == "[")
}

func testParseBrowserForward() {
    let cp = ComputerUsePlanner()
    let r = cp.parseBrowserCommand("前进")
    XCTAssertTrue(r?["key"] == "]")
}

func testParseBrowserAddressBar() {
    let cp = ComputerUsePlanner()
    for cmd in ["打开地址栏", "聚焦地址栏"] {
        let r = cp.parseBrowserCommand(cmd)
        XCTAssertTrue(r?["key"] == "l")
    }
}

func testParseBrowserFind() {
    let cp = ComputerUsePlanner()
    for cmd in ["查找页面", "页面查找"] {
        let r = cp.parseBrowserCommand(cmd)
        XCTAssertTrue(r?["key"] == "f")
    }
}

func testParseBrowserCommandUnknown() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.parseBrowserCommand("下载") == nil)
}

// MARK: - parseTypingText

func testParseTypingTextInput() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.parseTypingText("输入 hello") == "hello")
    XCTAssertTrue(cp.parseTypingText("打字 world") == "world")
    XCTAssertTrue(cp.parseTypingText("写入 test") == "test")
    XCTAssertTrue(cp.parseTypingText("粘贴 content") == "content")
}

func testParseTypingTextEmptyValue() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.parseTypingText("输入 ") == nil)
    XCTAssertTrue(cp.parseTypingText("输入") == nil)
}

func testParseTypingTextUnknown() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.parseTypingText("hello") == nil)
}

// MARK: - matches

func testMatchesExact() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.matches("Safari", "Safari") == true)
}

func testMatchesCaseInsensitive() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.matches("safari", "Safari") == true)
}

func testMatchesContains() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.matches("Saf", "Safari") == true)
    XCTAssertTrue(cp.matches("Safari", "Saf") == true)
}

func testMatchesNoSpaces() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.matches("Google Chrome", "GoogleChrome") == true)
}

func testMatchesEmpty() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.matches("", "Safari") == false)
    XCTAssertTrue(cp.matches("Safari", "") == false)
    XCTAssertTrue(cp.matches("", "") == false)
}

// MARK: - plan() end-to-end

private func emptyObservation() -> ComputerUseObservation {
    ComputerUseObservation()
}

func testPlanEmptyText() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.plan(userText: "", observation: emptyObservation()) == nil)
    XCTAssertTrue(cp.plan(userText: "   ", observation: emptyObservation()) == nil)
}

func testPlanShortcutEnter() {
    let cp = ComputerUsePlanner()
    let plan = cp.plan(userText: "回车", observation: emptyObservation())
    XCTAssertTrue(plan != nil)
    XCTAssertTrue(plan?.intent == .pressShortcut)
    XCTAssertTrue(plan?.action?.kind == .pressShortcut)
    XCTAssertTrue(plan?.action?.payload["key"] == "return")
}

func testPlanShortcutCopy() {
    let cp = ComputerUsePlanner()
    let plan = cp.plan(userText: "复制", observation: emptyObservation())
    XCTAssertTrue(plan != nil)
    XCTAssertTrue(plan?.action?.payload["key"] == "c")
    XCTAssertTrue(plan?.action?.payload["modifiers"] == "cmd")
}

func testPlanMediaCommand() {
    let cp = ComputerUsePlanner()
    let plan = cp.plan(userText: "下一首", observation: emptyObservation())
    XCTAssertTrue(plan != nil)
    XCTAssertTrue(plan?.intent == .pressShortcut)
    XCTAssertTrue(plan?.reason == "本地媒体快捷键")
}

func testPlanBrowserCommand() {
    let cp = ComputerUsePlanner()
    let plan = cp.plan(userText: "新建标签页", observation: emptyObservation())
    XCTAssertTrue(plan != nil)
    XCTAssertTrue(plan?.reason == "本地浏览器快捷键")
}

func testPlanSingleKey() {
    let cp = ComputerUsePlanner()
    let plan = cp.plan(userText: "按esc", observation: emptyObservation())
    XCTAssertTrue(plan != nil)
    XCTAssertTrue(plan?.action?.payload["key"] == "escape")
}

func testPlanTypingText() {
    let cp = ComputerUsePlanner()
    let plan = cp.plan(userText: "输入 hello world", observation: emptyObservation())
    XCTAssertTrue(plan != nil)
    XCTAssertTrue(plan?.intent == .typeText)
    XCTAssertTrue(plan?.action?.kind == .insertText)
    XCTAssertTrue(plan?.action?.payload["text"] == "hello world")
}

func testPlanTypingLongTextRequiresConfirmation() {
    let cp = ComputerUsePlanner()
    let long = String(repeating: "A", count: 200)
    let plan = cp.plan(userText: "输入 \(long)", observation: emptyObservation())
    XCTAssertTrue(plan != nil)
    XCTAssertTrue(plan?.requiresConfirmation == true)
}

func testPlanClickNoTarget() {
    let cp = ComputerUsePlanner()
    let plan = cp.plan(userText: "点击 按钮", observation: emptyObservation())
    XCTAssertTrue(plan != nil)
    XCTAssertTrue(plan?.intent == .clickTarget)
    XCTAssertTrue(plan?.action?.kind == .clickFocused) // no target found, fallback to focused
}

func testPlanUnknownCommand() {
    let cp = ComputerUsePlanner()
    XCTAssertTrue(cp.plan(userText: "今天天气怎么样", observation: emptyObservation()) == nil)
}
