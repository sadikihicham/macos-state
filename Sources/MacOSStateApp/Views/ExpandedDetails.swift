import SwiftUI
import SystemMetrics

/// Section "développée" : détails par métrique sous les jauges.
struct ExpandedDetails: View {
    let s: MetricsSnapshot
    @AppStorage("app.lang") private var lang = "fr"
    private func tr(_ x: String) -> String { L.t(x, lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Divider().opacity(0.35)
            cpuCores
            memoryBreakdown
            diskDetail
            if !s.interfaces.isEmpty { networkDetail }
            if let b = s.battery { batteryDetail(b) }
        }
    }

    // MARK: CPU par cœur (grille de mini-barres)
    private var cpuCores: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("\(tr("CPU ·")) \(s.cpuCores.count) \(tr("cœurs"))")
            let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
            LazyVGrid(columns: cols, spacing: 4) {
                ForEach(Array(s.cpuCores.enumerated()), id: \.offset) { _, v in
                    BarGauge(value: v)
                }
            }
        }
    }

    // MARK: Ventilation mémoire
    private var memoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 3) {
            sectionTitle("Mémoire")
            kv("Active", Metrics.formatBytes(Double(s.memActive)))
            kv("Câblée", Metrics.formatBytes(Double(s.memWired)))
            kv("Compressée", Metrics.formatBytes(Double(s.memCompressed)))
            kv("Libre", Metrics.formatBytes(Double(s.memFree)))
            kv("Total", Metrics.formatBytes(Double(s.memoryTotalBytes)))
        }
    }

    private var diskDetail: some View {
        VStack(alignment: .leading, spacing: 3) {
            sectionTitle("Disque /")
            kv("Utilisé", Metrics.formatBytes(Double(s.diskUsedBytes)))
            kv("Libre", Metrics.formatBytes(Double(s.diskFreeBytes)))
            kv("Total", Metrics.formatBytes(Double(s.diskTotalBytes)))
        }
    }

    private var networkDetail: some View {
        VStack(alignment: .leading, spacing: 3) {
            sectionTitle("Réseau par interface")
            ForEach(s.interfaces) { i in
                HStack(spacing: 6) {
                    Text(i.id).font(.system(size: 10, weight: .medium, design: .monospaced))
                        .frame(width: 42, alignment: .leading)
                    Label(Metrics.formatRate(i.down), systemImage: "arrow.down")
                        .foregroundStyle(.green)
                    Spacer(minLength: 2)
                    Label(Metrics.formatRate(i.up), systemImage: "arrow.up")
                        .foregroundStyle(.orange)
                }
                .font(.system(size: 10, design: .rounded)).monospacedDigit()
                .labelStyle(.titleAndIcon)
            }
        }
    }

    private func batteryDetail(_ b: BatteryInfo) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            sectionTitle("Batterie")
            if let h = b.healthPercent { kv("Santé", "\(h)%") }
            if let c = b.cycleCount { kv("Cycles", "\(c)") }
            if let cond = b.condition { kv("État", cond) }
            kv("Alimentation", b.isPluggedIn ? "Secteur" : "Batterie")
        }
    }

    // MARK: helpers
    private func sectionTitle(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
    }

    private func kv(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer()
            Text(v).font(.system(size: 10, weight: .medium, design: .rounded)).monospacedDigit()
        }
    }
}
