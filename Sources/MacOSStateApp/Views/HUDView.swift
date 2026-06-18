import SwiftUI
import SystemMetrics

/// HUD — mode réduit (jauges) ⇄ développé (détails). Le bouton chevron bascule
/// l'état persisté ; le panneau se redimensionne via `onResize`.
struct HUDView: View {
    @ObservedObject var engine: MetricsEngine
    /// Notifie l'hôte AppKit de la taille idéale pour redimensionner le panneau.
    var onResize: (CGSize) -> Void = { _ in }
    /// Demande de kill remontée à l'hôte AppKit (qui affiche la confirmation).
    var onKillRequest: (ProcSample) -> Void = { _ in }

    @AppStorage("hud.expanded") private var expanded = false
    // Visibilité par métrique (synchronisée avec le menu via UserDefaults).
    @AppStorage("hud.show.cpu") private var showCPU = true
    @AppStorage("hud.show.ram") private var showRAM = true
    @AppStorage("hud.show.disk") private var showDisk = true
    @AppStorage("hud.show.net") private var showNet = true
    @AppStorage("hud.show.battery") private var showBattery = true

    private var s: MetricsSnapshot { engine.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            header
            Divider().opacity(0.35)

            if showCPU {
                MetricRow(icon: "cpu", label: "CPU", value: s.cpu, trailing: percent(s.cpu))
            }
            if showRAM {
                MetricRow(icon: "memorychip", label: "RAM", value: s.memory, trailing: percent(s.memory))
            }
            if showDisk {
                MetricRow(icon: "internaldrive", label: "Disq", value: s.disk, trailing: percent(s.disk))
            }
            if showNet { networkRow }
            if showBattery, let b = s.battery { batteryRow(b) }

            if expanded {
                Divider().opacity(0.35)
                networkProofRow
                ExpandedDetails(s: s)
                if !engine.processes.isEmpty {
                    Divider().opacity(0.35)
                    ProcessListView(
                        processes: engine.processes,
                        decide: { engine.processController.decide($0) },
                        onKill: onKillRequest
                    )
                }
            }
        }
        .padding(12)
        .frame(width: 232, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .fixedSize()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { onResize($0) }
        .onAppear { engine.processListingEnabled = expanded }
        .onChange(of: expanded) { _, now in engine.processListingEnabled = now }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .foregroundStyle(.secondary)
            Text("macOS State")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            localSeal
            Spacer()
            Button {
                expanded.toggle()
            } label: {
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(expanded ? "Réduire" : "Détails")
        }
    }

    /// Sceau différenciateur : l'app est 100% locale, sans aucune capacité réseau.
    /// Adossé à l'invariant vérifié en CI (`make check-net`) ET à une preuve runtime
    /// (sockets réellement ouverts) — une garantie qu'un moniteur qui « téléphone
    /// dehors » ne peut pas afficher honnêtement.
    private var localSeal: some View {
        HStack(spacing: 2) {
            Image(systemName: s.openSockets == 0 ? "lock.shield.fill" : "lock.shield")
                .font(.system(size: 8))
            Text("Local").font(.system(size: 8, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 4).padding(.vertical, 1)
        .background(.green.opacity(0.14), in: Capsule())
        .help(sealTooltip)
        .accessibilityLabel("Application 100% locale, sans accès réseau")
    }

    private var sealTooltip: String {
        let base = "100% local — invariant vérifié en CI (make check-net)."
        switch s.openSockets {
        case 0:  return "Preuve en direct : 0 socket réseau ouvert. " + base
        case let n?: return "\(n) socket(s) ouvert(s). " + base
        case nil: return base
        }
    }

    /// Ligne de preuve tangible (mode développé) : nombre de sockets réseau
    /// réellement ouverts par l'app, lu en direct via libproc.
    private var networkProofRow: some View {
        HStack(spacing: 7) {
            Image(systemName: "lock.shield").font(.system(size: 10))
                .foregroundStyle(.green).frame(width: 13)
            Text("Privé").font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
            if let n = s.openSockets {
                Image(systemName: n == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 9)).foregroundStyle(n == 0 ? .green : .orange)
                Text(n == 0 ? "0 socket réseau ouvert" : "\(n) socket(s) ouvert(s)")
                    .font(.system(size: 10, design: .rounded)).monospacedDigit()
                    .foregroundStyle(n == 0 ? .green : .orange)
            } else {
                Text("100% local (vérifié en CI)")
                    .font(.system(size: 10, design: .rounded)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
        }
    }

    private var networkRow: some View {
        HStack(spacing: 7) {
            Image(systemName: "network").font(.system(size: 10))
                .foregroundStyle(.secondary).frame(width: 13)
            Text("Rés").font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
            Label(Metrics.formatRate(s.netDown), systemImage: "arrow.down")
                .font(.system(size: 10, design: .rounded)).monospacedDigit()
                .foregroundStyle(.green)
            Spacer(minLength: 4)
            Label(Metrics.formatRate(s.netUp), systemImage: "arrow.up")
                .font(.system(size: 10, design: .rounded)).monospacedDigit()
                .foregroundStyle(.orange)
        }
        .labelStyle(.titleAndIcon)
    }

    private func batteryRow(_ b: BatteryInfo) -> some View {
        HStack(spacing: 7) {
            Image(systemName: batteryIcon(b)).font(.system(size: 10))
                .foregroundStyle(b.percent <= 20 && !b.isPluggedIn ? .red : .secondary)
                .frame(width: 13)
            Text("Bat").font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
            Text("\(b.percent)%")
                .font(.system(size: 10, weight: .semibold, design: .rounded)).monospacedDigit()
            if b.isCharging { Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(.yellow) }
            Spacer(minLength: 4)
            Text(b.minutesRemaining >= 0 ? Metrics.formatMinutes(b.minutesRemaining) : "—")
                .font(.system(size: 10, design: .rounded)).monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private func batteryIcon(_ b: BatteryInfo) -> String {
        if b.isCharging || b.isPluggedIn { return "battery.100.bolt" }
        switch b.percent {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default:    return "battery.100"
        }
    }

    private func percent(_ v: Double) -> String {
        "\(Int((v * 100).rounded()))%"
    }
}
