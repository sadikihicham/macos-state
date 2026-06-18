import AppKit

// App "accessory" : pas d'icône Dock, HUD bureau uniquement (cf. LSUIElement).
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
