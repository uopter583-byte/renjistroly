import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge

public struct ListAppDriversTool: MCPTool {
    public let definition = ToolDefinition(
        name: "list_app_drivers",
        description: "列出 RenJistroly 内置的 app drivers 及能力",
        parameters: []
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let registry = AppDriverRegistry()
        let lines = registry.drivers.map { driver in
            let caps = driver.capabilities.map(\.rawValue).sorted().joined(separator: ", ")
            return "\(driver.id): \(driver.displayName) [\(caps)]"
        }
        return ToolCallResult(id: UUID().uuidString, output: lines.joined(separator: "\n"))
    }
}

public struct OpenPathTool: MCPTool {
    public let definition = ToolDefinition(
        name: "open_path",
        description: "使用 Finder 打开或定位本地路径",
        parameters: [
            .init(name: "path", type: .string, description: "本地文件或目录路径"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let path = arguments["path"], !path.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: path", isError: true)
        }
        do {
            try FinderDriver().open(path: path)
            Task { await AgentEventBus.shared.publish(.desktop(.folderOpened(path: path))) }
            return ToolCallResult(id: UUID().uuidString, output: "已在 Finder 中打开: \(path)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "打开路径失败: \(error.localizedDescription)", isError: true)
        }
    }
}

public struct FinderSearchTool: MCPTool {
    public let definition = ToolDefinition(
        name: "finder_search",
        description: "在指定目录中按文件名搜索，使用 Finder driver 的本地目录语义",
        parameters: [
            .init(name: "query", type: .string, description: "文件名关键词"),
            .init(name: "path", type: .string, description: "搜索目录路径"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let query = arguments["query"], !query.isEmpty,
              let path = arguments["path"], !path.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: query/path", isError: true)
        }
        do {
            let matches = try FinderDriver().search(named: query, in: path)
            Task { await AgentEventBus.shared.publish(.code(.fileOperation(action: "search", path: path))) }
            return ToolCallResult(
                id: UUID().uuidString,
                output: matches.isEmpty ? "未找到匹配文件" : matches.joined(separator: "\n")
            )
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "Finder 搜索失败: \(error.localizedDescription)", isError: true)
        }
    }
}

public struct ListDirectoryTool: MCPTool {
    public let definition = ToolDefinition(
        name: "list_directory",
        description: "使用 Finder driver 列出目录内容",
        parameters: [
            .init(name: "path", type: .string, description: "目录路径"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let path = arguments["path"], !path.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: path", isError: true)
        }
        do {
            let items = try FinderDriver().listDirectory(path: path)
            return ToolCallResult(
                id: UUID().uuidString,
                output: items.isEmpty ? "目录为空" : items.joined(separator: "\n")
            )
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "列出目录失败: \(error.localizedDescription)", isError: true)
        }
    }
}

public struct GetFinderStateTool: MCPTool {
    public let definition = ToolDefinition(
        name: "get_finder_state",
        description: "读取 Finder 前台窗口状态，返回当前目录和已选中文件",
        parameters: []
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        do {
            let state = try await FinderDriver().currentWindowState()
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            let output = String(data: data, encoding: .utf8) ?? "{}"
            return ToolCallResult(id: UUID().uuidString, output: output)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "读取 Finder 状态失败: \(error.localizedDescription)", isError: true)
        }
    }
}

public struct SafariSearchTool: MCPTool {
    public let definition = ToolDefinition(
        name: "safari_search",
        description: "使用 Safari driver 执行网页搜索",
        parameters: [
            .init(name: "query", type: .string, description: "搜索关键词"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let query = arguments["query"], !query.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: query", isError: true)
        }
        do {
            try SafariDriver().search(query: query)
            Task { await AgentEventBus.shared.publish(.browser(.searchPerformed(query: query, engine: "Safari"))) }
            return ToolCallResult(id: UUID().uuidString, output: "已在 Safari 中搜索: \(query)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "Safari 搜索失败: \(error.localizedDescription)", isError: true)
        }
    }
}

public struct GetBrowserStateTool: MCPTool {
    public let definition = ToolDefinition(
        name: "get_browser_state",
        description: "读取 Safari 或 Chrome 当前前台标签页状态，返回标题、URL、域名和搜索词",
        parameters: [
            .init(name: "app", type: .string, description: "可选浏览器名称：Safari / Chrome", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        let app = arguments["app"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        do {
            let state: BrowserPageState
            switch app {
            case "chrome", "google chrome":
                state = try await ChromeDriver().currentPageState()
            case "safari", .none, .some(""):
                state = try await SafariDriver().currentPageState()
            default:
                return ToolCallResult(id: UUID().uuidString, output: "不支持的浏览器: \(arguments["app"] ?? "")", isError: true)
            }

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            let output = String(data: data, encoding: .utf8) ?? "{}"
            return ToolCallResult(id: UUID().uuidString, output: output)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "读取浏览器状态失败: \(error.localizedDescription)", isError: true)
        }
    }
}

public struct TerminalRunTool: MCPTool {
    public let definition = ToolDefinition(
        name: "terminal_run",
        description: "使用 Terminal driver 在本地运行允许的命令，并返回 stdout/stderr",
        parameters: [
            .init(name: "command", type: .string, description: "要运行的命令"),
            .init(name: "cwd", type: .string, description: "可选工作目录", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let command = arguments["command"], !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: command", isError: true)
        }

        let driver = TerminalDriver()
        do {
            let shell = ShellExecutor()
            let previous = FileManager.default.currentDirectoryPath
            if let cwd = arguments["cwd"], !cwd.isEmpty {
                FileManager.default.changeCurrentDirectoryPath(cwd)
            }
            defer {
                FileManager.default.changeCurrentDirectoryPath(previous)
            }

            let result = try await driver.run(command: command, shell: shell)
            var output = result.stdout
            if !result.stderr.isEmpty {
                output += output.isEmpty ? "" : "\n"
                output += "[stderr]\n\(result.stderr)"
            }
            if result.exitCode != 0 {
                output += output.isEmpty ? "" : "\n"
                output += "退出码: \(result.exitCode)"
            }
            Task { await AgentEventBus.shared.publish(.code(.commandExecuted(command: command))) }
            return ToolCallResult(
                id: UUID().uuidString,
                output: output.isEmpty ? "命令执行完毕" : output,
                isError: result.exitCode != 0
            )
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "Terminal 运行失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - Xcode Navigation Tools

public struct XcodeNavigateTool: MCPTool {
    public let definition = ToolDefinition(
        name: "xcode_navigate",
        description: "在 Xcode 中打开文件并跳转到指定行",
        parameters: [
            .init(name: "path", type: .string, description: "文件路径"),
            .init(name: "line", type: .string, description: "可选行号", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let path = arguments["path"], !path.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: path", isError: true)
        }
        let line = arguments["line"].flatMap(Int.init)
        do {
            try await XcodeDriver().navigateToFile(path: path, line: line)
            let lineInfo = line.map { ":\($0)" } ?? ""
            Task { await AgentEventBus.shared.publish(.code(.fileOpened(path: path))) }
            return ToolCallResult(id: UUID().uuidString, output: "已在 Xcode 中打开: \(path)\(lineInfo)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "Xcode 导航失败: \(error.localizedDescription)", isError: true)
        }
    }
}

public struct ParseBuildErrorsTool: MCPTool {
    public let definition = ToolDefinition(
        name: "parse_build_errors",
        description: "解析 xcodebuild 输出，提取结构化错误信息（文件路径、行号、列号、消息）",
        parameters: [
            .init(name: "output", type: .string, description: "xcodebuild 的原始输出"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let output = arguments["output"], !output.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: output", isError: true)
        }
        let diagnostics = XcodeDriver.parseBuildDiagnostics(from: output)
        if diagnostics.isEmpty {
            return ToolCallResult(id: UUID().uuidString, output: "未找到结构化错误信息")
        }
        let lines = diagnostics.map { d in
            var parts: [String] = []
            if let path = d.filePath { parts.append(path) }
            if let line = d.line { parts.append(":\(line)") }
            if let col = d.column { parts.append(":\(col)") }
            parts.append(" \(d.severity): \(d.message)")
            return parts.joined()
        }
        return ToolCallResult(id: UUID().uuidString, output: lines.joined(separator: "\n"))
    }
}

// MARK: - Finder File Operation Tools

public struct CreateFolderTool: MCPTool {
    public let definition = ToolDefinition(
        name: "create_folder",
        description: "在指定路径创建新文件夹，自动处理冲突并验证结果",
        parameters: [
            .init(name: "path", type: .string, description: "父目录路径"),
            .init(name: "name", type: .string, description: "文件夹名称"),
            .init(name: "conflict", type: .string, description: "冲突策略: rename(默认)/overwrite/skip", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let path = arguments["path"], !path.isEmpty,
              let name = arguments["name"], !name.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: path/name", isError: true)
        }
        let strategy = parseConflictStrategy(arguments["conflict"])
        let result = FinderDriver().createFolderVerified(path: path, name: name, conflictStrategy: strategy)
        Task { await AgentEventBus.shared.publish(.code(.fileOperation(action: "createFolder", path: "\(path)/\(name)"))) }
        return formatResult(result, verb: "创建")
    }
}

public struct MoveFileTool: MCPTool {
    public let definition = ToolDefinition(
        name: "move_file",
        description: "移动/重命名文件或文件夹，自动处理冲突并验证结果",
        parameters: [
            .init(name: "from", type: .string, description: "源路径"),
            .init(name: "to", type: .string, description: "目标路径"),
            .init(name: "conflict", type: .string, description: "冲突策略: rename(默认)/overwrite/skip", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let from = arguments["from"], !from.isEmpty,
              let to = arguments["to"], !to.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: from/to", isError: true)
        }
        let strategy = parseConflictStrategy(arguments["conflict"])
        let result = FinderDriver().moveItemVerified(from: from, to: to, conflictStrategy: strategy)
        Task { await AgentEventBus.shared.publish(.code(.fileOperation(action: "move", path: "\(from) → \(to)"))) }
        return formatResult(result, verb: "移动")
    }
}

public struct CopyFileTool: MCPTool {
    public let definition = ToolDefinition(
        name: "copy_file",
        description: "复制文件或文件夹，自动处理冲突并验证结果",
        parameters: [
            .init(name: "from", type: .string, description: "源路径"),
            .init(name: "to", type: .string, description: "目标路径"),
            .init(name: "conflict", type: .string, description: "冲突策略: rename(默认)/overwrite/skip", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let from = arguments["from"], !from.isEmpty,
              let to = arguments["to"], !to.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: from/to", isError: true)
        }
        let strategy = parseConflictStrategy(arguments["conflict"])
        let result = FinderDriver().copyItemVerified(from: from, to: to, conflictStrategy: strategy)
        Task { await AgentEventBus.shared.publish(.code(.fileOperation(action: "copy", path: "\(from) → \(to)"))) }
        return formatResult(result, verb: "复制")
    }
}

public struct DeleteFileTool: MCPTool {
    public let definition = ToolDefinition(
        name: "delete_file",
        description: "将文件或文件夹移入废纸篓并验证结果",
        parameters: [
            .init(name: "path", type: .string, description: "要删除的文件路径"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let path = arguments["path"], !path.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: path", isError: true)
        }
        let result = FinderDriver().deleteItemVerified(path: path)
        Task { await AgentEventBus.shared.publish(.code(.fileOperation(action: "delete", path: path))) }
        return formatResult(result, verb: "删除")
    }
}

public struct RenameFileTool: MCPTool {
    public let definition = ToolDefinition(
        name: "rename_file",
        description: "重命名文件或文件夹，自动处理冲突并验证结果",
        parameters: [
            .init(name: "path", type: .string, description: "文件路径"),
            .init(name: "name", type: .string, description: "新名称"),
            .init(name: "conflict", type: .string, description: "冲突策略: rename(默认)/overwrite/skip", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let path = arguments["path"], !path.isEmpty,
              let name = arguments["name"], !name.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: path/name", isError: true)
        }
        let strategy = parseConflictStrategy(arguments["conflict"])
        let result = FinderDriver().renameItemVerified(at: path, to: name, conflictStrategy: strategy)
        Task { await AgentEventBus.shared.publish(.code(.fileOperation(action: "rename", path: "\(path) → \(name)"))) }
        return formatResult(result, verb: "重命名")
    }
}

// MARK: - Batch File Operation Tools

public struct BatchMoveTool: MCPTool {
    public let definition = ToolDefinition(
        name: "batch_move",
        description: "批量移动文件，每项自动验证",
        parameters: [
            .init(name: "operations", type: .string, description: "JSON 数组: [{\"from\":\"...\", \"to\":\"...\"}, ...]"),
            .init(name: "conflict", type: .string, description: "冲突策略: rename(默认)/overwrite/skip", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let jsonStr = arguments["operations"], !jsonStr.isEmpty,
              let data = jsonStr.data(using: .utf8),
              let ops = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数或格式无效: operations (需为 JSON 数组)", isError: true)
        }
        let strategy = parseConflictStrategy(arguments["conflict"])
        let pairs = ops.compactMap { op -> (String, String)? in
            guard let from = op["from"], let to = op["to"] else { return nil }
            return (from, to)
        }
        let results = FinderDriver().batchMoveVerified(pairs, conflictStrategy: strategy)
        Task { await AgentEventBus.shared.publish(.code(.fileOperation(action: "batchMove", path: "\(pairs.count) items"))) }
        return formatBatchResults(results, verb: "批量移动")
    }
}

public struct BatchCopyTool: MCPTool {
    public let definition = ToolDefinition(
        name: "batch_copy",
        description: "批量复制文件，每项自动验证",
        parameters: [
            .init(name: "operations", type: .string, description: "JSON 数组: [{\"from\":\"...\", \"to\":\"...\"}, ...]"),
            .init(name: "conflict", type: .string, description: "冲突策略: rename(默认)/overwrite/skip", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let jsonStr = arguments["operations"], !jsonStr.isEmpty,
              let data = jsonStr.data(using: .utf8),
              let ops = try? JSONDecoder().decode([[String: String]].self, from: data) else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数或格式无效: operations (需为 JSON 数组)", isError: true)
        }
        let strategy = parseConflictStrategy(arguments["conflict"])
        let pairs = ops.compactMap { op -> (String, String)? in
            guard let from = op["from"], let to = op["to"] else { return nil }
            return (from, to)
        }
        let results = FinderDriver().batchCopyVerified(pairs, conflictStrategy: strategy)
        Task { await AgentEventBus.shared.publish(.code(.fileOperation(action: "batchCopy", path: "\(pairs.count) items"))) }
        return formatBatchResults(results, verb: "批量复制")
    }
}

public struct BatchDeleteTool: MCPTool {
    public let definition = ToolDefinition(
        name: "batch_delete",
        description: "批量将文件移入废纸篓，每项自动验证",
        parameters: [
            .init(name: "paths", type: .string, description: "JSON 字符串数组: [\"path1\", \"path2\", ...]"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let jsonStr = arguments["paths"], !jsonStr.isEmpty,
              let data = jsonStr.data(using: .utf8),
              let paths = try? JSONDecoder().decode([String].self, from: data) else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数或格式无效: paths (需为 JSON 数组)", isError: true)
        }
        let results = FinderDriver().batchDeleteVerified(paths)
        Task { await AgentEventBus.shared.publish(.code(.fileOperation(action: "batchDelete", path: "\(paths.count) items"))) }
        return formatBatchResults(results, verb: "批量删除")
    }
}

// MARK: - Helpers

private func parseConflictStrategy(_ raw: String?) -> ConflictStrategy {
    guard let raw else { return .rename }
    return ConflictStrategy(rawValue: raw.lowercased()) ?? .rename
}

private func formatResult(_ result: FileOperationResult, verb: String) -> ToolCallResult {
    var lines: [String] = []
    if result.success {
        let actualPath = result.resolvedDestPath ?? result.destPath ?? result.sourcePath
        lines.append("\(verb)成功: \(actualPath)")
        if result.conflict != nil { lines.append("冲突: 已通过策略处理") }
        lines.append("验证: \(result.verified ? "通过" : "未通过")")
    } else {
        lines.append("\(verb)失败")
        if let conflict = result.conflict { lines.append("冲突: \(conflict.kind.rawValue) at \(conflict.path)") }
        if let error = result.error { lines.append("错误: \(error)") }
    }
    return ToolCallResult(id: UUID().uuidString, output: lines.joined(separator: "\n"), isError: !result.success)
}

private func formatBatchResults(_ results: [FileOperationResult], verb: String) -> ToolCallResult {
    let succeeded = results.filter(\.success).count
    let verified = results.filter(\.verified).count
    let failed = results.filter { !$0.success }.count
    var lines: [String] = ["\(verb): \(succeeded) 成功, \(failed) 失败, \(verified) 已验证"]
    for r in results where !r.success {
        let id = r.resolvedDestPath ?? r.destPath ?? r.sourcePath
        lines.append("  失败: \(id) — \(r.error ?? "未知错误")")
    }
    for r in results where !r.verified && r.success {
        let id = r.resolvedDestPath ?? r.destPath ?? r.sourcePath
        lines.append("  未验证: \(id)")
    }
    return ToolCallResult(id: UUID().uuidString, output: lines.joined(separator: "\n"), isError: failed > 0)
}

public struct FileInfoTool: MCPTool {
    public let definition = ToolDefinition(
        name: "file_info",
        description: "获取文件或文件夹的详细信息",
        parameters: [
            .init(name: "path", type: .string, description: "文件路径"),
        ]
    )
    public var riskLevel: ToolRiskLevel { .low }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let path = arguments["path"], !path.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: path", isError: true)
        }
        do {
            let info = try FinderDriver().getFileInfo(path: path)
            let output = info.map { "\($0.key): \($0.value)" }.sorted().joined(separator: "\n")
            Task { await AgentEventBus.shared.publish(.code(.fileOperation(action: "info", path: path))) }
            return ToolCallResult(id: UUID().uuidString, output: output.isEmpty ? "无信息" : output)
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "获取文件信息失败: \(error.localizedDescription)", isError: true)
        }
    }
}

// MARK: - DOM Write Tools

public struct DOMClickTool: MCPTool {
    public let definition = ToolDefinition(
        name: "dom_click",
        description: "点击浏览器页面中的 DOM 元素",
        parameters: [
            .init(name: "selector", type: .string, description: "CSS 选择器"),
            .init(name: "app", type: .string, description: "浏览器应用名（Safari/Chrome），默认 Safari", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let selector = arguments["selector"], !selector.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: selector", isError: true)
        }
        let app = arguments["app"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        do {
            let ok: Bool
            switch app {
            case "chrome", "google chrome":
                ok = try await ChromeDriver().clickElement(selector: selector)
            case "safari", .none, .some(""):
                ok = try await SafariDriver().clickElement(selector: selector)
            default:
                return ToolCallResult(id: UUID().uuidString, output: "不支持的浏览器: \(app ?? "")", isError: true)
            }
            Task { await AgentEventBus.shared.publish(.browser(.domClicked(selector: selector, success: ok))) }
            return ToolCallResult(id: UUID().uuidString, output: ok ? "已点击元素: \(selector)" : "未找到元素: \(selector)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "DOM 点击失败: \(error.localizedDescription)", isError: true)
        }
    }
}

public struct DOMFillTool: MCPTool {
    public let definition = ToolDefinition(
        name: "dom_fill",
        description: "填充浏览器页面中的表单元素",
        parameters: [
            .init(name: "selector", type: .string, description: "CSS 选择器"),
            .init(name: "value", type: .string, description: "要填充的值"),
            .init(name: "app", type: .string, description: "浏览器应用名（Safari/Chrome），默认 Safari", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .medium }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let selector = arguments["selector"], !selector.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: selector", isError: true)
        }
        guard let value = arguments["value"] else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: value", isError: true)
        }
        let app = arguments["app"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        do {
            let ok: Bool
            switch app {
            case "chrome", "google chrome":
                ok = try await ChromeDriver().fillElement(selector: selector, value: value)
            case "safari", .none, .some(""):
                ok = try await SafariDriver().fillElement(selector: selector, value: value)
            default:
                return ToolCallResult(id: UUID().uuidString, output: "不支持的浏览器: \(app ?? "")", isError: true)
            }
            Task { await AgentEventBus.shared.publish(.browser(.domFilled(selector: selector, success: ok))) }
            return ToolCallResult(id: UUID().uuidString, output: ok ? "已填充: \(selector)" : "无法填充元素: \(selector)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "DOM 填充失败: \(error.localizedDescription)", isError: true)
        }
    }
}

public struct DOMSubmitTool: MCPTool {
    public let definition = ToolDefinition(
        name: "dom_submit",
        description: "提交浏览器页面中的表单",
        parameters: [
            .init(name: "selector", type: .string, description: "表单元素或表单内元素的 CSS 选择器"),
            .init(name: "app", type: .string, description: "浏览器应用名（Safari/Chrome），默认 Safari", required: false),
        ]
    )
    public var riskLevel: ToolRiskLevel { .high }

    public init() {}

    public func execute(arguments: [String: String]) async throws -> ToolCallResult {
        guard let selector = arguments["selector"], !selector.isEmpty else {
            return ToolCallResult(id: UUID().uuidString, output: "缺少参数: selector", isError: true)
        }
        let app = arguments["app"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        do {
            let ok: Bool
            switch app {
            case "chrome", "google chrome":
                ok = try await ChromeDriver().submitForm(selector: selector)
            case "safari", .none, .some(""):
                ok = try await SafariDriver().submitForm(selector: selector)
            default:
                return ToolCallResult(id: UUID().uuidString, output: "不支持的浏览器: \(app ?? "")", isError: true)
            }
            Task { await AgentEventBus.shared.publish(.browser(.domSubmitted(formSelector: selector, success: ok))) }
            return ToolCallResult(id: UUID().uuidString, output: ok ? "已提交表单: \(selector)" : "未找到表单: \(selector)")
        } catch {
            return ToolCallResult(id: UUID().uuidString, output: "DOM 提交失败: \(error.localizedDescription)", isError: true)
        }
    }
}
