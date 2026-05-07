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
    
    /// Anzahl Werktage, die im Fetch-Fenster gehalten werden (ab Montag der aktuellen Woche).
    /// 15 = 3 volle Wochen Mo–Fr.
    private let workdayWindowSize = 15

    private var usersListener: ListenerRegistration?
    private var attendancesListener: ListenerRegistration?
    private var lunchDaysListener: ListenerRegistration?
    
    /// Timer für periodische Phase-Aktualisierung.
    /// Notwendig, weil Phasenwechsel zeitbasiert sind (14:00, 12:15, Mitternacht) und SwiftUI sonst keinen Anlass zum Re-Render hat.
    private var phaseUpdateTimer: Timer?

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
        startPhaseUpdateTimer()
    }

    /// Stoppt die Listener. Wichtig beim Verlassen des Screens, sonst Memory-Leak.
    func stop() {
        usersListener?.remove()
        usersListener = nil
        attendancesListener?.remove()
        attendancesListener = nil
        lunchDaysListener?.remove()
        lunchDaysListener = nil
        phaseUpdateTimer?.invalidate()
        phaseUpdateTimer = nil
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
    
    /// Startet einen Timer, der jede Minute prüft, ob sich die Phase irgendeines Tages geändert hat. Wenn ja, wird rebuildDays() aufgerufen, damit SwiftUI die UI aktualisiert.
    ///
    /// Hintergrund: Phasen-Übergänge sind zeitbasiert (14:00, 12:15, Mitternacht). Ohne Timer würde die UI bis zum nächsten Datenwechsel oder App-Restart "eingefroren" bleiben.
    private func startPhaseUpdateTimer() {
        // Sofortiges Update nicht nötig — start() ruft eh schon rebuildDays() indirekt
        // über die Listener. Ab dann jede Minute.
        phaseUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: 60,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.rebuildDaysIfPhaseChanged()
            }
        }
    }

    /// Prüft, ob mindestens ein Tag in der Liste seine Phase geändert hat.
    /// Nur dann wird rebuildDays() ausgelöst — vermeidet unnötige UI-Updates.
    private func rebuildDaysIfPhaseChanged() {
        let now = Date()
        let phaseChanged = days.contains { day in
            let currentPhase = day.phase
            let freshPhase = LunchDay.phase(for: day.date, now: now)
            return currentPhase != freshPhase
        }

        if phaseChanged {
            rebuildDays()
        }
    }

    // MARK: - Day-Berechnung

    /// Baut die DayViewModels aus den aktuellen User- und Attendance-Daten neu auf.
    private func rebuildDays() {
        let workdays = Self.nextWorkdays(count: workdayWindowSize)
        var newDays = workdays.map { date in
            buildDayViewModel(for: date)
        }

        // "Nächstes Mittagessen" markieren = erster Tag, der noch bevorsteht.
        // Voraussetzung: heute selbst ist bereits in Phase .lunchOver, sonst
        // ist das Badge auf "morgen" sinnlos (heute ist ja noch der Lunch-Tag).
        let now = Date()
        if LunchDay.phase(for: now, now: now) == .lunchOver,
           let nextLunchIndex = newDays.firstIndex(where: { $0.phase != .lunchOver }) {
            newDays[nextLunchIndex].isNextRelevantDay = true
        }

        Task { @MainActor in
            self.days = newDays
            self.isLoading = false
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
        if LunchDay.phase(for: date, now: Date()) != .bookable {
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

    /// Erzeugt n Werktage ab Montag der aktuellen Woche, auf 12:00 Uhr normalisiert.
    /// Startet ab Montag (statt ab heute), damit vergangene Wochentage ebenfalls
    /// mit Attendance-Daten geladen werden und in der Übersicht angezeigt werden können.
    static func nextWorkdays(count: Int) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        var dates: [Date] = []
        var current = mondayOfCurrentWeek(using: calendar)

        while dates.count < count {
            let weekday = calendar.component(.weekday, from: current)
            if weekday >= 2 && weekday <= 6 {
                dates.append(current)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return dates
    }

    /// Gibt die 5 Wochentage (Mo–Fr) für den angegebenen Wochenoffset zurück.
    /// offset 0 = aktuelle Woche, 1 = nächste Woche, usw.
    static func weekDates(offset: Int) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let monday = mondayOfCurrentWeek(using: calendar)
        guard let targetMonday = calendar.date(byAdding: .weekOfYear, value: offset, to: monday) else {
            return []
        }
        return (0..<5).compactMap { i in
            calendar.date(byAdding: .day, value: i, to: targetMonday)
        }
    }

    /// Liefert die DayViewModels für eine bestimmte Woche (offset 0 = diese Woche).
    /// Tage, für die noch keine Daten geladen wurden, erhalten einen Platzhalter.
    func days(forWeekOffset offset: Int) -> [DayViewModel] {
        let targetDates = Self.weekDates(offset: offset)
        let calendar = Calendar.current
        return targetDates.map { date in
            if let match = days.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                return match
            }
            let lunchDay = LunchDay(
                id: nil, date: date,
                isHoliday: false, holidayName: nil,
                forceLunch: false, activatedBy: nil
            )
            return DayViewModel(
                lunchDay: lunchDay,
                attendees: allUsers,
                absentees: [],
                allUsers: allUsers,
                currentUserId: currentUserId
            )
        }
    }

    /// Berechnet den Montag der aktuellen Woche, auf 12:00 Uhr normalisiert.
    private static func mondayOfCurrentWeek(using calendar: Calendar) -> Date {
        let now = Date()
        let weekday = calendar.component(.weekday, from: now) // 1=So, 2=Mo … 7=Sa
        let daysSinceMonday = weekday == 1 ? 6 : weekday - 2
        let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: now) ?? now
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: monday) ?? monday
    }
}
