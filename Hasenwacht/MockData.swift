//
//  MockData.swift
//  Hasenwacht
//
//  Mock-Daten für die UI-Entwicklung.
//  Verwendet die echten Datenmodelle (User, LunchDay, Attendance),
//  damit der Wechsel auf Firestore später nahtlos funktioniert.
//

import Foundation
import SwiftUI

// MARK: - Mock-Daten

enum MockData {

    /// Der aktuell eingeloggte Mock-User
    static let currentUser = User(
        id: "user-me",
        firstName: "Du",
        lastName: "Hasenwacht",
        photoURL: nil,
        createdAt: Date()
    )

    /// Die übrigen Bewohner als Mock
    static let otherUsers: [User] = [
        User(id: "u1", firstName: "Anna",   lastName: "Müller",    photoURL: nil, createdAt: Date()),
        User(id: "u2", firstName: "Marco",  lastName: "Bühler",    photoURL: nil, createdAt: Date()),
        User(id: "u3", firstName: "Lea",    lastName: "Keller",    photoURL: nil, createdAt: Date()),
        User(id: "u4", firstName: "Tobias", lastName: "Schneider", photoURL: nil, createdAt: Date()),
        User(id: "u5", firstName: "Sara",   lastName: "Weber",     photoURL: nil, createdAt: Date())
    ]

    /// Alle User inkl. eingeloggter User
    static var allUsers: [User] {
        [currentUser] + otherUsers
    }

    /// Erzeugt eine Liste der nächsten 7 Werktage als DayViewModel
    static func mockDays() -> [DayViewModel] {
        let calendar = Calendar.current
        var days: [DayViewModel] = []
        var date = Date()
        var added = 0

        while added < 7 {
            let weekday = calendar.component(.weekday, from: date)
            // Mo-Fr = 2..6 (1=Sonntag, 7=Samstag)
            if weekday >= 2 && weekday <= 6 {
                days.append(makeMockDay(date: date, index: added))
                added += 1
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return days
    }

    private static func makeMockDay(date: Date, index: Int) -> DayViewModel {
        let isHoliday = (index == 3)

        let lunchDay = LunchDay(
            id: nil,
            date: date,
            isHoliday: isHoliday,
            holidayName: isHoliday ? "Auffahrt" : nil,
            forceLunch: false,
            activatedBy: nil
        )

        if isHoliday {
            return DayViewModel(
                lunchDay: lunchDay,
                attendees: [],
                absentees: [],
                allUsers: allUsers,
                currentUserId: currentUser.id ?? ""
            )
        }

        // Variation: An Tag 1 ist current-User nicht da
        let currentUserAttending = (index != 1)
        let absentOtherCount = index % 3
        let absentOthers = Array(otherUsers.suffix(absentOtherCount))
        let attendingOthers = Array(otherUsers.prefix(otherUsers.count - absentOtherCount))

        let attendees = currentUserAttending ? [currentUser] + attendingOthers : attendingOthers
        let absentees = currentUserAttending ? absentOthers : [currentUser] + absentOthers

        return DayViewModel(
            lunchDay: lunchDay,
            attendees: attendees,
            absentees: absentees,
            allUsers: allUsers,
            currentUserId: currentUser.id ?? ""
        )
    }
}

// MARK: - DayViewModel

/// View-spezifische Repräsentation eines Tages.
/// Fügt LunchDay-Daten mit Teilnehmer-Daten zusammen, damit Views
/// einfach darauf zugreifen können, ohne mehrere Listen zu joinen.
struct DayViewModel: Identifiable, Hashable {
    let lunchDay: LunchDay
    var attendees: [User]
    var absentees: [User]
    let allUsers: [User]
    let currentUserId: String

    var id: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: lunchDay.date)
    }

    var date: Date { lunchDay.date }
    var isHoliday: Bool { lunchDay.isHoliday }
    var holidayName: String? { lunchDay.holidayName }
    var hasLunch: Bool { lunchDay.hasLunch }

    var attendingCount: Int { attendees.count }
    var totalCount: Int { allUsers.count }

    var currentUserAttending: Bool {
        attendees.contains { $0.id == currentUserId }
    }

    static func == (lhs: DayViewModel, rhs: DayViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Avatar-Farbe deterministisch aus User-ID

extension User {
    /// Erzeugt eine stabile Farbe aus der User-ID.
    /// Gleiche ID = gleiche Farbe, ohne dass die Farbe gespeichert werden muss.
    var avatarColor: Color {
        let palette: [Color] = [
            Color(red: 0.72, green: 0.35, blue: 0.24),  // Terrakotta
            Color(red: 0.24, green: 0.35, blue: 0.29),  // Tannengrün
            Color(red: 0.48, green: 0.24, blue: 0.32),  // Bordeaux
            Color(red: 0.17, green: 0.24, blue: 0.36),  // Marineblau
            Color(red: 0.66, green: 0.72, blue: 0.60),  // Salbei
            Color(red: 0.85, green: 0.79, blue: 0.66)   // Sand
        ]
        let userId = id ?? "default"
        let hash = abs(userId.hashValue)
        return palette[hash % palette.count]
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
