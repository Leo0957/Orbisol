import Foundation

struct AlertPreferences: Codable, Equatable {
    var excludedCities: Set<UUID> = []
    var quietEnabled = true
    var quietStart = 22
    var quietEnd = 8
    var windEnabled = false
    var windThreshold = 50.0
    var temperatureEnabled = false
    var temperatureThreshold = 30.0
    var coldEnabled: Bool? = false
    var coldThreshold: Double? = 0
    var airEnabled: Bool? = false
    var airThreshold: Int? = 80
    var pollenEnabled: Bool? = false
    var pollenThreshold: Double? = 50
    func isQuiet(_ date: Date, zone: TimeZone) -> Bool {
        guard quietEnabled else { return false }
        let hour = WorldTime.calendar(zone).component(.hour, from: date)
        if quietStart == quietEnd { return true }
        return quietStart < quietEnd ? hour >= quietStart && hour < quietEnd : hour >= quietStart || hour < quietEnd
    }
}

struct AlertProfile: Codable, Identifiable {
    var id = UUID()
    var name: String
    var preferences: AlertPreferences
    var rainEnabled: Bool
    var rainThreshold: Int
    var rainLeadMinutes: Int
}

struct WorkingHours: Codable, Equatable {
    var start = 9
    var end = 19
    /// Calendrier grégorien : dimanche = 1, lundi = 2.
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]

    func contains(_ date: Date, duration: TimeInterval, zone: TimeZone) -> Bool {
        guard (0..<24).contains(start), (1...24).contains(end), start < end else { return false }
        let calendar = WorldTime.calendar(zone)
        let finish = date.addingTimeInterval(duration - 1)
        return calendar.isDate(date, inSameDayAs: finish)
            && weekdays.contains(calendar.component(.weekday, from: date))
            && calendar.component(.hour, from: date) >= start
            && calendar.component(.hour, from: finish) < end
    }
}

enum WorldTime {
    static func calendar(_ zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar
    }

    static func offset(from: TimeZone, to: TimeZone, at date: Date) -> String {
        let minutes = (to.secondsFromGMT(for: date) - from.secondsFromGMT(for: date)) / 60
        let suffix = abs(minutes) % 60 == 0 ? "" : String(format: " %02d", abs(minutes) % 60)
        return "\(minutes >= 0 ? "+" : "−")\(abs(minutes) / 60) h\(suffix)"
    }

    static func dayDifference(from: TimeZone, to: TimeZone, at date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = from
        let home = formatter.string(from: date)
        formatter.timeZone = to
        let away = formatter.string(from: date)
        return away == home ? "Aujourd’hui" : (away > home ? "Demain" : "Hier")
    }

    static func commonSlots(zones: [TimeZone], after date: Date, startHour: Int = 9, endHour: Int = 19) -> [Date] {
        guard !zones.isEmpty else { return [] }
        let start = Date(timeIntervalSince1970: ceil(date.timeIntervalSince1970 / 1800) * 1800)
        return (0..<48).compactMap { step in
            let candidate = start.addingTimeInterval(Double(step) * 1800)
            let end = candidate.addingTimeInterval(3599)
            return zones.allSatisfy { zone in
                let calendar = calendar(zone)
                return calendar.component(.hour, from: candidate) >= startHour &&
                    calendar.component(.hour, from: end) < endHour && calendar.isDate(candidate, inSameDayAs: end)
            } ? candidate : nil
        }
    }

    static func commonSlots(availability: [(TimeZone, WorkingHours)], after date: Date) -> [Date] {
        guard !availability.isEmpty else { return [] }
        let start = Date(timeIntervalSince1970: ceil(date.timeIntervalSince1970 / 1800) * 1800)
        return (0..<48).compactMap { step in
            let candidate = start.addingTimeInterval(Double(step) * 1800)
            return availability.allSatisfy { $0.1.contains(candidate, duration: 3600, zone: $0.0) } ? candidate : nil
        }
    }

    static func weeklyOccurrences(from date: Date, count: Int) -> [Date] {
        guard count > 0 else { return [] }
        return (0..<min(count, 52)).compactMap { Calendar.current.date(byAdding: .weekOfYear, value: $0, to: date) }
    }

    static func offsetChanges(for cities: [Location], weeklyFrom date: Date, count: Int = 12) -> [(Location, Date, Int)] {
        let dates = weeklyOccurrences(from: date, count: count)
        guard let first = dates.first else { return [] }
        return cities.flatMap { city -> [(Location, Date, Int)] in
            guard let zone = city.timeZone else { return [] }
            let initial = zone.secondsFromGMT(for: first) - TimeZone.current.secondsFromGMT(for: first)
            return dates.dropFirst().compactMap { next in
                let delta = zone.secondsFromGMT(for: next) - TimeZone.current.secondsFromGMT(for: next)
                return delta != initial ? (city, next, delta - initial) : nil
            }.prefix(1).map { $0 }
        }
    }

    static func parse(_ value: String, zone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = value.count == 10 ? "yyyy-MM-dd" : "yyyy-MM-dd'T'HH:mm"
        formatter.isLenient = false
        return formatter.date(from: value)
    }

    static func time(_ date: Date, zone: TimeZone, hour12: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = zone
        formatter.dateFormat = hour12 ? "h:mm a" : "HH:mm"
        return formatter.string(from: date)
    }
}

struct ForecastHour: Identifiable {
    var id: Date { date }
    let date: Date
    let temperature: Double
    let code: Int
    let rain: Int?
    let wind: Double?
    let precipitation: Double?
}

enum WeatherInsights {
    enum Activity: String, CaseIterable, Identifiable {
        case walking, cycling, photography
        var id: String { rawValue }
        var title: String {
            switch self {
            case .walking: return "Marche"
            case .cycling: return "Vélo"
            case .photography: return "Photo"
            }
        }
    }
    static func hours(_ weather: OpenMeteoResponse?, zone: TimeZone) -> [ForecastHour] {
        guard let hourly = weather?.hourly else { return [] }
        var result: [ForecastHour] = []
        for index in hourly.time.indices {
            guard hourly.temperature2m.indices.contains(index), hourly.weatherCode.indices.contains(index),
                  let temperature = hourly.temperature2m[index], let code = hourly.weatherCode[index],
                  var date = WorldTime.parse(hourly.time[index], zone: zone) else { continue }
            // Local timestamps can repeat when clocks go back. Preserve chronological order.
            if let previous = result.last?.date, date <= previous {
                date = date.addingTimeInterval(3600)
                guard date > previous else { continue }
            }
            result.append(ForecastHour(date: date, temperature: temperature, code: code,
                rain: hourly.precipitationProbability.flatMap { $0.indices.contains(index) ? $0[index] : nil },
                wind: hourly.windSpeed10m.flatMap { $0.indices.contains(index) ? $0[index] : nil },
                precipitation: hourly.precipitation.flatMap { $0.indices.contains(index) ? $0[index] : nil }))
        }
        return result
    }

    static func bestWindow(_ hours: [ForecastHour], after now: Date, zone: TimeZone,
                           activity: Activity = .walking, latitude: Double = 0, longitude: Double = 0) -> [ForecastHour] {
        let calendar = WorldTime.calendar(zone)
        let upcoming = hours.filter { $0.date >= now && $0.date < now.addingTimeInterval(86400) }
        var best: [ForecastHour] = []
        var bestScore = Double.infinity
        for (index, first) in upcoming.enumerated() where index + 1 < upcoming.count {
            let second = upcoming[index + 1]
            let pair = [first, second]
            guard abs(second.date.timeIntervalSince(first.date) - 3600) < 1,
                  pair.allSatisfy({ calendar.component(.hour, from: $0.date) >= 8 && calendar.component(.hour, from: $0.date) < 20 && $0.rain != nil && $0.wind != nil }) else { continue }
            let score = pair.reduce(0.0) { partial, hour in
                let wet = Double(hour.rain!)
                let wind = hour.wind!
                switch activity {
                case .walking: return partial + wet * 2 + wind + abs(hour.temperature - 20) * 3
                case .cycling: return partial + wet * 3 + wind * 2 + abs(hour.temperature - 18) * 2
                case .photography:
                    let light = SolarPosition.elevation(at: hour.date, latitude: latitude, longitude: longitude)
                    return partial + wet * 2 + wind + abs(light - 2) * 3 + (hour.code > 3 ? 20 : 0)
                }
            }
            if score < bestScore { bestScore = score; best = pair }
        }
        return best
    }

    static func yesterdayDelta(_ hours: [ForecastHour], now: Date, zone: TimeZone) -> Double? {
        let calendar = WorldTime.calendar(zone)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
              let today = hours.min(by: { abs($0.date.timeIntervalSince(now)) < abs($1.date.timeIntervalSince(now)) }),
              let past = hours.min(by: { abs($0.date.timeIntervalSince(yesterday)) < abs($1.date.timeIntervalSince(yesterday)) }),
              abs(today.date.timeIntervalSince(now)) <= 3600, abs(past.date.timeIntervalSince(yesterday)) <= 3600 else { return nil }
        return today.temperature - past.temperature
    }
}

struct WeatherSnapshot: Codable {
    let locationID: UUID
    let fetchedAt: Date
    let weather: OpenMeteoResponse
}

struct WeatherSnapshotStore {
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OrbisolWeather", isDirectory: true)
    }
    func save(_ snapshot: WeatherSnapshot) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: directory.appendingPathComponent(snapshot.locationID.uuidString + ".json"), options: .atomic)
    }
    func load(_ id: UUID) -> WeatherSnapshot? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(id.uuidString + ".json")),
              let value = try? JSONDecoder().decode(WeatherSnapshot.self, from: data), value.locationID == id else { return nil }
        return value
    }
}

enum SolarPosition {
    static func daylightMinutes(on date: Date, latitude: Double, longitude: Double, zone: TimeZone) -> Int {
        let calendar = WorldTime.calendar(zone)
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        var lit = 0
        var cursor = start
        while cursor < end {
            if elevation(at: cursor, latitude: latitude, longitude: longitude) > -0.833 { lit += 1 }
            cursor = cursor.addingTimeInterval(60)
        }
        return lit
    }
    // NOAA fractional-year approximation, also used by the existing day/night widget.
    static func sun(at date: Date) -> (latitude: Double, longitude: Double) {
        let utc = WorldTime.calendar(TimeZone(secondsFromGMT: 0)!)
        let parts = utc.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60 + Double(parts.second ?? 0) / 3600
        let day = Double(utc.ordinality(of: .day, in: .year, for: date) ?? 1)
        let gamma = 2 * Double.pi / 365 * (day - 1 + (hour - 12) / 24)
        let declination = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)
        let equation = 229.18 * (0.000075 + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        return (declination * 180 / .pi, 15 * (12 - hour) - equation / 4)
    }
    static func elevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        let sun = sun(at: date)
        let lat = latitude * .pi / 180, decl = sun.latitude * .pi / 180
        let value = sin(lat) * sin(decl) + cos(lat) * cos(decl) * cos((longitude - sun.longitude) * .pi / 180)
        return asin(max(-1, min(1, value))) * 180 / .pi
    }
    struct Window: Identifiable {
        var id: Date { start }
        let name: String
        let start: Date
        let end: Date
    }
    static func photoWindows(on date: Date, latitude: Double, longitude: Double, zone: TimeZone) -> [Window] {
        let calendar = WorldTime.calendar(zone)
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        var windows: [Window] = []
        var currentName: String?
        var currentStart = start
        var cursor = start
        while cursor <= end {
            let height = elevation(at: cursor, latitude: latitude, longitude: longitude)
            let name: String? = cursor == end ? nil : (height >= -4 && height <= 6 ? "Heure dorée" : (height >= -6 && height < -4 ? "Heure bleue" : nil))
            if name != currentName {
                if let previous = currentName { windows.append(Window(name: previous, start: currentStart, end: cursor)) }
                currentStart = cursor
                currentName = name
            }
            cursor = min(cursor.addingTimeInterval(60), end.addingTimeInterval(60))
        }
        return windows
    }
}
