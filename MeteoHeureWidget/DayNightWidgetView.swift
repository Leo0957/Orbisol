import SwiftUI
import WidgetKit

// MARK: - Palette du widget « Jour · Nuit »
//
// Calquée sur `Theme` de l'application (Orbisol) : papier chaud,
// encre, gris doux et orange cuivre. Les couleurs « jour »/« nuit »
// descendent de cette identité — jamais de bleu générique.

enum WidgetPalette {
    static let paper        = adaptive(light: UIColor(white: 0.918, alpha: 1), dark: UIColor(white: 0.09, alpha: 1))
    static let paperBright  = adaptive(light: UIColor(white: 0.965, alpha: 1), dark: UIColor(white: 0.16, alpha: 1))
    static let ink          = adaptive(light: UIColor(white: 0.10, alpha: 1), dark: UIColor(white: 0.95, alpha: 1))
    static let dim          = adaptive(light: UIColor(white: 0.45, alpha: 1), dark: UIColor(white: 0.70, alpha: 1))
    static let faint        = Color(red: 0.76,  green: 0.75,  blue: 0.72)
    static let line         = Color(red: 0.84,  green: 0.83,  blue: 0.80)
    static let accent       = Color(red: 0.890, green: 0.537, blue: 0.114) // orange cuivre
    static let sun          = Color(red: 0.98,  green: 0.62,  blue: 0.22)  // éclat solaire
    static let night        = Color(red: 0.35,  green: 0.34,  blue: 0.31)  // brun-gris de nuit
    static let veil         = Color(red: 0.56,  green: 0.545, blue: 0.50)  // voile nuit
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

// MARK: - Astronomie solaire
//
// Tout est calculé localement, sans réseau : point subsolaire (date UTC),
// déclinaison solaire, équation du temps, puis « bande éclairée » de
// chaque méridien — c'est cette bande qui pilote le terminateur réel.

enum SunMath {

    /// Point subsolaire (latitude, longitude) : endroit où le Soleil est au zénith.
    static func subsolarPoint(at date: Date) -> (lat: Double, lon: Double) {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let components = utc.dateComponents([.hour, .minute, .second], from: date)
        let dayOfYear = utc.ordinality(of: .day, in: .year, for: date) ?? 1
        let hour = Double(components.hour ?? 0)
            + Double(components.minute ?? 0) / 60.0
            + Double(components.second ?? 0) / 3600.0

        // Angle fractionnaire de l'année (approximation NOAA/NREL).
        let gamma = 2.0 * .pi / 365.0 * (Double(dayOfYear) - 1.0 + (hour - 12.0) / 24.0)

        // Déclinaison solaire (radians).
        let declination = 0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma)
            + 0.00148  * sin(3 * gamma)

        // Équation du temps (minutes) → correction de longitude du zénith.
        let equationOfTime = 229.18 * (0.000075
            + 0.001868 * cos(gamma)
            - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma)
            - 0.040849 * sin(2 * gamma))

        let longitude = 15.0 * (12.0 - hour) - equationOfTime / 4.0
        return (declination * 180.0 / .pi, longitude)
    }

    /// De 1.0 (plein jour) à 0.0 (nuit), transition douce autour du crépuscule (~±2°).
    static func dayShade(latitude: Double, longitude: Double,
                         sunLatitude: Double, sunLongitude: Double) -> Double {
        let latR = latitude * .pi / 180.0
        let sunR = sunLatitude * .pi / 180.0
        let dLon = (longitude - sunLongitude) * .pi / 180.0
        let c = sin(latR) * sin(sunR) + cos(latR) * cos(sunR) * cos(dLon)
        let t = (c + 0.035) / 0.070   // crépuscule ≈ ±2°
        return max(0.0, min(1.0, t))
    }

    // MARK: Bande éclairée d'un méridien

    /// Pour un méridien donné, latitude Nord / Sud entre lesquelles le Soleil
    /// est au-dessus de l'horizon (nil = méridien entièrement dans la nuit).
    /// Résolution analytique de  sin(φ)sin(δ) + cos(φ)cos(δ)cos(Δλ) ≥ cos(90°+crépuscule).
    static func sunlitBand(longitude: Double, sunLatitude: Double, sunLongitude: Double,
                           twilightDeg: Double = 2.0) -> (north: Double, south: Double)? {
        let dLon = (longitude - sunLongitude + 540.0).truncatingRemainder(dividingBy: 360.0) - 180.0
        let deltaLon = abs(dLon) * .pi / 180.0
        let delta = sunLatitude * .pi / 180.0
        let threshold = -sin(twilightDeg * .pi / 180.0)   // Soleil à ~twilight° sous l'horizon

        let b = sin(delta)
        let c = cos(delta) * cos(deltaLon)
        let radius = sqrt(b * b + c * c)
        guard radius > 0.0001 else { return nil }          // cas équatorial ambigu (±90° de longitude)
        let ratio = threshold / radius
        guard ratio >= -1, ratio <= 1 else { return nil }  // aucun jour sur ce méridien

        let alpha = atan2(c, b)
        let arg = asin(ratio)
        let low = arg - alpha
        let high = .pi - arg - alpha
        let north = min(.pi / 2, high) * 180.0 / .pi
        let south = max(-.pi / 2, low) * 180.0 / .pi
        guard north >= south else { return nil }
        return (north, south)
    }

    /// Bande de latitudes éclairées, élargie de `expandDeg` de chaque côté
    /// (pour adoucir le bord du voile). Retourne nil si totalement nuit.
    static func expandedBand(longitude: Double, sunLatitude: Double, sunLongitude: Double,
                             expandDeg: Double) -> (north: Double, south: Double)? {
        guard let base = sunlitBand(longitude: longitude, sunLatitude: sunLatitude,
                                    sunLongitude: sunLongitude) else { return nil }
        return (min(90, base.north + expandDeg), max(-90, base.south - expandDeg))
    }
}

// MARK: - Projection équirectangulaire (partagée rendu + repères)
//
// x = (lon + 180) / 360 * largeur   y = (90 - lat) / 180 * hauteur

struct MapProjection {
    let rect: CGRect

    func point(latitude: Double, longitude: Double) -> CGPoint {
        CGPoint(x: rect.minX + CGFloat((longitude + 180.0) / 360.0) * rect.width,
                y: rect.minY + CGFloat((90.0 - latitude) / 180.0) * rect.height)
    }
    var midLonX: CGFloat { rect.minX + rect.width / 2 }
    var midLatY: CGFloat { rect.minY + rect.height / 2 }
}

// MARK: - Rendu de la carte du monde (Canvas)
//
// 1. grille géographique discrète
// 2. continents en points denses (masque Natural Earth, grille 1°)
// 3. teinte de chaque point selon la position réelle du Soleil
// 4. voile de nuit semi-transparent découpé sur la zone éclairée
// 5. repères des villes + étiquette de la ville principale

enum WorldRenderer {

    /// Grille des couleurs jour → nuit (pré-calculée une fois par rendu).
    private static func dotPalette() -> [Color] {
        let day = UIColor(WidgetPalette.accent)
        let night = UIColor(WidgetPalette.night)
        var dayR: CGFloat = 0, dayG: CGFloat = 0, dayB: CGFloat = 0, dayA: CGFloat = 0
        var nightR: CGFloat = 0, nightG: CGFloat = 0, nightB: CGFloat = 0, nightA: CGFloat = 0
        day.getRed(&dayR, green: &dayG, blue: &dayB, alpha: &dayA)
        night.getRed(&nightR, green: &nightG, blue: &nightB, alpha: &nightA)
        return (0...32).map { i in
            let t = CGFloat(i) / 32.0
            return Color(red: Double(dayR + (nightR - dayR) * t),
                         green: Double(dayG + (nightG - dayG) * t),
                         blue: Double(dayB + (nightB - dayB) * t))
        }
    }

    // MARK: Grille

    static func drawGrid(in ctx: inout GraphicsContext, projection: MapProjection) {
        let grid = WidgetPalette.faint.opacity(0.55)
        var path = Path()
        for lon in stride(from: -150.0, through: 180.0, by: 30.0) {
            let x = projection.point(latitude: 0, longitude: lon).x
            path.move(to: CGPoint(x: x, y: projection.rect.minY))
            path.addLine(to: CGPoint(x: x, y: projection.rect.maxY))
        }
        for lat in stride(from: -60.0, through: 60.0, by: 30.0) {
            let y = projection.point(latitude: lat, longitude: 0).y
            path.move(to: CGPoint(x: projection.rect.minX, y: y))
            path.addLine(to: CGPoint(x: projection.rect.maxX, y: y))
        }
        ctx.stroke(path, with: .color(grid),
                   style: StrokeStyle(lineWidth: 0.5, dash: [1.5, 5]))

        // Équateur, très discret.
        let equatorY = projection.midLatY
        var eq = Path()
        eq.move(to: CGPoint(x: projection.rect.minX, y: equatorY))
        eq.addLine(to: CGPoint(x: projection.rect.maxX, y: equatorY))
        ctx.stroke(eq, with: .color(WidgetPalette.accent.opacity(0.35)), lineWidth: 0.6)
    }

    // MARK: Continents en points

    /// Dessine les terres émergées : un point par cellule de 1° du masque.
    /// Les points sont regroupés par teinte pour limiter les appels de remplissage.
    static func drawLand(in ctx: inout GraphicsContext, projection: MapProjection,
                         sun: (lat: Double, lon: Double)) {
        let pitch = projection.rect.width / 360.0
        let dot = max(0.3, pitch * 0.46)
        let palette = dotPalette()
        var buckets = Array(repeating: Path(), count: palette.count)

        for land in WorldMap.landPoints {
            let shade = SunMath.dayShade(latitude: land.lat, longitude: land.lon,
                                         sunLatitude: sun.lat, sunLongitude: sun.lon)
            let index = min(palette.count - 1, Int(shade * Double(palette.count - 1)))
            let p = projection.point(latitude: land.lat, longitude: land.lon)
            buckets[index].addEllipse(in: CGRect(x: p.x - dot, y: p.y - dot,
                                                 width: dot * 2, height: dot * 2))
        }
        for index in palette.indices where !buckets[index].isEmpty {
            ctx.fill(buckets[index], with: .color(palette[index]))
        }
    }

    // MARK: Voile de nuit

    /// Polygone (ou morceaux) des latitudes éclairées du méridien courant.
    /// Découpe le voile : le voile couvre tout sauf la zone de jour réelle.
    private static func daylightRegionPath(projection: MapProjection,
                                           sun: (lat: Double, lon: Double),
                                           expandDeg: Double) -> Path {
        var region = Path()
        var inRun = false
        var firstSouth: CGPoint = .zero
        var previousSouth: CGPoint = .zero

        func closeRun() {
            guard inRun else { return }
            region.addLine(to: previousSouth)
            region.addLine(to: firstSouth)
            region.closeSubpath()
            inRun = false
        }

        for lon in stride(from: -180.0, through: 180.0, by: 2.0) {
            if let band = SunMath.expandedBand(longitude: lon, sunLatitude: sun.lat,
                                               sunLongitude: sun.lon, expandDeg: expandDeg) {
                let north = projection.point(latitude: band.north, longitude: lon)
                let south = projection.point(latitude: band.south, longitude: lon)
                if !inRun {
                    region.move(to: north)
                    firstSouth = south
                    inRun = true
                } else {
                    region.addLine(to: north)
                }
                previousSouth = south
            } else {
                closeRun()
            }
        }
        closeRun()
        return region
    }

    static func drawNightVeil(in ctx: inout GraphicsContext, projection: MapProjection,
                              sun: (lat: Double, lon: Double)) {
        guard projection.rect.width > 0, projection.rect.height > 0 else { return }
        // Deux passes : bord du terminateur légèrement progressif.
        for (expand, alpha) in [(3.5, 0.10), (1.2, 0.10)] {
            var mask = Path(projection.rect)
            mask.addPath(daylightRegionPath(projection: projection, sun: sun, expandDeg: expand))
            ctx.fill(mask, with: .color(WidgetPalette.veil.opacity(alpha)),
                     style: FillStyle(eoFill: true, antialiased: true))
        }
    }

    // MARK: Repères

    /// Petit point discret pour chaque ville suivie (sauf la principale).
    static func drawSecondaryCities(in ctx: inout GraphicsContext, cities: [WidgetCity],
                                    projection: MapProjection, excludeID: String?) {
        let marker = WidgetPalette.dim.opacity(0.9)
        for city in cities where city.id != excludeID {
            let p = projection.point(latitude: city.latitude, longitude: city.longitude)
            guard projection.rect.insetBy(dx: -3, dy: -3).contains(p) else { continue }
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.35, y: p.y - 1.35, width: 2.7, height: 2.7)),
                     with: .color(marker))
        }
    }

    /// Marqueur lumineux : halo doux + point orange cuivré + cœur clair.
    static func drawMarker(in ctx: inout GraphicsContext, at p: CGPoint, radius: CGFloat = 6) {
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - radius * 1.9, y: p.y - radius * 1.9,
                                        width: radius * 3.8, height: radius * 3.8)),
                 with: .color(WidgetPalette.accent.opacity(0.10)))
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius,
                                        width: radius * 2, height: radius * 2)),
                 with: .color(WidgetPalette.accent.opacity(0.28)))
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - radius * 0.42, y: p.y - radius * 0.42,
                                        width: radius * 0.84, height: radius * 0.84)),
                 with: .color(WidgetPalette.accent))
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - radius * 0.14, y: p.y - radius * 0.14,
                                        width: radius * 0.28, height: radius * 0.28)),
                 with: .color(.white.opacity(0.85)))
    }

    /// Éclat très discret au point subsolaire (position réelle du Soleil).
    static func drawSunGlow(in ctx: inout GraphicsContext, at p: CGPoint) {
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 5.4, y: p.y - 5.4, width: 10.8, height: 10.8)),
                 with: .color(WidgetPalette.sun.opacity(0.10)))
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2.7, y: p.y - 2.7, width: 5.4, height: 5.4)),
                 with: .color(WidgetPalette.sun.opacity(0.35)))
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.1, y: p.y - 1.1, width: 2.2, height: 2.2)),
                 with: .color(WidgetPalette.sun))
    }

    // MARK: Étiquette ville + heure (live)

    struct LabelStyle {
        var nameSize: CGFloat = 8.5
        var timeSize: CGFloat = 12
        var nameTracking: CGFloat = 1.4
        var paddingH: CGFloat = 9
        var paddingV: CGFloat = 5
    }

    static func drawCityLabel(in ctx: inout GraphicsContext, city: WidgetCity, at p: CGPoint,
                              inside bounds: CGRect, date: Date, hour12: Bool,
                              style: LabelStyle = LabelStyle()) {
        let time = timeText(city: city, date: date, hour12: hour12)
        let nameText = Text(city.name.uppercased())
            .font(.system(size: style.nameSize, weight: .semibold))
            .tracking(style.nameTracking)
            .foregroundColor(WidgetPalette.accent)
        let timeTextResolved = Text(time)
            .font(.system(size: style.timeSize, weight: .bold, design: .monospaced))
            .monospacedDigit()
            .foregroundColor(WidgetPalette.ink)

        let nameResolved = ctx.resolve(nameText)
        let timeResolved = ctx.resolve(timeTextResolved)
        let nameSize = nameResolved.measure(in: CGSize(width: 1000, height: 1000))
        let timeSize = timeResolved.measure(in: CGSize(width: 1000, height: 1000))
        let gap: CGFloat = 6
        let boxW = nameSize.width + gap + timeSize.width + style.paddingH * 2
        let boxH = max(nameSize.height, timeSize.height) + style.paddingV * 2

        // Place l'étiquette à côté du point, en restant dans la carte.
        var origin = CGPoint(x: p.x + 7, y: p.y + 5)
        if origin.x + boxW > bounds.maxX - 4 { origin.x = p.x - boxW - 7 }
        if origin.y + boxH > bounds.maxY - 4 { origin.y = p.y - boxH - 5 }
        origin.x = max(bounds.minX + 2, min(origin.x, bounds.maxX - boxW - 2))
        origin.y = max(bounds.minY + 2, min(origin.y, bounds.maxY - boxH - 2))

        let boxRect = CGRect(x: origin.x, y: origin.y, width: boxW, height: boxH)
        // Ombre douce puis pastille papier.
        let shadow = CGRect(x: boxRect.minX, y: boxRect.minY + 0.8, width: boxRect.width, height: boxRect.height)
        ctx.fill(Path(roundedRect: shadow, cornerRadius: boxH * 0.45),
                 with: .color(.black.opacity(0.12)))
        ctx.fill(Path(roundedRect: boxRect, cornerRadius: boxH * 0.45),
                 with: .color(WidgetPalette.paperBright.opacity(0.94)))
        ctx.stroke(Path(roundedRect: boxRect, cornerRadius: boxH * 0.45),
                   with: .color(WidgetPalette.line.opacity(0.9)), lineWidth: 0.6)

        // Texte aligné sur la ligne de base.
        let baselineY = origin.y + style.paddingV + max(nameSize.height, timeSize.height) * 0.78
        ctx.draw(nameResolved, at: CGPoint(x: origin.x + style.paddingH, y: baselineY), anchor: .leading)
        ctx.draw(timeResolved, at: CGPoint(x: origin.x + style.paddingH + nameSize.width + gap, y: baselineY),
                 anchor: .leading)
    }

    /// Heure locale du lieu à l'instant affiché (mise à jour « live » par TimelineView).
    static func timeText(city: WidgetCity, date: Date, hour12: Bool) -> String {
        let timeZone = city.timeZone ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        if !hour12 {
            return String(format: "%02d:%02d", hour, minute)
        }
        var displayHour = hour % 12
        if displayHour == 0 { displayHour = 12 }
        let suffix = hour < 12 ? " am" : " pm"
        return String(format: "%d:%02d%@", displayHour, minute, suffix)
    }

    /// Décalage UTC du lieu (« UTC+2 », « UTC-8 », « UTC+5:30 »…).
    static func utcLabel(timeZone: TimeZone, date: Date) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        let totalMinutes = seconds / 60
        let sign = totalMinutes < 0 ? "-" : "+"
        let hours = abs(totalMinutes) / 60
        let minutes = abs(totalMinutes) % 60
        if minutes == 0 { return String(format: "UTC%@%d", sign, hours) }
        return String(format: "UTC%@%d:%02d", sign, hours, minutes)
    }
}

// MARK: - Vue publique du widget

struct DayNightWidgetView: View {
    let date: Date
    let cities: [WidgetCity]

    @Environment(\.widgetFamily) private var family

    /// Format 12h/24h partagé par l'application (24 h si le réglage est absent).
    private var hour12: Bool {
        SharedGroup.hour12Shared ?? false
    }

    var body: some View {
        content
            .background(WidgetPalette.paper)
            .widgetBackground()
    }

    private var content: some View {
        // TimelineView : l'heure locale des étiquettes se met à jour toute seule
        // (chaque minute), même entre deux actualisations WidgetKit de la carte.
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let now = timeline.date
            switch family {
            case .systemSmall:
                SmallCard(date: now, cities: cities, hour12: hour12)
            case .systemLarge:
                LargeCard(date: now, cities: cities, hour12: hour12)
            default:
                MediumCard(date: now, cities: cities, hour12: hour12)
            }
        }
    }
}

// MARK: - Cartes par famille

/// Rectangle (la taille de référence) : la carte occupe la quasi-totalité
/// du widget, voile de nuit, ville principale avec halo + étiquette.
struct MediumCard: View {
    let date: Date
    let cities: [WidgetCity]
    let hour12: Bool

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, 2 * size.height)
            let mapRect = CGRect(x: (size.width - side) / 2, y: 0, width: side, height: size.height)
            let projection = MapProjection(rect: mapRect)
            let sun = SunMath.subsolarPoint(at: date)

            WorldRenderer.drawGrid(in: &ctx, projection: projection)
            WorldRenderer.drawLand(in: &ctx, projection: projection, sun: sun)
            WorldRenderer.drawNightVeil(in: &ctx, projection: projection, sun: sun)

            let primary = SharedGroup.primaryCity(in: cities)
            WorldRenderer.drawSecondaryCities(in: &ctx, cities: cities,
                                              projection: projection, excludeID: primary?.id)

            // Éclat du Soleil à son zénith réel (discret).
            let subsolar = projection.point(latitude: sun.lat, longitude: sun.lon)
            if mapRect.insetBy(dx: -8, dy: -8).contains(subsolar) {
                WorldRenderer.drawSunGlow(in: &ctx, at: subsolar)
            }

            if let primary {
                let p = projection.point(latitude: primary.latitude, longitude: primary.longitude)
                guard mapRect.insetBy(dx: -6, dy: -6).contains(p) else { return }
                WorldRenderer.drawMarker(in: &ctx, at: p, radius: 6.2)
                WorldRenderer.drawCityLabel(in: &ctx, city: primary, at: p,
                                            inside: mapRect, date: date, hour12: hour12)
            }
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "sun.max")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetPalette.accent.opacity(0.8))
                .padding(9)
        }
    }
}

/// Grand rectangle : la carte en haut, puis les horloges des villes suivies
/// (écho direct de l'écran « Horloges » de l'application).
struct LargeCard: View {
    let date: Date
    let cities: [WidgetCity]
    let hour12: Bool

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let mapHeight = min(width / 2, geometry.size.height * 0.56)
            let rows = Array(cities.prefix(4))
            let rowHeight = rows.isEmpty ? 0 : (geometry.size.height - mapHeight) / CGFloat(rows.count)

            VStack(spacing: 0) {
                Canvas { ctx, size in
                    let mapRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                    let projection = MapProjection(rect: mapRect)
                    let sun = SunMath.subsolarPoint(at: date)

                    WorldRenderer.drawGrid(in: &ctx, projection: projection)
                    WorldRenderer.drawLand(in: &ctx, projection: projection, sun: sun)
                    WorldRenderer.drawNightVeil(in: &ctx, projection: projection, sun: sun)

                    let primary = SharedGroup.primaryCity(in: cities)
                    WorldRenderer.drawSecondaryCities(in: &ctx, cities: cities,
                                                      projection: projection, excludeID: primary?.id)
                    let subsolar = projection.point(latitude: sun.lat, longitude: sun.lon)
                    if mapRect.contains(subsolar) {
                        WorldRenderer.drawSunGlow(in: &ctx, at: subsolar)
                    }
                    if let primary {
                        let p = projection.point(latitude: primary.latitude, longitude: primary.longitude)
                        guard mapRect.insetBy(dx: -4, dy: -4).contains(p) else { return }
                        WorldRenderer.drawMarker(in: &ctx, at: p, radius: 6)
                        WorldRenderer.drawCityLabel(in: &ctx, city: primary, at: p,
                                                    inside: mapRect, date: date, hour12: hour12,
                                                    style: .init(nameSize: 7.5, timeSize: 10.5,
                                                                 nameTracking: 1.2, paddingH: 8,
                                                                 paddingV: 4))
                    }
                }
                .frame(height: mapHeight)

                if !rows.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, city in
                            cityRow(city, height: rowHeight, divider: index < rows.count - 1)
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "sun.max")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WidgetPalette.accent.opacity(0.85))
                .padding(10)
        }
    }

    private func cityRow(_ city: WidgetCity, height: CGFloat, divider: Bool) -> some View {
        let isPrimary = city.id == SharedGroup.primaryCity(in: cities)?.id
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Circle()
                    .fill(isPrimary ? WidgetPalette.accent : WidgetPalette.dim.opacity(0.85))
                    .frame(width: isPrimary ? 7 : 5, height: isPrimary ? 7 : 5)
                VStack(alignment: .leading, spacing: 1.5) {
                    Text(city.name.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(WidgetPalette.ink.opacity(0.9))
                    Text(WorldRenderer.utcLabel(timeZone: city.timeZone ?? .current, date: date))
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(WidgetPalette.dim)
                }
                Spacer(minLength: 8)
                Text(WorldRenderer.timeText(city: city, date: date, hour12: hour12))
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(isPrimary ? WidgetPalette.ink : WidgetPalette.dim)
            }
            .frame(height: height)
            if divider {
                Rectangle().fill(WidgetPalette.line).frame(height: 0.5)
            }
        }
    }
}

/// Petit format : globe pointilliste (comme l'écran Météo de l'application),
/// teinté jour/nuit réel, ville principale au zénith.
struct SmallCard: View {
    let date: Date
    let cities: [WidgetCity]
    let hour12: Bool

    var body: some View {
        Canvas { ctx, size in
            let primary = SharedGroup.primaryCity(in: cities)
            guard let primary else { return }
            let sun = SunMath.subsolarPoint(at: date)

            // Cercle du globe (laisse la place à l'étiquette dessous).
            let radius = min(size.width, size.height) * 0.30
            let cx = size.width / 2
            let cy = size.height * 0.40
            let rotation = -primary.longitude * .pi / 180

            func project(_ lat: Double, _ lon: Double) -> (x: CGFloat, y: CGFloat, z: Double) {
                let la = lat * .pi / 180
                let lo = lon * .pi / 180 + rotation
                let x = cos(la) * sin(lo)
                let y = sin(la)
                let z = cos(la) * cos(lo)
                return (cx + x * radius, cy - y * radius, z)
            }

            let day = UIColor(WidgetPalette.accent)
            let night = UIColor(WidgetPalette.night)
            var dayR: CGFloat = 0, dayG: CGFloat = 0, dayB: CGFloat = 0, dayA: CGFloat = 0
            var nightR: CGFloat = 0, nightG: CGFloat = 0, nightB: CGFloat = 0, nightA: CGFloat = 0
            day.getRed(&dayR, green: &dayG, blue: &dayB, alpha: &dayA)
            night.getRed(&nightR, green: &nightG, blue: &nightB, alpha: &nightA)

            // Points du globe (grille 2,5°), teinte selon le Soleil réel.
            for lat in stride(from: -78.0, through: 78.0, by: 2.5) {
                for lon in stride(from: -178.0, through: 178.0, by: 2.5) {
                    let p = project(lat, lon)
                    guard p.z > 0.03 else { continue }
                    let shade = SunMath.dayShade(latitude: lat, longitude: lon,
                                                 sunLatitude: sun.lat, sunLongitude: sun.lon)
                    let alpha = 0.14 + p.z * 0.5
                    let dot = 1.0 + p.z * 1.5
                    let mix = CGFloat(shade)
                    let color = Color(red: Double(dayR + (nightR - dayR) * mix),
                                      green: Double(dayG + (nightG - dayG) * mix),
                                      blue: Double(dayB + (nightB - dayB) * mix))
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - dot, y: p.y - dot,
                                                    width: dot * 2, height: dot * 2)),
                             with: .color(color.opacity(alpha)))
                }
            }

            // Villes secondaires.
            for city in cities where city.id != primary.id {
                let p = project(city.latitude, city.longitude)
                guard p.z > 0 else { continue }
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.4, y: p.y - 1.4, width: 2.8, height: 2.8)),
                         with: .color(WidgetPalette.dim.opacity(0.8)))
            }

            // Ville principale : halo + point lumineux.
            let selected = project(primary.latitude, primary.longitude)
            if selected.z > 0 {
                WorldRenderer.drawMarker(in: &ctx, at: CGPoint(x: selected.x, y: selected.y), radius: 5.4)
            }

            // Étiquette en dessous : ville + heure locale live.
            let time = WorldRenderer.timeText(city: primary, date: date, hour12: hour12)
            let timeFont = Text(time)
                .font(.system(size: 19, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(WidgetPalette.ink)
            let nameFont = Text(primary.name.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(2)
                .foregroundColor(WidgetPalette.accent)
            let tR = ctx.resolve(timeFont)
            let nR = ctx.resolve(nameFont)
            let tSize = tR.measure(in: CGSize(width: 1000, height: 1000))
            let nSize = nR.measure(in: CGSize(width: 1000, height: 1000))
            let centerY = size.height * 0.885
            ctx.draw(tR, at: CGPoint(x: cx, y: centerY), anchor: .center)
            ctx.draw(nR, at: CGPoint(x: cx, y: centerY - tSize.height - nSize.height * 0.45), anchor: .center)
        }
    }
}

// MARK: - Extensions

private extension View {
    /// Fond du widget : nécessaire iOS 17+ (conteneur), simple papier avant.
    func widgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            return AnyView(containerBackground(for: .widget) { WidgetPalette.paper })
        }
        return AnyView(self)
    }
}

// MARK: - Aperçus

struct DayNightWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DayNightWidgetView(date: Date(), cities: SharedGroup.savedCities())
                .frame(width: 338, height: 158)
            DayNightWidgetView(date: Date(), cities: SharedGroup.savedCities())
                .frame(width: 158, height: 158)
            DayNightWidgetView(date: Date(), cities: SharedGroup.savedCities())
                .frame(width: 354, height: 382)
        }
        .previewLayout(.sizeThatFits)
    }
}
