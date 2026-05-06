//
//  LunchDay.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//

import Foundation
import FirebaseFirestore

// MARK: - DayPhase

/// Beschreibt den Zustand eines Tages aus User-Sicht.
///
/// Tagesablauf für einen Lunch-Tag X:
/// - Bis Vortag 14:00 → .bookable    (offen, Toggle möglich)
/// - Vortag 14:00 - 12:14 am Tag X → .locked  (gesperrt)
/// - 12:15 - 23:59 am Tag X → .lunchOver  (Mittagessen vorbei)
/// - nächster Tag → Tag verschwindet aus der Liste
enum DayPhase {
    case bookable
    case locked
    case lunchOver
}

// MARK: - LunchDay

struct LunchDay: Identifiable, Codable {
    @DocumentID var id: String?
    var date: Date
    var isHoliday: Bool
    var holidayName: String?
    var forceLunch: Bool
    var activatedBy: String?

    var hasLunch: Bool {
        !isHoliday || forceLunch
    }

    // MARK: - Phase-Konfiguration

    /// Stunde am Vortag, ab der Eintragungen für den Folgetag nicht mehr möglich sind.
    /// Spec: 14:00 — gibt der kochenden Person Zeit für Einkauf am Nachmittag.
    static let cutoffHour = 14

    /// Uhrzeit, ab der "Mittagessen vorbei" gilt.
    static let lunchOverTime = (hour: 12, minute: 15)

    // MARK: - Phase-Bestimmung

    /// Phase dieses Tages basierend auf der aktuellen Zeit.
    var phase: DayPhase {
        Self.phase(for: date, now: Date())
    }

    /// Statische Variante für Testbarkeit.
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
    private static func cutoffMoment(for date: Date, calendar: Calendar) -> Date? {
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

    /// Convenience: ist dieser Tag für Toggle-Aktionen gesperrt?
    /// True für alle Phasen ausser .bookable.
    var isLocked: Bool {
        phase != .bookable
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

    /// Optionaler Hinweistext basierend auf der aktuellen Phase.
    /// Gibt nil zurück, wenn keine Notiz angezeigt werden soll (Phase .bookable).
    var phaseMessage: String? {
        switch phase {
        case .bookable:  return nil
        case .locked:    return Self.lockedMessage
        case .lunchOver: return Self.lunchOverMessage
        }
    }

    // MARK: - Document ID Helper

    /// Erzeugt die deterministische Firestore-Document-ID für ein Datum.
    /// Format: "YYYY-MM-DD" (Schweizer Zeitzone).
    static func documentId(for date: Date) -> String {
        Self.documentIdFormatter.string(from: date)
    }

    private static let documentIdFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
