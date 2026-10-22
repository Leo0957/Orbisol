import Foundation
import UserNotifications

extension UNNotificationRequest {
    var plannedDate: Date? {
        if let trigger = trigger as? UNCalendarNotificationTrigger { return trigger.nextTriggerDate() }
        if let trigger = trigger as? UNTimeIntervalNotificationTrigger { return trigger.nextTriggerDate() }
        return nil
    }
}

actor RainNotifier {
    private var generation = 0
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func cancelAll() async {
        generation += 1
        let token = generation
        let pending = await center.pendingNotificationRequests()
        guard generation == token else { return }
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter {
            $0.hasPrefix("rain-") || $0.hasPrefix("orbisol-alert-") || $0.hasPrefix("orbisol-env-") || $0.hasPrefix("orbisol-dst-")
        })
    }

    func scheduleOffsetReminder(city: Location, meeting: Date, delta: Int) async -> Bool {
        let fire = meeting.addingTimeInterval(-24 * 3600)
        guard fire.timeIntervalSinceNow > 60, await requestAuthorization() else { return false }
        let content = UNMutableNotificationContent()
        content.title = "Décalage horaire modifié avec \(city.name)"
        content.body = "Votre rendez-vous hebdomadaire est demain. Vérifiez son heure locale : le décalage change de \(delta >= 0 ? "+" : "−")\(abs(delta) / 3600) h."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "orbisol-dst-\(city.id)-\(Int(meeting.timeIntervalSince1970))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: fire.timeIntervalSinceNow, repeats: false)
        )
        do { try await center.add(request); return true }
        catch { return false }
    }

    func schedule(cities: [Location], weatherBy: [UUID: OpenMeteoResponse],
                  airBy: [UUID: AirQualityResponse] = [:],
                  threshold: Int, leadMinutes: Int, rainEnabled: Bool = true,
                  preferences: AlertPreferences = AlertPreferences()) async {
        generation += 1
        let token = generation
        let pending = await center.pendingNotificationRequests()
        guard generation == token, !Task.isCancelled else { return }
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter {
            $0.hasPrefix("rain-") || $0.hasPrefix("orbisol-alert-")
        })
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { id in
            id.hasPrefix("orbisol-env-") &&
                ((id.hasSuffix("-air") && preferences.airEnabled != true) ||
                 (id.hasSuffix("-pollen") && preferences.pollenEnabled != true) ||
                 preferences.excludedCities.contains { id.contains($0.uuidString) })
        })
        let settings = await center.notificationSettings()
        guard generation == token,
              settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let now = Date()
        var count = 0
        for city in cities where !preferences.excludedCities.contains(city.id) {
            let zone = city.timeZone ?? .current
            let hours = WeatherInsights.hours(weatherBy[city.id], zone: zone)
            let types = [("rain", rainEnabled), ("wind", preferences.windEnabled), ("temperature", preferences.temperatureEnabled), ("cold", preferences.coldEnabled == true)]
            for (kind, enabled) in types where enabled && count < 48 {
                for hour in hours {
                    let fire = hour.date.addingTimeInterval(-Double(leadMinutes) * 60)
                    guard fire.timeIntervalSince(now) > 60, fire.timeIntervalSince(now) < 12 * 3600,
                          !preferences.isQuiet(fire, zone: .current) else { continue }
                    let matches: Bool
                    let title: String
                    switch kind {
                    case "rain": matches = (hour.rain ?? -1) >= threshold; title = "Pluie probable"
                    case "wind": matches = (hour.wind ?? -1) >= preferences.windThreshold; title = "Vent soutenu"
                    case "cold": matches = hour.temperature <= (preferences.coldThreshold ?? 0); title = "Température basse"
                    default: matches = hour.temperature >= preferences.temperatureThreshold; title = "Température élevée"
                    }
                    guard matches, generation == token, !Task.isCancelled else { continue }
                    let content = UNMutableNotificationContent()
                    content.title = "\(title) à \(city.name)"
                    content.body = "Prévision vers \(WorldTime.time(hour.date, zone: zone)) (heure locale). Données actualisées dans Orbisol."
                    content.sound = .default
                    let request = UNNotificationRequest(identifier: "orbisol-alert-\(token)-\(city.id)-\(kind)", content: content,
                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: fire.timeIntervalSince(now), repeats: false))
                    try? await center.add(request)
                    guard generation == token, !Task.isCancelled else {
                        center.removePendingNotificationRequests(withIdentifiers: [request.identifier])
                        return
                    }
                    count += 1
                    break
                }
            }
            guard count < 48, !preferences.isQuiet(now, zone: .current),
                  let air = airBy[city.id] else { continue }
            let values: [(String, Bool, Double?, Double, String)] = [
                ("air", preferences.airEnabled == true, air.current?.europeanAqi.map(Double.init), Double(preferences.airThreshold ?? 80), "AQI européen"),
                ("pollen", preferences.pollenEnabled == true, pollenLevel(air.hourly, zone: zone, at: now), preferences.pollenThreshold ?? 50, "Pollens")
            ]
            for (kind, enabled, value, limit, label) in values where enabled && count < 48 {
                guard let value, value >= limit else { continue }
                let key = "Orbisol.lastEnvironmentAlert.\(city.id).\(kind)"
                if let last = UserDefaults.standard.object(forKey: key) as? Date,
                   now.timeIntervalSince(last) < 6 * 3600 { continue }
                let content = UNMutableNotificationContent()
                content.title = "\(label) élevés à \(city.name)"
                content.body = "\(label) : \(Int(value)) · seuil choisi : \(Int(limit)). Données Open-Meteo, pas une alerte officielle."
                content.sound = .default
                let identifier = "orbisol-env-\(city.id)-\(kind)"
                let request = UNNotificationRequest(identifier: identifier, content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 65, repeats: false))
                do {
                    try await center.add(request)
                    if generation == token, !Task.isCancelled {
                        UserDefaults.standard.set(now, forKey: key)
                        count += 1
                    } else {
                        center.removePendingNotificationRequests(withIdentifiers: [identifier])
                        return
                    }
                } catch { continue }
            }
        }
    }

    private func pollenLevel(_ pollen: AirQualityResponse.Pollen?, zone: TimeZone, at now: Date) -> Double? {
        guard let pollen,
              let index = pollen.time.firstIndex(where: { text in
                  guard let date = WorldTime.parse(text, zone: zone) else { return false }
                  return date >= now.addingTimeInterval(-1800)
              }) else { return nil }
        let values = [pollen.grassPollen, pollen.birchPollen, pollen.alderPollen].compactMap { series -> Double? in
            guard let series, series.indices.contains(index) else { return nil }
            return series[index]
        }
        return values.max()
    }
}
