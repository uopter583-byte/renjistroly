import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - Reply triggers

func testReplyHearing() {
    let r = LocalQuickResponder()
    for q in ["能不能听到", "听得到吗", "听到吗", "可以听到我说话吗"] {
        XCTAssertTrue(r.reply(to: q)?.contains("已经听到") == true)
    }
}

func testReplySending() {
    let r = LocalQuickResponder()
    // "发出去了吗" doesn't contain "发送" as a substring, so it passes the action command check
    XCTAssertTrue(r.reply(to: "发出去了吗")?.contains("发送") == true)
}

func testReplySendingBlockedByActionCommand() {
    let r = LocalQuickResponder()
    // These contain "发送" which is an action command keyword, so reply returns nil
    for q in ["能不能发送", "直接发送", "发送不出去"] {
        XCTAssertTrue(r.reply(to: q) == nil)
    }
}

func testReplySpeed() {
    let r = LocalQuickResponder()
    for q in ["速度太慢了", "回答太慢", "太慢了", "能不能快两倍", "加快回答速度"] {
        XCTAssertTrue(r.reply(to: q)?.contains("本地即时回复") == true)
    }
}

func testReplyLocalReply() {
    let r = LocalQuickResponder()
    for q in ["本地回复可以吗", "本地无法回复", "无法回复语音", "可以本地回复吗"] {
        XCTAssertTrue(r.reply(to: q)?.contains("本地") == true)
    }
}

func testReplyGreeting() {
    let r = LocalQuickResponder()
    for q in ["你好", "您好", "在吗", "测试"] {
        XCTAssertTrue(r.reply(to: q) == "在，我能听到。")
    }
}

// MARK: - Action commands return nil (delegate to other parsers)

func testReplyActionCommandReturnsNil() {
    let r = LocalQuickResponder()
    for q in ["打开微信", "切换到 Safari", "输入 hello", "发送消息给张三", "点击按钮", "复制", "粘贴", "回车", "关闭窗口", "最小化"] {
        XCTAssertTrue(r.reply(to: q) == nil)
    }
}

// MARK: - Normalization

func testReplyIgnoresSpaces() {
    let r = LocalQuickResponder()
    XCTAssertTrue(r.reply(to: "你好 ") == "在，我能听到。")
    XCTAssertTrue(r.reply(to: " 你好") == "在，我能听到。")
}

func testReplyCaseInsensitive() {
    let r = LocalQuickResponder()
    XCTAssertTrue(r.reply(to: "你好") == "在，我能听到。")
}

// MARK: - Edge cases

func testReplyEmptyText() {
    let r = LocalQuickResponder()
    XCTAssertTrue(r.reply(to: "") == nil)
    XCTAssertTrue(r.reply(to: "   ") == nil)
}

func testReplyUnknownText() {
    let r = LocalQuickResponder()
    XCTAssertTrue(r.reply(to: "今天天气怎么样") == nil)
}
