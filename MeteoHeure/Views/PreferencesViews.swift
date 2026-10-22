import SwiftUI

struct CityOrganizerView: View {
    @EnvironmentObject private var model: LocationsViewModel
    var body: some View {
        List {
            NavigationLink { TripsView() } label: { Label("Voyages datés", systemImage: "suitcase") }
            ForEach(model.locations) { city in
                VStack(alignment: .leading, spacing: 8) {
                    Text(city.name).font(.headline)
                    TextField("Groupe ou voyage", text: Binding(get: {
                        model.locations.first(where: { $0.id == city.id })?.group ?? ""
                    }, set: { model.setGroup($0, for: city) }))
                    .font(.subheadline)
                }
            }
            .onMove(perform: model.move)
            .onDelete(perform: model.remove)
            if model.canUndoRemoval {
                Button { model.undoRemoval() } label: { Label("Annuler la suppression", systemImage: "arrow.uturn.backward") }
            }
        }
        .navigationTitle("Villes & voyages")
        .toolbar { EditButton() }
    }
}

struct AlertCenterView: View {
    @EnvironmentObject private var model: LocationsViewModel
    @Environment(\.openURL) private var openURL
    @State private var profileName = ""
    var body: some View {
        Form {
            Section("Profils d’alertes") {
                Text("Profil actif : " + (model.alertProfiles.first { $0.id == model.activeAlertProfileID }?.name ?? "Personnalisé"))
                ForEach(model.alertProfiles) { profile in
                    Button(profile.name) { model.activateAlertProfile(profile.id) }
                }.onDelete(perform: model.deleteAlertProfiles)
                HStack {
                    TextField("Nom du nouveau profil", text: $profileName)
                    Button("Enregistrer") {
                        model.saveCurrentAlertProfile(named: profileName)
                        profileName = ""
                    }.disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Text("Enregistre les seuils, les villes exclues et les heures silencieuses actuels. Balayez un profil pour le supprimer.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Notifications") {
                Text(model.notificationStatus)
                Button("Demander l’autorisation") { Task { await model.authorizeNotifications() } }
                Button("Réglages iOS") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                Toggle("Pluie", isOn: Binding(get: { model.rainAlertsEnabled }, set: model.setRainAlerts))
                Picker("Probabilité minimale", selection: Binding(get: { model.rainThreshold }, set: model.setRainThreshold)) {
                    ForEach([40, 55, 70], id: \.self) { Text("\($0) %").tag($0) }
                }
                Picker("Préavis", selection: Binding(get: { model.rainLeadMinutes }, set: model.setRainLeadMinutes)) {
                    ForEach([30, 60, 120], id: \.self) { Text("\($0) min").tag($0) }
                }
                Toggle("Vent soutenu", isOn: $model.alertPreferences.windEnabled)
                if model.alertPreferences.windEnabled {
                    Stepper("À partir de \(Int(model.alertPreferences.windThreshold)) km/h", value: $model.alertPreferences.windThreshold, in: 20...120, step: 5)
                }
                Toggle("Température élevée", isOn: $model.alertPreferences.temperatureEnabled)
                if model.alertPreferences.temperatureEnabled {
                    Stepper("À partir de \(Int(model.alertPreferences.temperatureThreshold)) °C", value: $model.alertPreferences.temperatureThreshold, in: 15...45)
                }
                Toggle("Température basse", isOn: Binding(get: { model.alertPreferences.coldEnabled == true }, set: { model.alertPreferences.coldEnabled = $0 }))
                if model.alertPreferences.coldEnabled == true {
                    Stepper("Au-dessous de \(Int(model.alertPreferences.coldThreshold ?? 0)) °C", value: Binding(get: { model.alertPreferences.coldThreshold ?? 0 }, set: { model.alertPreferences.coldThreshold = $0 }), in: -30...15)
                }
                Toggle("Qualité de l’air", isOn: Binding(get: { model.alertPreferences.airEnabled == true }, set: { model.alertPreferences.airEnabled = $0 }))
                if model.alertPreferences.airEnabled == true {
                    Stepper("AQI européen à partir de \(model.alertPreferences.airThreshold ?? 80)", value: Binding(get: { model.alertPreferences.airThreshold ?? 80 }, set: { model.alertPreferences.airThreshold = $0 }), in: 40...150, step: 10)
                }
                Toggle("Pollens", isOn: Binding(get: { model.alertPreferences.pollenEnabled == true }, set: { model.alertPreferences.pollenEnabled = $0 }))
                if model.alertPreferences.pollenEnabled == true {
                    Stepper("À partir de \(Int(model.alertPreferences.pollenThreshold ?? 50)) grains/m³", value: Binding(get: { model.alertPreferences.pollenThreshold ?? 50 }, set: { model.alertPreferences.pollenThreshold = Double($0) }), in: 10...200, step: 10)
                }
            }
            Section {
                Toggle("Heures silencieuses", isOn: $model.alertPreferences.quietEnabled)
                if model.alertPreferences.quietEnabled {
                    Picker("Début", selection: $model.alertPreferences.quietStart) { ForEach(0..<24, id: \.self) { Text("\($0) h").tag($0) } }
                    Picker("Fin", selection: $model.alertPreferences.quietEnd) { ForEach(0..<24, id: \.self) { Text("\($0) h").tag($0) } }
                }
            } header: { Text("Votre heure locale") } footer: {
                Text("Les alertes qui tombent dans cette plage ne sont pas programmées. Une plage avec début et fin identiques couvre toute la journée.")
            }
            Section("Villes concernées") {
                ForEach(model.locations) { city in
                    Toggle(city.name, isOn: Binding(get: { !model.alertPreferences.excludedCities.contains(city.id) }, set: { enabled in
                        if enabled { model.alertPreferences.excludedCities.remove(city.id) }
                        else { model.alertPreferences.excludedCities.insert(city.id) }
                    }))
                }
            }
            Section {
                if model.pendingAlerts.isEmpty { Text("Aucune alerte programmée.") }
                ForEach(model.pendingAlerts, id: \.identifier) { request in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(request.content.title)
                        if let date = request.plannedDate { Text(date, style: .date); Text(date, style: .time) }
                    }
                }
            } header: { Text("Programmées") } footer: {
                Text("Prévisions locales, pas des alertes officielles. La programmation est révisée à l’ouverture et lors des actualisations. Ouvrez l’app pour obtenir de nouvelles prévisions.")
            }
        }
        .navigationTitle("Centre des alertes")
        .task { await model.refreshNotificationStatus() }
        .onChange(of: model.alertPreferences) { _ in model.saveAlertPreferences() }
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject private var model: LocationsViewModel
    @AppStorage("Orbisol.startupCity") private var startupCity = ""
    @AppStorage("Orbisol.clock.nightAuto") private var nightAuto = false
    @AppStorage("Orbisol.appearance") private var appearance = "system"
    @AppStorage("Orbisol.clock.seconds") private var seconds = true
    @AppStorage("Orbisol.clock.date") private var date = true
    @AppStorage("Orbisol.clock.weather") private var weather = true
    @AppStorage("Orbisol.homeFocus") private var homeFocus = "clocks"
    @AppStorage("Orbisol.highLegibility") private var highLegibility = false
    var body: some View {
        Form {
            Section("Apparence") {
                Picker("Thème", selection: $appearance) {
                    Text("Système").tag("system")
                    Text("Clair").tag("light")
                    Text("Sombre").tag("dark")
                }.pickerStyle(.segmented)
            }
            Section("Grand format") {
                Toggle("Mode nuit automatique · 22 h–8 h", isOn: $nightAuto)
                Toggle("Secondes", isOn: $seconds)
                Toggle("Date", isOn: $date)
                Toggle("Météo", isOn: $weather)
            }
            Section("Au démarrage") {
                Picker("Ville", selection: $startupCity) {
                    Text("Dernière ville consultée").tag("")
                    ForEach(model.locations) { Text($0.name).tag($0.id.uuidString) }
                }
                Picker("Information mise en avant", selection: $homeFocus) {
                    Text("Horloges").tag("clocks")
                    Text("Pluie").tag("rain")
                    Text("Qualité de l’air").tag("air")
                    Text("Créneau de sortie").tag("outing")
                }
            }
            Section("Accessibilité") {
                Toggle("Lisibilité renforcée", isOn: $highLegibility)
                Text("Agrandit les informations clés et renforce leur contraste. La taille de texte choisie dans iOS reste respectée.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Apparence & horloge")
    }
}
