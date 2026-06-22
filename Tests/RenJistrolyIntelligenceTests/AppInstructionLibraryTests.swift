import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - Known apps (original 6)

func testInstructionsMusic() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Music")?.contains("Search") == true)
    XCTAssertTrue(lib.instructions(for: "音乐")?.contains("搜索") == true)
}

func testInstructionsClock() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Clock")?.contains("计时器") == true)
}

func testInstructionsNumbers() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Numbers")?.contains("单元格") == true)
}

func testInstructionsNotion() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Notion")?.contains("block") == true)
}

func testInstructionsSpotify() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Spotify")?.contains("播放") == true)
}

func testInstructionsIPhone() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "iPhone Mirroring")?.contains("scroll") == true)
    XCTAssertTrue(lib.instructions(for: "iPhone 镜像")?.contains("scroll") == true)
}

// MARK: - Newly added apps

func testInstructionsSafari() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Safari")?.contains("DOM") == true)
}

func testInstructionsFinder() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Finder")?.contains("list_directory") == true)
}

func testInstructionsWeChat() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "WeChat")?.contains("focus_wechat") == true)
    XCTAssertTrue(lib.instructions(for: "微信")?.contains("focus_wechat") == true)
}

func testInstructionsXcode() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Xcode")?.contains("swift_build") == true)
}

func testInstructionsTerminal() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Terminal")?.contains("shell_command") == true)
    XCTAssertTrue(lib.instructions(for: "终端")?.contains("shell_command") == true)
}

func testInstructionsNotes() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Notes")?.contains("备忘录") == true)
}

func testInstructionsMail() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Mail")?.contains("收件人") == true)
}

func testInstructionsPreview() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Preview")?.contains("open_path") == true)
    XCTAssertTrue(lib.instructions(for: "预览")?.contains("open_path") == true)
}

func testInstructionsSettings() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "System Settings")?.contains("手动操作") == true)
    XCTAssertTrue(lib.instructions(for: "系统设置")?.contains("手动操作") == true)
}

func testInstructionsVSCode() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Visual Studio Code")?.contains("shell_command") == true)
}

// MARK: - Case insensitivity

func testInstructionsCaseInsensitive() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "music")?.contains("Search") == true)
    XCTAssertTrue(lib.instructions(for: "SPOTIFY")?.contains("播放") == true)
}

// MARK: - Unknown / nil

func testInstructionsUnknownApp() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: "Blender") == nil)
    XCTAssertTrue(lib.instructions(for: "Final Cut Pro") == nil)
}

func testInstructionsNil() {
    let lib = AppInstructionLibrary()
    XCTAssertTrue(lib.instructions(for: nil) == nil)
}
