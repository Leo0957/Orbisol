import Foundation
import AppIntents
import WidgetKit

struct CityWeatherSnapshot: Codable, Identifiable {
    let id: String
    let temperature: String
    let condition: String
    let rain: String?
    let fetchedAt: Date
    let sunset: String?
    var nextRainAt: Date? = nil
    var rainProbability: Int? = nil
}

@available(iOS 17.0, *)
struct NextWidgetCityIntent: AppIntent {
    static var title: LocalizedStringResource = "Ville suivante du widget"
    func perform() async throws -> some IntentResult {
        let cities = SavedCityEntity.all()
        guard !cities.isEmpty else { return .result() }
        let defaults = UserDefaults(suiteName: "group.com.example.meteoheure")
        let current = defaults?.string(forKey: "Orbisol.widgetCycleCity")
        let index = cities.firstIndex { $0.id == current } ?? -1
        defaults?.set(cities[(index + 1) % cities.count].id, forKey: "Orbisol.widgetCycleCity")
        WidgetCenter.shared.reloadTimelines(ofKind: "OrbisolWeather")
        return .result()
    }
}

struct SavedCityEntity: AppEntity, Codable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Ville suivie"
    static var defaultQuery = SavedCityQuery()
    let id: String
    let name: String
    let timeZoneIdentifier: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    static func all() -> [SavedCityEntity] {
        guard let data = UserDefaults(suiteName: "group.com.example.meteoheure")?.data(forKey: "MeteoHeure.locations.v1") else { return [] }
        return (try? JSONDecoder().decode([SavedCityEntity].self, from: data)) ?? []
    }
}

struct SavedCityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SavedCityEntity] {
        SavedCityEntity.all().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [SavedCityEntity] { SavedCityEntity.all() }
    func defaultResult() async -> SavedCityEntity? { SavedCityEntity.all().first }
}

struct OpenCityIntent: AppIntent {
    static var title: LocalizedStringResource = "Ouvrir la météo d’une ville"
    static var openAppWhenRun = true
    @Parameter(title: "Ville") var city: SavedCityEntity
    @MainActor func perform() async throws -> some IntentResult {
        guard SavedCityEntity.all().contains(where: { $0.id == city.id }) else { throw CityIntentError.removed }
        UserDefaults(suiteName: "group.com.example.meteoheure")?.set(city.id, forKey: "Orbisol.requestedCity")
        NotificationCenter.default.post(name: Notification.Name("Orbisol.openCity"), object: nil)
        return .result()
    }
}

struct CityTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Obtenir l’heure d’une ville"
    @Parameter(title: "Ville") var city: SavedCityEntity
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        guard let zone = TimeZone(identifier: city.timeZoneIdentifier) else { throw CityIntentError.removed }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = zone
        formatter.dateFormat = "HH:mm"
        let value = "\(city.name) : \(formatter.string(from: Date()))"
        return .result(value: value, dialog: "\(value)")
    }
}

enum CityIntentError: Error, LocalizedError {
    case removed
    var errorDescription: String? { "Cette ville n’est plus disponible dans Orbisol." }
}
