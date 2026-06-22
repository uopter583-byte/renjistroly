import Foundation
import RenJistrolyModels

public struct ComputerUsePlanner: Sendable {
    private let localActionParser = LocalActionParser()

    public init() {}

    public func plan(userText: String, observation: ComputerUseObservation) -> ComputerUsePlan? {
        let text = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let plan = parseWeChatMessagePlan(text, observation: observation) {
            return plan
        }

        if let nativeAccessibility = parseNativeAccessibilitySetting(text) {
            let action = MacAction(
                kind: .openURL,
                payload: ["url": nativeAccessibility.settingURLString],
                riskLevel: .readOnly,
                humanPreview: "打开 macOS 辅助功能设置：\(nativeAccessibility.title)"
            )
            return ComputerUsePlan(
                userText: text,
                intent: .openURL,
                action: action,
                reason: "macOS 原生辅助功能入口"
            )
        }

        if let mediaShortcut = parseMediaCommand(text) {
            let action = MacAction(
                kind: .pressShortcut,
                payload: mediaShortcut,
                riskLevel: .reversibleInput,
                humanPreview: "媒体控制：\(text)"
            )
            return ComputerUsePlan(
                userText: text,
                intent: .pressShortcut,
                action: action,
                reason: "本地媒体快捷键"
            )
        }

        if let browserShortcut = parseBrowserCommand(text) {
            let action = MacAction(
                kind: .pressShortcut,
                payload: browserShortcut,
                riskLevel: .reversibleInput,
                humanPreview: "浏览器/标签页控制：\(text)"
            )
            return ComputerUsePlan(
                userText: text,
                intent: .pressShortcut,
                action: action,
                reason: "本地浏览器快捷键"
            )
        }

        if let action = localActionParser.parse(text) {
            let target = targetForAction(action, observation: observation)
            return ComputerUsePlan(
                userText: text,
                intent: intent(for: action.kind),
                target: target,
                action: action,
                requiresConfirmation: action.riskLevel >= .persistentOrExternal,
                reason: "本地命令解析"
            )
        }

        if let appName = parseActivationTarget(text, observation: observation) {
            let action = MacAction(
                kind: .openApplication,
                payload: ["name": appName],
                riskLevel: .readOnly,
                humanPreview: "切换到应用：\(appName)"
            )
            return ComputerUsePlan(
                userText: text,
                intent: .activateApp,
                target: findTarget(named: appName, in: observation),
                action: action,
                reason: "从运行中 App 定位目标"
            )
        }

        if let elementInput = parseElementInput(text, observation: observation) {
            let action = MacAction(
                kind: .setElementText,
                payload: [
                    "label": elementInput.target.label,
                    "role": elementInput.target.role ?? "",
                    "owner": elementInput.target.owner ?? "",
                    "text": elementInput.text
                ],
                riskLevel: elementInput.text.count > 120 ? .persistentOrExternal : .reversibleInput,
                humanPreview: "在 \(elementInput.target.label) 输入：\(elementInput.text)"
            )
            return ComputerUsePlan(
                userText: text,
                intent: .typeText,
                target: elementInput.target,
                action: action,
                requiresConfirmation: elementInput.text.count > 120,
                reason: "从控件树定位输入目标"
            )
        }

        if let typedText = parseTypingText(text) {
            let action = MacAction(
                kind: .insertText,
                payload: ["text": typedText],
                riskLevel: typedText.count > 120 ? .persistentOrExternal : .reversibleInput,
                humanPreview: "输入文本：\(typedText)"
            )
            return ComputerUsePlan(
                userText: text,
                intent: .typeText,
                target: observation.targets.first(where: { $0.kind == .accessibilityElement }),
                action: action,
                requiresConfirmation: typedText.count > 120,
                reason: "输入到当前焦点"
            )
        }

        if let shortcut = parseShortcut(text) {
            let action = MacAction(
                kind: .pressShortcut,
                payload: shortcut,
                riskLevel: .reversibleInput,
                humanPreview: "按快捷键：\(shortcut["modifiers"] ?? "")+\(shortcut["key"] ?? "")"
            )
            return ComputerUsePlan(
                userText: text,
                intent: .pressShortcut,
                action: action,
                reason: "快捷键命令"
            )
        }

        if let key = parseSingleKey(text) {
            let action = MacAction(
                kind: .pressShortcut,
                payload: ["key": key, "modifiers": ""],
                riskLevel: .reversibleInput,
                humanPreview: "按键：\(key)"
            )
            return ComputerUsePlan(
                userText: text,
                intent: .pressShortcut,
                action: action,
                reason: "键盘命令"
            )
        }

        if text.contains("点击") || text.contains("点一下") || text.contains("按一下") {
            let keyword = text
                .replacingOccurrences(of: "点击", with: "")
                .replacingOccurrences(of: "点一下", with: "")
                .replacingOccurrences(of: "按一下", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let target = findTarget(named: keyword, in: observation)
            let action = MacAction(
                kind: target == nil ? .clickFocused : .clickElement,
                payload: target.map { target in
                    [
                        "label": target.label,
                        "role": target.role ?? "",
                        "owner": target.owner ?? ""
                    ]
                } ?? [:],
                riskLevel: .reversibleInput,
                humanPreview: target.map { "点击：\($0.label)" } ?? "点击当前焦点控件"
            )
            return ComputerUsePlan(
                userText: text,
                intent: .clickTarget,
                target: target,
                action: action,
                requiresConfirmation: target == nil,
                reason: target == nil ? "未找到明确目标，退回当前焦点" : "从观察目标定位"
            )
        }

        return nil
    }

    private func parseElementInput(_ text: String, observation: ComputerUseObservation) -> (target: ComputerUseTarget, text: String)? {
        let markers = ["输入", "填入", "写入"]
        let targetPrefixes = ["在", "往", "给"]
        for marker in markers {
            guard let markerRange = text.range(of: marker, options: .backwards) else { continue }
            let head = String(text[..<markerRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            var value = String(text[markerRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            for prefix in ["内容是", "文字是", "为", "：", ":"] where value.hasPrefix(prefix) {
                value = String(value.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard !value.isEmpty else { continue }
            var targetName = head
            for prefix in targetPrefixes where targetName.hasPrefix(prefix) {
                targetName = String(targetName.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            for suffix in ["输入框", "文本框", "框"] where targetName.hasSuffix(suffix) && targetName.count > suffix.count {
                targetName = String(targetName.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
            guard !targetName.isEmpty,
                  let target = findTarget(named: targetName, in: observation)
            else { continue }
            return (target, value)
        }
        return nil
    }

    private func parseNativeAccessibilitySetting(_ text: String) -> NativeAccessibilityFeatureKind? {
        let shouldOpen = text.contains("打开") || text.contains("开启") || text.contains("设置") || text.contains("进入")
        guard shouldOpen else { return nil }
        return NativeAccessibilityFeatureCatalog.match(text)
    }

    private func parseWeChatMessagePlan(_ text: String, observation: ComputerUseObservation) -> ComputerUsePlan? {
        let inWeChatContext = isCurrentWeChatConversation(observation)
        guard text.contains("微信") || inWeChatContext else { return nil }
        guard text.contains("发") || text.contains("发送") || text.contains("告诉") else { return nil }

        let normalized = text
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "。", with: "")
        let contact = parseWeChatContact(from: normalized)
        let message = parseWeChatMessage(from: normalized)

        guard let message, !message.isEmpty else { return nil }
        let hasCurrentWeChatConversation = inWeChatContext && contact == nil

        let open = MacAction(
            kind: .openApplication,
            payload: ["name": "微信"],
            riskLevel: .readOnly,
            humanPreview: "打开微信"
        )
        let focusCurrentInput = MacAction(
            kind: .focusWeChatMessageInput,
            riskLevel: .reversibleInput,
            humanPreview: "识别并聚焦当前微信会话输入框"
        )
        let search = MacAction(
            kind: .pressShortcut,
            payload: ["key": "f", "modifiers": "cmd"],
            riskLevel: .reversibleInput,
            humanPreview: "在微信搜索联系人"
        )
        let typeContact = MacAction(
            kind: .insertText,
            payload: ["text": contact ?? ""],
            riskLevel: .reversibleInput,
            humanPreview: contact == nil ? "等待你选择微信联系人" : "输入联系人：\(contact ?? "")"
        )
        let confirmContact = MacAction(
            kind: .pressShortcut,
            payload: ["key": "return", "modifiers": ""],
            riskLevel: .reversibleInput,
            humanPreview: "打开微信搜索结果"
        )
        let typeMessage = MacAction(
            kind: .insertText,
            payload: ["text": message],
            riskLevel: message.count > 120 ? .persistentOrExternal : .reversibleInput,
            humanPreview: "在微信输入消息草稿：\(message)"
        )

        var steps = [
            ComputerUseStep(action: open, expectedState: "微信成为前台应用")
        ]
        if hasCurrentWeChatConversation {
            steps.append(ComputerUseStep(action: focusCurrentInput, expectedState: "当前微信会话输入框被聚焦"))
        } else {
            steps.append(ComputerUseStep(action: search, expectedState: "微信搜索框或搜索界面被聚焦"))
        }
        if contact != nil, !hasCurrentWeChatConversation {
            steps.append(ComputerUseStep(action: typeContact, expectedState: "搜索框内出现联系人名称"))
            steps.append(ComputerUseStep(action: confirmContact, expectedState: "打开目标聊天"))
            steps.append(ComputerUseStep(action: focusCurrentInput, expectedState: "目标聊天输入框被聚焦"))
        }
        steps.append(ComputerUseStep(action: typeMessage, expectedState: "消息已作为草稿出现在输入框，等待发送确认"))

        return ComputerUsePlan(
            userText: text,
            intent: .composeMessage,
            target: ComputerUseTarget(kind: .runningApp, label: "微信", owner: "com.tencent.xinWeChat", confidence: 0.9),
            action: nil,
            steps: steps,
            requiresConfirmation: true,
            reason: hasCurrentWeChatConversation
                ? "已识别当前微信会话，直接准备草稿；不会自动发送"
                : "微信消息草稿流程：不会自动发送，发送前必须确认"
        )
    }

    private func isCurrentWeChatConversation(_ observation: ComputerUseObservation) -> Bool {
        if let app = observation.frontmostApp {
            let name = app.appName.lowercased()
            let bundle = app.bundleIdentifier?.lowercased() ?? ""
            let isWeChat = app.appName == "微信" || name.contains("wechat") || bundle.contains("xinwechat") || bundle.contains("wechat")
            if isWeChat, let title = app.windowTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
                return title != "微信"
            }
        }

        if observation.visibleWindows.contains(where: { window in
            (window.ownerName == "微信" || window.ownerName.localizedCaseInsensitiveContains("WeChat"))
                && (window.windowTitle?.isEmpty == false)
        }) {
            return true
        }

        let ocr = observation.ocrText ?? ""
        let hasWeChatChatList = ocr.contains("搜索") && (ocr.contains("文件传输助手") || ocr.contains("公众号") || ocr.contains("微信"))
        let hasMessageComposer = ocr.contains("发送") || ocr.contains("输入") || ocr.contains("表情")
        let hasChatBubbles = ocr.contains("现在") || ocr.contains("好的") || ocr.contains("我")
        return hasWeChatChatList && (hasMessageComposer || hasChatBubbles)
    }

    private func parseWeChatContact(from text: String) -> String? {
        let markers = ["微信中给", "微信里给", "微信给", "给", "发给", "微信发给"]
        for marker in markers {
            guard let range = text.range(of: marker) else { continue }
            let tail = String(text[range.upperBound...])
            let stops = ["输入", "发送", "发", "说", "告诉", "：", ":", ","]
            var best: String?
            for stop in stops {
                if let stopRange = tail.range(of: stop) {
                    let candidate = String(tail[..<stopRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !candidate.isEmpty { best = candidate }
                    break
                }
            }
            if let best, !best.contains("微信") {
                return best
            }
        }
        if let inputRange = text.range(of: "输入") {
            let head = String(text[..<inputRange.lowerBound])
            let cleaned = head
                .replacingOccurrences(of: "在微信中", with: "")
                .replacingOccurrences(of: "在微信里", with: "")
                .replacingOccurrences(of: "微信中", with: "")
                .replacingOccurrences(of: "微信里", with: "")
                .replacingOccurrences(of: "给", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        return nil
    }

    private func parseWeChatMessage(from text: String) -> String? {
        let markers = ["内容是", "输入", "发送", "说", "告诉", "发消息", "发微信", "：", ":"]
        for marker in markers {
            guard let range = text.range(of: marker) else { continue }
            var candidate = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            for suffix in ["并发送", "然后发送", "再发送", "发送"] where candidate.hasSuffix(suffix) {
                candidate = String(candidate.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !candidate.isEmpty {
                return candidate
            }
        }
        return nil
    }

    private func targetForAction(_ action: MacAction, observation: ComputerUseObservation) -> ComputerUseTarget? {
        switch action.kind {
        case .openApplication:
            return action.payload["name"].flatMap { findTarget(named: $0, in: observation) }
        case .quitApplication, .hideApplication:
            return action.payload["name"].flatMap { findTarget(named: $0, in: observation) }
        case .openURL:
            return action.payload["url"].map { ComputerUseTarget(kind: .unknown, label: $0, confidence: 0.8) }
        case .openFileOrFolder, .openTerminalAtPath:
            return action.payload["path"].map { ComputerUseTarget(kind: .unknown, label: $0, confidence: 0.8) }
        default:
            return nil
        }
    }

    private func intent(for kind: MacActionKind) -> ComputerUseIntentKind {
        switch kind {
        case .openApplication: .activateApp
        case .quitApplication: .quitApp
        case .hideApplication: .hideApp
        case .closeWindow: .closeWindow
        case .minimizeWindow: .minimizeWindow
        case .openURL: .openURL
        case .openFileOrFolder: .openPath
        case .openTerminalAtPath: .openPath
        case .insertText, .setFocusedText, .setElementText: .typeText
        case .pressShortcut: .pressShortcut
        case .clickFocused, .clickElement, .clickAt, .doubleClickAt, .rightClickAt: .clickTarget
        default: .unknown
        }
    }

    private func parseActivationTarget(_ text: String, observation: ComputerUseObservation) -> String? {
        let prefixes = ["切换到", "切到", "回到", "转到", "进入", "激活"]
        for prefix in prefixes where text.hasPrefix(prefix) {
            let name = String(text.dropFirst(prefix.count))
                .replacingOccurrences(of: "窗口", with: "")
                .replacingOccurrences(of: "应用", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return normalizedAppName(name, observation: observation)
        }
        return nil
    }

    private func normalizedAppName(_ raw: String, observation: ComputerUseObservation) -> String? {
        guard !raw.isEmpty else { return nil }
        if let app = observation.runningApps.first(where: { matches(raw, $0.appName) || matches(raw, $0.bundleIdentifier ?? "") }) {
            return app.appName
        }
        if raw == "微信" || raw.lowercased().contains("wechat") {
            return "微信"
        }
        return raw
    }

    func parseTypingText(_ text: String) -> String? {
        let prefixes = ["输入", "打字", "写入", "粘贴"]
        for prefix in prefixes where text.hasPrefix(prefix) {
            let value = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    func parseShortcut(_ text: String) -> [String: String]? {
        if text.contains("回车") || text.contains("确认") {
            return ["key": "return", "modifiers": ""]
        }
        if text.contains("复制") {
            return ["key": "c", "modifiers": "cmd"]
        }
        if text.contains("粘贴") {
            return ["key": "v", "modifiers": "cmd"]
        }
        if text.contains("全选") {
            return ["key": "a", "modifiers": "cmd"]
        }
        if text.contains("撤销") {
            return ["key": "z", "modifiers": "cmd"]
        }
        if text.contains("保存") {
            return ["key": "s", "modifiers": "cmd"]
        }
        return nil
    }

    func parseMediaCommand(_ text: String) -> [String: String]? {
        let compact = text.replacingOccurrences(of: " ", with: "").lowercased()
        let mappings: [String: [String: String]] = [
            "播放": ["key": "space", "modifiers": ""],
            "暂停": ["key": "space", "modifiers": ""],
            "继续播放": ["key": "space", "modifiers": ""],
            "停止播放": ["key": "space", "modifiers": ""],
            "下一首": ["key": "right", "modifiers": "cmd"],
            "上一首": ["key": "left", "modifiers": "cmd"],
            "快进": ["key": "right", "modifiers": ""],
            "后退": ["key": "left", "modifiers": ""],
            "全屏": ["key": "f", "modifiers": "cmd+ctrl"]
        ]
        return mappings[compact]
    }

    func parseBrowserCommand(_ text: String) -> [String: String]? {
        let compact = text.replacingOccurrences(of: " ", with: "").lowercased()
        let mappings: [String: [String: String]] = [
            "新建标签": ["key": "t", "modifiers": "cmd"],
            "新建标签页": ["key": "t", "modifiers": "cmd"],
            "关闭标签": ["key": "w", "modifiers": "cmd"],
            "关闭标签页": ["key": "w", "modifiers": "cmd"],
            "刷新页面": ["key": "r", "modifiers": "cmd"],
            "刷新": ["key": "r", "modifiers": "cmd"],
            "后退": ["key": "[", "modifiers": "cmd"],
            "前进": ["key": "]", "modifiers": "cmd"],
            "打开地址栏": ["key": "l", "modifiers": "cmd"],
            "聚焦地址栏": ["key": "l", "modifiers": "cmd"],
            "查找页面": ["key": "f", "modifiers": "cmd"],
            "页面查找": ["key": "f", "modifiers": "cmd"]
        ]
        return mappings[compact]
    }

    func parseSingleKey(_ text: String) -> String? {
        let compact = text.replacingOccurrences(of: " ", with: "")
        let mappings = [
            "按回车": "return",
            "按确认": "return",
            "按esc": "escape",
            "按escape": "escape",
            "退出弹窗": "escape",
            "取消": "escape",
            "按tab": "tab",
            "下一个": "tab",
            "空格": "space"
        ]
        return mappings[compact.lowercased()]
    }

    private func findTarget(named raw: String, in observation: ComputerUseObservation) -> ComputerUseTarget? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return observation.targets
            .filter { matches(name, $0.label) || matches(name, $0.owner ?? "") }
            .sorted { $0.confidence > $1.confidence }
            .first
    }

    func matches(_ lhs: String, _ rhs: String) -> Bool {
        let a = lhs.lowercased().replacingOccurrences(of: " ", with: "")
        let b = rhs.lowercased().replacingOccurrences(of: " ", with: "")
        return !a.isEmpty && !b.isEmpty && (a.contains(b) || b.contains(a))
    }
}
