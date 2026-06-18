import Foundation
import Combine
import SystemMetrics

/// Débit réseau par interface (mode développé).
struct InterfaceRate: Identifiable {
    let id: String
    let down: Double
    let up: Double
}

/// Instantané présentable consommé par le HUD.
struct MetricsSnapshot {
    var cpu: Double = 0                 // 0...1
    var cpuCores: [Double] = []         // par cœur
    var memory: Double = 0
    var memoryUsedBytes: UInt64 = 0
    var memoryTotalBytes: UInt64 = 0
    var memActive: UInt64 = 0
    var memWired: UInt64 = 0
    var memCompressed: UInt64 = 0
    var memFree: UInt64 = 0
    var disk: Double = 0
    var diskUsedBytes: Int64 = 0
    var diskTotalBytes: Int64 = 0
    var diskFreeBytes: Int64 { max(0, diskTotalBytes - diskUsedBytes) }
    var netDown: Double = 0             // octets/s
    var netUp: Double = 0
    var interfaces: [InterfaceRate] = []
    var battery: BatteryInfo? = nil
    var hasBattery: Bool { battery != nil }
}

/// Pilote les samplers via un Timer et publie un snapshot pour SwiftUI.
@MainActor
final class MetricsEngine: ObservableObject {
    @Published private(set) var snapshot = MetricsSnapshot()

    private let cpu = CPUSampler()
    private let mem = MemorySampler()
    private let disk = DiskSampler()
    private let net = NetworkSampler()
    private let battery = BatterySampler()

    private let settings: Settings
    private var timer: Timer?

    init(settings: Settings) { self.settings = settings }

    func start() {
        tick()
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Re-planifie le timer (ex. après changement d'intervalle en Slice 4).
    func scheduleTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        var s = snapshot
        if let u = cpu.usage() { s.cpu = u }
        let cores = cpu.perCoreUsage()
        if !cores.isEmpty { s.cpuCores = cores }
        if let m = mem.read() {
            s.memory = m.fraction
            s.memoryUsedBytes = m.usedBytes
            s.memoryTotalBytes = m.totalBytes
            s.memActive = m.activeBytes
            s.memWired = m.wiredBytes
            s.memCompressed = m.compressedBytes
            s.memFree = m.freeBytes
        }
        if let d = disk.read() {
            s.disk = d.fraction
            s.diskUsedBytes = d.usedBytes
            s.diskTotalBytes = d.totalBytes
        }
        let r = net.rates()
        s.netDown = r.down
        s.netUp = r.up
        s.interfaces = net.interfaceRates().map { InterfaceRate(id: $0.name, down: $0.down, up: $0.up) }
        s.battery = battery.read()
        snapshot = s
    }
}
