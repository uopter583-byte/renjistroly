import AppKit
import Foundation

// MARK: - Menu Item Data

public struct MenuItemInfo: Sendable, Codable {
    public let title: String
    public let enabled: Bool
    public let shortcut: String?
    public let children: [MenuItemInfo]?

    public init(title: String, enabled: Bool, shortcut: String? = nil, children: [MenuItemInfo]? = nil) {
        self.title = title
        self.enabled = enabled
        self.shortcut = shortcut
        self.children = children
    }
}

// MARK: - Menu Bar Enumeration

extension AccessibilityBridge {

    /// Recursively enumerate the menu bar of the frontmost (or specified) application.
    /// Maximum depth is 4 levels (menu bar → menu → submenu → submenu).
    public func enumerateMenuBar(app: String? = nil) async throws -> [MenuItemInfo] {
        guard checkPermission() else { throw AccessibilityError.noPermission }

        var targetApp: NSRunningApplication?
        if let app {
            targetApp = NSWorkspace.shared.runningApplications.first { runningApp in
                let name = runningApp.localizedName ?? ""
                let bundle = runningApp.bundleIdentifier ?? ""
                return name.localizedCaseInsensitiveContains(app) || bundle.localizedCaseInsensitiveContains(app)
            }
        }
        let activeApp = targetApp ?? NSWorkspace.shared.frontmostApplication
        guard let activeApp else { return [] }

        let appElement = AXUIElementCreateApplication(activeApp.processIdentifier)
        var menuBarValue: CFTypeRef?
        AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarValue)
        guard let menuBar = menuBarValue, CFGetTypeID(menuBar) == AXUIElementGetTypeID() else { return [] }
        let menuBarElement = unsafeDowncast(menuBar, to: AXUIElement.self)

        return try collectMenuItems(from: menuBarElement, depth: 0, maxDepth: 4)
    }

    // MARK: - Private

    private func collectMenuItems(from element: AXUIElement, depth: Int, maxDepth: Int) throws -> [MenuItemInfo] {
        guard depth < maxDepth else { return [] }

        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        guard let childrenArray = children as? [AXUIElement] else { return [] }

        var items: [MenuItemInfo] = []
        for child in childrenArray {
            var role: CFTypeRef?
            var title: CFTypeRef?
            var enabled: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
            AXUIElementCopyAttributeValue(child, kAXEnabledAttribute as CFString, &enabled)

            let roleStr = (role as? String) ?? ""
            let titleStr = (title as? String) ?? ""

            guard isMenuRole(roleStr), !titleStr.isEmpty else { continue }

            let isEnabled = (enabled as? Bool) ?? true
            let shortcut = try extractShortcut(from: child)
            let subItems = try collectMenuItems(from: child, depth: depth + 1, maxDepth: maxDepth)

            items.append(MenuItemInfo(
                title: titleStr,
                enabled: isEnabled,
                shortcut: shortcut,
                children: subItems.isEmpty ? nil : subItems
            ))
        }
        return items
    }

    private func isMenuRole(_ role: String) -> Bool {
        ["AXMenuBarItem", "AXMenuItem", "AXMenu"].contains(role)
    }

    private func extractShortcut(from element: AXUIElement) throws -> String? {
        var cmdChar: CFTypeRef?
        var cmdMods: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXMenuItemCmdCharAttribute as CFString, &cmdChar)
        AXUIElementCopyAttributeValue(element, "AXMenuItemCmdModifiers" as CFString, &cmdMods)

        guard let char = cmdChar as? String, !char.isEmpty else { return nil }

        var mods: [String] = []
        if let modFlags = cmdMods as? UInt64 {
            if modFlags & 1 != 0 { mods.append("⌘") }
            if modFlags & 2 != 0 { mods.append("⌥") }
            if modFlags & 4 != 0 { mods.append("⇧") }
            if modFlags & 8 != 0 { mods.append("⌃") }
        }
        return mods.joined() + char.uppercased()
    }
}
