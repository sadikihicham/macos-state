import AppKit
import Combine
import SwiftUI
import SystemMetrics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private var panel: DesktopPanel?
    private var engine: MetricsEngine?
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let engine = MetricsEngine(settings: settings)
        let panel = DesktopPanel(settings: settings)
        let host = NSHostingView(rootView: HUDView(
            engine: engine,
            onResize: { [weak panel] size in panel?.resizeKeepingTopLeft(to: size) },
            onKillRequest: { [weak self] proc in self?.confirmKill(proc) }
        ))
        panel.present(content: host, menu: buildMenu())
        engine.start()
        setupStatusItem()
        self.engine = engine
        self.panel = panel

        // Lecture live en barre de menu : suit chaque snapshot publié.
        engine.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] s in self?.updateStatusReadout(s) }
            .store(in: &cancellables)
    }

    // MARK: - Icône barre de menu (à côté de l'horloge)

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = gaugeImage()
        item.button?.toolTip = "macOS State"
        item.menu = buildMenu()
        self.statusItem = item
    }

    private func gaugeImage() -> NSImage? {
        let img = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent",
                          accessibilityDescription: "macOS State")
        img?.isTemplate = true                     // s'adapte clair/sombre de la barre
        return img
    }

    /// Met à jour le texte (+ mini-sparkline) à côté de l'icône de la barre de menu.
    private func updateStatusReadout(_ s: MetricsSnapshot) {
        guard let button = statusItem?.button else { return }
        let metric = settings.menubarMetric
        guard metric != "off" else {
            button.image = gaugeImage(); button.imagePosition = .imageOnly; button.title = ""
            return
        }
        let text: String, history: [Double]
        switch metric {
        case "ram":  text = "\(Int((s.memory * 100).rounded()))%"; history = s.ramHistory
        case "temp": text = s.cpuTempC.map { "\(Int($0.rounded()))°" } ?? "—"; history = s.tempHistory
        default:     text = "\(Int((s.cpu * 100).rounded()))%"; history = s.cpuHistory
        }
        button.image = sparklineImage(history) ?? gaugeImage()
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        button.title = " " + text
    }

    /// Mini-sparkline monochrome (template → s'adapte clair/sombre) de l'historique.
    private func sparklineImage(_ values: [Double]) -> NSImage? {
        guard values.count > 1 else { return nil }
        let size = NSSize(width: 22, height: 12)
        let img = NSImage(size: size)
        img.lockFocus()
        let path = NSBezierPath()
        path.lineWidth = 1
        let step = size.width / CGFloat(values.count - 1)
        for (i, v) in values.enumerated() {
            let pt = NSPoint(x: CGFloat(i) * step,
                             y: 1 + (size.height - 2) * CGFloat(min(1, max(0, v))))
            if i == 0 { path.move(to: pt) } else { path.line(to: pt) }
        }
        NSColor.black.setStroke()
        path.stroke()
        img.unlockFocus()
        img.isTemplate = true
        return img
    }

    /// Menu partagé (barre de menu + clic droit HUD). Deux instances distinctes.
    /// Raccourci de localisation pour les chaînes AppKit (langue courante).
    private func t(_ s: String) -> String { L.t(s, L.lang) }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let toggleHUD = NSMenuItem(title: t("Masquer le HUD"),
                                   action: #selector(toggleHUDVisibility(_:)), keyEquivalent: "")
        toggleHUD.target = self
        menu.addItem(toggleHUD)

        let onTop = NSMenuItem(title: t("Toujours au-dessus"),
                               action: #selector(toggleFloatOnTop(_:)), keyEquivalent: "")
        onTop.target = self
        menu.addItem(onTop)

        // Sous-menu Intervalle.
        let intervalItem = NSMenuItem(title: t("Intervalle"), action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for v in Settings.intervalChoices {
            let it = NSMenuItem(title: "\(Int(v)) s", action: #selector(setInterval(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = v
            intervalMenu.addItem(it)
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)

        // Sous-menu Métriques.
        let metricsItem = NSMenuItem(title: t("Métriques"), action: nil, keyEquivalent: "")
        let metricsMenu = NSMenu()
        let labels = ["cpu": "CPU", "ram": "Mémoire", "disk": "Disque", "net": "Réseau",
                      "battery": "Batterie", "thermal": "Thermique (temp. + ventilo)"]
        for key in Settings.metricKeys {
            let it = NSMenuItem(title: t(labels[key] ?? key), action: #selector(toggleMetric(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = key
            metricsMenu.addItem(it)
        }
        metricsItem.submenu = metricsMenu
        menu.addItem(metricsItem)

        // Sous-menu Langue.
        let langItem = NSMenuItem(title: t("Langue"), action: nil, keyEquivalent: "")
        let langMenu = NSMenu()
        for code in L.supported {
            let it = NSMenuItem(title: L.name(code), action: #selector(setLanguage(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = code
            langMenu.addItem(it)
        }
        langItem.submenu = langMenu
        menu.addItem(langItem)

        // Sous-menu Barre de menu (métrique live affichée à côté de l'icône).
        let mbItem = NSMenuItem(title: t("Barre de menu"), action: nil, keyEquivalent: "")
        let mbMenu = NSMenu()
        let mbLabels = ["off": "Désactivée", "cpu": "CPU", "ram": "Mémoire", "temp": "Température"]
        for code in Settings.menubarChoices {
            let it = NSMenuItem(title: t(mbLabels[code] ?? code),
                                action: #selector(setMenubarMetric(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = code
            mbMenu.addItem(it)
        }
        mbItem.submenu = mbMenu
        menu.addItem(mbItem)

        let login = NSMenuItem(title: t("Lancer au login"),
                               action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        login.target = self
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: t("Quitter macOS State"),
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.userInterfaceLayoutDirection = L.isRTL(L.lang) ? .rightToLeft : .leftToRight
        return menu
    }

    @objc private func setMenubarMetric(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        settings.menubarMetric = code
        if let s = engine?.snapshot { updateStatusReadout(s) }   // mise à jour immédiate
    }

    @objc private func setLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        L.setLang(code)
        rebuildMenus()      // l'UI SwiftUI se met à jour via @AppStorage("app.lang")
    }

    /// Reconstruit les menus (barre de menu + clic droit) avec la nouvelle langue.
    private func rebuildMenus() {
        statusItem?.menu = buildMenu()
        panel?.contentView?.menu = buildMenu()
    }

    @objc private func toggleHUDVisibility(_ sender: NSMenuItem) {
        guard let panel else { return }
        if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        guard let v = sender.representedObject as? Double else { return }
        engine?.setRefreshInterval(v)
    }

    @objc private func toggleMetric(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        settings.setMetricVisible(key, !settings.isMetricVisible(key))
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
    }

    /// Met à jour dynamiquement titres/états des items de menu à l'ouverture.
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleHUDVisibility(_:)):
            menuItem.title = (panel?.isVisible == true) ? t("Masquer le HUD") : t("Afficher le HUD")
        case #selector(setLanguage(_:)):
            menuItem.state = (menuItem.representedObject as? String == L.lang) ? .on : .off
        case #selector(setMenubarMetric(_:)):
            menuItem.state = (menuItem.representedObject as? String == settings.menubarMetric) ? .on : .off
        case #selector(toggleFloatOnTop(_:)):
            menuItem.state = settings.floatOnTop ? .on : .off
        case #selector(setInterval(_:)):
            let v = menuItem.representedObject as? Double
            menuItem.state = (v == settings.refreshInterval) ? .on : .off
        case #selector(toggleMetric(_:)):
            if let key = menuItem.representedObject as? String {
                menuItem.state = settings.isMetricVisible(key) ? .on : .off
            }
        case #selector(toggleLaunchAtLogin(_:)):
            menuItem.state = LaunchAtLogin.isEnabled ? .on : .off
        default:
            break
        }
        return true
    }

    // MARK: - Kill avec confirmation (human-in-the-loop sur action irréversible)

    private func confirmKill(_ p: ProcSample) {
        guard let engine, let panel else { return }
        let decision = engine.processController.decide(p)
        if case .denied(let reason) = decision {
            present(title: t("Action impossible"), text: reason, style: .warning)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = L.fmt("Tuer « %@ » (PID %@) ?", p.name, "\(p.pid)")
        var info = t("Le process recevra SIGTERM, puis SIGKILL s'il ne répond pas.")
        if case .allowedWithWarning(let w) = decision { info = w + "\n\n" + info }
        alert.informativeText = info
        alert.addButton(withTitle: t("Tuer"))     // .alertFirstButtonReturn
        alert.addButton(withTitle: t("Annuler"))

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
            present(title: t("Refusé"), text: r, style: .warning)
        case .staleIdentity:
            present(title: t("Process changé"),
                    text: L.fmt("Le PID %@ ne correspond plus à « %@ » (réutilisé). Aucun kill effectué.", "\(p.pid)", p.name),
                    style: .informational)
        case .failed(let e):
            present(title: t("Échec"), text: L.fmt("Impossible de tuer « %@ » : %@", p.name, e), style: .critical)
        }
    }

    private func present(title: String, text: String, style: NSAlert.Style) {
        let a = NSAlert()
        a.alertStyle = style
        a.messageText = title
        a.informativeText = text
        a.addButton(withTitle: t("OK"))
        if let panel { NSApp.activate(ignoringOtherApps: true); a.beginSheetModal(for: panel, completionHandler: nil) }
        else { a.runModal() }
    }

    // Réafficher le HUD si l'app est relancée alors qu'elle tourne déjà.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        panel?.orderFrontRegardless()
        return true
    }

    @objc private func toggleFloatOnTop(_ sender: NSMenuItem) {
        settings.floatOnTop.toggle()
        sender.state = settings.floatOnTop ? .on : .off
        panel?.level = settings.floatOnTop
            ? .floating
            : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
    }
}

// Conformance explicite : garantit que validateMenuItem(_:) est bien appelé pour
// l'état/les titres dynamiques des items (sinon dépendance au comportement informel).
extension AppDelegate: NSMenuItemValidation {}
