
//
//  MockData.swift
//  Hasenwacht
//
//  Mock-Daten für die UI-Entwicklung und SwiftUI Previews.
//  Verwendet die echten Datenmodelle, damit der Wechsel auf Firestore
//  nahtlos funktioniert.
//
 
import Foundation
 
enum MockData {
 
    // MARK: - User
 
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
 
    // MARK: - Mock Days
 
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
