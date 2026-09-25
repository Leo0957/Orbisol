import Foundation
import CoreLocation

// MARK: - Service météo & géocodage
//
// 100 % natif : URLSession + async/await, aucune bibliothèque externe.
//
// L'application utilise **Open-Meteo** par défaut :
//   - Météo courante + horaires + 7 jours : https://open-meteo.com
//   - Géocodage (ville / pays / région) :  https://open-meteo.com/en/docs/geocoding-api
//   - GRATUIT, sans clé API, sans quota pour cet usage.
//
// ═══════════════════════════════════════════════════════════════════
//  PASSER À OPENWEATHERMAP (optionnel) :
//  1. Créez un compte gratuit sur https://home.openweathermap.org
//  2. Récupérez votre clé : « API keys » (1 clé gratuite, 1 000 appels/jour)
//  3. Collez-la dans **WeatherAPI.swift** (fichier ignoré par git) :
//         WeatherAPI.openWeatherMapKey = "votre_clé_ici"
//  4. Remplacez le corps de `fetchWeather(for:)` par l'appel « One Call API 3.0 » :
//         https://api.openweathermap.org/data/3.0/onecall?
//             lat=…&lon=…&exclude=minutely&units=metric&lang=fr&appid=WeatherAPI.openWeatherMapKey
//     puis mappez le JSON dans `OpenMeteoResponse` (les champs sont quasi identiques :
//     current.temp / feels_like / humidity / weather[0].id, daily.min_temp / max_temp…).
// ═══════════════════════════════════════════════════════════════════

/// Erreurs réseau exposées de manière « friendly » aux vues.
enum WeatherServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case network(Error)
    case decoding(Error)
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Adresse invalide."
        case .invalidResponse:     return "Réponse invalide du serveur."
        case .httpStatus(let code): return "Le serveur a répondu \(code)."
        case .network:             return "Connexion impossible. Vérifiez votre réseau."
        case .decoding:            return "Données reçues illisibles."
        case .noResults:           return "Aucun résultat trouvé."
        }
    }
}

/// Encapsule tous les appels réseau de l'application.
struct WeatherService {

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Météo courante + horaires + 7 jours (Open-Meteo)

    /// Récupère la météo complète d'une localisation.
    /// - Parameter location: la localisation (lat / lon + fuseau auto).
    /// - Returns: réponse décodée (`OpenMeteoResponse`).
    func fetchWeather(for location: Location) async throws -> OpenMeteoResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude",  value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current",   value: "temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,surface_pressure,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "hourly",    value: "temperature_2m,weather_code,precipitation_probability,apparent_temperature,uv_index"),
            URLQueryItem(name: "daily",     value: "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max"),
            URLQueryItem(name: "timezone",  value: "auto"), // heures & lever/coucher locaux du lieu
            URLQueryItem(name: "forecast_days", value: "8")
        ]
        guard let url = components.url else { throw WeatherServiceError.invalidURL }

        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw WeatherServiceError.httpStatus(http.statusCode)
            }
            // .convertFromSnakeCase aurait transformé "temperature_2m" en "temperature2M" :
            // on garde donc des CodingKeys explicites dans OpenMeteoResponse.
            let decoder = JSONDecoder()
            return try decoder.decode(OpenMeteoResponse.self, from: data)
        } catch let error as WeatherServiceError {
            throw error
        } catch let error as DecodingError {
            throw WeatherServiceError.decoding(error)
        } catch let nsError as NSError where nsError.domain == NSURLErrorDomain {
            throw WeatherServiceError.network(nsError)
        }
    }

    // MARK: - Qualité de l'air (Open-Meteo Air Quality)

    /// Récupère l'indice de qualité de l'air (AQI européen + particules).
    func fetchAirQuality(latitude: Double, longitude: Double) async throws -> AirQualityResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/air-quality")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "european_aqi,us_aqi,pm2_5,pm10,ozone,nitrogen_dioxide"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components.url else { throw WeatherServiceError.invalidURL }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw WeatherServiceError.httpStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(AirQualityResponse.self, from: data)
        } catch let error as DecodingError {
            throw WeatherServiceError.decoding(error)
        }
    }

    // MARK: - Géocodage inverse (CoreLocation)

    /// Retrouve le nom d'un lieu à partir de coordonnées GPS.
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> (name: String, region: String?, country: String?, timeZoneIdentifier: String) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else {
            throw WeatherServiceError.noResults
        }
        let locality = placemark.locality
            ?? placemark.subAdministrativeArea
            ?? placemark.administrativeArea
            ?? placemark.country
            ?? "Ma position"
        return (locality,
                placemark.administrativeArea,
                placemark.country,
                placemark.timeZone?.identifier ?? TimeZone.current.identifier)
    }

    // MARK: - Recherche de lieux (géocodage Open-Meteo)

    /// Recherche des localisations par nom (ville, pays, état/région…).
    /// - Parameter query: texte saisi par l'utilisateur.
    /// - Returns: liste de `Location` candidates.
    func searchLocations(query: String) async throws -> [Location] {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name",     value: query),
            URLQueryItem(name: "count",    value: "12"),
            URLQueryItem(name: "language", value: "fr"),
            URLQueryItem(name: "format",   value: "json")
        ]
        guard let url = components.url else { throw WeatherServiceError.invalidURL }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw WeatherServiceError.httpStatus(http.statusCode)
        }

        struct SearchResponse: Decodable {
            struct Result: Decodable {
                let name: String
                let latitude: Double
                let longitude: Double
                let country: String?
                let admin1: String?   // région / état / province
                let timezone: String? // IANA, ex. "Africa/Abidjan"
            }
            let results: [Result]?
        }

        do {
            let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
            guard let results = decoded.results, !results.isEmpty else {
                throw WeatherServiceError.noResults
            }
            return results.map { result in
                Location(name: result.name,
                         region: result.admin1,
                         country: result.country,
                         latitude: result.latitude,
                         longitude: result.longitude,
                         timeZoneIdentifier: result.timezone ?? "UTC")
            }
        } catch let error as WeatherServiceError {
            throw error
        } catch let error as DecodingError {
            throw WeatherServiceError.decoding(error)
        }
    }
}