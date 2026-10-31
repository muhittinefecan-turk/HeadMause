import Cocoa
import Carbon.HIToolbox

/// Genel kısayollar. Carbon RegisterEventHotKey kullanılıyor: ek izin gerektirmez.
enum HotKeys {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var refs: [EventHotKeyRef?] = []
    private static var installed = false

    static func install() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) -> OSStatus in
            var hk = EventHotKeyID()
            GetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hk)
            let id = hk.id
            DispatchQueue.main.async { HotKeys.handlers[id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }

    static func register(id: UInt32, keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        install()
        handlers[id] = action
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x484D5345), id: id)
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hkID,
                            GetApplicationEventTarget(), 0, &ref)
        refs.append(ref)
    }
}
