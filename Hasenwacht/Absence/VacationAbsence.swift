//
//  VacationAbsence.swift
//  Hasenwacht
//
//  Ein Dokument pro Ferieneintrag in der Collection "vacationAbsences".
//

import Foundation
import FirebaseFirestore

struct VacationAbsence: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var startDate: Date
    var endDate: Date
    var name: String?
    var createdAt: Date

    init(id: String? = nil,
         userId: String,
         startDate: Date,
         endDate: Date,
         name: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.startDate = startDate
        self.endDate = endDate
        self.name = name
        self.createdAt = createdAt
    }

    /// Gibt true zurück wenn das Datum innerhalb des Ferienbereichs liegt.
    func covers(date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let day = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return day >= start && day <= end
    }

    /// Anzeige-Label für die UI.
    var displayName: String {
        name?.isEmpty == false ? name! : "Ferien"
    }

    /// Formatierter Datumsbereich für die UI.
    var dateRangeLabel: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_CH")
        df.dateFormat = "d. MMM"
        df.timeZone = TimeZone(identifier: "Europe/Zurich")
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let startYear = yearFormatter.string(from: startDate)
        let endYear = yearFormatter.string(from: endDate)
        if startYear == endYear {
            return "\(df.string(from: startDate)) – \(df.string(from: endDate)) \(endYear)"
        }
        return "\(df.string(from: startDate)) \(startYear) – \(df.string(from: endDate)) \(endYear)"
    }
}
