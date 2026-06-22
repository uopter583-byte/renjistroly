import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - extractJSONObject

func testExtractJSONObject() {
    let p = ModelActionPlanner()
    let text = """
    一些前缀文字
    {"key": "value", "number": 42}
    一些后缀文字
    """
    let json = p.extractJSONObject(from: text)
    XCTAssertTrue(json == "{\"key\": \"value\", \"number\": 42}")
}

func testExtractJSONObjectNoBraces() {
    let p = ModelActionPlanner()
    XCTAssertTrue(p.extractJSONObject(from: "plain text") == nil)
}

func testExtractJSONObjectNested() {
    let p = ModelActionPlanner()
    let text = """
    {"outer": {"inner": "value"}, "array": [1, 2, 3]}
    """
    let json = p.extractJSONObject(from: text)
    XCTAssertTrue(json?.contains("\"outer\"") == true)
}

// MARK: - parse valid JSON

func testParseValidPlan() {
    let p = ModelActionPlanner()
    let json = """
    {
      "intent": "activateApp",
      "reason": "用户要求打开 Safari",
      "requiresConfirmation": false,
      "steps": [
        {
          "kind": "openApplication",
          "payload": {"name": "Safari"},
          "humanPreview": "打开 Safari",
          "expectedState": "Safari 成为前台应用"
        }
      ]
    }
    """
    let plan = p.parse(json, userText: "打开 Safari")
    XCTAssertTrue(plan != nil)
    XCTAssertTrue(plan?.intent == .activateApp)
    XCTAssertTrue(plan?.requiresConfirmation == false)
    XCTAssertTrue(plan?.steps.count == 1)
    XCTAssertTrue(plan?.steps[0].action.kind == .openApplication)
    XCTAssertTrue(plan?.steps[0].action.payload["name"] == "Safari")
}

func testParseMultiStepPlan() {
    let p = ModelActionPlanner()
    let json = """
    {
      "intent": "composeMessage",
      "reason": "微信发消息",
      "requiresConfirmation": true,
      "steps": [
        {
          "kind": "openApplication",
          "payload": {"name": "微信"},
          "humanPreview": "打开微信",
          "expectedState": "微信前台"
        },
        {
          "kind": "focusWeChatMessageInput",
          "payload": {},
          "humanPreview": "聚焦输入框",
          "expectedState": "输入框聚焦"
        },
        {
          "kind": "insertText",
          "payload": {"text": "你好"},
          "humanPreview": "输入消息",
          "expectedState": "消息已输入"
        }
      ]
    }
    """
    let plan = p.parse(json, userText: "给微信发你好")
    XCTAssertTrue(plan != nil)
    XCTAssertTrue(plan?.intent == .composeMessage)
    XCTAssertTrue(plan?.requiresConfirmation == true)
    XCTAssertTrue(plan?.steps.count == 3)
    XCTAssertTrue(plan?.steps[0].action.kind == .openApplication)
    XCTAssertTrue(plan?.steps[1].action.kind == .focusWeChatMessageInput)
    XCTAssertTrue(plan?.steps[2].action.kind == .insertText)
}

func testParseScrollAction() {
    let p = ModelActionPlanner()
    let json = """
    {
      "intent": "unknown",
      "reason": "滚动页面",
      "requiresConfirmation": false,
      "steps": [
        {
          "kind": "scroll",
          "payload": {"direction": "down", "amount": "5"},
          "humanPreview": "向下滚动",
          "expectedState": "页面滚动"
        }
      ]
    }
    """
    let plan = p.parse(json, userText: "向下滚动")
    XCTAssertTrue(plan != nil)
    XCTAssertTrue(plan?.steps[0].action.kind == .scroll)
    XCTAssertTrue(plan?.steps[0].action.payload["direction"] == "down")
    XCTAssertTrue(plan?.steps[0].action.payload["amount"] == "5")
}

// MARK: - parse invalid JSON

func testParseInvalidJSON() {
    let p = ModelActionPlanner()
    XCTAssertTrue(p.parse("not json", userText: "test") == nil)
    XCTAssertTrue(p.parse("", userText: "test") == nil)
}

func testParseMissingSteps() {
    let p = ModelActionPlanner()
    let json = """
    {
      "intent": "activateApp",
      "reason": "no steps",
      "requiresConfirmation": false,
      "steps": []
    }
    """
    XCTAssertTrue(p.parse(json, userText: "test") == nil)
}

func testParseUnknownActionKind() {
    let p = ModelActionPlanner()
    let json = """
    {
      "intent": "unknown",
      "reason": "bad kind",
      "requiresConfirmation": false,
      "steps": [
        {
          "kind": "madeUpAction",
          "payload": {},
          "humanPreview": "bad",
          "expectedState": "nope"
        }
      ]
    }
    """
    XCTAssertTrue(p.parse(json, userText: "test") == nil)
}

// MARK: - prompt generation

func testPromptContainsUserText() {
    let p = ModelActionPlanner()
    let obs = ComputerUseObservation()
    let prompt = p.prompt(userText: "打开 Safari", observation: obs)
    XCTAssertTrue(prompt.contains("打开 Safari"))
    XCTAssertTrue(prompt.contains("macOS 本地辅助功能动作解析器"))
}

func testPromptContainsObservation() {
    let p = ModelActionPlanner()
    var obs = ComputerUseObservation(
        frontmostApp: AppContext(appName: "Finder", bundleIdentifier: "com.apple.finder", windowTitle: "Downloads")
    )
    obs.runningApps = [RunningAppContext(appName: "Safari", bundleIdentifier: "com.apple.Safari")]
    let prompt = p.prompt(userText: "test", observation: obs)
    XCTAssertTrue(prompt.contains("Finder"))
    XCTAssertTrue(prompt.contains("Safari"))
}
