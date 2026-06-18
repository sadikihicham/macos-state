import Foundation

/// Fonctions pures partagées par les samplers — testables sans matériel.
public enum Metrics {

    /// Pourcentage [0...1] borné, robuste aux entrées invalides
    /// (total nul/négatif → 0, used > total → 1).
    public static func fraction(used: Double, total: Double) -> Double {
        guard total > 0, used > 0 else { return 0 }
        return min(1.0, used / total)
    }

    /// Variation positive entre deux compteurs cumulés monotones
    /// (octets réseau, ticks CPU…). Gère le reset/overflow → 0.
    public static func delta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        current >= previous ? current - previous : 0
    }

    /// Débit (unités/seconde) à partir d'un delta sur un intervalle.
    /// Intervalle ≤ 0 → 0 (évite la division par zéro).
    public static func rate(delta: UInt64, seconds: Double) -> Double {
        guard seconds > 0 else { return 0 }
        return Double(delta) / seconds
    }
}
