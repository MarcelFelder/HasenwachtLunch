//
//  RecurringAbsence.swift
//  Hasenwacht
//
//  Ein Dokument pro User in Firestore.
//  Speichert welche Wochentage dauerhaft abwesend sind.
//  Weekday-Encoding: 1=Montag … 5=Freitag (ISO, nicht Apple-Standard)
//

import Foundation
import FirebaseFirestore

struct RecurringAbsence: Codable {
    /// Abwesende Wochentage: 1=Mo, 2=Di, 3=Mi, 4=Do, 5=Fr
    var absentWeekdays: [Int]
    var updatedAt: Date

    init(absentWeekdays: [Int] = [], updatedAt: Date = Date()) {
        self.absentWeekdays = absentWeekdays
        self.updatedAt = updatedAt
    }

    /// Gibt true zurück wenn das gegebene Datum ein abwesender Wochentag ist.
    func isAbsent(on date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        // Apple: 1=So, 2=Mo … 7=Sa → umrechnen auf ISO 1=Mo…5=Fr
        let appleWeekday = calendar.component(.weekday, from: date)
        let isoWeekday = appleWeekday == 1 ? 7 : appleWeekday - 1
        return absentWeekdays.contains(isoWeekday)
    }
}
