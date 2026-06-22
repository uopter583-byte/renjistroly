import AppKit
import OSLog
import RenJistrolyModels

public enum AccessibilityPermissionGuide {
    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

    public static var message: String {
        let bundlePath = Bundle.main.bundlePath
        return """
        需要先开启辅助功能权限，RenJistroly 才能点击、按键和输入文字。
        请在系统设置 > 隐私与安全性 > 辅助功能中启用 RenJistroly。
        当前授权对象：\(bundlePath)
        如果刚刚启用过，请重启 RenJistroly 后再试。
        """
    }

    @discardableResult
    public static func promptAndOpenSettings() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options: NSDictionary = [key: true]
        let granted = AXIsProcessTrustedWithOptions(options)
        if !granted, let settingsURL {
            NSWorkspace.shared.open(settingsURL)
        }
        return granted
    }
}

public actor AccessibilityBridge {
    private var trusted: Bool = false

    public init() {}

    public func requestPermission() -> Bool {
        AccessibilityPermissionGuide.promptAndOpenSettings()
    }

    public func checkPermission() -> Bool {
        trusted = AXIsProcessTrusted()
        return trusted
    }

    public func getFocusedElement() throws -> AXUIElement? {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        var element: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            getSystemWideElement(),
            kAXFocusedUIElementAttribute as CFString,
            &element
        )
        guard result == .success, let element else { return nil }
        guard CFGetTypeID(element) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(element, to: AXUIElement.self)
    }

    public func getFocusedAppBundleID() throws -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return app.bundleIdentifier
    }

    public func getFocusedWindowTitle() throws -> String? {
        guard let appElement = try getFocusedApp() else { return nil }
        var title: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &title
        )
        guard result == .success, let title else { return nil }
        guard CFGetTypeID(title) == AXUIElementGetTypeID() else { return nil }
        let window = unsafeDowncast(title, to: AXUIElement.self)
        var windowTitle: CFTypeRef?
        AXUIElementCopyAttributeValue(
            window,
            kAXTitleAttribute as CFString,
            &windowTitle
        )
        return windowTitle as? String
    }

    public func activateApp(matching app: String) async throws {
        guard !app.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let candidates = NSWorkspace.shared.runningApplications.filter { runningApp in
            let name = runningApp.localizedName ?? ""
            let bundle = runningApp.bundleIdentifier ?? ""
            return name.localizedCaseInsensitiveContains(app) || bundle.localizedCaseInsensitiveContains(app)
        }
        guard let target = candidates.first else {
            throw AccessibilityError.actionFailed("app not running: \(app)")
        }
        target.activate(options: [.activateAllWindows])
        try await Task.sleep(for: .milliseconds(150))
    }

    public func getAppState(
        app: String? = nil,
        maxDepth: Int = 5,
        includeScreenshot: Bool = false
    ) async throws -> ComputerUseAppState {
        if let app, !app.isEmpty {
            try await activateApp(matching: app)
        }
        guard checkPermission() else { throw AccessibilityError.noPermission }
        let activeApp = NSWorkspace.shared.frontmostApplication
        let appElement = try getFocusedApp()
        let windows = try windowsForState(from: appElement)
        let focusedWindowTitle = try getFocusedWindowTitle()

        var indexedElements: [(ComputerUseElement, AXUIElement)] = []
        if let appElement {
            indexedElements = try await collectIndexedElements(
                appElement,
                depth: 0,
                maxDepth: min(maxDepth, 8),
                childPath: [],
                counter: Counter()
            )
        }
        await ElementRegistry.shared.replace(
            elements: indexedElements,
            appBundleID: activeApp?.bundleIdentifier,
            appName: activeApp?.localizedName
        )

        let screenshot: String?
        if includeScreenshot {
            do {
                let image = try await ScreenCaptureBridge().captureScreen()
                screenshot = image.base64EncodedString()
            } catch {
                #if DEBUG
                os_log("[AccessibilityBridge] 截屏失败: %{public}@", log: .default, type: .error, error.localizedDescription)
                #endif
                screenshot = nil
            }
        } else {
            screenshot = nil
        }

        return ComputerUseAppState(
            requestedApp: app,
            activeAppBundleID: activeApp?.bundleIdentifier,
            activeAppName: activeApp?.localizedName,
            focusedWindowTitle: focusedWindowTitle,
            windows: windows,
            elements: indexedElements.map(\.0),
            screenshotPNGBase64: screenshot
        )
    }

    public func getSelectedText() throws -> String? {
        guard let focused = try getFocusedElement() else { return nil }
        var selectedText: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )
        guard result == .success else { return nil }
        return selectedText as? String
    }

    public func getUIElementTree(maxDepth: Int = 3) throws -> [UIElementNode] {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        guard let app = try getFocusedApp() else { return [] }
        return try traverseElement(app, depth: 0, maxDepth: maxDepth)
    }

    public func performAction(_ action: String, on element: AXUIElement) throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        let result = AXUIElementPerformAction(element, action as CFString)
        guard result == .success else { throw AccessibilityError.actionFailed(action) }
    }

    public func performAction(_ action: String, elementIndex: String, app: String? = nil) async throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        let element = try await ElementRegistry.shared.element(for: elementIndex, expectedApp: app)
        try performAction(action, on: element)
    }

    public func pressKey(_ key: String, modifiers: [String] = []) async throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        try checkDangerousShortcut(key: key, modifiers: modifiers)
        let keyCode = try keyCodeFor(key)
        var flags: CGEventFlags = []
        for mod in modifiers {
            switch mod.lowercased() {
            case "command", "cmd": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "option", "alt": flags.insert(.maskAlternate)
            case "control", "ctrl": flags.insert(.maskControl)
            default: break
            }
        }
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else {
            throw AccessibilityError.actionFailed("pressKey: \(key)")
        }
        event.flags = flags
        event.post(tap: .cghidEventTap)
        // 10ms inter-key delay ensures HID processing completes before release event
        try await Task.sleep(for: .milliseconds(10))
        guard let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw AccessibilityError.actionFailed("pressKey release: \(key)")
        }
        upEvent.flags = flags
        upEvent.post(tap: .cghidEventTap)
        Task { await AgentEventBus.shared.publish(.desktop(.shortcutPressed(key: key, modifiers: modifiers.joined(separator: "+")))) }
    }

    public func typeText(_ text: String) async throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        guard isEditableFocused() else {
            throw AccessibilityError.actionFailed("当前焦点不是输入控件，无法输入文字。请先将光标定位到文本框或输入区域。")
        }
        for char in text {
            let str = String(char)
            if let keyCode = keyCodeForChar(str) {
                // Check if shift is needed
                let needsShift = str != str.lowercased() && str == str.uppercased()
                var flags: CGEventFlags = []
                if needsShift { flags.insert(.maskShift) }

                guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
                      let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
                else { continue }
                down.flags = flags
                up.flags = flags
                down.post(tap: .cghidEventTap)
                // Brief delay between key-down and key-up for reliable HID processing
                try await Task.sleep(for: .milliseconds(5))
                up.post(tap: .cghidEventTap)
                // Pacing delay to prevent event queue overflow
                try await Task.sleep(for: .milliseconds(5))
            } else if str == "\n" || str == "\r" {
                try await pressKey("return")
            } else if str == "\t" {
                try await pressKey("tab")
            } else if str == " " {
                try await pressKey("space")
            } else {
                // For special chars, try CGEvent keyboard string
                if let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
                    let uniChars: [UniChar] = Array(str.utf16)
                    event.keyboardSetUnicodeString(stringLength: uniChars.count, unicodeString: uniChars)
                    event.post(tap: .cghidEventTap)
                    try await Task.sleep(for: .milliseconds(5))
                    if let upEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
                        upEvent.post(tap: .cghidEventTap)
                        try await Task.sleep(for: .milliseconds(5))
                    }
                }
            }
        }
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName
        Task { await AgentEventBus.shared.publish(.desktop(.textTyped(text: text, app: frontApp))) }
    }

    public func setValue(elementIndex: String, value: String, app: String? = nil) async throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        let element = try await ElementRegistry.shared.element(for: elementIndex, expectedApp: app)
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFTypeRef)
        guard result == .success else {
            throw AccessibilityError.actionFailed("setValue on \(elementIndex)")
        }
    }

    // MARK: - Element Search

    public func findFocusedEditableElement() throws -> AXUIElement? {
        guard let focused = try getFocusedElement() else { return nil }
        return try findFirstEditable(from: focused, maxDepth: 5)
    }

    public func trySetTextToFocused(_ text: String) throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        guard let focused = try getFocusedElement() else { throw AccessibilityError.elementNotFound }
        guard let editable = try findFirstEditable(from: focused, maxDepth: 5) else {
            throw AccessibilityError.elementNotFound
        }
        let result = AXUIElementSetAttributeValue(editable, kAXValueAttribute as CFString, text as CFTypeRef)
        guard result == .success else {
            throw AccessibilityError.actionFailed("setValue")
        }
    }

    public func getFocusedValue() throws -> String? {
        guard let element = try getFocusedElement() else { return nil }
        return try getStringAttribute(kAXValueAttribute as CFString, from: element)
    }

    public func getElementRole() throws -> String? {
        guard let element = try getFocusedElement() else { return nil }
        return try getStringAttribute(kAXRoleAttribute as CFString, from: element)
    }

    public func setFocusedValue(_ text: String) throws {
        guard let element = try findFocusedEditableElement() ?? getFocusedElement() else {
            throw AccessibilityError.elementNotFound
        }
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        guard result == .success else {
            throw AccessibilityError.actionFailed("setValue(\(text.prefix(30))...)")
        }
    }

    public func pasteText(_ text: String, restorePasteboard: Bool = true) async throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        guard isEditableFocused() else {
            throw AccessibilityError.actionFailed("当前焦点不是输入控件，无法粘贴文字。请先将光标定位到文本框或输入区域。")
        }
        let targetBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let pasteboard = NSPasteboard.general
        let oldItems = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == targetBundleIdentifier else {
            throw AccessibilityError.actionFailed("frontmost app changed before paste")
        }
        try await pressKey("v", modifiers: ["cmd"])
        // 500ms wait for macOS to complete the paste before restoring clipboard contents
        try await Task.sleep(for: .milliseconds(500))
        // Restore original clipboard after paste
        if restorePasteboard {
            pasteboard.clearContents()
            if let items = oldItems, !items.isEmpty { pasteboard.writeObjects(items) }
        }
    }

    public func pressActionOnFocused(_ action: String) throws {
        guard let element = try getFocusedElement() else {
            throw AccessibilityError.elementNotFound
        }
        try performAction(action, on: element)
    }

    // MARK: - Click UI Elements

    public func clickElement(role: String? = nil, title: String? = nil, label: String? = nil) throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        guard let app = try getFocusedApp() else { throw AccessibilityError.elementNotFound }

        let element = try findElement(in: app, role: role, title: title, label: label, maxDepth: 8)
        guard let element else { throw AccessibilityError.elementNotFound }

        try performAction(kAXPressAction, on: element)
    }

    // MARK: - Menu Navigation

    public func activateMenuItem(path: [String]) async throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        guard let app = try getFocusedApp() else { throw AccessibilityError.elementNotFound }

        // Find the menu bar
        var menuBar: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &menuBar)
        guard let menuBar else { throw AccessibilityError.elementNotFound }
        guard CFGetTypeID(menuBar) == AXUIElementGetTypeID() else { throw AccessibilityError.elementNotFound }
        let menuBarElement = unsafeDowncast(menuBar, to: AXUIElement.self)

        var currentElement: AXUIElement = menuBarElement
        for (index, item) in path.enumerated() {
            guard let found = try findMenuItem(named: item, in: currentElement) else {
                throw AccessibilityError.actionFailed("menu item not found: \(item)")
            }
            if index == path.count - 1 {
                try performAction(kAXPressAction, on: found)
            } else {
                try performAction(kAXPressAction, on: found)
                try? await Task.sleep(for: .milliseconds(100))
                currentElement = found
            }
        }
        Task { await AgentEventBus.shared.publish(.desktop(.menuActivated(path: path.joined(separator: "/")))) }
    }

    // MARK: - Window Management

    public func getWindowList() throws -> [String] {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        guard let app = try getFocusedApp() else { throw AccessibilityError.elementNotFound }

        var windows: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows)
        // toll-free bridged
        guard let windowArray = windows as? [AXUIElement] else { return [] }

        return windowArray.compactMap { window in
            try? getStringAttribute(kAXTitleAttribute as CFString, from: window)
        }
    }

    public func focusWindow(title: String) throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        guard let app = try getFocusedApp() else { throw AccessibilityError.elementNotFound }

        var windows: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows)
        guard let windowArray = windows as? [AXUIElement] else {
            throw AccessibilityError.elementNotFound
        }

        for window in windowArray {
            let windowTitle = (try? getStringAttribute(kAXTitleAttribute as CFString, from: window)) ?? ""
            if windowTitle.localizedCaseInsensitiveContains(title) {
                guard let cfTrue = kCFBooleanTrue else { continue }
                AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, cfTrue)
                AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, cfTrue)
                try? performAction(kAXRaiseAction, on: window)
                let owner = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
                Task { await AgentEventBus.shared.publish(.desktop(.windowFocused(title: title, owner: owner))) }
                return
            }
        }
        throw AccessibilityError.elementNotFound
    }

    public func resizeWindow(title: String? = nil, x: Double? = nil, y: Double? = nil, width: Double? = nil, height: Double? = nil) throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        guard let app = try getFocusedApp() else { throw AccessibilityError.elementNotFound }

        var targetWindow: AXUIElement?
        var windows: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows)

        if let windowArray = windows as? [AXUIElement] {
            if let title {
                for w in windowArray {
                    let t = (try? getStringAttribute(kAXTitleAttribute as CFString, from: w)) ?? ""
                    if t.localizedCaseInsensitiveContains(title) { targetWindow = w; break }
                }
            } else {
                // Get main window
                var main: CFTypeRef?
                AXUIElementCopyAttributeValue(app, kAXMainWindowAttribute as CFString, &main)
                if let main, CFGetTypeID(main) == AXUIElementGetTypeID() { targetWindow = unsafeDowncast(main, to: AXUIElement.self) }
            }
        }

        guard let window = targetWindow else { throw AccessibilityError.elementNotFound }

        var position = CGPoint.zero
        var size = CGSize.zero
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue)
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)
        if let posValue, CFGetTypeID(posValue) == AXValueGetTypeID() { AXValueGetValue(unsafeDowncast(posValue, to: AXValue.self), .cgPoint, &position) }
        if let sizeValue, CFGetTypeID(sizeValue) == AXValueGetTypeID() { AXValueGetValue(unsafeDowncast(sizeValue, to: AXValue.self), .cgSize, &size) }



        if let x { position.x = CGFloat(x) }
        if let y { position.y = CGFloat(y) }
        if let width { size.width = CGFloat(width) }
        if let height { size.height = CGFloat(height) }

        var newPos = position
        var newSize = size
        if let posValue = AXValueCreate(.cgPoint, &newPos) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &newSize) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    // MARK: - Scroll

    public func scroll(deltaY: Int = 0, deltaX: Int = 0, lines: Int = 0) async throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }

        if lines != 0 {
            // Precise line scrolling via CGEvent, no hard caps
            if let event = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .line,
                wheelCount: 1,
                wheel1: -Int32(lines),
                wheel2: 0,
                wheel3: 0
            ) {
                event.post(tap: .cghidEventTap)
                try await Task.sleep(for: .milliseconds(10))
            }
        } else if let editable = try? findFocusedEditableElement() {
            if deltaY > 0 {
                for _ in 0..<deltaY { try? performAction("AXScrollPageDown", on: editable) }
            }
            if deltaY < 0 {
                for _ in 0..<(-deltaY) { try? performAction("AXScrollPageUp", on: editable) }
            }
            if deltaX != 0 {
                let action = deltaX > 0 ? "AXScrollRight" : "AXScrollLeft"
                for _ in 0..<abs(deltaX) { try? performAction(action, on: editable) }
            }
        } else {
            let steps = max(abs(deltaY), abs(deltaX))
            for _ in 0..<steps {
                let scrollY = deltaY > 0 ? -1 : (deltaY < 0 ? 1 : 0)
                let scrollX = deltaX > 0 ? -1 : (deltaX < 0 ? 1 : 0)
                if let event = CGEvent(
                    scrollWheelEvent2Source: nil,
                    units: .line,
                    wheelCount: 2,
                    wheel1: Int32(scrollY * 3),
                    wheel2: Int32(scrollX * 3),
                    wheel3: 0
                ) {
                    event.post(tap: .cghidEventTap)
                    try await Task.sleep(for: .milliseconds(10))
                }
            }
        }
        let dir = deltaY != 0 ? (deltaY > 0 ? "down" : "up") : (deltaX > 0 ? "right" : "left")
        Task { await AgentEventBus.shared.publish(.desktop(.scrolled(direction: dir, amount: Double(max(abs(deltaY), abs(deltaX)))))) }
    }
}

// MARK: - AccessibilityScrolling

extension AccessibilityBridge: AccessibilityScrolling {}

// MARK: - Drag

extension AccessibilityBridge {

    public func drag(from: CGPoint, to: CGPoint) async throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        Task { await AgentEventBus.shared.publish(.desktop(.dragStarted(fromX: from.x, fromY: from.y, toX: to.x, toY: to.y))) }

        // Move to start
        try moveMouse(to: from)
        // 50ms after cursor reposition ensures the system has processed the move
        try await Task.sleep(for: .milliseconds(50))

        // Press
        guard let down = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: from,
            mouseButton: .left
        ) else { throw AccessibilityError.actionFailed("drag down") }
        down.post(tap: .cghidEventTap)
        // 50ms after mouse-down ensures drag start is registered before movement
        try await Task.sleep(for: .milliseconds(50))

        // Drag in steps for smooth movement
        let steps = 20
        for i in 1...steps {
            let fraction = Double(i) / Double(steps)
            let currentX = from.x + (to.x - from.x) * fraction
            let currentY = from.y + (to.y - from.y) * fraction
            let current = CGPoint(x: currentX, y: currentY)

            guard let dragEvent = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDragged,
                mouseCursorPosition: current,
                mouseButton: .left
            ) else { continue }
            dragEvent.post(tap: .cghidEventTap)
            // 8ms between drag interpolation steps for smooth movement
            try await Task.sleep(for: .milliseconds(8))
        }

        // Release
        guard let up = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: to,
            mouseButton: .left
        ) else { throw AccessibilityError.actionFailed("drag up") }
        up.post(tap: .cghidEventTap)
    }

    // MARK: - Mouse

    public func moveMouse(to point: CGPoint) throws {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { throw AccessibilityError.actionFailed("moveMouse") }
        event.post(tap: .cghidEventTap)
    }

    public func click(at point: CGPoint) async throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }

        // Try AX element at coordinates first — no cursor movement
        let systemWide = AXUIElementCreateSystemWide()
        var axElement: AXUIElement?
        let hitResult = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &axElement)
        if hitResult == .success, let element = axElement {
            let actionNames = try copyActionNames(from: element)
            if actionNames.contains(kAXPressAction as String) {
                try performAction(kAXPressAction, on: element)
                Task { await AgentEventBus.shared.publish(.desktop(.mouseClicked(x: point.x, y: point.y, button: "ax_press"))) }
                return
            }
        }

        // Fallback: CGEvent at coordinates (cursor jumps to click point)
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseDown,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { throw AccessibilityError.actionFailed("click down") }
        event.post(tap: .cghidEventTap)
        // 10ms delay between mouse-down and mouse-up for reliable click registration
        try await Task.sleep(for: .milliseconds(10))
        guard let upEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .leftMouseUp,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { throw AccessibilityError.actionFailed("click up") }
        upEvent.post(tap: .cghidEventTap)
        Task { await AgentEventBus.shared.publish(.desktop(.mouseClicked(x: point.x, y: point.y, button: "left"))) }
    }

    public func click(elementIndex: String, app: String? = nil, clickCount: Int = 1) async throws {
        guard checkPermission() else { throw AccessibilityError.noPermission }
        let element = try await ElementRegistry.shared.element(for: elementIndex, expectedApp: app)

        let actionNames = try copyActionNames(from: element)
        if actionNames.contains(kAXPressAction as String) {
            for _ in 0..<max(1, clickCount) {
                try performAction(kAXPressAction, on: element)
                try await Task.sleep(nanoseconds: 50_000_000)
            }
            return
        }

        guard let frame = try frame(of: element) else {
            throw AccessibilityError.actionFailed("click: no frame for \(elementIndex)")
        }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        for _ in 0..<max(1, clickCount) {
            try await self.click(at: center)
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    // MARK: - Private

    private func getSystemWideElement() -> AXUIElement {
        AXUIElementCreateSystemWide()
    }

    private final class Counter {
        var value = 0
        func next() -> Int {
            value += 1
            return value
        }
    }

    private func getFocusedApp() throws -> AXUIElement? {
        let apps = NSWorkspace.shared.runningApplications
        guard let frontmost = apps.first(where: { $0.isActive }) else { return nil }
        return AXUIElementCreateApplication(frontmost.processIdentifier)
    }

    private func windowsForState(from app: AXUIElement?) throws -> [ComputerUseWindow] {
        guard let app else { return [] }
        var windows: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windows)
        // toll-free bridged
        guard let windowArray = windows as? [AXUIElement] else { return [] }

        return windowArray.map { window in
            let title = (try? getStringAttribute(kAXTitleAttribute as CFString, from: window)) ?? ""
            let frame = (try? frame(of: window)).map { rect in
                CodableRect(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
            }
            let isMain = (try? getBoolAttribute(kAXMainAttribute as CFString, from: window)) ?? false
            let isFocused = (try? getBoolAttribute(kAXFocusedAttribute as CFString, from: window)) ?? false
            return ComputerUseWindow(title: title, frame: frame, isMain: isMain, isFocused: isFocused)
        }
    }

    private func collectIndexedElements(
        _ element: AXUIElement,
        depth: Int,
        maxDepth: Int,
        childPath: [Int],
        counter: Counter
    ) async throws -> [(ComputerUseElement, AXUIElement)] {
        guard depth <= maxDepth else { return [] }

        let index = "e\(counter.next())"
        let role = (try? getStringAttribute(kAXRoleAttribute as CFString, from: element)) ?? "unknown"
        let title = try? getStringAttribute(kAXTitleAttribute as CFString, from: element)
        let value = try? getStringAttribute(kAXValueAttribute as CFString, from: element)
        let description = try? getStringAttribute(kAXDescriptionAttribute as CFString, from: element)
        let help = try? getStringAttribute(kAXHelpAttribute as CFString, from: element)
        let enabled = try? getBoolAttribute(kAXEnabledAttribute as CFString, from: element)
        let focused = try? getBoolAttribute(kAXFocusedAttribute as CFString, from: element)
        let rect = (try? frame(of: element)).map {
            CodableRect(x: $0.origin.x, y: $0.origin.y, width: $0.width, height: $0.height)
        }

        let node = ComputerUseElement(
            elementIndex: index,
            role: role,
            title: title,
            value: value,
            description: description,
            help: help,
            frame: rect,
            enabled: enabled,
            focused: focused,
            depth: depth,
            childPath: childPath
        )

        var nodes: [(ComputerUseElement, AXUIElement)] = [(node, element)]
        // Periodic yield prevents blocking the actor executor during deep AX tree traversal
        if counter.value % 15 == 0 {
            await Task.yield()
        }
        guard depth < maxDepth else { return nodes }

        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        if let childrenArray = children as? [AXUIElement] {
            for (offset, child) in childrenArray.prefix(80).enumerated() {
                let path = childPath + [offset]
                try await nodes.append(contentsOf: collectIndexedElements(
                    child,
                    depth: depth + 1,
                    maxDepth: maxDepth,
                    childPath: path,
                    counter: counter
                ))
            }
        }
        return nodes
    }

    private func traverseElement(
        _ element: AXUIElement,
        depth: Int,
        maxDepth: Int
    ) throws -> [UIElementNode] {
        guard depth < maxDepth else { return [] }
        var nodes: [UIElementNode] = []

        var role: CFTypeRef?
        var title: CFTypeRef?
        var description: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)

        let node = UIElementNode(
            role: (role as? String) ?? "unknown",
            title: title as? String,
            description: description as? String,
            depth: depth
        )
        nodes.append(node)

        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        if let childrenArray = children as? [AXUIElement] {
            for child in childrenArray.prefix(20) {
                try nodes.append(contentsOf: traverseElement(child, depth: depth + 1, maxDepth: maxDepth))
            }
        }
        return nodes
    }

    private func findElement(in element: AXUIElement, role: String?, title: String?, label: String?, maxDepth: Int) throws -> AXUIElement? {
        guard maxDepth > 0 else { return nil }

        var elementRole: CFTypeRef?
        var elementTitle: CFTypeRef?
        var elementDesc: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &elementRole)
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &elementTitle)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &elementDesc)

        let r = (elementRole as? String) ?? ""
        let t = (elementTitle as? String) ?? ""
        let d = (elementDesc as? String) ?? ""

        var matches = true
        if let role, !r.localizedCaseInsensitiveContains(role) { matches = false }
        if let title, !t.localizedCaseInsensitiveContains(title) && !d.localizedCaseInsensitiveContains(title) { matches = false }
        if let label {
            var axLabel: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXLabelValueAttribute as CFString, &axLabel)
            let l = (axLabel as? String) ?? ""
            if !l.localizedCaseInsensitiveContains(label) && !t.localizedCaseInsensitiveContains(label) && !d.localizedCaseInsensitiveContains(label) { matches = false }
        }

        if matches && (role != nil || title != nil || label != nil) {
            return element
        }

        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        if let childrenArray = children as? [AXUIElement] {
            for child in childrenArray.prefix(30) {
                if let found = try findElement(in: child, role: role, title: title, label: label, maxDepth: maxDepth - 1) {
                    return found
                }
            }
        }
        return nil
    }

    private func findMenuItem(named name: String, in element: AXUIElement) throws -> AXUIElement? {
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        guard let childrenArray = children as? [AXUIElement] else { return nil }

        for child in childrenArray {
            var role: CFTypeRef?
            var title: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role)
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &title)
            let r = (role as? String) ?? ""
            let t = (title as? String) ?? ""

            if (r == "AXMenuItem" || r == "AXMenuBarItem") && t.localizedCaseInsensitiveContains(name) {
                return child
            }
        }
        return nil
    }

    private func findFirstEditable(from element: AXUIElement, maxDepth: Int) throws -> AXUIElement? {
        guard maxDepth > 0 else { return nil }

        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        let roleStr = (role as? String) ?? ""

        let editableRoles = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
        if editableRoles.contains(roleStr) {
            var isFocused: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXFocusedAttribute as CFString, &isFocused)
            if (isFocused as? Bool) == true {
                return element
            }
            // Even if not focused, return it if it's the right type
            return element
        }

        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        if let childrenArray = children as? [AXUIElement] {
            for child in childrenArray.prefix(20) {
                if let found = try findFirstEditable(from: child, maxDepth: maxDepth - 1) {
                    return found
                }
            }
        }
        return nil
    }

    private func getStringAttribute(_ attr: CFString, from element: AXUIElement) throws -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attr, &value)
        guard result == .success else { return nil }
        if let string = value as? String {
            return string
        }
        if let attributed = value as? NSAttributedString {
            return attributed.string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private func getBoolAttribute(_ attr: CFString, from element: AXUIElement) throws -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attr, &value)
        guard result == .success else { return nil }
        return value as? Bool
    }

    private func frame(of element: AXUIElement) throws -> CGRect? {
        var position = CGPoint.zero
        var size = CGSize.zero
        var posValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue)
        let sizeResult = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        guard posResult == .success, sizeResult == .success,
              let posValue, let sizeValue
        else { return nil }
        guard CFGetTypeID(posValue) == AXValueGetTypeID() else { return nil }
        guard CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        let axPos = unsafeDowncast(posValue, to: AXValue.self)
        let axSize = unsafeDowncast(sizeValue, to: AXValue.self)
        AXValueGetValue(axPos, .cgPoint, &position)
        AXValueGetValue(axSize, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    private func copyActionNames(from element: AXUIElement) throws -> [String] {
        var names: CFArray?
        let result = AXUIElementCopyActionNames(element, &names)
        guard result == .success else { return [] }
        return (names as? [String]) ?? []
    }

    private func isEditableFocused() -> Bool {
        guard let focused = try? getFocusedElement() else { return false }
        let role = (try? getStringAttribute(kAXRoleAttribute as CFString, from: focused)) ?? ""
        let editableRoles = ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField"]
        guard editableRoles.contains(role) else { return false }
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(focused, kAXValueAttribute as CFString, &value) == .success
    }

    private func checkDangerousShortcut(key: String, modifiers: [String]) throws {
        let lowerKey = key.lowercased()
        let hasCmd = modifiers.contains { m in
            let lower = m.lowercased()
            return lower == "cmd" || lower == "command"
        }
        if hasCmd, lowerKey == "q" || lowerKey == "w" {
            throw AccessibilityError.actionFailed("安全限制：禁止执行危险快捷键 Cmd+\(lowerKey.uppercased())，请明确指定目标应用。")
        }
    }

    private func keyCodeForChar(_ char: String) -> CGKeyCode? {
        let map: [String: CGKeyCode] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
            "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46,
            "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1,
            "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
            "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
            "6": 22, "7": 26, "8": 28, "9": 25,
            "-": 27, "=": 24, "[": 33, "]": 30, "\\": 42,
            ";": 41, "'": 39, ",": 43, ".": 47, "/": 44,
            "`": 50,
        ]
        return map[char.lowercased()]
    }

    private func keyCodeFor(_ key: String) throws -> CGKeyCode {
        let map: [String: CGKeyCode] = [
            "return": 36, "enter": 36, "tab": 48, "space": 49,
            "delete": 51, "escape": 53, "esc": 53,
            "left": 123, "right": 124, "down": 125, "up": 126,
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
            "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46,
            "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1,
            "t": 17, "u": 32, "v": 9, "w": 13, "x": 7, "y": 16, "z": 6,
        ]
        guard let code = map[key.lowercased()] else {
            throw AccessibilityError.actionFailed("unknown key: \(key)")
        }
        return code
    }
}

public struct UIElementNode: Sendable, Hashable {
    public let role: String
    public let title: String?
    public let description: String?
    public let depth: Int

    public init(role: String, title: String?, description: String?, depth: Int) {
        self.role = role
        self.title = title
        self.description = description
        self.depth = depth
    }
}

public enum AccessibilityError: LocalizedError, Sendable, Equatable {
    case noPermission
    case actionFailed(String)
    case elementNotFound

    public var errorDescription: String? {
        switch self {
        case .noPermission:
            "RenJistroly 没有辅助功能权限。请在 系统设置 > 隐私 > 辅助功能 中允许 RenJistroly。"
        case .actionFailed(let action):
            "操作失败：\(action)，请重试。"
        case .elementNotFound:
            "未找到目标 UI 元素，请确认窗口或按钮仍在屏幕上。"
        }
    }
}
