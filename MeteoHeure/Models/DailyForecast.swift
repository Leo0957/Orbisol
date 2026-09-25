import Foundation

/// Une prévision journalière (min / max + code météo), prête à être affichée.
struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let minTemperature: Double
    let maxTemperature: Double
    let weatherCode: Int

    /// Construit une prévision depuis une date texte locale "yyyy-MM-dd".
    init?(dateText: String,
          minTemperature: Double,
          maxTemperature: Double,
          weatherCode: Int,
          timeZone: TimeZone) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        guard let date = formatter.date(from: dateText) else { return nil }
        self.date = date
        self.minTemperature = minTemperature
        self.maxTemperature = maxTemperature
        self.weatherCode = weatherCode
    }
}