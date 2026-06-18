import Foundation
import CoreGraphics

/// Préférences persistées (UserDefaults). V1 minimal : position + état HUD.
final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    private enum Key {
        static let originX = "hud.originX"
        static let originY = "hud.originY"
        static let hasOrigin = "hud.hasOrigin"
        static let expanded = "hud.expanded"
        static let interval = "hud.refreshInterval"
        static let floatOnTop = "hud.floatOnTop"
    }

    /// Dernière position connue du HUD (nil si jamais déplacé).
    var hudOrigin: CGPoint? {
        get {
            guard d.bool(forKey: Key.hasOrigin) else { return nil }
            return CGPoint(x: d.double(forKey: Key.originX),
                           y: d.double(forKey: Key.originY))
        }
        set {
            if let p = newValue {
                d.set(p.x, forKey: Key.originX)
                d.set(p.y, forKey: Key.originY)
                d.set(true, forKey: Key.hasOrigin)
            } else {
                d.set(false, forKey: Key.hasOrigin)
            }
        }
    }

    var expanded: Bool {
        get { d.bool(forKey: Key.expanded) }
        set { d.set(newValue, forKey: Key.expanded) }
    }

    /// Intervalle de rafraîchissement (s). Plancher 1 s pour limiter le coût.
    var refreshInterval: Double {
        get { let v = d.double(forKey: Key.interval); return v <= 0 ? 2.0 : max(1.0, v) }
        set { d.set(max(1.0, newValue), forKey: Key.interval) }
    }

    /// HUD au-dessus des fenêtres (true) ou posé sur le bureau (false).
    var floatOnTop: Bool {
        get { d.object(forKey: Key.floatOnTop) == nil ? true : d.bool(forKey: Key.floatOnTop) }
        set { d.set(newValue, forKey: Key.floatOnTop) }
    }

    // Visibilité par métrique (défaut : toutes visibles).
    static let metricKeys = ["cpu", "ram", "disk", "net", "battery", "thermal"]
    func isMetricVisible(_ key: String) -> Bool {
        let k = "hud.show.\(key)"
        return d.object(forKey: k) == nil ? true : d.bool(forKey: k)
    }
    func setMetricVisible(_ key: String, _ on: Bool) {
        d.set(on, forKey: "hud.show.\(key)")
    }

    /// Intervalles proposés dans le menu.
    static let intervalChoices: [Double] = [1, 2, 5]

    /// Métrique affichée en texte (+ sparkline) dans la barre de menu.
    var menubarMetric: String {
        get { d.string(forKey: "menubar.metric") ?? "cpu" }
        set { d.set(newValue, forKey: "menubar.metric") }
    }
    static let menubarChoices = ["off", "cpu", "ram", "temp"]

    /// Alertes de seuil (notification locale). Désactivées par défaut.
    var alertsEnabled: Bool {
        get { d.bool(forKey: "alerts.enabled") }
        set { d.set(newValue, forKey: "alerts.enabled") }
    }

    /// Facteur d'agrandissement du HUD (texte + jauges). 1.0 par défaut.
    var uiScale: Double {
        get { let v = d.double(forKey: "hud.scale"); return v > 0 ? v : 1.0 }
        set { d.set(newValue, forKey: "hud.scale") }
    }
    /// Tailles proposées : Normal / Grand / Très grand.
    static let scaleChoices: [Double] = [1.0, 1.25, 1.5]
}
