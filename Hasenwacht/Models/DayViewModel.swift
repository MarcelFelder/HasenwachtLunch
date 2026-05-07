//
//  DayViewModel.swift
//  Hasenwacht
//
//  View-spezifische Repräsentation eines Tages.
//  Fügt LunchDay-Daten mit Teilnehmer-Daten zusammen, damit Views
//  einfach darauf zugreifen können, ohne mehrere Listen zu joinen.
//

import Foundation

struct DayViewModel: Identifiable, Hashable {
    let lunchDay: LunchDay
    var attendees: [User]
    var absentees: [User]
    let allUsers: [User]
    let currentUserId: String

    /// Markiert den "nächsten relevanten Tag" in der Liste — gesetzt vom ViewModel.
    /// Wird in der Übersicht als Badge dargestellt, damit User nicht denken, der
    /// erste Tag in der Liste sei automatisch der wichtigste (bei lunchOver-Phase).
    var isNextRelevantDay: Bool = false

    // MARK: - Identity & Equality

    var id: String {
        LunchDay.documentId(for: lunchDay.date)
    }

    static func == (lhs: DayViewModel, rhs: DayViewModel) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Convenience-Properties

    var date: Date { lunchDay.date }
    var isHoliday: Bool { lunchDay.isHoliday }
    var holidayName: String? { lunchDay.holidayName }
    var hasLunch: Bool { lunchDay.hasLunch }

    var attendingCount: Int { attendees.count }
    var totalCount: Int { allUsers.count }

    var currentUserAttending: Bool {
        attendees.contains { $0.id == currentUserId }
    }

    // MARK: - Phase-Properties (delegieren an LunchDay)

    var phase: DayPhase { lunchDay.phase }
    var phaseMessage: String? { lunchDay.phaseMessage }

    // MARK: - Zeitliche Einordnung

    var isToday: Bool {
        Calendar.current.isDateInToday(lunchDay.date)
    }

    var isPast: Bool {
        Calendar.current.startOfDay(for: lunchDay.date) < Calendar.current.startOfDay(for: Date())
    }
}
