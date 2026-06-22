import Foundation
import RenJistrolyModels

public struct ModelActionPlanner: Sendable {
    public init() {}

    public func prompt(userText: String, observation: ComputerUseObservation) -> String {
        let frontmost = observation.frontmostApp.map { "\($0.appName) \($0.bundleIdentifier ?? "") \($0.windowTitle ?? "")" } ?? "unknown"
        let windows = observation.visibleWindows.prefix(12).map { "\($0.ownerName) \($0.windowTitle ?? "") \($0.boundsDescription)" }.joined(separator: "\n")
        let apps = observation.runningApps.prefix(30).map { "\($0.appName) \($0.bundleIdentifier ?? "")" }.joined(separator: "\n")
        let ocr = observation.ocrText?.prefix(1500) ?? ""
        return """
        你是 macOS 本地辅助功能动作解析器。只输出 JSON，不要解释，不要说你会执行。
        你的任务是把用户中文命令解析成本地可执行动作计划。真正执行由 macOS Accessibility/CGEvent 完成。

        只允许这些动作：
        - openApplication: {"name": "目标 App 名称，如 Codex、微信、Terminal、Finder、Safari"}
        - focusWeChatMessageInput: {}
        - insertText: {"text": "内容"}
        - setFocusedText: {"text": "内容"}
        - clickElement: {"label":"按钮或控件文字","role":"AXButton|AXTextField|可空","owner":"App 名称或 bundle，可空"}
        - setElementText: {"label":"输入框或控件文字","role":"AXTextField|AXTextArea|可空","owner":"App 名称或 bundle，可空","text":"内容"}
        - pressShortcut: {"key": "return|tab|escape|space|delete|a|c|v|f|w|m", "modifiers": "cmd|cmd+shift|option|control|"}
        - clickFocused: {}
        - clickAt: {"x":"100","y":"200"}
        - doubleClickAt: {"x":"100","y":"200"}
        - rightClickAt: {"x":"100","y":"200"}
        - scroll: {"direction":"up|down","amount":"5"}
        - openURL: {"url":"https://example.com"}
        - openFileOrFolder: {"path":"/Users/..."}
        - openTerminalAtPath: {"path":"/Users/..."}
        - openTerminalCommand: {"path":"/Users/...","command":"安全命令","title":"任务名"}
        - readFocusedText: {}
        - copySelectedText: {}

        外部发送消息不能自动发送。用户说“发送/发出去/并发送”时，只能准备草稿，并设置 requiresConfirmation=true。
        不允许删除文件、付款、发布、发送外部消息、修改系统安全设置。需要这些时返回 requiresConfirmation=true 且只做到草稿/准备阶段。

        返回 JSON 格式：
        {
          "intent": "composeMessage|activateApp|typeText|pressShortcut|unknown",
          "reason": "短原因",
          "requiresConfirmation": true,
          "steps": [
            {"kind":"openApplication","payload":{"name":"微信"},"humanPreview":"打开微信","expectedState":"微信成为前台应用"}
          ]
        }

        当前前台：\(frontmost)
        运行 App：
        \(apps)
        可见窗口：
        \(windows)
        屏幕 OCR：
        \(ocr)

        用户命令：\(userText)
        """
    }

    public func parse(_ text: String, userText: String) -> ComputerUsePlan? {
        guard let json = extractJSONObject(from: text),
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ModelActionPlanPayload.self, from: data)
        else { return nil }
        let steps = decoded.steps.compactMap(makeStep)
        guard !steps.isEmpty else { return nil }
        return ComputerUsePlan(
            userText: userText,
            intent: ComputerUseIntentKind(rawValue: decoded.intent) ?? .unknown,
            steps: steps,
            requiresConfirmation: decoded.requiresConfirmation,
            reason: "模型解析：\(decoded.reason)"
        )
    }

    private func makeStep(_ payload: ModelActionStepPayload) -> ComputerUseStep? {
        guard let kind = actionKind(payload.kind) else { return nil }
        let risk: ActionRiskLevel = switch kind {
        case .insertText, .setFocusedText, .setElementText: (payload.payload["text"] ?? "").count > 120 ? .persistentOrExternal : .reversibleInput
        case .openApplication, .readFocusedText, .copySelectedText: .readOnly
        case .pressShortcut, .clickFocused, .clickElement, .clickAt, .doubleClickAt, .rightClickAt, .scroll, .focusWeChatMessageInput: .reversibleInput
        case .openURL, .openFileOrFolder, .openTerminalAtPath, .openTerminalCommand: .persistentOrExternal
        default: .reversibleInput
        }
        let action = MacAction(
            kind: kind,
            payload: payload.payload,
            riskLevel: risk,
            humanPreview: payload.humanPreview
        )
        return ComputerUseStep(action: action, expectedState: payload.expectedState)
    }

    private static let actionKindMap: [String: MacActionKind] = [
        "openApplication": .openApplication,
        "focusWeChatMessageInput": .focusWeChatMessageInput,
        "insertText": .insertText,
        "setFocusedText": .setFocusedText,
        "clickElement": .clickElement,
        "setElementText": .setElementText,
        "pressShortcut": .pressShortcut,
        "clickFocused": .clickFocused,
        "clickAt": .clickAt,
        "doubleClickAt": .doubleClickAt,
        "rightClickAt": .rightClickAt,
        "scroll": .scroll,
        "openURL": .openURL,
        "openFileOrFolder": .openFileOrFolder,
        "openTerminalAtPath": .openTerminalAtPath,
        "openTerminalCommand": .openTerminalCommand,
        "readFocusedText": .readFocusedText,
        "copySelectedText": .copySelectedText,
    ]

    private func actionKind(_ raw: String) -> MacActionKind? {
        Self.actionKindMap[raw]
    }

    func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start <= end else {
            return nil
        }
        return String(text[start...end])
    }
}

private struct ModelActionPlanPayload: Decodable {
    var intent: String
    var reason: String
    var requiresConfirmation: Bool
    var steps: [ModelActionStepPayload]
}

private struct ModelActionStepPayload: Decodable {
    var kind: String
    var payload: [String: String]
    var humanPreview: String
    var expectedState: String
}
