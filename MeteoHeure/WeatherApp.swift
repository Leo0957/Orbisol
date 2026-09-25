import SwiftUI

/// Point d'entrée de l'application (généré automatiquement par le template SwiftUI).
/// MVVM : `LocationsViewModel` est créé une seule fois et partagé via `environmentObject`.
@main
struct MeteoHeureApp: App {

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
                }
        }
    }
}