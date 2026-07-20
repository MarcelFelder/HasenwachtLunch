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
    /// userId → abwesende ISO-Wochentage (1=Mo…5=Fr)
    private var recurringAbsences: [String: [Int]] = [:]
    private var currentUserId: String = ""

    /// Zählt wie viele der 3 Listener mindestens einmal gefeuert haben.
    /// rebuildDays() wird erst aufgerufen wenn alle 3 bereit sind.
    private var readyListeners: Set<String> = []
    private var allListenersReady: Bool { readyListeners.count >= 3 }

    private let holidayService = HolidayService()
    
    /// Anzahl Wochen in die Zukunft ab heute.
    private let futureWeeks = 5

    /// Berechnet den frühesten Montag basierend auf dem Installations-Datum.
    /// Mindestens 2 Wochen zurück, maximal ab Installationsdatum.
    static func earliestMonday() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current

        let installDate = OnboardingService.shared.firstAppUseDate

        // Finde den Montag der Installationswoche
        let weekday = calendar.component(.weekday, from: installDate)
        let daysSinceMonday = weekday == 1 ? 6 : weekday - 2
        let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: installDate) ?? installDate
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: monday) ?? monday
    }

    /// Anzahl Wochen von earliestMonday bis +futureWeeks ab heute.
    static func totalWeekCount() -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let earliest = earliestMonday()
        let currentMonday = mondayOfCurrentWeek(using: calendar)
        let weeksPast = calendar.dateComponents([.weekOfYear], from: earliest, to: currentMonday).weekOfYear ?? 0
        return weeksPast + 6 // vergangene Wochen + diese Woche + 5 Zukunft
    }

    /// Offset der aktuellen Woche innerhalb des Gesamtfensters.
    static func currentWeekOffset() -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let earliest = earliestMonday()
        let currentMonday = mondayOfCurrentWeek(using: calendar)
        return calendar.dateComponents([.weekOfYear], from: earliest, to: currentMonday).weekOfYear ?? 0
    }

    private var usersListener: ListenerRegistration?
    private var attendancesListener: ListenerRegistration?
    private var lunchDaysListener: ListenerRegistration?
    private var recurringAbsencesListener: ListenerRegistration?
    
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

    /// Wird vom AbsenceViewModel aufgerufen wenn sich Abwesenheiten ändern.
    /// Löst einen Rebuild aus damit die Tagesansicht sofort aktualisiert wird.
    func onAbsenceChanged() {
        rebuildDays()
    }

    /// Löst einen Rebuild aus wenn Kinder/Overrides sich geändert haben.
    func onChildrenChanged() {
        rebuildDays()
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
        startRecurringAbsencesListener()
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
        recurringAbsencesListener?.remove()
        recurringAbsencesListener = nil
        phaseUpdateTimer?.invalidate()
        phaseUpdateTimer = nil
        days = []
        allUsers = []
        attendances = []
        lunchDays = []
        isLoading = true
        readyListeners = []
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
                self.readyListeners.insert("users")
                if self.allListenersReady { self.rebuildDays() }
            }
        }
    }

    private func startAttendancesListener() {
        let workdays = Self.nextWorkdays()
        guard let firstDate = workdays.first,
              let lastDate = workdays.last else { return }

        attendancesListener = AttendanceService.shared.observeAttendances(
            from: firstDate,
            to: lastDate
        ) { [weak self] attendances in
            guard let self else { return }
            Task { @MainActor in
                self.attendances = attendances
                self.readyListeners.insert("attendances")
                if self.allListenersReady { self.rebuildDays() }
            }
        }
    }
    
    private func startLunchDaysListener() {
        let workdays = Self.nextWorkdays()
        guard let firstDate = workdays.first,
              let lastDate = workdays.last else { return }

        lunchDaysListener = LunchDayService.shared.observeLunchDays(
            from: firstDate,
            to: lastDate
        ) { [weak self] lunchDays in
            guard let self else { return }
            Task { @MainActor in
                self.lunchDays = lunchDays
                self.readyListeners.insert("lunchDays")
                if self.allListenersReady { self.rebuildDays() }
            }
        }
    }

    private func startRecurringAbsencesListener() {
        let db = Firestore.firestore()
        recurringAbsencesListener = db.collection("recurringAbsences")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                // DocumentID = userId, Inhalt = absentWeekdays
                var map: [String: [Int]] = [:]
                for doc in snapshot?.documents ?? [] {
                    if let absence = try? doc.data(as: RecurringAbsence.self) {
                        map[doc.documentID] = absence.absentWeekdays
                    }
                }
                Task { @MainActor in
                    self.recurringAbsences = map
                    if self.allListenersReady { self.rebuildDays() }
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
        let workdays = Self.nextWorkdays()
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

        let holiday = holidayService.holiday(for: date)
        let lunchDayOverride = lunchDays.first { calendar.isDate($0.date, inSameDayAs: date) }
        let forceLunch = lunchDayOverride?.forceLunch ?? false
        let isLunchHappening = (holiday == nil) || forceLunch

        let attendancesForDay = attendances.filter { calendar.isDate($0.date, inSameDayAs: date) }

        // Opt-Out-UserIds aus expliziten Attendance-Dokumenten (isAttending=false)
        let explicitOptOuts = Set(
            attendancesForDay
                .filter { !$0.isAttending }
                .map { $0.userId }
        )
        // Explizit angemeldete User (isAttending=true) — überschreiben Absenz-Regeln
        let explicitOptIns = Set(
            attendancesForDay
                .filter { $0.isAttending }
                .map { $0.userId }
        )

        // Wiederkehrende Absenzen direkt auswerten (robust auch ohne Attendance-Dokument)
        let appleWeekday = calendar.component(.weekday, from: date)
        let isoWeekday = appleWeekday == 1 ? 7 : appleWeekday - 1
        let recurringOptOuts = Set(
            recurringAbsences
                .filter { _, weekdays in weekdays.contains(isoWeekday) }
                .map { userId, _ in userId }
        )

        // Zusammenführen: recurring + explicit opt-outs, minus explicit opt-ins
        let optedOutUserIds = (explicitOptOuts.union(recurringOptOuts)).subtracting(explicitOptIns)

        let attendees: [User]
        let absentees: [User]

        let isCancelled = lunchDayOverride?.isCancelled ?? false

        if isLunchHappening && !isCancelled {
            attendees = allUsers.filter { user in
                guard let userId = user.id else { return false }
                return !optedOutUserIds.contains(userId)
            }
            absentees = allUsers.filter { user in
                guard let userId = user.id else { return false }
                return optedOutUserIds.contains(userId)
            }
        } else {
            attendees = []
            absentees = allUsers
        }

        var lunchDay = LunchDay(
            id: lunchDayOverride?.id,
            date: date,
            isHoliday: holiday != nil,
            holidayName: holiday?.name,
            forceLunch: forceLunch,
            activatedBy: lunchDayOverride?.activatedBy
        )
        lunchDay.isCancelled = isCancelled
        lunchDay.cancelledBy = lunchDayOverride?.cancelledBy

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
    /// Manuelle Anmeldung überschreibt eine aktive Absenz für diesen Tag.
    func toggleAttendance(for date: Date) async {
        if LunchDay.phase(for: date, now: Date()) != .bookable { return }

        let isCurrentlyAttending = days
            .first { Calendar.current.isDate($0.date, inSameDayAs: date) }?
            .currentUserAttending ?? true

        do {
            try await AttendanceService.shared.setAttendance(
                userId: currentUserId,
                date: date,
                isAttending: !isCurrentlyAttending
            )
            // Reminder neu planen, damit eine bereits eingeplante Push für diesen
            // Tag entfällt, falls der User sich soeben ausgetragen hat (und umgekehrt).
            await NotificationService.shared.rescheduleReminders()
        } catch {
            await MainActor.run {
                errorMessage = "Status konnte nicht aktualisiert werden: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Override-Aktion

    /// Aktiviert das Mittagessen an einem Feiertag.
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

    /// Deaktiviert das Mittagessen an einem Feiertag (nur durch den der es aktiviert hat).
    func deactivateLunchForHoliday(date: Date) async {
        do {
            try await LunchDayService.shared.deactivateLunch(for: date)
        } catch {
            await MainActor.run {
                errorMessage = "Mittagessen konnte nicht deaktiviert werden: \(error.localizedDescription)"
            }
        }
    }

    /// Streicht einen Tag (kein Mittagessen). Nur erlaubt wenn User dabei ist.
    func cancelLunch(date: Date) async {
        guard !currentUserId.isEmpty else { return }
        do {
            try await LunchDayService.shared.cancelLunch(for: date, userId: currentUserId)
        } catch {
            await MainActor.run {
                errorMessage = "Tag konnte nicht gestrichen werden: \(error.localizedDescription)"
            }
        }
    }

    /// Hebt die Streichung auf (nur durch den der gestrichen hat).
    func uncancelLunch(date: Date) async {
        do {
            try await LunchDayService.shared.uncancelLunch(for: date)
        } catch {
            await MainActor.run {
                errorMessage = "Tag konnte nicht aktiviert werden: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Datum-Helper

    /// Erzeugt alle Werktage im gesamten Fenster (Installationsdatum bis +5 Wochen).
    ///
    /// Wichtig: Es gibt hier bewusst KEIN Zähl-Limit. Der Bereich ist durch
    /// `futureEnd` bereits exakt begrenzt (aktuelle Woche + 10 Wochen Puffer).
    /// Ein zusätzliches hartes Limit (z.B. "max. 300 Tage") ist gefährlich:
    /// da `earliestMonday()` am Installationsdatum fixiert ist und `futureEnd`
    /// mit der Zeit weiterwandert, würde ein solches Limit nach einigen Monaten
    /// Nutzung erreicht, BEVOR die Schleife den heutigen Tag erreicht — die
    /// App würde dann keine aktuellen/zukünftigen Tage mehr anzeigen.
    static func nextWorkdays() -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        var dates: [Date] = []
        var current = earliestMonday()

        // Endpunkt: Freitag der Woche currentMonday + 10 Wochen (Puffer über max sichtbare +5)
        let currentMonday = mondayOfCurrentWeek(using: calendar)
        guard let futureEnd = calendar.date(byAdding: .weekOfYear, value: 10, to: currentMonday) else {
            return []
        }

        while current <= futureEnd {
            let weekday = calendar.component(.weekday, from: current)
            if weekday >= 2 && weekday <= 6 {
                dates.append(current)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return dates
    }

    /// Gibt die 5 Wochentage (Mo–Fr) für den angegebenen absoluten Wochenoffset zurück.
    /// offset 0 = früheste Woche (Installationswoche), currentWeekOffset() = diese Woche.
    static func weekDates(offset: Int) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let monday = earliestMonday()
        guard let targetMonday = calendar.date(byAdding: .weekOfYear, value: offset, to: monday) else {
            return []
        }
        return (0..<5).compactMap { i in
            calendar.date(byAdding: .day, value: i, to: targetMonday)
        }
    }

    /// Liefert die DayViewModels für eine bestimmte Woche (absoluter offset ab earliestMonday).
    func days(forWeekOffset offset: Int) -> [DayViewModel] {
        let targetDates = Self.weekDates(offset: offset)
        let calendar = Calendar.current
        let installDate = calendar.startOfDay(for: OnboardingService.shared.firstAppUseDate)

        return targetDates.map { date in
            if let match = days.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                return match
            }
            // Tag liegt vor App-Installation → keine Daten verfügbar
            let dayStart = calendar.startOfDay(for: date)
            let isBeforeInstall = dayStart < installDate

            let lunchDay = LunchDay(
                id: nil, date: date,
                isHoliday: false, holidayName: nil,
                forceLunch: false, activatedBy: nil
            )
            return DayViewModel(
                lunchDay: lunchDay,
                attendees: isBeforeInstall ? [] : allUsers,
                absentees: [],
                allUsers: allUsers,
                currentUserId: currentUserId,
                hasNoData: isBeforeInstall
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
