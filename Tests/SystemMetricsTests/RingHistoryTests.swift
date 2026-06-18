import XCTest
@testable import SystemMetrics

final class RingHistoryTests: XCTestCase {

    func testAppendKeepsOrderOldestToNewest() {
        var h = RingHistory(capacity: 5)
        [1, 2, 3].forEach { h.append($0) }
        XCTAssertEqual(h.values, [1, 2, 3])
        XCTAssertEqual(h.last, 3)
        XCTAssertEqual(h.count, 3)
    }

    func testEvictsOldestBeyondCapacity() {
        var h = RingHistory(capacity: 3)
        [1, 2, 3, 4, 5].forEach { h.append($0) }
        XCTAssertEqual(h.values, [3, 4, 5], "ne garde que les 3 dernieres")
        XCTAssertEqual(h.count, 3)
    }

    func testCapacityNeverBelowOne() {
        var h = RingHistory(capacity: 0)
        h.append(7); h.append(8)
        XCTAssertEqual(h.values, [8])
    }

    func testNormalizedClampsToUnitRange() {
        var h = RingHistory(capacity: 4)
        [0, 50, 100, 150].forEach { h.append($0) }
        // bornes 0..100 : 150 doit etre clampe a 1.0
        XCTAssertEqual(h.normalized(min: 0, max: 100), [0.0, 0.5, 1.0, 1.0])
    }

    func testNormalizedFlatWhenNoSpan() {
        var h = RingHistory(capacity: 3)
        [5, 5, 5].forEach { h.append($0) }
        XCTAssertEqual(h.normalized(min: 5, max: 5), [0.5, 0.5, 0.5])
    }
}
