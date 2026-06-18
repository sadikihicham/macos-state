import XCTest
import Darwin
@testable import SystemMetrics

final class NetworkProofTests: XCTestCase {

    // MARK: Logique pure (comptage de sockets)

    func testSocketCountCountsOnlySockets() {
        // 1=vnode, 2=socket, 6=pipe — seuls les "2" comptent.
        XCTAssertEqual(NetworkProof.socketCount(fdTypes: [1, 2, 2, 6, 2, 5]), 3)
    }

    func testSocketCountEmpty() {
        XCTAssertEqual(NetworkProof.socketCount(fdTypes: []), 0)
    }

    func testSocketCountNoneWhenNoSockets() {
        XCTAssertEqual(NetworkProof.socketCount(fdTypes: [1, 1, 6, 5, 1]), 0)
    }

    // MARK: Lecture réelle (smoke — dépend du process courant)

    func testOpenSocketCountIsReadable() {
        // Doit renvoyer une valeur lisible et non négative pour notre process.
        guard let count = NetworkProof.openSocketCount() else {
            return XCTFail("lecture des descripteurs impossible")
        }
        XCTAssertGreaterThanOrEqual(count, 0)
    }
}
