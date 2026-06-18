import Darwin

/// Décision de sûreté pour tuer un process. PURE et testée — c'est le cœur
/// sécurité du produit : aucun kill ne doit contourner cette porte.
public enum KillDecision: Equatable {
    case allowed
    case allowedWithWarning(String)
    case denied(String)

    public var isDenied: Bool { if case .denied = self { return true }; return false }
}

public enum KillGuard {

    /// Process critiques dont la mort déconnecte/instabilise la session de
    /// façon non triviale, même s'ils tournent sous l'uid de l'utilisateur.
    /// (Filet par nom — la frontière dure est `isSystem` via le chemin du binaire.)
    static let denyNames: Set<String> = [
        "launchd", "kernel_task", "windowserver", "loginwindow", "logd",
        "cfprefsd", "configd", "mdnsresponder", "mds", "mds_stores",
        "securityd", "opendirectoryd", "distnoted", "coreaudiod",
        "launchservicesd", "runningboardd", "powerd", "watchdogd",
        "usereventagent", "trustd", "amfid", "syspolicyd",
        // daemons par-session, propriété de l'utilisateur, critiques :
        "tccd", "sharingd", "cloudd", "bird", "nsurlsessiond", "secd",
        "knowledgeconstructd", "universalaccessd", "secinitd",
        "containermanagerd", "lsd", "trustdfileagent",
    ]

    /// Process relancés automatiquement par le système : kill autorisé mais
    /// avec avertissement (la session peut clignoter).
    static let warnNames: Set<String> = [
        "dock", "finder", "systemuiserver", "controlcenter", "notificationcenter",
        "spotlight", "windowmanager", "textinputmenuagent", "coreservicesuiagent",
    ]

    /// Décide si `pid` (propriétaire `uid`, nom `name`, binaire système `isSystem`)
    /// peut être tué par l'utilisateur `myUID`. `selfPID` = le moniteur (jamais tuable).
    public static func decide(pid: pid_t, uid: uid_t, name: String, isSystem: Bool,
                              myUID: uid_t, selfPID: pid_t) -> KillDecision {
        if pid <= 1 {
            return .denied("PID système réservé (\(pid)).")
        }
        if pid == selfPID {
            return .denied("C'est le moniteur lui-même.")
        }
        if uid != myUID {
            return .denied("Process d'un autre utilisateur (uid \(uid)) — élévation admin requise, non supportée en V1.")
        }
        // Frontière dure : binaire hébergé sous un répertoire système.
        if isSystem {
            return .denied("Process système (binaire sous un répertoire protégé).")
        }
        // Fail-closed : nom illisible → on refuse plutôt que d'autoriser à l'aveugle.
        let lname = name.lowercased()
        if lname.isEmpty {
            return .denied("Identité du process indéterminée — refus par précaution.")
        }
        if denyNames.contains(lname) {
            return .denied("Process système critique : \(name).")
        }
        // Tolérance à la troncature de proc_name (p_comm ~16 octets sur Darwin) :
        // un nom long tronqué reste refusé s'il est préfixe d'un nom critique connu.
        if lname.count >= 15, denyNames.contains(where: { $0.hasPrefix(lname) }) {
            return .denied("Process système critique (nom tronqué) : \(name).")
        }
        if warnNames.contains(lname) {
            return .allowedWithWarning("« \(name) » sera relancé automatiquement, mais votre session peut brièvement clignoter.")
        }
        return .allowed
    }
}
