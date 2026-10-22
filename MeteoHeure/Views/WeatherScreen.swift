import SwiftUI

/// Écran « Météo » de la maquette :
///  - en-tête : ville (orange), date, grande température + condition\n    - bannière discrète de pluie à venir (« PAS DE PLUIE PRÉVUE — 24 H »)\n    - globe pointilliste centré sur la ville (dégradé pêche → bleu, marqueur orange)\n    - lever / durée / coucher du soleil et arc pointillé avec la position du soleil
struct WeatherScreen: View {
    @EnvironmentObject private var viewModel: LocationsViewModel
    @AppStorage("Orbisol.highLegibility") private var highLegibility = false
    @ScaledMetric(relativeTo: .largeTitle) private var temperatureSize: CGFloat = 58
    let location: Location
    let onForecast: () -> Void
    let onAddCity: () -> Void
    @State private var showRadar = false
    @State private var showHistory = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                topRow
                    .padding(.top, 14)
                rainBanner
                    .padding(.top, 12)
                Button(action: onForecast) { Label("Prévisions détaillées", systemImage: "chart.xyaxis.line") }
                    .font(.subheadline).padding(.vertical, 12)
                Button { showRadar = true } label: { Label("Radar de pluie", systemImage: "map") }.font(.subheadline)
                Button { showHistory = true } label: { Label("Historique météo", systemImage: "calendar") }.font(.subheadline).padding(.top, 8)
                GlobeView(location: location,
                          others: viewModel.locations.filter { $0.id != location.id })
                    .frame(maxWidth: 420)
                    .padding(.top, 2)
                sunSection
                    .padding(.top, 6)
                WeatherInsightsView(location: location)
                    .padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .simultaneousGesture(citySwipeGesture)
        .refreshable { await viewModel.refreshWeather(for: location, force: true) }
        .sheet(isPresented: $showRadar) {
            NavigationStack { RadarView(location: location).toolbar { Button("Fermer") { showRadar = false } } }
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack { HistoricalWeatherView(location: location).toolbar { Button("Fermer") { showHistory = false } } }
        }
    }

    // MARK: - Ligne ville / date / température

    private var topRow: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                cityPicker
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
                    .font(Theme.digit(highLegibility ? temperatureSize * 1.1 : temperatureSize, .bold))
                    .tracking(0)
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
                    .font(highLegibility ? .system(.subheadline, weight: .bold) : .system(size: 11.5, weight: .medium))
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

    /// Le nom de la ville sert de sélecteur sans alourdir l'en-tête météo.
    private var cityPicker: some View {
        Menu {
            Button(action: onAddCity) {
                Label("Ajouter une ville…", systemImage: "plus")
            }
            if !viewModel.locations.isEmpty {
                Divider()
            }
            ForEach(viewModel.locations) { city in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        viewModel.select(city.id)
                    }
                } label: {
                    if city.id == location.id {
                        Label(city.name, systemImage: "checkmark")
                    } else {
                        Text(city.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(location.name.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(2.4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Theme.accent)
            .frame(minHeight: 30)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Ville météo, \(location.name)")
        .accessibilityHint("Touchez pour choisir une autre ville")
    }

    /// Balayer horizontalement permet de parcourir rapidement les villes suivies.
    private var citySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 35)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.4,
                      abs(value.translation.width) > 55 else { return }
                selectAdjacentCity(direction: value.translation.width < 0 ? 1 : -1)
            }
    }

    private func selectAdjacentCity(direction: Int) {
        guard viewModel.locations.count > 1,
              let currentIndex = viewModel.locations.firstIndex(where: { $0.id == location.id }) else { return }
        let count = viewModel.locations.count
        let nextIndex = (currentIndex + direction + count) % count
        withAnimation(.easeInOut(duration: 0.22)) {
            viewModel.select(viewModel.locations[nextIndex].id)
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
            Text(viewModel.dataStatus(for: location).label.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1.3)
                    .foregroundStyle(isStale ? Theme.accent : Theme.dim)
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
        switch viewModel.dataStatus(for: location) {
        case .old, .offline, .unavailable: return true
        case .loading, .current: return false
        }
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
                .clockTypeface(16, weight: .semibold)
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

// MARK: - Globe pointilliste interactif

struct GlobeView: View {
    let location: Location
    let others: [Location]
    var date: Date = Date()
    @State private var longitudeOffset = 0.0
    @State private var latitudeOffset = 0.0
    @GestureState private var drag = CGSize.zero

    private func wrapped(_ value: Double) -> Double {
        (value + 180).truncatingRemainder(dividingBy: 360) < 0
            ? (value + 180).truncatingRemainder(dividingBy: 360) + 180
            : (value + 180).truncatingRemainder(dividingBy: 360) - 180
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                let sensitivity = 180 / max(geometry.size.width, 1)
                let centerLongitude = location.longitude + longitudeOffset - Double(drag.width * sensitivity)
                let centerLatitude = max(-85, min(85, location.latitude + latitudeOffset + Double(drag.height * sensitivity)))
                Canvas { context, size in
                    let radius = min(size.width, size.height) * 0.46
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let yaw = centerLongitude * .pi / 180
                    let pitch = centerLatitude * .pi / 180
                    let sy = sin(yaw), cy = cos(yaw)
                    let sp = sin(pitch), cp = cos(pitch)

                    func project(_ vector: GlobeLand.Point) -> (point: CGPoint, depth: Double) {
                        let x = vector.x * cy - vector.z * sy
                        let z = vector.x * sy + vector.z * cy
                        let y = vector.y * cp - z * sp
                        return (CGPoint(x: center.x + x * radius, y: center.y - y * radius),
                                vector.y * sp + z * cp)
                    }
                    func vector(_ lat: Double, _ lon: Double) -> GlobeLand.Point {
                        let a = lat * .pi / 180, b = lon * .pi / 180
                        return .init(x: cos(a) * sin(b), y: sin(a), z: cos(a) * cos(b))
                    }

                    let disk = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                     width: radius * 2, height: radius * 2))
                    context.fill(disk, with: .radialGradient(
                        Gradient(colors: [Theme.paper, Theme.ink.opacity(0.08)]),
                        center: CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.4),
                        startRadius: 0, endRadius: radius * 1.5))
                    context.stroke(disk, with: .color(Theme.ink.opacity(0.17)), lineWidth: 0.6)

                    // Clip each line at the horizon; never join across the hidden hemisphere.
                    func gridLine(_ samples: [GlobeLand.Point]) {
                        var line = Path()
                        var drawing = false
                        for sample in samples {
                            let p = project(sample)
                            if p.depth > 0 {
                                if drawing { line.addLine(to: p.point) } else { line.move(to: p.point) }
                                drawing = true
                            } else {
                                drawing = false
                            }
                        }
                        context.stroke(line, with: .color(Theme.ink.opacity(0.10)), lineWidth: 0.5)
                    }
                    for lat in stride(from: -60.0, through: 60.0, by: 30) {
                        gridLine(stride(from: -180.0, through: 180.0, by: 3).map { vector(lat, $0) })
                    }
                    for lon in stride(from: -180.0, to: 180.0, by: 30) {
                        gridLine(stride(from: -90.0, through: 90.0, by: 3).map { vector($0, lon) })
                    }

                    let sun = SolarPosition.sun(at: date)
                    let lat = sun.latitude * .pi / 180, lon = sun.longitude * .pi / 180
                    for sample in GlobeLand.points {
                        let p = project(sample)
                        guard p.depth > 0.015 else { continue }
                        let dot = radius * (0.0025 + 0.0035 * p.depth)
                        let illumination = sample.x * cos(lat) * sin(lon) + sample.y * sin(lat) + sample.z * cos(lat) * cos(lon)
                        context.fill(Path(ellipseIn: CGRect(x: p.point.x - dot, y: p.point.y - dot,
                                                             width: dot * 2, height: dot * 2)),
                                     with: .color(illumination > 0 ? Theme.accent.opacity(0.45 + p.depth * 0.45) : Theme.ink.opacity(0.16 + p.depth * 0.25)))
                    }
                    for city in others {
                        let p = project(vector(city.latitude, city.longitude))
                        guard p.depth > 0.02 else { continue }
                        context.fill(Path(ellipseIn: CGRect(x: p.point.x - 2, y: p.point.y - 2,
                                                             width: 4, height: 4)),
                                     with: .color(Theme.dim))
                    }
                    let selected = project(vector(location.latitude, location.longitude))
                    if selected.depth > 0.03 {
                        let p = selected.point
                        context.fill(Path(ellipseIn: CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)),
                                     with: .color(Theme.accent))
                        context.stroke(Path(ellipseIn: CGRect(x: p.x - 10, y: p.y - 10, width: 20, height: 20)),
                                       with: .color(Theme.accent.opacity(0.75)), lineWidth: 1.3)
                        context.draw(Text(location.name.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Theme.ink),
                            at: CGPoint(x: min(size.width - 45, max(45, p.x)), y: max(12, p.y - 20)))
                    }
                }
                .contentShape(Circle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .updating($drag) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            longitudeOffset = wrapped(longitudeOffset - Double(value.translation.width * sensitivity))
                            let latitude = max(-85, min(85, location.latitude + latitudeOffset + Double(value.translation.height * sensitivity)))
                            latitudeOffset = latitude - location.latitude
                        }
                )
                .accessibilityElement()
                .accessibilityLabel("Globe terrestre, " + location.name)
                .accessibilityHint("Balayez vers le haut ou le bas pour faire tourner le globe.")
                .accessibilityAdjustableAction { direction in
                    longitudeOffset = wrapped(longitudeOffset + (direction == .increment ? 25 : -25))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            HStack {
                Text("Glissez pour explorer")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.dim)
                Spacer()
                Button {
                    longitudeOffset = 0
                    latitudeOffset = 0
                } label: {
                    Label("Recentrer", systemImage: "location")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accent)
                        .frame(minHeight: 44)
                }
                .accessibilityLabel("Recentrer sur " + location.name)
            }
            .padding(.horizontal, 10)
        }
        .onChange(of: location.id) { _ in
            longitudeOffset = 0
            latitudeOffset = 0
        }
    }
}
