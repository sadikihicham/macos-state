import XCTest
@testable import SystemMetrics

final class DetailTests: XCTestCase {

    // Per-core : smoke réel (nombre de cœurs > 0, valeurs bornées au 2e appel).
    func testPerCoreUsageBounded() {
        let cpu = CPUSampler()
        let first = cpu.perCoreUsage()      // pas de delta → []
        XCTAssertTrue(first.isEmpty)
        XCTAssertNotNil(cpu.readPerCore())
        XCTAssertFalse(cpu.readPerCore()?.isEmpty ?? true)

        let second = cpu.perCoreUsage()     // delta dispo
        XCTAssertFalse(second.isEmpty, "doit retourner un usage par cœur")
        for v in second {
            XCTAssertGreaterThanOrEqual(v, 0.0)
            XCTAssertLessThanOrEqual(v, 1.0)
        }
    }

    // Ventilation mémoire : used = active + wired + compressé, et ≤ total.
    func testMemoryBreakdownConsistent() {
        guard let m = MemorySampler().read() else { return XCTFail("lecture mémoire") }
        XCTAssertEqual(m.usedBytes, m.activeBytes + m.wiredBytes + m.compressedBytes)
        XCTAssertLessThanOrEqual(m.usedBytes, m.totalBytes)
        XCTAssertGreaterThan(m.totalBytes, 0)
    }

    // Réseau par interface : 2 lectures, débits ≥ 0, pas de doublon d'id.
    func testInterfaceRatesNonNegative() {
        let net = NetworkSampler()
        _ = net.interfaceRates()
        let rates = net.interfaceRates()
        let names = rates.map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "interfaces uniques")
        for r in rates {
            XCTAssertGreaterThanOrEqual(r.down, 0)
            XCTAssertGreaterThanOrEqual(r.up, 0)
        }
    }
}
