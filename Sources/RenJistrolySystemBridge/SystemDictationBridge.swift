import AppKit

public actor SystemDictationBridge {
    public init() {}

    public func triggerDictationShortcut() throws {
        // macOS Dictation commonly uses a double press of the Fn/Globe key.
        try postFunctionKeyTap()
        usleep(90_000)
        try postFunctionKeyTap()
    }

    public func stopDictationShortcut() throws {
        try postFunctionKeyTap()
    }

    private func postFunctionKeyTap() throws {
        let keyCode = CGKeyCode(63)
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else {
            throw SystemDictationError.eventCreationFailed
        }
        down.flags = .maskSecondaryFn
        up.flags = .maskSecondaryFn
        down.post(tap: .cghidEventTap)
        usleep(25_000)
        up.post(tap: .cghidEventTap)
    }
}

public enum SystemDictationError: LocalizedError, Sendable {
    case eventCreationFailed

    public var errorDescription: String? {
        switch self {
        case .eventCreationFailed:
            return "无法创建系统听写快捷键事件"
        }
    }
}
