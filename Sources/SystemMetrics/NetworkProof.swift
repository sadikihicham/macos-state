import Darwin

/// Preuve de confidentialité *vivante* : compte les sockets réseau réellement
/// ouverts par NOTRE process, via `libproc` (API publique, lecture seule).
///
/// C'est le différenciateur du produit : un moniteur 100% local peut le **prouver
/// à l'exécution** (0 socket), pas seulement le promettre. Complète l'invariant
/// build-time `make check-net` (aucun symbole réseau lié) par une preuve runtime.
public enum NetworkProof {

    /// Type de descripteur « socket » dans `proc_fdinfo.proc_fdtype`
    /// (`PROX_FDTYPE_SOCKET` de `<sys/proc_info.h>`).
    public static let socketFDType: UInt32 = 2

    /// Pur : nombre de descripteurs de type socket dans une liste de types.
    /// Testable sans matériel.
    public static func socketCount(fdTypes: [UInt32]) -> Int {
        fdTypes.filter { $0 == socketFDType }.count
    }

    /// Lit les descripteurs ouverts du process `pid` (par défaut le nôtre) et
    /// compte les sockets. `nil` si la lecture échoue (l'affichage retombe alors
    /// sur la garantie build-time, sans prétendre à une preuve runtime).
    public static func openSocketCount(pid: pid_t = getpid()) -> Int? {
        let stride = MemoryLayout<proc_fdinfo>.stride
        let needed = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard needed > 0 else { return needed == 0 ? 0 : nil }

        let cap = Int(needed) / stride + 16          // marge pour la course
        var buf = [proc_fdinfo](repeating: proc_fdinfo(), count: cap)
        let got = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &buf, Int32(cap * stride))
        guard got > 0 else { return nil }

        let n = Int(got) / stride
        return socketCount(fdTypes: buf.prefix(n).map { UInt32($0.proc_fdtype) })
    }
}
