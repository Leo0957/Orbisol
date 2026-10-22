import SwiftUI
import EventKit
import EventKitUI
import UniformTypeIdentifiers

struct HistoricalWeatherView: View {
    @EnvironmentObject private var model: LocationsViewModel
    let location: Location
    @State private var date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var result: WeatherService.HistoricalDay?
    @State private var error: String?
    private var latest: Date { Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date() }
    private var first: Date { Calendar.current.date(from: DateComponents(year: 1950, month: 1, day: 1)) ?? .distantPast }
    var body: some View {
        Form {
            DatePicker("Date passée", selection: $date, in: first...latest, displayedComponents: .date)
            if let daily = result?.daily, let high = daily.temperature2mMax.first ?? nil,
               let low = daily.temperature2mMin.first ?? nil {
                Section("\(location.name) · \(daily.time.first ?? "")") {
                    Text("Température : \(model.tempText(low, for: location)) à \(model.tempText(high, for: location))")
                    Text("Précipitations : " + ((daily.precipitationSum.first ?? nil).map { String(format: "%.1f mm", $0) } ?? "indisponibles"))
                }
            } else if let error { Text(error).foregroundStyle(.secondary) }
            Section { Text("Données historiques modélisées par Open-Meteo, pas une mesure de station locale. Les derniers jours peuvent être indisponibles.") }
        }
        .navigationTitle("Historique météo")
        .task(id: date) {
            result = nil; error = nil
            do { result = try await WeatherService().fetchHistoricalDay(for: location, on: date) }
            catch { self.error = "Historique indisponible pour cette date ou cette ville." }
        }
    }
}


struct MeetingActions: View {
    let date: Date
    let cities: [Location]
    @State private var showCalendar = false
    @State private var error: String?
    @State private var store = EKEventStore()
    @State private var weekly = false
    private var meetingURL: URL? {
        var parts = URLComponents()
        parts.scheme = "orbisol"
        parts.host = "meeting"
        parts.queryItems = [URLQueryItem(name: "at", value: String(Int(date.timeIntervalSince1970)))] +
            cities.map { URLQueryItem(name: "city", value: $0.id.uuidString) }
        return parts.url
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ShareLink(item: MeetingText.describe(date: date, cities: cities)) {
                    Label("Partager le texte", systemImage: "square.and.arrow.up")
                }
                Spacer()
                if let meetingURL {
                    ShareLink(item: meetingURL) { Label("Lien Orbisol", systemImage: "link") }
                }
            }
            Toggle("Répéter chaque semaine dans Calendrier", isOn: $weekly)
            Button {
                Task { @MainActor in
                    if #available(iOS 17, *) { showCalendar = true }
                    else {
                        do {
                            if try await store.requestAccess(to: .event) { showCalendar = true }
                            else { error = "Autorisez Calendrier dans les réglages iOS pour ajouter ce rendez-vous." }
                        } catch { self.error = error.localizedDescription }
                    }
                }
            } label: { Label("Calendrier", systemImage: "calendar.badge.plus") }
        }
        .disabled(cities.isEmpty)
        .sheet(isPresented: $showCalendar) { MeetingEditor(store: store, date: date, notes: MeetingText.describe(date: date, cities: cities), weekly: weekly) }
        .alert("Calendrier", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }
}

struct MeetingEditor: UIViewControllerRepresentable {
    let store: EKEventStore
    let date: Date
    let notes: String
    let weekly: Bool
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator(close: { dismiss() }) }
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        controller.eventStore = store
        let event = EKEvent(eventStore: store)
        event.title = "Rendez-vous"
        event.startDate = date
        event.endDate = date.addingTimeInterval(3600)
        event.timeZone = .current
        event.notes = notes
        if weekly { event.addRecurrenceRule(EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)) }
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}
    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let close: () -> Void
        init(close: @escaping () -> Void) { self.close = close }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) { close() }
    }
}

struct WeatherComparison: View {
    @EnvironmentObject private var model: LocationsViewModel
    let cities: [Location]
    let date: Date
    @State private var forecasts: [UUID: [ForecastHour]] = [:]
    private var cacheKey: String {
        dayKey(date, zone: .current) + cities.map { "\($0.id)-\(model.lastFetchDate(for: $0)?.timeIntervalSince1970 ?? 0)" }.joined()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Météo comparée").font(.headline)
            Text("Même date civile dans chaque ville · pluie maximale et vent maximal horaires").font(.caption).foregroundStyle(.secondary)
            ForEach(cities) { city in
                let hours = forecasts[city.id] ?? []
                VStack(alignment: .leading, spacing: 4) {
                    Text(city.name).bold()
                    if let low = hours.map(\.temperature).min(), let high = hours.map(\.temperature).max() {
                        Text("\(model.tempText(low, for: city)) à \(model.tempText(high, for: city)) · pluie \(hours.compactMap(\.rain).max().map { "\($0) %" } ?? "indisponible")")
                        Text("Vent : \(hours.compactMap(\.wind).max().map { model.windText(kmPerHour: $0, for: city) } ?? "indisponible")")
                        if let freshness = model.freshnessText(for: city) { Text(freshness).font(.caption).foregroundStyle(.secondary) }
                    } else { Text("Prévisions indisponibles pour cette date.").foregroundStyle(.secondary) }
                }.font(.subheadline).accessibilityElement(children: .combine)
            }
        }
        .task(id: cacheKey) {
            let day = dayKey(date, zone: .current)
            var values: [UUID: [ForecastHour]] = [:]
            for city in cities {
                let zone = city.timeZone ?? .current
                let calendar = WorldTime.calendar(zone)
                guard let localDay = WorldTime.parse(day, zone: zone) else { continue }
                values[city.id] = WeatherInsights.hours(model.weatherByLocation[city.id], zone: zone).filter { calendar.isDate($0.date, inSameDayAs: localDay) }
            }
            forecasts = values
        }
    }
    private func dayKey(_ date: Date, zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}


struct TripsView: View {
    @EnvironmentObject private var model: LocationsViewModel
    @AppStorage("Orbisol.trips") private var stored = "[]"
    @State private var group = ""
    @State private var start = Date()
    @State private var end = Date()
    @State private var showCalendarImport = false
    private var groups: [String] { Array(Set(model.locations.compactMap(\.group).filter { !$0.isEmpty })).sorted() }
    private var trips: [TripPlan] { (try? JSONDecoder().decode([TripPlan].self, from: Data(stored.utf8))) ?? [] }
    var body: some View {
        Form {
            Section("Nouveau séjour") {
                Picker("Groupe", selection: $group) {
                    Text("Choisir un groupe").tag("")
                    ForEach(groups, id: \.self) { Text($0).tag($0) }
                }
                if groups.isEmpty { Text("Attribuez un groupe aux villes dans Organiser.").font(.footnote) }
                DatePicker("Départ", selection: $start, displayedComponents: .date)
                DatePicker("Retour", selection: $end, in: start..., displayedComponents: .date)
                Button {
                    let calendar = Calendar.current
                    let firstDay = calendar.startOfDay(for: start)
                    let lastDay = calendar.startOfDay(for: max(end, start))
                    let lastInstant = calendar.date(byAdding: .day, value: 1, to: lastDay)!.addingTimeInterval(-1)
                    save(trips + [TripPlan(group: group, start: firstDay, end: lastInstant)])
                } label: {
                    Label("Ajouter le séjour", systemImage: "plus")
                }.disabled(group.isEmpty)
                Button { showCalendarImport = true } label: { Label("Importer depuis Calendrier", systemImage: "calendar.badge.plus") }
            }
            Section("Séjours") {
                if trips.isEmpty { Text("Aucun séjour enregistré.") }
                ForEach(trips) { trip in
                    NavigationLink {
                        TripDetail(trip: trip)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(trip.group).bold()
                            Text("\(trip.start.formatted(date: .abbreviated, time: .omitted)) – \(trip.end.formatted(date: .abbreviated, time: .omitted))").font(.caption)
                        }
                    }
                }.onDelete { offsets in var updated = trips; updated.remove(atOffsets: offsets); save(updated) }
            }
        }.navigationTitle("Voyages datés")
            .onChange(of: start) { if end < $0 { end = $0 } }
            .sheet(isPresented: $showCalendarImport) {
                NavigationStack {
                    CalendarTripImportView(cities: model.locations) { trip in
                        save(trips + [trip])
                        showCalendarImport = false
                    }
                    .toolbar { Button("Fermer") { showCalendarImport = false } }
                }
            }
    }
    private func save(_ trips: [TripPlan]) { if let data = try? JSONEncoder().encode(trips), let text = String(data: data, encoding: .utf8) { stored = text } }
}

private struct CalendarTripImportView: View {
    let cities: [Location]
    let onImport: (TripPlan) -> Void
    @State private var store = EKEventStore()
    @State private var events: [EKEvent] = []
    @State private var selectedIndex: Int?
    @State private var cityID: UUID?
    @State private var message = "Chargement des événements…"
    var body: some View {
        Form {
            Section {
                Text(message).font(.footnote).foregroundStyle(.secondary)
                ForEach(events.indices, id: \.self) { index in
                    Button {
                        selectedIndex = index
                    } label: {
                        HStack {
                            Text(events[index].title ?? "Événement").lineLimit(1)
                            Spacer()
                            if selectedIndex == index { Image(systemName: "checkmark") }
                        }
                    }
                }
            } header: { Text("Événement à importer") } footer: {
                Text("Orbisol lit les événements après votre autorisation. Aucun événement Calendrier n’est modifié.")
            }
            Section("Destination") {
                Picker("Ville suivie", selection: $cityID) {
                    Text("Choisir une ville").tag(Optional<UUID>.none)
                    ForEach(cities) { city in Text(city.name).tag(Optional(city.id)) }
                }
                Button("Créer le voyage") {
                    guard let selectedIndex, events.indices.contains(selectedIndex), let cityID else { return }
                    let event = events[selectedIndex]
                    let start = event.startDate ?? Date()
                    let end = max(start, event.endDate ?? start)
                    let title = (event.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    onImport(TripPlan(group: title.isEmpty ? "Calendrier" : title,
                        start: start, end: end, stages: [TripStage(locationID: cityID, arrive: start, depart: end)]))
                }.disabled(selectedIndex == nil || cityID == nil)
            }
        }
        .navigationTitle("Importer un voyage")
        .task {
            do {
                let granted: Bool
                if #available(iOS 17.0, *) { granted = try await store.requestFullAccessToEvents() }
                else { granted = try await store.requestAccess(to: .event) }
                guard granted else { message = "Accès au Calendrier refusé dans les réglages iOS."; return }
                let now = Date()
                let end = Calendar.current.date(byAdding: .month, value: 12, to: now) ?? now
                let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
                events = Array(store.events(matching: predicate).prefix(100))
                message = events.isEmpty ? "Aucun événement à venir sur les 12 prochains mois." : "Choisissez un événement puis associez sa destination."
            } catch { message = "Lecture du Calendrier impossible : \(error.localizedDescription)" }
        }
    }
}

struct TripDetail: View {
    @EnvironmentObject private var model: LocationsViewModel
    @AppStorage("Orbisol.trips") private var stored = "[]"
    let trip: TripPlan
    @State private var date: Date
    @State private var stageCity: UUID?
    @State private var stageArrive: Date
    @State private var stageDepart: Date
    @State private var packingName = ""
    init(trip: TripPlan) {
        self.trip = trip
        _date = State(initialValue: trip.start)
        _stageArrive = State(initialValue: trip.start)
        _stageDepart = State(initialValue: min(trip.end, trip.start.addingTimeInterval(3600)))
    }
    private var current: TripPlan {
        ((try? JSONDecoder().decode([TripPlan].self, from: Data(stored.utf8))) ?? []).first { $0.id == trip.id } ?? trip
    }
    private var cities: [Location] {
        let ids = Set((current.stages ?? []).map(\.locationID))
        return ids.isEmpty ? model.locations.filter { $0.group == trip.group } : model.locations.filter { ids.contains($0.id) }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                DatePicker("Date et heure", selection: $date, in: trip.start...max(trip.start, trip.end), displayedComponents: [.date, .hourAndMinute])
                Text("Étapes du voyage").font(.headline)
                ForEach(current.stages ?? []) { stage in
                    if let city = model.locations.first(where: { $0.id == stage.locationID }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(city.name).bold()
                                Text("\(stage.arrive.formatted(date: .abbreviated, time: .shortened)) → \(stage.depart.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                            }
                            Spacer()
                            Button(role: .destructive) { update { $0.stages?.removeAll { $0.id == stage.id } } } label: { Image(systemName: "trash") }
                                .accessibilityLabel("Supprimer l’étape \(city.name)")
                        }
                    }
                }
                if !model.locations.isEmpty {
                    Picker("Ville de l’étape", selection: $stageCity) {
                        Text("Choisir").tag(Optional<UUID>.none)
                        ForEach(model.locations) { city in Text(city.name).tag(Optional(city.id)) }
                    }
                    DatePicker("Arrivée", selection: $stageArrive, in: trip.start...trip.end, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Départ", selection: $stageDepart, in: stageArrive...trip.end, displayedComponents: [.date, .hourAndMinute])
                    Button("Ajouter une étape") {
                        guard let stageCity else { return }
                        update { $0.stages = ($0.stages ?? []) + [TripStage(locationID: stageCity, arrive: stageArrive, depart: stageDepart)] }
                    }.disabled(stageCity == nil)
                }
                if let first = (current.stages ?? []).sorted(by: { $0.arrive < $1.arrive }).first,
                   let last = (current.stages ?? []).sorted(by: { $0.depart < $1.depart }).last,
                   let origin = model.locations.first(where: { $0.id == first.locationID }),
                   let destination = model.locations.first(where: { $0.id == last.locationID }) {
                    Divider()
                    Text("Jour du départ").font(.headline)
                    Text("\(origin.name) · \(WorldTime.time(first.arrive, zone: origin.timeZone ?? .current)) → \(destination.name) · \(WorldTime.time(last.depart, zone: destination.timeZone ?? .current))")
                    Text("Décalage : \(WorldTime.offset(from: origin.timeZone ?? .current, to: destination.timeZone ?? .current, at: first.arrive))")
                        .font(.subheadline)
                    if let daylight = departureDaylight(for: origin, at: first.arrive) {
                        Text("\(origin.name) · lever \(daylight.0), coucher \(daylight.1)")
                            .font(.subheadline)
                    }
                    WeatherComparison(cities: [origin, destination], date: first.arrive)
                }
                if cities.isEmpty { Text("Ce groupe ne contient plus de ville.") }
                ForEach(cities) { city in
                    HStack {
                        Text(city.name)
                        Spacer()
                        Text(WorldTime.time(date, zone: city.timeZone ?? .current)).monospacedDigit()
                    }
                }
                WeatherComparison(cities: cities, date: date)
                Divider()
                Text("Liste de préparation").font(.headline)
                ForEach(current.checklist ?? []) { item in
                    Toggle(item.name, isOn: Binding(get: { current.checklist?.first(where: { $0.id == item.id })?.checked ?? false },
                        set: { value in update { plan in if let index = plan.checklist?.firstIndex(where: { $0.id == item.id }) { plan.checklist?[index].checked = value } } }))
                }
                HStack {
                    TextField("Nouvel objet", text: $packingName)
                    Button("Ajouter") {
                        let name = packingName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        update { $0.checklist = ($0.checklist ?? []) + [PackingItem(name: name)] }
                        packingName = ""
                    }.disabled(packingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Button("Suggérer selon les prévisions") {
                    let forecasts = cities.flatMap { city in WeatherInsights.hours(model.weatherByLocation[city.id], zone: city.timeZone ?? .current) }
                        .filter { $0.date >= trip.start && $0.date <= trip.end }
                    var suggestions: [String] = []
                    if forecasts.contains(where: { ($0.rain ?? 0) >= 50 }) { suggestions.append("Imperméable") }
                    if forecasts.contains(where: { $0.temperature <= 10 }) { suggestions.append("Veste chaude") }
                    if forecasts.contains(where: { $0.temperature >= 25 }) { suggestions.append("Protection solaire") }
                    update { plan in
                        let existing = Set((plan.checklist ?? []).map(\.name))
                        plan.checklist = (plan.checklist ?? []) + suggestions.filter { !existing.contains($0) }.map { PackingItem(name: $0) }
                    }
                }.disabled(cities.isEmpty)
                Text("Suggestions fondées seulement sur les prévisions disponibles pour les dates du séjour.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.navigationTitle(trip.group)
    }
    private func update(_ edit: (inout TripPlan) -> Void) {
        var all = (try? JSONDecoder().decode([TripPlan].self, from: Data(stored.utf8))) ?? []
        guard let index = all.firstIndex(where: { $0.id == trip.id }) else { return }
        edit(&all[index])
        if let data = try? JSONEncoder().encode(all), let value = String(data: data, encoding: .utf8) { stored = value }
    }
    private func departureDaylight(for city: Location, at date: Date) -> (String, String)? {
        guard let daily = model.weatherByLocation[city.id]?.daily,
              let sunrise = daily.sunrise, let sunset = daily.sunset else { return nil }
        let zone = city.timeZone ?? .current
        let day = WorldTime.calendar(zone).startOfDay(for: date)
        guard let index = daily.time.firstIndex(where: {
            guard let parsed = WorldTime.parse($0, zone: zone) else { return false }
            return WorldTime.calendar(zone).isDate(parsed, inSameDayAs: day)
        }), sunrise.indices.contains(index), sunset.indices.contains(index),
              let rise = WorldTime.parse(sunrise[index], zone: zone),
              let set = WorldTime.parse(sunset[index], zone: zone) else { return nil }
        return (WorldTime.time(rise, zone: zone), WorldTime.time(set, zone: zone))
    }
}


struct WeatherLayoutSettings: View {
    @AppStorage("Orbisol.weather.order") private var order = "[]"
    @AppStorage("Orbisol.weather.hidden") private var hidden = "[]"
    private var hiddenIDs: Set<String> { Set((try? JSONDecoder().decode([String].self, from: Data(hidden.utf8))) ?? []) }
    var body: some View {
        List {
            ForEach(WeatherSection.ordered(order)) { section in
                Toggle(section.title, isOn: Binding(get: { !hiddenIDs.contains(section.rawValue) }, set: { visible in
                    var ids = hiddenIDs
                    if visible { ids.remove(section.rawValue) } else { ids.insert(section.rawValue) }
                    hidden = String(data: try! JSONEncoder().encode(ids.sorted()), encoding: .utf8)!
                }))
            }.onMove { source, destination in
                var sections = WeatherSection.ordered(order)
                sections.move(fromOffsets: source, toOffset: destination)
                order = String(data: try! JSONEncoder().encode(sections.map(\.rawValue)), encoding: .utf8)!
            }
        }.navigationTitle("Sections météo").toolbar { EditButton() }
    }
}

struct NightClockView: View {
    @EnvironmentObject private var model: LocationsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    let location: Location
    @State private var controls = true
    @State private var brightness = 0.12
    @State private var originalBrightness: CGFloat?
    @State private var wasIdleDisabled = false
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Text(location.name).font(.title3).foregroundStyle(.gray)
                Text(WorldTime.time(model.now, zone: location.timeZone ?? .current, hour12: model.hour12))
                    .clockTypeface(90, weight: .regular).foregroundStyle(Color(white: 0.65))
                    .frame(maxWidth: .infinity).padding(.horizontal, 24)
                if controls {
                    Slider(value: $brightness, in: 0.03...0.4).tint(.gray).accessibilityLabel("Luminosité")
                    Button("Fermer") { dismiss() }.foregroundStyle(.white).padding()
                }
            }.padding(24)
        }
        .contentShape(Rectangle())
        .accessibilityAction(named: "Afficher les commandes") { controls = true }
        .onTapGesture { controls.toggle() }
        .persistentSystemOverlays(.hidden)
        .task(id: controls) {
            guard controls else { return }
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled { controls = false }
        }
        .onAppear {
            originalBrightness = UIScreen.main.brightness
            wasIdleDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
            UIScreen.main.brightness = brightness
        }
        .onChange(of: brightness) { UIScreen.main.brightness = $0 }
        .onChange(of: phase) { value in
            UIScreen.main.brightness = value == .active ? brightness : (originalBrightness ?? 0.5)
        }
        .onDisappear {
            if let originalBrightness { UIScreen.main.brightness = originalBrightness }
            UIApplication.shared.isIdleTimerDisabled = wasIdleDisabled
        }
    }
}


struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, data.count < 2_000_000 else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct BackupSettingsView: View {
    @EnvironmentObject private var model: LocationsViewModel
    @State private var exporting = false
    @State private var importing = false
    @State private var file = BackupFile(data: Data())
    @State private var pending: SettingsBackup?
    @State private var confirm = false
    @State private var message: String?
    var body: some View {
        Form {
            Section {
                Button { export() } label: { Label("Exporter une sauvegarde", systemImage: "square.and.arrow.up") }
                Button { importing = true } label: { Label("Importer une sauvegarde", systemImage: "square.and.arrow.down") }
            } footer: { Text("Villes, favoris, voyages et préférences. La météo téléchargée et les autorisations iOS ne sont pas incluses.") }
        }.navigationTitle("Sauvegarde")
            .fileExporter(isPresented: $exporting, document: file, contentType: .json, defaultFilename: "Orbisol-sauvegarde") { result in
                if case .failure(let error) = result { message = error.localizedDescription }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
                    guard size < 2_000_000 else { throw CocoaError(.fileReadTooLarge) }
                    let backup = try JSONDecoder().decode(SettingsBackup.self, from: Data(contentsOf: url))
                    try backup.validate()
                    pending = backup; confirm = true
                } catch { message = "Sauvegarde illisible ou incompatible : \(error.localizedDescription)" }
            }
            .confirmationDialog("Importer \(pending?.cities.count ?? 0) villes et appliquer les réglages ? Les villes déjà présentes sont conservées.", isPresented: $confirm, titleVisibility: .visible) {
                Button("Importer") { apply() }
                Button("Annuler", role: .cancel) { pending = nil }
            }
            .alert("Sauvegarde", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") { message = nil }
            } message: { Text(message ?? "") }
    }
    private func export() {
        let defaults = UserDefaults.standard
        let defaultStrings = ["Orbisol.appearance": "system", "Orbisol.clockTypeface": "orbitron", "Orbisol.startupCity": "", "Orbisol.weather.order": "[]", "Orbisol.weather.hidden": "[]", "Orbisol.trips": "[]", "Orbisol.workingHours": "{}", "Orbisol.homeFocus": "clocks", "Orbisol.alertProfiles": "[]"]
        let backup = SettingsBackup(cities: model.locations, alerts: model.alertPreferences, hour12: model.hour12,
            fahrenheit: model.unitFahrenheit, rain: model.rainAlertsEnabled, threshold: model.rainThreshold, lead: model.rainLeadMinutes,
            strings: Dictionary(uniqueKeysWithValues: SettingsBackup.stringKeys.map { key in (key, defaults.string(forKey: key) ?? defaultStrings[key]!) }),
            switches: Dictionary(uniqueKeysWithValues: SettingsBackup.boolKeys.map { key in
                (key, (defaults.object(forKey: key) as? Bool) ?? (key != "Orbisol.clock.nightAuto" && key != "Orbisol.highLegibility"))
            }))
        do { file = BackupFile(data: try JSONEncoder().encode(backup)); exporting = true }
        catch { message = error.localizedDescription }
    }
    private func apply() {
        guard let backup = pending else { return }
        model.importCities(backup.cities)
        model.alertPreferences = backup.alerts; model.saveAlertPreferences()
        model.setHour12(backup.hour12); model.setUnitFahrenheit(backup.fahrenheit)
        model.setRainThreshold(backup.threshold); model.setRainLeadMinutes(backup.lead)
        model.setRainAlerts(backup.rain)
        for (key, value) in backup.strings { UserDefaults.standard.set(value, forKey: key) }
        for (key, value) in backup.switches { UserDefaults.standard.set(value, forKey: key) }
        model.reloadAlertProfiles()
        pending = nil; message = "Sauvegarde importée. Les villes existantes ont été conservées."
    }
}
