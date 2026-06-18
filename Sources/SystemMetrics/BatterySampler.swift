import Foundation
import IOKit
import IOKit.ps

/// État batterie. nil retourné par le sampler si la machine n'a pas de batterie.
public struct BatteryInfo: Equatable {
    public let percent: Int
    public let isCharging: Bool
    public let isPluggedIn: Bool
    /// Minutes restantes (décharge) ou jusqu'à pleine charge ; -1 si inconnu/calcul.
    public let minutesRemaining: Int
    // Détails (mode développé) — nil si indisponible.
    public let cycleCount: Int?
    public let healthPercent: Int?
    public let condition: String?
    public init(percent: Int, isCharging: Bool, isPluggedIn: Bool, minutesRemaining: Int,
                cycleCount: Int? = nil, healthPercent: Int? = nil, condition: String? = nil) {
        self.percent = percent; self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn; self.minutesRemaining = minutesRemaining
        self.cycleCount = cycleCount; self.healthPercent = healthPercent
        self.condition = condition
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

            let condition = desc["BatteryHealth"] as? String
            let detail = Self.readRegistryDetail()

            return BatteryInfo(
                percent: percent,
                isCharging: isCharging,
                isPluggedIn: pluggedIn,
                minutesRemaining: raw,
                cycleCount: detail.cycles,
                healthPercent: detail.health,
                condition: condition
            )
        }
        return nil // pas de batterie interne (Mac de bureau)
    }

    /// Cycles + santé (% capacité max / capacité de conception) via IORegistry
    /// `AppleSmartBattery`. Best-effort : nil si indisponible.
    private static func readRegistryDetail() -> (cycles: Int?, health: Int?) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return (nil, nil) }
        defer { IOObjectRelease(service) }

        func intProp(_ key: String) -> Int? {
            guard let cf = IORegistryEntryCreateCFProperty(
                service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            else { return nil }
            return (cf as? Int) ?? (cf as? NSNumber)?.intValue
        }

        let cycles = intProp("CycleCount")
        let design = intProp("DesignCapacity")
        let maxCap = intProp("AppleRawMaxCapacity") ?? intProp("MaxCapacity")
        var health: Int? = nil
        if let d = design, d > 0, let m = maxCap {
            health = min(100, Int((Double(m) / Double(d) * 100).rounded()))
        }
        return (cycles, health)
    }
}
