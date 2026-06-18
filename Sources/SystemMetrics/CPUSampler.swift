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

    // MARK: - Par cœur

    private var previousCores: [CPUSample]?

    /// Lecture brute des ticks par cœur via `host_processor_info`.
    public func readPerCore() -> [CPUSample]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                     &cpuCount, &info, &infoCount)
        guard kr == KERN_SUCCESS, let info else { return nil }
        // Le buffer est alloué par le kernel : il faut le libérer.
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        let states = Int(CPU_STATE_MAX)
        let buf = UnsafeBufferPointer(start: info, count: Int(infoCount))
        var samples: [CPUSample] = []
        samples.reserveCapacity(Int(cpuCount))
        for i in 0..<Int(cpuCount) {
            let base = i * states
            guard base + Int(CPU_STATE_NICE) < buf.count else { break }
            samples.append(CPUSample(
                user:   UInt64(UInt32(bitPattern: buf[base + Int(CPU_STATE_USER)])),
                system: UInt64(UInt32(bitPattern: buf[base + Int(CPU_STATE_SYSTEM)])),
                idle:   UInt64(UInt32(bitPattern: buf[base + Int(CPU_STATE_IDLE)])),
                nice:   UInt64(UInt32(bitPattern: buf[base + Int(CPU_STATE_NICE)]))
            ))
        }
        return samples
    }

    /// Usage [0...1] par cœur depuis le dernier appel. [] tant qu'il n'y a pas de delta.
    public func perCoreUsage() -> [Double] {
        guard let cur = readPerCore() else { return [] }
        defer { previousCores = cur }
        guard let prev = previousCores, prev.count == cur.count else { return [] }
        return zip(cur, prev).map { Metrics.cpuUsage(current: $0, previous: $1) }
    }
}
