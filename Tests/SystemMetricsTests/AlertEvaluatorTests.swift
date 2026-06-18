import XCTest
@testable import SystemMetrics

final class AlertEvaluatorTests: XCTestCase {
    let t = AlertThresholds(cpu: 0.90, tempC: 85, disk: 0.95)

    func testFiresOnRisingEdgeOnly() {
        // Premier franchissement → fired.
        let r1 = AlertEvaluator.evaluate(cpu: 0.95, tempC: 50, disk: 0.5, thresholds: t, previouslyOver: [])
        XCTAssertEqual(r1.over, [.cpu])
        XCTAssertEqual(r1.fired, [.cpu])
        // Toujours au-dessus → plus de fired (pas de spam).
        let r2 = AlertEvaluator.evaluate(cpu: 0.96, tempC: 50, disk: 0.5, thresholds: t, previouslyOver: r1.over)
        XCTAssertEqual(r2.over, [.cpu])
        XCTAssertTrue(r2.fired.isEmpty)
    }

    func testHysteresisKeepsOverInBand() {
        // 0.90 seuil, hystérésis 0.81. À 0.85 (dans la bande) on reste "over".
        let over: Set<SystemAlert> = [.cpu]
        let r = AlertEvaluator.evaluate(cpu: 0.85, tempC: 50, disk: 0.5, thresholds: t, previouslyOver: over)
        XCTAssertEqual(r.over, [.cpu], "reste au-dessus dans la bande d'hystérésis")
        XCTAssertTrue(r.fired.isEmpty)
    }

    func testClearsBelowHysteresis() {
        let over: Set<SystemAlert> = [.cpu]
        let r = AlertEvaluator.evaluate(cpu: 0.70, tempC: 50, disk: 0.5, thresholds: t, previouslyOver: over)
        XCTAssertTrue(r.over.isEmpty, "repasse sous limit*0.9 → plus d'alerte")
    }

    func testNilTemperatureNotEvaluated() {
        let r = AlertEvaluator.evaluate(cpu: 0.5, tempC: nil, disk: 0.5, thresholds: t, previouslyOver: [])
        XCTAssertFalse(r.over.contains(.temperature))
    }

    func testMultipleSimultaneous() {
        let r = AlertEvaluator.evaluate(cpu: 0.95, tempC: 90, disk: 0.97, thresholds: t, previouslyOver: [])
        XCTAssertEqual(r.fired, [.cpu, .temperature, .disk])
    }
}
