import AppKit
import SwiftUI
import SystemMetrics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private var panel: DesktopPanel?
    private var engine: MetricsEngine?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let engine = MetricsEngine(settings: settings)
        let panel = DesktopPanel(settings: settings)
        let host = NSHostingView(rootView: HUDView(
            engine: engine,
            onResize: { [weak panel] size in panel?.resizeKeepingTopLeft(to: size) },
            onKillRequest: { [weak self] proc in self?.confirmKill(proc) }
        ))
        panel.present(content: host, menu: makeContextMenu())
        engine.start()
        setupStatusItem()
        self.engine = engine
        self.panel = panel
    }

    // MARK: - Icône barre de menu (à côté de l'horloge)

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let img = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent",
                              accessibilityDescription: "macOS State")
            img?.isTemplate = true                 // s'adapte clair/sombre de la barre
            button.image = img
            button.toolTip = "macOS State"
        }

        let menu = NSMenu()
        let toggleHUD = NSMenuItem(title: "Masquer le HUD",
                                   action: #selector(toggleHUDVisibility(_:)), keyEquivalent: "")
        toggleHUD.target = self
        menu.addItem(toggleHUD)

        let onTop = NSMenuItem(title: "Toujours au-dessus",
                               action: #selector(toggleFloatOnTop(_:)), keyEquivalent: "")
        onTop.target = self
        menu.addItem(onTop)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quitter macOS State",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        self.statusItem = item
    }

    @objc private func toggleHUDVisibility(_ sender: NSMenuItem) {
        guard let panel else { return }
        if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
    }

    /// Met à jour dynamiquement titres/états des items de menu à l'ouverture.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleHUDVisibility(_:)) {
            menuItem.title = (panel?.isVisible == true) ? "Masquer le HUD" : "Afficher le HUD"
        } else if menuItem.action == #selector(toggleFloatOnTop(_:)) {
            menuItem.state = settings.floatOnTop ? .on : .off
        }
        return true
    }

    // MARK: - Kill avec confirmation (human-in-the-loop sur action irréversible)

    private func confirmKill(_ p: ProcSample) {
        guard let engine, let panel else { return }
        let decision = engine.processController.decide(p)
        if case .denied(let reason) = decision {
            present(title: "Action impossible", text: reason, style: .warning)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Tuer « \(p.name) » (PID \(p.pid)) ?"
        var info = "Le process recevra SIGTERM, puis SIGKILL s'il ne répond pas."
        if case .allowedWithWarning(let w) = decision { info = w + "\n\n" + info }
        alert.informativeText = info
        alert.addButton(withTitle: "Tuer")     // .alertFirstButtonReturn
        alert.addButton(withTitle: "Annuler")

        NSApp.activate(ignoringOtherApps: true)
        alert.beginSheetModal(for: panel) { [weak self] resp in
            guard resp == .alertFirstButtonReturn else { return }
            let outcome = engine.performKill(p)
            self?.report(outcome, for: p)
        }
    }

    private func report(_ outcome: KillOutcome, for p: ProcSample) {
        switch outcome {
        case .terminated, .signalSent:
            break // succès : le process disparaît de la liste au prochain tick
        case .denied(let r):
            present(title: "Refusé", text: r, style: .warning)
        case .staleIdentity:
            present(title: "Process changé",
                    text: "Le PID \(p.pid) ne correspond plus à « \(p.name) » (réutilisé). Aucun kill effectué.",
                    style: .informational)
        case .failed(let e):
            present(title: "Échec", text: "Impossible de tuer « \(p.name) » : \(e)", style: .critical)
        }
    }

    private func present(title: String, text: String, style: NSAlert.Style) {
        let a = NSAlert()
        a.alertStyle = style
        a.messageText = title
        a.informativeText = text
        a.addButton(withTitle: "OK")
        if let panel { NSApp.activate(ignoringOtherApps: true); a.beginSheetModal(for: panel, completionHandler: nil) }
        else { a.runModal() }
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
