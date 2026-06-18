import XCTest
@testable import SystemMetrics

final class KillGuardTests: XCTestCase {
    let me: uid_t = 501
    let other: uid_t = 0
    let selfPID: pid_t = 4242

    private func decide(pid: pid_t = 9999, uid: uid_t = 501, name: String = "MyApp",
                        isSystem: Bool = false) -> KillDecision {
        KillGuard.decide(pid: pid, uid: uid, name: name, isSystem: isSystem,
                         myUID: me, selfPID: selfPID)
    }

    func testNormalUserAppAllowed() {
        XCTAssertEqual(decide(), .allowed)
    }

    func testOtherUserDenied() {
        XCTAssertTrue(decide(uid: other).isDenied, "process d'un autre uid doit être refusé")
    }

    func testReservedPIDsDenied() {
        XCTAssertTrue(decide(pid: 0).isDenied)
        XCTAssertTrue(decide(pid: 1, name: "launchd").isDenied)
        XCTAssertTrue(decide(pid: -5).isDenied)
    }

    func testSelfDenied() {
        XCTAssertTrue(decide(pid: selfPID).isDenied, "le moniteur ne doit pas se tuer lui-même")
    }

    func testCriticalNamesDeniedEvenAsUser() {
        // Même sous notre uid, ces process sont refusés.
        for n in ["loginwindow", "cfprefsd", "WindowServer", "coreaudiod", "securityd"] {
            XCTAssertTrue(decide(name: n).isDenied, "\(n) doit être refusé")
        }
    }

    func testCriticalNameCaseInsensitive() {
        XCTAssertTrue(decide(name: "LoginWindow").isDenied)
        XCTAssertTrue(decide(name: "LAUNCHD").isDenied)
    }

    func testUserEventAgentTypoFixed() {
        // Régression M1 : la coquille "useventagent" ne matchait jamais le vrai nom.
        XCTAssertTrue(decide(name: "UserEventAgent").isDenied)
    }

    func testNewlyAddedUserDaemonsDenied() {
        for n in ["tccd", "sharingd", "cloudd", "bird", "nsurlsessiond"] {
            XCTAssertTrue(decide(name: n).isDenied, "\(n) doit être refusé")
        }
    }

    func testSystemBinaryDenied() {
        // Frontière dure : tout binaire système est refusé, même nom anodin.
        XCTAssertTrue(decide(name: "anything", isSystem: true).isDenied)
    }

    func testEmptyNameFailsClosed() {
        // Nom illisible → refus par précaution (fail-closed).
        XCTAssertTrue(decide(name: "").isDenied)
    }

    func testRecoverableNamesWarn() {
        for n in ["Finder", "Dock", "SystemUIServer"] {
            if case .allowedWithWarning = decide(name: n) { continue }
            XCTFail("\(n) doit être autorisé avec avertissement")
        }
    }

    func testDeniedTakesPrecedenceOverWarn() {
        // uid étranger l'emporte sur un nom "warn".
        XCTAssertTrue(decide(uid: other, name: "Finder").isDenied)
    }
}
