//
//  LunchDay.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//

import Foundation
import FirebaseFirestore

// MARK: - LunchDay

struct LunchDay: Identifiable, Codable {
    @DocumentID var id: String?
    var date: Date
    var isHoliday: Bool
    var holidayName: String?
    var forceLunch: Bool
    var activatedBy: String?

    /// True wenn der Tag manuell von einem User gestrichen wurde.
    var isCancelled: Bool = false
    /// User der den Tag gestrichen hat (darf ihn auch wieder aktivieren).
    var cancelledBy: String?

    var hasLunch: Bool {
        guard !isCancelled else { return false }
        return !isHoliday || forceLunch
    }

    // MARK: - Phase-Bestimmung
    //
    // Die eigentliche Cutoff-/Phasen-Logik lebt in LunchPhaseCalculator (Shared/),
    // damit sie ohne FirebaseFirestore-Abhängigkeit auch von der Widget-Extension
    // genutzt werden kann.

    static var cutoffHour: Int { LunchPhaseCalculator.cutoffHour }

    /// Phase dieses Tages basierend auf der aktuellen Zeit.
    var phase: DayPhase {
        Self.phase(for: date, now: Date())
    }

    /// Statische Variante für Testbarkeit.
    static func phase(for date: Date, now: Date) -> DayPhase {
        LunchPhaseCalculator.phase(for: date, now: now)
    }

    /// Convenience: ist dieser Tag für Toggle-Aktionen gesperrt?
    /// True für alle Phasen ausser .bookable.
    var isLocked: Bool {
        phase != .bookable
    }

    // MARK: - UI-Texte (zentralisiert für DRY)

    static var lockedMessage: String { LunchPhaseCalculator.lockedMessage }
    static var lunchOverMessage: String { LunchPhaseCalculator.lunchOverMessage }

    /// Optionaler Hinweistext basierend auf der aktuellen Phase.
    /// Gibt nil zurück, wenn keine Notiz angezeigt werden soll (Phase .bookable).
    var phaseMessage: String? {
        LunchPhaseCalculator.message(for: phase)
    }

    // MARK: - Document ID Helper

    /// Erzeugt die deterministische Firestore-Document-ID für ein Datum.
    /// Format: "YYYY-MM-DD" (Schweizer Zeitzone).
    static func documentId(for date: Date) -> String {
        LunchPhaseCalculator.dayDocumentId(for: date)
    }
}
