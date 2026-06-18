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

    /// Usage CPU [0...1] entre deux échantillons de ticks.
    public static func cpuUsage(current: CPUSample, previous: CPUSample) -> Double {
        let busy = delta(current.user, previous.user)
            + delta(current.system, previous.system)
            + delta(current.nice, previous.nice)
        let idle = delta(current.idle, previous.idle)
        return fraction(used: Double(busy), total: Double(busy + idle))
    }

    // MARK: - Formatage (pur, testé)

    /// Taille lisible (B/KB/MB/GB/TB), base 1024.
    public static func formatBytes(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var v = max(0, bytes)
        var i = 0
        while v >= 1024 && i < units.count - 1 { v /= 1024; i += 1 }
        let digits = (i == 0) ? "%.0f" : "%.1f"
        return "\(String(format: digits, v)) \(units[i])"
    }

    /// Débit lisible "X/s".
    public static func formatRate(_ bytesPerSec: Double) -> String {
        formatBytes(bytesPerSec) + "/s"
    }

    /// Minutes → "h:mm" ; négatif/inconnu → "—".
    public static func formatMinutes(_ minutes: Int) -> String {
        guard minutes >= 0 else { return "—" }
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }
}
