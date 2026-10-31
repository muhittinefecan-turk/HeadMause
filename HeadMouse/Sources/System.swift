import Cocoa
import ApplicationServices

/// Bağlı ekranların birleşik sınırları (CG koordinatları: sol-üst başlangıç).
final class Displays {
    static let shared = Displays()
    private var rects: [CGRect] = []

    private init() {
        refresh()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else { return }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        rects = ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }

    /// AppKit (sol-alt başlangıç) dönüşümü için ana ekran yüksekliği.
    var primaryHeight: Double { Double(CGDisplayBounds(CGMainDisplayID()).height) }

    /// Noktayı en yakın ekranın içine sıkıştırır.
    func clamp(_ p: V2) -> V2 {
        if rects.isEmpty { return p }
        let cg = p.cg
        for r in rects where r.contains(cg) { return p }
        var best = p
        var bestD = Double.greatestFiniteMagnitude
        for r in rects {
            let q = V2(min(max(p.x, Double(r.minX)), Double(r.maxX) - 1),
                       min(max(p.y, Double(r.minY)), Double(r.maxY) - 1))
            let d = q.distance(to: p)
            if d < bestD { bestD = d; best = q }
        }
        return best
    }
}

/// Sistem fare olaylarını üretir. Tüm olaylar kendi işaretimizi taşır,
/// böylece MouseWatcher gerçek fare hareketini bizimkinden ayırabilir.
enum EventSynth {
    static let tag: Int64 = 0x48454144
    private static let source: CGEventSource? = CGEventSource(stateID: .hidSystemState)

    static func currentLocation() -> V2 {
        if let e = CGEvent(source: nil) { return V2(e.location) }
        return V2()
    }

    private static func post(_ e: CGEvent) {
        e.setIntegerValueField(.eventSourceUserData, value: tag)
        e.post(tap: .cghidEventTap)
    }

    static func move(to p: V2, dx: Double, dy: Double, dragging: Bool) {
        let type: CGEventType = dragging ? .leftMouseDragged : .mouseMoved
        guard let e = CGEvent(mouseEventSource: source, mouseType: type,
                              mouseCursorPosition: p.cg, mouseButton: .left) else { return }
        e.setIntegerValueField(.mouseEventDeltaX, value: Int64(dx.rounded()))
        e.setIntegerValueField(.mouseEventDeltaY, value: Int64(dy.rounded()))
        post(e)
    }

    static func click(at p: V2, right: Bool, count: Int) {
        let down: CGEventType = right ? .rightMouseDown : .leftMouseDown
        let up: CGEventType = right ? .rightMouseUp : .leftMouseUp
        let button: CGMouseButton = right ? .right : .left
        for t in [down, up] {
            guard let e = CGEvent(mouseEventSource: source, mouseType: t,
                                  mouseCursorPosition: p.cg, mouseButton: button) else { continue }
            e.setIntegerValueField(.mouseEventClickState, value: Int64(count))
            post(e)
        }
    }

    /// Klavye kısayolu gönderir (ör. ⌘[ geri).
    static func key(_ code: Int, flags: CGEventFlags) {
        for down in [true, false] {
            guard let e = CGEvent(keyboardEventSource: source,
                                  virtualKey: CGKeyCode(code),
                                  keyDown: down) else { continue }
            e.flags = flags
            post(e)
        }
    }

    /// Dikey kaydırma (piksel). Pozitif = yukarı kaydır.
    static func scroll(dy: Int32) {
        guard let e = CGEvent(scrollWheelEvent2Source: source, units: .pixel,
                              wheelCount: 1, wheel1: dy, wheel2: 0, wheel3: 0) else { return }
        post(e)
    }

    static func leftButton(down: Bool, at p: V2) {
        let t: CGEventType = down ? .leftMouseDown : .leftMouseUp
        guard let e = CGEvent(mouseEventSource: source, mouseType: t,
                              mouseCursorPosition: p.cg, mouseButton: .left) else { return }
        e.setIntegerValueField(.mouseEventClickState, value: 1)
        post(e)
    }
}

/// Gerçek (fiziksel) fare / trackpad kullanımını izler; kendi olaylarımızı yok sayar.
final class MouseWatcher {
    private(set) var lastExternal: TimeInterval = -100
    private var tap: CFMachPort?

    func startIfPossible() {
        guard tap == nil, AXIsProcessTrusted() else { return }
        let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged,
                                    .otherMouseDragged, .leftMouseDown, .rightMouseDown,
                                    .scrollWheel]
        var mask: CGEventMask = 0
        for t in types { mask |= CGEventMask(1) << CGEventMask(t.rawValue) }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        // .defaultTap (aktif) sadece Erişilebilirlik izni ister; Input Monitoring istemez.
        // Olayları hiç değiştirmeden geçiriyoruz.
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                        place: .headInsertEventTap,
                                        options: .defaultTap,
                                        eventsOfInterest: mask,
                                        callback: mouseTapCallback,
                                        userInfo: refcon) else { return }
        tap = t
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
    }

    func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return
        }
        let pid = event.getIntegerValueField(.eventSourceUnixProcessID)
        let tag = event.getIntegerValueField(.eventSourceUserData)
        if pid == Int64(getpid()) || tag == EventSynth.tag { return }
        lastExternal = ProcessInfo.processInfo.systemUptime
    }
}

private func mouseTapCallback(proxy: CGEventTapProxy,
                              type: CGEventType,
                              event: CGEvent,
                              refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if let refcon = refcon {
        let watcher = Unmanaged<MouseWatcher>.fromOpaque(refcon).takeUnretainedValue()
        watcher.handle(type: type, event: event)
    }
    return Unmanaged.passUnretained(event)
}

/// İzin istekleri ve Sistem Ayarları kısayolları.
enum SystemPanes {
    static func requestAccessibility() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    static func open(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// "Akıllı dwell": imlecin altındaki öğe tıklanabilir mi? (Erişilebilirlik API'si)
enum AXProbe {
    private static let system: AXUIElement = {
        let s = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(s, 0.25)
        return s
    }()

    private static let clickableRoles: Set<String> = [
        "AXButton", "AXLink", "AXCheckBox", "AXRadioButton", "AXPopUpButton",
        "AXMenuItem", "AXMenuBarItem", "AXMenuButton", "AXTab", "AXDisclosureTriangle",
        "AXComboBox", "AXTextField", "AXTextArea", "AXSearchField", "AXSlider",
        "AXCell", "AXRow", "AXSegmentedControl", "AXToolbarButton", "AXIncrementor",
    ]

    static func isClickable(at p: V2) -> Bool {
        var el: AXUIElement?
        let err = AXUIElementCopyElementAtPosition(system, Float(p.x), Float(p.y), &el)
        // Uygulama AX desteklemiyorsa (oyun, bazı Electron) engelleme.
        guard err == .success, let e = el else { return true }

        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(e, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String, clickableRoles.contains(role) {
            return true
        }
        var names: CFArray?
        if AXUIElementCopyActionNames(e, &names) == .success,
           let list = names as? [String], list.contains("AXPress") {
            return true
        }
        return false
    }
}
