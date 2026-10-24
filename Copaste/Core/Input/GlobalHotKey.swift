import Carbon.HIToolbox

/// A system-wide keyboard shortcut (works while another app is in front), via Carbon's hot key API,
/// which needs no Accessibility permission.
final class GlobalHotKey {
    /// Carbon calls back through a C function, which can't capture context; the actions live here, by hot key ID.
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var handler: EventHandlerRef?
    private let id: UInt32
    private var hotKey: EventHotKeyRef?

    /// - Parameters:
    ///   - keyCode: a virtual key code, e.g. `kVK_ANSI_V`.
    ///   - modifiers: Carbon modifier flags, e.g. `cmdKey | shiftKey`.
    init(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        id = Self.nextID
        Self.nextID += 1
        Self.actions[id] = action
        Self.installHandler()
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKey)
    }

    func unregister() {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        Self.actions[id] = nil
    }

    private static func installHandler() {
        guard handler == nil else { return }
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            let id = hotKeyID.id
            DispatchQueue.main.async { MainActor.assumeIsolated { GlobalHotKey.actions[id]?() } }
            return noErr
        }, 1, &pressed, nil, &handler)
    }

    /// "CPST", identifying Copaste's hot keys to Carbon.
    private static let signature: OSType = 0x4350_5354
}
