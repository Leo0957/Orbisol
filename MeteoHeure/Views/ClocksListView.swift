import SwiftUI

/// Écran « Horloges » de la maquette.
/// En-tête de section, puis la liste des villes suivies. Chaque ligne :
/// fuseau (UTC+2) + ville + pays à gauche, heure locale en gros chiffres
/// + suffixe am/pm à droite, et une ligne météo discrète (temp · temps).
/// La carte « Ajouter une ville » ferme la liste.
struct ClocksListView: View {
    @EnvironmentObject private var viewModel: LocationsViewModel
    @AppStorage("Orbisol.homeFocus") private var homeFocus = "clocks"
    @AppStorage("Orbisol.highLegibility") private var highLegibility = false
    @ScaledMetric(relativeTo: .largeTitle) private var clockSize: CGFloat = 44
    let onSelect: (Location) -> Void
    let onAdd: () -> Void
    let onShowWeather: () -> Void
    @State private var showPlanner = false
    @State private var showOrganizer = false
    @State private var query = ""
    @State private var worldwideResults: [Location] = []
    @State private var worldwideError: String?
    @State private var isSearchingWorldwide = false
    @State private var worldwideTask: Task<Void, Never>?
    @State private var preview: Location?
    @State private var isLocating = false
    @State private var locatedCity: Location?
    @State private var showLocationProposal = false
    @State private var showLocationError = false
    @State private var locationError = ""
    @State private var locationNotice: String?
    private let searchSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.15, alpha: 1)
            : UIColor(white: 0.91, alpha: 1)
    })
    private let locationSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.17, alpha: 1)
            : UIColor(white: 0.98, alpha: 1)
    })
    private var visibleCities: [Location] {
        let matches = viewModel.locations.filter {
            query.isEmpty || ($0.name + " " + $0.countrySubtitle + " " + ($0.group ?? "")).localizedStandardContains(query)
        }
        return matches.filter { $0.favorite == true } + matches.filter { $0.favorite != true }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                    VStack(spacing: 0) {
                        ScreenHeader(eyebrow: "Horloges",
                                     title: "Villes suivies",
                                     subtitle: "Fuseaux, météo rapide et pluie à venir")
                            .padding(.top, 18)
                            .padding(.bottom, 4)
                        if homeFocus != "clocks", let city = viewModel.selectedLocation {
                            homeCard(city)
                                .padding(.vertical, 12)
                        }

                        HStack(spacing: 11) {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Theme.dim)
                                TextField("Rechercher une ville dans le monde", text: $query)
                                    .foregroundStyle(Theme.ink)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.words)
                                    .accessibilityLabel("Rechercher une ville dans le monde")
                                if !query.isEmpty {
                                    Button { query = "" } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(Theme.dim)
                                    }
                                    .accessibilityLabel("Effacer la recherche")
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(searchSurface, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.line.opacity(0.55), lineWidth: 0.5))

                            Button(action: locateCity) {
                                Group {
                                    if isLocating {
                                        ProgressView().tint(Theme.ink)
                                    } else {
                                        Image(systemName: "location.viewfinder")
                                            .font(.system(size: 19, weight: .medium))
                                            .foregroundStyle(Theme.ink)
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .background(locationSurface, in: Circle())
                                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .disabled(isLocating)
                            .accessibilityLabel(isLocating ? "Localisation en cours" : "Trouver ma ville actuelle")
                            .accessibilityHint("Recherche votre ville à partir de votre position")
                        }
                        .padding(.vertical, 14)
                        if let locationNotice {
                            Text(locationNotice)
                                .font(.caption)
                                .foregroundStyle(Theme.dim)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.bottom, 8)
                        }
                        if !query.isEmpty {
                            Text("Villes suivies").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if visibleCities.isEmpty && !query.isEmpty {
                            Text("Aucune ville déjà suivie ne correspond.").font(.caption).foregroundStyle(Theme.dim)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                        }
                        ForEach(visibleCities) { location in
                            row(location)
                            Hairline()
                        }
                        if !query.isEmpty {
                            Text("Recherche mondiale")
                                .font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 15)
                            if isSearchingWorldwide { ProgressView("Recherche de villes…").padding(.vertical) }
                            else if let worldwideError {
                                Text(worldwideError).font(.caption).foregroundStyle(Theme.dim)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical)
                            } else if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                                Text("Saisissez au moins deux caractères.").font(.caption).foregroundStyle(Theme.dim)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical)
                            } else {
                                ForEach(worldwideResults) { city in
                                    Button { preview = city } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(city.name).font(.subheadline.bold())
                                                Text(city.subtitle).font(.caption).foregroundStyle(Theme.dim)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                        }
                                        .contentShape(Rectangle()).padding(.vertical, 9)
                                    }
                                    .buttonStyle(.plain)
                                    Hairline()
                                }
                            }
                            Text("Pour un village homonyme, précisez « village, pays » ou cherchez son code postal.")
                                .font(.caption2).foregroundStyle(Theme.dim)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
                        }
                        HStack {
                            Button { showPlanner = true } label: { Label("Comparer", systemImage: "globe") }
                            Spacer()
                            Button { showOrganizer = true } label: { Label("Organiser", systemImage: "list.bullet") }
                        }.padding(.vertical, 16)
                        if viewModel.canUndoRemoval {
                            Button { viewModel.undoRemoval() } label: { Label("Annuler la suppression", systemImage: "arrow.uturn.backward") }
                        }
                        addCard
                            .padding(.top, 18)
                            .padding(.bottom, 4)
                    }
                    .padding(.horizontal, 20)
            }
        }
        .onChange(of: query) {
            locationNotice = nil
            scheduleWorldwideSearch($0)
        }
        .onDisappear { worldwideTask?.cancel() }
        .sheet(item: $preview) { location in
            CitySearchPreview(location: location, isSaved: viewModel.savedMatch(for: location) != nil) {
                viewModel.addAndSelect(location)
                preview = nil
                query = ""
                onShowWeather()
            }
            .environmentObject(viewModel)
        }
        .sheet(isPresented: $showPlanner) {
            NavigationStack { WorldPlannerView().toolbar { Button("Fermer") { showPlanner = false } } }
        }
        .sheet(isPresented: $showOrganizer) {
            NavigationStack { CityOrganizerView().toolbar { Button("Fermer") { showOrganizer = false } } }
        }
        .confirmationDialog("Ajouter cette ville aux horloges ?",
                            isPresented: $showLocationProposal,
                            titleVisibility: .visible) {
            if let locatedCity {
                Button("Ajouter \(locatedCity.name)") {
                    viewModel.addAndSelect(locatedCity)
                    query = locatedCity.name
                    locationNotice = "\(locatedCity.name) a été ajoutée aux horloges."
                    self.locatedCity = nil
                }
            }
            Button("Annuler", role: .cancel) { locatedCity = nil }
        } message: {
            if let locatedCity {
                Text("\(locatedCity.name), \(locatedCity.countrySubtitle) · \(locatedCity.timeZoneIdentifier)")
            }
        }
        .alert("Localisation indisponible", isPresented: $showLocationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(locationError)
        }
    }

    private func locateCity() {
        guard !isLocating else { return }
        isLocating = true
        locationNotice = nil
        Task {
            defer { isLocating = false }
            do {
                let city = try await viewModel.locateCurrentCity()
                if let followed = viewModel.followedCity(matching: city) {
                    viewModel.select(followed.id)
                    query = followed.name
                    locationNotice = "\(followed.name) est déjà dans vos horloges."
                } else {
                    locatedCity = city
                    showLocationProposal = true
                }
            } catch {
                locationError = error.localizedDescription
                showLocationError = true
            }
        }
    }

    private func scheduleWorldwideSearch(_ text: String) {
        worldwideTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        worldwideResults = []
        worldwideError = nil
        guard trimmed.count >= 2 else { isSearchingWorldwide = false; return }
        isSearchingWorldwide = true
        worldwideTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            do {
                let cities = try await viewModel.searchLocations(query: trimmed)
                guard !Task.isCancelled else { return }
                worldwideResults = cities
                worldwideError = cities.isEmpty ? "Aucune localité trouvée. Essayez une autre orthographe ou le code postal." : nil
            } catch {
                guard !Task.isCancelled else { return }
                worldwideError = "Recherche indisponible : \(error.localizedDescription)"
            }
            isSearchingWorldwide = false
        }
    }

    // MARK: - Ligne horloge

    private func row(_ location: Location) -> some View {
        let t = ClockFormat.time(timeZone: location.timeZone ?? .current,
                                 hour12: viewModel.hour12,
                                 date: viewModel.now)
        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ClockFormat.utcLabel(timeZone: location.timeZone ?? .current))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.dim)
                HStack(spacing: 7) {
                    Text(location.name.uppercased())
                    .font(highLegibility ? .system(.title2, weight: .bold) : .system(size: 20, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.ink)
                    if viewModel.isPrimary(location) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.accent)
                            .accessibilityLabel("Ville principale")
                    }
                    if location.favorite == true { Image(systemName: "pin.fill").font(.caption).foregroundStyle(Theme.accent) }
                }
                Text(location.countrySubtitle)
                    .font(.system(size: 12.5, weight: .regular))
                    .tracking(0.2)
                    .foregroundStyle(Theme.dim)
                Text("\(WorldTime.offset(from: .current, to: location.timeZone ?? .current, at: viewModel.now)) · \(WorldTime.dayDifference(from: .current, to: location.timeZone ?? .current, at: viewModel.now))")
                    .font(.caption2).foregroundStyle(Theme.dim)
                if let current = viewModel.weatherByLocation[location.id]?.current {
                    weatherLine(current, location: location)
                        .padding(.top, 3)
                }
                Text(viewModel.dataStatus(for: location).label)
                    .font(.caption2)
                    .foregroundStyle(Theme.dim)
            }
            Spacer(minLength: 12)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(t.text)
                    .clockTypeface(highLegibility ? clockSize * 1.1 : clockSize, weight: .bold)
                    .lineLimit(1).minimumScaleFactor(0.55)
                    .tracking(0.5)
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                if !t.suffix.isEmpty {
                    VStack(spacing: 3) {
                        Circle().fill(Theme.dim).frame(width: 3.5, height: 3.5)
                        Text(t.suffix)
                            .font(.system(size: 9.5, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.dim)
                    }
                }
            }
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .onTapGesture { onSelect(location) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onSelect(location) }
        .contextMenu {
            Button { viewModel.toggleFavorite(location) } label: {
                Label(location.favorite == true ? "Retirer des favoris" : "Épingler aux favoris", systemImage: "pin")
            }
            if !viewModel.isPrimary(location) {
                Button {
                    viewModel.makePrimary(location)
                } label: {
                    Label("Ville principale", systemImage: "star")
                }
            }
            Button(role: .destructive) {
                viewModel.remove(location)
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    private func homeCard(_ city: Location) -> some View {
        let weather = viewModel.weatherByLocation[city.id]
        let title: String
        let value: String
        switch homeFocus {
        case "rain":
            title = "PLUIE · \(city.name.uppercased())"
            value = viewModel.nextRainText(for: city) ?? "Prévision de pluie indisponible"
        case "air":
            title = "AIR · \(city.name.uppercased())"
            value = viewModel.airQualityByLocation[city.id]?.current?.europeanAqi.map { "AQI européen \($0)" } ?? "Qualité de l’air indisponible"
        default:
            title = "SORTIE · \(city.name.uppercased())"
            let hours = WeatherInsights.hours(weather, zone: city.timeZone ?? .current)
            let best = WeatherInsights.bestWindow(hours, after: Date(), zone: city.timeZone ?? .current)
            value = best.first.map { "À partir de " + WorldTime.time($0.date, zone: city.timeZone ?? .current, hour12: viewModel.hour12) } ?? "Créneau indisponible"
        }
        return VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.bold()).foregroundStyle(Theme.accent)
            Text(value).font(highLegibility ? .title2.bold() : .headline).foregroundStyle(Theme.ink)
            Text(viewModel.dataStatus(for: city).label).font(.caption).foregroundStyle(Theme.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(Theme.paper.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: highLegibility ? 2 : 1))
        .accessibilityElement(children: .combine)
    }

    /// « 18° · ciel clair » — ou « 18° · pluie vers 11 am » si la pluie approche.
    private func weatherLine(_ current: OpenMeteoResponse.Current, location: Location) -> some View {
        HStack(spacing: 6) {
            Image(systemName: WeatherStyle.symbol(code: current.weatherCode,
                                                  isDay: current.isDay == 1))
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 15)
            Text(weatherSummary(current, location: location))
                .font(.system(size: 12.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Theme.dim)
        }
    }

    private func weatherSummary(_ current: OpenMeteoResponse.Current, location: Location) -> String {
        let temperature = viewModel.tempText(current.temperature2m, for: location)
        if case .soon(_, let hour) = viewModel.nextRain(for: location) {
            return "\(temperature) · pluie vers \(ClockFormat.shortHour(hour: hour, hour12: viewModel.hour12))"
        }
        return "\(temperature) · \(WeatherStyle.shortCondition(code: current.weatherCode))"
    }

    // MARK: - Carte « ajouter » (dégradé pêche → bleu de la maquette)

    private var addCard: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(colors: [
                        Color(red: 0.99, green: 0.83, blue: 0.61),
                        Color(red: 0.66, green: 0.83, blue: 0.95),
                        Color(red: 0.42, green: 0.65, blue: 0.88)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            HStack {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
            }
            .padding(20)

            VStack(alignment: .leading, spacing: 3) {
                Spacer()
                Text("Ajouter une ville")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(.white)
                Text("ville · pays · région")
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(20)

            Button {
                onAdd()
            } label: {
                ZStack {
                    Circle().fill(.white)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
            }
            .padding(14)
            .accessibilityLabel("Ajouter une ville")
        }
        .frame(height: 158)
    }

}
