import Foundation

// MARK: - Réponse brute de l'API Open-Meteo
//
// L'API renvoie du JSON en *snake_case* ("temperature_2m"…).
// On utilise des `CodingKeys` explicites pour mapper proprement
// les clés JSON vers des propriétés Swift en camelCase.
//
// Documentation : https://open-meteo.com/en/docs

struct OpenMeteoResponse: Codable {
    let current: Current?
    let hourly: Hourly?
    let daily: Daily?
    let timezone: String
    var minutely15: Minutely?

    enum CodingKeys: String, CodingKey {
        case current, hourly, daily, timezone
        case minutely15 = "minutely_15"
    }

    struct Minutely: Codable {
        let time: [String]
        let precipitation: [Double?]
    }

    struct Current: Codable {
        let temperature2m: Double
        let apparentTemperature: Double
        let relativeHumidity2m: Int
        let weatherCode: Int
        let isDay: Int
        let surfacePressure: Double       // hPa
        let windSpeed10m: Double          // km/h
        let windDirection10m: Double      // degrés (0 = Nord)

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case relativeHumidity2m = "relative_humidity_2m"
            case weatherCode = "weather_code"
            case isDay = "is_day"
            case surfacePressure = "surface_pressure"
            case windSpeed10m = "wind_speed_10m"
            case windDirection10m = "wind_direction_10m"
        }
    }

    struct Hourly: Codable {
        /// Horodatages locaux du lieu, format "yyyy-MM-dd'T'HH:mm".
        let time: [String]
        let temperature2m: [Double?]
        let weatherCode: [Int?]
        /// Probabilité de précipitations en % (optionnel).
        let precipitationProbability: [Int?]?
        /// Température ressentie horaire (optionnel).
        let apparentTemperature: [Double?]?
        /// Indice UV horaire (optionnel).
        let uvIndex: [Double?]?
        var windSpeed10m: [Double?]?
        var precipitation: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case weatherCode = "weather_code"
            case precipitationProbability = "precipitation_probability"
            case apparentTemperature = "apparent_temperature"
            case uvIndex = "uv_index"
            case windSpeed10m = "wind_speed_10m"
            case precipitation
        }
    }

    struct Daily: Codable {
        /// Dates locales "yyyy-MM-dd".
        let time: [String]
        let weatherCode: [Int]
        let temperature2mMax: [Double]
        let temperature2mMin: [Double]
        let sunrise: [String]?
        let sunset: [String]?
        /// Indice UV maximal de la journée (optionnel).
        let uvIndexMax: [Double]?

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case sunrise
            case sunset
            case uvIndexMax = "uv_index_max"
        }
    }
}
