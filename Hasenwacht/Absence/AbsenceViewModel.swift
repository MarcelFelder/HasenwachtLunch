//
//  AbsenceViewModel.swift
//  Hasenwacht
//
//  Hält den reaktiven State für Abwesenheiten und stellt
//  Mutationsmethoden für die View bereit.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore

final class AbsenceViewModel: ObservableObject {

    static let shared = AbsenceViewModel()

    @Published var recurring = RecurringAbsence()
    @Published var vacations: [VacationAbsence] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var userId: String = ""
    private var recurringListener: ListenerRegistration?
    private var vacationListener: ListenerRegistration?

    private init() {}

    // MARK: - Lifecycle

    func start(userId: String) {
        guard !userId.isEmpty, userId != self.userId else { return }
        self.userId = userId

        DispatchQueue.main.async { self.isLoading = true }

        recurringListener?.remove()
        vacationListener?.remove()

        recurringListener = AbsenceService.shared.observeRecurring(userId: userId) { [weak self] absence in
            DispatchQueue.main.async {
                self?.recurring = absence
                self?.isLoading = false
                LunchDaysViewModel.shared.onAbsenceChanged()
            }
        }

        vacationListener = AbsenceService.shared.observeVacations(userId: userId) { [weak self] vacations in
            DispatchQueue.main.async {
                self?.vacations = vacations
                LunchDaysViewModel.shared.onAbsenceChanged()
            }
        }
    }

    func stop() {
        recurringListener?.remove()
        vacationListener?.remove()
        recurringListener = nil
        vacationListener = nil
        userId = ""
    }

    // MARK: - Recurring

    func toggleWeekday(_ weekday: Int) async {
        var updated = recurring
        let wasAbsent = updated.absentWeekdays.contains(weekday)

        if wasAbsent {
            updated.absentWeekdays.removeAll { $0 == weekday }
        } else {
            updated.absentWeekdays.append(weekday)
        }

        // Optimistic UI update
        await MainActor.run { self.recurring = updated }

        // Alle bookable Tage im Fenster bestimmen die diesen Wochentag haben
        let affectedDates = bookableDatesForWeekday(weekday)

        do {
            // 1. Absenz-Regel speichern
            try await AbsenceService.shared.saveRecurring(userId: userId, absence: updated)

            if wasAbsent {
                // Absenz entfernt → Attendance-Dokumente löschen damit Default (angemeldet) gilt
                // Nur Dokumente löschen die durch die Absenz-Regel gesetzt wurden (isAttending=false)
                // Manuell gesetzte "true"-Dokumente bleiben unangetastet
                try await AttendanceService.shared.batchDeleteAttendances(userId: userId, dates: affectedDates)
            } else {
                // Absenz gesetzt → für alle betroffenen bookable Tage als abgemeldet schreiben
                try await AttendanceService.shared.batchSetAttendances(userId: userId, dates: affectedDates, isAttending: false)
            }
        } catch {
            // Rollback bei Fehler
            await MainActor.run {
                self.recurring = recurring
                self.errorMessage = "Konnte nicht gespeichert werden."
            }
        }
    }

    /// Liefert alle bookable Werktage im Lade-Fenster (3 Wochen) die dem ISO-Wochentag entsprechen.
    private func bookableDatesForWeekday(_ isoWeekday: Int) -> [Date] {
        LunchDaysViewModel.nextWorkdays(count: 200).filter { date in
            // Nur bookable Tage (nicht gesperrt)
            guard LunchDay.phase(for: date, now: Date()) == .bookable else { return false }
            // ISO-Wochentag prüfen
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
            let appleWeekday = calendar.component(.weekday, from: date)
            let iso = appleWeekday == 1 ? 7 : appleWeekday - 1
            return iso == isoWeekday
        }
    }

    // MARK: - Vacation

    func addVacation(startDate: Date, endDate: Date, name: String?) async {
        let vacation = VacationAbsence(
            userId: userId,
            startDate: startDate,
            endDate: endDate,
            name: name
        )
        do {
            try await AbsenceService.shared.addVacation(vacation)
            // Alle bookable Werktage im Ferienzeitraum als abgemeldet schreiben
            let affected = bookableDatesInRange(from: startDate, to: endDate)
            if !affected.isEmpty {
                try await AttendanceService.shared.batchSetAttendances(
                    userId: userId, dates: affected, isAttending: false
                )
            }
        } catch {
            print("❌ addVacation failed: \(error)")
            await MainActor.run { self.errorMessage = "Ferien konnten nicht gespeichert werden: \(error.localizedDescription)" }
        }
    }

    func deleteVacation(_ vacation: VacationAbsence) async {
        guard let id = vacation.id else { return }
        do {
            try await AbsenceService.shared.deleteVacation(id: id)
            // Attendance-Dokumente für betroffene Tage löschen
            // (nur wenn kein anderer Absenzgrund für diesen Tag gilt)
            let affected = bookableDatesInRange(from: vacation.startDate, to: vacation.endDate)
                .filter { date in
                    // Nicht löschen wenn ein wiederkehrender Wochentag noch aktiv ist
                    !recurring.isAbsent(on: date)
                }
            if !affected.isEmpty {
                try await AttendanceService.shared.batchDeleteAttendances(userId: userId, dates: affected)
            }
        } catch {
            await MainActor.run { self.errorMessage = "Löschen fehlgeschlagen." }
        }
    }

    /// Alle bookable Werktage zwischen zwei Daten (inklusiv).
    private func bookableDatesInRange(from start: Date, to end: Date) -> [Date] {
        LunchDaysViewModel.nextWorkdays(count: 200).filter { date in
            guard LunchDay.phase(for: date, now: Date()) == .bookable else { return false }
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
            let day = cal.startOfDay(for: date)
            let s   = cal.startOfDay(for: start)
            let e   = cal.startOfDay(for: end)
            return day >= s && day <= e
        }
    }

    // MARK: - Absenz-Check (für LunchDaysViewModel)

    func isAbsent(on date: Date) -> Bool {
        if recurring.isAbsent(on: date) { return true }
        return vacations.contains { $0.covers(date: date) }
    }
}
