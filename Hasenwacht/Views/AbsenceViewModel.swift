//
//  AbsenceViewModel.swift
//  Hasenwacht
//
//  Hält den reaktiven State für Abwesenheiten und stellt
//  Mutationsmethoden für die View bereit.
//

import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
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
        isLoading = true

        recurringListener?.remove()
        vacationListener?.remove()

        recurringListener = AbsenceService.shared.observeRecurring(userId: userId) { [weak self] absence in
            Task { @MainActor in
                self?.recurring = absence
                self?.isLoading = false
                LunchDaysViewModel.shared.onAbsenceChanged()
            }
        }

        vacationListener = AbsenceService.shared.observeVacations(userId: userId) { [weak self] vacations in
            Task { @MainActor in
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
        if updated.absentWeekdays.contains(weekday) {
            updated.absentWeekdays.removeAll { $0 == weekday }
        } else {
            updated.absentWeekdays.append(weekday)
        }
        recurring = updated // optimistic
        do {
            try await AbsenceService.shared.saveRecurring(userId: userId, absence: updated)
        } catch {
            errorMessage = "Konnte nicht gespeichert werden."
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
        } catch {
            errorMessage = "Ferien konnten nicht gespeichert werden."
        }
    }

    func deleteVacation(_ vacation: VacationAbsence) async {
        guard let id = vacation.id else { return }
        do {
            try await AbsenceService.shared.deleteVacation(id: id)
        } catch {
            errorMessage = "Löschen fehlgeschlagen."
        }
    }

    // MARK: - Absenz-Check (für LunchDaysViewModel)

    /// True wenn der User an diesem Datum durch eine Regel abwesend ist.
    /// Manuelle Attendance-Overrides werden im LunchDaysViewModel geprüft.
    func isAbsent(on date: Date) -> Bool {
        if recurring.isAbsent(on: date) { return true }
        return vacations.contains { $0.covers(date: date) }
    }
}
