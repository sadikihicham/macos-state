import XCTest
@testable import SystemMetrics

final class SamplersTests: XCTestCase {

    // MARK: CPU (logique pure de delta)

    func testCPUUsageHalf() {
        let prev = CPUSample(user: 100, system: 100, idle: 800, nice: 0)
        let cur  = CPUSample(user: 200, system: 200, idle: 1000, nice: 0)
        // busy = 100+100 = 200 ; idle = 200 ; total = 400 → 0.5
        XCTAssertEqual(Metrics.cpuUsage(current: cur, previous: prev), 0.5, accuracy: 1e-9)
    }

    func testCPUUsageIdleStable() {
        let s = CPUSample(user: 10, system: 10, idle: 100, nice: 0)
        // Aucun tick écoulé → total 0 → 0 (pas de NaN).
        XCTAssertEqual(Metrics.cpuUsage(current: s, previous: s), 0)
    }

    func testCPUUsageCountsNice() {
        let prev = CPUSample(user: 0, system: 0, idle: 0, nice: 0)
        let cur  = CPUSample(user: 0, system: 0, idle: 100, nice: 100)
        // nice compte comme occupé : busy 100 / total 200 = 0.5
        XCTAssertEqual(Metrics.cpuUsage(current: cur, previous: prev), 0.5, accuracy: 1e-9)
    }

    // MARK: Samples (calculs de fraction)

    func testMemoryFraction() {
        let m = MemorySample(usedBytes: 8 * 1024*1024*1024, totalBytes: 16 * 1024*1024*1024)
        XCTAssertEqual(m.fraction, 0.5, accuracy: 1e-9)
    }

    func testDiskFractionClampsNegativeAvailable() {
        // used > total ne doit jamais dépasser 1.
        let d = DiskSample(usedBytes: 600, totalBytes: 500)
        XCTAssertEqual(d.fraction, 1.0)
    }

    // MARK: Formatage

    func testFormatBytes() {
        XCTAssertEqual(Metrics.formatBytes(512), "512 B")
        XCTAssertEqual(Metrics.formatBytes(1024), "1.0 KB")
        XCTAssertEqual(Metrics.formatBytes(1_572_864), "1.5 MB")
    }

    func testFormatRate() {
        XCTAssertEqual(Metrics.formatRate(2_097_152), "2.0 MB/s")
    }

    func testFormatMinutes() {
        XCTAssertEqual(Metrics.formatMinutes(161), "2:41")
        XCTAssertEqual(Metrics.formatMinutes(-1), "—")
        XCTAssertEqual(Metrics.formatMinutes(5), "0:05")
    }

    // MARK: Samplers réels (smoke — dépend du matériel, valeurs bornées)

    func testRealSamplersAreSane() {
        let cpu = CPUSampler()
        _ = cpu.usage()                  // 1er appel: nil (pas de delta)
        XCTAssertNotNil(cpu.read())

        if let m = MemorySampler().read() {
            XCTAssertGreaterThan(m.totalBytes, 0)
            XCTAssertLessThanOrEqual(m.fraction, 1.0)
            XCTAssertGreaterThanOrEqual(m.fraction, 0.0)
        } else { XCTFail("lecture mémoire impossible") }

        if let d = DiskSampler().read() {
            XCTAssertGreaterThan(d.totalBytes, 0)
            XCTAssertLessThanOrEqual(d.fraction, 1.0)
        } else { XCTFail("lecture disque impossible") }

        // Réseau : 1er appel (0,0), 2e ≥ 0.
        let net = NetworkSampler()
        _ = net.rates()
        let r = net.rates()
        XCTAssertGreaterThanOrEqual(r.down, 0)
        XCTAssertGreaterThanOrEqual(r.up, 0)
    }
}
