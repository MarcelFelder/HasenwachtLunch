//
//  TeamAbsenceViewModel.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 19.05.2026.
//
//  Lädt alle Abwesenheiten aller User für die Team-Übersicht (Gantt).
//

import Foundation
import Combine
import FirebaseFirestore

struct UserAbsenceInfo: Identifiable {
    let user: User
    let vacations: [VacationAbsence]
    let recurringWeekdays: [Int] // 1=Mo…5=Fr

    var id: String { user.id ?? UUID().uuidString }

    /// Ist der User an diesem Datum abwesend?
    func isAbsent(on date: Date) -> Bool {
        let cal = Calendar.current
        // Ferien
        if vacations.contains(where: { $0.covers(date: date) }) { return true }
        // Wiederkehrend
        let appleWeekday = cal.component(.weekday, from: date)
        let iso = appleWeekday == 1 ? 7 : appleWeekday - 1
        return recurringWeekdays.contains(iso)
    }

    /// Warum fehlt der User an diesem Datum?
    func absenceReason(on date: Date) -> AbsenceReason? {
        if let v = vacations.first(where: { $0.covers(date: date) }) {
            return .vacation(v)
        }
        let cal = Calendar.current
        let appleWeekday = cal.component(.weekday, from: date)
        let iso = appleWeekday == 1 ? 7 : appleWeekday - 1
        if recurringWeekdays.contains(iso) {
            return .recurring(iso)
        }
        return nil
    }
}

enum AbsenceReason {
    case vacation(VacationAbsence)
    case recurring(Int) // ISO weekday

    var label: String {
        switch self {
        case .vacation(let v):
            let df = DateFormatter()
            df.locale = Locale(identifier: "de_CH")
            df.dateFormat = "d. MMM"
            df.timeZone = TimeZone(identifier: "Europe/Zurich")
            return "Ferien bis \(df.string(from: v.endDate))"
        case .recurring(let iso):
            let days = ["Montag","Dienstag","Mittwoch","Donnerstag","Freitag"]
            return "Jeden \(days[iso - 1])"
        }
    }

    var isVacation: Bool {
        if case .vacation = self { return true }
        return false
    }
}

final class TeamAbsenceViewModel: ObservableObject {

    static let shared = TeamAbsenceViewModel()

    @Published var teamAbsences: [UserAbsenceInfo] = []
    @Published var isLoading = true
    @Published var weekOffset = 0 // relativ zur aktuellen Woche

    private var db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    private var allUsers: [User] = []
    private var allVacations: [VacationAbsence] = []
    private var recurringMap: [String: [Int]] = [:] // userId → weekdays

    private init() {}

    func start(users: [User]) {
        guard !users.isEmpty else { return }
        allUsers = users
        isLoading = true
        stopListeners()
        startVacationsListener()
        startRecurringListeners(for: users)
    }

    func stop() {
        stopListeners()
        teamAbsences = []
        isLoading = true
    }

    private func stopListeners() {
        listeners.forEach { $0.remove() }
        listeners = []
    }

    // MARK: - Listeners

    private func startVacationsListener() {
        let l = db.collection("vacationAbsences")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                self.allVacations = snapshot?.documents.compactMap {
                    try? $0.data(as: VacationAbsence.self)
                } ?? []
                self.rebuild()
            }
        listeners.append(l)
    }

    private func startRecurringListeners(for users: [User]) {
        for user in users {
            guard let userId = user.id else { continue }
            let l = db.collection("recurringAbsences").document(userId)
                .addSnapshotListener { [weak self] snapshot, _ in
                    guard let self else { return }
                    if let absence = try? snapshot?.data(as: RecurringAbsence.self) {
                        self.recurringMap[userId] = absence.absentWeekdays
                    } else {
                        self.recurringMap[userId] = []
                    }
                    self.rebuild()
                }
            listeners.append(l)
        }
    }

    // MARK: - Rebuild

    private func rebuild() {
        teamAbsences = allUsers.compactMap { user -> UserAbsenceInfo? in
            guard let userId = user.id else { return nil }
            let userVacations = allVacations.filter { $0.userId == userId }
            let weekdays = recurringMap[userId] ?? []
            // Nur anzeigen wenn mindestens eine Abwesenheit vorhanden
            return UserAbsenceInfo(
                user: user,
                vacations: userVacations,
                recurringWeekdays: weekdays
            )
        }
        isLoading = false
    }

    // MARK: - Week dates for Gantt

    var currentWeekDates: [Date] {
        LunchDaysViewModel.weekDates(offset: LunchDaysViewModel.currentWeekOffset() + weekOffset)
    }

    var weekLabel: String {
        switch weekOffset {
        case 0:  return "Diese Woche"
        case 1:  return "Nächste Woche"
        case -1: return "Letzte Woche"
        case 2...: return "In \(weekOffset) Wochen"
        default: return "Vor \(abs(weekOffset)) Wochen"
        }
    }

    var weekDateRange: String {
        let dates = currentWeekDates
        guard let first = dates.first, let last = dates.last else { return "" }
        let cal = Calendar.current
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_CH")
        df.dateFormat = "MMMM"
        return "\(cal.component(.day, from: first)). – \(cal.component(.day, from: last)). \(df.string(from: last))"
    }
}
