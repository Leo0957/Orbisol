import SwiftUI

/// Écran d'ajout : une recherche (ville / pays / région) et une liste de résultats.
/// La recherche est débouncée (300 ms) pour limiter les appels réseau.
struct AddLocationView: View {
    @EnvironmentObject private var viewModel: LocationsViewModel
    @Environment(\.dismiss) private var dismiss
    var onAdded: (() -> Void)? = nil

    @State private var query = ""
    @State private var results: [Location] = []
    @State private var isSearching = false
    @State private var searchErrorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var preview: Location?

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView("Recherche…")
                        Spacer()
                    }
                } else if let message = searchErrorMessage {
                    Text(message)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else if query.count < 2 {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recherchez une ville ou un village partout dans le monde.")
                            .font(.subheadline)
                        Text("Essayez « Reims », « Renty, France » ou un code postal. Ajoutez le pays pour départager les homonymes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                } else if results.isEmpty {
                    Text("Aucun résultat.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(results) { location in
                        Button {
                            preview = location
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(location.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(subtitle(for: location))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: isSaved(location) ? "checkmark.circle" : "chevron.right")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Chercher une ville")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbarBackground(Theme.paper, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Ville, village ou code postal…")
            .tint(Theme.accent)
            .onChange(of: query) { newQuery in
                scheduleSearch(newQuery)
            }
            .onDisappear { searchTask?.cancel() }
            .sheet(item: $preview) { location in
                CitySearchPreview(location: location, isSaved: isSaved(location)) {
                    viewModel.addAndSelect(location)
                    preview = nil
                    dismiss()
                    onAdded?()
                }
                .environmentObject(viewModel)
            }
        }
    }

    // MARK: - Recherche débouncée

    /// Annule la recherche précédente puis en planifie une nouvelle
    /// après 300 ms de pause de frappe.
    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            isSearching = false
            searchErrorMessage = nil
            return
        }
        isSearching = true
        searchErrorMessage = nil

        let task = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // debounce
            guard !Task.isCancelled else { return }
            do {
                let found = try await viewModel.searchLocations(query: trimmed)
                guard !Task.isCancelled else { return }
                searchErrorMessage = found.isEmpty ? "Aucun résultat pour « \(trimmed) ». Essayez le nom local ou un code postal." : nil
                results = found
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                searchErrorMessage = "Recherche indisponible : \(error.localizedDescription)"
            }
            isSearching = false
        }
        searchTask = task
    }

    private func isSaved(_ location: Location) -> Bool {
        viewModel.savedMatch(for: location) != nil
    }

    private func subtitle(for location: Location) -> String {
        var parts: [String] = []
        if let region = location.region, !region.isEmpty { parts.append(region) }
        if let country = location.country, !country.isEmpty { parts.append(country) }
        parts.append(utcLabel(location))
        return parts.joined(separator: " · ")
    }

    /// Libellé « UTC+1 » / « UTC-5:30 » calculé depuis le fuseau du lieu.
    private func utcLabel(_ location: Location) -> String {
        let seconds = location.timeZone?.secondsFromGMT(for: Date()) ?? 0
        let totalMinutes = seconds / 60
        let sign = totalMinutes < 0 ? "-" : "+"
        let hours = abs(totalMinutes) / 60
        let minutes = abs(totalMinutes) % 60
        if minutes == 0 { return "UTC\(sign)\(hours)" }
        return String(format: "UTC%@%d:%02d", sign, hours, minutes)
    }
}

/// Aperçu réseau indépendant : consulter une ville ne l'enregistre pas.
struct CitySearchPreview: View {
    @EnvironmentObject private var viewModel: LocationsViewModel
    @Environment(\.dismiss) private var dismiss
    let location: Location
    let isSaved: Bool
    let onAdd: () -> Void
    @State private var weather: OpenMeteoResponse?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if !location.subtitle.isEmpty { Text(location.subtitle) }
                    Text("Heure locale : \(WorldTime.time(Date(), zone: location.timeZone ?? .current))")
                } header: { Text(location.name) }
                Section("Météo actuelle") {
                    if let current = weather?.current {
                        Label("\(viewModel.tempText(current.temperature2m, for: location)) · \(WeatherStyle.conditionName(code: current.weatherCode))",
                              systemImage: WeatherStyle.symbol(code: current.weatherCode, isDay: current.isDay == 1))
                        Text("Ressenti : \(viewModel.tempText(current.apparentTemperature, for: location))")
                        Text("Humidité : \(current.relativeHumidity2m) %")
                        Text("Vent : \(viewModel.windText(kmPerHour: current.windSpeed10m, for: location))")
                    } else if let error {
                        Text(error).foregroundStyle(.secondary)
                    } else {
                        ProgressView("Chargement de la météo…")
                    }
                }
                if let daily = weather?.daily {
                    Section("Prochains jours") {
                        ForEach(0..<min(3, daily.time.count, daily.temperature2mMin.count, daily.temperature2mMax.count), id: \.self) { index in
                            HStack {
                                Text(daily.time[index])
                                Spacer()
                                Text("\(viewModel.tempText(daily.temperature2mMin[index], for: location)) – \(viewModel.tempText(daily.temperature2mMax[index], for: location))")
                            }
                        }
                    }
                }
                Section {
                    Button(isSaved ? "Voir la météo dans Orbisol" : "Ajouter et voir la météo") { onAdd() }
                        .font(.headline)
                    Text("La météo est une prévision pour les coordonnées de cette localité ; elle ne provient pas forcément d'une station dans le village.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(location.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fermer") { dismiss() } } }
            .task(id: location.id) {
                do { weather = try await WeatherService().fetchWeather(for: location) }
                catch { self.error = "Météo indisponible pour le moment : \(error.localizedDescription)" }
            }
        }
    }
}

#Preview {
    AddLocationView()
        .environmentObject(LocationsViewModel())
}
