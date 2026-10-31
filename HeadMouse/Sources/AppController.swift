import Cocoa
import ApplicationServices
import SwiftUI
import Carbon.HIToolbox

/// Menü öğesi + kapanış (closure) eylemi
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, checked: Bool = false, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        self.target = self
        self.state = checked ? .on : .off
    }

    required init(coder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    @objc private func fire() { handler() }
}

final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let engine = HeadMouseEngine()
    private let settings = Settings.shared
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private var settingsWindow: NSWindow?

    // MARK: - Yaşam döngüsü

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu.delegate = self
        statusItem.menu = menu
        updateIcon(.noAirPods)

        engine.onStatusChange = { [weak self] st in self?.updateIcon(st) }
        engine.start()
        registerHotKeys()

        if !AXIsProcessTrusted() { SystemPanes.requestAccessibility() }
        if !settings.firstRunDone {
            settings.firstRunDone = true
            DispatchQueue.main.async { [weak self] in self?.showSettings() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }

    /// Dock ikonuna tıklanınca ya da uygulama tekrar açılınca ayarlar penceresini göster.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    // MARK: - Ayarlar penceresi

    func showSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsRootView(engine: engine))
            let w = NSWindow(contentViewController: host)
            w.title = "HeadMouse"
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.setContentSize(NSSize(width: 860, height: 640))
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            settingsWindow = w
        }
        // Pencere açıkken Dock'ta ve ⌘Tab'da görünsün
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Ana menü (⌘Q, ⌘W için)

    private func buildMainMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        main.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "HeadMouse'tan çık",
                                   action: #selector(NSApplication.terminate(_:)),
                                   keyEquivalent: "q"))
        appItem.submenu = appMenu

        let winItem = NSMenuItem()
        main.addItem(winItem)
        let winMenu = NSMenu(title: "Pencere")
        winMenu.addItem(NSMenuItem(title: "Kapat",
                                   action: #selector(NSWindow.performClose(_:)),
                                   keyEquivalent: "w"))
        winItem.submenu = winMenu

        NSApp.mainMenu = main
    }

    // MARK: - Kısayollar

    private func registerHotKeys() {
        let mods = controlKey | optionKey
        HotKeys.register(id: 1, keyCode: kVK_ANSI_H, modifiers: mods) { [weak self] in
            self?.engine.toggleEnabled()
        }
        HotKeys.register(id: 2, keyCode: kVK_ANSI_C, modifiers: mods) { [weak self] in
            self?.engine.recenter()
        }
        HotKeys.register(id: 3, keyCode: kVK_ANSI_D, modifiers: mods) { [weak self] in
            self?.engine.toggleDwell()
        }
        HotKeys.register(id: 4, keyCode: kVK_ANSI_S, modifiers: mods) { [weak self] in
            self?.engine.toggleScrollMode()
        }
        HotKeys.register(id: 5, keyCode: kVK_ANSI_R, modifiers: mods) { [weak self] in
            self?.engine.setNext(.right)
        }
        HotKeys.register(id: 6, keyCode: kVK_ANSI_F, modifiers: mods) { [weak self] in
            self?.engine.setNext(.double)
        }
        HotKeys.register(id: 7, keyCode: kVK_ANSI_G, modifiers: mods) { [weak self] in
            self?.engine.setNext(.dragStart)
        }
        HotKeys.register(id: 8, keyCode: kVK_ANSI_Comma, modifiers: mods) { [weak self] in
            self?.showSettings()
        }
    }

    // MARK: - İkon / durum

    private func symbol(_ names: [String]) -> NSImage? {
        for n in names {
            if let img = NSImage(systemSymbolName: n, accessibilityDescription: "HeadMouse") {
                img.isTemplate = true
                return img
            }
        }
        return nil
    }

    private func updateIcon(_ st: EngineStatus) {
        guard let button = statusItem.button else { return }
        switch st {
        case .active, .mouseActive:
            button.image = symbol(["cursorarrow.motionlines", "cursorarrow"])
            button.appearsDisabled = false
        case .paused, .noAirPods, .appPaused:
            button.image = symbol(["cursorarrow.motionlines", "cursorarrow"])
            button.appearsDisabled = true
        case .needsMotionPermission, .needsAccessibility:
            button.image = symbol(["exclamationmark.triangle", "cursorarrow"])
            button.appearsDisabled = false
        }
        if button.image == nil { button.title = "HM" }
    }

    // MARK: - Menü (kısa; asıl ayarlar pencerede)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: "HeadMouse — " + engine.status.text,
                                action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(ClosureMenuItem(engine.enabled ? "Duraklat  (⌃⌥H)" : "Devam et  (⌃⌥H)") { [weak self] in
            self?.engine.toggleEnabled()
        })
        menu.addItem(ClosureMenuItem("Merkeze al  (⌃⌥C)") { [weak self] in
            self?.engine.recenter()
        })
        menu.addItem(ClosureMenuItem("Bekleyerek tıkla  (⌃⌥D)",
                                     checked: settings.dwellEnabled) { [weak self] in
            self?.engine.toggleDwell()
        })
        menu.addItem(ClosureMenuItem("Kaydırma modu  (⌃⌥S)",
                                     checked: LiveState.shared.scrollMode) { [weak self] in
            self?.engine.toggleScrollMode()
        })

        let nextMenu = NSMenu()
        for k in ClickKind.allCases {
            nextMenu.addItem(ClosureMenuItem(k.title, checked: LiveState.shared.pending == k) { [weak self] in
                self?.engine.setNext(k)
            })
        }
        let nextItem = NSMenuItem(title: "Sonraki bekleme tıklaması", action: nil, keyEquivalent: "")
        nextItem.submenu = nextMenu
        menu.addItem(nextItem)

        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("Ayarlar…  (⌃⌥,)") { [weak self] in
            self?.showSettings()
        })
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "HeadMouse'tan çık",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
    }
}
