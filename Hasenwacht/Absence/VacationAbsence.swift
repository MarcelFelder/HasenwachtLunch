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
        let startYear = Self.yearFormatter.string(from: startDate)
        let endYear = Self.yearFormatter.string(from: endDate)
        if startYear == endYear {
            return "\(Self.dayMonthFormatter.string(from: startDate)) – \(Self.dayMonthFormatter.string(from: endDate)) \(endYear)"
        }
        return "\(Self.dayMonthFormatter.string(from: startDate)) \(startYear) – \(Self.dayMonthFormatter.string(from: endDate)) \(endYear)"
    }

    private static let dayMonthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_CH")
        df.dateFormat = "d. MMM"
        df.timeZone = TimeZone(identifier: "Europe/Zurich")
        return df
    }()

    private static let yearFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy"
        return df
    }()
}
