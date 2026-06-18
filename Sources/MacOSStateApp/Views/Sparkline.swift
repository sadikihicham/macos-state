import SwiftUI

/// Mini-courbe d'historique (valeurs déjà normalisées [0...1], plus ancien →
/// plus récent). Remplissage léger sous la ligne pour la lisibilité.
struct Sparkline: View {
    let values: [Double]
    var color: Color = .green
    var height: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            if values.count > 1 {
                let pts = points(in: CGSize(width: w, height: h))
                ZStack {
                    // aire
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: h))
                        pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: h))
                        p.closeSubpath()
                    }
                    .fill(color.opacity(0.16))
                    // ligne
                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(height: height)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        let step = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) * step,
                    y: size.height * (1 - CGFloat(min(1, max(0, v)))))
        }
    }
}
