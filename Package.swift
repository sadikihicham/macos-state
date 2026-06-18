// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacOSState",
    platforms: [.macOS(.v14)],
    targets: [
        // Shim C : prototypes des fonctions IOHID privées (capteurs thermiques
        // Apple Silicon, non exposées dans les headers publics). Lecture seule.
        .target(name: "CIOHID"),

        // Cœur pur, sans UI : échantillonnage système + logique testable.
        .target(
            name: "SystemMetrics",
            dependencies: ["CIOHID"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),

        // Exécutable AppKit/SwiftUI : HUD flottant sur le bureau.
        .executableTarget(
            name: "MacOSStateApp",
            dependencies: ["SystemMetrics"]
        ),

        // Tests unitaires sur la lib pure (deltas, %, KillGuard, blacklist…).
        .testTarget(
            name: "SystemMetricsTests",
            dependencies: ["SystemMetrics"]
        ),
    ],
    // V1 : on reste en mode langage Swift 5 pour éviter la rigidité de la
    // concurrence stricte Swift 6 sur le code AppKit/main-actor. Durcissement
    // possible plus tard (Slice 4).
    swiftLanguageModes: [.v5]
)
