import Darwin

/// Échantillon de ticks CPU cumulés (user/system/idle/nice).
public struct CPUSample: Equatable {
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64
    public let nice: UInt64
    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user; self.system = system; self.idle = idle; self.nice = nice
    }
}

/// Lit la charge CPU agrégée via `host_statistics(HOST_CPU_LOAD_INFO)` et
/// calcule l'usage par différence entre deux appels.
public final class CPUSampler {
    private var previous: CPUSample?
    public init() {}

    /// Lecture brute des ticks cumulés. nil si l'appel mach échoue.
    public func read() -> CPUSample? {
        // HOST_CPU_LOAD_INFO_COUNT (macro sizeof non importée en Swift).
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reb in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reb, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUSample(
            user: UInt64(info.cpu_ticks.0),
            system: UInt64(info.cpu_ticks.1),
            idle: UInt64(info.cpu_ticks.2),
            nice: UInt64(info.cpu_ticks.3)
        )
    }

    /// Usage [0...1] depuis le dernier appel. nil au tout premier (pas de delta).
    public func usage() -> Double? {
        guard let cur = read() else { return nil }
        defer { previous = cur }
        guard let prev = previous else { return nil }
        return Metrics.cpuUsage(current: cur, previous: prev)
    }
}
