import AppKit
import ApplicationServices
import Foundation
import RenJistrolyModels

public actor AccessibilityContextProvider {
    public init() {}

    public func requestPermission() -> Bool {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let options: NSDictionary = [key: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    public func readFrontmostApp() -> AppContext? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return AppContext(
            appName: app.localizedName ?? app.bundleIdentifier ?? "Unknown App",
            bundleIdentifier: app.bundleIdentifier,
            windowTitle: focusedWindowTitle()
        )
    }

    public func readRunningApps() -> [RunningAppContext] {
        NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular
                    || app.localizedName == "微信"
                    || app.localizedName == "WeChat"
            }
            .compactMap { app in
                guard let name = app.localizedName ?? app.bundleIdentifier else { return nil }
                return RunningAppContext(
                    appName: name,
                    bundleIdentifier: app.bundleIdentifier,
                    isFrontmost: app.isActive
                )
            }
            .sorted { lhs, rhs in
                if lhs.isFrontmost != rhs.isFrontmost { return lhs.isFrontmost && !rhs.isFrontmost }
                return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
            }
    }

    public func readFocusedElement() -> UIElementContext? {
        guard AXIsProcessTrusted(), let element = focusedElementWithFallback() else { return nil }
        return UIElementContext(
            role: stringAttribute(kAXRoleAttribute, from: element),
            title: stringAttribute(kAXTitleAttribute, from: element),
            value: stringAttribute(kAXValueAttribute, from: element),
            selectedText: stringAttribute(kAXSelectedTextAttribute, from: element)
        )
    }

    public func readFrontmostAccessibilityTargets(limit: Int = 80) -> [ComputerUseTarget] {
        guard AXIsProcessTrusted(),
              let app = NSWorkspace.shared.frontmostApplication
        else { return [] }
        if app.bundleIdentifier == Bundle.main.bundleIdentifier || app.processIdentifier == NSRunningApplication.current.processIdentifier {
            return []
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var targets: [ComputerUseTarget] = []
        if let windows = axChildrenAttribute(kAXWindowsAttribute, from: appElement), !windows.isEmpty {
            for window in windows.prefix(4) {
                collectTargets(
                    from: window,
                    owner: app.localizedName ?? app.bundleIdentifier,
                    depth: 0,
                    limit: limit,
                    targets: &targets
                )
                if targets.count >= limit { break }
            }
        } else {
            collectTargets(
                from: appElement,
                owner: app.localizedName ?? app.bundleIdentifier,
                depth: 0,
                limit: limit,
                targets: &targets
            )
        }
        return targets
    }

    public func readSelectedText() -> String? {
        guard AXIsProcessTrusted(), let element = focusedElementWithFallback() else { return nil }
        return stringAttribute(kAXSelectedTextAttribute, from: element)
    }

    private func verifyTargetApp(expectedBundleID: String?) throws {
        guard let expected = expectedBundleID else { return }
        let currentBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if currentBundleID != expected {
            throw AccessibilityContextError.appChanged(expected: expected, current: currentBundleID ?? "unknown")
        }
    }

    public func insertText(_ text: String) throws {
        guard AXIsProcessTrusted() else { throw AccessibilityContextError.notAuthorized }
        let targetBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let pasteboard = NSPasteboard.general
        let oldItems = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
        defer {
            pasteboard.clearContents()
            if let items = oldItems, !items.isEmpty {
                pasteboard.writeObjects(items)
            }
        }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        try verifyTargetApp(expectedBundleID: targetBundleIdentifier)
        try pressShortcut(keyCode: 9, flags: .maskCommand)
        let waitMicroseconds: useconds_t = useconds_t(max(150_000, text.utf8.count * 50))
        usleep(waitMicroseconds)
    }

    public func setFocusedText(_ text: String) throws {
        guard AXIsProcessTrusted() else { throw AccessibilityContextError.notAuthorized }
        guard let element = focusedElementWithFallback() else {
            try insertText(text)
            return
        }
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFString)
        if result != .success {
            try insertText(text)
        }
    }

    public func focusedTextDescription() -> String {
        guard let element = focusedElementWithFallback() else { return "没有找到焦点控件。" }
        let role = stringAttribute(kAXRoleAttribute, from: element) ?? "未知"
        let title = stringAttribute(kAXTitleAttribute, from: element) ?? ""
        let value = stringAttribute(kAXValueAttribute, from: element) ?? ""
        let selected = stringAttribute(kAXSelectedTextAttribute, from: element) ?? ""
        var lines = ["焦点控件：\(role)"]
        if !title.isEmpty { lines.append("标题：\(title)") }
        if !value.isEmpty { lines.append("内容：\(value)") }
        if !selected.isEmpty { lines.append("选中：\(selected)") }
        return lines.joined(separator: "\n")
    }

    public func pressShortcut(key: String, modifiers: [String]) throws {
        guard AXIsProcessTrusted() else { throw AccessibilityContextError.notAuthorized }
        let keyCode = try keyCode(for: key)
        var flags: CGEventFlags = []
        for modifier in modifiers {
            switch modifier.lowercased() {
            case "cmd", "command": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "option", "alt": flags.insert(.maskAlternate)
            case "control", "ctrl": flags.insert(.maskControl)
            default: break
            }
        }
        try pressShortcut(keyCode: keyCode, flags: flags)
    }

    public func clickFocused() throws {
        guard AXIsProcessTrusted() else { throw AccessibilityContextError.notAuthorized }
        guard let element = focusedElementWithFallback() else { throw AccessibilityContextError.elementNotFound }
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        guard result == .success else { throw AccessibilityContextError.actionFailed("AXPress") }
    }

    public func clickElement(label: String, role: String? = nil, owner: String? = nil) throws {
        guard AXIsProcessTrusted() else { throw AccessibilityContextError.notAuthorized }
        let targetBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        // Verify BEFORE click
        try verifyTargetApp(expectedBundleID: targetBundleID)
        guard let element = findElement(label: label, role: role, owner: owner) else {
            throw AccessibilityContextError.elementNotFound
        }
        let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
        if result == .success {
            return
        }
        if result == .actionUnsupported, let point = centerPoint(of: element) {
            guard click(at: point, clickCount: 1, button: .left) else {
                throw AccessibilityContextError.actionFailed("click element")
            }
            try verifyTargetApp(expectedBundleID: targetBundleID)
            return
        }
        if let point = centerPoint(of: element), click(at: point, clickCount: 1, button: .left) {
            try verifyTargetApp(expectedBundleID: targetBundleID)
            return
        }
        throw AccessibilityContextError.actionFailed("AXPress")
    }

    public func setElementText(label: String, text: String, role: String? = nil, owner: String? = nil) throws {
        guard AXIsProcessTrusted() else { throw AccessibilityContextError.notAuthorized }
        let targetBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard let element = findElement(label: label, role: role, owner: owner) else {
            throw AccessibilityContextError.elementNotFound
        }
        AXUIElementSetAttributeValue(focusedAppElement() ?? AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, element)
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFString)
        if result == .success {
            try verifyTargetApp(expectedBundleID: targetBundleID)
            return
        }
        if let point = centerPoint(of: element), click(at: point, clickCount: 1, button: .left) {
            try verifyTargetApp(expectedBundleID: targetBundleID)
            try insertText(text)
            return
        }
        throw AccessibilityContextError.actionFailed("set element text")
    }

    public enum MouseButton: Sendable {
        case left
        case right
    }

    // MARK: - Foreground input (cghidEventTap)

    public func click(at point: CGPoint, clickCount: Int = 1, button: MouseButton = .left) -> Bool {
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier {
            return click(at: point, clickCount: clickCount, button: button, toPid: pid)
        }
        return click(at: point, clickCount: clickCount, button: button, toPid: nil)
    }

    public func scroll(direction: String, amount: Double) -> Bool {
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier {
            return scroll(direction: direction, amount: amount, toPid: pid)
        }
        return scroll(direction: direction, amount: amount, toPid: nil)
    }

    public func drag(from start: CGPoint, to end: CGPoint) -> Bool {
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier {
            return drag(from: start, to: end, toPid: pid)
        }
        return drag(from: start, to: end, toPid: nil)
    }

    // MARK: - Background input (CGEventPostToPid + SkyLight SPI)

    /// Click at screen point, optionally targeting a specific PID for background delivery.
    ///
    /// Cursor-neutral 3-level strategy:
    ///   Level 1 → AX element hit-test + kAXPressAction (zero cursor movement, no mouse grab)
    ///   Level 2 → CGEventPostToPid / SkyLight SPI (background delivery, cursor stays put)
    ///   Level 3 → CGEvent cghidEventTap (moves cursor — only as last resort)
    public func click(at point: CGPoint, clickCount: Int = 1, button: MouseButton = .left, toPid pid: pid_t?) -> Bool {
        // Level 1: AX hit-test for single left-clicks — zero cursor movement.
        // Only for nil-PID calls (no explicit target process); when a PID
        // is explicitly provided, go straight to background delivery.
        if pid == nil, button == .left, clickCount == 1, AXIsProcessTrusted() {
            let systemWide = AXUIElementCreateSystemWide()
            var axElement: AXUIElement?
            if AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &axElement) == .success,
               let element = axElement {
                var actionNames: CFArray?
                if AXUIElementCopyActionNames(element, &actionNames) == .success,
                   let actions = actionNames as? [String],
                   actions.contains(kAXPressAction as String) {
                    if AXUIElementPerformAction(element, kAXPressAction as CFString) == .success {
                        return true
                    }
                }
            }
        }

        let downType: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
        let upType: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp
        let cgButton: CGMouseButton = button == .left ? .left : .right

        guard let targetPid = pid else {
            let expectedBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            do { try verifyTargetApp(expectedBundleID: expectedBundleID) } catch { return false }
            for _ in 0..<max(1, clickCount) {
                guard let down = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: cgButton),
                      let up = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: cgButton) else {
                    return false
                }
                down.post(tap: .cghidEventTap)
                usleep(20_000)
                up.post(tap: .cghidEventTap)
                usleep(80_000)
            }
            return true
        }

        // Background path: dual-post via SkyLight + public CGEvent.postToPid.
        // Neither path moves the user's real cursor.
        for clickIndex in 0..<max(1, clickCount) {
            guard let down = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: cgButton),
                  let up = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: cgButton) else {
                return false
            }
            down.setIntegerValueField(.mouseEventClickState, value: Int64(clickIndex + 1))
            up.setIntegerValueField(.mouseEventClickState, value: Int64(clickIndex + 1))

            // Belt-and-suspenders: SkyLight SPI first, then public API fallback
            if !SkyLightEventPost.postToPid(targetPid, event: down, attachAuthMessage: false) {
                down.postToPid(targetPid)
            }
            usleep(20_000)
            if !SkyLightEventPost.postToPid(targetPid, event: up, attachAuthMessage: false) {
                up.postToPid(targetPid)
            }
            usleep(80_000)
        }
        return true
    }

    // MARK: - Chromium-style click (NSEvent bridge + FocusWithoutRaise + primer)

    /// Chromium/Electron-optimized click that uses NSEvent-bridged CGEvent
    /// construction, yabai-style focus-without-raise, and an off-screen
    /// primer click to satisfy Chromium's user-activation gate.
    ///
    /// Sequence: FocusWithoutRaise → 50ms settle → mouseMoved at target →
    /// off-screen primer at (-1,-1) → target click pair(s).
    ///
    /// Falls back to the basic dual-post path when the NSEvent bridge
    /// or FocusWithoutRaise SPIs are unavailable.
    public func clickChromiumStyle(
        at point: CGPoint,
        toPid pid: pid_t,
        clickCount: Int = 1
    ) -> Bool {
        guard SkyLightEventPost.isAvailable else {
            return click(at: point, clickCount: clickCount, toPid: pid)
        }

        // Resolve target window for field stamps + window-local coords
        let targetWindows = SkyLightEventPost.windowIDs(forPid: pid)
        let windowID = Int64(targetWindows.first ?? 0)
        let windowBounds = frontmostWindowBounds(forPid: pid)
        let windowLocal = windowBounds.map { CGPoint(x: point.x - $0.minX, y: point.y - $0.minY) } ?? point

        // Step 1: activate without raise
        if windowID != 0 {
            _ = FocusWithoutRaise.activateWithoutRaise(
                targetPid: pid, targetWid: CGWindowID(windowID))
            usleep(50_000)
        }

        // Helper: build NSEvent-bridged CGEvent. Chromium's renderer
        // trusts NSEvent-bridged events; raw-CGEvent-built events are
        // filtered at the renderer IPC boundary.
        func makeEvent(_ type: NSEvent.EventType, clickCount: Int) -> CGEvent? {
            guard let ns = NSEvent.mouseEvent(
                with: type,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: Int(windowID),
                context: nil,
                eventNumber: 0,
                clickCount: clickCount,
                pressure: 1.0
            ) else { return nil }
            return ns.cgEvent
        }

        // Helper: stamp common fields on every event
        func stamp(_ event: CGEvent, screenPt: CGPoint, winLocal: CGPoint, clickState: Int64) {
            event.location = screenPt
            event.setIntegerValueField(.mouseEventButtonNumber, value: 0)
            event.setIntegerValueField(.mouseEventSubtype, value: 3)
            event.setIntegerValueField(.mouseEventClickState, value: clickState)
            if windowID != 0 {
                event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: windowID)
                event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: windowID)
            }
            _ = SkyLightEventPost.setWindowLocation(event, winLocal)
            _ = SkyLightEventPost.setIntegerField(event, field: 40, value: Int64(pid))
        }

        // Step 2: mouseMoved at target
        guard let move = makeEvent(.mouseMoved, clickCount: 0) else {
            return click(at: point, clickCount: clickCount, toPid: pid)
        }
        stamp(move, screenPt: point, winLocal: windowLocal, clickState: 0)

        // Step 3: off-screen primer click at (-1, -1) — satisfies
        // Chromium's user-activation gate without hitting any DOM element
        let offScreen = CGPoint(x: -1, y: -1)
        guard let primerDown = makeEvent(.leftMouseDown, clickCount: 1),
              let primerUp = makeEvent(.leftMouseUp, clickCount: 1)
        else {
            return click(at: point, clickCount: clickCount, toPid: pid)
        }
        stamp(primerDown, screenPt: offScreen, winLocal: offScreen, clickState: 1)
        stamp(primerUp, screenPt: offScreen, winLocal: offScreen, clickState: 1)

        // Step 4: target click pair(s)
        let pairs = max(1, min(2, clickCount))
        var targetPairs: [(down: CGEvent, up: CGEvent)] = []
        for pairIndex in 1...pairs {
            guard let down = makeEvent(.leftMouseDown, clickCount: pairIndex),
                  let up = makeEvent(.leftMouseUp, clickCount: pairIndex)
            else {
                return click(at: point, clickCount: clickCount, toPid: pid)
            }
            let state = Int64(pairIndex)
            stamp(down, screenPt: point, winLocal: windowLocal, clickState: state)
            stamp(up, screenPt: point, winLocal: windowLocal, clickState: state)
            targetPairs.append((down, up))
        }

        func post(_ event: CGEvent) {
            _ = SkyLightEventPost.postToPid(pid, event: event, attachAuthMessage: false)
        }

        post(move)
        usleep(15_000)
        post(primerDown)
        usleep(1_000)
        post(primerUp)
        usleep(100_000)
        for (i, pair) in targetPairs.enumerated() {
            post(pair.down)
            usleep(1_000)
            post(pair.up)
            if i < targetPairs.count - 1 { usleep(80_000) }
        }
        return true
    }

    private func frontmostWindowBounds(forPid pid: pid_t) -> CGRect? {
        guard let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        else { return nil }
        for info in all {
            guard (info[kCGWindowOwnerPID as String] as? Int32) == pid,
                  (info[kCGWindowLayer as String] as? Int32) ?? 1 == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? Double,
                  let y = bounds["Y"] as? Double,
                  let w = bounds["Width"] as? Double,
                  let h = bounds["Height"] as? Double
            else { continue }
            return CGRect(x: x, y: y, width: w, height: h)
        }
        return nil
    }

    /// Scroll at screen position, optionally targeting a specific PID.
    public func scroll(direction: String, amount: Double, toPid pid: pid_t?) -> Bool {
        let units = Int32(max(1, amount))
        let delta: Int32
        switch direction.lowercased() {
        case "up", "上": delta = units
        case "down", "下": delta = -units
        default: return false
        }
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: delta, wheel2: 0, wheel3: 0) else {
            return false
        }
        if let targetPid = pid {
            if !SkyLightEventPost.postToPid(targetPid, event: event, attachAuthMessage: false) {
                event.postToPid(targetPid)
            }
        } else {
            let expectedBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            do { try verifyTargetApp(expectedBundleID: expectedBundleID) } catch { return false }
            event.post(tap: .cghidEventTap)
        }
        return true
    }

    /// Drag from start to end, optionally targeting a specific PID.
    ///
    /// Cursor-neutral strategy (no AX equivalent for drag):
    ///   Level 2 → CGEventPostToPid / SkyLight SPI (background, cursor-neutral)
    ///   Level 3 → CGEvent cghidEventTap (moves cursor, last resort)
    public func drag(from start: CGPoint, to end: CGPoint, toPid pid: pid_t?) -> Bool {
        guard let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: start, mouseButton: .left),
              let drag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: end, mouseButton: .left),
              let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: end, mouseButton: .left) else {
            return false
        }
        if let targetPid = pid {
            if !SkyLightEventPost.postToPid(targetPid, event: down, attachAuthMessage: false) {
                down.postToPid(targetPid)
            }
            usleep(50_000)
            if !SkyLightEventPost.postToPid(targetPid, event: drag, attachAuthMessage: false) {
                drag.postToPid(targetPid)
            }
            usleep(50_000)
            if !SkyLightEventPost.postToPid(targetPid, event: up, attachAuthMessage: false) {
                up.postToPid(targetPid)
            }
        } else {
            let expectedBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            do { try verifyTargetApp(expectedBundleID: expectedBundleID) } catch { return false }
            down.post(tap: .cghidEventTap)
            usleep(50_000)
            drag.post(tap: .cghidEventTap)
            usleep(50_000)
            up.post(tap: .cghidEventTap)
        }
        return true
    }

    /// Press shortcut key combo, optionally targeting a specific PID for background delivery.
    public func pressShortcut(key: String, modifiers: [String], toPid pid: pid_t?) throws {
        guard AXIsProcessTrusted() else { throw AccessibilityContextError.notAuthorized }
        let keyCode = try keyCode(for: key)
        var flags: CGEventFlags = []
        for modifier in modifiers {
            switch modifier.lowercased() {
            case "cmd", "command": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "option", "alt": flags.insert(.maskAlternate)
            case "control", "ctrl": flags.insert(.maskControl)
            default: break
            }
        }
        try pressShortcut(keyCode: keyCode, flags: flags, toPid: pid)
    }

    public func openApplication(named name: String) async -> Bool {
        let targetNames = applicationNameCandidates(for: name)
        if await activateRunningApplication(named: name, targetNames: targetNames, shouldYieldFocus: true) {
            return true
        }
        guard let url = applicationURL(named: name) else {
            return false
        }
        yieldFocusIfSwitchingAway(to: targetNames)
        _ = try? await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        if waitUntilFrontmost(matchesAnyOf: targetNames, timeout: 1.2) {
            return true
        }
        _ = await runOpen(arguments: ["-a", url.path])
        if waitUntilFrontmost(matchesAnyOf: targetNames, timeout: 1.2) {
            return true
        }
        if let bundleIdentifier = bundleIdentifier(forApplicationAt: url) {
            _ = await runOpen(arguments: ["-b", bundleIdentifier])
            if waitUntilFrontmost(matchesAnyOf: targetNames + [bundleIdentifier], timeout: 1.2) {
                return true
            }
        }
        for candidate in targetNames where !candidate.contains(".") {
            _ = await runOpen(arguments: ["-a", candidate])
            if waitUntilFrontmost(matchesAnyOf: targetNames, timeout: 1.2) {
                return true
            }
        }
        restoreFocusAfterFailedSwitch()
        return false
    }

    public func isApplicationFrontmost(named name: String) -> Bool {
        waitUntilFrontmost(matchesAnyOf: applicationNameCandidates(for: name), timeout: 0.1)
    }

    private func activateRunningApplication(named rawName: String, targetNames: [String]? = nil, shouldYieldFocus: Bool = false) async -> Bool {
        let name = normalizedApplicationQuery(rawName)
        guard !name.isEmpty else { return false }
        let names = targetNames ?? applicationNameCandidates(for: rawName)
        guard let app = NSWorkspace.shared.runningApplications
            .filter({ app in
            let localized = app.localizedName ?? ""
            let bundle = app.bundleIdentifier ?? ""
            return matchesApplicationQuery(name, localized)
                || matchesApplicationQuery(name, bundle)
                || names.contains(where: { matchesApplicationQuery($0, localized) || matchesApplicationQuery($0, bundle) })
            })
            .sorted(by: preferredActivationOrder)
            .first else {
            return false
        }
        if shouldYieldFocus {
            yieldFocusIfSwitchingAway(to: names)
        }
        app.unhide()
        _ = app.activate(options: [.activateAllWindows])
        if waitUntilFrontmost(matchesAnyOf: names, timeout: 0.8) {
            return true
        }
        raiseWindows(for: app.processIdentifier)
        if waitUntilFrontmost(matchesAnyOf: names, timeout: 0.8) {
            return true
        }
        if let bundleIdentifier = app.bundleIdentifier {
            _ = await runOpen(arguments: ["-b", bundleIdentifier])
            if waitUntilFrontmost(matchesAnyOf: names + [bundleIdentifier], timeout: 1.2) {
                return true
            }
        }
        for candidate in names where !candidate.contains(".") {
            _ = await runOpen(arguments: ["-a", candidate])
            if waitUntilFrontmost(matchesAnyOf: names, timeout: 1.2) {
                return true
            }
        }
        restoreFocusAfterFailedSwitch()
        return false
    }

    public func quitApplication(named name: String) -> Bool {
        guard let app = runningApplication(named: name) else { return false }
        return app.terminate()
    }

    public func hideApplication(named name: String) -> Bool {
        guard let app = runningApplication(named: name) else { return false }
        return app.hide()
    }

    private func runningApplication(named rawName: String) -> NSRunningApplication? {
        let name = normalizedApplicationQuery(rawName)
        return NSWorkspace.shared.runningApplications.first { app in
            let localized = app.localizedName ?? ""
            let bundle = app.bundleIdentifier ?? ""
            return matchesApplicationQuery(name, localized) || matchesApplicationQuery(name, bundle)
        }
    }

    public func openURL(_ rawURL: String) -> Bool {
        let text = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = text.contains("://") ? text : "https://\(text)"
        guard let url = URL(string: normalized) else { return false }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        NSWorkspace.shared.open(url)
        return true
    }

    public func openFileOrFolder(_ rawPath: String) -> Bool {
        let expanded = rawPath.replacingOccurrences(of: "~", with: NSHomeDirectory())
        let url = URL(fileURLWithPath: expanded)
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        NSWorkspace.shared.open(url)
        return true
    }

    public func openTerminal(at rawPath: String) -> Bool {
        let expanded = rawPath.replacingOccurrences(of: "~", with: NSHomeDirectory())
        let path = FileManager.default.fileExists(atPath: expanded) ? expanded : NSHomeDirectory()
        let script = """
        tell application "Terminal"
            activate
            do script "cd \(shellEscapedForAppleScript(path))"
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return false }
        appleScript.executeAndReturnError(&error)
        return error == nil
    }

    public func openTerminal(command rawCommand: String, at rawPath: String, title: String? = nil) -> Bool {
        let command = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return false }
        let expanded = rawPath.replacingOccurrences(of: "~", with: NSHomeDirectory())
        let path = FileManager.default.fileExists(atPath: expanded) ? expanded : NSHomeDirectory()
        let titleCommand: String
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            titleCommand = "printf '\\\\e]0;\(shellEscapedForAppleScript(title))\\\\a'; "
        } else {
            titleCommand = ""
        }
        let fullCommand = "cd \(shellQuoted(path)); \(titleCommand)\(command)"
        let script = """
        tell application "Terminal"
            activate
            do script "\(shellEscapedForAppleScript(fullCommand))"
        end tell
        """
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return false }
        appleScript.executeAndReturnError(&error)
        return error == nil
    }

    public func focusWeChatMessageInput() async -> Bool {
        guard await openApplication(named: "微信") else { return false }
        yieldFocusIfSwitchingAway(to: applicationNameCandidates(for: "微信"))
        usleep(250_000)
        if focusEditableElement(inApplicationNamed: "微信") {
            return true
        }
        guard let window = visibleWindowBounds(ownerNames: ["微信", "WeChat"]) else {
            return false
        }
        let x = window.midX
        let y = window.maxY - min(70, max(45, window.height * 0.08))
        return click(at: CGPoint(x: x, y: y), clickCount: 1, button: .left)
    }

    private func applicationURL(named rawName: String) -> URL? {
        let name = normalizedApplicationQuery(rawName)
        guard !name.isEmpty else { return nil }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: name) {
            return url
        }

        let candidates = applicationNameCandidates(for: name)

        for candidate in candidates {
            if candidate.hasPrefix("/"), FileManager.default.fileExists(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate) {
                return url
            }
            if let url = NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "/Applications/\(candidate).app")) {
                return url
            }
            if let url = NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "/System/Applications/\(candidate).app")) {
                return url
            }
            if let url = NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "/System/Applications/Utilities/\(candidate).app")) {
                return url
            }
            if let url = NSWorkspace.shared.urlForApplication(toOpen: URL(fileURLWithPath: "\(NSHomeDirectory())/Applications/\(candidate).app")) {
                return url
            }
        }

        return nil
    }

    private func applicationNameCandidates(for rawName: String) -> [String] {
        let name = normalizedApplicationQuery(rawName)
            .replacingOccurrences(of: "。", with: "")
        let aliases: [String: [String]] = [
            "终端": ["Terminal", "com.apple.Terminal"],
            "terminal": ["Terminal", "com.apple.Terminal"],
            "命令行": ["Terminal", "com.apple.Terminal"],
            "访达": ["Finder", "com.apple.finder"],
            "finder": ["Finder", "com.apple.finder"],
            "浏览器": ["Safari", "com.apple.Safari"],
            "safari": ["Safari", "com.apple.Safari", "Safari浏览器"],
            "Safari": ["Safari浏览器", "com.apple.Safari"],
            "谷歌浏览器": ["Google Chrome", "com.google.Chrome"],
            "chrome": ["Google Chrome", "com.google.Chrome"],
            "Google Chrome": ["谷歌浏览器", "com.google.Chrome"],
            "备忘录": ["Notes", "com.apple.Notes"],
            "notes": ["Notes", "备忘录", "com.apple.Notes"],
            "Notes": ["备忘录", "com.apple.Notes"],
            "文本编辑": ["TextEdit", "com.apple.TextEdit"],
            "textedit": ["TextEdit", "文本编辑", "com.apple.TextEdit"],
            "TextEdit": ["文本编辑", "com.apple.TextEdit"],
            "便笺": ["Stickies", "com.apple.Stickies"],
            "日历": ["Calendar", "com.apple.iCal"],
            "calendar": ["Calendar", "日历", "com.apple.iCal"],
            "提醒事项": ["Reminders", "com.apple.reminders"],
            "reminders": ["Reminders", "提醒事项", "com.apple.reminders"],
            "邮件": ["Mail", "com.apple.mail"],
            "mail": ["Mail", "邮件", "com.apple.mail"],
            "信息": ["Messages", "com.apple.MobileSMS"],
            "messages": ["Messages", "信息", "com.apple.MobileSMS"],
            "微信": ["微信", "WeChat", "com.tencent.xinWeChat", "com.tencent.flue.WeChatAppEx"],
            "wechat": ["WeChat", "微信", "com.tencent.xinWeChat", "com.tencent.flue.WeChatAppEx"],
            "weixin": ["WeChat", "微信", "com.tencent.xinWeChat", "com.tencent.flue.WeChatAppEx"],
            "音乐": ["Music", "com.apple.Music"],
            "music": ["Music", "音乐", "com.apple.Music"],
            "Music": ["音乐", "com.apple.Music"],
            "播客": ["Podcasts", "com.apple.podcasts"],
            "podcasts": ["Podcasts", "播客", "com.apple.podcasts"],
            "照片": ["Photos", "com.apple.Photos"],
            "photos": ["Photos", "照片", "com.apple.Photos"],
            "系统设置": ["System Settings", "com.apple.systempreferences"],
            "设置": ["System Settings", "com.apple.systempreferences"],
            "system settings": ["System Settings", "系统设置", "com.apple.systempreferences"],
            "system preferences": ["System Settings", "系统设置", "com.apple.systempreferences"],
            "活动监视器": ["Activity Monitor", "com.apple.ActivityMonitor"],
            "activity monitor": ["Activity Monitor", "活动监视器", "com.apple.ActivityMonitor"],
            "磁盘工具": ["Disk Utility", "com.apple.DiskUtility"],
            "disk utility": ["Disk Utility", "磁盘工具", "com.apple.DiskUtility"],
            "控制台": ["Console", "com.apple.Console"],
            "console": ["Console", "控制台", "com.apple.Console"],
            "脚本编辑器": ["Script Editor", "com.apple.ScriptEditor2"],
            "script editor": ["Script Editor", "脚本编辑器", "com.apple.ScriptEditor2"],
            "xcode": ["Xcode", "com.apple.dt.Xcode"],
            "Xcode": ["com.apple.dt.Xcode"],
            "codex": ["Codex", "/Applications/Codex.app"],
            "vscode": ["Visual Studio Code", "com.microsoft.VSCode"],
            "Visual Studio Code": ["com.microsoft.VSCode"],
            "github desktop": ["GitHub Desktop", "com.github.GitHubClient"],
            "github": ["GitHub Desktop", "com.github.GitHubClient"],
            "钥匙串访问": ["Keychain Access", "com.apple.keychainaccess"],
            "keychain access": ["Keychain Access", "钥匙串访问", "com.apple.keychainaccess"],
            "词典": ["Dictionary", "com.apple.Dictionary"],
            "dictionary": ["Dictionary", "词典", "com.apple.Dictionary"],
            "计算器": ["Calculator", "com.apple.calculator"],
            "calculator": ["Calculator", "计算器", "com.apple.calculator"],
            "预览": ["Preview", "com.apple.Preview"],
            "preview": ["Preview", "预览", "com.apple.Preview"],
            "地图": ["Maps", "com.apple.Maps"],
            "maps": ["Maps", "地图", "com.apple.Maps"],
            "时钟": ["Clock", "com.apple.clock"],
            "clock": ["Clock", "时钟", "com.apple.clock"],
            "天气": ["Weather", "com.apple.weather"],
            "weather": ["Weather", "天气", "com.apple.weather"],
            "股票": ["Stocks", "com.apple.stocks"],
            "stocks": ["Stocks", "股票", "com.apple.stocks"],
            "语音备忘录": ["VoiceMemos", "com.apple.VoiceMemos"],
            "voicememos": ["VoiceMemos", "语音备忘录", "com.apple.VoiceMemos"],
            "快捷指令": ["Shortcuts", "com.apple.shortcuts"],
            "shortcuts": ["Shortcuts", "快捷指令", "com.apple.shortcuts"],
            "自动化": ["Automator", "com.apple.Automator"],
            "automator": ["Automator", "自动化", "com.apple.Automator"],
        ]
        var candidates = [name]
        candidates.append(contentsOf: aliases[name.lowercased()] ?? aliases[name] ?? [])
        return candidates.reduce(into: []) { result, candidate in
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !result.contains(trimmed) {
                result.append(trimmed)
            }
        }
    }

    private func preferredActivationOrder(_ lhs: NSRunningApplication, _ rhs: NSRunningApplication) -> Bool {
        if lhs.activationPolicy != rhs.activationPolicy {
            return lhs.activationPolicy == .regular
        }
        let lhsName = lhs.localizedName ?? ""
        let rhsName = rhs.localizedName ?? ""
        if lhsName != rhsName {
            if lhsName == "微信" { return true }
            if rhsName == "微信" { return false }
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }
        return lhs.processIdentifier < rhs.processIdentifier
    }

    private func yieldFocusIfSwitchingAway(to candidates: [String]) {
        let currentNames = [
            NSRunningApplication.current.localizedName ?? "",
            Bundle.main.bundleIdentifier ?? ""
        ]
        let switchingToSelf = candidates.contains { target in
            currentNames.contains { current in
                matchesApplicationQuery(target, current)
            }
        }
        guard !switchingToSelf else { return }
        NSRunningApplication.current.hide()
        if Bundle.main.bundleIdentifier != nil {
            DispatchQueue.main.async { @MainActor in
                NSApp?.hide(nil)
            }
        }
        usleep(180_000)
    }

    private func restoreFocusAfterFailedSwitch() {
        guard !NSRunningApplication.current.isActive else { return }
        NSRunningApplication.current.unhide()
        _ = NSRunningApplication.current.activate(options: [.activateAllWindows])
    }

    private func waitUntilFrontmost(matchesAnyOf candidates: [String], timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let app = NSWorkspace.shared.frontmostApplication {
                let localized = app.localizedName ?? ""
                let bundle = app.bundleIdentifier ?? ""
                if candidates.contains(where: { matchesApplicationQuery($0, localized) || matchesApplicationQuery($0, bundle) }) {
                    return true
                }
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return false
    }

    private func raiseWindows(for pid: pid_t) {
        guard AXIsProcessTrusted() else { return }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
           let windows = value as? [AXUIElement] { // toll-free bridged
            for window in windows.prefix(3) {
                AXUIElementPerformAction(window, kAXRaiseAction as CFString)
            }
        }
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let focusedWindow, CFGetTypeID(focusedWindow) == AXUIElementGetTypeID() {
            let window = unsafeDowncast(focusedWindow, to: AXUIElement.self)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
    }

    private func runOpen(arguments: [String]) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = arguments
        process.standardError = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        let (_, status) = (try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<(String, Int32), Error>) in
            process.terminationHandler = { proc in
                cont.resume(returning: ("", proc.terminationStatus))
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }) ?? ("", -1)
        return status == 0
    }

    private func bundleIdentifier(forApplicationAt url: URL) -> String? {
        Bundle(url: url)?.bundleIdentifier
    }

    private func focusEditableElement(inApplicationNamed name: String) -> Bool {
        guard AXIsProcessTrusted(), let app = runningApplication(named: name) else { return false }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let editable = firstEditableElement(in: appElement, depth: 0) else { return false }
        AXUIElementSetAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, editable)
        let result = AXUIElementPerformAction(editable, kAXPressAction as CFString)
        return result == .success || result == .actionUnsupported
    }

    private func firstEditableElement(in element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth < 8 else { return nil }
        let role = stringAttribute(kAXRoleAttribute, from: element) ?? ""
        let subrole = stringAttribute(kAXSubroleAttribute, from: element) ?? ""
        if role == "AXTextArea" || role == "AXTextField" || subrole.localizedCaseInsensitiveContains("Text") {
            return element
        }
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
           let children = value as? [AXUIElement] {
            for child in children.reversed() {
                if let match = firstEditableElement(in: child, depth: depth + 1) {
                    return match
                }
            }
        }
        return nil
    }

    private func collectTargets(
        from element: AXUIElement,
        owner: String?,
        depth: Int,
        limit: Int,
        targets: inout [ComputerUseTarget]
    ) {
        guard depth <= 8, targets.count < limit else { return }
        let role = stringAttribute(kAXRoleAttribute, from: element)
        let title = stringAttribute(kAXTitleAttribute, from: element)
        let value = stringAttribute(kAXValueAttribute, from: element)
        let description = stringAttribute(kAXDescriptionAttribute, from: element)
        let placeholder = stringAttribute(kAXPlaceholderValueAttribute, from: element)
        let label = [title, value, description, placeholder, role]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "控件"
        if let role, shouldExpose(role: role, label: label) {
            targets.append(
                ComputerUseTarget(
                    kind: .accessibilityElement,
                    label: String(label.prefix(120)),
                    owner: owner,
                    role: role,
                    boundsDescription: boundsDescription(for: element),
                    valuePreview: value.map { String($0.prefix(180)) },
                    actions: actionNames(for: element),
                    depth: depth,
                    confidence: roleConfidence(role)
                )
            )
        }

        if let children = axChildrenAttribute(kAXChildrenAttribute, from: element) {
            for child in children.prefix(80) {
                collectTargets(from: child, owner: owner, depth: depth + 1, limit: limit, targets: &targets)
                if targets.count >= limit { break }
            }
        }
    }

    private func findElement(label: String, role: String?, owner: String?) -> AXUIElement? {
        guard let app = targetApplication(owner: owner) ?? NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var best: (element: AXUIElement, score: Double)?
        findElementRecursive(
            appElement,
            label: label,
            role: role,
            depth: 0,
            best: &best
        )
        return best?.element
    }

    private func targetApplication(owner: String?) -> NSRunningApplication? {
        guard let owner, !owner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return NSWorkspace.shared.runningApplications
            .filter { app in
                let name = app.localizedName ?? ""
                let bundle = app.bundleIdentifier ?? ""
                return matchesApplicationQuery(owner, name) || matchesApplicationQuery(owner, bundle)
            }
            .sorted(by: preferredActivationOrder)
            .first
    }

    private func findElementRecursive(
        _ element: AXUIElement,
        label: String,
        role expectedRole: String?,
        depth: Int,
        best: inout (element: AXUIElement, score: Double)?
    ) {
        guard depth <= 9 else { return }
        let role = stringAttribute(kAXRoleAttribute, from: element)
        let title = stringAttribute(kAXTitleAttribute, from: element)
        let value = stringAttribute(kAXValueAttribute, from: element)
        let description = stringAttribute(kAXDescriptionAttribute, from: element)
        let placeholder = stringAttribute(kAXPlaceholderValueAttribute, from: element)
        let candidates = [title, value, description, placeholder, role].compactMap { $0 }
        let score = matchScore(needle: label, candidates: candidates, role: role, expectedRole: expectedRole)
        if score > (best?.score ?? 0) {
            best = (element, score)
        }
        if let children = axChildrenAttribute(kAXChildrenAttribute, from: element) {
            for child in children.prefix(120) {
                findElementRecursive(child, label: label, role: expectedRole, depth: depth + 1, best: &best)
            }
        }
    }

    private func axChildrenAttribute(_ attribute: String, from element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? [AXUIElement] // toll-free bridged
    }

    private func matchScore(needle: String, candidates: [String], role: String?, expectedRole: String?) -> Double {
        let normalizedNeedle = normalizedMatchText(needle)
        guard !normalizedNeedle.isEmpty else { return 0 }
        var score = 0.0
        for candidate in candidates {
            let normalizedCandidate = normalizedMatchText(candidate)
            if normalizedCandidate == normalizedNeedle {
                score = max(score, 1.0)
            } else if normalizedCandidate.contains(normalizedNeedle) || normalizedNeedle.contains(normalizedCandidate) {
                score = max(score, 0.72)
            }
        }
        if let expectedRole, let role, expectedRole == role {
            score += 0.18
        }
        if let role, role == "AXButton" || role.localizedCaseInsensitiveContains("Text") {
            score += 0.08
        }
        return score
    }

    private func normalizedMatchText(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func centerPoint(of element: AXUIElement) -> CGPoint? {
        guard let description = boundsDescription(for: element) else { return nil }
        let numbers = description
            .split { !$0.isNumber }
            .compactMap { Double($0) }
        guard numbers.count >= 4 else { return nil }
        return CGPoint(x: numbers[0] + numbers[2] / 2, y: numbers[1] + numbers[3] / 2)
    }

    private func shouldExpose(role: String, label: String) -> Bool {
        let interestingRoles = [
            "AXButton", "AXTextField", "AXTextArea", "AXSearchField", "AXCheckBox", "AXRadioButton",
            "AXPopUpButton", "AXMenuButton", "AXMenuItem", "AXStaticText", "AXLink", "AXTabGroup",
            "AXList", "AXRow", "AXCell", "AXOutline", "AXTable", "AXComboBox", "AXSlider"
        ]
        if interestingRoles.contains(role) { return true }
        return !label.isEmpty && (role.localizedCaseInsensitiveContains("Text") || role.localizedCaseInsensitiveContains("Button"))
    }

    private func actionNames(for element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success,
              let actions = names as? [String]
        else { return [] }
        return Array(actions.prefix(6))
    }

    private func boundsDescription(for element: AXUIElement) -> String? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let position = positionValue,
              let size = sizeValue
        else { return nil }
        guard CFGetTypeID(position) == AXValueGetTypeID() else { return nil }
        guard CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        let axPos = unsafeDowncast(position, to: AXValue.self)
        let axSize = unsafeDowncast(size, to: AXValue.self)
        var point = CGPoint.zero
        var cgSize = CGSize.zero
        AXValueGetValue(axPos, .cgPoint, &point)
        AXValueGetValue(axSize, .cgSize, &cgSize)
        return "x:\(Int(point.x)) y:\(Int(point.y)) w:\(Int(cgSize.width)) h:\(Int(cgSize.height))"
    }

    private func roleConfidence(_ role: String) -> Double {
        switch role {
        case "AXButton", "AXTextField", "AXTextArea", "AXSearchField": 0.86
        case "AXMenuItem", "AXLink", "AXCheckBox", "AXPopUpButton": 0.78
        case "AXStaticText": 0.58
        default: 0.64
        }
    }

    private func visibleWindowBounds(ownerNames: [String]) -> CGRect? {
        guard let rawWindows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        return rawWindows.compactMap { window -> CGRect? in
            guard let owner = window[kCGWindowOwnerName as String] as? String,
                  ownerNames.contains(where: { matchesApplicationQuery($0, owner) }),
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat,
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat,
                  width > 320,
                  height > 240
            else { return nil }
            return CGRect(x: x, y: y, width: width, height: height)
        }
        .sorted { $0.width * $0.height > $1.width * $1.height }
        .first
    }

    private func normalizedApplicationQuery(_ rawName: String) -> String {
        rawName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "窗口", with: "")
            .replacingOccurrences(of: "应用", with: "")
            .replacingOccurrences(of: "软件", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchesApplicationQuery(_ query: String, _ candidate: String) -> Bool {
        let q = query.lowercased().replacingOccurrences(of: " ", with: "")
        let c = candidate.lowercased().replacingOccurrences(of: " ", with: "")
        guard !q.isEmpty, !c.isEmpty else { return false }
        if q == "微信", c.contains("wechat") || c.contains("xinwechat") || candidate == "微信" {
            return true
        }
        return q == c || q.contains(c) || c.contains(q)
    }

    private func shellEscapedForAppleScript(_ path: String) -> String {
        path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func focusedWindowTitle() -> String? {
        guard AXIsProcessTrusted() else { return nil }
        guard let app = focusedAppElement() else { return nil }
        var window: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &window)
        guard let window else { return nil }
        guard CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        let windowElement = unsafeDowncast(window, to: AXUIElement.self)
        return stringAttribute(kAXTitleAttribute, from: windowElement)
    }

    /// Generate a compact accessibility tree string in Brother-style format:
    /// `- button "OK" [ref=e1]`
    /// Filters structural containers, assigns sequential ref IDs.
    /// Returns empty string if no AX tree is available or permission is denied.
    public func compactAccessibilityTree(limit: Int = 40, appBundleID: String? = nil) -> String {
        guard AXIsProcessTrusted() else { return "(需要辅助功能权限)" }
        let app: NSRunningApplication
        if let bundleID = appBundleID {
            guard let match = NSWorkspace.shared.runningApplications.first(where: {
                $0.bundleIdentifier == bundleID
            }) else { return "(未找到应用)" }
            app = match
        } else {
            guard let front = NSWorkspace.shared.frontmostApplication else { return "(无前台应用)" }
            app = front
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var refCounter = 0
        var lines: [String] = []

        func addLine(_ text: String) { lines.append(text) }

        func collectCompact(from element: AXUIElement, depth: Int) {
            guard depth <= 6, refCounter < limit else { return }
            let role = stringAttribute(kAXRoleAttribute, from: element) ?? ""
            let title = stringAttribute(kAXTitleAttribute, from: element) ?? ""
            let value = stringAttribute(kAXValueAttribute, from: element) ?? ""
            let desc = stringAttribute(kAXDescriptionAttribute, from: element) ?? ""
            let placeholder = stringAttribute(kAXPlaceholderValueAttribute, from: element) ?? ""

            let name = [title, value, desc, placeholder].compactMap { $0 }.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""

            let interactiveRoles: Set<String> = ["AXButton", "AXLink", "AXTextField", "AXComboBox",
                "AXCheckBox", "AXRadioButton", "AXSlider", "AXPopUpButton", "AXMenuButton",
                "AXTabGroup", "AXDisclosureTriangle", "AXStepper", "AXSegmentedControl",
                "AXOutline", "AXBrowser", "AXList", "AXTable", "AXTree", "AXSheet",
                "AXScrollBar", "AXHandle", "AXCell", "AXColumn", "AXGrid", "AXRow",
                "AXMenu", "AXMenuItem", "AXMenuItemCheckBox", "AXStaticText",
                "AXHeading", "AXImage", "AXProgressIndicator", "AXLevelIndicator",
                "AXDatePicker", "AXColorWell", "AXSplitter", "AXToolbar",
                "AXGroup", "AXScrollArea", "AXSplitGroup", "AXValueIndicator",
                "AXMenuBar", "AXMenuBarItem"]

            let structuralRoles: Set<String> = ["AXWindow", "AXApplication", "AXDrawer",
                "AXSystemWide", "AXUnknown", "AXLayoutArea", "AXLayoutItem",
                "AXDockItem", "AXStatusItem"]

            let shouldSkip = structuralRoles.contains(role) || (!interactiveRoles.contains(role) && name.isEmpty)

            if !shouldSkip {
                refCounter += 1
                let displayName = name.isEmpty ? role : name
                let indent = String(repeating: "  ", count: depth)
                addLine("\(indent)- \(role.replacingOccurrences(of: "AX", with: "").lowercased()) \"\(displayName.prefix(120))\" [ref=e\(refCounter)]")
            }

            if let children = axChildrenAttribute(kAXChildrenAttribute, from: element) {
                for child in children.prefix(50) {
                    collectCompact(from: child, depth: shouldSkip ? depth : depth + 1)
                    if refCounter >= limit { break }
                }
            }
        }

        if let windows = axChildrenAttribute(kAXWindowsAttribute, from: appElement), !windows.isEmpty {
            for window in windows.prefix(2) {
                collectCompact(from: window, depth: 0)
                if refCounter >= limit { break }
            }
        } else {
            collectCompact(from: appElement, depth: 0)
        }

        return lines.isEmpty ? "(无可交互元素)" : lines.joined(separator: "\n")
    }

    private func focusedElementWithFallback() -> AXUIElement? {
        if let element = focusedElement() {
            let role = stringAttribute(kAXRoleAttribute, from: element) ?? ""
            let value = stringAttribute(kAXValueAttribute, from: element) ?? ""
            if role == "AXTextArea" || role == "AXTextField" || !value.isEmpty {
                return element
            }
        }
        guard let app = focusedAppElement() else { return nil }
        var window: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &window)
        if let window, CFGetTypeID(window) == AXUIElementGetTypeID(),
           let editable = firstEditableElement(in: unsafeDowncast(window, to: AXUIElement.self), depth: 0) {
            return editable
        }
        return firstEditableElement(in: app, depth: 0)
    }

    private func focusedElement() -> AXUIElement? {
        var value: CFTypeRef?
        let systemWide = AXUIElementCreateSystemWide()
        let result = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &value)
        guard result == .success, let value else { return nil }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func focusedAppElement() -> AXUIElement? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        return AXUIElementCreateApplication(pid)
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private func pressShortcut(keyCode: CGKeyCode, flags: CGEventFlags, toPid pid: pid_t? = nil) throws {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else {
            throw AccessibilityContextError.actionFailed("keyboard event")
        }
        down.flags = flags
        up.flags = flags
        if let targetPid = pid {
            if !SkyLightEventPost.postToPid(targetPid, event: down) {
                down.postToPid(targetPid)
            }
            usleep(10_000)
            if !SkyLightEventPost.postToPid(targetPid, event: up) {
                up.postToPid(targetPid)
            }
        } else {
            let expectedBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            try verifyTargetApp(expectedBundleID: expectedBundleID)
            down.post(tap: .cghidEventTap)
            usleep(10_000)
            up.post(tap: .cghidEventTap)
        }
    }

    private func keyCode(for key: String) throws -> CGKeyCode {
        let map: [String: CGKeyCode] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
            "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19,
            "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28,
            "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "return": 36,
            "l": 37, "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45,
            "m": 46, ".": 47, "tab": 48, "space": 49, "`": 50, "delete": 51, "escape": 53,
            "left": 123, "right": 124, "down": 125, "up": 126
        ]
        guard let code = map[key.lowercased()] else {
            throw AccessibilityContextError.unsupportedKey(key)
        }
        return code
    }
}

public enum AccessibilityContextError: Error, LocalizedError, Sendable {
    case notAuthorized
    case elementNotFound
    case unsupportedKey(String)
    case actionFailed(String)
    case appChanged(expected: String, current: String)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            AccessibilityPermissionGuide.message
        case .elementNotFound:
            "没有找到可操作的光标或控件。请先把光标放到要输入的位置。"
        case .unsupportedKey(let key):
            "暂不支持这个快捷键：\(key)。"
        case .actionFailed(let action):
            "执行动作失败：\(action)。请确认当前 App 支持该操作。"
        case .appChanged(let expected, let current):
            "目标 App 已切换：期望 \(expected)，当前 \(current)。已取消操作以避免输入到错误位置。"
        }
    }
}
