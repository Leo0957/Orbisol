import SwiftUI

// MARK: - Courbe des températures (24 h)
//
// Tracé lissé (courbes de Bézier par points Catmull-Rom) de la température
// heure par heure, avec remplissage dégradé et point « maintenant » en orange.

struct TemperatureCurveView: View {
    /// Prévisions horaires ordonnées (temps + température, °C).
    let forecasts: [HourlyForecast]
    /// Formatteur d'affichage local (fourni par la vue parente).
    var hourFormatter: (Date) -> String = { _ in "" }

    private var values: [Double] { forecasts.map(\.temperature) }

    var body: some View {
        Canvas { ctx, size in
            guard values.count > 1,
                  let minValue = values.min(), let maxValue = values.max() else { return }
            let span = max(maxValue - minValue, 1)
            let width = size.width
            let height = size.height
            let padding: CGFloat = 8

            func point(_ index: Int) -> CGPoint {
                let x = width * CGFloat(index) / CGFloat(values.count - 1)
                let normalized = CGFloat((values[index] - minValue) / span)
                let y = height - padding - normalized * (height - 2 * padding)
                return CGPoint(x: x, y: y)
            }

            var line = Path()
            line.move(to: point(0))
            // Catmull-Rom → Bézier pour un rendu lissé.
            for index in 0..<(values.count - 1) {
                let p0 = point(max(index - 1, 0))
                let p1 = point(index)
                let p2 = point(index + 1)
                let p3 = point(min(index + 2, values.count - 1))
                let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
                let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
                line.addCurve(to: p2, control1: c1, control2: c2)
            }

            // Remplissage dégradé sous la courbe.
            var fill = line
            fill.addLine(to: CGPoint(x: width, y: height))
            fill.addLine(to: CGPoint(x: 0, y: height))
            fill.closeSubpath()
            ctx.fill(fill, with: .linearGradient(
                Gradient(colors: [Theme.accent.opacity(0.22), Theme.accent.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: height)))

            ctx.stroke(line, with: .color(Theme.ink.opacity(0.85)), lineWidth: 1.8)

            // Min / max.
            if let minIndex = values.firstIndex(of: minValue), let maxIndex = values.firstIndex(of: maxValue) {
                let minP = point(minIndex), maxP = point(maxIndex)
                ctx.draw(Text("\(Int(minValue.rounded()))°")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.dim), at: CGPoint(x: minP.x + 2, y: minP.y - 10))
                ctx.draw(Text("\(Int(maxValue.rounded()))°")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.dim), at: CGPoint(x: maxP.x - 2, y: maxP.y + 14))
            }

            // Heures remarquables (minuit / midi) en pointillés.
            let calendar = Calendar.current
            for (index, forecast) in forecasts.enumerated() {
                let hour = calendar.component(.hour, from: forecast.date)
                if hour == 0 || hour == 12 {
                    let p = point(index)
                    var dash = Path()
                    dash.move(to: CGPoint(x: p.x, y: 0))
                    dash.addLine(to: CGPoint(x: p.x, y: height))
                    ctx.stroke(dash, with: .color(Theme.faint.opacity(0.7)),
                               style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                }
            }

            // Point « maintenant » (première prévision) en orange.
            let nowP = point(0)
            ctx.fill(Path(ellipseIn: CGRect(x: nowP.x - 4, y: nowP.y - 4, width: 8, height: 8)),
                     with: .color(Theme.accent))
            ctx.stroke(Path(ellipseIn: CGRect(x: nowP.x - 7, y: nowP.y - 7, width: 14, height: 14)),
                       with: .color(Theme.accent), lineWidth: 1.4)
        }
        .frame(height: 120)
    }
}

// MARK: - Sparkline générique (utilisée pour l'indice UV)

struct SparklineView: View {
    let values: [Double]

    var body: some View {
        Canvas { ctx, size in
            guard values.count > 1,
                  let minValue = values.min(), let maxValue = values.max() else { return }
            let span = max(maxValue - minValue, 0.1)
            let step = size.width / CGFloat(values.count - 1)

            var path = Path()
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * step
                let normalized = CGFloat((value - minValue) / span)
                let y = size.height - 2 - normalized * (size.height - 4)
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(path, with: .color(Theme.accent), lineWidth: 1.6)

            if let last = values.last {
                let x = size.width
                let normalized = CGFloat((last - minValue) / span)
                let y = size.height - 2 - normalized * (size.height - 4)
                ctx.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
                         with: .color(Theme.accent))
            }
        }
        .frame(height: 44)
    }
}
