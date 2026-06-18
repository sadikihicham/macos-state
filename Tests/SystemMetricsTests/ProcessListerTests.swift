import XCTest
import Darwin
@testable import SystemMetrics

final class ProcessListerTests: XCTestCase {

    func testListsCurrentProcess() {
        let lister = ProcessLister()
        _ = lister.list()                 // 1er passage (amorce les deltas CPU)
        let procs = lister.list()
        XCTAssertFalse(procs.isEmpty, "doit lister au moins quelques process")

        let myPID = getpid()
        guard let me = procs.first(where: { $0.pid == myPID }) else {
            // top-12 par CPU : on n'est peut-être pas dedans → on valide juste l'identité.
            XCTAssertTrue(lister.validate(pid: myPID,
                                          expectedStart: ProcessLister.bsdInfo(myPID)!.start,
                                          expectedUID: getuid()))
            return
        }
        XCTAssertEqual(me.uid, getuid())
        XCTAssertGreaterThan(me.memBytes, 0)
    }

    func testValidateRejectsWrongIdentity() {
        let lister = ProcessLister()
        let myPID = getpid()
        guard let info = ProcessLister.bsdInfo(myPID) else { return XCTFail("bsdInfo") }
        // Bon start time → ok.
        XCTAssertTrue(lister.validate(pid: myPID, expectedStart: info.start, expectedUID: getuid()))
        // Mauvais start time (PID réutilisé simulé) → refus.
        XCTAssertFalse(lister.validate(pid: myPID, expectedStart: info.start &+ 1, expectedUID: getuid()))
        // Mauvais uid → refus.
        XCTAssertFalse(lister.validate(pid: myPID, expectedStart: info.start, expectedUID: 99999))
    }

    func testValidateDeadPIDFalse() {
        let lister = ProcessLister()
        // PID très improbable d'exister.
        XCTAssertFalse(lister.validate(pid: 999_999, expectedStart: 0, expectedUID: getuid()))
    }

    // MARK: - isSystemPath (frontière dure, F3)

    func testSystemPathNilFailsClosed() {
        // F3 : chemin illisible ⇒ traité comme système (non tuable), pas fail-open.
        XCTAssertTrue(ProcessLister.isSystemPath(nil))
    }

    func testSystemPathCaseInsensitive() {
        XCTAssertTrue(ProcessLister.isSystemPath("/SYSTEM/Library/Foo"))
        XCTAssertTrue(ProcessLister.isSystemPath("/usr/LibExec/food"))
    }

    func testSystemPathPrefixNotOverMatched() {
        // Le slash final évite que /Systemfoo matche /System/.
        XCTAssertFalse(ProcessLister.isSystemPath("/Users/x/Systemfoo"))
        XCTAssertFalse(ProcessLister.isSystemPath("/Applications/Foo.app/Contents/MacOS/Foo"))
    }

    func testSystemPathRealSystemBinary() {
        XCTAssertTrue(ProcessLister.isSystemPath("/System/Library/CoreServices/loginwindow"))
        XCTAssertTrue(ProcessLister.isSystemPath("/usr/libexec/secd"))
    }
}
