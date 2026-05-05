//
//  LunchDay.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//

import Foundation
import FirebaseFirestore

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

    // MARK: - Deadline-Lock (US-08)

    /// Deadline-Stunde: Bis zu dieser Uhrzeit (lokal) sind Eintragungen für heute möglich.
    /// Einzige Quelle der Wahrheit — alle Texte und Logik nutzen diesen Wert.
    static let deadlineHour = 9

    /// Formatierte Uhrzeit für UI-Texte. Beispiel: "09:00".
    /// Generiert sich automatisch aus deadlineHour, damit beim Anpassen der Stunde
    /// auch alle Texte automatisch korrekt sind.
    static var deadlineTimeString: String {
        String(format: "%02d:00", deadlineHour)
    }

    /// Standardisierter Hinweistext für gesperrte Tage.
    /// Wird in Übersicht und Detail-View identisch angezeigt.
    static var lockedMessage: String {
        "Eintragungen seit \(deadlineTimeString) geschlossen"
    }

    /// Ist dieser Tag für Änderungen gesperrt?
    /// Sperre greift, wenn der Tag heute ist UND die Deadline-Stunde überschritten wurde.
    var isLocked: Bool {
        Self.isLocked(for: date, now: Date())
    }

    /// Statische Variante für Testbarkeit und Wiederverwendung.
    static func isLocked(for date: Date, now: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current

        // Nur "heute" kann überhaupt gesperrt sein.
        guard calendar.isDate(date, inSameDayAs: now) else {
            return false
        }

        // Wir sind heute — ist die Deadline-Stunde überschritten?
        let currentHour = calendar.component(.hour, from: now)
        return currentHour >= deadlineHour
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
