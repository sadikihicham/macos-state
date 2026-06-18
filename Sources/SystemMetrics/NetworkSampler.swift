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
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { return (0, 0) }
        defer { freeifaddrs(head) }

        var rx: UInt64 = 0, tx: UInt64 = 0
        var ptr = head
        while let cur = ptr {
            defer { ptr = cur.pointee.ifa_next }
            guard let addr = cur.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: cur.pointee.ifa_name)
            if name.hasPrefix("lo") { continue } // exclut loopback
            guard let raw = cur.pointee.ifa_data else { continue }
            let data = raw.assumingMemoryBound(to: if_data.self).pointee
            rx &+= UInt64(data.ifi_ibytes)
            tx &+= UInt64(data.ifi_obytes)
        }
        return (rx, tx)
    }
}
