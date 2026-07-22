//
//  LunchPhaseCalculator.swift
//  Hasenwacht
//
//  Firebase-freie Cutoff-/Phasen-Logik. Wird sowohl von der App (LunchDay)
//  als auch von der Widget-Extension genutzt — die Extension kann kein
//  FirebaseFirestore importieren, daher liegt diese Logik hier statt in
//  LunchDay.swift.
//

import Foundation

/// Beschreibt den Zustand eines Tages aus User-Sicht.
///
/// Tagesablauf für einen Lunch-Tag X:
/// - Bis Vortag 14:00 → .bookable    (offen, Toggle möglich)
/// - Vortag 14:00 - 12:14 am Tag X → .locked  (gesperrt)
/// - 12:15 - 23:59 am Tag X → .lunchOver  (Mittagessen vorbei)
/// - nächster Tag → Tag verschwindet aus der Liste
enum DayPhase: String, Codable {
    case bookable
    case locked
    case lunchOver
}

enum LunchPhaseCalculator {

    // MARK: - Phase-Konfiguration

    /// Stunde am Vortag, ab der Eintragungen für den Folgetag nicht mehr möglich sind.
    /// Spec: 14:00 — gibt der kochenden Person Zeit für Einkauf am Nachmittag.
    static let cutoffHour = 14

    /// Uhrzeit, ab der "Mittagessen vorbei" gilt.
    static let lunchOverTime = (hour: 12, minute: 15)

    // MARK: - Phase-Bestimmung

    /// Logik:
    /// - Heute & nach 12:15 → .lunchOver
    /// - Cutoff überschritten (Vortag 14:00) → .locked
    /// - Sonst → .bookable
    static func phase(for date: Date, now: Date) -> DayPhase {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current

        // 1. Sonderfall "heute": Nach 12:15 = lunchOver.
        if calendar.isDate(date, inSameDayAs: now) {
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            if hour > lunchOverTime.hour ||
               (hour == lunchOverTime.hour && minute >= lunchOverTime.minute) {
                return .lunchOver
            }
        }

        // 2. Cutoff prüfen: Ist now >= (Vortag um cutoffHour:00)?
        if let cutoff = cutoffMoment(for: date, calendar: calendar), now >= cutoff {
            return .locked
        }

        return .bookable
    }

    /// Berechnet den exakten Cutoff-Zeitpunkt für einen Lunch-Tag.
    /// Beispiel: Lunch am Mittwoch 13.5. → Cutoff = Dienstag 12.5. 14:00.
    static func cutoffMoment(for date: Date, calendar: Calendar) -> Date? {
        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: date) else {
            return nil
        }
        return calendar.date(
            bySettingHour: cutoffHour,
            minute: 0,
            second: 0,
            of: dayBefore
        )
    }

    // MARK: - Nächstes buchbares Datum

    /// Der nächste Werktag (Mo–Fr), für den aktuell noch ein Toggle möglich ist
    /// (phase == .bookable). Feiertage und gestrichene Tage zählen weiterhin als
    /// buchbar — die App selbst sperrt den Toggle dort nicht, nur der Cutoff tut das.
    static func nextBookableDate(now: Date = Date()) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        var candidate = calendar.startOfDay(for: now)

        for _ in 0..<30 {
            let weekday = calendar.component(.weekday, from: candidate)
            if weekday >= 2 && weekday <= 6 {
                let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: candidate) ?? candidate
                if phase(for: noon, now: now) == .bookable {
                    return noon
                }
            }
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    // MARK: - UI-Texte (zentralisiert für DRY)

    /// Generische Lock-Message — der konkrete Cutoff-Zeitpunkt ist
    /// für den User nicht handlungsrelevant, also halten wir's knapp.
    static var lockedMessage: String {
        "Eintragungen geschlossen"
    }

    /// Hinweistext für Phase .lunchOver.
    static var lunchOverMessage: String {
        "Heute schon gegessen."
    }

    /// Optionaler Hinweistext basierend auf der Phase. Gibt nil zurück für .bookable.
    static func message(for phase: DayPhase) -> String? {
        switch phase {
        case .bookable:  return nil
        case .locked:    return lockedMessage
        case .lunchOver: return lunchOverMessage
        }
    }

    // MARK: - Document-ID-Helper

    /// Erzeugt die deterministische "YYYY-MM-DD"-Datumskomponente (Schweizer Zeitzone),
    /// die in mehreren Firestore-Document-IDs verwendet wird (lunchDays, attendances, ...).
    static func dayDocumentId(for date: Date) -> String {
        dayIdFormatter.string(from: date)
    }

    private static let dayIdFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
