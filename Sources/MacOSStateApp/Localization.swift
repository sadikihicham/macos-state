import Foundation

/// Localisation légère, sans bundle : table FR→EN/AR en Swift pur (robuste pour
/// un .app empaqueté à la main, contrairement aux ressources .lproj de SwiftPM
/// qui partent dans Bundle.module). La clé EST la chaîne française du code.
/// Bascule en direct via UserDefaults("app.lang") + @AppStorage côté SwiftUI.
enum L {
    static let key = "app.lang"
    static let supported = ["fr", "en", "ar"]

    static var lang: String {
        let l = UserDefaults.standard.string(forKey: key) ?? "fr"
        return supported.contains(l) ? l : "fr"
    }
    static func setLang(_ l: String) { UserDefaults.standard.set(l, forKey: key) }

    static func name(_ l: String) -> String {
        switch l { case "en": return "English"; case "ar": return "العربية"; default: return "Français" }
    }
    static func isRTL(_ l: String) -> Bool { l == "ar" }

    /// Traduit `fr` vers la langue courante (ou `lang` fourni pour le suivi de
    /// dépendance SwiftUI). Repli sur le français si clé absente.
    static func t(_ fr: String, _ l: String? = nil) -> String {
        switch l ?? lang {
        case "en": return en[fr] ?? fr
        case "ar": return ar[fr] ?? fr
        default:   return fr
        }
    }

    /// Gabarit localisé avec arguments (placeholders %@).
    static func fmt(_ frTemplate: String, _ args: CVarArg...) -> String {
        String(format: t(frTemplate), arguments: args)
    }

    static let en: [String: String] = [
        "Réduire": "Collapse", "Détails": "Details", "Réduire en pastille": "Collapse to dot",
        "Afficher le HUD": "Show HUD", "Masquer le HUD": "Hide HUD",
        "Local": "Local", "Privé": "Private", "100% local (vérifié en CI)": "100% local (verified in CI)",
        "0 socket réseau ouvert": "0 network sockets open",
        "CPU": "CPU", "RAM": "RAM", "Disq": "Disk", "Rés": "Net", "Bat": "Bat",
        "Temp": "Temp", "vent. N/A": "fan N/A", "cœurs": "cores", "CPU ·": "CPU ·",
        "Mémoire": "Memory", "Active": "Active", "Câblée": "Wired", "Compressée": "Compressed",
        "Libre": "Free", "Total": "Total", "Disque /": "Disk /", "Utilisé": "Used",
        "Réseau par interface": "Network by interface", "Batterie": "Battery", "Santé": "Health",
        "Cycles": "Cycles", "État": "Status", "Alimentation": "Power", "Secteur": "AC power",
        "PROCESSUS (TOP CPU)": "PROCESSES (TOP CPU)", "Tuer ce process": "Kill this process",
        "Toujours au-dessus": "Always on top", "Intervalle": "Interval", "Métriques": "Metrics",
        "Disque": "Disk", "Réseau": "Network", "Thermique (temp. + ventilo)": "Thermal (temp + fan)",
        "Lancer au login": "Launch at login", "Quitter macOS State": "Quit macOS State",
        "Tuer": "Kill", "Annuler": "Cancel", "OK": "OK", "Action impossible": "Action not available",
        "Refusé": "Denied", "Process changé": "Process changed", "Échec": "Failed", "Langue": "Language",
        "Le process recevra SIGTERM, puis SIGKILL s'il ne répond pas.":
            "The process will receive SIGTERM, then SIGKILL if it doesn’t respond.",
        "Tuer « %@ » (PID %@) ?": "Kill “%@” (PID %@)?",
        "Le PID %@ ne correspond plus à « %@ » (réutilisé). Aucun kill effectué.":
            "PID %@ no longer matches “%@” (reused). No kill performed.",
        "Impossible de tuer « %@ » : %@": "Couldn’t kill “%@”: %@",
    ]

    static let ar: [String: String] = [
        "Réduire": "تصغير", "Détails": "تفاصيل", "Réduire en pastille": "تصغير إلى أيقونة",
        "Afficher le HUD": "إظهار الواجهة", "Masquer le HUD": "إخفاء الواجهة",
        "Local": "محلي", "Privé": "خاص", "100% local (vérifié en CI)": "محلي 100٪ (يُتحقق منه في CI)",
        "0 socket réseau ouvert": "لا يوجد اتصال شبكي مفتوح",
        "CPU": "المعالج", "RAM": "ذاكرة", "Disq": "قرص", "Rés": "شبكة", "Bat": "بطارية",
        "Temp": "حرارة", "vent. N/A": "المروحة: غير متاح", "cœurs": "أنوية", "CPU ·": "المعالج ·",
        "Mémoire": "الذاكرة", "Active": "نشطة", "Câblée": "مُقفلة", "Compressée": "مضغوطة",
        "Libre": "حرة", "Total": "الإجمالي", "Disque /": "القرص /", "Utilisé": "مستخدم",
        "Réseau par interface": "الشبكة حسب البطاقة", "Batterie": "البطارية", "Santé": "الصحة",
        "Cycles": "الدورات", "État": "الحالة", "Alimentation": "التغذية", "Secteur": "التيار الكهربائي",
        "PROCESSUS (TOP CPU)": "العمليات (الأعلى استهلاكًا للمعالج)", "Tuer ce process": "إنهاء هذه العملية",
        "Toujours au-dessus": "دائمًا في المقدمة", "Intervalle": "الفاصل الزمني", "Métriques": "المقاييس",
        "Disque": "القرص", "Réseau": "الشبكة", "Thermique (temp. + ventilo)": "الحرارة (الدرجة + المروحة)",
        "Lancer au login": "التشغيل عند تسجيل الدخول", "Quitter macOS State": "إنهاء macOS State",
        "Tuer": "إنهاء", "Annuler": "إلغاء", "OK": "موافق", "Action impossible": "تعذّر تنفيذ الإجراء",
        "Refusé": "مرفوض", "Process changé": "تغيّرت العملية", "Échec": "فشل", "Langue": "اللغة",
        "Le process recevra SIGTERM, puis SIGKILL s'il ne répond pas.":
            "ستتلقى العملية إشارة SIGTERM، ثم SIGKILL إن لم تستجب.",
        "Tuer « %@ » (PID %@) ?": "إنهاء «%@» (المعرّف %@)؟",
        "Le PID %@ ne correspond plus à « %@ » (réutilisé). Aucun kill effectué.":
            "المعرّف %@ لم يعد يطابق «%@» (أُعيد استخدامه). لم يُنفَّذ أي إنهاء.",
        "Impossible de tuer « %@ » : %@": "تعذّر إنهاء «%@»: %@",
    ]
}
