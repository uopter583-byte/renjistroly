import Foundation
import XCTest
import RenJistrolyModels
@testable import RenJistrolyIntelligence

// MARK: - Tool definition helpers

private func tool(_ name: String) -> ToolDefinition {
    ToolDefinition(name: name, description: "", parameters: [])
}

private func tools(_ names: String...) -> [ToolDefinition] {
    names.map { tool($0) }
}

// MARK: - Open App

final class CommandParserTests: XCTestCase {
    func testParseOpenAppChinese() {
        let r = CommandParser.parse("打开 Safari", tools: tools("open_app"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "open_app")
        XCTAssertTrue(r.toolCalls[0].arguments["app_name"] == "Safari")
    }

    func testParseOpenAppWithoutTool() {
        let r = CommandParser.parse("打开 Safari", tools: tools("type_text"))
        XCTAssertTrue(r.toolCalls.isEmpty)

    }
    func testParseOpenAppLaunch() {
        let r = CommandParser.parse("启动 终端", tools: tools("open_app"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["app_name"] == "终端")

    }
    func testParseOpenAppEnglish() {
        let r = CommandParser.parse("open Safari", tools: tools("open_app"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["app_name"] == "Safari")

    // MARK: - Type Text

    }
    func testParseTypeText() {
        let r = CommandParser.parse("输入 hello world", tools: tools("type_text"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "type_text")
        XCTAssertTrue(r.toolCalls[0].arguments["text"] == "hello world")

    }
    func testParseTypeTextEnglish() {
        let r = CommandParser.parse("type hello world", tools: tools("type_text"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["text"] == "hello world")

    // MARK: - Open and Type

    }
    func testParseOpenAndType() {
        let r = CommandParser.parse("在终端输入 ls 并回车", tools: tools("open_app", "type_text", "press_key"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "open_app")
        XCTAssertTrue(r.toolCalls[0].arguments["app_name"] == "终端")
        guard r.toolCalls.count >= 2 else { XCTFail("Expected at least 2 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[1].name == "type_text")
        XCTAssertTrue(r.toolCalls[1].arguments["text"] == "ls")
        guard r.toolCalls.count >= 3 else { XCTFail("Expected at least 3 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[2].name == "press_key")
        XCTAssertTrue(r.toolCalls[2].arguments["key"] == "return")

    }
    func testParseOpenAndTypeWithoutEnter() {
        let r = CommandParser.parse("在终端输入 ls", tools: tools("open_app", "type_text"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "open_app")
        guard r.toolCalls.count >= 2 else { XCTFail("Expected at least 2 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[1].name == "type_text")

    // MARK: - Press Key

    }
    func testParsePressKeyEnter() {
        let r = CommandParser.parse("按回车", tools: tools("press_key"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "press_key")
        XCTAssertTrue(r.toolCalls[0].arguments["key"] == "return")

    }
    func testParsePressKeyEscape() {
        let r = CommandParser.parse("按 esc", tools: tools("press_key"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["key"] == "escape")

    }
    func testParsePressKeySpace() {
        let r = CommandParser.parse("按下 空格 键", tools: tools("press_key"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["key"] == "space")

    }
    func testParsePressKeyArrow() {
        let r = CommandParser.parse("按下 上 键", tools: tools("press_key"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["key"] == "up")

    }
    func testParsePressKeyCombo() {
        let r = CommandParser.parse("按 cmd+s", tools: tools("press_key"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "press_key")
        XCTAssertTrue(r.toolCalls[0].arguments["key"] == "command+s")

    }
    func testParsePressKeyComboCtrl() {
        let r = CommandParser.parse("按 ctrl+c", tools: tools("press_key"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["key"] == "ctrl+c")

    // MARK: - Click Element

    }
    func testParseClickElement() {
        let r = CommandParser.parse("点击 确定 按钮", tools: tools("click_element"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "click_element")
        XCTAssertTrue(r.toolCalls[0].arguments["title"] == "确定")

    }
    func testParseClickElementSimple() {
        let r = CommandParser.parse("点 保存", tools: tools("click_element"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["title"] == "保存")

    // MARK: - Menu

    }
    func testParseActivateMenu() {
        let r = CommandParser.parse("菜单: File/New Window", tools: tools("activate_menu"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "activate_menu")
        XCTAssertTrue(r.toolCalls[0].arguments["path"] == "File/New Window")

    // MARK: - Shell Command

    }
    func testParseShellCommand() {
        let r = CommandParser.parse("运行命令: swift build", tools: tools("shell_command"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "shell_command")
        XCTAssertTrue(r.toolCalls[0].arguments["command"] == "swift build")

    }
    func testParseShellCommandEnglish() {
        let r = CommandParser.parse("run swift build", tools: tools("shell_command"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["command"] == "swift build")

    // MARK: - Window Operations

    }
    func testParseListWindows() {
        let r = CommandParser.parse("列出所有窗口", tools: tools("list_windows"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "list_windows")

    }
    func testParseListWindowsQuestion() {
        let r = CommandParser.parse("有哪些窗口", tools: tools("list_windows"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "list_windows")

    }
    func testParseFocusWindow() {
        let r = CommandParser.parse("切换到 Safari 窗口", tools: tools("focus_window"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "focus_window")
        XCTAssertTrue(r.toolCalls[0].arguments["title"] == "Safari")

    // MARK: - Scroll

    }
    func testParseScrollDown() {
        let r = CommandParser.parse("向下滚动 5 页", tools: tools("scroll"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "scroll")
        XCTAssertTrue(r.toolCalls[0].arguments["delta_y"] == "5")

    }
    func testParseScrollUp() {
        let r = CommandParser.parse("向上滚动 2 页", tools: tools("scroll"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["delta_y"] == "-2")

    // MARK: - Git

    }
    func testParseGitStatus() {
        let r = CommandParser.parse("git status", tools: tools("git_status"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "git_status")

    }
    func testParseGitStatusChinese() {
        let r = CommandParser.parse("查看 git 仓库状态", tools: tools("git_status"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "git_status")

    }
    func testParseGitLog() {
        let r = CommandParser.parse("git log", tools: tools("git_log"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "git_log")

    // MARK: - File Operations

    }
    func testParseListFiles() {
        let r = CommandParser.parse("列出文件 /tmp", tools: tools("list_files"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "list_files")
        XCTAssertTrue(r.toolCalls[0].arguments["path"] == "/tmp")

    }
    func testParseListFilesLs() {
        let r = CommandParser.parse("ls", tools: tools("list_files"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "list_files")
        XCTAssertTrue(r.toolCalls[0].arguments.isEmpty)

    }
    func testParseListFilesLsWithPath() {
        let r = CommandParser.parse("ls /tmp", tools: tools("list_files"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["path"] == "/tmp")

    }
    func testParseReadFile() {
        let r = CommandParser.parse("读取 AppDelegate.swift", tools: tools("read_file"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "read_file")
        XCTAssertTrue(r.toolCalls[0].arguments["file_path"] == "AppDelegate.swift")

    }
    func testParseWriteFile() {
        let r = CommandParser.parse("写入 test.txt", tools: tools("write_file"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "write_file")
        XCTAssertTrue(r.toolCalls[0].arguments["file_path"] == "test.txt")

    // MARK: - System Info

    }
    func testParseSystemInfo() {
        let r = CommandParser.parse("系统信息", tools: tools("system_info"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "system_info")

    }
    func testParseSystemInfoCPU() {
        let r = CommandParser.parse("CPU 使用率", tools: tools("system_info"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "system_info")

    // MARK: - Running Apps

    }
    func testParseRunningApps() {
        let r = CommandParser.parse("正在运行的应用", tools: tools("running_apps"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "running_apps")

    // MARK: - UI Tree

    }
    func testParseUITree() {
        let r = CommandParser.parse("获取 UI 树", tools: tools("get_ui_tree"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "get_ui_tree")
        XCTAssertTrue(r.toolCalls[0].arguments["depth"] == "3")

    // MARK: - Drag

    }
    func testParseDrag() {
        let r = CommandParser.parse("拖拽 (100,200) 到 (300,400)", tools: tools("drag"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "drag")
        XCTAssertTrue(r.toolCalls[0].arguments["from_x"] == "100")
        XCTAssertTrue(r.toolCalls[0].arguments["from_y"] == "200")
        XCTAssertTrue(r.toolCalls[0].arguments["to_x"] == "300")
        XCTAssertTrue(r.toolCalls[0].arguments["to_y"] == "400")

    // MARK: - Polish Replace

    }
    func testParsePolishReplace() {
        let r = CommandParser.parse("润色这段文字", tools: tools("polish_replace"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "polish_replace")

    }
    func testParsePolishReplaceOptimize() {
        let r = CommandParser.parse("优化当前句子", tools: tools("polish_replace"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "polish_replace")

    // MARK: - Explain Selected

    }
    func testParseExplainSelected() {
        let r = CommandParser.parse("解释这段代码", tools: tools("explain_selected"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "explain_selected")
        XCTAssertTrue(r.toolCalls[0].arguments["focus"] == "code")

    }
    func testParseExplainSelectedTranslate() {
        let r = CommandParser.parse("翻译这段文字", tools: tools("explain_selected"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["focus"] == "translate")

    }
    func testParseExplainSelectedDefault() {
        let r = CommandParser.parse("这是什么意思", tools: tools("explain_selected"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["focus"] == "text")

    // MARK: - Read Screen

    }
    func testParseReadScreen() {
        let r = CommandParser.parse("读取当前屏幕", tools: tools("read_screen"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "read_screen")

    }
    func testParseReadScreenContext() {
        let r = CommandParser.parse("屏幕显示什么", tools: tools("screen_context"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "screen_context")

    }
    func testParseReadScreenEnglish() {
        let r = CommandParser.parse("read the screen", tools: tools("read_screen"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "read_screen")

    // MARK: - Code Search

    }
    func testParseCodeSearch() {
        let r = CommandParser.parse("搜索 ViewController", tools: tools("rg_search"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "rg_search")
        XCTAssertTrue(r.toolCalls[0].arguments["pattern"] == "ViewController")

    }
    func testParseCodeSearchGrep() {
        let r = CommandParser.parse("grep myFunction", tools: tools("rg_search"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["pattern"] == "myFunction")

    // MARK: - Build

    }
    func testParseBuild() {
        let r = CommandParser.parse("构建项目", tools: tools("swift_build"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "swift_build")

    }
    func testParseBuildXcode() {
        let r = CommandParser.parse("xcodebuild", tools: tools("xcodebuild"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "xcodebuild")

    // MARK: - Test

    }
    func testParseTest() {
        let r = CommandParser.parse("运行测试", tools: tools("swift_test"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "swift_test")

    // MARK: - Git Blame

    }
    func testParseGitBlame() {
        let r = CommandParser.parse("谁改的 AppDelegate.swift", tools: tools("git_blame"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "git_blame")
        XCTAssertTrue(r.toolCalls[0].arguments["file_path"] == "AppDelegate.swift")

    // MARK: - Git Branch

    }
    func testParseGitBranchSwitch() {
        let r = CommandParser.parse("切换到 feature 分支", tools: tools("git_branch"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "git_branch")
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "switch")
        XCTAssertTrue(r.toolCalls[0].arguments["name"] == "feature")

    }
    func testParseGitBranchCreate() {
        let r = CommandParser.parse("创建分支 develop", tools: tools("git_branch"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "create")
        XCTAssertTrue(r.toolCalls[0].arguments["name"] == "develop")

    }
    func testParseGitBranchList() {
        let r = CommandParser.parse("列出分支", tools: tools("git_branch"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "list")

    // MARK: - Git Commit

    }
    func testParseGitCommit() {
        let r = CommandParser.parse("提交: fix crash", tools: tools("git_commit"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "git_commit")
        XCTAssertTrue(r.toolCalls[0].arguments["message"] == "fix crash")

    // MARK: - Find Symbol

    }
    func testParseFindSymbol() {
        let r = CommandParser.parse("找定义 UserDefaults", tools: tools("find_symbol"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "find_symbol")
        XCTAssertTrue(r.toolCalls[0].arguments["symbol"] == "UserDefaults")

    // MARK: - Process Kill

    }
    func testParseProcessKill() {
        let r = CommandParser.parse("杀掉 Simulator", tools: tools("process"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "process")
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "kill")
        XCTAssertTrue(r.toolCalls[0].arguments["name"] == "Simulator")

    }
    func testParseProcessList() {
        let r = CommandParser.parse("查看进程", tools: tools("process"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "list")

    // MARK: - Git Advanced

    }
    func testParseGitStashSave() {
        let r = CommandParser.parse("stash 当前变更", tools: tools("git_stash"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "git_stash")
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "save")

    }
    func testParseGitStashPop() {
        let r = CommandParser.parse("git stash pop", tools: tools("git_stash"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "pop")

    }
    func testParseGitPush() {
        let r = CommandParser.parse("推送", tools: tools("git_push_pull"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "push")

    }
    func testParseGitPull() {
        let r = CommandParser.parse("拉取代码", tools: tools("git_push_pull"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "pull")

    }
    func testParseGitMerge() {
        let r = CommandParser.parse("合并 main", tools: tools("git_merge_rebase"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "git_merge_rebase")
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "merge")
        XCTAssertTrue(r.toolCalls[0].arguments["branch"] == "main")

    }
    func testParseGitRebase() {
        let r = CommandParser.parse("rebase dev", tools: tools("git_merge_rebase"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "rebase")
        XCTAssertTrue(r.toolCalls[0].arguments["branch"] == "dev")

    }
    func testParseGitReset() {
        let r = CommandParser.parse("reset 到 HEAD~1", tools: tools("git_reset"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "git_reset")
        XCTAssertTrue(r.toolCalls[0].arguments["ref"] == "HEAD~1")

    }
    func testParseGitTagCreate() {
        let r = CommandParser.parse("创建标签 v1.0", tools: tools("git_tag"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "create")
        XCTAssertTrue(r.toolCalls[0].arguments["name"] == "v1.0")

    }
    func testParseGitCherryPick() {
        let r = CommandParser.parse("cherry-pick abc123", tools: tools("git_cherry_pick"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "pick")
        XCTAssertTrue(r.toolCalls[0].arguments["commit"] == "abc123")

    }
    func testParseGitRevert() {
        let r = CommandParser.parse("撤销提交 def456", tools: tools("git_revert"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "git_revert")
        XCTAssertTrue(r.toolCalls[0].arguments["commit"] == "def456")

    }
    func testParseGitClean() {
        let r = CommandParser.parse("清理未跟踪文件", tools: tools("git_clean"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "git_clean")

    }
    func testParseGitCleanDryRun() {
        let r = CommandParser.parse("预览清理", tools: tools("git_clean"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["dry_run"] == "true")

    // MARK: - Changed Files

    }
    func testParseChangedFiles() {
        let r = CommandParser.parse("变更了哪些文件", tools: tools("changed_files"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "changed_files")

    // MARK: - Quick Open

    }
    func testParseQuickOpen() {
        let r = CommandParser.parse("快速打开 AppDelegate", tools: tools("quick_open"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "quick_open")
        XCTAssertTrue(r.toolCalls[0].arguments["name"] == "AppDelegate")

    // MARK: - LSP Symbol

    }
    func testParseLSPDefinition() {
        let r = CommandParser.parse("跳转定义 UserDefaults", tools: tools("lsp_symbol"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "definition")
        XCTAssertTrue(r.toolCalls[0].arguments["symbol"] == "UserDefaults")

    }
    func testParseLSPReferences() {
        let r = CommandParser.parse("查找引用 setup", tools: tools("lsp_symbol"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["action"] == "references")

    // MARK: - Project Tools

    }
    func testParseOpenInXcode() {
        let r = CommandParser.parse("在 Xcode 打开 Sources/App.swift", tools: tools("open_in_xcode"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "open_in_xcode")
        XCTAssertTrue(r.toolCalls[0].arguments["file_path"] == "Sources/App.swift")

    }
    func testParseRevealInFinder() {
        let r = CommandParser.parse("在 Finder 定位 /tmp", tools: tools("reveal_in_finder"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "reveal_in_finder")
        XCTAssertTrue(r.toolCalls[0].arguments["path"] == "/tmp")

    }
    func testParseListSchemes() {
        let r = CommandParser.parse("列出 schemes", tools: tools("list_schemes"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "list_schemes")

    }
    func testParseBuildSettings() {
        let r = CommandParser.parse("构建设置", tools: tools("build_settings"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "build_settings")

    }
    func testParseCodeSignInfo() {
        let r = CommandParser.parse("签名信息 MyApp.app", tools: tools("code_sign_info"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "code_sign_info")
        XCTAssertTrue(r.toolCalls[0].arguments["path"] == "MyApp.app")

    // MARK: - Priority order (openAndType before openApp + typeText)

    }
    func testParsePriorityOpenAndTypeOverOpenApp() {
        let r = CommandParser.parse("打开终端输入 ls", tools: tools("open_app", "type_text", "press_key"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].name == "open_app")
        guard r.toolCalls.count >= 2 else { XCTFail("Expected at least 2 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[1].name == "type_text")

    // MARK: - Fallback responses

    }
    func testFallbackGreeting() {
        let r = CommandParser.parse("你好", tools: tools())
        XCTAssertTrue(r.toolCalls.isEmpty)
        XCTAssertTrue(r.response.contains("RenJistroly"))

    }
    func testFallbackThanks() {
        let r = CommandParser.parse("谢谢", tools: tools())
        XCTAssertTrue(r.response.contains("不客气"))

    }
    func testFallbackGoodbye() {
        let r = CommandParser.parse("再见", tools: tools())
        XCTAssertTrue(r.response.contains("再见"))

    }
    func testFallbackGeneric() {
        let r = CommandParser.parse("今天天气怎么样", tools: tools())
        XCTAssertTrue(r.response.contains("收到"))

    // MARK: - Empty input

    }
    func testParseEmptyText() {
        let r = CommandParser.parse("", tools: tools("open_app"))
        XCTAssertTrue(r.toolCalls.isEmpty)

    // MARK: - No matching tools

    }
    func testParseNoMatchingTools() {
        let r = CommandParser.parse("打开 Safari", tools: tools())
        XCTAssertTrue(r.toolCalls.isEmpty)

    // MARK: - Edge cases

    }
    func testParseAppNameWithPunctuation() {
        let r = CommandParser.parse("打开 'Safari'", tools: tools("open_app"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["app_name"] == "Safari")

    }
    func testParseAppNameTooLong() {
        let long = String(repeating: "A", count: 60)
        let r = CommandParser.parse("打开 \(long)", tools: tools("open_app"))
        XCTAssertTrue(r.toolCalls.isEmpty)

    }
    func testParseTypeTextTooLong() {
        let long = String(repeating: "A", count: 1010)
        let r = CommandParser.parse("输入 \(long)", tools: tools("type_text"))
        XCTAssertTrue(r.toolCalls.isEmpty)

    }
    func testParsePressKeyTab() {
        let r = CommandParser.parse("按 tab", tools: tools("press_key"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["key"] == "tab")

    }
    func testParsePressKeyF5() {
        let r = CommandParser.parse("按 f5", tools: tools("press_key"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["key"] == "f5")

    }
    func testParseScrollDefaultAmount() {
        let r = CommandParser.parse("向下滚动", tools: tools("scroll"))
        guard r.toolCalls.count >= 1 else { XCTFail("Expected at least 1 tool call(s), got \(r.toolCalls.count)"); return }
        XCTAssertTrue(r.toolCalls[0].arguments["delta_y"] == "3")

    }
}