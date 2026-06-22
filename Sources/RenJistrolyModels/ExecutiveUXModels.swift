import Foundation

// MARK: - 496. 能力描述层 (CapabilityDescriptionLayer)
// 将 Gate/MCP/provider 等内部概念映射为用户友好的能力描述

public struct CapabilityDescriptionLayer: Sendable, Codable, Equatable {
    public var mappedCapabilities: [String: CapabilityDescription]

    public struct CapabilityDescription: Sendable, Codable, Equatable {
        public var internalName: String
        public var friendlyName: String
        public var friendlyExplanation: String
        public var exampleUsage: String
        public var emoji: String

        public init(internalName: String, friendlyName: String, friendlyExplanation: String, exampleUsage: String = "", emoji: String = "") {
            self.internalName = internalName
            self.friendlyName = friendlyName
            self.friendlyExplanation = friendlyExplanation
            self.exampleUsage = exampleUsage
            self.emoji = emoji
        }
    }

    public init(mappedCapabilities: [String: CapabilityDescription] = Self.defaultMappings) {
        self.mappedCapabilities = mappedCapabilities
    }

    public func describe(_ internalName: String) -> CapabilityDescription? {
        mappedCapabilities[internalName]
    }

    public func friendlySummary() -> String {
        mappedCapabilities.values.map { desc in
            "\(desc.emoji) **\(desc.friendlyName)**：\(desc.friendlyExplanation)"
        }.joined(separator: "\n")
    }

    public static let defaultMappings: [String: CapabilityDescription] = [
        "mcp": CapabilityDescription(
            internalName: "mcp",
            friendlyName: "智能工具集",
            friendlyExplanation: "助手用来操作电脑的各种功能模块，就像你的手和眼睛",
            exampleUsage: "打开应用、点击按钮、输入文字",
            emoji: "🛠️"
        ),
        "gate": CapabilityDescription(
            internalName: "gate",
            friendlyName: "安全防护",
            friendlyExplanation: "防止误操作的智能护栏，确保每一步都安全可控",
            exampleUsage: "高风险操作前提醒、误操作拦截",
            emoji: "🛡️"
        ),
        "provider": CapabilityDescription(
            internalName: "provider",
            friendlyName: "AI 大脑",
            friendlyExplanation: "驱动助手的核心智能引擎，负责思考和决策",
            exampleUsage: "理解你的需求、规划执行步骤",
            emoji: "🧠"
        ),
        "accessibility": CapabilityDescription(
            internalName: "accessibility",
            friendlyName: "屏幕观察",
            friendlyExplanation: "助手察看你屏幕上的内容来理解当前状态",
            exampleUsage: "识别按钮、读取文字、定位窗口",
            emoji: "👁️"
        ),
        "screenCapture": CapabilityDescription(
            internalName: "screenCapture",
            friendlyName: "屏幕截图",
            friendlyExplanation: "截取屏幕画面帮助助手理解你看到的内容",
            exampleUsage: "分析页面布局、确认操作结果",
            emoji: "📸"
        ),
        "appControl": CapabilityDescription(
            internalName: "appControl",
            friendlyName: "应用控制",
            friendlyExplanation: "打开、关闭、切换各类应用程序",
            exampleUsage: "打开浏览器、切换窗口、关闭应用",
            emoji: "🚀"
        ),
        "shell": CapabilityDescription(
            internalName: "shell",
            friendlyName: "命令行执行",
            friendlyExplanation: "在终端中运行命令来完成任务",
            exampleUsage: "编译代码、运行脚本、查看文件",
            emoji: "💻"
        ),
    ]
}

// MARK: - 497. 卡住检测 (StuckDetector)
// 监测操作是否卡住，并向用户发出提示

public struct StuckDetector: Sendable, Codable, Equatable {
    public var thresholdSeconds: TimeInterval
    public var maxRetries: Int
    public var currentStuckDuration: TimeInterval
    public var retryCount: Int
    public var lastActionTime: Date
    public var isStuck: Bool
    public var stuckReason: String?
    public var stuckAutoResolved: Bool

    public init(
        thresholdSeconds: TimeInterval = 15,
        maxRetries: Int = 3,
        currentStuckDuration: TimeInterval = 0,
        retryCount: Int = 0,
        lastActionTime: Date = Date(),
        isStuck: Bool = false,
        stuckReason: String? = nil,
        stuckAutoResolved: Bool = false
    ) {
        self.thresholdSeconds = thresholdSeconds
        self.maxRetries = maxRetries
        self.currentStuckDuration = currentStuckDuration
        self.retryCount = retryCount
        self.lastActionTime = lastActionTime
        self.isStuck = isStuck
        self.stuckReason = stuckReason
        self.stuckAutoResolved = stuckAutoResolved
    }

    public mutating func recordAction() {
        lastActionTime = Date()
        currentStuckDuration = 0
        isStuck = false
        stuckReason = nil
    }

    public mutating func check() {
        let elapsed = Date().timeIntervalSince(lastActionTime)
        currentStuckDuration = elapsed
        if elapsed > thresholdSeconds {
            isStuck = true
            retryCount += 1
            if retryCount > maxRetries {
                stuckReason = "已重试 \(maxRetries) 次仍未完成，可能需要您的帮助"
                stuckAutoResolved = false
            } else {
                stuckReason = "操作似乎没有响应（\(Int(elapsed))秒），正在重试（第\(retryCount)次）"
                stuckAutoResolved = true
            }
        }
    }

    public mutating func reset() {
        currentStuckDuration = 0
        retryCount = 0
        isStuck = false
        stuckReason = nil
        stuckAutoResolved = false
        lastActionTime = Date()
    }

    public var userPrompt: String? {
        guard isStuck else { return nil }
        if stuckAutoResolved {
            return nil // 自动恢复，不需要提示
        }
        return "操作似乎卡住了。\(stuckReason ?? "需要您确认如何处理")"
    }

    public var needsUserIntervention: Bool {
        isStuck && !stuckAutoResolved
    }
}

// MARK: - 498. 屏幕状态确认 (ScreenConfirmationPrompt)
// 操作后确认屏幕状态是否正确

public struct ScreenConfirmationPrompt: Sendable, Codable, Equatable {
    public enum ConfirmationScope: String, Sendable, Codable {
        case always
        case afterDestructiveAction
        case afterNavigation
        case never
    }

    public var scope: ConfirmationScope
    public var lastExpectedState: String
    public var lastActualState: String?
    public var isConfirmed: Bool
    public var pendingPrompt: String?

    public init(
        scope: ConfirmationScope = .afterDestructiveAction,
        lastExpectedState: String = "",
        lastActualState: String? = nil,
        isConfirmed: Bool = true,
        pendingPrompt: String? = nil
    ) {
        self.scope = scope
        self.lastExpectedState = lastExpectedState
        self.lastActualState = lastActualState
        self.isConfirmed = isConfirmed
        self.pendingPrompt = pendingPrompt
    }

    public mutating func setExpectation(_ description: String) {
        lastExpectedState = description
        isConfirmed = false
        pendingPrompt = nil
    }

    public mutating func verify(with actualState: String) -> Bool {
        lastActualState = actualState
        let match = lastExpectedState == actualState || actualState.localizedCaseInsensitiveContains(lastExpectedState)
        isConfirmed = match
        if !match {
            pendingPrompt = "屏幕状态和预期不符。\n预期：\(lastExpectedState)\n实际：\(actualState)\n是否继续？"
        }
        return match
    }

    public mutating func confirm() {
        isConfirmed = true
        pendingPrompt = nil
    }

    public var needsConfirmation: Bool {
        switch scope {
        case .always: return !isConfirmed
        case .afterDestructiveAction: return !isConfirmed
        case .afterNavigation: return !isConfirmed
        case .never: return false
        }
    }
}

// MARK: - 499. 鼠标控制可视化指示 (CursorControlIndicator)
// 当 AI 控制鼠标时显示视觉指示

public struct CursorControlIndicator: Sendable, Codable, Equatable {
    public enum IndicatorStyle: String, Sendable, Codable, CaseIterable {
        case ring
        case crosshair
        case glow
        case label
        case none
    }

    public var isActive: Bool
    public var style: IndicatorStyle
    public var color: String
    public var label: String
    public var lastClickPosition: CGPoint?
    public var lastClickDescription: String?
    public var cursorOwner: CursorOwner

    public enum CursorOwner: String, Sendable, Codable {
        case user
        case assistant
        case system
    }

    public init(
        isActive: Bool = false,
        style: IndicatorStyle = .ring,
        color: String = "#FF4500",
        label: String = "AI 操作中",
        lastClickPosition: CGPoint? = nil,
        lastClickDescription: String? = nil,
        cursorOwner: CursorOwner = .user
    ) {
        self.isActive = isActive
        self.style = style
        self.color = color
        self.label = label
        self.lastClickPosition = lastClickPosition
        self.lastClickDescription = lastClickDescription
        self.cursorOwner = cursorOwner
    }

    public mutating func beginAssistControl() {
        isActive = true
        cursorOwner = .assistant
    }

    public mutating func endAssistControl() {
        isActive = false
        cursorOwner = .user
    }

    public mutating func recordClick(at position: CGPoint, description: String) {
        lastClickPosition = position
        lastClickDescription = description
    }

    public var statusMessage: String {
        switch cursorOwner {
        case .user: "鼠标控制权：您"
        case .assistant: "鼠标控制权：助手（\(label)）"
        case .system: "鼠标控制权：系统"
        }
    }
}

// MARK: - 500. 窗口匹配确认 (WindowMatchConfirm)
// 操作前确认窗口匹配

public struct WindowMatchConfirm: Sendable, Codable, Equatable {
    public struct WindowMatch: Sendable, Codable, Equatable {
        public var expectedTitle: String
        public var expectedApp: String
        public var actualTitle: String?
        public var actualApp: String?
        public var isConfirmed: Bool

        public init(expectedTitle: String, expectedApp: String, actualTitle: String? = nil, actualApp: String? = nil, isConfirmed: Bool = false) {
            self.expectedTitle = expectedTitle
            self.expectedApp = expectedApp
            self.actualTitle = actualTitle
            self.actualApp = actualApp
            self.isConfirmed = isConfirmed
        }

        public var isMatch: Bool {
            (actualTitle?.localizedCaseInsensitiveContains(expectedTitle) ?? false)
                && (actualApp?.localizedCaseInsensitiveContains(expectedApp) ?? false)
        }

        public var matchDescription: String {
            if isMatch {
                return "窗口匹配：\(expectedApp) - \(expectedTitle) ✓"
            }
            return "预期：\(expectedApp) - \(expectedTitle)\n实际：\(actualApp ?? "未知") - \(actualTitle ?? "未知")"
        }
    }

    public var pendingMatch: WindowMatch?
    public var matchHistory: [WindowMatch]
    public var confirmationRequired: Bool

    public init(pendingMatch: WindowMatch? = nil, matchHistory: [WindowMatch] = [], confirmationRequired: Bool = true) {
        self.pendingMatch = pendingMatch
        self.matchHistory = matchHistory
        self.confirmationRequired = confirmationRequired
    }

    public mutating func setExpectation(app: String, title: String) {
        pendingMatch = WindowMatch(expectedTitle: title, expectedApp: app)
    }

    public mutating func verify(actualApp: String, actualTitle: String?) -> Bool {
        guard var match = pendingMatch else { return false }
        match.actualApp = actualApp
        match.actualTitle = actualTitle
        match.isConfirmed = match.isMatch
        pendingMatch = match
        matchHistory.append(match)
        return match.isMatch
    }

    public mutating func confirmMatch() {
        pendingMatch?.isConfirmed = true
    }

    public var needsConfirmation: Bool {
        guard let match = pendingMatch, confirmationRequired else { return false }
        return !match.isConfirmed
    }

    public var prompt: String? {
        guard let match = pendingMatch, needsConfirmation else { return nil }
        return "即将操作「\(match.expectedApp) - \(match.expectedTitle)」窗口，是否确认？"
    }
}

// MARK: - 501. 交互模式切换 (InteractionMode)
// 助理模式 vs 调试模式

public enum InteractionMode: String, Sendable, Codable, CaseIterable {
    case assistant
    case debug

    public var title: String {
        switch self {
        case .assistant: "助理模式"
        case .debug: "调试模式"
        }
    }

    public var description: String {
        switch self {
        case .assistant: "友好助理模式：简化说明、自动确认低风险操作、用自然语言描述"
        case .debug: "调试模式：显示技术细节、逐步骤确认、展示原始工具调用"
        }
    }

    public var showTechnicalDetail: Bool { self == .debug }
    public var autoApproveLowRisk: Bool { self == .assistant }
    public var showToolCalls: Bool { self == .debug }
    public var useFriendlyCapabilityNames: Bool { self == .assistant }
}

public struct InteractionModeState: Sendable, Codable, Equatable {
    public var currentMode: InteractionMode
    public var modeHistory: [ModeChange]

    public struct ModeChange: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var from: InteractionMode
        public var to: InteractionMode
        public var timestamp: Date
        public var reason: String

        public init(id: UUID = UUID(), from: InteractionMode, to: InteractionMode, timestamp: Date = Date(), reason: String = "") {
            self.id = id
            self.from = from
            self.to = to
            self.timestamp = timestamp
            self.reason = reason
        }
    }

    public init(currentMode: InteractionMode = .assistant, modeHistory: [ModeChange] = []) {
        self.currentMode = currentMode
        self.modeHistory = modeHistory
    }

    public mutating func switchTo(_ mode: InteractionMode, reason: String = "") {
        let change = ModeChange(from: currentMode, to: mode, reason: reason)
        modeHistory.append(change)
        currentMode = mode
    }
}

// MARK: - 502. 实时操作描述 (OperationDescription)
// 生成当前操作的可读描述

public struct OperationDescription: Sendable, Codable, Equatable {
    public var operationChain: [OperationStep]
    public var currentStepIndex: Int
    public var currentSummary: String?

    public struct OperationStep: Sendable, Codable, Equatable, Identifiable {
        public var id: UUID
        public var action: String
        public var targetDescription: String
        public var purpose: String
        public var status: StepStatus

        public enum StepStatus: String, Sendable, Codable {
            case pending
            case executing
            case completed
            case failed
        }

        public init(id: UUID = UUID(), action: String, targetDescription: String, purpose: String, status: StepStatus = .pending) {
            self.id = id
            self.action = action
            self.targetDescription = targetDescription
            self.purpose = purpose
            self.status = status
        }

        public var userFriendlyDescription: String {
            let actionMap: [String: String] = [
                "click": "点击", "type": "输入", "scroll": "滚动",
                "open": "打开", "close": "关闭", "copy": "复制",
                "paste": "粘贴", "select": "选择", "drag": "拖拽",
                "press": "按下", "wait": "等待", "navigate": "导航",
                "submit": "提交", "fill": "填写",
            ]
            let friendlyAction = actionMap[action.lowercased()] ?? action
            return "\(friendlyAction)「\(targetDescription)」"
        }
    }

    public init(operationChain: [OperationStep] = [], currentStepIndex: Int = 0, currentSummary: String? = nil) {
        self.operationChain = operationChain
        self.currentStepIndex = currentStepIndex
        self.currentSummary = currentSummary
    }

    public mutating func startOperation(_ step: OperationStep) {
        var s = step
        s.status = .executing
        operationChain.append(s)
        currentStepIndex = operationChain.count - 1
        updateSummary()
    }

    public mutating func completeCurrent() {
        guard operationChain.indices.contains(currentStepIndex) else { return }
        operationChain[currentStepIndex].status = .completed
        updateSummary()
    }

    public mutating func failCurrent() {
        guard operationChain.indices.contains(currentStepIndex) else { return }
        operationChain[currentStepIndex].status = .failed
        updateSummary()
    }

    private mutating func updateSummary() {
        guard operationChain.indices.contains(currentStepIndex) else {
            currentSummary = nil
            return
        }
        let current = operationChain[currentStepIndex]
        let prefix = currentStepIndex > 0 ? "上一步完成，正在" : "正在"
        currentSummary = "\(prefix)\(current.userFriendlyDescription)（\(current.purpose)）"
    }

    public var fullProgressDescription: String {
        guard !operationChain.isEmpty else { return "暂无操作" }
        let completed = operationChain.filter { $0.status == .completed }.count
        let total = operationChain.count
        let current = operationChain.first { $0.status == .executing }
        let currentDesc = current.map { $0.userFriendlyDescription } ?? ""
        return "进度：\(completed)/\(total)  \(currentDesc)"
    }
}

// MARK: - 503. 确认理由说明 (ConfirmationReason)
// 解释为什么需要用户确认

public struct ConfirmationReason: Sendable, Codable, Equatable {
    public enum ReasonCategory: String, Sendable, Codable, CaseIterable {
        case destructiveAction
        case dataLoss
        case financial
        case sensitiveData
        case externalCommunication
        case irreversibleChange
        case insufficientContext
        case policyRequirement
        case firstTimeAction

        public var title: String {
            switch self {
            case .destructiveAction: "破坏性操作"
            case .dataLoss: "数据丢失风险"
            case .financial: "财务影响"
            case .sensitiveData: "敏感数据处理"
            case .externalCommunication: "对外通信"
            case .irreversibleChange: "不可逆变更"
            case .insufficientContext: "上下文不足以决策"
            case .policyRequirement: "策略要求"
            case .firstTimeAction: "首次操作"
            }
        }

        public var friendlyExplanation: String {
            switch self {
            case .destructiveAction: "这个操作可能会对系统造成影响，需要您确认后再执行"
            case .dataLoss: "这个操作可能导致数据丢失，请您仔细确认"
            case .financial: "这个操作涉及资金变动，需要您亲自确认"
            case .sensitiveData: "即将处理您的敏感信息，需要您授权"
            case .externalCommunication: "即将对外发送消息，请您确认内容和收件人"
            case .irreversibleChange: "这个变更无法撤销，请您确认"
            case .insufficientContext: "我没有足够的信息来独立判断，需要您的指导"
            case .policyRequirement: "根据安全策略，此操作需要您确认"
            case .firstTimeAction: "这是我第一次执行这个操作，请您确认是否继续"
            }
        }
    }

    public var category: ReasonCategory
    public var specificReason: String
    public var riskDescription: String
    public var actionSummary: String
    public var isUnderstood: Bool

    public init(category: ReasonCategory, specificReason: String, riskDescription: String = "", actionSummary: String = "", isUnderstood: Bool = false) {
        self.category = category
        self.specificReason = specificReason
        self.riskDescription = riskDescription
        self.actionSummary = actionSummary
        self.isUnderstood = isUnderstood
    }

    public var promptMessage: String {
        var parts: [String] = ["**需要您确认**"]
        parts.append("")
        parts.append("原因：\(category.friendlyExplanation)")
        if !specificReason.isEmpty {
            parts.append("具体说明：\(specificReason)")
        }
        if !riskDescription.isEmpty {
            parts.append("风险：\(riskDescription)")
        }
        if !actionSummary.isEmpty {
            parts.append("操作：\(actionSummary)")
        }
        return parts.joined(separator: "\n")
    }
}

// MARK: - 504. 友好错误消息 (FriendlyErrorMessage)
// 将技术错误转为用户友好的消息

public struct FriendlyErrorMessage: Sendable, Codable, Equatable {
    public var technicalError: String
    public var friendlyMessage: String
    public var suggestion: String
    public var isActionable: Bool
    public var errorCategory: ErrorCategory

    public enum ErrorCategory: String, Sendable, Codable {
        case permissionDenied
        case networkError
        case timeout
        case elementNotFound
        case appNotRunning
        case operationFailed
        case unknown

        public var friendlyCategory: String {
            switch self {
            case .permissionDenied: "权限不足"
            case .networkError: "网络连接"
            case .timeout: "操作超时"
            case .elementNotFound: "找不到目标"
            case .appNotRunning: "应用未启动"
            case .operationFailed: "操作失败"
            case .unknown: "未知问题"
            }
        }
    }

    public init(technicalError: String, friendlyMessage: String, suggestion: String = "", isActionable: Bool = false, errorCategory: ErrorCategory = .unknown) {
        self.technicalError = technicalError
        self.friendlyMessage = friendlyMessage
        self.suggestion = suggestion
        self.isActionable = isActionable
        self.errorCategory = errorCategory
    }

    public func formatted() -> String {
        var parts: [String] = ["😅 \(friendlyMessage)"]
        if !suggestion.isEmpty {
            parts.append("")
            parts.append("建议：\(suggestion)")
        }
        return parts.joined(separator: "\n")
    }

    public static func from(error: Error) -> FriendlyErrorMessage {
        let desc = String(describing: error)
        if desc.localizedCaseInsensitiveContains("permission") || desc.localizedCaseInsensitiveContains("accessibility") {
            return FriendlyErrorMessage(
                technicalError: desc,
                friendlyMessage: "我没有获得足够的权限来执行这个操作",
                suggestion: "请在「系统设置 > 隐私与安全性」中授予辅助功能权限",
                isActionable: true,
                errorCategory: .permissionDenied
            )
        }
        if desc.localizedCaseInsensitiveContains("timeout") || desc.localizedCaseInsensitiveContains("timed out") {
            return FriendlyErrorMessage(
                technicalError: desc,
                friendlyMessage: "操作等待时间过长，可能应用没有响应",
                suggestion: "请检查应用是否正常运行，然后重试",
                isActionable: true,
                errorCategory: .timeout
            )
        }
        if desc.localizedCaseInsensitiveContains("network") || desc.localizedCaseInsensitiveContains("connection") {
            return FriendlyErrorMessage(
                technicalError: desc,
                friendlyMessage: "网络连接似乎出现了问题",
                suggestion: "请检查您的网络连接后重试",
                isActionable: true,
                errorCategory: .networkError
            )
        }
        if desc.localizedCaseInsensitiveContains("not found") || desc.localizedCaseInsensitiveContains("no such") {
            return FriendlyErrorMessage(
                technicalError: desc,
                friendlyMessage: "找不到要操作的目标元素",
                suggestion: "请确认屏幕上的内容没有发生变化",
                isActionable: false,
                errorCategory: .elementNotFound
            )
        }
        return FriendlyErrorMessage(
            technicalError: desc,
            friendlyMessage: "操作执行时遇到了意外问题",
            suggestion: "请重试，如果问题持续请联系支持",
            isActionable: false,
            errorCategory: .unknown
        )
    }
}

// MARK: - 505. 全局停止机制 (GlobalStopMechanism)
// 用户可以随时停止所有操作

public struct GlobalStopMechanism: Sendable, Codable, Equatable {
    public enum StopLevel: String, Sendable, Codable {
        case soft    // 完成当前步骤后停止
        case hard    // 立即停止
        case panic   // 紧急停止，回滚可回滚的操作
    }

    public enum StopState: String, Sendable, Codable {
        case running
        case stopRequested
        case stopped
        case rolledBack
    }

    public var state: StopState
    public var stopLevel: StopLevel?
    public var stoppedAt: Date?
    public var stopReason: String?
    public var canResume: Bool
    public var hotkeyDescription: String

    public init(
        state: StopState = .running,
        stopLevel: StopLevel? = nil,
        stoppedAt: Date? = nil,
        stopReason: String? = nil,
        canResume: Bool = true,
        hotkeyDescription: String = "ESC 或 Option+."
    ) {
        self.state = state
        self.stopLevel = stopLevel
        self.stoppedAt = stoppedAt
        self.stopReason = stopReason
        self.canResume = canResume
        self.hotkeyDescription = hotkeyDescription
    }

    public mutating func requestStop(level: StopLevel = .soft, reason: String = "用户请求停止") {
        state = .stopRequested
        stopLevel = level
        stopReason = reason
    }

    public mutating func confirmStopped() {
        state = .stopped
        stoppedAt = Date()
        canResume = stopLevel != .panic
    }

    public mutating func resume() {
        state = .running
        stopLevel = nil
        stoppedAt = nil
        stopReason = nil
    }

    public var isStopped: Bool {
        state == .stopped || state == .stopRequested
    }

    public var stopMessage: String? {
        guard isStopped else { return nil }
        switch stopLevel {
        case .soft: return "操作将在当前步骤完成后停止"
        case .hard: return "操作已停止"
        case .panic: return "已紧急停止，正在回滚"
        case nil: return "操作已停止"
        }
    }

    public var isRunning: Bool { state == .running }
}
