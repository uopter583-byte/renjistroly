import AppKit
import Foundation
import RenJistrolyModels
import RenJistrolySystemBridge
import ScreenCaptureKit

/// Unified coordinator that routes computer use actions through the best available backend,
/// handles verification, and supports cross-backend fallback on failure.
public actor ComputerUseCoordinator {
    public enum BackendChoice: String, Sendable {
        case accessibility
        case dom
        case vision
        case anthropicCU
    }

    public struct ActionTrace: Sendable {
        public let stepIndex: Int
        public let backend: BackendChoice
        public let actionLabel: String
        public let beforeCompactTree: String?
        public let result: BackendActionResult
        public let verification: VerificationSummary
        public let recovered: Bool
        public let recoveryFrom: BackendChoice?
    }

    public struct VerificationSummary: Sendable {
        public let passed: Bool
        public let evidence: [String]
        public let note: String
    }

    public struct RunSummary: Sendable {
        public let traces: [ActionTrace]
        public let succeeded: Bool
        public let totalSteps: Int
        public let completedSteps: Int
    }

    private let accessibility: AccessibilityContextProvider
    private let observer: ComputerUseObserver
    private let vision: VisionCUAFallback

    /// Tracks the last backend used per tool call ID, for UI surfacing.
    public private(set) var lastBackendByToolCallID: [String: BackendChoice] = [:]
    /// Tracks the last permission error per tool call ID.
    public private(set) var lastPermissionErrorByToolCallID: [String: String] = [:]
    /// Tracks the recovery chain: which backend was first attempted before falling back.
    public private(set) var lastRecoveryFromByToolCallID: [String: BackendChoice] = [:]

    public init(accessibility: AccessibilityContextProvider, observer: ComputerUseObserver, vision: VisionCUAFallback) {
        self.accessibility = accessibility
        self.observer = observer
        self.vision = vision
    }

    /// Configure the Vision backend with an LLM backend for screenshot analysis.
    public func configureVisionBackend(_ backend: LLMBackend?) async {
        await vision.setLLMBackend(backend)
    }

    /// Execute a single MacAction through the optimal backend with verification.
    public func execute(_ action: MacAction) async -> ActionTrace {
        let backend = selectBackend(for: action)
        let beforeCompact = await accessibility.compactAccessibilityTree(limit: 30)
        let result: BackendActionResult
        var recovered: Bool = false
        var recoveryFrom: BackendChoice? = nil

        // Primary attempt
        let primary = await executeOnBackend(backend, action: action)
        if primary.success {
            result = primary
            recovered = false
            recoveryFrom = nil
        } else if Self.isPermissionError(primary.message) {
            // Permission errors: skip fallback, surface guidance directly
            result = primary
            recovered = false
            recoveryFrom = nil
        } else {
            // Fallback: try other backends
            let fallbacks: [BackendChoice] = BackendChoice.allCases.filter { $0 != backend }
            var fallbackResult: BackendActionResult?
            for fb in fallbacks {
                let r = await executeOnBackend(fb, action: action)
                if r.success {
                    fallbackResult = r
                    recoveryFrom = backend
                    recovered = true
                    break
                }
            }
            if let fbResult = fallbackResult {
                result = fbResult
            } else {
                result = primary
                recovered = false
                recoveryFrom = nil
            }
        }

        let verification = await verifyAction(action, result: result, beforeCompact: beforeCompact)
        return ActionTrace(
            stepIndex: 0,
            backend: result.success ? backend : (recoveryFrom ?? backend),
            actionLabel: action.humanPreview,
            beforeCompactTree: beforeCompact,
            result: BackendActionResult(success: result.success, message: result.message),
            verification: verification,
            recovered: recovered,
            recoveryFrom: recoveryFrom
        )
    }

    // MARK: - ToolCall-based execution

    /// Execute a ToolCallRequest through the optimal backend with cross-backend fallback.
    /// Maps tool calls to MacAction via actionFromToolCall, routes through selectBackend + executeOnBackend,
    /// and falls back to other backends on failure.
    public func execute(toolCall: ToolCallRequest, policy: ToolExecutionPolicy = .default) async -> ToolCallResult {
        let action = actionFromToolCall(toolCall)
        let backend = selectBackend(for: action)

        let primary = await executeOnBackend(backend, action: action)
        if primary.success {
            lastBackendByToolCallID[toolCall.id] = backend
            lastPermissionErrorByToolCallID[toolCall.id] = nil
            return ToolCallResult(id: toolCall.id, output: primary.message)
        }

        // Permission errors: skip fallback, surface guidance directly
        if Self.isPermissionError(primary.message) {
            lastBackendByToolCallID[toolCall.id] = backend
            lastPermissionErrorByToolCallID[toolCall.id] = primary.message
            return ToolCallResult(id: toolCall.id, output: primary.message, isError: true)
        }

        let fallbacks: [BackendChoice] = BackendChoice.allCases.filter { $0 != backend }
        for fb in fallbacks {
            let r = await executeOnBackend(fb, action: action)
            if r.success {
                lastBackendByToolCallID[toolCall.id] = fb
                lastRecoveryFromByToolCallID[toolCall.id] = backend
                lastPermissionErrorByToolCallID[toolCall.id] = nil
                return ToolCallResult(id: toolCall.id, output: r.message)
            }
        }

        lastBackendByToolCallID[toolCall.id] = backend
        lastRecoveryFromByToolCallID[toolCall.id] = nil
        lastPermissionErrorByToolCallID[toolCall.id] = nil
        return ToolCallResult(id: toolCall.id, output: primary.message, isError: true)
    }

    private func actionFromToolCall(_ toolCall: ToolCallRequest) -> MacAction {
        let args = toolCall.arguments
        let kind: MacActionKind
        let riskLevel: ActionRiskLevel
        let preview: String

        switch toolCall.name {
        case "click":
            if args["click_count"] == "2" { kind = .doubleClickAt }
            else { kind = .clickAt }
            riskLevel = .reversibleInput
            preview = "点击 (\(args["x"] ?? "?"), \(args["y"] ?? "?"))"
        case "click_element":
            kind = .clickElement
            riskLevel = .reversibleInput
            preview = "点击元素: \(args["title"] ?? args["label"] ?? "?")"
        case "type_text", "set_value":
            kind = .insertText
            riskLevel = .reversibleInput
            preview = "输入: \(args["text"] ?? args["value"] ?? "")"
        case "press_key":
            kind = .pressShortcut
            riskLevel = .reversibleInput
            preview = "按键: \(args["key"] ?? "")"
        case "scroll":
            kind = .scroll
            riskLevel = .reversibleInput
            preview = "滚动"
        case "drag":
            kind = .drag
            riskLevel = .reversibleInput
            preview = "拖拽"
        case "open_app", "open_application":
            kind = .openApplication
            riskLevel = .persistentOrExternal
            preview = "打开应用: \(args["app_name"] ?? args["name"] ?? "")"
        case "open_url":
            kind = .openURL
            riskLevel = .persistentOrExternal
            preview = "打开网页: \(args["url"] ?? "")"
        default:
            kind = .readContext
            riskLevel = .readOnly
            preview = toolCall.name
        }

        return MacAction(kind: kind, payload: args, riskLevel: riskLevel, humanPreview: preview)
    }

    /// Execute multiple actions in sequence with per-step verification.
    public func executeAll(actions: [MacAction]) async -> RunSummary {
        var traces: [ActionTrace] = []
        for (index, action) in actions.enumerated() {
            let backend = selectBackend(for: action)
            let beforeCompact = await accessibility.compactAccessibilityTree(limit: 30)
            let primary = await executeOnBackend(backend, action: action)
            let (result, recovered, recoveryFrom): (BackendActionResult, Bool, BackendChoice?)
            if primary.success {
                result = primary; recovered = false; recoveryFrom = nil
            } else if Self.isPermissionError(primary.message) {
                result = primary; recovered = false; recoveryFrom = nil
            } else {
                let fallbacks = BackendChoice.allCases.filter { $0 != backend }
                var fr: BackendActionResult?
                for fb in fallbacks {
                    let r = await executeOnBackend(fb, action: action)
                    if r.success { fr = r; break }
                }
                if let f = fr { result = f; recovered = true; recoveryFrom = backend }
                else { result = primary; recovered = false; recoveryFrom = nil }
            }
            let verification = await verifyAction(action, result: result, beforeCompact: beforeCompact)
            traces.append(ActionTrace(
                stepIndex: index, backend: result.success ? backend : (recoveryFrom ?? backend),
                actionLabel: action.humanPreview, beforeCompactTree: beforeCompact,
                result: result, verification: verification, recovered: recovered, recoveryFrom: recoveryFrom
            ))
            if !result.success { break }
        }
        let completed = traces.filter { $0.result.success }.count
        return RunSummary(traces: traces, succeeded: traces.last?.result.success ?? false,
                          totalSteps: actions.count, completedSteps: completed)
    }

    // MARK: - Permission Pre-check

    /// Check if a backend result message indicates a permission failure.
    public static func isPermissionError(_ message: String) -> Bool {
        message.hasPrefix("[权限错误]")
    }

    /// Required system permission for each backend.
    private enum PermissionRequirement: String {
        case accessibility
        case screenRecording
        case appleEvents
    }

    private static func permissionRequirement(for backend: BackendChoice) -> PermissionRequirement? {
        switch backend {
        case .accessibility: .accessibility
        case .vision: .screenRecording
        case .dom: .appleEvents
        case .anthropicCU: .screenRecording
        }
    }

    /// Check a system permission and return (granted, guidanceMessage).
    private static func checkPermission(_ requirement: PermissionRequirement) async -> (granted: Bool, message: String) {
        switch requirement {
        case .accessibility:
            let granted = AXIsProcessTrusted()
            if !granted {
                return (false, "需要「辅助功能」权限才能控制界面元素。\n请打开 系统设置 → 隐私与安全性 → 辅助功能，添加 RenJistroly 并勾选。\n授权后请重启应用使权限生效。")
            }
            return (true, "")
        case .screenRecording:
            let granted = (try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)) != nil
            if !granted {
                return (false, "需要「屏幕录制」权限才能捕获屏幕截图。\n请打开 系统设置 → 隐私与安全性 → 屏幕录制，添加 RenJistroly 并勾选。\n授权后请重启应用使权限生效。")
            }
            return (true, "")
        case .appleEvents:
            // Apple Events is per-target-app; can't fully pre-check.
            // macOS will prompt automatically on first use.
            return (true, "")
        }
    }

    /// Human-readable backend display name for UI and error messages.
    public static func backendDisplayName(_ backend: BackendChoice) -> String {
        switch backend {
        case .accessibility: "AX (辅助功能)"
        case .dom: "DOM (浏览器)"
        case .vision: "Vision (截图视觉)"
        case .anthropicCU: "Anthropic CU (视觉定位)"
        }
    }

    // MARK: - Backend Selection

    private func selectBackend(for action: MacAction) -> BackendChoice {
        // Browser actions: prefer DOM backend when frontmost app is Safari/Chrome
        let isBrowserAction: Bool = {
            switch action.kind {
            case .clickElement, .setFocusedText, .insertText, .scroll, .pressShortcut, .openURL:
                return true
            default:
                return false
            }
        }()
        if isBrowserAction,
           let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontApp.bundleIdentifier?.lowercased() {
            let isBrowser = bundleID.contains("safari") || bundleID.contains("chrome")
            if isBrowser {
                return .dom
            }
        }

        let ax = AXComputerUseBackend(accessibility: accessibility)
        if ax.canHandle(action: action) { return .accessibility }
        return .vision
    }

    private func executeOnBackend(_ choice: BackendChoice, action: MacAction) async -> BackendActionResult {
        // Permission pre-check before execution
        if let requirement = Self.permissionRequirement(for: choice) {
            let (granted, message) = await Self.checkPermission(requirement)
            if !granted {
                return BackendActionResult(success: false, message: "[权限错误] " + message)
            }
        }

        switch choice {
        case .accessibility:
            let backend = AXComputerUseBackend(accessibility: accessibility)
            return await backend.execute(action: action)
        case .dom:
            let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
            let browserName: String
            if bundleID.contains("chrome") { browserName = "chrome" }
            else { browserName = "safari" }
            let backend = DOMComputerUseBackend(browserName: browserName)
            return await backend.execute(action: action)
        case .vision:
            guard let base64 = await captureBase64Screenshot() else {
                return BackendActionResult(success: false, message: "[权限错误] 截图失败（需要屏幕录制权限）\n请联系管理员检查应用授权状态。")
            }
            let result = await vision.analyze(screenshotBase64: base64, instruction: action.humanPreview)
            guard result.confidence >= 0.5, let point = result.tapPoint else {
                return BackendActionResult(
                    success: false,
                    message: "Vision 定位失败(置信度\(result.confidence)): \(result.explanation)"
                )
            }
            guard point.x >= 0, point.y >= 0,
                  let screenFrame = NSScreen.main?.frame,
                  point.x <= screenFrame.width, point.y <= screenFrame.height else {
                return BackendActionResult(success: false, message: "Vision 坐标超出屏幕: (\(Int(point.x)), \(Int(point.y)))")
            }
            let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
            let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
            let location = CGEventTapLocation.cghidEventTap
            down?.post(tap: location)
            up?.post(tap: location)
            return BackendActionResult(success: true, message: "Vision 定位点击 (\(Int(point.x)), \(Int(point.y))): \(result.explanation)")
        case .anthropicCU:
            let backend = AnthropicCUBackend()
            return await backend.execute(action: action)
        }
    }

    // MARK: - Screenshot

    /// Capture the main screen and return a base64 PNG string.
    /// Uses ScreenCaptureKit via ScreenCaptureBridge — requires Screen Recording permission.
    private func captureBase64Screenshot() async -> String? {
        let bridge = ScreenCaptureBridge()
        guard let pngData = try? await bridge.captureScreen() else { return nil }
        return pngData.base64EncodedString()
    }

    private func verifyAction(_ action: MacAction, result: BackendActionResult, beforeCompact: String?) async -> VerificationSummary {
        guard result.success else {
            return VerificationSummary(passed: false, evidence: [result.message], note: "动作失败")
        }
        var evidence: [String] = []

        switch action.kind {
        case .openApplication:
            if let app = NSWorkspace.shared.frontmostApplication,
               let name = app.localizedName {
                evidence.append("前台应用: \(name)")
                return VerificationSummary(passed: true, evidence: evidence, note: "应用已切换")
            }
            evidence.append("无法确认前台应用")
            return VerificationSummary(passed: false, evidence: evidence, note: "未检测到应用切换")

        case .clickElement, .clickAt, .doubleClickAt:
            let after = await accessibility.compactAccessibilityTree(limit: 20)
            if after != beforeCompact {
                evidence.append("UI 树已变化")
                return VerificationSummary(passed: true, evidence: evidence, note: "界面状态变化")
            }
            evidence.append("UI 树未观察到变化（可能点击已生效但无视觉反馈）")
            return VerificationSummary(passed: true, evidence: evidence, note: "点击完成")

        case .setFocusedText, .insertText, .setElementText:
            let focusedValue = await accessibility.focusedTextDescription()
            let expected = action.payload["text"] ?? ""
            if !expected.isEmpty, focusedValue.localizedCaseInsensitiveContains(expected) {
                evidence.append("焦点内容包含预期文本")
                return VerificationSummary(passed: true, evidence: evidence, note: "输入验证通过")
            }
            evidence.append("已执行输入操作")
            return VerificationSummary(passed: true, evidence: evidence, note: "输入完成")

        case .scroll:
            evidence.append("滚动操作已执行")
            return VerificationSummary(passed: true, evidence: evidence, note: "滚动完成")

        case .pressShortcut:
            evidence.append("快捷键已发送")
            return VerificationSummary(passed: true, evidence: evidence, note: "快捷键完成")

        default:
            evidence.append("操作已执行")
            return VerificationSummary(passed: true, evidence: evidence, note: "执行完成")
        }
    }
}

extension ComputerUseCoordinator.BackendChoice: CaseIterable {}
