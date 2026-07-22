//
//  HolidayService.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//
//  Verantwortlich für die Erkennung von Schweizer Feiertagen
//  im Kanton Aargau. Berechnet bewegliche Feiertage (Oster-basiert)
//  selbst, ohne externe Dependencies.
//

import Foundation

/// Repräsentiert einen Feiertag mit Datum und Name.
struct Holiday {
    let date: Date
    let name: String
}

/// Service zur Bestimmung von Schweizer Feiertagen im Kanton Aargau.
///
/// Verwendung:
/// ```
/// let service = HolidayService()
/// if let holiday = service.holiday(for: Date()) {
///     print("Heute ist \(holiday.name)")
/// }
/// ```
final class HolidayService {

    // MARK: - Public API

    /// Gibt zurück, ob das gegebene Datum ein Feiertag im Kanton Aargau ist.
    /// - Parameter date: Das zu prüfende Datum (Uhrzeit wird ignoriert).
    /// - Returns: `Holiday`-Objekt mit Name, oder `nil` wenn kein Feiertag.
    func holiday(for date: Date) -> Holiday? {
        let year = calendar.component(.year, from: date)
        let normalizedDate = calendar.startOfDay(for: date)

        return holidays(in: year).first { holiday in
            calendar.isDate(holiday.date, inSameDayAs: normalizedDate)
        }
    }

    /// Komfort-Methode für UI-Code: ist das Datum ein Feiertag?
    func isHoliday(_ date: Date) -> Bool {
        holiday(for: date) != nil
    }

    /// Liefert alle Feiertage eines Jahres im Kanton Aargau.
    /// - Parameter year: Jahreszahl (z. B. 2026).
    /// - Returns: Array von Holidays, sortiert nach Datum.
    func holidays(in year: Int) -> [Holiday] {
        // Fixe Feiertage (datum-basiert)
        let fixed: [(month: Int, day: Int, name: String)] = [
            (1,  1,  "Neujahr"),
            (1,  2,  "Berchtoldstag"),
            (5,  1,  "Tag der Arbeit"),
            (8,  1,  "Bundesfeiertag"),
            (12, 25, "Weihnachten"),
            (12, 26, "Stephanstag")
        ]

        var result: [Holiday] = fixed.compactMap { entry in
            guard let date = makeDate(year: year, month: entry.month, day: entry.day) else {
                return nil
            }
            return Holiday(date: date, name: entry.name)
        }

        // Bewegliche Feiertage (Oster-basiert)
        if let easter = easterSunday(year: year) {
            // Karfreitag = Ostersonntag - 2 Tage
            if let goodFriday = calendar.date(byAdding: .day, value: -2, to: easter) {
                result.append(Holiday(date: goodFriday, name: "Karfreitag"))
            }
            // Ostermontag = Ostersonntag + 1 Tag
            if let easterMonday = calendar.date(byAdding: .day, value: 1, to: easter) {
                result.append(Holiday(date: easterMonday, name: "Ostermontag"))
            }
            // Auffahrt (Christi Himmelfahrt) = Ostersonntag + 39 Tage
            if let ascension = calendar.date(byAdding: .day, value: 39, to: easter) {
                result.append(Holiday(date: ascension, name: "Auffahrt"))
            }
            // Pfingstmontag = Ostersonntag + 50 Tage
            if let whitMonday = calendar.date(byAdding: .day, value: 50, to: easter) {
                result.append(Holiday(date: whitMonday, name: "Pfingstmontag"))
            }
        }

        return result.sorted { $0.date < $1.date }
    }

    // MARK: - Private

    /// Schweizer Kalender mit Zeitzone Europe/Zurich.
    /// Wichtig: Wir wollen *lokale* Daten — wenn der User um Mitternacht
    /// auf "morgen" tappt, soll das auch wirklich morgen in Zürich sein.
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        return cal
    }()

    /// Hilfsfunktion: erzeugt ein Datum aus Jahr/Monat/Tag.
    private func makeDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    /// Berechnet Ostersonntag nach der anonymen Gregorianischen Formel
    /// (Meeus/Jones/Butcher-Algorithmus).
    ///
    /// Funktioniert für alle Jahre im Gregorianischen Kalender (ab 1583).
    /// Wir validieren das Ergebnis nicht weiter — die Formel ist mathematisch
    /// bewiesen korrekt für unseren Anwendungsbereich.
    private func easterSunday(year: Int) -> Date? {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1

        return makeDate(year: year, month: month, day: day)
    }
}
