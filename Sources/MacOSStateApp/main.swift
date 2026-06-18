import AppKit

// App "accessory" : pas d'icône Dock, HUD bureau uniquement (cf. LSUIElement).
// Le démarrage s'exécute sur le main actor (thread principal au lancement).
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
}
