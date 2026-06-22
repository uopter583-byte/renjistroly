import AppKit
import ApplicationServices
import Foundation
import os

// MARK: - FocusState

public struct FocusState: Sendable {
    fileprivate let pid: pid_t
    fileprivate let window: AXUIElement?
    fileprivate let element: AXUIElement?
    fileprivate let priorWindowFocused: Bool?
    fileprivate let priorWindowMain: Bool?
    fileprivate let priorElementFocused: Bool?
}

// MARK: - SuppressionHandle

public struct SuppressionHandle: Sendable, Hashable {
    fileprivate let id: UUID
    fileprivate init() { self.id = UUID() }
}

// MARK: - FocusGuard

/// Three-layer focus suppression for background AX actions.
///
/// 1. **AX enablement** — writes `AXManualAccessibility` / `AXEnhancedUserInterface`
///    on the target app root so Chromium/Electron builds its full AX tree.
/// 2. **Synthetic focus** — writes `AXFocused` / `AXMain` before the AX action
///    and restores originals after, so the target's AppKit state machine doesn't
///    trigger a reflexive `NSApp.activate(ignoringOtherApps:)`.
/// 3. **Reactive suppression** — subscribes to `NSWorkspace.didActivateApplicationNotification`
///    and immediately re-activates the prior frontmost app if the target self-activates.
public actor FocusGuard {

    /// Zero-delay demote: reactivation fires synchronously within the same
    /// run-loop turn as the activation notification, completing before
    /// WindowServer composites the next frame.
    private static let suppressionDelayNs: UInt64 = 0

    private var assertedPids: Set<pid_t> = []
    private var nonAssertablePids: Set<pid_t> = []
    private let dispatcher = SuppressionDispatcher(delayNs: suppressionDelayNs)

    public init() {}

    /// Run `body` with all three focus-suppression layers active for `pid`.
    /// Restores synthetic focus and disarms reactive suppression even if `body` throws.
    public func withFocusSuppressed<T: Sendable>(
        pid: pid_t,
        element: AXUIElement?,
        body: @Sendable () async throws -> T
    ) async throws -> T {
        // Layer 1 — AX enablement
        let root = AXUIElementCreateApplication(pid)
        assertAccessibilityEnablement(pid: pid, root: root)

        // Layer 2 — synthetic focus. Skip when window is minimized.
        let window = element.flatMap { enclosingWindow(of: $0) }
        let windowIsMinimized = window.flatMap { readBool($0, "AXMinimized") } ?? false
        let focusState: FocusState?
        if windowIsMinimized {
            focusState = nil
        } else {
            focusState = preventActivation(pid: pid, window: window, element: element)
        }

        // Layer 3 — reactive suppression
        let handle: SuppressionHandle?
        let targetApp = NSRunningApplication(processIdentifier: pid)
        let isTargetFrontmost = targetApp?.isActive ?? false
        if !isTargetFrontmost,
           let frontmost = NSWorkspace.shared.frontmostApplication {
            handle = await dispatcher.begin(targetPid: pid, restoreTo: frontmost)
        } else {
            handle = nil
        }

        do {
            let result = try await body()
            if let state = focusState { reenableActivation(state) }
            if let h = handle {
                try? await Task.sleep(nanoseconds: 50_000_000)
                await dispatcher.end(h)
            }
            return result
        } catch {
            if let state = focusState { reenableActivation(state) }
            if let h = handle { await dispatcher.end(h) }
            throw error
        }
    }

    // MARK: - Layer 1: AX enablement

    private func assertAccessibilityEnablement(pid: pid_t, root: AXUIElement) {
        if nonAssertablePids.contains(pid) { return }

        let manualResult = AXUIElementSetAttributeValue(
            root, "AXManualAccessibility" as CFString, kCFBooleanTrue
        )
        let enhancedResult = AXUIElementSetAttributeValue(
            root, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue
        )

        if manualResult != .success && enhancedResult != .success {
            if !assertedPids.contains(pid) { nonAssertablePids.insert(pid) }
            return
        }
        assertedPids.insert(pid)
    }

    // MARK: - Layer 2: Synthetic focus

    private func preventActivation(pid: pid_t, window: AXUIElement?, element: AXUIElement?) -> FocusState {
        let priorWindowFocused = window.flatMap { readBool($0, "AXFocused") }
        let priorWindowMain = window.flatMap { readBool($0, "AXMain") }
        let priorElementFocused = element.flatMap { readBool($0, "AXFocused") }

        if let window {
            writeBool(window, "AXFocused", true)
            writeBool(window, "AXMain", true)
        }
        if let element {
            writeBool(element, "AXFocused", true)
        }

        return FocusState(
            pid: pid, window: window, element: element,
            priorWindowFocused: priorWindowFocused,
            priorWindowMain: priorWindowMain,
            priorElementFocused: priorElementFocused
        )
    }

    private func reenableActivation(_ state: FocusState) {
        if let window = state.window {
            // Validate window still exists before restoring focus
            var unused: CFTypeRef?
            let isValid = AXUIElementCopyAttributeValue(window, kAXMainAttribute as CFString, &unused) == .success
            guard isValid else { return }
            if let prior = state.priorWindowFocused { writeBool(window, "AXFocused", prior) }
            if let prior = state.priorWindowMain { writeBool(window, "AXMain", prior) }
        }
        if let element = state.element, let prior = state.priorElementFocused {
            writeBool(element, "AXFocused", prior)
        }
    }

    // MARK: - Helpers

    private func readBool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let v = value else { return nil }
        if CFGetTypeID(v) == CFBooleanGetTypeID() {
            return CFBooleanGetValue(unsafeDowncast(v as AnyObject, to: CFBoolean.self))
        }
        return nil
    }

    private func writeBool(_ element: AXUIElement, _ attribute: String, _ value: Bool) {
        _ = AXUIElementSetAttributeValue(
            element, attribute as CFString,
            (value ? kCFBooleanTrue : kCFBooleanFalse) as CFTypeRef
        )
    }

    private func enclosingWindow(of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, "AXWindow" as CFString, &value)
        guard result == .success, let raw = value else { return nil }
        guard CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(raw as AnyObject, to: AXUIElement.self)
    }
}

// MARK: - SuppressionDispatcher (actor)

private actor SuppressionDispatcher {
    private struct Entry {
        let targetPid: pid_t
        let restoreTo: NSRunningApplication
    }

    private let delayNs: UInt64
    private var entries: [UUID: Entry] = [:]
    private var observer: NSObjectProtocol?

    init(delayNs: UInt64) {
        self.delayNs = delayNs
    }

    func begin(targetPid: pid_t, restoreTo: NSRunningApplication) -> SuppressionHandle {
        let handle = SuppressionHandle()
        entries[handle.id] = Entry(targetPid: targetPid, restoreTo: restoreTo)
        if observer == nil { installObserver() }
        return handle
    }

    func end(_ handle: SuppressionHandle) {
        entries.removeValue(forKey: handle.id)
        if entries.isEmpty, let token = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            observer = nil
        }
    }

    private func installObserver() {
        let token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            guard let pid else { return }
            Task { await self?.handleActivation(pid: pid) }
        }
        observer = token
    }

    private func handleActivation(pid activatedPid: pid_t) {
        let restoreCandidates = entries.values
            .filter { $0.targetPid == activatedPid }
            .map { $0.restoreTo }

        guard let restoreTo = restoreCandidates.first else { return }

        let restorePid = restoreTo.processIdentifier
        Task.detached {
            try? await Task.sleep(nanoseconds: self.delayNs)
            await MainActor.run {
                guard let app = NSRunningApplication(processIdentifier: restorePid) else { return }
                _ = app.activate(options: [])
            }
        }
    }
}
