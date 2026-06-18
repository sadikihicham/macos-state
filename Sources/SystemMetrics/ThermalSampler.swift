import Foundation
import CIOHID

/// Instantané thermique. Toutes les valeurs sont optionnelles : « best-effort »,
/// nil → « N/A » à l'affichage (capteur absent, ex. ventilateur sur un Air).
public struct ThermalSample: Equatable {
    public let cpuTempC: Double?
    public let fanRPM: Int?
    public let fanCount: Int
    public init(cpuTempC: Double?, fanRPM: Int?, fanCount: Int) {
        self.cpuTempC = cpuTempC; self.fanRPM = fanRPM; self.fanCount = fanCount
    }
}

/// Lit température (via IOHID, API privée) et ventilateur (via SMC, IOKit public).
/// ⚠️ Capteurs non documentés → non testables unitairement ; la couche pure
/// (sélection du token, parsing) est isolée et testée à part.
public final class ThermalSampler {
    public init() {}

    public func read() -> ThermalSample {
        let (rpm, count) = SMCFan.read()
        return ThermalSample(cpuTempC: cpuTemperature(), fanRPM: rpm, fanCount: count)
    }

    /// Tokens de nom de capteur essayés dans l'ordre pour approcher « température
    /// CPU/SoC » ; repli sur la moyenne de tous les capteurs si aucun ne matche.
    static let cpuTokens = ["PMU tdie", "SOC MTR", "PACC MTR", "ECPU", "PCPU", "CPU"]

    /// Température CPU approchée (°C), ou nil si aucun capteur exploitable.
    public func cpuTemperature() -> Double? {
        for token in Self.cpuTokens {
            let v = token.withCString { cihid_temperature_avg($0) }
            if v > 0 { return v }
        }
        let any = cihid_temperature_avg(nil)
        return any > 0 ? any : nil
    }

    /// Diagnostic : imprime sur stderr tous les capteurs de température détectés.
    public static func debugDumpSensors() {
        cihid_dump_temperatures()
    }
}
