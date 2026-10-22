import Foundation

/// Partage de données entre l'application et le widget via un App Group.
enum SharedGroup {

    /// Identifiant du groupe (à activer dans Xcode : Signing & Capabilities → App Groups,
    /// sur les DEUX cibles, avec le même identifiant).
    static let suiteName = "group.com.example.meteoheure"

    /// Même clé que celle utilisée par l'application dans UserDefaults.
    static let locationsKey = "MeteoHeure.locations.v1"
    /// Ville sélectionnée dans l'application (même clé que dans l'app).
    static let selectedKey = "MeteoHeure.selectedID"
    /// Format 12 h / 24 h choisi dans l'application (même clé que dans l'app).
    static let formatKey = "MeteoHeure.hour12"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}

/// Version allégée d'une localisation, lisible par le widget.
/// Les clés correspondent à celles de `Location` (décodage partiel et tolérant).
struct WidgetCity: Codable, Identifiable {
    var name: String
    var latitude: Double
    var longitude: Double
    /// Identifiant de la `Location` d'origine (uuidString) — absent dans d'anciennes données.
    var locationID: String?
    var region: String?
    var country: String?
    /// Fuseau IANA du lieu (absent dans d'anciennes données partagées).
    var timeZoneIdentifier: String?

    /// Identité stable (pour ForEach et la comparaison avec la ville sélectionnée).
    var id: String { locationID ?? name }

    /// Sous-titre (région, pays) — réservé aux grandes familles de widget.
    var subtitle: String? {
        let parts = [region, country].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Fuseau horaire du lieu (défaut : fuseau de l'appareil).
    var timeZone: TimeZone? {
        timeZoneIdentifier.flatMap { TimeZone(identifier: $0) }
    }

    init(name: String, latitude: Double, longitude: Double,
         locationID: String? = nil, region: String? = nil, country: String? = nil,
         timeZoneIdentifier: String? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.locationID = locationID
        self.region = region
        self.country = country
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    /// Décodage tolérant : fuseau, région ou identifiant peuvent manquer
    /// dans des données plus anciennes.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        latitude = try container.decode(Double.self, forKey: .latitude)
        longitude = try container.decode(Double.self, forKey: .longitude)
        locationID = try container.decodeIfPresent(String.self, forKey: .locationID)
        region = try container.decodeIfPresent(String.self, forKey: .region)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        timeZoneIdentifier = try container.decodeIfPresent(String.self, forKey: .timeZoneIdentifier)
    }

    // Le décodage ci-dessus exige que l'encodeur utilise bien ces clés :
    // `locationID` doit matcher le champ `id` (UUID → uuidString) de `Location`.
    private enum CodingKeys: String, CodingKey {
        case name, latitude, longitude, region, country, timeZoneIdentifier
        case locationID = "id"
    }
}

extension SharedGroup {

    /// Format 12 h / 24 h partagé par l'application (nil = jamais ouvert, défaut 24 h).
    static var hour12Shared: Bool? {
        guard let defaults = sharedDefaults,
              defaults.object(forKey: formatKey) != nil else { return nil }
        return defaults.bool(forKey: formatKey)
    }

    /// Identifiant (uuidString) de la ville sélectionnée dans l'application.
    static func selectedCityID() -> String? {
        sharedDefaults?.string(forKey: selectedKey)
    }

    /// Ville à mettre en avant : la sélection partagée si elle existe,
    /// sinon la première ville de la liste.
    static func primaryCity(in cities: [WidgetCity]) -> WidgetCity? {
        guard !cities.isEmpty else { return nil }
        if let selected = selectedCityID(),
           let match = cities.first(where: { $0.id == selected }) {
            return match
        }
        return cities.first
    }

    /// Villes sauvegardées dans l'application ; villes témoins si rien n'est partagé
    /// (par exemple au tout premier lancement du widget, sans ouvrir l'app).
    static func savedCities() -> [WidgetCity] {
        if let defaults = sharedDefaults,
           let data = defaults.data(forKey: locationsKey),
           let cities = try? JSONDecoder().decode([WidgetCity].self, from: data) {
            return cities
        }
        return [
            WidgetCity(name: "Paris", latitude: 48.8566, longitude: 2.3522,
                       region: "Île-de-France", country: "France",
                       timeZoneIdentifier: "Europe/Paris"),
            WidgetCity(name: "Los Angeles", latitude: 34.0522, longitude: -118.2437,
                       region: "Californie", country: "États-Unis",
                       timeZoneIdentifier: "America/Los_Angeles"),
        ]
    }
}
