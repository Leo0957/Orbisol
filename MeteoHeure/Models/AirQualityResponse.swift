import Foundation
import SwiftUI

// MARK: - Réponse brute de l'API Qualité de l'air (Open-Meteo)
//
// Endpoint : https://api.open-meteo.com/v1/air-quality
// Indices : european_aqi (échelle européenne 0-100+), us_aqi, PM2.5, PM10, ozone…

struct AirQualityResponse: Codable {
    let current: Current?
    var hourly: Pollen?

    struct Pollen: Codable {
        let time: [String]
        let grassPollen: [Double?]?
        let birchPollen: [Double?]?
        let alderPollen: [Double?]?
        enum CodingKeys: String, CodingKey {
            case time
            case grassPollen = "grass_pollen"
            case birchPollen = "birch_pollen"
            case alderPollen = "alder_pollen"
        }
    }

    struct Current: Codable {
        /// Indice européen de qualité de l'air (0-20 très bonne → 100+ extrême).
        let europeanAqi: Int?
        /// Indice US (optionnel).
        let usAqi: Int?
        /// Particules fines µg/m³.
        let pm2_5: Double?
        let pm10: Double?
        let ozone: Double?
        let nitrogenDioxide: Double?

        enum CodingKeys: String, CodingKey {
            case europeanAqi = "european_aqi"
            case usAqi = "us_aqi"
            case pm2_5
            case pm10
            case ozone
            case nitrogenDioxide = "nitrogen_dioxide"
        }
    }
}

/// Catégorie + couleur associées à l'indice européen AQI.
enum AirQualityScale {
    static func category(europeanAqi: Int) -> (label: String, color: SwiftUI.Color) {
        switch europeanAqi {
        case ..<20:  return ("Très bonne", .green)
        case ..<40:  return ("Bonne", .green.opacity(0.7))
        case ..<60:  return ("Moyenne", .yellow)
        case ..<80:  return ("Médiocre", .orange)
        case ..<100: return ("Mauvaise", .red)
        default:     return ("Très mauvaise", .purple)
        }
    }
}
