//
//  Date+Formatting.swift
//  Hasenwacht
//
//  Date-Extensions für die UI-Darstellung von Werktagen, Daten und Wochentagen.
//

import Foundation

extension Date {
    
    // MARK: - Properties (für neuen Code)
    
    /// Wochentag abgekürzt: "Mo", "Di", ...
    var weekdayName: String {
        Self.weekdayShortFormatter.string(from: self)
    }
    
    /// Wochentag ausgeschrieben: "Montag", "Dienstag", ...
    var weekdayNameLong: String {
        Self.weekdayLongFormatter.string(from: self)
    }
    
    /// ISO-Tag: "2026-05-06" — für Firestore-Document-IDs.
    var isoDayString: String {
        Self.isoDayFormatter.string(from: self)
    }
    
    // MARK: - Methoden (Kompatibilität mit bestehendem View-Code)
    //
    // Hinweis: Diese Methoden existieren parallel zu den Properties oben,
    // weil die Views sie als Funktionen aufrufen. Funktional identisch.
    
    /// Kompakte Tagesanzeige: "6. Mai".
    func formattedShort() -> String {
        Self.shortFormatter.string(from: self)
    }
    
    /// Lange Datumsanzeige: "6. Mai 2026".
    func formattedLong() -> String {
        Self.longFormatter.string(from: self)
    }
    
    // MARK: - Cached Formatters
    
    private static let weekdayShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        f.dateFormat = "EE"   // "Mo", "Di", ...
        return f
    }()
    
    private static let weekdayLongFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        f.dateFormat = "EEEE"   // "Montag", "Dienstag", ...
        return f
    }()
    
    private static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        f.dateFormat = "d. MMMM"   // "6. Mai"
        return f
    }()
    
    private static let longFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_CH")
        f.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        f.dateFormat = "d. MMMM yyyy"   // "6. Mai 2026"
        return f
    }()
    
    private static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
