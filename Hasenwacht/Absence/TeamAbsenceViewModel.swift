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
            return "Ferien bis \(Self.vacationEndFormatter.string(from: v.endDate))"
        case .recurring(let iso):
            let days = ["Montag","Dienstag","Mittwoch","Donnerstag","Freitag"]
            return "Jeden \(days[iso - 1])"
        }
    }

    var isVacation: Bool {
        if case .vacation = self { return true }
        return false
    }

    /// Gecacht statt pro Aufruf neu erzeugt — DateFormatter-Instanzierung ist teuer
    /// und `label` wird pro sichtbarer Zeile in der Abgemeldet-Liste aufgerufen.
    private static let vacationEndFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_CH")
        df.dateFormat = "d. MMM"
        df.timeZone = TimeZone(identifier: "Europe/Zurich")
        return df
    }()
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

    /// Startet alle drei Listener (User, Ferien, wiederkehrende Absenzen) reaktiv.
    /// Braucht keine extern geladene Userliste mehr — beobachtet die
    /// "users"-Collection selbst, genau wie LunchDaysViewModel.
    func start() {
        isLoading = true
        stopListeners()
        startUsersListener()
        startVacationsListener()
        startRecurringListener()
    }

    func stop() {
        stopListeners()
        allUsers = []
        allVacations = []
        recurringMap = [:]
        teamAbsences = []
        isLoading = true
    }

    private func stopListeners() {
        listeners.forEach { $0.remove() }
        listeners = []
    }

    // MARK: - Listeners

    private func startUsersListener() {
        let l = UserService.shared.observeAllUsers { [weak self] users in
            guard let self else { return }
            self.allUsers = users
            self.rebuild()
        }
        listeners.append(l)
    }

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

    /// EIN Listener auf die gesamte Collection statt einem Listener pro User —
    /// deckt exakt dieselben Daten ab, die LunchDaysViewModel bereits separat
    /// abonniert, aber ohne für jeden Team-Mitglied einen eigenen offenen
    /// Firestore-Listener zu benötigen.
    private func startRecurringListener() {
        let l = db.collection("recurringAbsences")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                var map: [String: [Int]] = [:]
                for doc in snapshot?.documents ?? [] {
                    if let absence = try? doc.data(as: RecurringAbsence.self) {
                        map[doc.documentID] = absence.absentWeekdays
                    }
                }
                self.recurringMap = map
                self.rebuild()
            }
        listeners.append(l)
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
        return "\(cal.component(.day, from: first)). – \(cal.component(.day, from: last)). \(Self.monthFormatter.string(from: last))"
    }

    private static let monthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_CH")
        df.dateFormat = "MMMM"
        return df
    }()
}
