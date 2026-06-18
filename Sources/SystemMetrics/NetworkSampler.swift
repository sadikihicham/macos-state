import Darwin
import Foundation

/// Débit réseau agrégé (↓/↑ octets/s) calculé par différence de compteurs
/// `if_data` entre deux lectures, sur les interfaces actives (hors loopback).
public final class NetworkSampler {
    private var lastRx: UInt64 = 0
    private var lastTx: UInt64 = 0
    private var lastTime: DispatchTime?
    public init() {}

    /// Débits instantanés (down, up) en octets/seconde. (0,0) au 1er appel.
    public func rates() -> (down: Double, up: Double) {
        let (rx, tx) = Self.readCounters()
        let now = DispatchTime.now()
        defer { lastRx = rx; lastTx = tx; lastTime = now }

        guard let last = lastTime else { return (0, 0) }
        let seconds = Double(now.uptimeNanoseconds - last.uptimeNanoseconds) / 1_000_000_000
        let down = Metrics.rate(delta: Metrics.delta(rx, lastRx), seconds: seconds)
        let up = Metrics.rate(delta: Metrics.delta(tx, lastTx), seconds: seconds)
        return (down, up)
    }

    /// Somme des octets reçus/émis sur les interfaces physiques actives.
    static func readCounters() -> (rx: UInt64, tx: UInt64) {
        var rx: UInt64 = 0, tx: UInt64 = 0
        for (_, c) in readPerInterface() { rx &+= c.rx; tx &+= c.tx }
        return (rx, tx)
    }

    /// Compteurs cumulés par interface (hors loopback).
    static func readPerInterface() -> [String: (rx: UInt64, tx: UInt64)] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { return [:] }
        defer { freeifaddrs(head) }

        var out: [String: (rx: UInt64, tx: UInt64)] = [:]
        var ptr = head
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let addr = cur.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: cur.pointee.ifa_name)
            if name == "lo0" { continue } // exclut loopback
            guard let raw = cur.pointee.ifa_data else { continue }
            let data = raw.assumingMemoryBound(to: if_data.self).pointee
            out[name] = (UInt64(data.ifi_ibytes), UInt64(data.ifi_obytes))
        }
        return out
    }

    // MARK: - Par interface (mode développé)

    private var perIface: [String: (rx: UInt64, tx: UInt64, t: DispatchTime)] = [:]

    /// Débits (down, up) par interface active, triés par activité décroissante.
    public func interfaceRates() -> [(name: String, down: Double, up: Double)] {
        let now = DispatchTime.now()
        let counters = Self.readPerInterface()
        var result: [(name: String, down: Double, up: Double)] = []

        for (name, c) in counters {
            defer { perIface[name] = (c.rx, c.tx, now) }
            guard let prev = perIface[name] else { continue }
            let seconds = Double(now.uptimeNanoseconds - prev.t.uptimeNanoseconds) / 1_000_000_000
            let down = Metrics.rate(delta: Metrics.delta(c.rx, prev.rx), seconds: seconds)
            let up = Metrics.rate(delta: Metrics.delta(c.tx, prev.tx), seconds: seconds)
            if down > 0 || up > 0 { result.append((name, down, up)) }
        }
        // Purge des interfaces disparues.
        perIface = perIface.filter { counters.keys.contains($0.key) }
        return result.sorted { ($0.down + $0.up) > ($1.down + $1.up) }
    }
}
