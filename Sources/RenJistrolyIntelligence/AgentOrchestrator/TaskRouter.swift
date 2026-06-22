import Foundation
import RenJistrolyModels

public struct TaskRouter: Sendable {
    private let thresholdForLLM: Double

    public init(thresholdForLLM: Double = 0.65) {
        self.thresholdForLLM = thresholdForLLM
    }

    public func route(_ prompt: String) -> RoutedTask {
        let scored = scoreAllKinds(prompt)
        let sorted = scored.sorted { $0.confidence > $1.confidence }
        let primary = sorted.first ?? TaskRoute(kind: .chat, confidence: 0.5, reason: "默认")

        // Check if we need LLM refinement
        if primary.confidence < thresholdForLLM || primary.kind == .mixed {
            var routes = sorted
            routes.append(TaskRoute(kind: .mixed, confidence: 0.7, reason: "多意图，建议规划"))
            let deduped = deduplicateRoutes(routes)
            return RoutedTask(prompt: prompt, primaryRoute: deduped[0], fallbackRoutes: Array(deduped.dropFirst()))
        }

        return RoutedTask(prompt: prompt, primaryRoute: primary, fallbackRoutes: Array(sorted.dropFirst().prefix(2)))
    }

    // MARK: - Route Continuation (cross-route fallback chain)

    public func continueRoute(from routed: RoutedTask, after failedKind: TaskKind) -> TaskRoute? {
        routed.fallbackRoutes.first { $0.kind != failedKind }
    }

    // MARK: - Enhanced Sub-task Decomposition

    public func decompose(_ prompt: String) -> DecomposedTask {
        let scored = scoreAllKinds(prompt)
        let activeKinds = scored.map(\.kind).filter { $0 != .chat && $0 != .mixed }

        guard activeKinds.count >= 1 else {
            let primary = scored.first ?? TaskRoute(kind: .chat, confidence: 0.6, reason: "默认")
            return DecomposedTask(
                originalPrompt: prompt,
                subTasks: [SubTask(prompt: prompt, route: primary)]
            )
        }

        // Detect parallel markers — tasks that can run simultaneously
        let parallelMarkers = ["同时", "并且", "另外", "还", "也", "同时帮我", "and", "also", "meanwhile"]
        let hasParallelIntent = parallelMarkers.contains { prompt.contains($0) }

        if activeKinds.count >= 2 || hasParallelIntent {
            return decomposeMultiIntent(prompt, kinds: activeKinds, hasParallelIntent: hasParallelIntent)
        }

        // Single-domain but complex — split into logical steps
        return decomposeSingleDomain(prompt, primaryKind: activeKinds.first ?? .chat)
    }

    /// Decompose a multi-intent prompt into sub-tasks with dependency analysis.
    private func decomposeMultiIntent(_ prompt: String, kinds: [TaskKind], hasParallelIntent: Bool) -> DecomposedTask {
        let segments = splitPrompt(prompt, kinds: kinds)
        var subTasks: [SubTask] = []
        var previousID: UUID?

        // Detect sequential markers for dependency chain
        let seqMarkers = ["然后", "接着", "再", "之后", "最后", "then", "next", "after", "finally"]
        let isSequential = seqMarkers.contains { prompt.contains($0) }

        for (index, segment) in segments.enumerated() {
            let kind = index < kinds.count ? kinds[index] : .chat
            let confidence = min(0.85, 0.7 + Double(kinds.count - index) * 0.05)
            let route = TaskRoute(kind: kind, confidence: confidence, reason: "分解自多意图任务")

            // Category hints based on task kind
            let categoryHint = categoryHintFor(kind: kind, segment: segment)

            // Tool hints based on task kind
            let toolHints = toolHintsFor(kind: kind)

            var deps: [UUID] = []
            if isSequential, let prev = previousID {
                deps.append(prev)
            }
            // Non-sequential + parallel = no dependencies
            // (parallel tasks can run simultaneously)

            subTasks.append(SubTask(
                prompt: segment,
                route: route,
                dependsOn: deps,
                categoryHint: categoryHint,
                toolHints: toolHints
            ))
            previousID = subTasks.last?.id
        }

        return DecomposedTask(originalPrompt: prompt, subTasks: subTasks)
    }

    /// Decompose a single-domain but complex prompt into logical steps.
    private func decomposeSingleDomain(_ prompt: String, primaryKind: TaskKind) -> DecomposedTask {
        let stepDelimiters = ["先", "然后", "接着", "再", "之后", "最后",
                              "first", "then", "next", "after", "finally",
                              "1.", "2.", "3.", "步骤", "step"]
        let containsSteps = stepDelimiters.contains { prompt.contains($0) }

        guard containsSteps else {
            let route = TaskRoute(kind: primaryKind, confidence: 0.7, reason: "单域任务")
            return DecomposedTask(
                originalPrompt: prompt,
                subTasks: [SubTask(prompt: prompt, route: route,
                                   categoryHint: categoryHintFor(kind: primaryKind, segment: prompt),
                                   toolHints: toolHintsFor(kind: primaryKind))]
            )
        }

        // Simple step-based decomposition
        let segments = splitBySteps(prompt)
        var subTasks: [SubTask] = []
        var previousID: UUID?

        for (index, seg) in segments.enumerated() {
            let route = TaskRoute(kind: primaryKind, confidence: 0.75, reason: "步骤\(index + 1)")
            var deps: [UUID] = []
            if let prev = previousID { deps.append(prev) }
            subTasks.append(SubTask(
                prompt: seg,
                route: route,
                dependsOn: deps,
                categoryHint: categoryHintFor(kind: primaryKind, segment: seg),
                toolHints: toolHintsFor(kind: primaryKind)
            ))
            previousID = subTasks.last?.id
        }

        return DecomposedTask(originalPrompt: prompt, subTasks: subTasks)
    }

    /// Split prompt into steps by step markers.
    private func splitBySteps(_ prompt: String) -> [String] {
        let stepPatterns = ["先", "然后", "接着", "再", "之后", "最后",
                            "first", "then", "next", "after", "finally",
                            "1.", "2.", "3.", "步骤一", "步骤二", "步骤三"]
        var segments: [String] = []
        var remaining = prompt

        for delim in stepPatterns {
            if let range = remaining.range(of: delim, options: .caseInsensitive) {
                let before = String(remaining[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !before.isEmpty { segments.append(before) }
                remaining = String(remaining[range.lowerBound...])
            }
        }
        if !remaining.isEmpty { segments.append(remaining.trimmingCharacters(in: .whitespacesAndNewlines)) }

        if segments.isEmpty { segments.append(prompt) }
        return segments
    }

    /// Determine category hint based on task kind and segment content.
    private func categoryHintFor(kind: TaskKind, segment: String) -> String? {
        let lower = segment.lowercased()
        switch kind {
        case .code:
            let deepTerms = ["重构", "架构", "设计模式", "并发", "性能优化", "安全",
                             "refactor", "architecture", "design pattern", "concurrency", "optimize", "security"]
            if deepTerms.contains(where: { lower.contains($0) }) {
                return "deep"
            }
            return "quick"
        case .desktop:
            let complexTerms = ["安装", "配置", "设置系统", "自动化", "批量",
                                "install", "configure", "setup", "automate"]
            if complexTerms.contains(where: { lower.contains($0) }) {
                return "deep"
            }
            return "quick"
        case .browser:
            return "visual-engineering"
        case .fileSystem:
            return "quick"
        case .chat, .mixed:
            return nil
        }
    }

    /// Determine tool hints based on task kind.
    private func toolHintsFor(kind: TaskKind) -> [String] {
        switch kind {
        case .code: return ["read_file", "write_file", "swift_build", "swift_test", "git_*"]
        case .desktop: return ["get_app_state", "click", "type_text", "scroll", "open_app"]
        case .browser: return ["safari_search", "get_browser_state", "dom_*", "web_search"]
        case .fileSystem: return ["list_directory", "read_file", "write_file", "move_file"]
        case .chat, .mixed: return []
        }
    }

    // MARK: - Context-aware Joint Routing

    public func routeWithContext(
        _ prompt: String,
        availableTools: [String],
        activeApp: String? = nil,
        screenContext: String? = nil
    ) -> RoutedTask {
        let baseResult = route(prompt)
        let primary = baseResult.primaryRoute

        let adjustedConfidence: Double
        var adjustments: [String] = []

        switch primary.kind {
        case .desktop:
            let hasDesktopTools = availableTools.contains { tool in
                ["click", "type_text", "scroll", "drag", "open_app", "get_app_state", "ui_tree"].contains(tool)
            }
            adjustedConfidence = hasDesktopTools ? primary.confidence : primary.confidence * 0.6
            if !hasDesktopTools { adjustments.append("桌面工具不可用") }
            if let app = activeApp { adjustments.append("当前前台: \(app)") }
        case .browser:
            let hasBrowserTools = availableTools.contains { tool in
                ["safari_search", "get_browser_state", "dom_click", "dom_fill"].contains(tool)
            }
            adjustedConfidence = hasBrowserTools ? primary.confidence : primary.confidence * 0.5
            if let sc = screenContext, !sc.isEmpty { adjustments.append("屏幕上下文可用") }
        case .fileSystem:
            let hasFSTools = availableTools.contains { tool in
                ["list_directory", "read_file", "write_file", "move_file", "create_folder"].contains(tool)
            }
            adjustedConfidence = hasFSTools ? primary.confidence : primary.confidence * 0.5
        case .code:
            let hasCodeTools = availableTools.contains { tool in
                ["git_status", "swift_build", "swift_test", "terminal_run"].contains(tool)
            }
            adjustedConfidence = hasCodeTools ? primary.confidence : primary.confidence * 0.6
        default:
            adjustedConfidence = primary.confidence
        }

        let adjustedReason = adjustments.isEmpty ? primary.reason : "\(primary.reason) (\(adjustments.joined(separator: ", ")))"
        let adjustedPrimary = TaskRoute(kind: primary.kind, confidence: min(adjustedConfidence, 0.95), reason: adjustedReason)

        var fallbacks = baseResult.fallbackRoutes
        if adjustedConfidence < 0.5, let firstFallback = fallbacks.first {
            fallbacks.insert(adjustedPrimary, at: 1)
            return RoutedTask(prompt: prompt, primaryRoute: firstFallback, fallbackRoutes: Array(fallbacks.dropFirst().prefix(3)))
        }

        return RoutedTask(prompt: prompt, primaryRoute: adjustedPrimary, fallbackRoutes: fallbacks)
    }

    /// LLM-based semantic classification for ambiguous queries
    public func classifyWithLLM(_ prompt: String, using classifier: @Sendable (String) async -> TaskKind?) async -> RoutedTask {
        let keywordResult = route(prompt)
        if keywordResult.primaryRoute.confidence >= 0.75 && keywordResult.primaryRoute.kind != .mixed {
            return keywordResult
        }
        guard let kind = await classifier(prompt) else { return keywordResult }
        let llmRoute = TaskRoute(kind: kind, confidence: 0.85, reason: "LLM 语义分类")
        return RoutedTask(
            prompt: prompt,
            primaryRoute: llmRoute,
            fallbackRoutes: keywordResult.fallbackRoutes
        )
    }

    // MARK: - Weighted Heuristic Scoring

    // MARK: - Prompt Splitting

    private func splitPrompt(_ prompt: String, kinds: [TaskKind]) -> [String] {
        let delimiters = ["然后", "接着", "并且", "同时", "再", "之后", "最后", "先", "然后帮我", "and then", "also"]
        var segments: [String] = []
        var remaining = prompt
        for delimiter in delimiters {
            if let range = remaining.range(of: delimiter), segments.count < kinds.count - 1 {
                let before = String(remaining[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let after = String(remaining[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !before.isEmpty {
                    segments.append(before)
                    remaining = after
                }
            }
        }
        if !remaining.isEmpty { segments.append(remaining) }

        while segments.count < kinds.count {
            segments.append(prompt)
        }
        return Array(segments.prefix(kinds.count))
    }

    private func scoreAllKinds(_ prompt: String) -> [TaskRoute] {
        let normalized = prompt.lowercased()
        var routes: [TaskRoute] = []

        let codeScore = scoreCode(normalized)
        if codeScore.confidence > 0 {
            routes.append(codeScore)
        }

        let desktopScore = scoreDesktop(normalized)
        if desktopScore.confidence > 0 {
            routes.append(desktopScore)
        }

        let browserScore = scoreBrowser(normalized)
        if browserScore.confidence > 0 {
            routes.append(browserScore)
        }

        let fsScore = scoreFileSystem(normalized)
        if fsScore.confidence > 0 {
            routes.append(fsScore)
        }

        if routes.count >= 2 {
            let topConfidence = routes.map(\.confidence).max() ?? 0.7
            routes.append(TaskRoute(kind: .mixed, confidence: min(0.95, topConfidence + 0.03), reason: "多域意图"))
        }

        if routes.isEmpty {
            routes.append(TaskRoute(kind: .chat, confidence: 0.6, reason: "常规问答"))
        }

        return routes
    }

    private func deduplicateRoutes(_ routes: [TaskRoute]) -> [TaskRoute] {
        var seen: Set<TaskKind> = []
        return routes.filter { seen.insert($0.kind).inserted }
    }

    // MARK: - Scoring Functions

    private func scoreCode(_ text: String) -> TaskRoute {
        var score: Double = 0
        var reasons: [String] = []

        let highSignal: [(String, Double)] = [
            ("修 bug", 0.9), ("修复", 0.9), ("编译错误", 0.9), ("测试失败", 0.9),
            ("跑测试", 0.85), ("重构", 0.85), ("代码审查", 0.85),
            ("写代码", 0.8), ("添加功能", 0.8), ("实现", 0.75),
            ("build", 0.8), ("test", 0.7), ("编译", 0.8), ("部署", 0.7),
            ("claude code", 0.85), ("claudecode", 0.85),
            ("git status", 0.9), ("git diff", 0.9), ("git log", 0.85),
            ("终端运行", 0.85), ("运行 git", 0.9),
        ]
        for (keyword, weight) in highSignal where text.contains(keyword) {
            score = max(score, weight)
            reasons.append(keyword)
        }

        let codePrefixes = ["git ", "swift ", "npm ", "xcodebuild ", "docker "]
        for prefix in codePrefixes where text.hasPrefix(prefix) {
            score = max(score, 0.85)
            reasons.append("命令: \(prefix)")
        }

        let devKeywords = ["终端", "terminal", "代码", "code", "仓库", "pr", "commit", "diff", "git", "项目",
                           "claude code", "claudecode"]
        let devMatches = devKeywords.filter { text.contains($0) }.count
        if devMatches >= 2 {
            score = max(score, 0.7 + Double(devMatches) * 0.05)
            reasons.append("开发关键词x\(devMatches)")
        }

        let questionWords = ["什么是", "怎么", "为什么", "如何", "what is", "how to", "why"]
        let hasQuestion = questionWords.contains { text.contains($0) }
        if hasQuestion && score < 0.7 {
            score *= 0.5
        }

        guard score > 0 && !reasons.isEmpty else { return TaskRoute(kind: .code, confidence: 0, reason: "") }
        return TaskRoute(kind: .code, confidence: min(score, 0.95), reason: reasons.prefix(2).joined(separator: "、"))
    }

    private func scoreDesktop(_ text: String) -> TaskRoute {
        var score: Double = 0
        var reasons: [String] = []

        let openPatterns = ["打开", "启动", "运行", "open", "launch"]
        let appNames = ["Safari", "Chrome", "Finder", "Terminal", "Xcode", "微信", "WeChat",
                        "系统设置", "System Settings", "访达", "终端", "VSCode", "Visual Studio Code",
                        "备忘录", "日历", "提醒", "邮件", "信息", "音乐", "照片"]
        // CLI tools that look like app names but aren't
        let cliToolNames = ["claude code", "claude", "git", "npm", "docker", "brew", "swift", "python", "node"]
        let lowerText = text.lowercased()
        let hasCLITool = cliToolNames.contains { lowerText.contains($0) }

        let hasOpen = openPatterns.contains { text.contains($0) }
        let matchedApp = appNames.first { text.contains($0) }
        let commandVerbs = ["运行", "执行", "run "]
        let looksLikeCLICommand = hasCLITool && commandVerbs.contains { lowerText.contains($0) }
        if looksLikeCLICommand {
            return TaskRoute(kind: .desktop, confidence: 0, reason: "")
        } else if hasOpen, hasCLITool {
            // "打开 Claude Code" etc → not a desktop task, reduce desktop score
            score = 0.3
            reasons.append("CLI工具非桌面")
        } else if hasOpen, let app = matchedApp {
            score = 0.88
            reasons.append("打开 \(app)")
        } else if let app = matchedApp {
            score = 0.7
            reasons.append("提到 \(app)")
        }

        let uiActions = ["点击", "输入", "切换窗口", "滚动", "拖拽", "click", "type", "scroll", "drag"]
        let uiMatches = uiActions.filter { text.contains($0) }
        if !uiMatches.isEmpty {
            score = max(score, 0.65 + Double(uiMatches.count) * 0.05)
            reasons.append(contentsOf: uiMatches)
        }

        let desktopWords = ["桌面", "窗口", "菜单", "按钮", "设置", "app", "应用", "屏幕"]
        let dtMatches = desktopWords.filter { text.contains($0) }.count
        if dtMatches >= 2 {
            score = max(score, 0.6 + Double(dtMatches) * 0.05)
            reasons.append("桌面操作")
        }

        guard score > 0 && !reasons.isEmpty else { return TaskRoute(kind: .desktop, confidence: 0, reason: "") }
        return TaskRoute(kind: .desktop, confidence: min(score, 0.92), reason: reasons.prefix(2).joined(separator: "、"))
    }

    private func scoreBrowser(_ text: String) -> TaskRoute {
        var score: Double = 0
        var reasons: [String] = []

        if let url = extractURL(text) {
            score = 0.9
            reasons.append("URL: \(url.host ?? "")")
        }

        let searchMarkers = ["搜索网页", "搜索", "搜一下", "查一下", "search for", "search ", "google ", "百度"]
        for marker in searchMarkers where text.contains(marker) {
            let after = String(text.drop(while: { $0 != Character(String(marker.last ?? " ")) }).dropFirst())
            if !after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                score = max(score, 0.85)
                reasons.append("网页搜索")
                break
            }
        }

        let browserWords = ["浏览器", "网页", "网址", "url", "下载", "safari", "chrome", "网站", "登录"]
        let bMatches = browserWords.filter { text.contains($0) }.count
        if bMatches >= 1 {
            score = max(score, 0.6 + Double(bMatches) * 0.08)
            reasons.append("浏览器相关")
        }

        guard score > 0 else { return TaskRoute(kind: .browser, confidence: 0, reason: "") }
        return TaskRoute(kind: .browser, confidence: min(score, 0.93), reason: reasons.prefix(2).joined(separator: "、"))
    }

    private func scoreFileSystem(_ text: String) -> TaskRoute {
        var score: Double = 0
        var reasons: [String] = []

        let fsActions = ["文件", "目录", "文件夹", "移动", "复制", "重命名", "删除", "创建",
                          "list files", "read file", "写入", "保存", "查找文件", "搜索文件",
                          "找文件", "find file", "search file"]
        let fsMatches = fsActions.filter { text.contains($0) }
        if !fsMatches.isEmpty {
            score = 0.55 + Double(fsMatches.count) * 0.07
            reasons.append("文件操作")
        }

        let pathPattern = /(?:\/[\w.-]+)+/
        if text.contains(pathPattern) {
            score = max(score, 0.8)
            reasons.append("包含路径")
        }

        guard score > 0 else { return TaskRoute(kind: .fileSystem, confidence: 0, reason: "") }
        return TaskRoute(kind: .fileSystem, confidence: min(score, 0.9), reason: reasons.prefix(2).joined(separator: "、"))
    }

    private func extractURL(_ text: String) -> URL? {
        let pieces = text.split(separator: " ").map(String.init)
        for piece in pieces {
            if let url = URL(string: piece), url.scheme?.hasPrefix("http") == true {
                return url
            }
        }
        return nil
    }
}
