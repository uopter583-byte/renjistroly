import AppKit
import Foundation

// MARK: - Data Types

public struct DialogInfo: Sendable, Codable {
    public let role: String
    public let title: String?
    public let message: String?
    public let buttons: [DialogButtonInfo]
    public let textFieldCount: Int

    public init(role: String, title: String?, message: String?, buttons: [DialogButtonInfo], textFieldCount: Int) {
        self.role = role
        self.title = title
        self.message = message
        self.buttons = buttons
        self.textFieldCount = textFieldCount
    }
}

public struct DialogButtonInfo: Sendable, Codable {
    public let title: String
    public let enabled: Bool

    public init(title: String, enabled: Bool) {
        self.title = title
        self.enabled = enabled
    }
}

// MARK: - Dialog Detector

public struct DialogDetector {
    public init() {}

    /// Scan the current app's AX tree for dialogs, sheets, and alerts.
    public func detectDialogs() async throws -> [DialogInfo] {
        guard AXIsProcessTrusted() else { throw AccessibilityError.noPermission }
        guard let app = try getFocusedApp() else { return [] }
        var dialogs: [DialogInfo] = []
        try collectDialogs(from: app, dialogs: &dialogs, maxDepth: 10)
        return dialogs
    }

    /// Press a button inside a dialog matching the given title (or any dialog if nil).
    public func pressButton(inDialogMatching label: String? = nil, buttonLabel: String) async throws {
        guard AXIsProcessTrusted() else { throw AccessibilityError.noPermission }
        guard let app = try getFocusedApp() else { throw AccessibilityError.elementNotFound }

        let matchedDialogs = try findDialogElements(in: app, maxDepth: 10)
        for (dialogElement, dialogTitle) in matchedDialogs {
            if let label, !dialogTitle.localizedCaseInsensitiveContains(label) {
                continue
            }
            try pressButton(buttonLabel, in: dialogElement)
            return
        }
        throw AccessibilityError.actionFailed("no button '\(buttonLabel)' found\(label.map { " in dialog matching '\($0)'" } ?? "")")
    }

    // MARK: - Private

    private func getFocusedApp() throws -> AXUIElement? {
        guard let frontmost = NSWorkspace.shared.runningApplications.first(where: { $0.isActive }) else { return nil }
        return AXUIElementCreateApplication(frontmost.processIdentifier)
    }

    private func findDialogElements(in element: AXUIElement, maxDepth: Int) throws -> [(AXUIElement, String)] {
        guard maxDepth > 0 else { return [] }
        var results: [(AXUIElement, String)] = []
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleStr = (role as? String) ?? ""

        if ["AXSheet", "AXDialog", "AXAlert"].contains(roleStr) {
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
            results.append((element, (title as? String) ?? ""))
            // Don't recurse into the dialog itself for nested dialogs
            return results
        }

        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        guard let childrenArray = children as? [AXUIElement] else { return results }
        for child in childrenArray {
            try results.append(contentsOf: findDialogElements(in: child, maxDepth: maxDepth - 1))
        }
        return results
    }

    private func collectDialogs(from element: AXUIElement, dialogs: inout [DialogInfo], maxDepth: Int) throws {
        guard maxDepth > 0 else { return }
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleStr = (role as? String) ?? ""

        if ["AXSheet", "AXDialog", "AXAlert"].contains(roleStr) {
            if let info = try buildDialogInfo(from: element) {
                dialogs.append(info)
            }
            return
        }

        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        guard let childrenArray = children as? [AXUIElement] else { return }
        for child in childrenArray {
            try collectDialogs(from: child, dialogs: &dialogs, maxDepth: maxDepth - 1)
        }
    }

    private func buildDialogInfo(from element: AXUIElement) throws -> DialogInfo? {
        var role: CFTypeRef?
        var title: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)

        let roleStr = (role as? String) ?? ""
        var message: String?
        var buttons: [DialogButtonInfo] = []
        var textFieldCount = 0

        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        if let childrenArray = children as? [AXUIElement] {
            for child in childrenArray {
                if let info = try extractButton(from: child) {
                    buttons.append(info)
                } else if try isTextField(child) {
                    textFieldCount += 1
                } else if let text = try extractStaticText(from: child), message == nil {
                    message = text
                }
            }
        }

        return DialogInfo(role: roleStr, title: title as? String, message: message, buttons: buttons, textFieldCount: textFieldCount)
    }

    private func extractButton(from element: AXUIElement) throws -> DialogButtonInfo? {
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        guard (role as? String) == "AXButton" else { return nil }

        var title: CFTypeRef?
        var desc: CFTypeRef?
        var enabled: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &desc)
        AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &enabled)

        let buttonTitle = (title as? String) ?? (desc as? String) ?? ""
        guard !buttonTitle.isEmpty else { return nil }

        return DialogButtonInfo(title: buttonTitle, enabled: (enabled as? Bool) ?? true)
    }

    private func isTextField(_ element: AXUIElement) throws -> Bool {
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleStr = (role as? String) ?? ""
        return ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"].contains(roleStr)
    }

    private func extractStaticText(from element: AXUIElement) throws -> String? {
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        guard (role as? String) == "AXStaticText" else { return nil }
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        return value as? String
    }

    private func pressButton(_ label: String, in dialogElement: AXUIElement) throws {
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(dialogElement, kAXChildrenAttribute as CFString, &children)
        guard let childrenArray = children as? [AXUIElement] else {
            throw AccessibilityError.actionFailed("dialog has no children")
        }

        for child in childrenArray {
            var role: CFTypeRef?
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)

            guard (role as? String) == "AXButton",
                  let btnTitle = title as? String,
                  btnTitle.localizedCaseInsensitiveContains(label) else { continue }

            var enabled: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXEnabledAttribute as CFString, &enabled)
            guard (enabled as? Bool) != false else {
                throw AccessibilityError.actionFailed("button '\(label)' is disabled")
            }

            let result = AXUIElementPerformAction(child, kAXPressAction as CFString)
            guard result == .success else {
                throw AccessibilityError.actionFailed("press button '\(label)'")
            }
            return
        }
        throw AccessibilityError.actionFailed("button '\(label)' not found")
    }
}
