import SwiftUI
import SystemMetrics

/// HUD — mode réduit (jauges) ⇄ développé (détails). Le bouton chevron bascule
/// l'état persisté ; le panneau se redimensionne via `onResize`.
struct HUDView: View {
    @ObservedObject var engine: MetricsEngine
    /// Notifie l'hôte AppKit de la taille idéale pour redimensionner le panneau.
    var onResize: (CGSize) -> Void = { _ in }

    @AppStorage("hud.expanded") private var expanded = false

    private var s: MetricsSnapshot { engine.snapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            header
            Divider().opacity(0.35)

            MetricRow(icon: "cpu", label: "CPU", value: s.cpu,
                      trailing: percent(s.cpu))
            MetricRow(icon: "memorychip", label: "RAM", value: s.memory,
                      trailing: percent(s.memory))
            MetricRow(icon: "internaldrive", label: "Disq", value: s.disk,
                      trailing: percent(s.disk))

            networkRow
            if let b = s.battery { batteryRow(b) }

            if expanded { ExpandedDetails(s: s) }
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
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "gauge.with.dots.needle.50percent")
                .foregroundStyle(.secondary)
            Text("macOS State")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
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
