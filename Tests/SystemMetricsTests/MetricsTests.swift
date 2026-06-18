import XCTest
@testable import SystemMetrics

final class MetricsTests: XCTestCase {

    func testFractionNormal() {
        XCTAssertEqual(Metrics.fraction(used: 50, total: 200), 0.25, accuracy: 1e-9)
    }

    func testFractionClampsAndGuards() {
        XCTAssertEqual(Metrics.fraction(used: 300, total: 200), 1.0)   // clamp haut
        XCTAssertEqual(Metrics.fraction(used: 10, total: 0), 0)        // total nul
        XCTAssertEqual(Metrics.fraction(used: -5, total: 200), 0)      // used négatif
    }

    func testDeltaMonotonic() {
        XCTAssertEqual(Metrics.delta(1000, 600), 400)
    }

    func testDeltaHandlesReset() {
        // Compteur réinitialisé (current < previous) → 0, pas d'underflow.
        XCTAssertEqual(Metrics.delta(100, 5000), 0)
    }

    func testRate() {
        XCTAssertEqual(Metrics.rate(delta: 2_000_000, seconds: 2.0), 1_000_000, accuracy: 1e-6)
        XCTAssertEqual(Metrics.rate(delta: 1000, seconds: 0), 0)       // garde division/0
    }
}
