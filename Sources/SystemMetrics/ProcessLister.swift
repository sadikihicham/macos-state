import Darwin
import Foundation

/// Instantané d'un process : identité (pid+startTime pour l'anti-réutilisation),
/// propriétaire (uid), et consommation (CPU%/mémoire).
public struct ProcSample: Identifiable, Equatable {
    public let pid: pid_t
    public let name: String
    public let uid: uid_t
    public let startTime: UInt64       // sec*1e6 + µsec — clé anti-PID-reuse (résolution µs)
    public let cpuPercent: Double      // peut dépasser 100 (multicœur), comme Activity Monitor
    public let memBytes: UInt64
    public let isSystem: Bool          // binaire sous un répertoire système → non tuable
    public var id: pid_t { pid }
    public init(pid: pid_t, name: String, uid: uid_t, startTime: UInt64,
                cpuPercent: Double, memBytes: UInt64, isSystem: Bool = false) {
        self.pid = pid; self.name = name; self.uid = uid; self.startTime = startTime
        self.cpuPercent = cpuPercent; self.memBytes = memBytes; self.isSystem = isSystem
    }
}

/// Énumère les process via libproc et calcule le CPU% par différence de temps.
public final class ProcessLister {
    private struct Prev { let cpu: UInt64; let start: UInt64; let t: DispatchTime }
    private var prev: [pid_t: Prev] = [:]
    public init() {}

    public func list() -> [ProcSample] {
        let now = DispatchTime.now()
        var out: [ProcSample] = []
        var seen = Set<pid_t>()

        for pid in Self.allPIDs() where pid > 0 {
            guard let bsd = Self.bsdInfo(pid) else { continue }
            let path = Self.procPath(pid)
            let isSystem = Self.isSystemPath(path)
            // Fail-closed : si le nom est illisible, on garde "" (KillGuard refusera).
            let name = Self.procName(pid)
                ?? (path.map { ($0 as NSString).lastPathComponent } ?? "")
            let usage = Self.rusage(pid)          // nil si pas la permission (autre user)
            let mem = usage?.mem ?? 0

            var cpuPct = 0.0
            if let cpu = usage?.cpu {
                if let p = prev[pid], p.start == bsd.start {
                    let dt = Double(now.uptimeNanoseconds &- p.t.uptimeNanoseconds)
                    if dt > 0 { cpuPct = Double(Metrics.delta(cpu, p.cpu)) / dt * 100.0 }
                }
                prev[pid] = Prev(cpu: cpu, start: bsd.start, t: now)
            }
            seen.insert(pid)
            out.append(ProcSample(pid: pid, name: name, uid: bsd.uid,
                                  startTime: bsd.start, cpuPercent: cpuPct,
                                  memBytes: mem, isSystem: isSystem))
        }
        prev = prev.filter { seen.contains($0.key) }   // purge des PID disparus
        return out
    }

    /// Anti-réutilisation de PID : re-valide l'identité (start time + uid) juste
    /// avant un kill. false si le process a disparu ou si l'identité a changé.
    public func validate(pid: pid_t, expectedStart: UInt64, expectedUID: uid_t) -> Bool {
        guard let bsd = Self.bsdInfo(pid) else { return false }
        return bsd.start == expectedStart && bsd.uid == expectedUID
    }

    // MARK: - libproc (statique)

    static func allPIDs() -> [pid_t] {
        let needed = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard needed > 0 else { return [] }
        let cap = Int(needed) / MemoryLayout<pid_t>.size + 32   // marge pour la course
        var buf = [pid_t](repeating: 0, count: cap)
        let got = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &buf,
                                Int32(cap * MemoryLayout<pid_t>.size))
        guard got > 0 else { return [] }
        let n = Int(got) / MemoryLayout<pid_t>.size
        return Array(buf.prefix(n))
    }

    static func bsdInfo(_ pid: pid_t) -> (uid: uid_t, start: UInt64)? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let rc = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        guard rc == size else { return nil }
        // Résolution µs (sec*1e6 + µsec) pour rendre la collision PID-reuse négligeable.
        let start = info.pbi_start_tvsec &* 1_000_000 &+ UInt64(info.pbi_start_tvusec)
        return (info.pbi_uid, start)
    }

    static func procName(_ pid: pid_t) -> String? {
        var buf = [CChar](repeating: 0, count: 256)
        let n = proc_name(pid, &buf, UInt32(buf.count))
        guard n > 0 else { return nil }
        return String(cString: buf)
    }

    static func procPath(_ pid: pid_t) -> String? {
        var buf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let n = proc_pidpath(pid, &buf, UInt32(buf.count))
        guard n > 0 else { return nil }
        return String(cString: buf)
    }

    /// Binaire hébergé sous un répertoire système (frontière dure, plus fiable
    /// que le seul nom) → considéré comme non tuable.
    static func isSystemPath(_ path: String?) -> Bool {
        guard let path else { return false }
        let systemDirs = ["/System/", "/usr/libexec/", "/usr/sbin/", "/sbin/", "/usr/lib/"]
        return systemDirs.contains { path.hasPrefix($0) }
    }

    static func rusage(_ pid: pid_t) -> (cpu: UInt64, mem: UInt64)? {
        var ru = rusage_info_v4()
        let rc = withUnsafeMutablePointer(to: &ru) { ptr in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reb in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, reb)
            }
        }
        guard rc == 0 else { return nil }
        return (ru.ri_user_time + ru.ri_system_time, ru.ri_phys_footprint)
    }
}
