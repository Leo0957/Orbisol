import Foundation
import UserNotifications

// MARK: - Alertes pluie (notifications locales)
//
// Pour chaque ville, on cherche la première heure des 12 prochaines où la
// probabilité de précipitations dépasse le seuil, puis on programme une
// notification UNE HEURE AVANT. Aucune dépendance externe.

struct RainNotifier {

    private static let prefix = "rain-"

    /// Demande l'autorisation de notifier.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Supprime toutes les alertes pluie déjà programmées.
    func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let rainIDs = pending.map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: rainIDs)
    }

    /// (Re)programme une alerte par ville, au plus une par ville.
    /// - Parameters:
    ///   - threshold: probabilité minimale (%) pour déclencher l'alerte.
    ///   - leadMinutes: préavis (minutes) avant l'heure de pluie.
    func schedule(cities: [Location], weatherBy: [UUID: OpenMeteoResponse],
                  threshold: Int, leadMinutes: Int) async {
        await cancelAll()
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let hourParser = DateFormatter()
        hourParser.dateFormat = "yyyy-MM-dd'T'HH:mm"
        hourParser.locale = Locale(identifier: "en_US_POSIX")

        for city in cities {
            guard let data = weatherBy[city.id], let hourly = data.hourly else { continue }
            let timeZone = city.timeZone ?? .current
            let probabilities = hourly.precipitationProbability ?? []
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            formatter.timeZone = timeZone

            for index in hourly.time.indices {
                let probability = probabilities.indices.contains(index) ? probabilities[index] : 0
                guard probability >= threshold else { continue }

                hourParser.timeZone = timeZone
                guard let rainDate = hourParser.date(from: hourly.time[index]) else { continue }
                // On prévient `leadMinutes` avant la pluie.
                let fireDate = rainDate.addingTimeInterval(-Double(leadMinutes) * 60)
                let delay = fireDate.timeIntervalSinceNow
                guard delay > 60, delay < 12 * 3600 else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Pluie probable à \(city.name)"
                content.body = "\(probability)% de précipitations autour de \(formatter.string(from: rainDate)) (heure locale)."
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                let request = UNNotificationRequest(identifier: Self.prefix + city.id.uuidString,
                                                    content: content,
                                                    trigger: trigger)
                try? await center.add(request)
                break // une alerte par ville suffit
            }
        }
    }

    /// Prochaine pluie probable (pour l'affichage dans les réglages).
    func nextRain(in data: OpenMeteoResponse?, timeZone: TimeZone?, threshold: Int) -> String? {
        guard let hourly = data?.hourly else { return nil }
        let probabilities = hourly.precipitationProbability ?? []
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = timeZone ?? .current
        let clock = DateFormatter()
        clock.dateFormat = "HH:mm"
        clock.timeZone = timeZone ?? .current

        for index in hourly.time.indices {
            let probability = probabilities.indices.contains(index) ? probabilities[index] : 0
            guard probability >= threshold, let date = parser.date(from: hourly.time[index]),
                  date.timeIntervalSinceNow > 0 else { continue }
            return "\(probability)% à \(clock.string(from: date))"
        }
        return nil
    }
}
