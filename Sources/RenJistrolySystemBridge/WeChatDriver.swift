import AppKit
import Foundation
import RenJistrolyModels

public struct WeChatDriver: AppDriver {
    public let id = "wechat"
    public let displayName = "WeChat"
    public let capabilities: Set<AppDriverCapability> = [.open, .search, .write, .requiresConfirmationBeforeSend]
    private let appleScriptBridge: AppleScriptBridge

    public init(appleScriptBridge: AppleScriptBridge = AppleScriptBridge()) {
        self.appleScriptBridge = appleScriptBridge
    }

    public func open() throws {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.tencent.xinWeChat") {
            NSWorkspace.shared.open(url)
        } else {
            throw NSError(domain: "WeChatDriver", code: 1, userInfo: [NSLocalizedDescriptionKey: "未找到微信应用"])
        }
    }

    public func searchContact(name: String) async throws -> Bool {
        let script = #"""
        tell application "WeChat"
            activate
            delay 0.3
        end tell
        tell application "System Events"
            tell process "WeChat"
                keystroke "f" using {command down}
                delay 0.3
                keystroke "\#(name)"
                delay 0.5
                keystroke return
            end tell
        end tell
        """#
        let result = try await appleScriptBridge.run(script)
        return result.success
    }

    public func sendMessage(to contact: String, text: String) async throws -> Bool {
        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedContact = contact.replacingOccurrences(of: "\"", with: "\\\"")
        let script = #"""
        tell application "WeChat"
            activate
            delay 0.3
        end tell
        tell application "System Events"
            tell process "WeChat"
                keystroke "f" using {command down}
                delay 0.3
                keystroke "\#(escapedContact)"
                delay 0.5
                keystroke return
                delay 0.5
                keystroke "\#(escaped)"
                delay 0.2
                keystroke return
            end tell
        end tell
        """#
        let result = try await appleScriptBridge.run(script)
        return result.success
    }

    public func readRecentMessages() async throws -> String {
        let script = #"""
        tell application "System Events"
            tell process "WeChat"
                set chatArea to first group of first window
                set messageText to ""
                try
                    set messageText to value of static text 1 of chatArea
                end try
                return messageText
            end tell
        end tell
        """#
        let result = try await appleScriptBridge.run(script)
        return result.stringValue ?? ""
    }

    public func currentChatState() async throws -> WeChatChatState {
        let script = #"""
        tell application "System Events"
            tell process "WeChat"
                try
                    set chatTitle to title of front window
                    return chatTitle
                on error
                    return ""
                end try
            end tell
        end tell
        """#
        let result = try await appleScriptBridge.run(script)
        return WeChatChatState(
            isOpen: true,
            activeChatTitle: result.stringValue?.nonEmptyValue
        )
    }

    public func searchContacts(name: String) async throws -> [String] {
        let script = #"""
        tell application "WeChat"
            activate
            delay 0.3
        end tell
        tell application "System Events"
            tell process "WeChat"
                keystroke "f" using {command down}
                delay 0.2
                keystroke "\#(name)"
                delay 0.8
                keystroke "a" using {command down}
                delay 0.1
                keystroke "c" using {command down}
            end tell
        end tell
        """#
        let result = try await appleScriptBridge.run(script)
        // Parse search results from clipboard or AX tree
        return result.success ? [name] : []
    }

    public func confirmCurrentChat(expectedName: String) async throws -> Bool {
        let state = try await currentChatState()
        guard let title = state.activeChatTitle else { return false }
        return title.localizedCaseInsensitiveContains(expectedName)
    }

    public func draftMessage(_ text: String) async throws -> Bool {
        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
        let script = #"""
        tell application "WeChat"
            activate
            delay 0.2
        end tell
        tell application "System Events"
            tell process "WeChat"
                set frontmost to true
                delay 0.2
                keystroke "\#(escaped)"
            end tell
        end tell
        """#
        let result = try await appleScriptBridge.run(script)
        return result.success
    }

    public func sendDraft() async throws -> Bool {
        let script = #"""
        tell application "System Events"
            tell process "WeChat"
                keystroke return
            end tell
        end tell
        """#
        let result = try await appleScriptBridge.run(script)
        return result.success
    }
}

public struct WeChatChatState: Codable, Sendable, Hashable {
    public let isOpen: Bool
    public let activeChatTitle: String?

    public init(isOpen: Bool, activeChatTitle: String?) {
        self.isOpen = isOpen
        self.activeChatTitle = activeChatTitle
    }
}
