import WidgetKit

/// Une « image » du widget : l'instant affiché + les villes marquées.
struct DayNightEntry: TimelineEntry {
    let date: Date
    let cities: [WidgetCity]
}

/// Fournit les instants : la carte jour/nuit évolue lentement, une
/// actualisation toutes les ~15 minutes suffit — iOS décide ensuite
/// de la fréquence réelle (budget WidgetKit).
struct DayNightProvider: TimelineProvider {

    func placeholder(in context: Context) -> DayNightEntry {
        DayNightEntry(date: Date(), cities: SharedGroup.savedCities())
    }

    func getSnapshot(in context: Context, completion: @escaping (DayNightEntry) -> Void) {
        completion(DayNightEntry(date: Date(), cities: SharedGroup.savedCities()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayNightEntry>) -> Void) {
        let cities = SharedGroup.savedCities()
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)

        // Instants tous les quarts d'heure sur les prochaines heures :
        // le terminateur bouge ainsi progressivement, sans nécessiter
        // de réveils fréquents.
        var entries: [DayNightEntry] = []
        let startMinutes = calendar.component(.minute, from: now)
        let nextQuarter = 15 - (startMinutes % 15)
        if let first = calendar.date(byAdding: .minute, value: nextQuarter, to: now) {
            var cursor = first
            for _ in 0..<10 {
                entries.append(DayNightEntry(date: cursor, cities: cities))
                guard let next = calendar.date(byAdding: .minute, value: 15, to: cursor) else { break }
                cursor = next
            }
        }
        if entries.isEmpty {
            entries = [DayNightEntry(date: now, cities: cities)]
        }

        // Prochaine demande : un quart d'heure après la dernière entrée.
        let refresh = calendar.date(byAdding: .minute, value: 15, to: entries.last?.date ?? now)
            ?? now.addingTimeInterval(15 * 60)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}
