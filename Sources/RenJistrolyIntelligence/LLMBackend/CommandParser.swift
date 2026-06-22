import Foundation
import RenJistrolyModels

struct ParsedCommand {
    let toolCalls: [ToolCallRequest]
    let response: String
}

enum CommandParser {
    static func parse(_ text: String, tools: [ToolDefinition]) -> ParsedCommand {
        let toolNames = Set(tools.map(\.name))
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let cmd = parseOpenAndType(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseOpenApp(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseTypeText(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parsePressKey(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseClickElement(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseActivateMenu(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseShellCommand(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseWindowOps(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseScroll(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseGitOps(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseFileOps(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseSystemInfo(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseRunningApps(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseUITree(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseDrag(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parsePolishReplace(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseExplainSelected(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseReadScreen(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseCodeSearch(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseBuild(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseTest(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseGitBlame(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseGitBranch(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseGitCommit(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseFindSymbol(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseProcessKill(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseGitAdvanced(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseChangedFiles(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseQuickOpen(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseLSP(trimmed, toolNames: toolNames) { return cmd }
        if let cmd = parseProjectTools(trimmed, toolNames: toolNames) { return cmd }

        return ParsedCommand(toolCalls: [], response: fallbackResponse(trimmed))
    }

    // MARK: - Helpers

    private static func firstMatch(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            if let match = try? Regex(pattern).firstMatch(in: text) {
                return match.output.count > 1 ? String(match.output[1].substring ?? "") : String(match.output[0].substring ?? "")
            }
        }
        return nil
    }

    private static func firstMatchGroups(in text: String, patterns: [String]) -> [String]? {
        for pattern in patterns {
            if let match = try? Regex(pattern).firstMatch(in: text) {
                return match.output.dropFirst().compactMap { $0.substring.map(String.init) }
            }
        }
        return nil
    }

    // MARK: - Open App

    private static func parseOpenApp(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("open_app") else { return nil }
        guard let appName = firstMatch(in: text, patterns: [
            #"打开\s*[''"』]?(\S+)[''"』]?"#,
            #"启动\s*[''"』]?(\S+)[''"』]?"#,
            #"(?:open|launch|start)\s+(\S+)"#,
            #"运行\s*[''"』]?(\S+)[''"』]?"#,
        ]) else { return nil }

        let cleaned = appName.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        guard !cleaned.isEmpty, cleaned.count < 50 else { return nil }
        let id = UUID().uuidString
        return ParsedCommand(
            toolCalls: [ToolCallRequest(id: id, name: "open_app", arguments: ["app_name": cleaned])],
            response: "正在打开 \(cleaned)..."
        )
    }

    // MARK: - Type Text

    private static func parseTypeText(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("type_text") else { return nil }
        guard let content = firstMatch(in: text, patterns: [
            #"(?:输入|打字|写入|键入)[:：]?\s*(.+)"#,
            #"type\s+(.+)"#,
        ]) else { return nil }

        let cleaned = content.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, cleaned.count < 1000 else { return nil }
        let id = UUID().uuidString
        return ParsedCommand(
            toolCalls: [ToolCallRequest(id: id, name: "type_text", arguments: ["text": cleaned])],
            response: "正在输入: \(cleaned.prefix(50))..."
        )
    }

    // MARK: - Open + Type + Enter

    private static func parseOpenAndType(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("open_app") && toolNames.contains("type_text") else { return nil }

        // "在终端输入 ls 并回车" / "在 Terminal 中执行 ls -la" / "打开终端输入 ls"
        let patterns: [(String, Bool)] = [
            (#"在\s*(\S+)\s*(?:中|里|上)?\s*(?:输入|打字|键入|执行|运行)[:：]?\s*(.+?)(?:并|然后|再)?\s*(回车|按回车|按确认|确认)?\s*$"#, true),
            (#"打开\s*(\S+)\s*(?:输入|打字|键入|执行|运行)[:：]?\s*(.+?)(?:并|然后|再)?\s*(回车|按回车|按确认|确认)?\s*$"#, true),
            (#"打开\s*(\S+)\s*(?:后|之后|然后)\s*(?:输入|打字|键入|执行|运行)[:：]?\s*(.+?)(?:并|然后|再)?\s*(回车|按回车|按确认|确认)?\s*$"#, true),
            (#"启动\s*(\S+)\s*(?:输入|打字|键入|执行|运行)[:：]?\s*(.+?)(?:并|然后|再)?\s*(回车|按回车|按确认|确认)?\s*$"#, true),
            (#"(?:open|launch)\s+(\S+)\s+(?:and|then|&)\s+(?:type|enter)\s+(.+)"#, false),
        ]

        for (pattern, hasEnterFlag) in patterns {
            guard let match = try? Regex(pattern).firstMatch(in: text) else { continue }

            let appName = String(match.output[1].substring ?? "").trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            let cmd = String(match.output[2].substring ?? "").trimmingCharacters(in: .whitespaces)
            let pressEnter = hasEnterFlag ? (match.output[3].substring != nil) : false

            guard !appName.isEmpty, !cmd.isEmpty, appName.count < 50, cmd.count < 1000 else { continue }

            var calls: [ToolCallRequest] = [
                ToolCallRequest(id: UUID().uuidString, name: "open_app", arguments: ["app_name": appName]),
                ToolCallRequest(id: UUID().uuidString, name: "type_text", arguments: ["text": cmd]),
            ]
            if pressEnter {
                calls.append(ToolCallRequest(id: UUID().uuidString, name: "press_key", arguments: ["key": "return"]))
            }
            return ParsedCommand(
                toolCalls: calls,
                response: "正在打开 \(appName) 并输入指令\(pressEnter ? "（含回车）" : "")..."
            )
        }
        return nil
    }

    // MARK: - Press Key

    private static func parsePressKey(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("press_key") else { return nil }

        let keyMap: [(String, String)] = [
            ("回车", "return"), ("确认", "return"), ("换行", "return"), ("enter", "return"),
            ("esc", "escape"), ("退出", "escape"), ("取消", "escape"),
            ("tab", "tab"), ("制表", "tab"),
            ("空格", "space"), ("space", "space"),
            ("删除", "delete"), ("delete", "delete"),
            ("上", "up"), ("下", "down"), ("左", "left"), ("右", "right"),
            ("f5", "f5"), ("f11", "f11"),
            ("cmd", "command"), ("command", "command"),
            ("shift", "shift"), ("option", "option"), ("ctrl", "control"),
        ]

        // Combo: cmd+c (check first so "按 cmd+s" is combo, not single-key "command")
        if let match = try? Regex(#"(?:按|按下|press)\s*(cmd|command|ctrl|control|option|shift|alt)\s*[+＋]\s*(\S)"#).firstMatch(in: text) {
            let modifier = String(match.output[1].substring ?? "").lowercased()
            let key = String(match.output[2].substring ?? "").lowercased()
            let modKey = modifier == "cmd" ? "command" : (modifier == "alt" ? "option" : modifier)
            let id = UUID().uuidString
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "press_key", arguments: ["key": "\(modKey)+\(key)"])],
                response: "已按 \(modKey)+\(key)"
            )
        }

        for (chinese, key) in keyMap {
            let match1 = (try? Regex("按\\s*\(chinese)\\s*键?").firstMatch(in: text)) != nil
            let match2 = (try? Regex("按下\\s*\(chinese)\\s*键?").firstMatch(in: text)) != nil
            if match1 || match2 {
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "press_key", arguments: ["key": key])],
                    response: "已按 \(chinese) 键"
                )
            }
        }
        return nil
    }

    // MARK: - Click Element

    private static func parseClickElement(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("click_element") else { return nil }
        guard let title = firstMatch(in: text, patterns: [
            #"(?:点击|按下|单击|click)\s*[''"』]?(\S+)[''"』]?\s*(?:按钮|元素|链接)?"#,
            #"(?:点|按)\s*[''"』]?(.+)[''"』]?\s*(?:按钮|一下)?"#,
        ]) else { return nil }

        let cleaned = title.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        guard !cleaned.isEmpty, cleaned.count < 100 else { return nil }
        let id = UUID().uuidString
        return ParsedCommand(
            toolCalls: [ToolCallRequest(id: id, name: "click_element", arguments: ["title": cleaned])],
            response: "正在点击「\(cleaned)」..."
        )
    }

    // MARK: - Menu

    private static func parseActivateMenu(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("activate_menu") else { return nil }
        guard let path = firstMatch(in: text, patterns: [
            #"(?:执行|运行|激活)?\s*菜单[:：]?\s*(.+)"#,
            #"(?:activate|run|exec)\s+menu[:：]?\s*(.+)"#,
        ]) else { return nil }

        let cleaned = path.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, cleaned.count < 200 else { return nil }
        let id = UUID().uuidString
        return ParsedCommand(
            toolCalls: [ToolCallRequest(id: id, name: "activate_menu", arguments: ["path": cleaned])],
            response: "正在执行菜单: \(cleaned)"
        )
    }

    // MARK: - Shell Command


    // MARK: - Window Operations


    // MARK: - Scroll

    private static func parseScroll(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("scroll") else { return nil }

        for (pattern, direction) in [
            (#"(?:向下|往下)\s*(?:滚动|翻|滑)\s*(\d+)?\s*(?:页|屏|行)?"#, 1),
            (#"(?:向上|往上)\s*(?:滚动|翻|滑)\s*(\d+)?\s*(?:页|屏|行)?"#, -1),
        ] {
            if let match = try? Regex(pattern).firstMatch(in: text) {
                let raw = match.output.count > 1 ? (match.output[1].substring ?? "3") : "3"
                let count = Int(raw) ?? 3
                let deltaY = direction * count
                let id = UUID().uuidString
                let dirStr = direction > 0 ? "下" : "上"
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "scroll", arguments: ["delta_y": "\(deltaY)"])],
                    response: "正在向\(dirStr)滚动 \(count) 页..."
                )
            }
        }
        return nil
    }

    // MARK: - Git


    // MARK: - File Operations


    // MARK: - System Info


    // MARK: - Running Apps


    // MARK: - UI Tree


    // MARK: - Drag

    private static func parseDrag(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("drag") else { return nil }
        if let match = try? Regex(#"(?:拖拽|拖动|drag)\s*(?:从)?\s*\((\d+),\s*(\d+)\)\s*(?:到|→|->|至)\s*\((\d+),\s*(\d+)\)"#).firstMatch(in: text),
           let fx = Int(match.output[1].substring ?? ""),
           let fy = Int(match.output[2].substring ?? ""),
           let tx = Int(match.output[3].substring ?? ""),
           let ty = Int(match.output[4].substring ?? "") {
            let id = UUID().uuidString
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "drag", arguments: [
                    "from_x": "\(fx)", "from_y": "\(fy)",
                    "to_x": "\(tx)", "to_y": "\(ty)",
                ])],
                response: "正在拖拽 (\(fx),\(fy)) → (\(tx),\(ty))"
            )
        }
        return nil
    }

    // MARK: - Polish Replace

    private static func parsePolishReplace(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("polish_replace") else { return nil }
        let patterns = [
            #"润色(?:\s*(?:这段|选中的?|一下|当前))?\s*(?:文字|句子|段落)?"#,
            #"优化(?:\s*(?:这段|选中的?|一下|当前))?\s*(?:文字|句子|段落)?"#,
            #"改写(?:\s*(?:这段|选中的?|一下))?\s*(?:文字|句子)?"#,
            #"(?:polish|rewrite|refine)\s*(?:this|selected|text)?"#,
        ]
        for p in patterns {
            if (try? Regex(p).firstMatch(in: text)) != nil {
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "polish_replace", arguments: [:])],
                    response: "正在润色选中的文字..."
                )
            }
        }
        return nil
    }

    // MARK: - Explain Selected

    private static func parseExplainSelected(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("explain_selected") else { return nil }
        let patterns = [
            #"解释(?:\s*(?:这段|选中的?|一下|当前))?\s*(?:文字|代码|句子|内容)?"#,
            #"分析(?:\s*(?:这段|选中的?|一下))?\s*(?:代码|文字)?"#,
            #"翻译(?:\s*(?:这段|选中的?|一下))?\s*(?:文字|句子)?"#,
            #"这是?什么(?:\s*(?:意思|代码|文字))?"#,
            #"(?:explain|analyze|what does this|what's this)\s*(?:this|selected|code|text)?"#,
        ]
        for p in patterns {
            if (try? Regex(p).firstMatch(in: text)) != nil {
                let id = UUID().uuidString
                var args: [String: String] = [:]
                if (try? Regex(#"(?:代码|code)"#).firstMatch(in: text)) != nil { args["focus"] = "code" }
                else if (try? Regex(#"(?:翻译|translate)"#).firstMatch(in: text)) != nil { args["focus"] = "translate" }
                else { args["focus"] = "text" }
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: "explain_selected", arguments: args)],
                    response: "正在解释选中的内容..."
                )
            }
        }
        return nil
    }

    // MARK: - Read Screen

    private static func parseReadScreen(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        let toolName: String
        if toolNames.contains("screen_context") {
            toolName = "screen_context"
        } else if toolNames.contains("read_screen") {
            toolName = "read_screen"
        } else if toolNames.contains("ocr_screen") {
            toolName = "ocr_screen"
        } else {
            return nil
        }
        let patterns = [
            #"读\s*(?:取|一下)?\s*(?:当前)?\s*(?:屏幕|画面|界面)"#,
            #"(?:当前)?\s*(?:屏幕|画面|界面)\s*(?:有?什么|内容|显示)"#,
            #"查看(?:\s*(?:当前))?\s*(?:屏幕|画面|界面)"#,
            #"(?:read|check|show|what's on)\s*(?:the)?\s*(?:screen|display)"#,
        ]
        for p in patterns {
            if (try? Regex(p).firstMatch(in: text)) != nil {
                let id = UUID().uuidString
                return ParsedCommand(
                    toolCalls: [ToolCallRequest(id: id, name: toolName, arguments: [:])],
                    response: "正在读取屏幕内容..."
                )
            }
        }
        return nil
    }

    // MARK: - Code Search

    private static func parseCodeSearch(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("rg_search") else { return nil }
        guard let pattern = firstMatch(in: text, patterns: [
            #"(?:搜索|查找|搜一下|找一下|rg|grep)\s+(.+)"#,
            #"search\s+(.+)"#,
        ]) else { return nil }

        let cleaned = pattern.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, cleaned.count < 500 else { return nil }
        let id = UUID().uuidString
        return ParsedCommand(
            toolCalls: [ToolCallRequest(id: id, name: "rg_search", arguments: ["pattern": cleaned])],
            response: "正在搜索: \(cleaned)"
        )
    }

    // MARK: - Build

    private static func parseBuild(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        let hasSwiftBuild = toolNames.contains("swift_build")
        let hasXcodeBuild = toolNames.contains("xcodebuild")

        let isBuild = firstMatch(in: text, patterns: [
            #"(?:构建|编译|build)\s*(?:项目|工程)?"#,
            #"swift\s+build"#,
            #"xcodebuild"#,
        ]) != nil
        guard isBuild else { return nil }

        let id = UUID().uuidString
        if text.contains("xcode") || text.contains("Xcode"), hasXcodeBuild {
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "xcodebuild", arguments: ["action": "build"])],
                response: "正在通过 xcodebuild 构建..."
            )
        }
        if hasSwiftBuild {
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "swift_build", arguments: [:])],
                response: "正在 swift build..."
            )
        }
        return nil
    }

    // MARK: - Test

    private static func parseTest(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("swift_test") else { return nil }
        guard firstMatch(in: text, patterns: [
            #"(?:测试|test)\s*(?:项目|工程|运行)?"#,
            #"swift\s+test"#,
            #"运行\s*测试"#,
        ]) != nil else { return nil }

        let id = UUID().uuidString
        return ParsedCommand(
            toolCalls: [ToolCallRequest(id: id, name: "swift_test", arguments: [:])],
            response: "正在运行测试..."
        )
    }

    // MARK: - Git Blame


    // MARK: - Git Branch


    // MARK: - Git Commit


    // MARK: - Find Symbol

    private static func parseFindSymbol(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("find_symbol") else { return nil }
        guard let symbol = firstMatch(in: text, patterns: [
            #"(?:找定义|找实现|查找符号|查找函数|符号)\s+(.+)"#,
            #"find\s+(?:symbol|def|definition)\s+(.+)"#,
            #"(?:where is|go to definition of)\s+(.+)"#,
        ]) else { return nil }

        let cleaned = symbol.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, cleaned.count < 200 else { return nil }
        let id = UUID().uuidString
        return ParsedCommand(
            toolCalls: [ToolCallRequest(id: id, name: "find_symbol", arguments: ["symbol": cleaned])],
            response: "正在查找符号: \(cleaned)"
        )
    }

    // MARK: - Process Kill


    // MARK: - Git Advanced (stash, push/pull, remote, reset, merge/rebase, tag, show, cherry-pick, revert, clean)


    // MARK: - Changed Files


    // MARK: - Quick Open

    private static func parseQuickOpen(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("quick_open") else { return nil }
        guard let name = firstMatch(in: text, patterns: [
            #"(?:快速打开|quick open|快速查找|打开文件)\s+[''"』]?(\S+)[''"』]?"#,
            #"quick_open\s+(\S+)"#,
        ]) else { return nil }

        let id = UUID().uuidString
        return ParsedCommand(
            toolCalls: [ToolCallRequest(id: id, name: "quick_open", arguments: ["name": name])],
            response: "正在搜索文件: \(name)"
        )
    }

    // MARK: - LSP Symbol

    private static func parseLSP(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("lsp_symbol") else { return nil }
        let id = UUID().uuidString

        if let groups = firstMatchGroups(in: text, patterns: [
            #"(?:跳转|跳转到|转到|查看|go to)\s*(?:定义|definition)\s*(?:of|:)?\s*(\S+)"#,
        ]) {
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "lsp_symbol", arguments: [
                    "action": "definition", "file_path": "", "line": "1", "column": "1",
                    "symbol": groups.first ?? "",
                ])],
                response: "正在查找定义..."
            )
        }
        if let groups = firstMatchGroups(in: text, patterns: [
            #"(?:查找|搜索|find)\s*(?:引用|references|调用|usages)\s*(?:of|:)?\s*(\S+)"#,
        ]) {
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "lsp_symbol", arguments: [
                    "action": "references", "file_path": "", "line": "1", "column": "1",
                    "symbol": groups.first ?? "",
                ])],
                response: "正在查找引用..."
            )
        }
        if let groups = firstMatchGroups(in: text, patterns: [
            #"(?:hover|悬停|查看信息)\s*(?:of|:)?\s*(\S+)"#,
        ]) {
            return ParsedCommand(
                toolCalls: [ToolCallRequest(id: id, name: "lsp_symbol", arguments: [
                    "action": "hover", "file_path": "", "line": "1", "column": "1",
                    "symbol": groups.first ?? "",
                ])],
                response: "正在获取符号信息..."
            )
        }
        return nil
    }

    // MARK: - Project Tools (open_in_xcode, reveal_in_finder, list_schemes, build_settings, code_sign_info)

    private static func parseProjectTools(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        if let cmd = parseOpenInXcode(text, toolNames: toolNames) { return cmd }
        if let cmd = parseRevealInFinder(text, toolNames: toolNames) { return cmd }
        if let cmd = parseListSchemes(text, toolNames: toolNames) { return cmd }
        if let cmd = parseBuildSettings(text, toolNames: toolNames) { return cmd }
        if let cmd = parseCodeSignInfo(text, toolNames: toolNames) { return cmd }
        return nil
    }

    private static func parseOpenInXcode(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("open_in_xcode") else { return nil }
        guard let filePath = firstMatch(in: text, patterns: [
            #"(?:在|用|使用)?\s*Xcode\s*(?:中|里)?\s*(?:打开|查看|编辑)\s*[''"』]?(\S+)[''"』]?"#,
            #"(?:open_in_xcode|open in xcode|xcode open)\s+(\S+)"#,
        ]) else { return nil }

        let id = UUID().uuidString
        var args: [String: String] = ["file_path": filePath]
        if let m = try? Regex(#"(?:第|行|line)\s*(\d+)"#).firstMatch(in: text),
           let line = Int(m.output[1].substring ?? "") {
            args["line"] = "\(line)"
        }
        return ParsedCommand(
            toolCalls: [ToolCallRequest(id: id, name: "open_in_xcode", arguments: args)],
            response: "正在 Xcode 中打开: \(filePath)..."
        )
    }

    private static func parseRevealInFinder(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("reveal_in_finder") else { return nil }
        guard let path = firstMatch(in: text, patterns: [
            #"(?:在|用)?\s*(?:Finder|访达)\s*(?:中|里)?\s*(?:打开|定位|显示|查看)\s*[''"』]?(\S+)[''"』]?"#,
            #"reveal_in_finder\s+(\S+)"#,
        ]) else { return nil }

        let id = UUID().uuidString
        return ParsedCommand(
            toolCalls: [ToolCallRequest(id: id, name: "reveal_in_finder", arguments: ["path": path])],
            response: "已在 Finder 中定位: \(path)"
        )
    }

    private static func parseListSchemes(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("list_schemes") else { return nil }
        guard firstMatch(in: text, patterns: [
            #"(?:列出|查看|显示)\s*(?:schemes?|方案|构建方案)"#,
            #"list_schemes"#,
        ]) != nil else { return nil }

        let id = UUID().uuidString
        return ParsedCommand(
            toolCalls: [ToolCallRequest(id: id, name: "list_schemes", arguments: [:])],
            response: "正在获取 schemes..."
        )
    }

    private static func parseBuildSettings(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("build_settings") else { return nil }
        guard firstMatch(in: text, patterns: [
            #"(?:构建|build)\s*(?:设置|settings|配置)"#,
            #"build_settings"#,
        ]) != nil else { return nil }

        let id = UUID().uuidString
        var args: [String: String] = [:]
        if let m = try? Regex(#"(?:scheme|方案)\s*[''"』]?(\S+)[''"』]?"#).firstMatch(in: text) {
            args["scheme"] = String(m.output[1].substring ?? "")
        }
        return ParsedCommand(
            toolCalls: [ToolCallRequest(id: id, name: "build_settings", arguments: args)],
            response: "正在获取构建设置..."
        )
    }

    private static func parseCodeSignInfo(_ text: String, toolNames: Set<String>) -> ParsedCommand? {
        guard toolNames.contains("code_sign_info") else { return nil }
        guard let path = firstMatch(in: text, patterns: [
            #"(?:代码签名|签名|code sign|code_sign)\s*(?:信息|状态|检查)?\s*[''"』]?(\S+)[''"』]?"#,
            #"code_sign_info\s+(\S+)"#,
        ]) else { return nil }

        let id = UUID().uuidString
        return ParsedCommand(
            toolCalls: [ToolCallRequest(id: id, name: "code_sign_info", arguments: ["path": path])],
            response: "正在检查签名信息..."
        )
    }

    // MARK: - Fallback

    private static func fallbackResponse(_ text: String) -> String {
        let lower = text.lowercased()
        let greetings = ["你好", "嗨", "hello", "hi", "hey", "早上好", "下午好", "晚上好"]
        let thanks = ["谢谢", "感谢", "多谢", "thanks", "thank"]
        let goodbye = ["再见", "拜拜", "bye", "goodbye"]

        if greetings.contains(where: { lower.contains($0) }) {
            return """
            你好！我是 RenJistroly，可以直接操控你的 Mac。

            日常操作：
            - "打开 Safari" / "打开终端"
            - "在终端输入 ls 并回车"
            - "点击确定按钮" / "按 cmd+s"
            - "列出窗口" / "滚动到顶部"
            - "在 Finder 打开 ~/Downloads"

            开发工具：
            - "构建项目" — swift build / xcodebuild
            - "运行测试" — swift test
            - "搜索 ViewController" — 代码搜索
            - "谁改的 AppDelegate.swift" — git blame
            - "列出分支" / "切换到 feature 分支" — git 分支
            - "提交: fix crash" — git commit
            - "stash 当前变更" / "git stash pop" — git stash
            - "推送" / "拉取代码" — git push/pull
            - "合并 main" / "rebase dev" — merge/rebase
            - "reset 到 HEAD~1" — git reset
            - "列出标签" / "创建标签 v1.0" — git tag
            - "cherry-pick <hash>" — git cherry-pick
            - "撤销提交 <hash>" — git revert
            - "清理未跟踪文件" — git clean
            - "查看远程仓库" — git remote
            - "git show <hash>" — 查看提交详情
            - "变更了哪些文件" — 变更文件列表
            - "快速打开 AppDelegate" — 快速文件搜索
            - "跳转定义 UserDefaults" — 符号导航
            - "查找引用 setup" — 引用查找
            - "在 Xcode 打开 Sources/App.swift" — Xcode 打开
            - "列出 schemes" / "构建设置" / "签名信息"
            - "杀掉 Simulator" — 进程管理
            """
        }
        if thanks.contains(where: { lower.contains($0) }) {
            return "不客气！有什么需要随时告诉我。"
        }
        if goodbye.contains(where: { lower.contains($0) }) {
            return "再见！"
        }

        return """
        收到。告诉我需要做什么：

        开发："构建项目" / "运行测试" / "搜索 <pattern>" / "谁改的 <file>"
        Git："git status" / "提交: <msg>" / "列出分支" / "stash" / "推送" / "合并 <branch>" / "reset <ref>" / "cherry-pick <hash>" / "标签"
        文件："变更了哪些文件" / "在 Xcode 打开 <file>" / "在 Finder 定位 <path>" / "快速打开 <name>"
        符号："跳转定义 <sym>" / "查找引用 <sym>" / "hover <sym>"
        项目："列出 schemes" / "构建设置" / "签名信息 <app>"
        系统："系统信息" / "查看进程" / "杀掉 <进程>" / "打开 <app>" / "输入 <text>" / "按 <key>"
        """
    }
}
