import AppKit

/// Panneau flottant translucide, non-activant, déplaçable, posé sur le bureau.
/// Ne vole jamais le focus clavier (canBecomeKey = false) ; se déplace par
/// glisser sur le fond. Position persistée à chaque déplacement.
final class DesktopPanel: NSPanel {
    private let settings: Settings
    private var moveObserver: NSObjectProtocol?

    init(settings: Settings) {
        self.settings = settings
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 150),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = settings.floatOnTop
            ? .floating
            : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        // Coins arrondis nets sur le contenu translucide.
        contentView?.wantsLayer = true

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: self, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.settings.hudOrigin = self.frame.origin
        }
    }

    deinit {
        if let moveObserver { NotificationCenter.default.removeObserver(moveObserver) }
    }

    // Devient key pour rendre les contrôles (bouton "Tuer", confirmation)
    // cliquables, mais reste non-activant : ne change pas d'espace ni d'app au premier plan.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Redimensionne en gardant le bord supérieur-gauche fixe (HUD ancré en haut).
    func resizeKeepingTopLeft(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        var f = frame
        if abs(f.width - size.width) < 0.5 && abs(f.height - size.height) < 0.5 { return }
        let topY = f.maxY
        f.size = size
        f.origin.y = topY - size.height
        setFrame(f, display: true, animate: false)
        settings.hudOrigin = f.origin
    }

    /// Installe la vue SwiftUI hôte + le menu contextuel, puis affiche.
    func present(content view: NSView, menu: NSMenu) {
        view.menu = menu
        contentView = view
        positionInitially()
        orderFrontRegardless()
    }

    private func positionInitially() {
        if let saved = settings.hudOrigin {
            setFrameOrigin(saved)
            return
        }
        // Défaut : coin supérieur droit de l'écran principal, avec marge.
        if let screen = NSScreen.main {
            let v = screen.visibleFrame
            let margin: CGFloat = 24
            setFrameOrigin(CGPoint(
                x: v.maxX - frame.width - margin,
                y: v.maxY - frame.height - margin
            ))
        }
    }
}
