//
//  LunchDaysViewModel.swift
//  Hasenwacht
//
//  ViewModel für die Tagesübersicht.
//  Hält reaktive Listener auf User und Attendances und stellt eine
//  fertige Liste von DayViewModels für die View bereit.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import Combine

final class LunchDaysViewModel: ObservableObject {

    // MARK: - Singleton

    static let shared = LunchDaysViewModel()

    // MARK: - Reaktiver State

    @Published var days: [DayViewModel] = []
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?

    // MARK: - Privater State
    
    private var allUsers: [User] = []
    private var attendances: [Attendance] = []
    private var lunchDays: [LunchDay] = []
    private var currentUserId: String = ""

    private let holidayService = HolidayService()
    
    /// Anzahl Werktage, die in der Tagesübersicht angezeigt werden.
    private let workdayWindowSize = 12

    private var usersListener: ListenerRegistration?
    private var attendancesListener: ListenerRegistration?
    private var lunchDaysListener: ListenerRegistration?

    // MARK: - Init

    private init() {}
    
    /// Aktualisiert die UserId nachträglich. Nötig, weil die View das
    /// ViewModel bei der Initialisierung noch nicht mit der echten UID kennt.
    func updateUserId(_ userId: String) {
        self.currentUserId = userId
    }

    // MARK: - Lifecycle

    /// Startet die Listener für User und Attendances.
    func start() {
        // Falls schon gestartet, erst stoppen, damit keine Doppel-Listener entstehen
        stop()
        isLoading = true
        startUsersListener()
        startAttendancesListener()
        startLunchDaysListener()
    }

    /// Stoppt die Listener. Wichtig beim Verlassen des Screens, sonst Memory-Leak.
    func stop() {
        usersListener?.remove()
        usersListener = nil
        attendancesListener?.remove()
        attendancesListener = nil
        lunchDaysListener?.remove()
        lunchDaysListener = nil
        days = []
        allUsers = []
        attendances = []
        lunchDays = []
        isLoading = true
    }

    deinit {
        stop()
    }

    // MARK: - Listener

    private func startUsersListener() {
        usersListener = UserService.shared.observeAllUsers { [weak self] users in
            guard let self else { return }
            Task { @MainActor in
                self.allUsers = users
                self.rebuildDays()
            }
        }
    }

    private func startAttendancesListener() {
        let workdays = Self.nextWorkdays(count: workdayWindowSize)
        guard let firstDate = workdays.first,
              let lastDate = workdays.last else { return }

        attendancesListener = AttendanceService.shared.observeAttendances(
            from: firstDate,
            to: lastDate
        ) { [weak self] attendances in
            guard let self else { return }
            for att in attendances {
            }
            Task { @MainActor in
                self.attendances = attendances
                self.rebuildDays()
            }
        }
    }
    
    private func startLunchDaysListener() {
        let workdays = Self.nextWorkdays(count: workdayWindowSize)
        guard let firstDate = workdays.first,
              let lastDate = workdays.last else { return }

        lunchDaysListener = LunchDayService.shared.observeLunchDays(
            from: firstDate,
            to: lastDate
        ) { [weak self] lunchDays in
            guard let self else { return }
            Task { @MainActor in
                self.lunchDays = lunchDays
                self.rebuildDays()
            }
        }
    }

    // MARK: - Day-Berechnung

    /// Baut die DayViewModels aus den aktuellen User- und Attendance-Daten neu auf.
    private func rebuildDays() {
        let workdays = Self.nextWorkdays(count: workdayWindowSize)
        let newDays = workdays.map { date in
            buildDayViewModel(for: date)
        }
        Task { @MainActor in
            self.days = newDays
            self.isLoading = false
            for day in newDays {
            }
        }
    }

    private func buildDayViewModel(for date: Date) -> DayViewModel {
        let calendar = Calendar.current

        // 1. Feiertag-Info zuerst bestimmen — sie beeinflusst alles weitere.
        let holiday = holidayService.holiday(for: date)

        // 2. Override aus Firestore prüfen: Wurde dieser Tag manuell aktiviert?
        let lunchDayOverride = lunchDays.first { entry in
            calendar.isDate(entry.date, inSameDayAs: date)
        }
        let forceLunch = lunchDayOverride?.forceLunch ?? false

        // 3. Findet überhaupt Mittagessen statt?
        //    Normaler Werktag: ja. Feiertag: nur wenn forceLunch.
        let isLunchHappening = (holiday == nil) || forceLunch

        // 4. Attendances für diesen Tag filtern.
        let attendancesForDay = attendances.filter { attendance in
            calendar.isDate(attendance.date, inSameDayAs: date)
        }

        let optedOutUserIds = Set(
            attendancesForDay
                .filter { !$0.isAttending }
                .map { $0.userId }
        )

        // 5. Teilnehmerlisten aufbauen.
        let attendees: [User]
        let absentees: [User]

        if isLunchHappening {
            attendees = allUsers.filter { user in
                guard let userId = user.id else { return false }
                return !optedOutUserIds.contains(userId)
            }
            absentees = allUsers.filter { user in
                guard let userId = user.id else { return false }
                return optedOutUserIds.contains(userId)
            }
        } else {
            // Feiertag ohne forceLunch: niemand isst.
            attendees = []
            absentees = allUsers
        }

        // 6. LunchDay-Objekt zusammenbauen.
        let lunchDay = LunchDay(
            id: lunchDayOverride?.id,
            date: date,
            isHoliday: holiday != nil,
            holidayName: holiday?.name,
            forceLunch: forceLunch,
            activatedBy: lunchDayOverride?.activatedBy
        )

        return DayViewModel(
            lunchDay: lunchDay,
            attendees: attendees,
            absentees: absentees,
            allUsers: allUsers,
            currentUserId: currentUserId
        )
    }

    // MARK: - Toggle-Aktion

    /// Wechselt den Anwesenheitsstatus des aktuellen Users für den gegebenen Tag.
    func toggleAttendance(for date: Date) async {
        // Defense in Depth: UI sollte den Tap schon blockieren, aber wir
        // verifizieren hier nochmal, falls jemand z.B. via Notification rein kommt.
        if LunchDay.isLocked(for: date, now: Date()) {
            return
        }

        let isCurrentlyAttending = days
            .first { Calendar.current.isDate($0.date, inSameDayAs: date) }?
            .currentUserAttending ?? true

        do {
            try await AttendanceService.shared.setAttendance(
                userId: currentUserId,
                date: date,
                isAttending: !isCurrentlyAttending
            )
        } catch {
            await MainActor.run {
                errorMessage = "Status konnte nicht aktualisiert werden: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Override-Aktion

    /// Aktiviert das Mittagessen an einem Feiertag.
    /// Schreibt ein lunchDays-Dokument mit forceLunch = true.
    func activateLunchForHoliday(date: Date) async {
        let holiday = holidayService.holiday(for: date)

        do {
            try await LunchDayService.shared.activateLunch(
                for: date,
                userId: currentUserId,
                holidayName: holiday?.name
            )
        } catch {
            await MainActor.run {
                errorMessage = "Mittagessen konnte nicht aktiviert werden: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Datum-Helper

    /// Erzeugt die nächsten n Werktage ab heute, mit Datum auf 12:00 Uhr normalisiert.
    /// Die Normalisierung ist wichtig für stabile Firestore-Queries und Vergleiche.
    static func nextWorkdays(count: Int) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var current = calendar.startOfDay(for: Date())

        // Auf 12:00 Uhr setzen, um Zeitzonen-Probleme zu minimieren
        current = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: current) ?? current

        while dates.count < count {
            let weekday = calendar.component(.weekday, from: current)
            // 1=Sonntag, 7=Samstag → Werktage sind 2..6
            if weekday >= 2 && weekday <= 6 {
                dates.append(current)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return dates
    }
}
