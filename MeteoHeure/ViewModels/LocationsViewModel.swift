import SwiftUI
import Combine
import UserNotifications
import WidgetKit // rechargement du widget « Jour · Nuit » quand la liste change

// MARK: - ViewModel principal
//
// MVVM : les vues ne mutent jamais l'état directement.
// Toute l'intelligence applicative vit ici :
//   - liste des lieux + persistance (UserDefaults / JSON)
//   - cache météo par lieu (découplé de l'affichage)
//   - horloge « monde » (tick 1×/seconde) pour les heures locales
//   - gestion du cycle de vie (mise en veille / retour au premier plan)

// MARK: - Résumé « prochaine pluie »

/// Pré-calculé par le ViewModel (à chaque mise à jour météo), affiché dans
/// la liste des horloges et l'écran météo — jamais recalculé à chaque tick.
enum NextRain: Equatable {
    /// Données météo pas encore chargées.
    case unknown
    /// Rien de significatif dans les 24 prochaines heures.
    case none
    /// Pluie probable : probabilité (%) + heure locale (heure pleine).
    case soon(probability: Int, hour: Int)
}

enum WeatherDataStatus {
    case loading, unavailable, current(Date), old(Date), offline(Date)

    var label: String {
        switch self {
        case .loading: return "Chargement de la météo"
        case .unavailable: return "Météo indisponible"
        case .current(let date): return "Météo actualisée " + date.formatted(date: .omitted, time: .shortened)
        case .old(let date): return "Météo ancienne · " + date.formatted(date: .omitted, time: .shortened)
        case .offline(let date): return "Hors connexion · prévisions du " + date.formatted(date: .abbreviated, time: .shortened)
        }
    }
}

@MainActor
final class LocationsViewModel: ObservableObject {

    // MARK: État publié (observé par les vues)

    @Published private(set) var locations: [Location] = []
    @Published private(set) var weatherByLocation: [UUID: OpenMeteoResponse] = [:]
    /// Qualité de l'air par lieu.
    @Published private(set) var airQualityByLocation: [UUID: AirQualityResponse] = [:]
    private var airFetchedAt: [UUID: Date] = [:]
    @Published private(set) var loadingIDs: Set<UUID> = []
    @Published private(set) var errorMessage: String?
    /// Horodatage partagé, mis à jour toutes les secondes.
    /// Toutes les horloges (liste, détail, fuseaux) se basent dessus.
    @Published private(set) var now = Date()

    /// Format horaire : true = 12 h (am/pm), false = 24 h.
    @Published private(set) var hour12: Bool
    /// Unité : true = °F, false = °C.
    @Published private(set) var unitFahrenheit: Bool
    /// Lieu sélectionné (écrans Météo / Grand format).
    @Published private(set) var selectedID: UUID?
    /// Alertes pluie activées.
    @Published private(set) var rainAlertsEnabled: Bool
    /// Seuil d'alerte pluie (%) ; réglable dans le menu (40 / 55 / 70).
    @Published private(set) var rainThreshold: Int
    /// Préavis avant la pluie (minutes) ; réglable dans le menu (30 / 60 / 120).
    @Published private(set) var rainLeadMinutes: Int
    /// Résumé « prochaine pluie » par lieu (listes et écran météo).
    @Published private(set) var rainByLocation: [UUID: NextRain] = [:]
    /// Synchronisation iCloud des villes.
    @Published private(set) var cloudSyncEnabled: Bool
    @Published private(set) var offlineIDs: Set<UUID> = []
    @Published private(set) var cloudStatus = "État iCloud non vérifié"
    @Published private(set) var notificationStatus = "Non vérifié"
    @Published private(set) var pendingAlerts: [UNNotificationRequest] = []
    @Published var alertPreferences = AlertPreferences()
    @Published private(set) var alertProfiles: [AlertProfile] = []
    @Published private(set) var activeAlertProfileID: UUID?
    @Published private(set) var canUndoRemoval = false
    private var removedLocations: [Location] = []
    private var removedSelection: UUID?
    private let snapshotStore = WeatherSnapshotStore()
    private var alertTask: Task<Void, Never>?
    private var refreshingAll = false

    private let service: WeatherService
    private let locationProvider = CurrentLocationProvider()
    private let rainNotifier = RainNotifier()
    private var cloudObserver: NSObjectProtocol?
    private var clockTimer: Timer?
    private var lastFetch: [UUID: Date] = [:]

    private static let storageKey = "MeteoHeure.locations.v1"
    /// Suite du App Group partagé avec le widget (même valeur que dans SharedGroup).
    static let sharedGroupSuite = "group.com.example.meteoheure"
    private static let formatKey = "MeteoHeure.hour12"
    private static let unitKey = "MeteoHeure.unitFahrenheit"
    private static let selectedKey = "MeteoHeure.selectedID"
    private static let rainAlertsKey = "MeteoHeure.rainAlerts"
    private static let rainThresholdKey = "MeteoHeure.rainThreshold"
    private static let rainLeadKey = "MeteoHeure.rainLeadMinutes"
    private static let cloudSyncKey = "MeteoHeure.cloudSync"
    private static let icloudStoreKey = "MeteoHeure.icloud.locations"

    // MARK: Init

    init(service: WeatherService = WeatherService()) {
        self.service = service
        let defaults = UserDefaults.standard
        // Maquette : 12 h actif, degrés Celsius, alertes pluie et sync actives.
        self.hour12 = defaults.object(forKey: Self.formatKey) as? Bool ?? true
        self.unitFahrenheit = defaults.object(forKey: Self.unitKey) as? Bool ?? false // °C
        self.rainAlertsEnabled = defaults.object(forKey: Self.rainAlertsKey) as? Bool ?? true
        self.rainThreshold = defaults.object(forKey: Self.rainThresholdKey) as? Int ?? 55
        self.rainLeadMinutes = defaults.object(forKey: Self.rainLeadKey) as? Int ?? 60
        self.cloudSyncEnabled = defaults.object(forKey: Self.cloudSyncKey) as? Bool ?? true
        if let raw = defaults.string(forKey: Self.selectedKey) { self.selectedID = UUID(uuidString: raw) }
        loadLocations()
        if defaults.data(forKey: Self.storageKey) == nil {
            locations = Location.defaults   // premier lancement
            persist()
        }
        if let startup = defaults.string(forKey: "Orbisol.startupCity"),
           let id = UUID(uuidString: startup), locations.contains(where: { $0.id == id }) { selectedID = id }
        if selectedID == nil { selectedID = locations.first?.id }
        if let data = defaults.data(forKey: "Orbisol.alertPreferences"),
           let preferences = try? JSONDecoder().decode(AlertPreferences.self, from: data) {
            alertPreferences = preferences
        }
        if let value = defaults.string(forKey: "Orbisol.alertProfiles") {
            alertProfiles = (try? JSONDecoder().decode([AlertProfile].self, from: Data(value.utf8))) ?? []
        }
        activeAlertProfileID = defaults.string(forKey: "Orbisol.activeAlertProfile").flatMap(UUID.init(uuidString:))
        for location in locations {
            if let snapshot = snapshotStore.load(location.id) {
                weatherByLocation[location.id] = snapshot.weather
                lastFetch[location.id] = snapshot.fetchedAt
                rainByLocation[location.id] = rainHint(for: location)
            }
        }
        syncWidgetList() // liste à jour dans le widget (même au premier lancement)
        // Partage le format horaire avec le widget (défaut : réglage de l'app).
        if UserDefaults(suiteName: Self.sharedGroupSuite)?.object(forKey: Self.formatKey) == nil {
            UserDefaults(suiteName: Self.sharedGroupSuite)?.set(hour12, forKey: Self.formatKey)
        }

        // Écoute des changements iCloud (modifiés sur un autre appareil).
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.applyCloudChanges() }
        }

        startClock()
        // Un réveil iOS en arrière-plan passe par refreshBackgroundWeather().
        // L'actualisation complète est lancée par handleScenePhase(.active).
    }

    deinit {
        if let cloudObserver {
            NotificationCenter.default.removeObserver(cloudObserver)
        }
    }

    // MARK: - Cycle de vie (pause / reprise)

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            startClock()
            refreshCloudStatus()
            Task { await refreshNotificationStatus() }
            // Une donnée plus vieille que 5 min force un rafraîchissement.
            if locations.contains(where: { lastFetch[$0.id] == nil || Date().timeIntervalSince(lastFetch[$0.id]!) > 5 * 60 }) {
                Task { await refreshAllWeather() }
            }
        case .background, .inactive:
            stopClock()   // on n'update pas l'heure en arrière-plan
        @unknown default:
            break
        }
    }

    // MARK: - Horloge

    private func startClock() {
        guard clockTimer == nil else { return }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
    }

    private func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
    }

    // MARK: - Météo

    /// Récupère la météo d'un lieu précis.
    /// La fraîcheur du cache (10 min) évite de marteler l'API à chaque
    /// apparition de vue ; `force: true` outre-passe le cache.
    func refreshWeather(for location: Location, force: Bool = false) async {
        guard !loadingIDs.contains(location.id) else { return }
        if !force,
           let last = lastFetch[location.id],
           Date().timeIntervalSince(last) < 10 * 60 {
            return
        }
        loadingIDs.insert(location.id)
        defer { loadingIDs.remove(location.id) }

        async let air = try? service.fetchAirQuality(latitude: location.latitude, longitude: location.longitude)
        do {
            let weatherResult = try await service.fetchWeather(for: location)
            guard locations.contains(where: { $0.id == location.id }) else { return }
            weatherByLocation[location.id] = weatherResult
            lastFetch[location.id] = Date()
            offlineIDs.remove(location.id)
            rainByLocation[location.id] = rainHint(for: location)
            do {
                try snapshotStore.save(WeatherSnapshot(locationID: location.id, fetchedAt: lastFetch[location.id]!, weather: weatherResult))
            } catch {
                errorMessage = "La météo est chargée, mais sa sauvegarde hors connexion a échoué."
            }
            shareWeatherSnapshots()
        } catch {
            offlineIDs.insert(location.id)
            if weatherByLocation[location.id] == nil {
                errorMessage = "Impossible de charger la météo pour \(location.name)."
            }
        }
        let result = await air
        if locations.contains(where: { $0.id == location.id }) {
            airQualityByLocation[location.id] = result
            if result != nil { airFetchedAt[location.id] = Date() }
        }
        if !refreshingAll { rescheduleRainAlerts() }
    }

    /// Rafraîchit toutes les villes en parallèle (TaskGroup).
    func refreshAllWeather() async {
        guard !refreshingAll else { return }
        refreshingAll = true
        let targets = locations
        await withTaskGroup(of: Void.self) { group in
            for location in targets {
                group.addTask { await self.refreshWeather(for: location, force: true) }
            }
        }
        refreshingAll = false
        rescheduleRainAlerts()
    }

    /// iOS choisit la date effective du réveil. On borne le travail pour
    /// pouvoir rendre la main rapidement au système.
    func refreshBackgroundWeather() async {
        let ordered = locations.filter { $0.id == selectedID } +
            locations.filter { $0.favorite == true && $0.id != selectedID } +
            locations.filter { $0.id != selectedID && $0.favorite != true }
        for location in ordered.prefix(4) {
            if Task.isCancelled { break }
            await refreshWeather(for: location, force: true)
        }
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Préférences & sélection

    var selectedLocation: Location? {
        locations.first { $0.id == selectedID } ?? locations.first
    }

    func select(_ id: UUID?) {
        let changed = selectedID != id
        selectedID = id
        UserDefaults.standard.set(id?.uuidString, forKey: Self.selectedKey)
        guard changed else { return }
        // La ville sélectionnée est aussi partagée avec le widget
        // (marqueur principal) : rechargement immédiat du widget.
        UserDefaults(suiteName: Self.sharedGroupSuite)?.set(id?.uuidString, forKey: Self.selectedKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "DayNightWidget")
    }

    func setHour12(_ value: Bool) {
        hour12 = value
        UserDefaults.standard.set(value, forKey: Self.formatKey)
        // Le widget affiche l'heure dans le même format (12 h / 24 h).
        UserDefaults(suiteName: Self.sharedGroupSuite)?.set(value, forKey: Self.formatKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "DayNightWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "OrbisolWeather")
    }

    func setUnitFahrenheit(_ value: Bool) {
        unitFahrenheit = value
        UserDefaults.standard.set(value, forKey: Self.unitKey)
        shareWeatherSnapshots()
        // Re-rendu immédiat des températures (les vues lisent unitFahrenheit).
        objectWillChange.send()
    }

    /// Unité effective : réglage propre au lieu si défini, sinon global.
    func unitIsFahrenheit(for location: Location?) -> Bool {
        location?.usesFahrenheit(appDefault: unitFahrenheit) ?? unitFahrenheit
    }

    /// Force l'unité d'un lieu précis (nil = suivre le réglage global).
    func setUnitFor(_ location: Location, fahrenheit: Bool?) {
        guard let index = locations.firstIndex(where: { $0.id == location.id }) else { return }
        var updated = location
        updated.prefersFahrenheit = fahrenheit
        locations[index] = updated
        persist()
    }

    /// Affiche une température selon l'unité choisie (« 21° »).
    func tempText(_ celsius: Double, for location: Location? = nil) -> String {
        let fahrenheit = unitIsFahrenheit(for: location)
        let value = fahrenheit ? celsius * 9 / 5 + 32 : celsius
        return "\(Int(value.rounded()))°"
    }

    /// Affiche le vent (« 14 km/h » ou « 9 mph »).
    func windText(kmPerHour: Double, for location: Location? = nil) -> String {
        let fahrenheit = unitIsFahrenheit(for: location)
        let value = fahrenheit ? kmPerHour / 1.609344 : kmPerHour
        let unit = fahrenheit ? "mph" : "km/h"
        return "\(Int(value.rounded())) \(unit)"
    }

    // MARK: - Ma position

    /// Détecte la position de l'utilisateur et l'ajoute comme ville suivie.
    func addCurrentLocation() async {
        do {
            let coordinate = try await locationProvider.request()
            let place = try await service.reverseGeocode(latitude: coordinate.latitude,
                                                         longitude: coordinate.longitude)
            let city = Location(name: place.name,
                                region: place.region,
                                country: place.country,
                                latitude: coordinate.latitude,
                                longitude: coordinate.longitude,
                                timeZoneIdentifier: place.timeZoneIdentifier)
            // Déjà suivi ? On le sélectionne simplement.
            if let existing = locations.first(where: {
                abs($0.latitude - city.latitude) < 0.05 && abs($0.longitude - city.longitude) < 0.05
            }) {
                select(existing.id)
                return
            }
            locations.append(city)
            persist()
            select(city.id)
            await refreshWeather(for: city, force: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Alertes pluie

    func setRainAlerts(_ enabled: Bool) {
        if enabled {
            Task {
                let granted = await rainNotifier.requestAuthorization()
                if granted {
                    rainAlertsEnabled = true
                    UserDefaults.standard.set(true, forKey: Self.rainAlertsKey)
                    rescheduleRainAlerts()
                } else {
                    errorMessage = "Notifications refusées. Activez-les dans Réglages > Notifications."
                }
            }
        } else {
            rainAlertsEnabled = false
            UserDefaults.standard.set(false, forKey: Self.rainAlertsKey)
            rescheduleRainAlerts()
        }
    }

    /// Change le seuil d'alerte et reprogramme les notifications.
    func setRainThreshold(_ value: Int) {
        guard [40, 55, 70].contains(value) else { return }
        rainThreshold = value
        UserDefaults.standard.set(value, forKey: Self.rainThresholdKey)
        rescheduleRainAlerts()
    }

    /// Change le préavis et reprogramme les notifications.
    func setRainLeadMinutes(_ value: Int) {
        guard [30, 60, 120].contains(value) else { return }
        rainLeadMinutes = value
        UserDefaults.standard.set(value, forKey: Self.rainLeadKey)
        rescheduleRainAlerts()
    }

    private func rescheduleRainAlerts() {
        alertTask?.cancel()
        alertTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            let fresh = weatherByLocation.filter { Date().timeIntervalSince(lastFetch[$0.key] ?? .distantPast) < 3600 }
            let freshAir = airQualityByLocation.filter { Date().timeIntervalSince(airFetchedAt[$0.key] ?? .distantPast) < 3600 }
            await rainNotifier.schedule(cities: locations, weatherBy: fresh,
                                        airBy: freshAir,
                                        threshold: rainThreshold, leadMinutes: rainLeadMinutes,
                                        rainEnabled: rainAlertsEnabled, preferences: alertPreferences)
            await refreshNotificationStatus()
        }
    }

    func saveAlertPreferences() {
        if let data = try? JSONEncoder().encode(alertPreferences) {
            UserDefaults.standard.set(data, forKey: "Orbisol.alertPreferences")
        }
        if let id = activeAlertProfileID,
           alertProfiles.first(where: { $0.id == id })?.preferences != alertPreferences {
            activeAlertProfileID = nil
            UserDefaults.standard.removeObject(forKey: "Orbisol.activeAlertProfile")
        }
        rescheduleRainAlerts()
    }

    func saveCurrentAlertProfile(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 60, alertProfiles.count < 20 else { return }
        let profile = AlertProfile(name: name, preferences: alertPreferences, rainEnabled: rainAlertsEnabled,
                                   rainThreshold: rainThreshold, rainLeadMinutes: rainLeadMinutes)
        alertProfiles.append(profile)
        persistAlertProfiles()
        activeAlertProfileID = profile.id
        UserDefaults.standard.set(profile.id.uuidString, forKey: "Orbisol.activeAlertProfile")
    }

    func activateAlertProfile(_ id: UUID) {
        guard let profile = alertProfiles.first(where: { $0.id == id }) else { return }
        alertPreferences = profile.preferences
        if let data = try? JSONEncoder().encode(alertPreferences) { UserDefaults.standard.set(data, forKey: "Orbisol.alertPreferences") }
        setRainThreshold(profile.rainThreshold)
        setRainLeadMinutes(profile.rainLeadMinutes)
        setRainAlerts(profile.rainEnabled)
        activeAlertProfileID = id
        UserDefaults.standard.set(id.uuidString, forKey: "Orbisol.activeAlertProfile")
        rescheduleRainAlerts()
    }

    func deleteAlertProfiles(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            if alertProfiles[index].id == activeAlertProfileID { activeAlertProfileID = nil }
            alertProfiles.remove(at: index)
        }
        persistAlertProfiles()
    }

    private func persistAlertProfiles() {
        if let data = try? JSONEncoder().encode(alertProfiles), let value = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(value, forKey: "Orbisol.alertProfiles")
        }
    }

    func reloadAlertProfiles() {
        let raw = UserDefaults.standard.string(forKey: "Orbisol.alertProfiles") ?? "[]"
        alertProfiles = (try? JSONDecoder().decode([AlertProfile].self, from: Data(raw.utf8))) ?? []
        if !alertProfiles.contains(where: { $0.id == activeAlertProfileID }) { activeAlertProfileID = nil }
    }

    func authorizeNotifications() async {
        _ = await rainNotifier.requestAuthorization()
        rescheduleRainAlerts()
        await refreshNotificationStatus()
    }

    func scheduleOffsetReminder(city: Location, meeting: Date, delta: Int) async -> Bool {
        let scheduled = await rainNotifier.scheduleOffsetReminder(city: city, meeting: meeting, delta: delta)
        await refreshNotificationStatus()
        return scheduled
    }

    func refreshNotificationStatus() async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized: notificationStatus = "Autorisées"
        case .provisional, .ephemeral: notificationStatus = "Autorisées discrètement"
        case .denied: notificationStatus = "Refusées dans les réglages iOS"
        default: notificationStatus = "Autorisation à demander"
        }
        let requests = await center.pendingNotificationRequests()
        let owned = requests.filter {
            $0.identifier.hasPrefix("orbisol-alert-") || $0.identifier.hasPrefix("orbisol-env-") ||
                $0.identifier.hasPrefix("orbisol-dst-") || $0.identifier.hasPrefix("rain-")
        }
        pendingAlerts = owned.sorted(by: { first, second in
            let firstDate = first.plannedDate ?? Date.distantFuture
            let secondDate = second.plannedDate ?? Date.distantFuture
            return firstDate < secondDate
        })
    }

    /// Résumé « pluie » de la ville, affiché dans les réglages
    /// (ex. « 11 am · 55 % », format horaire suivant le réglage 12/24 h).
    func nextRainText(for location: Location) -> String? {
        guard case .soon(let probability, let hour) = nextRain(for: location) else { return nil }
        var display = hour
        let suffix = hour12 ? (hour < 12 ? "am" : "pm") : ""
        if hour12 {
            display = hour % 12 == 0 ? 12 : hour % 12
        }
        let label = hour12 ? "\(display) \(suffix)" : "\(display) h"
        return "\(label) · \(probability) %"
    }

    /// Résumé « prochaine pluie » pré-calculé (24 h, seuil d'affichage 30 %).
    func nextRain(for location: Location) -> NextRain {
        rainByLocation[location.id] ?? .unknown
    }

    /// Recalcule le résumé pluie d'un lieu depuis ses données horaires.
    private func rainHint(for location: Location) -> NextRain {
        guard let hourly = weatherByLocation[location.id]?.hourly else { return .unknown }
        let probabilities = hourly.precipitationProbability ?? []
        let timeZone = location.timeZone ?? .current
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = timeZone
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var hasProbability = false
        for index in hourly.time.indices {
            guard let date = parser.date(from: hourly.time[index]) else { continue }
            let interval = date.timeIntervalSince(now)
            guard interval > -900, interval < 24 * 3600 else { continue }
            guard probabilities.indices.contains(index), let probability = probabilities[index] else { continue }
            hasProbability = true
            if probability >= Self.rainHintThreshold {
                return .soon(probability: probability, hour: calendar.component(.hour, from: date))
            }
        }
        return hasProbability ? .none : .unknown
    }

    private static let rainHintThreshold = 30

    // MARK: - Fraîcheur des données

    /// Horodatage du dernier chargement météo réussi pour un lieu (lecture seule).
    func lastFetchDate(for location: Location) -> Date? {
        lastFetch[location.id]
    }

    /// « mis à jour il y a X min » (nil si jamais chargé).
    func freshnessText(for location: Location) -> String? {
        guard let date = lastFetch[location.id] else { return nil }
        let minutes = Int(max(0, Date().timeIntervalSince(date)) / 60)
        if minutes < 1 { return "mis à jour à l'instant" }
        if minutes < 60 { return "mis à jour il y a \(minutes) min" }
        return "mis à jour il y a \(minutes / 60) h"
    }

    func dataStatus(for location: Location, at date: Date = Date()) -> WeatherDataStatus {
        guard let fetched = lastFetch[location.id] else {
            return loadingIDs.contains(location.id) ? .loading : .unavailable
        }
        if offlineIDs.contains(location.id) { return .offline(fetched) }
        return date.timeIntervalSince(fetched) > 30 * 60 ? .old(fetched) : .current(fetched)
    }

    // MARK: - Synchronisation iCloud

    func setCloudSync(_ enabled: Bool) {
        cloudSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.cloudSyncKey)
        if enabled {
            applyCloudChanges()
            pushToCloud()
        }
        refreshCloudStatus()
    }

    func refreshCloudStatus() {
        guard cloudSyncEnabled else { cloudStatus = "Désactivée"; return }
        guard FileManager.default.ubiquityIdentityToken != nil else {
            cloudStatus = "iCloud indisponible : compte ou capacité à vérifier"
            return
        }
        if let date = UserDefaults.standard.object(forKey: "Orbisol.lastCloudReceipt") as? Date {
            cloudStatus = "Dernière réception : " + date.formatted(date: .abbreviated, time: .shortened)
        } else { cloudStatus = "En attente d’un échange iCloud" }
    }

    private func pushToCloud() {
        guard cloudSyncEnabled,
              let data = try? JSONEncoder().encode(locations) else { return }
        NSUbiquitousKeyValueStore.default.set(data, forKey: Self.icloudStoreKey)
    }

    /// Fusionne les villes reçues depuis iCloud (le nuage a priorité).
    private func applyCloudChanges() {
        guard cloudSyncEnabled,
              let data = NSUbiquitousKeyValueStore.default.data(forKey: Self.icloudStoreKey),
              let cloudLocations = try? JSONDecoder().decode([Location].self, from: data) else { return }
        UserDefaults.standard.set(Date(), forKey: "Orbisol.lastCloudReceipt")
        refreshCloudStatus()
        let localIDs = Set(locations.map(\.id))
        let cloudIDs = Set(cloudLocations.map(\.id))
        // On garde l'ordre du nuage, en conservant les lieux uniquement locaux.
        var merged = cloudLocations
        for location in locations where !cloudIDs.contains(location.id) {
            merged.append(location)
        }
        guard merged != locations || !localIDs.isSubset(of: cloudIDs) else { return }
        locations = merged
        persist()
        Task { await refreshAllWeather() }
    }

    // MARK: - Recherche

    /// Délègue la recherche au service de géocodage.
    func searchLocations(query: String) async throws -> [Location] {
        guard query.trimmingCharacters(in: .whitespaces).count >= 2 else { return [] }
        return try await service.searchLocations(query: query)
    }

    // MARK: - Gestion de la liste

    /// Une proximité de plusieurs kilomètres ne suffit pas : deux villages
    /// voisins doivent pouvoir être suivis séparément.
    func savedMatch(for location: Location) -> Location? {
        locations.first { $0.isSamePlace(as: location) }
    }

    /// Ajoute un lieu puis le sélectionne (après une recherche).
    func addAndSelect(_ location: Location) {
        if let existing = savedMatch(for: location) {
            select(existing.id)
            return
        }
        add(location)
        select(location.id)
    }

    /// Ajoute un lieu sans fusionner deux localités voisines.
    func add(_ location: Location) {
        guard savedMatch(for: location) == nil else { return }
        locations.append(location)
        persist()
        Task { await refreshWeather(for: location) }
    }

    /// Définit une ville comme principale : elle passe en tête de liste
    /// (le widget la met en avant) et devient la sélection courante.
    func makePrimary(_ location: Location) {
        guard let index = locations.firstIndex(where: { $0.id == location.id }) else { return }
        if index != 0 {
            var updated = locations
            updated.remove(at: index)
            updated.insert(location, at: 0)
            locations = updated
            persist()
        }
        select(location.id)
    }

    /// Vrai si le lieu est la ville principale (première de la liste).
    func isPrimary(_ location: Location) -> Bool {
        locations.first?.id == location.id
    }

    /// Suppression via « swipe to delete » (ForEach.onDelete).
    func remove(at offsets: IndexSet) {
        rememberRemoval()
        for index in offsets {
            let id = locations[index].id
            weatherByLocation.removeValue(forKey: id)
            rainByLocation.removeValue(forKey: id)
            lastFetch.removeValue(forKey: id)
        }
        locations.remove(atOffsets: offsets)
        if !locations.contains(where: { $0.id == selectedID }) { select(locations.first?.id) }
        persist()
        rescheduleRainAlerts()
    }

    /// Suppression par identifiant (ex. bouton dans le détail).
    func remove(_ location: Location) {
        rememberRemoval()
        locations.removeAll { $0.id == location.id }
        weatherByLocation.removeValue(forKey: location.id)
        rainByLocation.removeValue(forKey: location.id)
        lastFetch.removeValue(forKey: location.id)
        if selectedID == location.id { select(locations.first?.id) }
        persist()
        rescheduleRainAlerts()
    }

    /// Supprime toutes les villes.
    func removeAll() {
        rememberRemoval()
        locations = []
        weatherByLocation = [:]
        rainByLocation = [:]
        lastFetch = [:]
        select(nil)
        persist()
        rescheduleRainAlerts()
    }

    private func rememberRemoval() {
        removedLocations = locations
        removedSelection = selectedID
        canUndoRemoval = !locations.isEmpty
    }

    func undoRemoval() {
        guard canUndoRemoval else { return }
        let current = locations.filter { city in !removedLocations.contains(where: { $0.id == city.id }) }
        locations = removedLocations + current
        select(removedSelection)
        canUndoRemoval = false
        persist()
        Task { await refreshAllWeather() }
    }

    func setGroup(_ group: String?, for location: Location) {
        guard let index = locations.firstIndex(where: { $0.id == location.id }) else { return }
        locations[index].group = group?.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    func toggleFavorite(_ location: Location) {
        guard let index = locations.firstIndex(where: { $0.id == location.id }) else { return }
        locations[index].favorite = locations[index].favorite != true
        persist()
    }

    func importCities(_ incoming: [Location]) {
        for city in incoming where !locations.contains(where: { $0.id == city.id }) {
            locations.append(city)
        }
        persist()
        Task { await refreshAllWeather() }
    }

    private func shareWeatherSnapshots() {
        let values = locations.compactMap { location -> CityWeatherSnapshot? in
            guard let current = weatherByLocation[location.id]?.current, let fetched = lastFetch[location.id] else { return nil }
            let next = WeatherInsights.hours(weatherByLocation[location.id], zone: location.timeZone ?? .current)
                .first { $0.date > Date() && ($0.rain ?? 0) >= rainThreshold }
            return CityWeatherSnapshot(id: location.id.uuidString, temperature: tempText(current.temperature2m, for: location),
                condition: WeatherStyle.shortCondition(code: current.weatherCode), rain: nextRainText(for: location),
                fetchedAt: fetched, sunset: weatherByLocation[location.id]?.daily?.sunset?.first,
                nextRainAt: next?.date, rainProbability: next?.rain)
        }
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults(suiteName: Self.sharedGroupSuite)?.set(data, forKey: "Orbisol.widgetWeather")
            WidgetCenter.shared.reloadTimelines(ofKind: "OrbisolWeather")
            WidgetCenter.shared.reloadTimelines(ofKind: "OrbisolRain")
        }
    }

    /// Réordonnancement via EditButton (ForEach.onMove).
    func move(from source: IndexSet, to destination: Int) {
        locations.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    // MARK: - Persistance

    private func persist() {
        guard let data = try? JSONEncoder().encode(locations) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        pushToCloud()
        syncWidgetList()
        shareWeatherSnapshots()
    }

    /// Partage la liste des villes avec le widget (App Group) et demande son rafraîchissement.
    private func syncWidgetList() {
        guard let data = try? JSONEncoder().encode(locations) else { return }
        UserDefaults(suiteName: Self.sharedGroupSuite)?.set(data, forKey: Self.storageKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "DayNightWidget")
    }

    private func loadLocations() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([Location].self, from: data) else { return }
        locations = decoded
    }
}
