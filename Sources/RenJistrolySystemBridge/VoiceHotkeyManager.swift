import AppKit
import Carbon
import Foundation
import RenJistrolyModels

@MainActor
public final class HotkeyManager {
    public typealias Handler = @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var handler: Handler?

    public init() {}

    @discardableResult
    public func register(_ preset: HotkeyPreset = .controlOptionSpace, handler: @escaping Handler) -> Bool {
        unregister()
        self.handler = handler

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in manager.handler?() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)

        let signature = OSType(UInt32(truncatingIfNeeded: 0x4D564131))
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            modifierFlags(for: preset),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if registerStatus != noErr {
            hotKeyRef = nil
            return false
        }
        return true
    }

    public func registerCommandSpace(handler: @escaping Handler) {
        register(.controlOptionSpace, handler: handler)
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func modifierFlags(for preset: HotkeyPreset) -> UInt32 {
        switch preset {
        case .controlOptionSpace:
            UInt32(controlKey | optionKey)
        case .optionCommandSpace:
            UInt32(cmdKey | optionKey)
        case .commandShiftSpace:
            UInt32(cmdKey | shiftKey)
        case .controlSpace:
            UInt32(controlKey)
        case .optionSpace:
            UInt32(optionKey)
        }
    }
}
