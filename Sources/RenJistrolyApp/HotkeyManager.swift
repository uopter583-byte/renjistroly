import AppKit
import Carbon

@MainActor
final class HotkeyManager: @unchecked Sendable {
    static let shared = HotkeyManager()

    nonisolated(unsafe) private var _hotkeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var _handlerRef: EventHandlerRef?
    nonisolated(unsafe) private var _isRegistered: Bool = false

    init() {}

    func registerGlobalHotkey() {
        if isRegistered { return }

        // Default: Option + Space
        var gHotKeyEvent = EventHotKeyID()
        gHotKeyEvent.signature = OSType(0x524A53_54) // "RJST"
        gHotKeyEvent.id = UInt32(1)

        let modifierFlags: UInt32 = UInt32(optionKey)
        let keyCode: UInt32 = UInt32(kVK_Space)

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifierFlags,
            gHotKeyEvent,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr {
            _hotkeyRef = ref
            _isRegistered = true
            setupEventHandler()
        }
    }

    func unregisterGlobalHotkey() {
        guard let ref = _hotkeyRef else { return }
        UnregisterEventHotKey(ref)
        if let hRef = _handlerRef {
            RemoveEventHandler(hRef)
        }
        _hotkeyRef = nil
        _handlerRef = nil
        _isRegistered = false
    }

    private var isRegistered: Bool {
        _isRegistered
    }

    private func setupEventHandler() {
        var gHotKeyEvent = EventHotKeyID()
        gHotKeyEvent.signature = OSType(0x524A53_54) // "RJST"
        gHotKeyEvent.id = UInt32(1)

        var eventTypes = [
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: OSType(kEventHotKeyPressed)
            ),
            EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: OSType(kEventHotKeyReleased)
            ),
        ]

        let handler: EventHandlerUPP = { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if err == noErr,
               hotKeyID.signature == OSType(0x524A53_54),
               hotKeyID.id == 1 {
                let kind = GetEventKind(event)
                DispatchQueue.main.async {
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        if kind == OSType(kEventHotKeyPressed) {
                            appDelegate.beginPushToTalk()
                        } else if kind == OSType(kEventHotKeyReleased) {
                            appDelegate.endPushToTalk()
                        }
                    }
                }
            }
            return noErr
        }

        var installedHandlerRef: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            eventTypes.count,
            &eventTypes,
            nil,
            &installedHandlerRef
        )
        _handlerRef = installedHandlerRef
    }
}
