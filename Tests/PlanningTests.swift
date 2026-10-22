import Foundation
@main struct PlanningTests {
    static func main() throws {
        if let path = CommandLine.arguments.dropFirst().first {
            let live = try JSONDecoder().decode(OpenMeteoResponse.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
            precondition(live.current != nil)
            print("PASS: live weather response decoded")
        }
        let date = ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z")!
        precondition(WorldTime.offset(from: TimeZone(identifier: "Europe/Paris")!, to: TimeZone(identifier: "Asia/Kolkata")!, at: date) == "+4 h 30")
        print("PASS: half-hour offsets")
        let utc = TimeZone(secondsFromGMT: 0)!
        let paris = TimeZone(identifier: "Europe/Paris")!
        func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
        func hour(_ offset: Double, rain: Int? = 0, wind: Double? = 10, temperature: Double = 20) -> ForecastHour {
            ForecastHour(date: date.addingTimeInterval(offset * 3600), temperature: temperature,
                         code: 0, rain: rain, wind: wind, precipitation: nil)
        }
        precondition(WorldTime.offset(from: utc, to: paris, at: instant("2026-07-15T12:00:00Z")) == "+2 h")
        precondition(WorldTime.dayDifference(from: utc, to: TimeZone(identifier: "Asia/Tokyo")!, at: instant("2026-01-15T23:00:00Z")) == "Demain")
        precondition(WorldTime.dayDifference(from: utc, to: TimeZone(identifier: "America/New_York")!, at: instant("2026-01-15T01:00:00Z")) == "Hier")
        precondition(WorldTime.parse("invalid", zone: utc) == nil)
        print("PASS: daylight saving, date boundaries and invalid timestamps")

        var preferences = AlertPreferences()
        precondition(preferences.isQuiet(instant("2026-01-15T23:00:00Z"), zone: utc))
        precondition(preferences.isQuiet(instant("2026-01-15T07:59:00Z"), zone: utc))
        precondition(!preferences.isQuiet(instant("2026-01-15T08:00:00Z"), zone: utc))
        preferences.quietStart = 12; preferences.quietEnd = 14
        precondition(preferences.isQuiet(date, zone: utc))
        precondition(!preferences.isQuiet(date.addingTimeInterval(7200), zone: utc))
        preferences.quietEnabled = false
        precondition(!preferences.isQuiet(date, zone: utc))
        let decoded = try JSONDecoder().decode(AlertPreferences.self, from: JSONEncoder().encode(preferences))
        precondition(decoded == preferences)
        print("PASS: overnight/daytime quiet hours and preferences persistence")

        let slots = WorldTime.commonSlots(zones: [paris, TimeZone(identifier: "America/New_York")!], after: date)
        precondition(!slots.isEmpty)
        for slot in slots {
            for zone in [paris, TimeZone(identifier: "America/New_York")!] {
                let calendar = WorldTime.calendar(zone)
                precondition(calendar.component(.hour, from: slot) >= 9)
                precondition(calendar.component(.hour, from: slot.addingTimeInterval(3599)) < 19)
            }
        }
        precondition(WorldTime.commonSlots(zones: [], after: date).isEmpty)
        precondition(WorldTime.commonSlots(zones: [utc, TimeZone(secondsFromGMT: 12 * 3600)!], after: date).isEmpty)
        print("PASS: common one-hour slots and impossible overlaps")

        let weekday = WorldTime.calendar(utc).component(.weekday, from: date)
        let allowed = WorkingHours(start: 12, end: 15, weekdays: [weekday])
        let limited = WorldTime.commonSlots(availability: [(utc, allowed)], after: date)
        precondition(!limited.isEmpty && limited.allSatisfy { allowed.contains($0, duration: 3600, zone: utc) })
        precondition(WorldTime.commonSlots(availability: [(utc, WorkingHours(start: 12, end: 15, weekdays: []))], after: date).isEmpty)
        precondition(WorldTime.weeklyOccurrences(from: date, count: 4).count == 4)
        print("PASS: configurable local working hours and weekly occurrences")

        let best = WeatherInsights.bestWindow([hour(0, rain: 90), hour(1), hour(2), hour(3, wind: 80)], after: date, zone: utc)
        precondition(best.map(\.date) == [hour(1).date, hour(2).date])
        precondition(WeatherInsights.bestWindow([hour(0, rain: nil), hour(1)], after: date, zone: utc).isEmpty)
        precondition(WeatherInsights.bestWindow([hour(0), hour(2)], after: date, zone: utc).isEmpty)
        precondition(WeatherInsights.yesterdayDelta([hour(-24, temperature: 17), hour(0)], now: date, zone: utc) == 3)
        precondition(WeatherInsights.yesterdayDelta([hour(0)], now: date, zone: utc) == nil)
        precondition(!WeatherInsights.bestWindow([hour(0), hour(1), hour(2)], after: date, zone: utc, activity: .cycling).isEmpty)
        print("PASS: outing scoring, missing data, gaps and yesterday comparison")

        let json = #"{"timezone":"UTC","hourly":{"time":["2026-01-15T12:00","2026-01-15T13:00"],"temperature_2m":[20],"weather_code":[0,0]}}"#
        let weather = try JSONDecoder().decode(OpenMeteoResponse.self, from: Data(json.utf8))
        precondition(WeatherInsights.hours(weather, zone: utc).count == 1)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = WeatherSnapshotStore(directory: directory)
        let id = UUID()
        precondition(store.load(id) == nil)
        try store.save(WeatherSnapshot(locationID: id, fetchedAt: date, weather: weather))
        precondition(store.load(id)?.fetchedAt == date)
        precondition(store.load(id)?.weather.hourly?.temperature2m == [20])
        try Data("corrupt".utf8).write(to: directory.appendingPathComponent(id.uuidString + ".json"))
        precondition(store.load(id) == nil)
        print("PASS: truncated arrays, offline roundtrip and corrupt cache")
        let nulls = #"{"timezone":"UTC","hourly":{"time":["2026-01-15T12:00","2026-01-15T13:00"],"temperature_2m":[20,null],"weather_code":[0,null],"precipitation_probability":[null,null],"uv_index":[null,null]}}"#
        let incomplete = try JSONDecoder().decode(OpenMeteoResponse.self, from: Data(nulls.utf8))
        let validHours = WeatherInsights.hours(incomplete, zone: utc)
        precondition(validHours.count == 1 && validHours[0].rain == nil)
        print("PASS: null forecast values preserve valid hours without inventing rain")

        let equinox = instant("2026-03-20T12:00:00Z")
        precondition(SolarPosition.elevation(at: equinox, latitude: 0, longitude: 0) > 85)
        precondition(SolarPosition.elevation(at: equinox, latitude: 0, longitude: 180) < -85)
        let windows = SolarPosition.photoWindows(on: equinox, latitude: 48.85, longitude: 2.35, zone: paris)
        precondition(windows.count == 4 && windows.allSatisfy { $0.end > $0.start })
        precondition(SolarPosition.photoWindows(on: instant("2026-06-21T12:00:00Z"), latitude: 89, longitude: 0, zone: utc).isEmpty)
        print("PASS: solar day/night, photo windows and polar day")
        let summer = SolarPosition.daylightMinutes(on: instant("2026-06-21T12:00:00Z"), latitude: 48.85, longitude: 2.35, zone: paris)
        let winter = SolarPosition.daylightMinutes(on: instant("2026-12-21T12:00:00Z"), latitude: 48.85, longitude: 2.35, zone: paris)
        precondition(summer > 900 && winter < 550 && summer > winter)
        let oldPreferences = #"{"excludedCities":[],"quietEnabled":true,"quietStart":22,"quietEnd":8,"windEnabled":false,"windThreshold":50,"temperatureEnabled":false,"temperatureThreshold":30}"#
        let migrated = try JSONDecoder().decode(AlertPreferences.self, from: Data(oldPreferences.utf8))
        precondition(migrated.coldEnabled != true && (migrated.coldThreshold ?? 0) == 0)
        precondition(migrated.airEnabled != true && migrated.pollenEnabled != true)
        print("PASS: seasonal daylight and backwards-compatible cold-alert preferences")
        let city = Location(name: "Paris", latitude: 48.85, longitude: 2.35, timeZoneIdentifier: "Europe/Paris")
        let sameCity = Location(name: "PARIS", latitude: 48.85, longitude: 2.35, timeZoneIdentifier: "Europe/Paris")
        let nearbyVillage = Location(name: "Village voisin", latitude: 48.851, longitude: 2.351, timeZoneIdentifier: "Europe/Paris")
        precondition(city.isSamePlace(as: sameCity) && !city.isSamePlace(as: nearbyVillage))
        var backup = SettingsBackup(cities: [city], alerts: preferences, hour12: false, fahrenheit: false, rain: false,
            threshold: 55, lead: 60, strings: [:], switches: [:])
        try backup.validate()
        let restored = try JSONDecoder().decode(SettingsBackup.self, from: JSONEncoder().encode(backup))
        precondition(restored.cities == [city] && restored.alerts == preferences)
        let oldTrip = TripPlan(group: "Séjour", start: date, end: date.addingTimeInterval(86400))
        let oldTripData = try JSONEncoder().encode(oldTrip)
        let decodedTrip = try JSONDecoder().decode(TripPlan.self, from: oldTripData)
        precondition(decodedTrip.stages == nil && decodedTrip.checklist == nil)
        let invalidStage = TripStage(locationID: city.id, arrive: date.addingTimeInterval(-60), depart: date)
        backup.strings["Orbisol.trips"] = String(data: try JSONEncoder().encode([
            TripPlan(group: "Séjour", start: date, end: date.addingTimeInterval(86400), stages: [invalidStage])
        ]), encoding: .utf8)!
        do { try backup.validate(); preconditionFailure("Out-of-range trip stage accepted") } catch {}
        backup.strings.removeValue(forKey: "Orbisol.trips")
        backup.version = 99
        do { try backup.validate(); preconditionFailure("Unknown backup version accepted") } catch {}
        backup.version = 1; backup.cities = [city, city]
        do { try backup.validate(); preconditionFailure("Duplicate cities accepted") } catch {}
        backup.cities = [city]; backup.strings["Orbisol.weather.order"] = "[\"invalid\"]"
        do { try backup.validate(); preconditionFailure("Invalid sections accepted") } catch {}
        precondition(WeatherSection.ordered("[\"rain\",\"rain\"]").count == WeatherSection.allCases.count)
        precondition(WeatherSection.ordered("[\"rain\"]").first == .rain)
        let meeting = MeetingText.describe(date: instant("2026-01-15T23:30:00Z"), cities: [city])
        precondition(meeting.contains("16 janvier 2026") && meeting.contains("00:30"))
        print("PASS: backup roundtrip, version/duplicate/layout validation and meeting local date")
    }
}
