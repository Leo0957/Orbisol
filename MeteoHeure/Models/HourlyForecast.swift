import Foundation

/// Une prévision horaire, prête à être affichée (date absolue + température + code météo).
struct HourlyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let temperature: Double
    let weatherCode: Int
    let precipitationProbability: Int?
    /// Indice UV (optionnel, non fourni par toutes les sources).
    let uvIndex: Double?

    /// Construit une prévision à partir d'un horodatage texte local "yyyy-MM-dd'T'HH:mm".
    /// Le `timeZone` reçu est celui de la ville : la date obtenue est donc l'instant
    /// absolu correspondant à cette heure locale.
    init?(hourText: String,
          temperature: Double,
          weatherCode: Int,
          precipitationProbability: Int?,
          uvIndex: Double? = nil,
          timeZone: TimeZone) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        guard let date = formatter.date(from: hourText) else { return nil }
        self.date = date
        self.temperature = temperature
        self.weatherCode = weatherCode
        self.precipitationProbability = precipitationProbability
        self.uvIndex = uvIndex
    }
}