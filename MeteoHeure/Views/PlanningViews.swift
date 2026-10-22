import SwiftUI
import Charts

struct WeatherInsightsView: View {
    @EnvironmentObject private var model: LocationsViewModel
    let location: Location
    @State private var hours: [ForecastHour] = []
    @State private var photoWindows: [SolarPosition.Window] = []
    @State private var daylightChange = ""
    @State private var activity = WeatherInsights.Activity.walking
    @AppStorage("Orbisol.weather.order") private var sectionOrder = "[]"
    @AppStorage("Orbisol.weather.hidden") private var hiddenSections = "[]"
    private var zone: TimeZone { location.timeZone ?? .current }
    private var upcoming: [ForecastHour] { hours.filter { $0.date >= Date().addingTimeInterval(-3600) && $0.date < Date().addingTimeInterval(86400) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if model.offlineIDs.contains(location.id) {
                Label("Hors connexion · dernières prévisions conservées", systemImage: "wifi.slash")
                    .font(.footnote).foregroundStyle(Theme.accent)
            }
            if let updated = model.freshnessText(for: location) {
                Text(updated).font(.caption).foregroundStyle(Theme.dim)
            }
            ForEach(WeatherSection.ordered(sectionOrder)) { item in
                if !hiddenIDs.contains(item.rawValue) { insight(item) }
            }
        }
        .foregroundStyle(Theme.ink)
        .task(id: "\(location.id)-\(model.lastFetchDate(for: location)?.timeIntervalSince1970 ?? 0)") {
            hours = WeatherInsights.hours(model.weatherByLocation[location.id], zone: zone)
            photoWindows = SolarPosition.photoWindows(on: Date(), latitude: location.latitude, longitude: location.longitude, zone: zone)
            let today = SolarPosition.daylightMinutes(on: Date(), latitude: location.latitude, longitude: location.longitude, zone: zone)
            let yesterday = WorldTime.calendar(zone).date(byAdding: .day, value: -1, to: Date())!
            let previous = SolarPosition.daylightMinutes(on: yesterday, latitude: location.latitude, longitude: location.longitude, zone: zone)
            let delta = today - previous
            daylightChange = delta == 0 ? "Durée du jour stable par rapport à hier" : "\(abs(delta)) min de jour en \(delta > 0 ? "plus" : "moins") qu’hier"
        }
    }
    private var hiddenIDs: Set<String> { Set((try? JSONDecoder().decode([String].self, from: Data(hiddenSections.utf8))) ?? []) }
    @ViewBuilder private func insight(_ item: WeatherSection) -> some View {
        switch item {
        case .summary:
            if !upcoming.isEmpty {
                section("Votre journée", icon: "sun.horizon") {
                    Text(summary).font(.body).fixedSize(horizontal: false, vertical: true)
                    if let delta = WeatherInsights.yesterdayDelta(hours, now: Date(), zone: zone) {
                        let value = model.unitIsFahrenheit(for: location) ? delta * 1.8 : delta
                        Text(String(format: "%+.0f°", value) + " par rapport à hier à la même heure")
                            .font(.footnote).foregroundStyle(Theme.dim)
                    }
                }
            }
        case .outing:
            if !upcoming.isEmpty {
                section("Créneau de sortie", icon: "figure.walk") {
                    Picker("Activité", selection: $activity) {
                        ForEach(WeatherInsights.Activity.allCases) { value in Text(value.title).tag(value) }
                    }.pickerStyle(.segmented)
                    let best = WeatherInsights.bestWindow(hours, after: Date(), zone: zone,
                        activity: activity, latitude: location.latitude, longitude: location.longitude)
                    if let first = best.first, let last = best.last {
                        Text("\(time(first.date)) – \(time(last.date.addingTimeInterval(3600)))")
                            .font(.title3.bold()).monospacedDigit()
                        Text("Pluie ≤ \(best.compactMap(\.rain).max() ?? 0) % · vent ≤ \(model.windText(kmPerHour: best.compactMap(\.wind).max() ?? 0, for: location))")
                            .font(.footnote)
                        Text(activity == .photography ? "Lumière solaire estimée, pluie, vent et nébulosité approximée par les conditions prévues." : "Comparaison entre 8 h et 20 h : pluie, vent et température. Ce créneau reste une prévision.")
                            .font(.caption).foregroundStyle(Theme.dim)
                    } else { Text("Données insuffisantes pour comparer les créneaux.").font(.footnote) }
                }
            }
        case .rain: precipitation
        case .pollen: pollen
        case .light:
            section("Lumière du jour", icon: "camera.aperture") {
                Text(daylightChange).font(.subheadline)
                if photoWindows.isEmpty { Text("Pas de passage dans ces plages solaires aujourd’hui.").font(.footnote) }
                ForEach(photoWindows) { window in
                    HStack {
                        Text(window.name)
                        Spacer()
                        Text("\(time(window.start)) – \(time(window.end))").monospacedDigit()
                    }.font(.subheadline)
                }
                Text("Estimation locale : dorée −4° à +6°, bleue −6° à −4° d’élévation solaire ; horizon et nuages non pris en compte.")
                    .font(.caption).foregroundStyle(Theme.dim)
            }
        }
    }

    private var summary: String {
        let calendar = WorldTime.calendar(zone)
        let parts = [("Matin", 6..<12), ("Après-midi", 12..<18), ("Soir", 18..<24)]
        let today = upcoming.filter { calendar.isDateInToday($0.date) }
        return parts.compactMap { name, range in
            let values = today.filter { range.contains(calendar.component(.hour, from: $0.date)) }
            guard let first = values.first else { return nil }
            let wet = values.compactMap(\.rain).max().map { $0 >= 50 } ?? false
            return "\(name) : \(wet ? "pluie probable" : WeatherStyle.shortCondition(code: first.code)), \(model.tempText(values.map(\.temperature).min()!, for: location)) à \(model.tempText(values.map(\.temperature).max()!, for: location))."
        }.joined(separator: " ")
    }

    @ViewBuilder private var precipitation: some View {
        if let data = model.weatherByLocation[location.id]?.minutely15 {
            let points = data.time.enumerated().compactMap { index, text -> RainPoint? in
                guard data.precipitation.indices.contains(index), let amount = data.precipitation[index],
                      let date = WorldTime.parse(text, zone: zone), date > Date(), date < Date().addingTimeInterval(10800) else { return nil }
                return RainPoint(date: date, amount: amount)
            }
            section("Précipitations · 3 heures", icon: "cloud.rain") {
                if points.isEmpty { Text("Données à 15 minutes indisponibles.").font(.footnote) }
                else {
                    Chart(points) { point in
                        BarMark(x: .value("Heure", point.date), y: .value("mm / 15 min", point.amount), width: .ratio(0.8))
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel(time(point.date))
                            .accessibilityValue("\(point.amount.formatted()) millimètres en 15 minutes")
                    }
                    .chartYScale(domain: 0...max(1, points.map(\.amount).max() ?? 1))
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour)) { value in
                            AxisValueLabel { if let date = value.as(Date.self) { Text(time(date)) } }
                        }
                    }
                    .frame(height: 130)
                }
                Text("mm par 15 min · Open-Meteo · données modélisées, parfois interpolées selon la région.")
                    .font(.caption).foregroundStyle(Theme.dim)
            }
        }
    }

    private var pollen: some View {
        section("Pollens", icon: "leaf") {
            let data = model.airQualityByLocation[location.id]?.hourly
            let index = data?.time.firstIndex { text in
                guard let date = WorldTime.parse(text, zone: zone) else { return false }
                return date >= Date().addingTimeInterval(-1800)
            }
            let values: [(String, Double?)] = [("Graminées", pollenValue(data?.grassPollen, index)),
                                               ("Bouleau", pollenValue(data?.birchPollen, index)),
                                               ("Aulne", pollenValue(data?.alderPollen, index))]
            if values.allSatisfy({ $0.1 == nil }) {
                Text("Indisponibles pour ce lieu ou cette période.").font(.footnote).foregroundStyle(Theme.dim)
            } else {
                ForEach(values, id: \.0) { name, value in
                    HStack { Text(name); Spacer(); Text(value.map { "\(Int($0.rounded())) grains/m³" } ?? "Indisponible") }
                        .font(.subheadline)
                }
                Text("Prévisions CAMS / Open-Meteo · couverture européenne saisonnière.").font(.caption).foregroundStyle(Theme.dim)
            }
        }
    }
    private func pollenValue(_ values: [Double?]?, _ index: Int?) -> Double? {
        guard let values, let index, values.indices.contains(index) else { return nil }
        return values[index]
    }
    private func time(_ date: Date) -> String { WorldTime.time(date, zone: zone, hour12: model.hour12) }
    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Divider()
            Label(title, systemImage: icon).font(.headline)
            content()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private struct RainPoint: Identifiable { var id: Date { date }; let date: Date; let amount: Double }
}

struct DayForecastView: View {
    @EnvironmentObject private var model: LocationsViewModel
    let location: Location
    let date: Date
    @State private var hours: [ForecastHour] = []
    var body: some View {
        List {
            ForEach(hours) { hour in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(WorldTime.time(hour.date, zone: location.timeZone ?? .current, hour12: model.hour12)).monospacedDigit()
                        Image(systemName: WeatherStyle.symbol(code: hour.code, isDay: true)).foregroundStyle(Theme.accent)
                        Spacer()
                        Text(model.tempText(hour.temperature, for: location)).bold()
                    }
                    Text("Pluie : \(hour.rain.map { "\($0) %" } ?? "indisponible") · vent : \(hour.wind.map { model.windText(kmPerHour: $0, for: location) } ?? "indisponible")")
                        .font(.caption).foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine)
            }
            if hours.isEmpty { Text("Aucune prévision horaire disponible pour cette journée.") }
        }
        .navigationTitle(dayTitle)
        .task {
            let calendar = WorldTime.calendar(location.timeZone ?? .current)
            hours = WeatherInsights.hours(model.weatherByLocation[location.id], zone: location.timeZone ?? .current)
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
        }
    }
    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = location.timeZone ?? .current
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
}

struct WorldPlannerView: View {
    @EnvironmentObject private var model: LocationsViewModel
    var initialDate: Date? = nil
    var initialCities: Set<UUID>? = nil
    @AppStorage("Orbisol.workingHours") private var storedHours = "{}"
    @State private var anchor = Date()
    @State private var offset = 0.0
    @State private var group = "Toutes"
    @State private var selectedCities: Set<UUID> = []
    @State private var showCitySelection = false
    @State private var showHours = false
    @State private var offsetReminderMessage: String?
    private var workingHours: [String: WorkingHours] {
        (try? JSONDecoder().decode([String: WorkingHours].self, from: Data(storedHours.utf8))) ?? [:]
    }
    private var date: Date { anchor.addingTimeInterval(offset * 3600) }
    private var cities: [Location] {
        model.locations.filter { (group == "Toutes" || $0.group == group) && selectedCities.contains($0.id) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DatePicker("Date de comparaison", selection: $anchor, displayedComponents: [.date, .hourAndMinute])
                HStack {
                    Text("\(offset, specifier: "%+.2f") h").monospacedDigit()
                    Spacer()
                    Button("Maintenant") { anchor = Date(); offset = 0 }
                }
                Slider(value: $offset, in: -12...36, step: 0.25).accessibilityLabel("Décalage temporel")
                MeetingActions(date: date, cities: cities)
                Picker("Groupe", selection: $group) {
                    Text("Toutes").tag("Toutes")
                    ForEach(Array(Set(model.locations.compactMap(\.group).filter { !$0.isEmpty })).sorted(), id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                Button { showCitySelection = true } label: { Label("Choisir les villes", systemImage: "checklist") }
                Button { showHours = true } label: { Label("Horaires disponibles", systemImage: "calendar.badge.clock") }
                ForEach(cities) { city in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(city.name).font(.headline)
                            Spacer()
                            Text(WorldTime.time(date, zone: city.timeZone ?? .current, hour12: model.hour12)).font(.title3).monospacedDigit()
                        }
                        Text("\(WorldTime.offset(from: .current, to: city.timeZone ?? .current, at: date)) · \(WorldTime.dayDifference(from: .current, to: city.timeZone ?? .current, at: date))")
                            .font(.caption).foregroundStyle(Theme.dim)
                        if let current = model.weatherByLocation[city.id]?.current {
                            Text("Météo actuelle : \(model.tempText(current.temperature2m, for: city)) · \(WeatherStyle.shortCondition(code: current.weatherCode))")
                                .font(.caption)
                        }
                    }.accessibilityElement(children: .combine)
                    Divider()
                }
                if let city = cities.first {
                    WeatherComparison(cities: cities, date: date)
                    GlobeView(location: city, others: Array(cities.dropFirst()), date: date)
                        .accessibilityLabel("Jour et nuit à l’heure sélectionnée")
                    Text("Créneaux communs · 1 heure").font(.headline)
                    Text("Selon les jours et horaires définis pour chaque ville, au cours des prochaines 24 heures.")
                        .font(.caption).foregroundStyle(Theme.dim)
                    let slots = WorldTime.commonSlots(availability: cities.map { ($0.timeZone ?? .current, workingHours[$0.id.uuidString] ?? WorkingHours()) }, after: date)
                    if slots.isEmpty { Text("Aucun créneau commun avec ces horaires.") }
                    ForEach(Array(slots.prefix(6)), id: \.self) { slot in
                        Button { anchor = slot; offset = 0 } label: {
                            Label("\(WorldTime.time(slot, zone: .current)) – \(WorldTime.time(slot.addingTimeInterval(3600), zone: .current)) · votre heure", systemImage: "clock")
                        }
                    }
                    let changes = WorldTime.offsetChanges(for: cities, weeklyFrom: date)
                    if !changes.isEmpty {
                        Text("Changement de décalage à venir").font(.headline)
                        ForEach(changes, id: \.0.id) { change in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(change.0.name) · \(change.1.formatted(date: .abbreviated, time: .omitted)) · \(change.2 > 0 ? "+" : "")\(change.2 / 3600) h par rapport à votre fuseau")
                                    .font(.subheadline)
                                Button("Me rappeler la veille") {
                                    Task {
                                        let scheduled = await model.scheduleOffsetReminder(city: change.0, meeting: change.1, delta: change.2)
                                        offsetReminderMessage = scheduled ? "Rappel programmé 24 h avant ce rendez-vous." : "Rappel impossible : date trop proche ou notifications refusées."
                                    }
                                }
                            }
                        }
                        if let offsetReminderMessage { Text(offsetReminderMessage).font(.caption).foregroundStyle(Theme.dim) }
                    }
                } else { Text("Sélectionnez au moins une ville.") }
            }.padding(20)
        }
        .background(Theme.paper).foregroundStyle(Theme.ink)
        .navigationTitle("Heures & voyages")
        .onAppear {
            if let initialDate { anchor = initialDate; offset = 0 }
            if selectedCities.isEmpty { selectedCities = initialCities ?? Set(model.locations.map(\.id)) }
        }
        .sheet(isPresented: $showHours) {
            NavigationStack { WorkingHoursSettings(cities: cities, stored: $storedHours) }
        }
        .sheet(isPresented: $showCitySelection) {
            NavigationStack {
                List(model.locations) { city in
                    Toggle(city.name, isOn: Binding(get: { selectedCities.contains(city.id) }, set: { enabled in
                        if enabled { selectedCities.insert(city.id) } else { selectedCities.remove(city.id) }
                    }))
                }.navigationTitle("Villes comparées")
                    .toolbar { Button("Terminé") { showCitySelection = false } }
            }
        }
    }
}

private struct WorkingHoursSettings: View {
    let cities: [Location]
    @Binding var stored: String
    @Environment(\.dismiss) private var dismiss
    private let names = [(1, "D"), (2, "L"), (3, "M"), (4, "M"), (5, "J"), (6, "V"), (7, "S")]
    private var values: [String: WorkingHours] {
        (try? JSONDecoder().decode([String: WorkingHours].self, from: Data(stored.utf8))) ?? [:]
    }
    var body: some View {
        Form {
            ForEach(cities) { city in
                Section(city.name) {
                    Stepper("Début : \(values[city.id.uuidString, default: WorkingHours()].start) h", value: binding(city, \.start), in: 0...22)
                    Stepper("Fin : \(values[city.id.uuidString, default: WorkingHours()].end) h", value: binding(city, \.end), in: 1...24)
                    ForEach(Array(names.enumerated()), id: \.offset) { entry in
                        Toggle("\(entry.element.1) · jour \(entry.element.0)", isOn: Binding(
                            get: { values[city.id.uuidString, default: WorkingHours()].weekdays.contains(entry.element.0) },
                            set: { enabled in update(city) { if enabled { $0.weekdays.insert(entry.element.0) } else { $0.weekdays.remove(entry.element.0) } } }
                        ))
                    }
                }
            }
        }
        .navigationTitle("Horaires disponibles")
        .toolbar { Button("Terminé") { dismiss() } }
    }
    private func binding(_ city: Location, _ keyPath: WritableKeyPath<WorkingHours, Int>) -> Binding<Int> {
        Binding(get: { values[city.id.uuidString, default: WorkingHours()][keyPath: keyPath] },
                set: { value in update(city) { $0[keyPath: keyPath] = value } })
    }
    private func update(_ city: Location, _ change: (inout WorkingHours) -> Void) {
        var all = values
        var current = all[city.id.uuidString] ?? WorkingHours()
        change(&current)
        all[city.id.uuidString] = current
        if let data = try? JSONEncoder().encode(all), let value = String(data: data, encoding: .utf8) { stored = value }
    }
}
