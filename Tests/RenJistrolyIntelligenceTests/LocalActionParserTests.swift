import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

let parser = LocalActionParser()

// MARK: - Window & Application Control

func testParseCloseWindow() {
    let a = parser.parse("关闭当前窗口")
    XCTAssertTrue(a?.kind == .closeWindow)
    XCTAssertTrue(a?.payload.isEmpty == true)
}

func testParseCloseWindowVariant() {
    let variants = ["关掉当前窗口", "关当前窗口", "关闭窗口", "关掉窗口"]
    for text in variants {
        let a = parser.parse(text)
        XCTAssertTrue(a?.kind == .closeWindow)
    }
}

func testParseMinimizeWindow() {
    let variants = ["最小化当前窗口", "最小化窗口", "收起窗口"]
    for text in variants {
        let a = parser.parse(text)
        XCTAssertTrue(a?.kind == .minimizeWindow)
    }
}

func testParseQuitApplication() {
    let a = parser.parse("退出 Safari")
    XCTAssertTrue(a?.kind == .quitApplication)
    XCTAssertTrue(a?.payload["name"] == "Safari")
}

func testParseQuitApplicationVariant() {
    let a = parser.parse("关掉 微信")
    XCTAssertTrue(a?.kind == .quitApplication)
    XCTAssertTrue(a?.payload["name"] == "微信")
}

func testParseHideApplication() {
    let a = parser.parse("隐藏 Safari")
    XCTAssertTrue(a?.kind == .hideApplication)
    XCTAssertTrue(a?.payload["name"] == "Safari")
}

// MARK: - URL

func testParseURLOpenHTTP() {
    let a = parser.parse("打开https://example.com")
    XCTAssertTrue(a?.kind == .openURL)
    XCTAssertTrue(a?.payload["url"] == "https://example.com")
}

func testParseURLOpenHTTPWithSpace() {
    let a = parser.parse("打开 https://example.com")
    XCTAssertTrue(a?.kind == .openURL)
}

func testParseURLOpenWebsite() {
    let a = parser.parse("打开网址 https://example.com")
    XCTAssertTrue(a?.kind == .openURL)
    XCTAssertTrue(a?.payload["url"] == "https://example.com")
}

func testParseURLContainsDotCom() {
    let a = parser.parse("打开 example.com")
    XCTAssertTrue(a?.kind == .openURL)
    XCTAssertTrue(a?.payload["url"] == "example.com")
}

// MARK: - Folder Path

func testParseFolderDownloads() {
    let a = parser.parse("打开下载")
    XCTAssertTrue(a?.kind == .openFileOrFolder)
    XCTAssertTrue(a?.payload["path"] == "~/Downloads")
}

func testParseFolderDesktop() {
    let a = parser.parse("打开桌面")
    XCTAssertTrue(a?.kind == .openFileOrFolder)
    XCTAssertTrue(a?.payload["path"] == "~/Desktop")
}

func testParseFolderDocuments() {
    let a = parser.parse("打开文稿")
    XCTAssertTrue(a?.kind == .openFileOrFolder)
    XCTAssertTrue(a?.payload["path"] == "~/Documents")
}

func testParseFolderApplications() {
    let a = parser.parse("打开应用程序")
    XCTAssertTrue(a?.kind == .openFileOrFolder)
    XCTAssertTrue(a?.payload["path"] == "/Applications")
}

func testParseFolderProject() {
    let a = parser.parse("打开当前项目")
    XCTAssertTrue(a?.kind == .openFileOrFolder)
    XCTAssertTrue(a?.payload["path"] == "/Users/yoming")
}

func testParseFolderCustom() {
    let a = parser.parse("打开文件夹 /tmp/test")
    XCTAssertTrue(a?.kind == .openFileOrFolder)
    XCTAssertTrue(a?.payload["path"] == "/tmp/test")
}

// MARK: - Terminal Path

func testParseTerminalOpenProject() {
    let a = parser.parse("在终端打开当前项目")
    XCTAssertTrue(a?.kind == .openTerminalAtPath)
    XCTAssertTrue(a?.payload["path"] == "/Users/yoming")
}

func testParseTerminalOpen() {
    let a = parser.parse("在终端打开 ~/Desktop")
    XCTAssertTrue(a?.kind == .openTerminalAtPath)
    XCTAssertTrue(a?.payload["path"] == "~/Desktop")
}

// MARK: - Terminal Command

func testParseTerminalCommand() {
    let a = parser.parse("在终端运行 swift build")
    XCTAssertTrue(a?.kind == .openTerminalCommand)
    XCTAssertTrue(a?.payload["command"] == "swift build")
}

func testParseTerminalCommandVariant() {
    let a = parser.parse("终端运行 ls -la")
    XCTAssertTrue(a?.kind == .openTerminalCommand)
    XCTAssertTrue(a?.payload["command"] == "ls -la")
}

// MARK: - Open Application

func testParseOpenAppSafari() {
    let a = parser.parse("打开 Safari")
    XCTAssertTrue(a?.kind == .openApplication)
    XCTAssertTrue(a?.payload["name"] == "Safari")
}

func testParseOpenAppTerminal() {
    let a = parser.parse("开终端")
    XCTAssertTrue(a?.kind == .openApplication)
    XCTAssertTrue(a?.payload["name"] == "终端")
}

func testParseOpenAppWeChat() {
    let a = parser.parse("打开微信")
    XCTAssertTrue(a?.kind == .openApplication)
    XCTAssertTrue(a?.payload["name"] == "微信")
}

func testParseOpenAppSettings() {
    let a = parser.parse("打开设置")
    XCTAssertTrue(a?.kind == .openApplication)
    XCTAssertTrue(a?.payload["name"] == "设置")
}

func testParseOpenAppWithPrefix() {
    let a = parser.parse("你帮我打开 Safari")
    XCTAssertTrue(a?.kind == .openApplication)
    XCTAssertTrue(a?.payload["name"] == "Safari")
}

func testParseSwitchToApp() {
    let a = parser.parse("切换到 Safari")
    XCTAssertTrue(a?.kind == .openApplication)
    XCTAssertTrue(a?.payload["name"] == "Safari")
}

// MARK: - App name cleaning

func testParseOpenAppCleanSuffix() {
    let a = parser.parse("关闭 Safari 应用")
    XCTAssertTrue(a?.kind == .quitApplication)
    XCTAssertTrue(a?.payload["name"] == "Safari")
}

// MARK: - Nil cases

func testParseEmpty() {
    let a = parser.parse("")
    XCTAssertTrue(a == nil)
}

func testParseWhitespace() {
    let a = parser.parse("   ")
    XCTAssertTrue(a == nil)
}

func testParseUnknown() {
    let a = parser.parse("今天天气怎么样")
    XCTAssertTrue(a == nil)
}

// MARK: - Risk levels

func testParseRiskLevelReadOnly() {
    let a = parser.parse("打开 Safari")
    XCTAssertTrue(a?.riskLevel == .readOnly)
}

func testParseRiskLevelReversible() {
    let a = parser.parse("关闭当前窗口")
    XCTAssertTrue(a?.riskLevel == .reversibleInput)
}

func testParseRiskLevelPersistent() {
    let a = parser.parse("在终端运行 rm -rf /")
    XCTAssertTrue(a?.riskLevel == .persistentOrExternal)
}

// MARK: - Human preview

func testParseHumanPreviewNotEmpty() {
    let tests: [String] = [
        "打开 Safari", "关闭当前窗口", "在终端运行 ls",
        "打开下载", "退出 微信", "在终端打开当前项目"
    ]
    for text in tests {
        let a = parser.parse(text)
        XCTAssertTrue(a != nil)
        XCTAssertTrue(!a!.humanPreview.isEmpty)
    }
}
