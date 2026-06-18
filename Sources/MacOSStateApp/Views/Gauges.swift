import SwiftUI

/// Couleur d'alerte selon le taux d'utilisation (vert/jaune/rouge).
func loadColor(_ value: Double) -> Color {
    switch value {
    case ..<0.60: return .green
    case ..<0.85: return .yellow
    default:      return .red
    }
}

/// Barre de progression fine et arrondie.
struct BarGauge: View {
    let value: Double // 0...1
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.14))
                Capsule()
                    .fill(loadColor(value))
                    .frame(width: max(2, geo.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 6)
    }
}

/// Ligne métrique compacte : libellé + barre + valeur (%).
struct MetricRow: View {
    let icon: String
    let label: String
    let value: Double
    var trailing: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 13)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
            BarGauge(value: value)
            Text(trailing)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .frame(width: 42, alignment: .trailing)
        }
    }
}
