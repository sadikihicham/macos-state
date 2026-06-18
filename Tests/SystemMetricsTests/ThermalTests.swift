import XCTest
@testable import SystemMetrics

final class ThermalTests: XCTestCase {

    // MARK: Encodage de clé SMC (pur)

    func testFourCCEncodesKey() {
        // "FNum" → 0x46 4E 75 6D
        XCTAssertEqual(SMCFan.fourCC("FNum"), 0x46_4E_75_6D)
        // "F0Ac" → 0x46 30 41 63
        XCTAssertEqual(SMCFan.fourCC("F0Ac"), 0x46_30_41_63)
    }

    func testFourCCUsesFirstFourBytes() {
        XCTAssertEqual(SMCFan.fourCC("FNumXYZ"), SMCFan.fourCC("FNum"))
    }

    // MARK: Modèle

    func testThermalSampleStoresValues() {
        let s = ThermalSample(cpuTempC: 50.5, fanRPM: 1200, fanCount: 2)
        XCTAssertEqual(s.cpuTempC, 50.5)
        XCTAssertEqual(s.fanRPM, 1200)
        XCTAssertEqual(s.fanCount, 2)
    }

    func testCpuTokensTargetDieSensors() {
        // Le 1er token doit cibler les capteurs die (PMU tdie…), la vraie temp CPU.
        XCTAssertEqual(ThermalSampler.cpuTokens.first, "PMU tdie")
    }

    // MARK: Lecture réelle (smoke — best-effort, ne doit jamais crasher)

    func testThermalReadDoesNotCrash() {
        let s = ThermalSampler().read()
        if let t = s.cpuTempC { XCTAssertTrue(t > 0 && t < 150, "temp plausible") }
        XCTAssertGreaterThanOrEqual(s.fanCount, 0)
    }
}
