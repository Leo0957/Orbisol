import SwiftUI

// MARK: - Style météo partagé
//
// Traduit les codes météo WMO (renvoyés par l'API) en :
//   - symboles SF natives (adaptés jour / nuit)
//   - libellés français
//   - dégradés de fond doux (s'adaptent au mode clair / sombre)

enum WeatherStyle {

    /// Symbole SF principal pour un code météo WMO.
    static func symbol(code: Int, isDay: Bool) -> String {
        switch code {
        case 0:   return isDay ? "sun.max.fill"       : "moon.stars.fill"
        case 1:   return isDay ? "sun.min.fill"       : "moon.fill"
        case 2:   return isDay ? "cloud.sun.fill"     : "cloud.moon.fill"
        case 3:   return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 66, 67, 80, 81: return "cloud.rain.fill"
        case 65, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95:  return "cloud.bolt.rain.fill"
        case 96, 99: return "cloud.bolt.fill"
        default:  return "thermometer"
        }
    }

    /// Libellé français d'un code météo WMO.
    static func conditionName(code: Int) -> String {
        switch code {
        case 0:  return "Dégagé"
        case 1:  return "Plutôt dégagé"
        case 2:  return "Partiellement nuageux"
        case 3:  return "Couvert"
        case 45: return "Brouillard"
        case 48: return "Brouillard givrant"
        case 51: return "Bruine légère"
        case 53: return "Bruine"
        case 55: return "Bruine dense"
        case 56: return "Bruine verglaçante"
        case 57: return "Bruine verglaçante dense"
        case 61: return "Pluie faible"
        case 63: return "Pluie"
        case 65: return "Pluie forte"
        case 66: return "Pluie verglaçante"
        case 67: return "Pluie verglaçante forte"
        case 71: return "Neige faible"
        case 73: return "Neige"
        case 75: return "Neige forte"
        case 77: return "Grains de neige"
        case 80: return "Averses faibles"
        case 81: return "Averses"
        case 82: return "Averses violentes"
        case 85: return "Averses de neige"
        case 86: return "Fortes averses de neige"
        case 95: return "Orage"
        case 96: return "Orage avec grêle"
        case 99: return "Orage violent avec grêle"
        default: return "—"
        }
    }

    /// Libellé court en minuscules, utilisé dans les lignes de villes et
    /// l'écran météo (« 18° · ciel clair », « CIEL CLAIR »).
    static func shortCondition(code: Int) -> String {
        switch code {
        case 0:   return "ciel clair"
        case 1:   return "peu nuageux"
        case 2:   return "nuageux"
        case 3:   return "couvert"
        case 45, 48: return "brouillard"
        case 51, 53, 55, 56, 57: return "bruine"
        case 61, 63, 66, 67, 80, 81: return "pluie"
        case 65, 82: return "forte pluie"
        case 71, 73, 75, 77, 85, 86: return "neige"
        case 95, 96, 99: return "orage"
        default:  return "—"
        }
    }

    /// Dégradé de fond : nuances fines, posées en surimpression sur le fond
    /// système (clair ou sombre) → le mode sombre est géré automatiquement.
    static func gradientColors(code: Int, isDay: Bool) -> [Color] {
        switch code {
        case 0, 1:
            return isDay
                ? [Color(red: 0.10, green: 0.45, blue: 0.85).opacity(0.30),
                   Color(red: 0.45, green: 0.75, blue: 0.95).opacity(0.18)]
                : [Color(red: 0.16, green: 0.13, blue: 0.32).opacity(0.55),
                   Color(red: 0.25, green: 0.20, blue: 0.45).opacity(0.25)]
        case 2, 3:
            return [Color(red: 0.42, green: 0.45, blue: 0.50).opacity(0.35),
                    Color(red: 0.55, green: 0.58, blue: 0.62).opacity(0.18)]
        case 45, 48:
            return [Color(red: 0.50, green: 0.52, blue: 0.55).opacity(0.30),
                    Color(red: 0.60, green: 0.62, blue: 0.65).opacity(0.15)]
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82:
            return [Color(red: 0.20, green: 0.30, blue: 0.45).opacity(0.40),
                    Color(red: 0.35, green: 0.45, blue: 0.58).opacity(0.20)]
        case 71, 73, 75, 77, 85, 86:
            return [Color(red: 0.55, green: 0.58, blue: 0.65).opacity(0.30),
                    Color(red: 0.70, green: 0.72, blue: 0.78).opacity(0.18)]
        case 95, 96, 99:
            return [Color(red: 0.25, green: 0.22, blue: 0.40).opacity(0.50),
                    Color(red: 0.40, green: 0.38, blue: 0.55).opacity(0.25)]
        default:
            return [Color.primary.opacity(0.06)]
        }
    }
}