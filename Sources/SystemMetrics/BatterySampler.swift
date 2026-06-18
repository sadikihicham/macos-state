import Foundation
import IOKit.ps

/// État batterie. nil retourné par le sampler si la machine n'a pas de batterie.
public struct BatteryInfo: Equatable {
    public let percent: Int
    public let isCharging: Bool
    public let isPluggedIn: Bool
    /// Minutes restantes (décharge) ou jusqu'à pleine charge ; -1 si inconnu/calcul.
    public let minutesRemaining: Int
    public init(percent: Int, isCharging: Bool, isPluggedIn: Bool, minutesRemaining: Int) {
        self.percent = percent; self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn; self.minutesRemaining = minutesRemaining
    }
}

/// Lit l'état batterie via IOKit Power Sources.
public final class BatterySampler {
    public init() {}

    public func read() -> BatteryInfo? {
        guard let snap = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snap)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in list {
            guard let desc = IOPSGetPowerSourceDescription(snap, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            guard let type = desc[kIOPSTypeKey] as? String,
                  type == kIOPSInternalBatteryType else { continue }

            let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maxCap = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let percent = maxCap > 0 ? Int((Double(current) / Double(maxCap) * 100).rounded()) : current

            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let pluggedIn = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue

            // Temps restant : -1 = calcul en cours / illimité (branché, non chargé).
            let raw = isCharging
                ? (desc[kIOPSTimeToFullChargeKey] as? Int ?? -1)
                : (desc[kIOPSTimeToEmptyKey] as? Int ?? -1)

            return BatteryInfo(
                percent: percent,
                isCharging: isCharging,
                isPluggedIn: pluggedIn,
                minutesRemaining: raw
            )
        }
        return nil // pas de batterie interne (Mac de bureau)
    }
}
