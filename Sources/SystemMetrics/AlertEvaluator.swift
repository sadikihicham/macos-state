/// Alertes de seuil. Logique PURE et testée : décide quelles métriques sont
/// « au-dessus » du seuil et lesquelles viennent de le FRANCHIR (front montant)
/// — pour notifier une seule fois, pas à chaque tick. Hystérésis pour éviter le
/// clignotement autour du seuil.
public enum SystemAlert: String, CaseIterable, Equatable {
    case cpu, temperature, disk
}

public struct AlertThresholds: Equatable {
    public var cpu: Double      // fraction 0...1
    public var tempC: Double    // °C
    public var disk: Double     // fraction 0...1
    public init(cpu: Double, tempC: Double, disk: Double) {
        self.cpu = cpu; self.tempC = tempC; self.disk = disk
    }
    /// Seuils par défaut raisonnables : CPU 90 %, température 85 °C, disque 95 %.
    public static let defaults = AlertThresholds(cpu: 0.90, tempC: 85, disk: 0.95)
}

public enum AlertEvaluator {
    /// Largeur de l'hystérésis : on ne « repasse sous » qu'à 90 % du seuil.
    static let hysteresis = 0.90

    /// Renvoie l'ensemble des métriques au-dessus du seuil et celles qui viennent
    /// de le franchir (à notifier). `tempC` nil → la température n'est pas évaluée.
    public static func evaluate(cpu: Double, tempC: Double?, disk: Double,
                                thresholds t: AlertThresholds,
                                previouslyOver: Set<SystemAlert>)
        -> (over: Set<SystemAlert>, fired: Set<SystemAlert>) {
        var over: Set<SystemAlert> = []
        func check(_ a: SystemAlert, _ value: Double, _ limit: Double) {
            // Si déjà au-dessus, on n'en sort qu'en passant sous limit*hystérésis.
            let threshold = previouslyOver.contains(a) ? limit * hysteresis : limit
            if value >= threshold { over.insert(a) }
        }
        check(.cpu, cpu, t.cpu)
        if let temp = tempC { check(.temperature, temp, t.tempC) }
        check(.disk, disk, t.disk)
        return (over, fired: over.subtracting(previouslyOver))
    }
}
