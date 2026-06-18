import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private var panel: DesktopPanel?
    private var engine: MetricsEngine?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let engine = MetricsEngine(settings: settings)
        let host = NSHostingView(rootView: HUDView(engine: engine))
        let panel = DesktopPanel(settings: settings)
        panel.present(content: host, menu: makeContextMenu())
        engine.start()
        self.engine = engine
        self.panel = panel
    }

    // Réafficher le HUD si l'app est relancée alors qu'elle tourne déjà.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        panel?.orderFrontRegardless()
        return true
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let onTop = NSMenuItem(
            title: "Toujours au-dessus",
            action: #selector(toggleFloatOnTop(_:)),
            keyEquivalent: ""
        )
        onTop.target = self
        onTop.state = settings.floatOnTop ? .on : .off
        menu.addItem(onTop)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quitter macOS State",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    @objc private func toggleFloatOnTop(_ sender: NSMenuItem) {
        settings.floatOnTop.toggle()
        sender.state = settings.floatOnTop ? .on : .off
        panel?.level = settings.floatOnTop
            ? .floating
            : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    }
}
