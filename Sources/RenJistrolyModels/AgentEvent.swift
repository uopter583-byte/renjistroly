import Foundation

// MARK: - Timeline Entry (unified envelope)

public struct AgentTimelineEntry: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let event: AgentEvent

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: AgentEvent) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
    }

    public var category: String { event.category }
    public var summary: String { event.summary }
    public var icon: String { event.icon }
}

// MARK: - Unified Agent Event

public enum AgentEvent: Sendable, Identifiable {
    public var id: String { "\(category)/\(summary)" }
    case voice(VoiceEvent)
    case desktop(DesktopEvent)
    case browser(BrowserEvent)
    case code(CodeEvent)
    case lifecycle(LifecycleEvent)
    case system(SystemEvent)

    public var category: String {
        switch self {
        case .voice: return "voice"
        case .desktop: return "desktop"
        case .browser: return "browser"
        case .code: return "code"
        case .lifecycle: return "lifecycle"
        case .system: return "system"
        }
    }

    public var summary: String {
        switch self {
        case .voice(let e):
            switch e {
            case .listeningStarted: return "开始监听"
            case .listeningStopped: return "停止监听"
            case .transcriptPartial(let t): return "语音: \(t.prefix(30))"
            case .transcriptFinal(let t): return "转写完成: \(t.prefix(40))"
            case .speechStarted: return "开始语音输入"
            case .speechEnded: return "语音输入结束"
            case .ttsStarted(let t): return "播报: \(t.prefix(30))"
            case .ttsCompleted: return "播报完成"
            case .ttsInterrupted: return "播报中断"
            case .conversationModeToggled(let on): return on ? "连续对话开启" : "连续对话关闭"
            case .gateToggled(let on): return on ? "安全门开启" : "安全门关闭"
            }
        case .desktop(let e):
            switch e {
            case .appActivated(_, let name): return "激活: \(name)"
            case .appDeactivated(_, let name): return "退出: \(name)"
            case .windowFocused(let title, let owner): return "窗口: \(title ?? owner)"
            case .windowClosed(let app): return "关闭窗口: \(app)"
            case .windowMinimized(let app): return "最小化: \(app)"
            case .mouseClicked(let x, let y, let btn): return "点击 [\(x),\(y)] \(btn)"
            case .rightClicked(let x, let y): return "右键 [\(x),\(y)]"
            case .doubleClicked(let x, let y): return "双击 [\(x),\(y)]"
            case .textTyped(let text, _): return "输入: \(text.prefix(20))"
            case .textCopied(let text): return "复制: \(text.prefix(30))"
            case .shortcutPressed(let key, let mod): return "快捷键: \(mod)+\(key)"
            case .scrolled(let dir, let amt): return "滚动 \(dir) x\(Int(amt))"
            case .dragStarted: return "拖拽"
            case .menuActivated(let path): return "菜单: \(path)"
            case .folderOpened(let path): return "打开文件夹: \(path)"
            case .screenCaptured(let chars, let wins): return "屏幕: \(chars)字 \(wins)窗口"
            case .mediaControl(let action): return "媒体: \(action)"
            case .officeAction(let action): return "办公: \(action)"
            }
        case .browser(let e):
            switch e {
            case .pageLoaded(let url, let title): return "页面加载: \(title ?? url)"
            case .pageNavigated(_, let to): return "导航: \(to)"
            case .browserAction(let action, let browser): return "浏览器: \(action) @\(browser)"
            case .searchPerformed(let query, let engine): return "搜索: \(query) @\(engine)"
            case .domQueried(let sel, let count): return "DOM查询: \(sel) (\(count))"
            case .domClicked(let sel, let ok): return "点击: \(sel) \(ok ? "✓" : "✗")"
            case .domFilled(let sel, let ok): return "填充: \(sel) \(ok ? "✓" : "✗")"
            case .domSubmitted(let sel, let ok): return "提交: \(sel) \(ok ? "✓" : "✗")"
            case .consoleOutput(let level, let msg): return "[\(level)] \(msg.prefix(40))"
            case .networkRequest(let method, let url, let code): return "\(method) \(url) \(code.map { "\($0)" } ?? "")"
            case .networkFailure(let url, _): return "网络错误: \(url)"
            case .tabOpened: return "标签页打开"
            case .tabClosed: return "标签页关闭"
            case .tabSwitched(let i): return "切换标签页 #\(i)"
            }
        case .code(let e):
            switch e {
            case .buildStarted(let target): return "构建: \(target ?? "")"
            case .buildCompleted(let code, let errors, let warnings): return "构建完成 (exit \(code), \(errors)E \(warnings)W)"
            case .buildFailed(let stderr): return "构建失败: \(stderr.prefix(80))"
            case .testStarted(let filter): return "测试: \(filter ?? "")"
            case .testCompleted(let passed, let failed, let dur): return "测试: \(passed)✓ \(failed)✗ (\(String(format: "%.1f", dur))s)"
            case .testFailed(let name, _): return "测试失败: \(name)"
            case .lintStarted: return "Lint 开始"
            case .lintCompleted(let issues): return "Lint: \(issues) 问题"
            case .gitOperation(let op, _): return "git \(op)"
            case .fileOpened(let path): return "打开: \(path)"
            case .fileSaved(let path): return "保存: \(path)"
            case .fileModified(let path, let change): return "修改: \(path) (\(change))"
            case .fileOperation(let action, let path): return "文件\(action): \(path)"
            case .claudeCodeStarted(let prompt): return "Claude Code: \(prompt.prefix(60))"
            case .claudeCodeToken: return "token"
            case .claudeCodeToolCall(let name): return "工具: \(name)"
            case .claudeCodeCompleted(let summary): return "CC 完成: \(summary.prefix(60))"
            case .claudeCodeFailed(let err): return "Claude Code 失败: \(err.prefix(40))"
            case .commandExecuted(let cmd): return "执行: \(cmd.prefix(30))"
            case .taskApproved(let summary): return "批准: \(summary.prefix(30))"
            case .taskEvent(let kind, let summary): return "\(kind): \(summary.prefix(30))"
            }
        case .lifecycle(let e):
            switch e {
            case .thinkingStarted(let reason): return "思考: \(reason)"
            case .thinkingCompleted: return "思考完成"
            case .planningStarted(let goal): return "规划: \(goal)"
            case .planningCompleted(let steps): return "规划完成 (\(steps)步)"
            case .actingStarted(let action, _): return "执行: \(action)"
            case .actingCompleted(let action, let ok): return "\(action) \(ok ? "✓" : "✗")"
            case .verifyingStarted(let action): return "验证: \(action)"
            case .verifyingCompleted(let action, let passed): return "验证\(action): \(passed ? "通过" : "未通过")"
            case .recoveringStarted(let action, let strategy): return "恢复: \(action) via \(strategy)"
            case .recoveringCompleted(let action, let ok): return "恢复\(action): \(ok ? "成功" : "失败")"
            case .taskDelegated(let to, _): return "委派: \(to)"
            case .routeSelected(let provider, let conf): return "路由: \(provider) (\(Int(conf*100))%)"
            case .providerFellback(let from, let to, _): return "回退: \(from) → \(to)"
            case .taskResumed: return "任务恢复"
            case .taskRetry(let attempt): return "重试 #\(attempt)"
            case .approvalRequired: return "需要批准"
            case .taskStatusUpdate(let summary): return "状态: \(summary)"
            case .contextObserved(let detail): return "上下文: \(detail)"
            case .modelFirstToken: return "首个 token"
            case .observingStarted(let action): return "观察: \(action)"
            case .turnCompleted(let dur): return "回合完成\(dur.map { " (\(String(format: "%.1f", $0))s)" } ?? "")"
            case .turnFailed(let err): return "回合失败: \(err ?? "")"
            }
        case .system(let e):
            switch e {
            case .permissionChanged(let perm, let granted): return "权限: \(perm) \(granted ? "✓" : "✗")"
            case .systemWokeFromSleep: return "系统唤醒"
            case .systemWillSleep: return "系统休眠"
            case .gateMessageSent: return "Gate 消息已发送"
            case .gateReplyReceived: return "Gate 回复已收到"
            case .gateTimeout(let dur): return "Gate 超时 (\(String(format: "%.0f", dur))s)"
            case .errorOccurred(let domain, let msg, _): return "[\(domain)] \(msg.prefix(40))"
            case .warningIssued(let domain, let msg): return "警告 [\(domain)]: \(msg.prefix(40))"
            case .appNapPrevented: return "App Nap 阻止"
            case .duplicateInstanceDetected: return "检测到重复实例"
            }
        }
    }

    public var icon: String {
        switch self {
        case .voice: return "mic.fill"
        case .desktop: return "rectangle.on.rectangle"
        case .browser: return "safari"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .lifecycle: return "arrow.triangle.branch"
        case .system: return "gearshape"
        }
    }
}

// MARK: - Voice Events

public enum VoiceEvent: Sendable {
    case listeningStarted
    case listeningStopped
    case transcriptPartial(String)
    case transcriptFinal(String)
    case speechStarted
    case speechEnded
    case ttsStarted(String)
    case ttsCompleted
    case ttsInterrupted
    case conversationModeToggled(Bool)
    case gateToggled(Bool)
}

// MARK: - Desktop Events

public enum DesktopEvent: Sendable {
    case appActivated(bundleID: String, name: String)
    case appDeactivated(bundleID: String, name: String)
    case windowFocused(title: String?, owner: String)
    case windowClosed(app: String)
    case windowMinimized(app: String)
    case mouseClicked(x: Double, y: Double, button: String)
    case rightClicked(x: Double, y: Double)
    case doubleClicked(x: Double, y: Double)
    case textTyped(text: String, app: String?)
    case textCopied(text: String)
    case shortcutPressed(key: String, modifiers: String)
    case scrolled(direction: String, amount: Double)
    case dragStarted(fromX: Double, fromY: Double, toX: Double, toY: Double)
    case menuActivated(path: String)
    case folderOpened(path: String)
    case screenCaptured(ocrCharCount: Int, windowCount: Int)
    case mediaControl(action: String)
    case officeAction(action: String)
}

// MARK: - Browser Events

public enum BrowserEvent: Sendable {
    case pageLoaded(url: String, title: String?)
    case pageNavigated(from: String, to: String)
    case browserAction(action: String, browser: String)
    case searchPerformed(query: String, engine: String)
    case domQueried(selector: String, resultCount: Int)
    case domClicked(selector: String, success: Bool)
    case domFilled(selector: String, success: Bool)
    case domSubmitted(formSelector: String, success: Bool)
    case consoleOutput(level: String, message: String)
    case networkRequest(method: String, url: String, statusCode: Int?)
    case networkFailure(url: String, error: String)
    case tabOpened(url: String?)
    case tabClosed
    case tabSwitched(index: Int)
}

// MARK: - Code Events

public enum CodeEvent: Sendable {
    case buildStarted(target: String?)
    case buildCompleted(exitCode: Int32, errorCount: Int, warningCount: Int)
    case buildFailed(stderr: String)
    case testStarted(filter: String?)
    case testCompleted(passed: Int, failed: Int, duration: TimeInterval)
    case testFailed(name: String, message: String)
    case lintStarted
    case lintCompleted(issues: Int)
    case gitOperation(op: String, result: String)
    case fileOpened(path: String)
    case fileSaved(path: String)
    case fileModified(path: String, changeType: String)
    case fileOperation(action: String, path: String)
    case claudeCodeStarted(prompt: String)
    case claudeCodeToken(String)
    case claudeCodeToolCall(toolName: String)
    case claudeCodeCompleted(summary: String)
    case claudeCodeFailed(error: String)
    case commandExecuted(command: String)
    case taskApproved(String)
    case taskEvent(kind: String, summary: String)
}

// MARK: - Lifecycle Events

public enum LifecycleEvent: Sendable {
    case thinkingStarted(reason: String)
    case thinkingCompleted
    case planningStarted(goal: String)
    case planningCompleted(steps: Int)
    case actingStarted(action: String, tool: String)
    case actingCompleted(action: String, success: Bool)
    case verifyingStarted(action: String)
    case verifyingCompleted(action: String, passed: Bool)
    case recoveringStarted(action: String, strategy: String)
    case recoveringCompleted(action: String, success: Bool)
    case taskDelegated(to: String, reason: String)
    case routeSelected(provider: String, confidence: Double)
    case providerFellback(from: String, to: String, reason: String)
    case taskResumed(reason: String)
    case taskRetry(attempt: Int)
    case approvalRequired(prompt: String)
    case taskStatusUpdate(summary: String)
    case contextObserved(detail: String)
    case modelFirstToken
    case observingStarted(action: String)
    case turnCompleted(duration: TimeInterval?)
    case turnFailed(error: String?)
}

// MARK: - System Events

public enum SystemEvent: Sendable {
    case permissionChanged(permission: String, granted: Bool)
    case systemWokeFromSleep
    case systemWillSleep
    case gateMessageSent(text: String)
    case gateReplyReceived(text: String)
    case gateTimeout(duration: TimeInterval)
    case errorOccurred(domain: String, message: String, recoverable: Bool)
    case warningIssued(domain: String, message: String)
    case appNapPrevented
    case duplicateInstanceDetected
}
