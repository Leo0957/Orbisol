import SwiftUI
import AppIntents
import BackgroundTasks

/// Point d'entrée de l'application (généré automatiquement par le template SwiftUI).
/// MVVM : `LocationsViewModel` est créé une seule fois et partagé via `environmentObject`.
@main
struct MeteoHeureApp: App {
    nonisolated private static let refreshID = "com.example.meteoheure.weather-refresh"

    @StateObject private var viewModel = LocationsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(viewModel)
                // Gestion du cycle de vie : on coupe l'horloge en arrière-plan
                // et on rafraîchit la météo au retour au premier plan.
                .onChange(of: scenePhase) { phase in
                    viewModel.handleScenePhase(phase)
                    if phase == .background { scheduleRefresh() }
                }
                .onAppear {
                    scheduleRefresh()
                    if UIApplication.shared.applicationState == .active {
                        viewModel.handleScenePhase(.active)
                    }
                }
        }
        .backgroundTask(.appRefresh(Self.refreshID)) {
            Self.scheduleRefresh()
            await viewModel.refreshBackgroundWeather()
        }
    }

    nonisolated private static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func scheduleRefresh() { Self.scheduleRefresh() }
}

struct OrbisolShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenCityIntent(), phrases: ["Ouvrir une ville dans \(.applicationName)"], shortTitle: "Météo d’une ville", systemImageName: "cloud.sun")
        AppShortcut(intent: CityTimeIntent(), phrases: ["L’heure d’une ville avec \(.applicationName)"], shortTitle: "Heure locale", systemImageName: "clock")
    }
}
