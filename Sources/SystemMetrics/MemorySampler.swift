import Darwin

/// Instantané mémoire : octets « utilisés » (façon Activity Monitor :
/// active + wired + compressé) et capacité totale.
public struct MemorySample: Equatable {
    public let usedBytes: UInt64
    public let totalBytes: UInt64
    // Ventilation (mode développé).
    public let activeBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let freeBytes: UInt64
    public init(usedBytes: UInt64, totalBytes: UInt64,
                activeBytes: UInt64 = 0, wiredBytes: UInt64 = 0,
                compressedBytes: UInt64 = 0, freeBytes: UInt64 = 0) {
        self.usedBytes = usedBytes; self.totalBytes = totalBytes
        self.activeBytes = activeBytes; self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes; self.freeBytes = freeBytes
    }
    public var fraction: Double {
        Metrics.fraction(used: Double(usedBytes), total: Double(totalBytes))
    }
}

/// Lit la mémoire via `host_statistics64(HOST_VM_INFO64)` + `hw.memsize`.
public final class MemorySampler {
    public init() {}

    private static func totalBytes() -> UInt64 {
        var size: UInt64 = 0
        var len = MemoryLayout<UInt64>.size
        return sysctlbyname("hw.memsize", &size, &len, nil, 0) == 0 ? size : 0
    }

    public func read() -> MemorySample? {
        var pageSize: vm_size_t = 0
        if host_page_size(mach_host_self(), &pageSize) != KERN_SUCCESS || pageSize == 0 {
            pageSize = vm_size_t(vm_page_size) // repli : évite un used=0 silencieux
        }

        // HOST_VM_INFO64_COUNT (macro sizeof non importée en Swift).
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var stats = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reb in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reb, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let ps = UInt64(pageSize)
        let active = UInt64(stats.active_count) * ps
        let wired = UInt64(stats.wire_count) * ps
        let compressed = UInt64(stats.compressor_page_count) * ps
        let free = UInt64(stats.free_count) * ps
        // « Utilisé » ≈ pages actives + câblées + compressées (cache exclu).
        let used = active + wired + compressed

        return MemorySample(usedBytes: used, totalBytes: Self.totalBytes(),
                            activeBytes: active, wiredBytes: wired,
                            compressedBytes: compressed, freeBytes: free)
    }
}
