//
//  AttendanceEntry.swift
//  HasenwachtWidget
//

import WidgetKit
import Foundation

/// Anzeigezustand des Widgets für den nächsten buchbaren Tag.
struct AttendanceDisplayState: Equatable {
    var date: Date
    var isAttending: Bool
    var phase: DayPhase
    var holidayName: String?
    var isCancelled: Bool
    /// True, wenn die Daten aus dem lokalen Cache stammen (kein frischer
    /// Netzwerk-Request), z.B. weil das Gerät gerade offline ist.
    var isStale: Bool
}

enum AttendanceWidgetState: Equatable {
    /// Kein Refresh-Token in der geteilten Keychain gefunden — User ist in der App nicht eingeloggt.
    case loggedOut
    /// Netzwerk-/Auth-Fehler und kein brauchbarer Cache vorhanden.
    case error(String)
    case attendance(AttendanceDisplayState)
}

struct AttendanceEntry: TimelineEntry {
    let date: Date
    let state: AttendanceWidgetState
}
