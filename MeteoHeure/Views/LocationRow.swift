import SwiftUI

/// Une ligne de la liste principale :
/// nom du lieu + heure locale (fuseau du lieu) à gauche,
/// icône météo + température à droite.
struct LocationRow: View {
    let location: Location
    let weather: OpenMeteoResponse?
    let isLoading: Bool
    let now: Date

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(location.name)
                    .font(.headline)
                // L'heure est affichée dans le fuseau horaire du lieu,
                // pas celui de l'utilisateur.
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .padding(.trailing, 8)
            } else if let current = weather?.current {
                Image(systemName: WeatherStyle.symbol(code: current.weatherCode,
                                                      isDay: current.isDay == 1))
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 34)
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(Int(current.temperature2m.rounded()))°")
                        .font(.title2.weight(.semibold))
                    Text(WeatherStyle.conditionName(code: current.weatherCode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("--°")
                        .font(.title2.weight(.semibold))
                    Text("…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let region = location.region, !region.isEmpty { parts.append(region) }
        if let country = location.country, !country.isEmpty { parts.append(country) }
        parts.append(self.localTime)
        return parts.joined(separator: " · ")
    }

    /// Heure locale du lieu au moment `now`.
    private var localTime: String {
        guard let timeZone = location.timeZone else { return "—" }
        return Self.timeFormatter(zone: timeZone).string(from: now)
    }

    /// Formatter HH:mm par fuseau horaire (léger + 100 % local).
    private nonisolated static func timeFormatter(zone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = zone
        return formatter
    }
}

#Preview {
    List {
        LocationRow(location: Location(name: "Paris", region: "Île-de-France", country: "France",
                                       latitude: 48.8566, longitude: 2.3522, timeZoneIdentifier: "Europe/Paris"),
                    weather: nil, isLoading: true, now: Date())
    }
}