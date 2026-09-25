import Foundation

// MARK: - Formatage des heures & fuseaux
//
// Toutes les horloges de l'interface passent par ici pour rester cohérentes
// (12h/24h, fuseau local du lieu, libellés UTC, codes courts).

enum ClockFormat {

    /// H / min / s locales d'un fuseau à un instant donné.
    static func parts(timeZone: TimeZone, date: Date = Date()) -> (hour: Int, minute: Int, second: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0, components.minute ?? 0, components.second ?? 0)
    }

    /// « 08:42 » + suffixe « am » / « pm » (vide en mode 24 h).
    /// Heure toujours sur deux chiffres, comme sur la maquette (« 08:42 »).
    static func time(timeZone: TimeZone, hour12: Bool, date: Date = Date()) -> (text: String, suffix: String) {
        let p = parts(timeZone: timeZone, date: date)
        var hour = p.hour
        if hour12 {
            let suffix = hour < 12 ? "am" : "pm"
            hour = hour % 12
            if hour == 0 { hour = 12 }
            return (String(format: "%02d:%02d", hour, p.minute), suffix)
        }
        return (String(format: "%02d:%02d", hour, p.minute), "")
    }

    /// « 18 h » (24 h) ou « 6 pm » (12 h) — créneau horaire à l'heure pleine.
    static func shortHour(hour: Int, hour12: Bool) -> String {
        if hour12 {
            let suffix = hour < 12 ? "am" : "pm"
            var h = hour % 12
            if h == 0 { h = 12 }
            return "\(h) \(suffix)"
        }
        return "\(hour) h"
    }

    /// Libellé UTC (« UTC-8 », « UTC+5:30 »…).
    static func utcLabel(timeZone: TimeZone) -> String {
        let seconds = timeZone.secondsFromGMT()
        let totalMinutes = seconds / 60
        let sign = totalMinutes < 0 ? "-" : "+"
        let hours = abs(totalMinutes) / 60
        let minutes = abs(totalMinutes) % 60
        if minutes == 0 { return String(format: "UTC%@%d", sign, hours) }
        return String(format: "UTC%@%d:%02d", sign, hours, minutes)
    }

    /// Code court (« LOS », « TOK »…) pour les cadrans et la carte.
    static func code3(_ name: String) -> String {
        let alphanumerics = name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(alphanumerics.prefix(3))).uppercased()
    }
}
