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
            // Beim ersten Laden: fehlende Opt-Out Attendances für wiederkehrende Wochentage nachschreiben
            Task { [weak self] in
                await self?.repairMissingRecurringAttendances(absence: absence)
            }
        }

        vacationListener = AbsenceService.shared.observeVacations(userId: userId) { [weak self] vacations in
            DispatchQueue.main.async {
                self?.vacations = vacations
                LunchDaysViewModel.shared.onAbsenceChanged()
            }
            // Beim ersten Laden: fehlende Attendances für aktive Ferien nachschreiben
            // (Repair für User die vom Cutoff-Bug betroffen waren)
            Task { [weak self] in
                await self?.repairMissingVacationAttendances(vacations: vacations)
            }
        }
    }

    /// Repariert fehlende Attendance-Dokumente für bestehende Ferien.
    /// Wird beim Start einmal pro Ferienperiode ausgeführt.
    private var hasRepaired = false
    private func repairMissingVacationAttendances(vacations: [VacationAbsence]) async {
        guard !hasRepaired, !userId.isEmpty, !vacations.isEmpty else { return }
        hasRepaired = true

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let today = cal.startOfDay(for: Date())

        // Alle Werktage in laufenden/zukünftigen Ferien sammeln
        var datesToOptOut: [Date] = []
        for vacation in vacations {
            let endDay = cal.startOfDay(for: vacation.endDate)
            // Nur Ferien die noch nicht vorbei sind
            guard endDay >= today else { continue }

            let dates = bookableDatesInRange(from: vacation.startDate, to: vacation.endDate)
                .filter { cal.startOfDay(for: $0) >= today } // nur ab heute reparieren
            datesToOptOut.append(contentsOf: dates)
        }

        guard !datesToOptOut.isEmpty else { return }

        do {
            try await AttendanceService.shared.batchSetAttendances(
                userId: userId,
                dates: datesToOptOut,
                isAttending: false
            )
        } catch {
            // Stille Reparatur — wenn sie scheitert ist es kein User-Fehler
        }
    }

    func stop() {
        recurringListener?.remove()
        vacationListener?.remove()
        recurringListener = nil
        vacationListener = nil
        userId = ""
        hasRepaired = false
        hasRepairedRecurring = false
    }

    /// Repariert fehlende Opt-Out Attendances für wiederkehrende Absenzen.
    /// Läuft einmal pro Session — schreibt für alle zukünftigen Occurrences
    /// der abgespeicherten Wochentage ein Opt-Out Attendance-Dokument.
    private var hasRepairedRecurring = false
    private func repairMissingRecurringAttendances(absence: RecurringAbsence) async {
        guard !hasRepairedRecurring, !userId.isEmpty else { return }
        guard !absence.absentWeekdays.isEmpty else { return }
        hasRepairedRecurring = true

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let today = cal.startOfDay(for: Date())

        // Alle zukünftigen Werktage im Fenster sammeln die einem abwesenden Wochentag entsprechen
        let allWorkdays = LunchDaysViewModel.nextWorkdays()
        let datesToOptOut = allWorkdays.filter { date in
            guard cal.startOfDay(for: date) >= today else { return false }
            let appleWeekday = cal.component(.weekday, from: date)
            let iso = appleWeekday == 1 ? 7 : appleWeekday - 1
            return absence.absentWeekdays.contains(iso)
        }

        guard !datesToOptOut.isEmpty else { return }

        do {
            try await AttendanceService.shared.batchSetAttendances(
                userId: userId,
                dates: datesToOptOut,
                isAttending: false
            )
        } catch {
            // Stille Reparatur
        }
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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let today = calendar.startOfDay(for: Date())
        return LunchDaysViewModel.nextWorkdays(count: 200).filter { date in
            // Nur ab heute (vergangene Tage nicht überschreiben)
            guard calendar.startOfDay(for: date) >= today else { return false }
            // ISO-Wochentag prüfen
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

    /// Alle Werktage zwischen zwei Daten (inklusiv).
    /// Cutoff wird hier ignoriert — Ferien werden für alle Werktage im Zeitraum
    /// als abgemeldet markiert, auch wenn sie schon vergangen sind oder im Cutoff liegen.
    private func bookableDatesInRange(from start: Date, to end: Date) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end)
        var result: [Date] = []
        var current = s
        while current <= e {
            let weekday = cal.component(.weekday, from: current)
            if weekday >= 2 && weekday <= 6 { // Mo–Fr
                result.append(cal.date(bySettingHour: 12, minute: 0, second: 0, of: current) ?? current)
            }
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return result
    }

    // MARK: - Absenz-Check (für LunchDaysViewModel)

    func isAbsent(on date: Date) -> Bool {
        if recurring.isAbsent(on: date) { return true }
        return vacations.contains { $0.covers(date: date) }
    }
}
