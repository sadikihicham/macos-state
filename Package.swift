// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacOSState",
    platforms: [.macOS(.v14)],
    targets: [
        // Cœur pur, sans UI : échantillonnage système + logique testable.
        .target(name: "SystemMetrics"),

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
