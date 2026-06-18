import Foundation

/// Capacité du volume racine "/" (octets utilisés/total).
public struct DiskSample: Equatable {
    public let usedBytes: Int64
    public let totalBytes: Int64
    public init(usedBytes: Int64, totalBytes: Int64) {
        self.usedBytes = usedBytes; self.totalBytes = totalBytes
    }
    public var fraction: Double {
        Metrics.fraction(used: Double(usedBytes), total: Double(totalBytes))
    }
}

public final class DiskSampler {
    private let url: URL
    public init(path: String = "/") { self.url = URL(fileURLWithPath: path) }

    public func read() -> DiskSample? {
        guard let vals = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]) else { return nil }

        guard let total = vals.volumeTotalCapacity.map(Int64.init) else { return nil }
        let available = vals.volumeAvailableCapacityForImportantUsage ?? 0
        let used = max(0, total - available)
        return DiskSample(usedBytes: used, totalBytes: total)
    }
}
