import SwiftUI

/// Écran détail d'un lieu :
///  - en-tête : nom + heure locale en direct (tick seconde)
///  - météo actuelle (grande icône, température, conditions, détails)
///  - prévisions horaires (12 prochaines heures, défilement horizontal)
///  - prévisions journalières (7 jours)
///  - fond dégradé adapté à la condition météo
struct DetailView: View {
    @EnvironmentObject private var viewModel: LocationsViewModel
    let location: Location

    var body: some View {
        ZStack {
            LinearGradient(colors: WeatherStyle.gradientColors(code: weatherCode,
                                                               isDay: isDay),
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if isLoading {
                        loadingState
                    } else if let current = current {
                        currentSection(current)
                        rainSummaryLine
                        hourlySection
                        airQualitySection
                        dailySection
                    } else {
                        errorState
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Re-fetch au plus tôt (le cache de 10 min du ViewModel évite
            // de re-télécharger à chaque apparition).
            Task { await viewModel.refreshWeather(for: location) }
        }
    }

    // MARK: - Données dérivées

    private var weather: OpenMeteoResponse? {
        viewModel.weatherByLocation[location.id]
    }
    private var current: OpenMeteoResponse.Current? { weather?.current }
    private var isLoading: Bool { viewModel.loadingIDs.contains(location.id) }
    private var isDay: Bool { current?.isDay == 1 }
    private var weatherCode: Int { current?.weatherCode ?? 0 }

    private var timeZone: TimeZone {
        location.timeZone ?? .current
    }

    // MARK: - En-tête

    private var header: some View {
        VStack(spacing: 3) {
            Text(location.name.uppercased())
                .font(.headline)
                .textCase(nil)
            Text(location.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            // Heure locale en direct (mise à jour chaque seconde via `now`).
            Text(liveTime)
                .font(.system(size: 34, weight: .light, design: .rounded))
                .monospacedDigit()
                .padding(.top, 2)
            Text(liveDate)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var liveTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = timeZone
        return formatter.string(from: viewModel.now)
    }

    private var liveDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.timeZone = timeZone
        let date = formatter.string(from: viewModel.now)
        return date.prefix(1).uppercased() + date.dropFirst()
    }

    // MARK: - États

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text("Chargement de la météo…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var errorState: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 42))
                .foregroundStyle(.orange)
            Text("Impossible de charger la météo.")
                .font(.subheadline)
            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Réessayer") {
                Task { await viewModel.refreshWeather(for: location, force: true) }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Météo actuelle

    private func currentSection(_ current: OpenMeteoResponse.Current) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Image(systemName: WeatherStyle.symbol(code: current.weatherCode, isDay: current.isDay == 1))
                    .font(.system(size: 54))
                    .symbolRenderingMode(.multicolor)

                Text(viewModel.tempText(current.temperature2m, for: location))
                    .font(.system(size: 78, weight: .thin, design: .rounded))
                    .monospacedDigit()

                Text(WeatherStyle.conditionName(code: current.weatherCode))
                    .font(.title3.weight(.semibold))

                Text("Ressenti " + viewModel.tempText(current.apparentTemperature, for: location))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            statsGrid(current)
        }
    }

    // MARK: - Prochaine pluie (résumé discret)

    private var rainSummaryLine: some View {
        HStack(spacing: 8) {
            switch viewModel.nextRain(for: location) {
            case .unknown:
                EmptyView()
            case .none:
                Image(systemName: "cloud.sun")
                    .font(.system(size: 15))
                Text("Pas de pluie prévue dans les 24 h")
            case .soon(let probability, let hour):
                Image(systemName: "cloud.rain")
                    .font(.system(size: 15))
                Text("Pluie vers \(ClockFormat.shortHour(hour: hour, hour12: viewModel.hour12)) · \(probability) %")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private func statsGrid(_ current: OpenMeteoResponse.Current) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statCard(icon: "thermometer.medium",
                     label: "Ressenti",
                     value: viewModel.tempText(current.apparentTemperature, for: location))
            statCard(icon: "humidity.fill",
                     label: "Humidité",
                     value: "\(current.relativeHumidity2m) %")
            statCard(icon: "wind",
                     label: "Vent",
                     value: viewModel.windText(kmPerHour: current.windSpeed10m, for: location),
                     footer: cardinalDirection(current.windDirection10m))
            statCard(icon: "gauge.with.dots.needle.50percent",
                     label: "Pression",
                     value: "\(Int(current.surfacePressure.rounded())) hPa")
            statCard(icon: "sun.max",
                     label: "Indice UV",
                     value: uvMaxText,
                     footer: uvMaxLabel)
            sunCard
        }
        .padding(.top, 4)
    }

    private var uvMaxText: String {
        guard let value = weather?.daily?.uvIndexMax?.first else { return "—" }
        let rounded = (value * 10).rounded() / 10
        return String(format: "%.1f", rounded)
    }

    private var uvMaxLabel: String {
        guard let value = weather?.daily?.uvIndexMax?.first else { return "" }
        switch value {
        case ..<3: return "Faible (max du jour)"
        case ..<6: return "Modéré (max du jour)"
        case ..<8: return "Élevé (max du jour)"
        case ..<11: return "Très élevé (max du jour)"
        default: return "Extrême (max du jour)"
        }
    }

    private var sunCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Soleil", systemImage: "sunrise.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(sunTimesText)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            Text("lever · coucher")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

    private var sunTimesText: String {
        let sunrise = weather?.daily?.sunrise?.first ?? ""
        let sunset = weather?.daily?.sunset?.first ?? ""
        let rise = sunrise.count >= 16 ? String(sunrise.dropFirst(11).prefix(5)) : "--:--"
        let set = sunset.count >= 16 ? String(sunset.dropFirst(11).prefix(5)) : "--:--"
        return "\(rise) / \(set)"
    }

    private func statCard(icon: String, label: String, value: String, footer: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }

    private func cardinalDirection(_ degrees: Double) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]
        let index = Int((degrees.truncatingRemainder(dividingBy: 360) + 22.5) / 45) % 8
        return "Direction \(directions[index])"
    }

    // MARK: - Prévisions horaires (24 prochaines heures)

    private var hourlySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Prochaines 24 heures")

            // Courbe de température sur 24 h.
            if hourlyForecasts.count > 1 {
                TemperatureCurveView(forecasts: hourlyForecasts)
                    .padding(.bottom, 2)
            }

            // Échelle UV (si données disponibles).
            if hasUvData {
                VStack(alignment: .leading, spacing: 6) {
                    Text("INDICE UV — PROCHAINES 24 H")
                        .font(.caption2.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    SparklineView(values: hourlyUvValues)
                }
                .padding(.bottom, 2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    ForEach(hourlyForecasts) { forecast in
                        hourCell(forecast)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    private var hasUvData: Bool {
        !hourlyUvValues.isEmpty
    }

    private var hourlyUvValues: [Double] {
        hourlyForecasts.compactMap { $0.uvIndex }
    }

    private func hourCell(_ forecast: HourlyForecast) -> some View {
        VStack(spacing: 8) {
            Text(hourLabel(forecast.date))
                .font(.callout)
                .monospacedDigit()
            Image(systemName: WeatherStyle.symbol(code: forecast.weatherCode, isDay: true))
                .font(.title3)
                .symbolRenderingMode(.multicolor)
            Text(viewModel.tempText(forecast.temperature, for: location))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
            if let probability = forecast.precipitationProbability, probability >= 20 {
                Text("\(probability)%")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                    .monospacedDigit()
            } else {
                Text("—")
                    .font(.caption2)
                    .foregroundStyle(.clear)
            }
        }
        .padding(.vertical, 6)
        .frame(minWidth: 44)
    }

    private var hourlyForecasts: [HourlyForecast] {
        guard let hourly = weather?.hourly else { return [] }
        var forecasts: [HourlyForecast] = []
        let probabilities = hourly.precipitationProbability ?? []
        let uvValues = hourly.uvIndex ?? []
        for index in hourly.time.indices {
            let probability = probabilities.indices.contains(index) ? probabilities[index] : nil
            let uv = uvValues.indices.contains(index) ? uvValues[index] : nil
            if let forecast = HourlyForecast(hourText: hourly.time[index],
                                             temperature: hourly.temperature2m[index],
                                             weatherCode: hourly.weatherCode[index],
                                             precipitationProbability: probability,
                                             uvIndex: uv,
                                             timeZone: timeZone) {
                forecasts.append(forecast)
            }
        }
        // Garde les 24 prochaines heures à partir de l'heure courante du lieu.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let currentHourStart = calendar.dateInterval(of: .hour, for: viewModel.now)?.start ?? viewModel.now
        return Array(forecasts.filter { $0.date >= currentHourStart }.prefix(24))
    }

    private func hourLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        formatter.timeZone = timeZone
        return formatter.string(from: date) + "h"
    }

    // MARK: - Prévisions journalières (7 jours)

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("7 prochains jours")
            VStack(spacing: 0) {
                ForEach(dailyForecasts) { forecast in
                    dayRow(forecast)
                    if forecast.id != dailyForecasts.last?.id {
                        Divider().opacity(0.5)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func dayRow(_ forecast: DailyForecast) -> some View {
        HStack(spacing: 12) {
            Text(dayLabel(forecast.date))
                .font(.callout)
                .frame(width: 56, alignment: .leading)
            Image(systemName: WeatherStyle.symbol(code: forecast.weatherCode, isDay: true))
                .font(.subheadline)
                .symbolRenderingMode(.multicolor)
                .frame(width: 28)
            Text(viewModel.tempText(forecast.minTemperature, for: location))
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            Text(viewModel.tempText(forecast.maxTemperature, for: location))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 10)
    }

    private var dailyForecasts: [DailyForecast] {
        guard let daily = weather?.daily else { return [] }
        var forecasts: [DailyForecast] = []
        for index in daily.time.indices {
            if let forecast = DailyForecast(dateText: daily.time[index],
                                            minTemperature: daily.temperature2mMin[index],
                                            maxTemperature: daily.temperature2mMax[index],
                                            weatherCode: daily.weatherCode[index],
                                            timeZone: timeZone) {
                forecasts.append(forecast)
            }
        }
        return forecasts
    }

    // MARK: - Qualité de l'air

    private var airQuality: AirQualityResponse? {
        viewModel.airQualityByLocation[location.id]
    }

    @ViewBuilder
    private var airQualitySection: some View {
        if let aqi = airQuality?.current?.europeanAqi {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("Qualité de l'air")
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(aqi)")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(AirQualityScale.category(europeanAqi: aqi).color)
                        Text("AQI européen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        airPill("PM2.5", value: airQuality?.current?.pm2_5)
                        airPill("PM10", value: airQuality?.current?.pm10)
                        airPill("Ozone", value: airQuality?.current?.ozone)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1))
            }
        }
    }

    private func airPill(_ label: String, value: Double?) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.map { "\(Int($0.rounded()))" } ?? "—")
                .font(.callout.monospacedDigit())
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = timeZone
        let today = Calendar.current.startOfDay(for: viewModel.now)
        let day = Calendar.current.startOfDay(for: date)
        if day == today { return "Auj." }
        if day == today.addingTimeInterval(86400) { return "Dem." }
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    // MARK: - Titres de section

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }
}

#Preview {
    NavigationStack {
        DetailView(location: Location(name: "Paris", region: "Île-de-France", country: "France",
                                      latitude: 48.8566, longitude: 2.3522, timeZoneIdentifier: "Europe/Paris"))
    }
    .environmentObject(LocationsViewModel())
}