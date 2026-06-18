import SwiftUI

/// Placeholder Slice 0 : enveloppe visuelle du HUD (fond translucide, titre).
/// Le contenu réel (jauges, détails, process) arrive en Slice 1+.
struct HUDView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .foregroundStyle(.secondary)
                Text("macOS State")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
            }
            Divider().opacity(0.4)
            Text("Initialisation…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}
