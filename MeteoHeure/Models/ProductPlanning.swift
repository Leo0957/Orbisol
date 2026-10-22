import Foundation

enum MeetingText {
    static func describe(date: Date, cities: [Location]) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEEE d MMMM yyyy 'à' HH:mm zzz"
        return (["Rendez-vous · 1 heure"] + cities.map { city in
            formatter.timeZone = city.timeZone ?? .current
            return "\(city.name) : \(formatter.string(from: date))"
        }).joined(separator: "\n")
    }
}

struct TripPlan: Codable, Identifiable {
    var id = UUID()
    var group: String
    var start: Date
    var end: Date
    var stages: [TripStage]? = nil
    var checklist: [PackingItem]? = nil
}

struct TripStage: Codable, Identifiable {
    var id = UUID()
    var locationID: UUID
    var arrive: Date
    var depart: Date
}

struct PackingItem: Codable, Identifiable {
    var id = UUID()
    var name: String
    var checked = false
}

enum WeatherSection: String, CaseIterable, Identifiable {
    case summary, outing, rain, pollen, light
    var id: String { rawValue }
    var title: String {
        switch self {
        case .summary: return "Résumé et comparaison avec hier"
        case .outing: return "Créneau de sortie"
        case .rain: return "Précipitations"
        case .pollen: return "Pollens"
        case .light: return "Lumière du jour"
        }
    }
    static func ordered(_ raw: String) -> [WeatherSection] {
        let values = ((try? JSONDecoder().decode([String].self, from: Data(raw.utf8))) ?? []).compactMap(Self.init(rawValue:))
        var seen: Set<Self> = []
        return (values + allCases).filter { seen.insert($0).inserted }
    }
}

struct SettingsBackup: Codable {
    var version = 1
    var cities: [Location]
    var alerts: AlertPreferences
    var hour12: Bool
    var fahrenheit: Bool
    var rain: Bool
    var threshold: Int
    var lead: Int
    var strings: [String: String]
    var switches: [String: Bool]
    static let stringKeys = ["Orbisol.appearance", "Orbisol.clockTypeface", "Orbisol.startupCity", "Orbisol.weather.order", "Orbisol.weather.hidden", "Orbisol.trips", "Orbisol.workingHours", "Orbisol.homeFocus", "Orbisol.alertProfiles"]
    static let boolKeys = ["Orbisol.clock.seconds", "Orbisol.clock.date", "Orbisol.clock.weather", "Orbisol.clock.nightAuto", "Orbisol.highLegibility"]
    func validate() throws {
        guard version == 1, cities.count <= 500, Set(cities.map(\.id)).count == cities.count,
              cities.allSatisfy({ !$0.name.isEmpty && $0.name.count <= 200 && (-90...90).contains($0.latitude) && (-180...180).contains($0.longitude) && TimeZone(identifier: $0.timeZoneIdentifier) != nil }),
              [40, 55, 70].contains(threshold), [30, 60, 120].contains(lead),
              (0...23).contains(alerts.quietStart), (0...23).contains(alerts.quietEnd),
              (20...120).contains(alerts.windThreshold), (15...45).contains(alerts.temperatureThreshold),
              (-30...15).contains(alerts.coldThreshold ?? 0),
              (40...150).contains(alerts.airThreshold ?? 80), (10...200).contains(alerts.pollenThreshold ?? 50),
              strings.keys.allSatisfy(Self.stringKeys.contains), switches.keys.allSatisfy(Self.boolKeys.contains) else { throw CocoaError(.fileReadCorruptFile) }
        if let text = strings["Orbisol.trips"] {
            let trips = try JSONDecoder().decode([TripPlan].self, from: Data(text.utf8))
            guard trips.count <= 500, Set(trips.map(\.id)).count == trips.count,
                  trips.allSatisfy({ trip in
                      trip.start <= trip.end && !trip.group.isEmpty
                      && (trip.stages ?? []).count <= 100
                      && (trip.stages ?? []).allSatisfy { $0.arrive <= $0.depart && $0.arrive >= trip.start && $0.depart <= trip.end }
                      && (trip.checklist ?? []).count <= 100
                      && (trip.checklist ?? []).allSatisfy { !$0.name.isEmpty && $0.name.count <= 100 }
                  }) else { throw CocoaError(.fileReadCorruptFile) }
        }
        if let value = strings["Orbisol.appearance"], !["system", "light", "dark"].contains(value) { throw CocoaError(.fileReadCorruptFile) }
        for key in ["Orbisol.weather.order", "Orbisol.weather.hidden"] {
            if let text = strings[key] {
                let ids = try JSONDecoder().decode([String].self, from: Data(text.utf8))
                guard ids.allSatisfy({ WeatherSection(rawValue: $0) != nil }) else { throw CocoaError(.fileReadCorruptFile) }
            }
        }
        if let value = strings["Orbisol.startupCity"], !value.isEmpty, UUID(uuidString: value) == nil { throw CocoaError(.fileReadCorruptFile) }
        if let value = strings["Orbisol.homeFocus"], !["clocks", "rain", "air", "outing"].contains(value) { throw CocoaError(.fileReadCorruptFile) }
        if let value = strings["Orbisol.workingHours"] {
            let hours = try JSONDecoder().decode([String: WorkingHours].self, from: Data(value.utf8))
            guard hours.count <= 500, hours.allSatisfy({ UUID(uuidString: $0.key) != nil && (0..<24).contains($0.value.start) && (1...24).contains($0.value.end) && $0.value.start < $0.value.end && $0.value.weekdays.isSubset(of: Set(1...7)) }) else { throw CocoaError(.fileReadCorruptFile) }
        }
        if let value = strings["Orbisol.alertProfiles"] {
            let profiles = try JSONDecoder().decode([AlertProfile].self, from: Data(value.utf8))
            guard profiles.count <= 20, Set(profiles.map(\.id)).count == profiles.count,
                  profiles.allSatisfy({ !$0.name.isEmpty && $0.name.count <= 60 && [40, 55, 70].contains($0.rainThreshold) && [30, 60, 120].contains($0.rainLeadMinutes) }) else { throw CocoaError(.fileReadCorruptFile) }
        }
    }
}
