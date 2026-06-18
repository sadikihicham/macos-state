import XCTest
import Foundation
@testable import SystemMetrics

/// Eval d'exactitude reproductible : croise la sortie des samplers avec des
/// sources système INDÉPENDANTES (sysctl, vm_stat, df, pmset, ifconfig).
/// But : attraper les régressions silencieuses de formule / conversion d'unité
/// (un ×1024 oublié, une mauvaise taille de page…) que les invariants internes
/// ne voient pas. Tolérances généreuses + XCTSkip si l'outil/valeur est
/// indisponible → jamais flaky, sûr pour la porte (hook pre-commit).
///
/// Lancement ciblé : `make accuracy` (filtre AccuracyCrossSource).
final class AccuracyCrossSourceTests: XCTestCase {

    // MARK: - Mémoire

    /// La RAM totale du sampler doit égaler exactement `hw.memsize`.
    func testMemoryTotalMatchesSysctl() throws {
        guard let total = MemorySampler().read()?.totalBytes else { throw XCTSkip("mémoire illisible") }
        guard let raw = shell("/usr/sbin/sysctl", ["-n", "hw.memsize"]),
              let ground = UInt64(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        else { throw XCTSkip("sysctl indisponible") }
        XCTAssertEqual(total, ground, "RAM totale doit égaler hw.memsize")
    }

    /// La mémoire « utilisée » (active+wired+compressé) doit correspondre, à ~30%
    /// près, au même calcul depuis `vm_stat` × taille de page. C'est le garde-fou
    /// clé contre une erreur de conversion octets/pages.
    func testMemoryUsedMatchesVmStat() throws {
        guard let used = MemorySampler().read()?.usedBytes, used > 0 else { throw XCTSkip("mémoire illisible") }
        guard let out = shell("/usr/bin/vm_stat", []),
              let pageSize = firstInt(after: "page size of ", in: out),
              let active = pagesValue("Pages active:", in: out),
              let wired = pagesValue("Pages wired down:", in: out),
              let compressed = pagesValue("Pages occupied by compressor:", in: out)
        else { throw XCTSkip("vm_stat illisible") }

        let groundUsed = (active + wired + compressed) * pageSize
        assertWithin(Double(used), Double(groundUsed), ratio: 0.30,
                     "mémoire utilisée sampler vs vm_stat")
    }

    // MARK: - Disque

    /// Capacité totale du volume "/" cohérente avec `df -k /` (tolérance large :
    /// la comptabilité APFS diffère ; on vise surtout l'ordre de grandeur / l'unité).
    func testDiskTotalMatchesDf() throws {
        guard let total = DiskSampler().read()?.totalBytes, total > 0 else { throw XCTSkip("disque illisible") }
        guard let out = shell("/bin/df", ["-k", "/"]) else { throw XCTSkip("df indisponible") }
        let lines = out.split(separator: "\n")
        guard lines.count >= 2 else { throw XCTSkip("df illisible") }
        let fields = lines[1].split(separator: " ", omittingEmptySubsequences: true)
        guard fields.count >= 2, let kb = UInt64(fields[1]) else { throw XCTSkip("df illisible") }
        assertWithin(Double(total), Double(kb * 1024), ratio: 0.25, "disque total sampler vs df")
    }

    // MARK: - Batterie

    /// Si une batterie est présente, le % du sampler doit être à ±8 points du
    /// % rapporté par `pmset -g batt`. Skip propre sur Mac de bureau.
    func testBatteryPercentMatchesPmset() throws {
        guard let info = BatterySampler().read() else { throw XCTSkip("pas de batterie (Mac de bureau)") }
        guard let out = shell("/usr/bin/pmset", ["-g", "batt"]),
              let ground = percentBefore("%", in: out)
        else { throw XCTSkip("pmset illisible") }
        XCTAssertLessThanOrEqual(abs(info.percent - ground), 8,
                                 "batterie sampler \(info.percent)% vs pmset \(ground)%")
    }

    // MARK: - Réseau

    /// Toutes les interfaces vues par le sampler doivent exister dans `ifconfig -l`
    /// (on n'invente pas d'interface ; lo0 est exclu côté sampler).
    func testInterfacesSubsetOfIfconfig() throws {
        let sampled = Set(NetworkSampler.readPerInterface().keys)
        guard !sampled.isEmpty else { throw XCTSkip("aucune interface active") }
        guard let out = shell("/sbin/ifconfig", ["-l"]) else { throw XCTSkip("ifconfig indisponible") }
        let known = Set(out.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init))
        guard !known.isEmpty else { throw XCTSkip("ifconfig illisible") }
        XCTAssertTrue(sampled.isSubset(of: known),
                      "interfaces hors ifconfig : \(sampled.subtracting(known))")
    }

    // MARK: - Helpers

    /// Lance un binaire système et capture stdout. nil si l'exécution échoue.
    private func shell(_ path: String, _ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

    /// Premier entier qui suit `marker` dans `s`.
    private func firstInt(after marker: String, in s: String) -> UInt64? {
        guard let r = s.range(of: marker) else { return nil }
        let digits = s[r.upperBound...].prefix { $0.isNumber }
        return UInt64(digits)
    }

    /// Valeur d'une ligne `vm_stat` du type "Pages active:   12345.".
    private func pagesValue(_ label: String, in s: String) -> UInt64? {
        for line in s.split(separator: "\n") where line.hasPrefix(label) {
            return UInt64(line.filter { $0.isNumber })
        }
        return nil
    }

    /// Entier collé juste avant la 1ʳᵉ occurrence de `token` (ex. "83%").
    private func percentBefore(_ token: String, in s: String) -> Int? {
        guard let r = s.range(of: token) else { return nil }
        let digits = String(s[..<r.lowerBound].reversed().prefix { $0.isNumber }.reversed())
        return Int(digits)
    }

    /// Assert que deux mesures sont dans un ratio d'écart relatif.
    private func assertWithin(_ a: Double, _ b: Double, ratio: Double, _ msg: String) {
        let hi = max(a, b), lo = min(a, b)
        XCTAssertGreaterThan(lo, 0, "\(msg) — valeur nulle")
        let diff = hi > 0 ? (hi - lo) / hi : 1
        XCTAssertLessThanOrEqual(diff, ratio,
            "\(msg) — écart \(Int(diff * 100))% > \(Int(ratio * 100))% (\(Int(a)) vs \(Int(b)))")
    }
}
