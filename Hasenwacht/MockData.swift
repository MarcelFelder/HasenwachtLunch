//
//  MockData.swift
//  Hasenwacht
//
//  Datenmodelle und Mock-Daten für die UI-Entwicklung.
//  Wird später durch echte Firestore-Daten ersetzt.
//

import Foundation

// MARK: - Datenmodelle

/// Repräsentiert einen einzelnen Bewohner / User
struct Person: Identifiable, Hashable {
    let id: String
    let firstName: String
    let lastName: String
    let avatarColor: String  // Hex-Farbe für Default-Avatar

    var fullName: String { "\(firstName) \(lastName)" }
    var initials: String {
        let first = firstName.first.map { String($0) } ?? ""
        let last = lastName.first.map { String($0) } ?? ""
        return first + last
    }
}

/// Repräsentiert einen einzelnen Mittagstag
struct LunchDay: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let isHoliday: Bool
    let holidayName: String?
    let attendees: [Person]
    let absentees: [Person]
    let totalPeople: Int  // Anzahl Bewohner gesamt

    /// Ist der angemeldete User dabei? (Für MVP fest auf true gesetzt – später dynamisch)
    var currentUserAttending: Bool

    var attendingCount: Int { attendees.count }
}

// MARK: - Mock-Daten

enum MockData {

    /// Der "ich" – also der angemeldete User
    static let currentUser = Person(
        id: "user-me",
        firstName: "Du",
        lastName: "",
        avatarColor: "#D9C9A8"
    )

    /// Die übrigen Bewohner
    static let otherResidents: [Person] = [
        Person(id: "u1", firstName: "Anna",   lastName: "Müller",   avatarColor: "#B85A3E"),
        Person(id: "u2", firstName: "Marco",  lastName: "Bühler",   avatarColor: "#3D5A4A"),
        Person(id: "u3", firstName: "Lea",    lastName: "Keller",   avatarColor: "#7A3E52"),
        Person(id: "u4", firstName: "Tobias", lastName: "Schneider", avatarColor: "#2C3E5C"),
        Person(id: "u5", firstName: "Sara",   lastName: "Weber",    avatarColor: "#A8B89A")
    ]

    static var allResidents: [Person] {
        [currentUser] + otherResidents
    }

    /// Die nächsten 7 Werktage als Mock
    static func nextWorkdays() -> [LunchDay] {
        let calendar = Calendar.current
        var days: [LunchDay] = []
        var date = Date()
        var added = 0

        while added < 7 {
            let weekday = calendar.component(.weekday, from: date)
            // 1 = Sonntag, 7 = Samstag (US-Konvention) → Mo-Fr = 2..6
            if weekday >= 2 && weekday <= 6 {
                days.append(makeDay(for: date, index: added))
                added += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return days
    }

    private static func makeDay(for date: Date, index: Int) -> LunchDay {
        // Variation in den Mock-Daten, damit es spannend aussieht
        let allOthers = otherResidents

        let isHoliday = (index == 3)  // 4. Tag als Beispiel-Feiertag
        if isHoliday {
            return LunchDay(
                date: date,
                isHoliday: true,
                holidayName: "Auffahrt",
                attendees: [],
                absentees: [],
                totalPeople: allResidents.count,
                currentUserAttending: false
            )
        }

        // Mock: Pro Tag andere Verteilung
        let attendingOthers = Array(allOthers.prefix(allOthers.count - (index % 3)))
        let absentOthers = Array(allOthers.suffix(index % 3))
        let userAttends = (index != 1)  // An Tag 2 mal nicht da

        let attendees = userAttends ? [currentUser] + attendingOthers : attendingOthers
        let absentees = userAttends ? absentOthers : [currentUser] + absentOthers

        return LunchDay(
            date: date,
            isHoliday: false,
            holidayName: nil,
            attendees: attendees,
            absentees: absentees,
            totalPeople: allResidents.count,
            currentUserAttending: userAttends
        )
    }
}

// MARK: - Date-Helpers

extension Date {
    /// "Mo, 5. Mai"
    func formattedShort() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateFormat = "EE, d. MMM"
        return formatter.string(from: self)
    }

    /// "Montag"
    func weekdayName() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }

    /// "5. Mai 2026"
    func formattedLong() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_CH")
        formatter.dateFormat = "d. MMMM yyyy"
        return formatter.string(from: self)
    }
}
