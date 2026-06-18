import AppKit
import Darwin
import SystemMetrics

enum KillOutcome: Equatable {
    case terminated          // app quittée proprement (NSRunningApplication)
    case signalSent          // SIGTERM envoyé (escalade SIGKILL planifiée)
    case denied(String)      // refusé par KillGuard
    case staleIdentity       // le PID ne correspond plus au même process
    case failed(String)      // échec syscall (errno)
}

/// Exécute les kills sous la double protection : re-validation d'identité
/// (anti-PID-reuse) PUIS porte KillGuard. Préfère un arrêt gracieux pour les apps.
@MainActor
final class ProcessController {
    private let lister: ProcessLister
    init(lister: ProcessLister) { self.lister = lister }

    /// Décision affichable (pour activer/désactiver le bouton dans l'UI).
    func decide(_ p: ProcSample) -> KillDecision {
        KillGuard.decide(pid: p.pid, uid: p.uid, name: p.name, isSystem: p.isSystem,
                         myUID: getuid(), selfPID: getpid())
    }

    func perform(_ p: ProcSample) -> KillOutcome {
        // 1) Anti-réutilisation de PID : l'identité doit être inchangée.
        guard lister.validate(pid: p.pid, expectedStart: p.startTime, expectedUID: p.uid) else {
            return .staleIdentity
        }
        // 2) Porte de sûreté (jamais contournée).
        if case .denied(let reason) = decide(p) { return .denied(reason) }

        // 3) Re-validation juste avant de frapper (referme la micro-fenêtre TOCTOU).
        guard lister.validate(pid: p.pid, expectedStart: p.startTime, expectedUID: p.uid) else {
            return .staleIdentity
        }

        // 4) Exécution — arrêt gracieux si c'est une app à interface.
        if let app = NSRunningApplication(processIdentifier: p.pid) {
            app.terminate()
            return .terminated
        }
        if Darwin.kill(p.pid, SIGTERM) == 0 {
            scheduleEscalation(pid: p.pid, start: p.startTime, uid: p.uid)
            return .signalSent
        }
        return .failed(String(cString: strerror(errno)))
    }

    /// Si le process refuse SIGTERM, escalade vers SIGKILL après un délai —
    /// uniquement si l'identité est toujours la même (sécurité anti-PID-reuse).
    private func scheduleEscalation(pid: pid_t, start: UInt64, uid: uid_t) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self else { return }
            if self.lister.validate(pid: pid, expectedStart: start, expectedUID: uid) {
                _ = Darwin.kill(pid, SIGKILL)
            }
        }
    }
}
