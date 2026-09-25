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

    enum Screen { case clocks, weather, big, settings }

    @State private var screen: Screen = MainView.initialScreen

    /// Onglet de départ ; en debug, `MH_TAB` (simctl launch) force un écran
    /// pour capturer facilement les quatre onglets.
    private static var initialScreen: Screen {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["MH_TAB"] {
        case "weather": return .weather
        case "big": return .big
        case "settings": return .settings
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
        .onChange(of: viewModel.errorMessage) { message in
            if let message {
                alertMessage = message
                viewModel.clearError()
            }
        }
        .alert("Météo · Heure", isPresented: alertPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(isPresented: $showAdd) {
            AddLocationView()
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
            // Sélectionne la première ville par défaut.
            if viewModel.selectedLocation == nil, let first = viewModel.locations.first {
                viewModel.select(first.id)
            }
        }
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
            }, onAdd: { showAdd = true })
        case .weather:
            if let selected = viewModel.selectedLocation {
                WeatherScreen(location: selected) {
                    forecastLocation = selected
                }
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
            settingsScreen
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
                             subtitle: "Unités, alertes pluie et synchronisation")
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
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
            Hairline()
            HStack(spacing: 12) {
                settingLabel("VILLES")
                Spacer()
                Button("Tout effacer", role: .destructive) { viewModel.removeAll() }
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .padding(.vertical, 11)
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
