import SwiftUI

/// Écran « Météo » de la maquette :
///  - en-tête : ville (orange), date, grande température + condition\n    - bannière discrète de pluie à venir (« PAS DE PLUIE PRÉVUE — 24 H »)\n    - globe pointilliste centré sur la ville (dégradé pêche → bleu, marqueur orange)\n    - lever / durée / coucher du soleil et arc pointillé avec la position du soleil
struct WeatherScreen: View {
    @EnvironmentObject private var viewModel: LocationsViewModel
    let location: Location
    let onForecast: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                topRow
                    .padding(.top, 14)
                rainBanner
                    .padding(.top, 12)
                GlobeView(location: location,
                          others: viewModel.locations.filter { $0.id != location.id })
                    .frame(width: 300, height: 300)
                    .padding(.top, 2)
                sunSection
                    .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Ligne ville / date / température

    private var topRow: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(Theme.accent)
                Text(dayLine)
                    .font(Theme.label(15, .semibold))
                    .foregroundStyle(Theme.dim)
                Text(monthLine)
                    .font(Theme.label(15, .semibold))
                    .foregroundStyle(Theme.dim)
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 3) {
                Text(tempDigits)
                    .font(Theme.digit(58, .bold))
                    .tracking(-1)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .contextMenu {
                        Button { viewModel.setUnitFor(location, fahrenheit: false) } label: {
                            Label("°C pour \(location.name)", systemImage: "thermometer")
                        }
                        Button { viewModel.setUnitFor(location, fahrenheit: true) } label: {
                            Label("°F pour \(location.name)", systemImage: "thermometer")
                        }
                        Divider()
                        Button { viewModel.setUnitFor(location, fahrenheit: nil) } label: {
                            Label("Suivre le réglage global", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                Text(conditionLine)
                    .font(.system(size: 11.5, weight: .medium))
                    .tracking(1.4)
                    .foregroundStyle(Theme.dim)
            }
            .contentShape(Rectangle())
            .onTapGesture { onForecast() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(tempDigits), \(conditionLine), prévisions")
            .accessibilityAddTraits(.isButton)
        }
    }

    // MARK: - Bannière pluie + fraîcheur

    private var rainBanner: some View {
        VStack(spacing: 3) {
            if !rainLine.isEmpty {
                Text(rainLine)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.7)
                    .foregroundStyle(rainLineColor)
            }
            if isStale, let freshness = viewModel.freshnessText(for: location) {
                Text(freshness.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.3)
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var rainLine: String {
        switch viewModel.nextRain(for: location) {
        case .unknown: return ""
        case .none: return "PAS DE PLUIE PRÉVUE — 24 H"
        case .soon(let probability, let hour):
            return "PLUIE VERS \(ClockFormat.shortHour(hour: hour, hour12: viewModel.hour12).uppercased()) · \(probability) %"
        }
    }

    private var rainLineColor: Color {
        if case .soon = viewModel.nextRain(for: location) { return Theme.accent }
        return Theme.dim
    }

    private var isStale: Bool {
        guard let date = viewModel.lastFetchDate(for: location) else { return false }
        return Date().timeIntervalSince(date) > 30 * 60
    }

    private var dayLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE,"
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = location.timeZone ?? .current
        let value = formatter.string(from: viewModel.now)
        return value.prefix(1).uppercased() + value.dropFirst()
    }
    private var monthLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = location.timeZone ?? .current
        let value = formatter.string(from: viewModel.now)
        return value.prefix(1).uppercased() + value.dropFirst()
    }
    private var tempDigits: String {
        guard let current = viewModel.weatherByLocation[location.id]?.current else { return "--°" }
        return viewModel.tempText(current.temperature2m, for: location)
    }
    private var conditionLine: String {
        guard let current = viewModel.weatherByLocation[location.id]?.current else { return "Chargement…" }
        return WeatherStyle.shortCondition(code: current.weatherCode).uppercased()
    }

    // MARK: - Lever / durée / coucher + arc

    private var sunSection: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 0) {
                sunColumn(icon: "sun.max.fill",
                          value: sunValue(wx?.daily?.sunrise?.first),
                          label: "lever", align: .leading)
                sunColumn(icon: nil,
                          value: dayLength,
                          label: "durée", align: .center)
                sunColumn(icon: "sunset.fill",
                          value: sunValue(wx?.daily?.sunset?.first),
                          label: "coucher", align: .trailing)
            }
            sunArc
        }
    }

    private func sunColumn(icon: String?, value: String, label: String,
                           align: HorizontalAlignment) -> some View {
        VStack(spacing: 3) {
            Group {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.accent)
                } else {
                    Color.clear.frame(height: 16)
                }
            }
            .frame(height: 18)
            Text(value)
                .font(Theme.digit(16, .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.8)
                .foregroundStyle(Theme.dim)
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: align, vertical: .center))
    }

    /// Durée du jour (entre lever et coucher du soleil).
    private var dayLength: String {
        guard let sunrise = wx?.daily?.sunrise?.first,
              let sunset = wx?.daily?.sunset?.first else { return "--" }
        func minutes(_ iso: String) -> Int? {
            let hhmm = String(iso.dropFirst(11).prefix(5)).split(separator: ":")
            guard hhmm.count == 2, let h = Int(hhmm[0]), let m = Int(hhmm[1]) else { return nil }
            return h * 60 + m
        }
        guard let start = minutes(sunrise), let end = minutes(sunset), end > start else { return "--" }
        let total = end - start
        return "\(total / 60) h \(String(format: "%02d", total % 60))"
    }

    private var wx: OpenMeteoResponse? { viewModel.weatherByLocation[location.id] }

    /// Heure de lever / coucher, toujours au format 24 h (comme la maquette).
    private func sunValue(_ iso: String?) -> String {
        guard let iso else { return "--:--" }
        return String(iso.dropFirst(11).prefix(5))
    }

    // MARK: - Arc pointillé avec position du soleil

    private var sunArc: some View {
        Canvas { ctx, size in
            let width = size.width
            let height = size.height
            let p0 = CGPoint(x: 0, y: height * 0.86)
            let c1 = CGPoint(x: width * 0.3, y: height * 0.06)
            let c2 = CGPoint(x: width * 0.7, y: height * 0.06)
            let p3 = CGPoint(x: width, y: height * 0.86)

            var path = Path()
            path.move(to: p0)
            path.addCurve(to: p3, control1: c1, control2: c2)
            ctx.stroke(path, with: .color(Theme.ink.opacity(0.6)),
                       style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [0.1, 8.5]))

            // Point sur la courbe de Bézier cubique (position du soleil).
            let t = sunProgress
            let mt = 1 - t
            let point = CGPoint(
                x: mt * mt * mt * p0.x + 3 * mt * mt * t * c1.x + 3 * mt * t * t * c2.x + t * t * t * p3.x,
                y: mt * mt * mt * p0.y + 3 * mt * mt * t * c1.y + 3 * mt * t * t * c2.y + t * t * t * p3.y)
            ctx.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)),
                     with: .color(Theme.accent))
        }
        .frame(height: 52)
    }

    private var sunProgress: CGFloat {
        guard let sunrise = wx?.daily?.sunrise?.first,
              let sunset = wx?.daily?.sunset?.first else { return 0 }
        func minutes(_ iso: String) -> Int? {
            let hhmm = String(iso.dropFirst(11).prefix(5)).split(separator: ":")
            guard hhmm.count == 2, let h = Int(hhmm[0]), let m = Int(hhmm[1]) else { return nil }
            return h * 60 + m
        }
        guard let rise = minutes(sunrise), let set = minutes(sunset), set > rise else { return 0 }
        let p = ClockFormat.parts(timeZone: location.timeZone ?? .current, date: viewModel.now)
        let now = p.hour * 60 + p.minute
        let t = CGFloat(now - rise) / CGFloat(set - rise)
        return max(0, min(1, t))
    }
}

// MARK: - Globe pointilliste

/// Globe de points (grille latitude / longitude projetée) posé sur un disque
/// en dégradé doux pêche → bleu, comme sur la maquette. La ville sélectionnée
/// est marquée d'un point orange cerclé, les autres d'un point gris discret.
struct GlobeView: View {
    let location: Location
    let others: [Location]

    var body: some View {
        ZStack {
            backdrop
            Canvas { ctx, size in
                let width = size.width
                let height = size.height
                let radius = min(width, height) * 0.43
                let cx = width / 2
                let cy = height / 2
                let rotation = -location.longitude * .pi / 180

                func project(_ lat: Double, _ lon: Double) -> (x: CGFloat, y: CGFloat, z: Double) {
                    let la = lat * .pi / 180
                    let lo = lon * .pi / 180 + rotation
                    let x = cos(la) * sin(lo)
                    let y = sin(la)
                    let z = cos(la) * cos(lo)
                    return (cx + x * radius, cy - y * radius, z)
                }

                // Grille de points, plus denses et plus sombres au centre.
                for lat in stride(from: -80.0, through: 80.0, by: 6.5) {
                    for lon in stride(from: -180.0, to: 180.0, by: 6.5) {
                        let p = project(lat, lon)
                        guard p.z > 0.02 else { continue }
                        let alpha = 0.12 + p.z * 0.40
                        let dot = 1.0 + p.z * 1.25
                        ctx.fill(Path(ellipseIn: CGRect(x: p.x - dot, y: p.y - dot,
                                                        width: dot * 2, height: dot * 2)),
                                 with: .color(Theme.ink.opacity(alpha)))
                    }
                }

                // Les autres villes suivies : simples points gris foncé.
                for city in others {
                    let p = project(city.latitude, city.longitude)
                    guard p.z > 0 else { continue }
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)),
                             with: .color(Theme.ink.opacity(0.55)))
                }

                // Ville sélectionnée : point orange + anneau concentrique.
                let selected = project(location.latitude, location.longitude)
                if selected.z > 0 {
                    ctx.fill(Path(ellipseIn: CGRect(x: selected.x - 5.5, y: selected.y - 5.5,
                                                    width: 11, height: 11)),
                             with: .color(Theme.accent))
                    ctx.stroke(Path(ellipseIn: CGRect(x: selected.x - 12, y: selected.y - 12,
                                                      width: 24, height: 24)),
                               with: .color(Theme.accent.opacity(0.85)), lineWidth: 1.6)
                }
            }
        }
    }

    /// Disque doux pêche (haut-gauche) → bleu-gris (bas-droite), bord fondu.
    private var backdrop: some View {
        Circle()
            .fill(LinearGradient(colors: [
                Color(red: 0.99, green: 0.82, blue: 0.60).opacity(0.85),
                Color(red: 0.78, green: 0.87, blue: 0.97).opacity(0.6)
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 276, height: 276)
            .mask(Circle().fill(RadialGradient(colors: [Color.white.opacity(0.95),
                                                        Color.white.opacity(0.0)],
                                               center: .center,
                                               startRadius: 60, endRadius: 138)))
    }
}
