//
//  SharedAttendanceCache.swift
//  Hasenwacht
//
//  Nicht-sensitiver Cache des zuletzt bekannten Anmeldestatus für den nächsten
//  buchbaren Tag, geteilt über die App-Group-UserDefaults. Wird von der App nach
//  jedem Rebuild aktualisiert (schnelle Datenquelle für die Extension) und von
//  der Extension selbst als Fallback benutzt, wenn ein Netzwerk-Request fehlschlägt.
//
//  Enthält keine Auth-Daten — dafür ist SharedKeychain zuständig.
//

import Foundation

struct SharedAttendanceCache: Codable, Equatable {
    var date: Date
    var isAttending: Bool
    var phase: DayPhase
    var holidayName: String?
    var isCancelled: Bool
    var lastSyncedAt: Date
    var lastErrorMessage: String?

    private static let key = "sharedAttendanceCache"

    static func load() -> SharedAttendanceCache? {
        guard let data = AppGroupConstants.sharedDefaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedAttendanceCache.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        AppGroupConstants.sharedDefaults?.set(data, forKey: Self.key)
    }

    static func clear() {
        AppGroupConstants.sharedDefaults?.removeObject(forKey: key)
    }

    /// Vergleich ohne `lastSyncedAt`/`lastErrorMessage` — für "hat sich der
    /// anzeigerelevante Zustand tatsächlich geändert?"-Checks.
    func hasSameDisplayState(as other: SharedAttendanceCache?) -> Bool {
        guard let other else { return false }
        return Calendar.current.isDate(date, inSameDayAs: other.date)
            && isAttending == other.isAttending
            && phase == other.phase
            && holidayName == other.holidayName
            && isCancelled == other.isCancelled
    }
}
