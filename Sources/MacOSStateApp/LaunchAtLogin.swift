import Foundation
import ServiceManagement

/// Lancement au login via SMAppService (macOS 13+). Ne fonctionne que pour le
/// .app bundlé et signé (pas le binaire brut lancé en dev) — échec silencieux sinon.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("macOS State — LaunchAtLogin (\(enabled)) a échoué : \(error.localizedDescription)")
        }
    }
}
