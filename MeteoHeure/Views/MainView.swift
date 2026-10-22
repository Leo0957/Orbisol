import SwiftUI

// MARK: - Écran racine
//
// Reprend la maquette : fond papier, barre du haut partagée
// (logo, toggle 12h/24h) et quatre écrans navigables par la barre
// d'onglets en verre en bas — Horloges, Météo, Grand format, Réglages.
//
// iOS 26 utilise la barre système pour la lentille interactive Liquid Glass.
// Les versions antérieures conservent la capsule personnalisée.

struct MainView: View {
    @EnvironmentObject private var viewModel: LocationsViewModel
    @AppStorage(ClockTypeface.storageKey) private var clockTypeface = ClockTypeface.orbitron.rawValue
    @AppStorage("Orbisol.appearance") private var appearance = "system"
    @State private var confirmDelete = false
    @State private var sharedMeetingDate: Date?
    @State private var sharedMeetingCities: Set<UUID>?

    enum Screen { case clocks, weather, big, settings }

    @State private var screen: Screen = MainView.initialScreen
    @State private var settingsPath: [String] = {
        #if DEBUG
        let route = ProcessInfo.processInfo.environment["MH_TAB"] ?? ""
        return ["fonts", "appearance", "alerts", "cities", "planner", "trips", "weatherLayout", "backup", "radar"].contains(route) ? [route] : []
        #else
        return []
        #endif
    }()

    /// Onglet de départ ; en debug, `MH_TAB` (simctl launch) force un écran
    /// pour capturer facilement les quatre onglets.
    private static var initialScreen: Screen {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["MH_TAB"] {
        case "weather": return .weather
        case "big": return .big
        case "settings", "fonts", "appearance", "alerts", "cities", "planner", "trips", "weatherLayout", "backup", "radar": return .settings
        default: return .clocks
        }
        #else
        return .clocks
        #endif
    }
    @State private var showAdd = false
    @State private var forecastLocation: Location?
    @State private var alertMessage: String?

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                nativeTabLayout
            } else {
                legacyTabLayout
            }
        }
        .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        .confirmationDialog("Supprimer toutes les villes ?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Tout supprimer", role: .destructive) { viewModel.removeAll() }
            Button("Annuler", role: .cancel) {}
        }
        .onOpenURL { url in
            if url.scheme == "orbisol", url.host == "meeting" {
                let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
                let fields = parts?.queryItems ?? []
                guard let raw = fields.first(where: { $0.name == "at" })?.value,
                      let seconds = Double(raw), seconds.isFinite,
                      abs(Date().timeIntervalSince1970 - seconds) < 3 * 365 * 86400 else { return }
                let ids = Set(fields.filter { $0.name == "city" }.compactMap { $0.value.flatMap(UUID.init(uuidString:)) })
                guard !ids.isEmpty, ids.count <= 12 else { return }
                let saved = Set(viewModel.locations.map(\.id))
                guard ids.isSubset(of: saved) else { return }
                sharedMeetingDate = Date(timeIntervalSince1970: seconds)
                sharedMeetingCities = ids
                settingsPath = ["planner"]
                screen = .settings
                return
            }
            guard url.scheme == "orbisol", let id = UUID(uuidString: url.lastPathComponent),
                  viewModel.locations.contains(where: { $0.id == id }) else { return }
            viewModel.select(id)
            screen = url.host == "clock" ? .big : .weather
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("Orbisol.openCity"))) { _ in openRequestedCity() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in openRequestedCity() }
        .onChange(of: viewModel.errorMessage) { message in
            if let message {
                alertMessage = message
                viewModel.clearError()
            }
        }
        .alert("Orbisol", isPresented: alertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(isPresented: $showAdd) {
            AddLocationView(onAdded: { screen = .weather })
        }
        .sheet(item: $forecastLocation) { location in
            NavigationStack {
                DetailView(location: location)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Fermer") { forecastLocation = nil }
                        }
                    }
            }
        }
        .onAppear {
            openRequestedCity()
            // Sélectionne la première ville par défaut.
            if viewModel.selectedLocation == nil, let first = viewModel.locations.first {
                viewModel.select(first.id)
            }
        }
    }

    private func openRequestedCity() {
        let defaults = UserDefaults(suiteName: LocationsViewModel.sharedGroupSuite)
        guard let raw = defaults?.string(forKey: "Orbisol.requestedCity"), let id = UUID(uuidString: raw),
              viewModel.locations.contains(where: { $0.id == id }) else { return }
        defaults?.removeObject(forKey: "Orbisol.requestedCity")
        viewModel.select(id)
        screen = .weather
    }

    @available(iOS 26.0, *)
    private var nativeTabLayout: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 12)

            Rectangle().fill(Theme.line).frame(height: 1)

            TabView(selection: $screen) {
                Tab("Horloges", systemImage: "clock", value: Screen.clocks) {
                    content(for: .clocks)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.paper)
                }
                Tab("Météo", systemImage: "cloud.sun", value: Screen.weather) {
                    content(for: .weather)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.paper)
                }
                Tab("Grand format", systemImage: "gauge", value: Screen.big) {
                    content(for: .big)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.paper)
                }
                Tab("Réglages", systemImage: "gearshape", value: Screen.settings) {
                    content(for: .settings)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.paper)
                }
            }
            .tint(.primary)
            .tabBarMinimizeBehavior(.never)
        }
        .background(Theme.paper.ignoresSafeArea())
    }

    private var legacyTabLayout: some View {
        GeometryReader { geometry in
            let topInset = geometry.safeAreaInsets.top
            let tabBottomPadding = geometry.safeAreaInsets.bottom + 12
            let contentBottomPadding = tabBottomPadding + BottomTabBar.height + 16

            ZStack(alignment: .bottom) {
                Theme.paper.ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, topInset + 6)
                        .padding(.bottom, 12)

                    Rectangle().fill(Theme.line).frame(height: 1)

                    content(for: screen)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.bottom, contentBottomPadding)
                }
                .animation(.easeInOut(duration: 0.25), value: screen)

                BottomTabBar(selection: $screen)
                    .padding(.horizontal, 16)
                    .padding(.bottom, tabBottomPadding)
            }
        }
    }

    // MARK: - Barre du haut

    private var topBar: some View {
        HStack {
            LogoMark()
            Spacer()
            FormatToggle(hour12: viewModel.hour12) { viewModel.setHour12($0) }
        }
    }

    // MARK: - Contenu (écran courant)

    @ViewBuilder
    private func content(for screen: Screen) -> some View {
        switch screen {
        case .clocks:
            ClocksListView(onSelect: { location in
                viewModel.select(location.id)
                withAnimation { self.screen = .big }
            }, onAdd: { showAdd = true }, onShowWeather: { self.screen = .weather })
        case .weather:
            if let selected = viewModel.selectedLocation {
                WeatherScreen(location: selected,
                              onForecast: { forecastLocation = selected },
                              onAddCity: { showAdd = true })
            } else {
                emptyScreen("Aucune ville — ajoutez-en une depuis l'onglet Réglages.")
            }
        case .big:
            if let selected = viewModel.selectedLocation {
                BigClockScreen(location: selected)
            } else {
                emptyScreen("Aucune ville — ajoutez-en une depuis l'onglet Réglages.")
            }
        case .settings:
            NavigationStack(path: $settingsPath) {
                settingsScreen
                    .navigationDestination(for: String.self) { destination in
                        switch destination {
                        case "appearance": AppearanceSettingsView()
                        case "alerts": AlertCenterView()
                        case "cities": CityOrganizerView()
                        case "planner": WorldPlannerView(initialDate: sharedMeetingDate, initialCities: sharedMeetingCities)
                        case "trips": TripsView()
                        case "weatherLayout": WeatherLayoutSettings()
                        case "backup": BackupSettingsView()
                        case "radar":
                            if let city = viewModel.selectedLocation { RadarView(location: city) }
                        default: ClockTypefaceSettings()
                        }
                    }
                    .navigationTitle("Réglages")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(Theme.paper, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tint(Theme.ink)
        }
    }

    private var alertPresented: Binding<Bool> {
        Binding(get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } })
    }

    private func emptyScreen(_ message: String) -> some View {
        VStack {
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.dim)
                .multilineTextAlignment(.center)
                .padding(30)
            Spacer()
        }
    }

    // MARK: - Réglages (onglet)

    private var settingsScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ScreenHeader(eyebrow: "Réglages",
                             title: "Préférences",
                             subtitle: "Polices, unités, alertes et synchronisation")
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    NavigationLink(value: "trips") { Label("Voyages datés", systemImage: "suitcase").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14) }
                    Hairline()
                    NavigationLink(value: "weatherLayout") { Label("Sections météo", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14) }
                    Hairline()
                    NavigationLink(value: "backup") { Label("Sauvegarde", systemImage: "externaldrive").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14) }
                    Hairline()
                    NavigationLink(value: "appearance") { Label("Apparence & horloge", systemImage: "circle.lefthalf.filled").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14) }
                    Hairline()
                    NavigationLink(value: "alerts") { Label("Centre des alertes", systemImage: "bell").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14) }
                    Hairline()
                    NavigationLink(value: "cities") { Label("Villes & voyages", systemImage: "list.bullet").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14) }
                    Hairline()
                    NavigationLink(value: "planner") { Label("Comparer les heures", systemImage: "globe").frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 14) }
                    Hairline()
                    NavigationLink(value: "fonts") {
                        HStack(spacing: 12) {
                            Image(systemName: "textformat")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 34, height: 34)
                                .background(Theme.peach, in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Police d’écriture").font(.system(size: 16, weight: .semibold))
                                Text((ClockTypeface(rawValue: clockTypeface) ?? .orbitron).title)
                                    .font(.caption).foregroundStyle(Theme.dim)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.faint)
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Hairline()
                    actionRow("Ajouter une ville", icon: "plus") { showAdd = true }
                    Hairline()
                    actionRow("Ma position", icon: "scope") {
                        Task { await viewModel.addCurrentLocation() }
                    }
                    Hairline()
                        .padding(.top, 10)
                    settingsList
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(Theme.paper)
    }

    private func actionRow(_ title: String, icon: String,
                           action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Theme.peach)
                Image(systemName: icon)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(width: 34, height: 34)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.faint)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Réglages (réglages proprement dits)

    private var settingsList: some View {
        VStack(spacing: 0) {
            settingRow("UNITÉ") {
                UnitToggle(fahrenheit: viewModel.unitFahrenheit) { viewModel.setUnitFahrenheit($0) }
            }
            Hairline()
            settingRow("FORMAT") {
                FormatToggle(hour12: viewModel.hour12) { viewModel.setHour12($0) }
            }
            Hairline()
            settingRow("DONNÉES") {
                Button("Actualiser") { Task { await viewModel.refreshAllWeather() } }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            Hairline()

            // PLUIE : libellé + résumé de la ville principale + interrupteur.
            HStack(spacing: 10) {
                settingLabel("PLUIE")
                Spacer(minLength: 8)
                if let next = viewModel.nextRainText(for: rainSummaryLocation) {
                    Text(next)
                        .font(.system(size: 11.5, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(Theme.dim)
                }
                Toggle("", isOn: Binding(get: { viewModel.rainAlertsEnabled },
                                         set: { viewModel.setRainAlerts($0) }))
                    .labelsHidden()
                    .tint(Theme.accent)
            }
            .padding(.vertical, 11)

            if viewModel.rainAlertsEnabled {
                Hairline()
                settingRow("SEUIL") {
                    OptionToggle(options: [(40, "40 %"), (55, "55 %"), (70, "70 %")],
                                 selected: viewModel.rainThreshold) { viewModel.setRainThreshold($0) }
                }
                Hairline()
                settingRow("PRÉAVIS") {
                    OptionToggle(options: [(30, "30 min"), (60, "1 h"), (120, "2 h")],
                                 selected: viewModel.rainLeadMinutes) { viewModel.setRainLeadMinutes($0) }
                }
            }
            Hairline()
            settingRow("SYNC iCLOUD") {
                Toggle("", isOn: Binding(get: { viewModel.cloudSyncEnabled },
                                         set: { viewModel.setCloudSync($0) }))
                    .labelsHidden()
                    .tint(Theme.accent)
            }
            Text(viewModel.cloudStatus).font(.caption).foregroundStyle(Theme.dim).padding(.vertical, 8)
            Hairline()
            HStack(spacing: 12) {
                settingLabel("VILLES")
                Spacer()
                Button("Tout effacer", role: .destructive) { confirmDelete = true }
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .padding(.vertical, 11)
            if viewModel.canUndoRemoval {
                Button { viewModel.undoRemoval() } label: { Label("Annuler la suppression", systemImage: "arrow.uturn.backward") }
                    .padding(.vertical, 12)
            }
        }
    }

    /// Ligne de réglage type : libellé discret à gauche, contrôle à droite.
    private func settingRow<Control: View>(_ label: String,
                                           @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            settingLabel(label)
            Spacer()
            control()
        }
        .padding(.vertical, 11)
    }

    private func settingLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(2)
            .foregroundStyle(Theme.dim)
    }

    /// Ville servant au résumé de pluie des réglages (principale, sinon première).
    private var rainSummaryLocation: Location {
        viewModel.selectedLocation ?? viewModel.locations.first ?? Location.defaults[0]
    }
}

#Preview {
    MainView()
        .environmentObject(LocationsViewModel())
}
