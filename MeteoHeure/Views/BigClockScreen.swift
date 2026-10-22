import SwiftUI

/// Écran « Grand format » de la maquette : l'horloge en très gros.
/// En-tête (ville / pays / UTC), trois bandes empilées (heures / minutes /
/// secondes) séparées par des filets fins, chiffres monospaces, puis un
/// cadran radial en bas : l'arc pointillé de la « journée » avec les autres
/// villes suivies autour de la ville sélectionnée (marquée en orange).
struct BigClockScreen: View {
    @EnvironmentObject private var viewModel: LocationsViewModel
    let location: Location
    @AppStorage("Orbisol.clock.seconds") private var showSeconds = true
    @AppStorage("Orbisol.clock.date") private var showDate = true
    @AppStorage("Orbisol.clock.weather") private var showWeather = true
    @AppStorage("Orbisol.clock.nightAuto") private var nightAuto = false
    @State private var showNight = false
    private var nightTime: Bool { Calendar.current.component(.hour, from: viewModel.now) >= 22 || Calendar.current.component(.hour, from: viewModel.now) < 8 }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 12) {
                    Button { showNight = true } label: { Label("Mode nuit", systemImage: "moon.fill") }
                    if geometry.size.width > geometry.size.height {
                        header
                        Text(hourText + ":" + minuteText + (showSeconds ? ":" + secondText : ""))
                            .clockTypeface(90, weight: .light).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.4)
                            .frame(maxWidth: .infinity)
                    } else {
                        portraitClock
                    }
                    if showDate {
                        Text(localDate).font(.headline).foregroundStyle(Theme.dim)
                    }
                    if showWeather, let current = viewModel.weatherByLocation[location.id]?.current {
                        Label("\(viewModel.tempText(current.temperature2m, for: location)) · \(WeatherStyle.shortCondition(code: current.weatherCode))",
                              systemImage: WeatherStyle.symbol(code: current.weatherCode, isDay: current.isDay == 1))
                            .font(.subheadline).foregroundStyle(Theme.dim)
                    }
                }.padding(.bottom, 16)
            }
        }
        .fullScreenCover(isPresented: $showNight) { NightClockView(location: location) }
        .onAppear { if nightAuto && nightTime { showNight = true } }
        .onChange(of: nightTime) { if nightAuto { showNight = $0 } }
    }

    private var localDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = location.timeZone ?? .current
        formatter.dateStyle = .full
        return formatter.string(from: viewModel.now)
    }

    private var portraitClock: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 0) {
                band(hourText, unit: "h", weight: .ultraLight,
                     color: Theme.faint, size: 100, pad: false)
                hairline
                band(minuteText, unit: "min", weight: .light,
                     color: Theme.dim, size: 100, pad: true)
                if showSeconds {
                    hairline
                    band(secondText, unit: "sec", weight: .bold,
                         color: Theme.ink, size: 78, pad: true)
                }
            }
            .padding(.top, 12)

            Spacer(minLength: 0)
            dial
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name.uppercased())
                    .font(.system(size: 21, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink)
                Text(location.countrySubtitle)
                    .font(.system(size: 13, weight: .regular))
                    .tracking(0.3)
                    .foregroundStyle(Theme.dim)
            }
            Spacer()
            Text(ClockFormat.utcLabel(timeZone: location.timeZone ?? .current))
                .font(.system(size: 14, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.accent)
        }
    }

    private var hairline: some View {
        Rectangle().fill(Theme.line).frame(height: 1)
    }

    private func band(_ value: String, unit: String, weight: Font.Weight,
                      color: Color, size: CGFloat, pad: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(value)
                .clockTypeface(size, weight: weight)
                .tracking(2)
                .monospacedDigit()
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 14, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.dim)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.leading, pad ? 16 : 0)
    }

    // MARK: - Valeurs (mises à jour via viewModel.now, chaque seconde)

    private var parts: (hour: Int, minute: Int, second: Int) {
        ClockFormat.parts(timeZone: location.timeZone ?? .current, date: viewModel.now)
    }
    private var hourText: String {
        var hour = parts.hour
        if viewModel.hour12 {
            hour = hour % 12
            if hour == 0 { hour = 12 }
        }
        return String(format: "%02d", hour)
    }
    private var minuteText: String { String(format: "%02d", parts.minute) }
    private var secondText: String { String(format: "%02d", parts.second) }

    // MARK: - Cadran radial (position relative des villes)

    private var dial: some View {
        VStack(spacing: 4) {
            Canvas { ctx, size in
                let cx = size.width / 2
                let radius = min(size.width * 0.44, CGFloat(168))
                let apexY: CGFloat = 34
                let cy = apexY + radius
                let selectedMinutes = minutesOfDay(location)
                let otherCities = viewModel.locations.filter { $0.id != location.id }

                // Arc de base (de -176° à -4° : gauche → sommet → droite).
                var arc = Path()
                arc.addArc(center: CGPoint(x: cx, y: cy),
                           radius: radius,
                           startAngle: .degrees(-176),
                           endAngle: .degrees(-4),
                           clockwise: false)
                ctx.stroke(arc, with: .color(Theme.ink.opacity(0.55)),
                           style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [0.1, 6]))

                // Graduations toutes les 3 h (fines, discrètes).
                for hour in stride(from: 0, through: 21, by: 3) {
                    guard let angle = angleFor(deltaHours: Double(hour) - Double(selectedMinutes) / 60) else { continue }
                    let inner = radius - 6
                    let p1 = CGPoint(x: cx + cos(angle) * radius, y: cy + sin(angle) * radius)
                    let p2 = CGPoint(x: cx + cos(angle) * inner, y: cy + sin(angle) * inner)
                    var tick = Path()
                    tick.move(to: p1)
                    tick.addLine(to: p2)
                    ctx.stroke(tick, with: .color(Theme.ink.opacity(0.28)), lineWidth: 1)
                }

                // Villes suivies (autour de la sélectionnée).
                for city in otherCities {
                    let deltaHours = (Double(minutesOfDay(city) - selectedMinutes)) / 60
                    guard let angle = angleFor(deltaHours: deltaHours) else { continue }
                    let p = CGPoint(x: cx + cos(angle) * radius, y: cy + sin(angle) * radius)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.6, y: p.y - 2.6, width: 5.2, height: 5.2)),
                             with: .color(Theme.ink.opacity(0.65)))
                    ctx.draw(Text(ClockFormat.code3(city.name))
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(Theme.dim),
                             at: CGPoint(x: p.x, y: p.y - 14))
                }

                // Fuseau central (méridien) sous la ville sélectionnée.
                var meridian = Path()
                meridian.move(to: CGPoint(x: cx, y: apexY + radius * 0.55))
                meridian.addLine(to: CGPoint(x: cx, y: size.height - 2))
                ctx.stroke(meridian, with: .color(Theme.ink.opacity(0.18)),
                           style: StrokeStyle(lineWidth: 1, dash: [1.5, 6]))

                // Ville sélectionnée : point orange au sommet + anneau.
                let top = CGPoint(x: cx, y: apexY)
                ctx.fill(Path(ellipseIn: CGRect(x: top.x - 5, y: top.y - 5, width: 10, height: 10)),
                         with: .color(Theme.accent))
                ctx.stroke(Path(ellipseIn: CGRect(x: top.x - 11.5, y: top.y - 11.5, width: 23, height: 23)),
                           with: .color(Theme.accent), lineWidth: 1.6)
                ctx.draw(Text(ClockFormat.code3(location.name))
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(Theme.ink),
                         at: CGPoint(x: top.x, y: top.y - 26))
            }
            .frame(height: 196)

            Text(location.name.uppercased())
                .font(.system(size: 11.5, weight: .bold))
                .tracking(3.4)
                .foregroundStyle(Theme.ink)
            Circle().fill(Theme.accent).frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity)
    }

    /// Angle (radians) d'un écart en heures, borné à la portion d'arc affichée
    /// (≈ ±8 h : toutes les villes restent sur le cadran).
    private func angleFor(deltaHours: Double) -> Double? {
        var delta = deltaHours
        while delta > 12 { delta -= 24 }
        while delta < -12 { delta += 24 }
        let degrees = -90 + delta * 10.5
        guard degrees >= -176, degrees <= -4 else { return nil }
        return degrees * .pi / 180
    }

    private func minutesOfDay(_ city: Location) -> Int {
        let p = ClockFormat.parts(timeZone: city.timeZone ?? .current, date: viewModel.now)
        return p.hour * 60 + p.minute
    }
}
