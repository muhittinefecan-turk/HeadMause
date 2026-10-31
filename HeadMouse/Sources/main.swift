import Cocoa

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // Dock'ta görünmez, sadece menü çubuğu
let controller = AppController()
app.delegate = controller
app.run()
