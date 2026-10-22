import Foundation

/// Une localisation suivie par l'application : ville, région ou pays.
/// `Identifiable` + `Hashable` : utilisée dans les `List`, `NavigationLink(value:)`,
/// `ForEach` et pour le passage de valeur dans la navigation stack.
struct Location: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var region: String?
    var country: String?
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String
    /// Préférence d'unité propre à ce lieu (nil = suivre le réglage global).
    var prefersFahrenheit: Bool?
    var group: String?
    var favorite: Bool?

    /// Fuseau horaire IANA de la ville (ex. "Europe/Paris").
    /// C'est lui qui permet d'afficher l'heure locale réelle du lieu.
    var timeZone: TimeZone? {
        TimeZone(identifier: timeZoneIdentifier)
    }

    /// Unité effective pour ce lieu.
    func usesFahrenheit(appDefault: Bool) -> Bool {
        prefersFahrenheit ?? appDefault
    }

    /// Sous-titre affiché sous le nom (région, pays).
    var subtitle: String {
        [region, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// Libellé compact (pays, sinon région) pour les lignes et en-têtes
    /// des écrans — la maquette n'affiche que le pays (« France »…).
    var countrySubtitle: String {
        if let country, !country.isEmpty { return country }
        if let region, !region.isEmpty { return region }
        return name
    }

    /// Identifie le même résultat géographique sans confondre des villages
    /// proches qui se trouvaient auparavant dans le rayon de déduplication.
    func isSamePlace(as other: Location) -> Bool {
        abs(latitude - other.latitude) < 0.0001 &&
        abs(longitude - other.longitude) < 0.0001 &&
        name.localizedCaseInsensitiveCompare(other.name) == .orderedSame
    }

    init(id: UUID = UUID(),
         name: String,
         region: String? = nil,
         country: String? = nil,
         latitude: Double,
         longitude: Double,
         timeZoneIdentifier: String,
         prefersFahrenheit: Bool? = nil) {
        self.id = id
        self.name = name
        self.region = region
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.prefersFahrenheit = prefersFahrenheit
    }
}

// MARK: - Exemples

extension Location {
    /// Villes pré-chargées au premier lancement (si aucune donnée sauvegardée),
    /// calquées sur la maquette : Paris, New York, Tokyo, Londres.
    static let defaults: [Location] = [
        Location(name: "Paris", region: "Île-de-France", country: "France",
                 latitude: 48.8566, longitude: 2.3522, timeZoneIdentifier: "Europe/Paris"),
        Location(name: "New York", region: "New York", country: "États-Unis",
                 latitude: 40.7128, longitude: -74.0060, timeZoneIdentifier: "America/New_York"),
        Location(name: "Tokyo", region: "Tokyo", country: "Japon",
                 latitude: 35.6895, longitude: 139.6917, timeZoneIdentifier: "Asia/Tokyo"),
        Location(name: "Londres", region: nil, country: "Royaume-Uni",
                 latitude: 51.5074, longitude: -0.1278, timeZoneIdentifier: "Europe/London")
    ]
}
