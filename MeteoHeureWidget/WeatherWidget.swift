import SwiftUI
import WidgetKit
import AppIntents

@available(iOS 17.0, *)
struct CityWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Ville du widget"
    static var description = IntentDescription("Choisissez une ville suivie dans Orbisol.")
    @Parameter(title: "Ville") var city: SavedCityEntity?
}

@available(iOS 17.0, *)
struct WeatherWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = CityWidgetConfiguration
    func placeholder(in context: Context) -> WeatherWidgetEntry { entry(configuration: CityWidgetConfiguration(), date: Date()) }
    func snapshot(for configuration: Intent, in context: Context) async -> WeatherWidgetEntry { entry(configuration: configuration, date: Date()) }
    func timeline(for configuration: Intent, in context: Context) async -> Timeline<WeatherWidgetEntry> {
        let now = Date()
        let entries = (0..<60).map { entry(configuration: configuration, date: now.addingTimeInterval(Double($0) * 60)) }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(3600)))
    }
    private func entry(configuration: Intent, date: Date) -> WeatherWidgetEntry {
        let cities = SavedCityEntity.all()
        let rotating = UserDefaults(suiteName: SharedGroup.suiteName)?.string(forKey: "Orbisol.widgetCycleCity")
        let city = configuration.city.flatMap { choice in cities.first { $0.id == choice.id } }
            ?? (configuration.city == nil ? (cities.first { $0.id == rotating } ?? cities.first) : nil)
        let data = UserDefaults(suiteName: SharedGroup.suiteName)?.data(forKey: "Orbisol.widgetWeather")
        let snapshots = data.flatMap { try? JSONDecoder().decode([CityWeatherSnapshot].self, from: $0) } ?? []
        return WeatherWidgetEntry(date: date, city: city, weather: snapshots.first { $0.id == city?.id }, canCycle: configuration.city == nil && cities.count > 1)
    }
}

struct WeatherWidgetEntry: TimelineEntry {
    let date: Date
    let city: SavedCityEntity?
    let weather: CityWeatherSnapshot?
    let canCycle: Bool
}

@available(iOS 17.0, *)
struct OrbisolWeatherWidget: Widget {
    let kind = "OrbisolWeather"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: CityWidgetConfiguration.self, provider: WeatherWidgetProvider()) { entry in
            WeatherWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .widgetURL(entry.city.flatMap { URL(string: "orbisol://weather/\($0.id)") })
        }
        .configurationDisplayName("Météo & heure")
        .description("L’heure locale, la météo conservée et la prochaine pluie d’une ville.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@available(iOS 17.0, *)
struct WeatherWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeatherWidgetEntry
    private var time: String {
        let formatter = DateFormatter()
        formatter.timeZone = entry.city.flatMap { TimeZone(identifier: $0.timeZoneIdentifier) } ?? .current
        formatter.dateFormat = SharedGroup.hour12Shared == true ? "h:mm a" : "HH:mm"
        return formatter.string(from: entry.date)
    }
    private var stale: Bool { entry.date.timeIntervalSince(entry.weather?.fetchedAt ?? .distantPast) > 3600 }
    var body: some View {
        if let city = entry.city {
            switch family {
            case .accessoryInline:
                Text("\(city.name) · \(time) · \(stale ? "—" : entry.weather?.temperature ?? "—")")
            case .accessoryCircular:
                VStack { Text(time).font(.caption).minimumScaleFactor(0.6); Text(stale ? "—" : entry.weather?.temperature ?? "—").bold() }
                    .accessibilityLabel("\(city.name), \(time), \(stale ? "météo ancienne" : entry.weather?.temperature ?? "météo indisponible")")
            default:
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(city.name).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                        if entry.canCycle && (family == .systemSmall || family == .systemMedium) {
                            Button(intent: NextWidgetCityIntent()) { Image(systemName: "arrow.right.circle") }
                                .buttonStyle(.plain).accessibilityLabel("Ville suivante")
                        }
                    }
                    HStack {
                        Text(time).monospacedDigit()
                        Spacer(minLength: 4)
                        Text(entry.weather?.temperature ?? "—").bold()
                    }
                    if family == .systemSmall || family == .systemMedium {
                        Text(stale ? "Météo ancienne · ouvrez Orbisol" : entry.weather?.condition ?? "Ouvrir Orbisol pour charger la météo").font(.caption)
                        if let at = entry.weather?.nextRainAt, let probability = entry.weather?.rainProbability, !stale, at > entry.date {
                            HStack { Text("Pluie \(probability) % · dans"); Text(at, style: .relative) }.font(.caption)
                        }
                        if let fetched = entry.weather?.fetchedAt {
                            HStack(spacing: 3) { Text(stale ? "Ancienne ·" : "Actualisée"); Text(fetched, style: .relative) }
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    } else {
                        Text(stale ? "Météo à actualiser" : entry.weather?.rain.map { "Pluie : \($0)" } ?? entry.weather?.condition ?? "Météo indisponible")
                            .font(.caption2)
                    }
                }
            }
        } else { Text("Ajoutez une ville dans Orbisol").font(.caption) }
    }
}

@available(iOS 17.0, *)
struct OrbisolRainWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "OrbisolRain", intent: CityWidgetConfiguration.self, provider: WeatherWidgetProvider()) { entry in
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.city?.name ?? "Orbisol").font(.headline)
                if let at = entry.weather?.nextRainAt, let probability = entry.weather?.rainProbability,
                   entry.date.timeIntervalSince(entry.weather?.fetchedAt ?? .distantPast) <= 3600, at > entry.date {
                    Text("Pluie probable · \(probability) %").font(.subheadline)
                    HStack { Text("Dans"); Text(at, style: .relative) }.font(.caption)
                } else {
                    Text(entry.weather == nil ? "Ouvrez Orbisol pour charger la météo" : "Aucune pluie proche confirmée par les données récentes")
                        .font(.caption)
                }
            }
            .containerBackground(.background, for: .widget)
            .widgetURL(entry.city.flatMap { URL(string: "orbisol://weather/\($0.id)") })
        }
        .configurationDisplayName("Pluie à venir")
        .description("Prochaine pluie probable selon la dernière prévision chargée dans Orbisol.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@available(iOS 17.0, *)
struct MultiCityConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Horloges du widget"
    static var description = IntentDescription("Choisissez deux à quatre villes suivies.")
    @Parameter(title: "Ville 1") var first: SavedCityEntity?
    @Parameter(title: "Ville 2") var second: SavedCityEntity?
    @Parameter(title: "Ville 3") var third: SavedCityEntity?
    @Parameter(title: "Ville 4") var fourth: SavedCityEntity?
}

struct MultiCityRow: Identifiable {
    let city: SavedCityEntity
    let weather: CityWeatherSnapshot?
    var id: String { city.id }
}

struct MultiCityEntry: TimelineEntry {
    let date: Date
    let rows: [MultiCityRow]
}

@available(iOS 17.0, *)
struct MultiCityProvider: AppIntentTimelineProvider {
    typealias Intent = MultiCityConfiguration
    func placeholder(in context: Context) -> MultiCityEntry { entry(MultiCityConfiguration(), at: Date()) }
    func snapshot(for configuration: Intent, in context: Context) async -> MultiCityEntry { entry(configuration, at: Date()) }
    func timeline(for configuration: Intent, in context: Context) async -> Timeline<MultiCityEntry> {
        let now = Date()
        return Timeline(entries: (0..<60).map { entry(configuration, at: now.addingTimeInterval(Double($0) * 60)) },
                        policy: .after(now.addingTimeInterval(3600)))
    }
    private func entry(_ configuration: Intent, at date: Date) -> MultiCityEntry {
        let all = SavedCityEntity.all()
        let chosen = [configuration.first, configuration.second, configuration.third, configuration.fourth].compactMap { $0 }
        var ids: Set<String> = []
        var cities = chosen.compactMap { choice in all.first { $0.id == choice.id } }.filter { ids.insert($0.id).inserted }
        if cities.count < 2 { cities += all.filter { ids.insert($0.id).inserted }.prefix(2 - cities.count) }
        let data = UserDefaults(suiteName: SharedGroup.suiteName)?.data(forKey: "Orbisol.widgetWeather")
        let snapshots = data.flatMap { try? JSONDecoder().decode([CityWeatherSnapshot].self, from: $0) } ?? []
        return MultiCityEntry(date: date, rows: Array(cities.prefix(4)).map { city in
            MultiCityRow(city: city, weather: snapshots.first { $0.id == city.id })
        })
    }
}

@available(iOS 17.0, *)
struct OrbisolMultiCityWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "OrbisolMultiCity", intent: MultiCityConfiguration.self, provider: MultiCityProvider()) { entry in
            MultiCityWidgetView(entry: entry).containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Mes villes")
        .description("Heure et météo récente de deux à quatre villes choisies.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct MultiCityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MultiCityEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if entry.rows.isEmpty { Text("Ajoutez deux villes dans Orbisol").font(.caption) }
            ForEach(Array(entry.rows.prefix(family == .systemMedium ? 2 : 4))) { row in
                if let url = URL(string: "orbisol://weather/\(row.city.id)") {
                    Link(destination: url) {
                        HStack {
                            Text(row.city.name).lineLimit(1)
                            Spacer()
                            Text(offset(row.city)).font(.caption2).foregroundStyle(.secondary)
                            Text(clock(row.city)).monospacedDigit()
                            Text(entry.date.timeIntervalSince(row.weather?.fetchedAt ?? .distantPast) <= 3600 ? row.weather?.temperature ?? "—" : "—")
                                .foregroundStyle(.secondary)
                        }.font(.subheadline)
                    }
                }
            }
            Text("Météo conservée · ouvrez l’app pour actualiser").font(.caption2).foregroundStyle(.secondary)
        }
    }
    private func clock(_ city: SavedCityEntity) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: city.timeZoneIdentifier)
        formatter.dateFormat = SharedGroup.hour12Shared == true ? "h:mm a" : "HH:mm"
        return formatter.string(from: entry.date)
    }
    private func offset(_ city: SavedCityEntity) -> String {
        let seconds = TimeZone(identifier: city.timeZoneIdentifier)?.secondsFromGMT(for: entry.date) ?? 0
        let minutes = seconds / 60
        let sign = minutes >= 0 ? "+" : "−"
        let fraction = abs(minutes) % 60
        return "UTC\(sign)\(abs(minutes) / 60)\(fraction == 0 ? "" : String(format: ":%02d", fraction))"
    }
}

@available(iOS 17.0, *)
struct ConfiguredDayNightProvider: AppIntentTimelineProvider {
    typealias Intent = CityWidgetConfiguration
    func placeholder(in context: Context) -> DayNightEntry { DayNightEntry(date: Date(), cities: SharedGroup.savedCities()) }
    func snapshot(for configuration: Intent, in context: Context) async -> DayNightEntry {
        DayNightEntry(date: Date(), cities: cities(configuration))
    }
    func timeline(for configuration: Intent, in context: Context) async -> Timeline<DayNightEntry> {
        let now = Date()
        let cities = cities(configuration)
        return Timeline(entries: (0..<12).map { DayNightEntry(date: now.addingTimeInterval(Double($0) * 900), cities: cities) },
                        policy: .after(now.addingTimeInterval(10800)))
    }
    private func cities(_ configuration: Intent) -> [WidgetCity] {
        let cities = SharedGroup.savedCities()
        guard let selection = configuration.city else { return cities }
        return cities.filter { $0.id == selection.id }
    }
}

@available(iOS 17.0, *)
struct ConfiguredDayNightWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "DayNightWidget", intent: CityWidgetConfiguration.self, provider: ConfiguredDayNightProvider()) { entry in
            DayNightWidgetView(date: entry.date, cities: entry.cities)
        }
        .configurationDisplayName("Jour · Nuit")
        .description("Le globe et l’heure d’une ville indépendante de la sélection de l’app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
