//
//  AttendanceTimelineProvider.swift
//  HasenwachtWidget
//
//  Reload-Strategie: Der Anmeldestatus ändert sich für den User nur an zwei
//  Zeitpunkten von selbst (ohne dass er etwas tut) — Mitternacht (neuer Tag
//  rutscht nach) und der 14:00-Cutoff (der bisher nächste buchbare Tag kann
//  gerade gesperrt werden, ein neuer rückt nach). Deshalb planen wir Reloads
//  gezielt auf diese beiden Zeitpunkte plus einen 6h-Sicherheits-Fallback,
//  statt das WidgetKit-Budget mit häufigeren Reloads zu strapazieren.
//

import WidgetKit
import Foundation

struct AttendanceTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> AttendanceEntry {
        if context.family == .systemLarge {
            return AttendanceEntry(date: Date(), state: .week(Self.placeholderWeek()))
        }
        return AttendanceEntry(
            date: Date(),
            state: .attendance(AttendanceDisplayState(
                date: LunchPhaseCalculator.nextBookableDate(),
                isAttending: true,
                phase: .bookable,
                holidayName: nil,
                isCancelled: false,
                isStale: true
            ))
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AttendanceEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task {
            if context.family == .systemLarge {
                completion(await Self.currentWeekEntry())
            } else {
                completion(await Self.currentEntry())
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AttendanceEntry>) -> Void) {
        Task {
            let entry = context.family == .systemLarge
                ? await Self.currentWeekEntry()
                : await Self.currentEntry()
            let timeline = Timeline(entries: [entry], policy: .after(Self.nextReloadDate()))
            completion(timeline)
        }
    }

    private static func placeholderWeek() -> [AttendanceDisplayState] {
        let dates = Self.currentWeekWorkdays()
        return dates.enumerated().map { index, date in
            AttendanceDisplayState(
                date: date,
                isAttending: index != 2,
                phase: .bookable,
                holidayName: nil,
                isCancelled: false,
                isStale: true
            )
        }
    }

    // MARK: - Entry-Aufbau

    static func currentEntry() async -> AttendanceEntry {
        guard SharedKeychain.load() != nil else {
            return AttendanceEntry(date: Date(), state: .loggedOut)
        }

        let targetDate = LunchPhaseCalculator.nextBookableDate()

        do {
            let displayState = try await fetchDisplayState(for: targetDate)
            let cache = SharedAttendanceCache(
                date: displayState.date,
                isAttending: displayState.isAttending,
                phase: displayState.phase,
                holidayName: displayState.holidayName,
                isCancelled: displayState.isCancelled,
                lastSyncedAt: Date(),
                lastErrorMessage: nil
            )
            cache.save()
            return AttendanceEntry(date: Date(), state: .attendance(displayState))
        } catch {
            return fallbackEntry(for: targetDate)
        }
    }

    /// Bei Netzwerk-/Token-Fehlern: letzten Cache-Stand zeigen, sofern er
    /// tatsächlich denselben Zieltag betrifft — sonst wäre er irreführend.
    private static func fallbackEntry(for targetDate: Date) -> AttendanceEntry {
        guard let cached = SharedAttendanceCache.load(),
              Calendar.current.isDate(cached.date, inSameDayAs: targetDate)
        else {
            return AttendanceEntry(date: Date(), state: .error("Keine Verbindung"))
        }

        let displayState = AttendanceDisplayState(
            date: cached.date,
            isAttending: cached.isAttending,
            phase: LunchPhaseCalculator.phase(for: cached.date, now: Date()),
            holidayName: cached.holidayName,
            isCancelled: cached.isCancelled,
            isStale: true
        )
        return AttendanceEntry(date: Date(), state: .attendance(displayState))
    }

    // MARK: - Remote-Status laden

    private static func fetchDisplayState(for date: Date) async throws -> AttendanceDisplayState {
        let idToken = try await FirebaseTokenRefresher.validIdToken()
        guard let userId = SharedKeychain.load()?.userId else {
            throw FirebaseTokenRefresher.TokenError.notSignedIn
        }

        let dateId = LunchPhaseCalculator.dayDocumentId(for: date)

        async let attendanceDoc = FirestoreRESTClient.getDocument(
            path: "attendances/\(userId)_\(dateId)", idToken: idToken
        )
        async let recurringDoc = FirestoreRESTClient.getDocument(
            path: "recurringAbsences/\(userId)", idToken: idToken
        )
        async let lunchDayDoc = FirestoreRESTClient.getDocument(
            path: "lunchDays/\(dateId)", idToken: idToken
        )

        let (attendance, recurring, lunchDay) = try await (attendanceDoc, recurringDoc, lunchDayDoc)

        let isAttending = resolveIsAttending(date: date, attendance: attendance, recurring: recurring)

        let forceLunch = lunchDay?["forceLunch"] as? Bool ?? false
        let isCancelled = lunchDay?["isCancelled"] as? Bool ?? false
        let localHoliday = HolidayService().holiday(for: date)
        let holidayName = (localHoliday != nil && !forceLunch) ? localHoliday?.name : nil

        return AttendanceDisplayState(
            date: date,
            isAttending: isAttending,
            phase: LunchPhaseCalculator.phase(for: date, now: Date()),
            holidayName: holidayName,
            isCancelled: isCancelled,
            isStale: false
        )
    }

    /// Default-Verhalten (siehe AttendanceService.swift): jeder ist angemeldet,
    /// ausser es existiert ein explizites Opt-out-Dokument ODER eine wiederkehrende
    /// Absenz für den Wochentag greift (und wurde nicht explizit überschrieben).
    /// `nonisolated`: reine Auswertung ohne UI-Bezug, wird u.a. aus den parallelen
    /// TaskGroup-Child-Tasks in `fetchWeekDisplayStates` aufgerufen.
    private nonisolated static func resolveIsAttending(
        date: Date,
        attendance: [String: Any]?,
        recurring: [String: Any]?
    ) -> Bool {
        if let explicit = attendance?["isAttending"] as? Bool {
            return explicit
        }
        if let weekdays = recurring?["absentWeekdays"] as? [Int] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
            let appleWeekday = calendar.component(.weekday, from: date)
            let isoWeekday = appleWeekday == 1 ? 7 : appleWeekday - 1
            return !weekdays.contains(isoWeekday)
        }
        return true
    }

    // MARK: - Wochenansicht (systemLarge)

    static func currentWeekEntry() async -> AttendanceEntry {
        guard SharedKeychain.load() != nil else {
            return AttendanceEntry(date: Date(), state: .loggedOut)
        }

        do {
            let states = try await fetchWeekDisplayStates(for: Self.currentWeekWorkdays())
            return AttendanceEntry(date: Date(), state: .week(states))
        } catch {
            // Keine mehrtägige Cache-Fallback-Variante (anders als bei .attendance) —
            // bei Fehlern lieber "offline" zeigen als veraltete/unvollständige Wochentage.
            return AttendanceEntry(date: Date(), state: .error("Keine Verbindung"))
        }
    }

    /// Mo–Fr dieser Woche; an Sa/So bereits die Folgewoche — identische Logik zum
    /// Wochen-Switcher im Mittagessen-Tab der App (`LunchOverviewView`).
    static func currentWeekWorkdays(now: Date = Date()) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current

        let weekday = calendar.component(.weekday, from: now) // 1=So...7=Sa
        let isWeekend = weekday == 1 || weekday == 7
        let daysSinceMonday = weekday == 1 ? 6 : weekday - 2

        guard var monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: now) else { return [] }
        monday = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: monday) ?? monday
        if isWeekend {
            monday = calendar.date(byAdding: .day, value: 7, to: monday) ?? monday
        }

        return (0..<5).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    /// Lädt attendance + lunchDay für jeden Tag parallel (eine `recurringAbsences`-
    /// Abfrage reicht für die ganze Woche, die ändert sich nicht pro Tag).
    private static func fetchWeekDisplayStates(for dates: [Date]) async throws -> [AttendanceDisplayState] {
        let idToken = try await FirebaseTokenRefresher.validIdToken()
        guard let userId = SharedKeychain.load()?.userId else {
            throw FirebaseTokenRefresher.TokenError.notSignedIn
        }

        let recurring = try await FirestoreRESTClient.getDocument(
            path: "recurringAbsences/\(userId)", idToken: idToken
        )

        var statesByIndex: [Int: AttendanceDisplayState] = [:]
        try await withThrowingTaskGroup(of: (Int, AttendanceDisplayState).self) { group in
            for (index, date) in dates.enumerated() {
                group.addTask {
                    let dateId = LunchPhaseCalculator.dayDocumentId(for: date)
                    async let attendanceDoc = FirestoreRESTClient.getDocument(
                        path: "attendances/\(userId)_\(dateId)", idToken: idToken
                    )
                    async let lunchDayDoc = FirestoreRESTClient.getDocument(
                        path: "lunchDays/\(dateId)", idToken: idToken
                    )
                    let (attendance, lunchDay) = try await (attendanceDoc, lunchDayDoc)

                    let isAttending = resolveIsAttending(date: date, attendance: attendance, recurring: recurring)
                    let forceLunch = lunchDay?["forceLunch"] as? Bool ?? false
                    let isCancelled = lunchDay?["isCancelled"] as? Bool ?? false
                    let localHoliday = HolidayService().holiday(for: date)
                    let holidayName = (localHoliday != nil && !forceLunch) ? localHoliday?.name : nil

                    let state = AttendanceDisplayState(
                        date: date,
                        isAttending: isAttending,
                        phase: LunchPhaseCalculator.phase(for: date, now: Date()),
                        holidayName: holidayName,
                        isCancelled: isCancelled,
                        isStale: false
                    )
                    return (index, state)
                }
            }
            for try await (index, state) in group {
                statesByIndex[index] = state
            }
        }

        return dates.indices.compactMap { statesByIndex[$0] }
    }

    // MARK: - Reload-Zeitpunkt

    static func nextReloadDate(now: Date = Date()) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current

        var candidates: [Date] = []

        if let midnight = calendar.date(bySettingHour: 0, minute: 5, second: 0, of: now) {
            candidates.append(midnight > now ? midnight : (calendar.date(byAdding: .day, value: 1, to: midnight) ?? midnight))
        }
        if let cutoff = calendar.date(bySettingHour: LunchPhaseCalculator.cutoffHour, minute: 0, second: 0, of: now) {
            candidates.append(cutoff > now ? cutoff : (calendar.date(byAdding: .day, value: 1, to: cutoff) ?? cutoff))
        }
        candidates.append(calendar.date(byAdding: .hour, value: 6, to: now) ?? now.addingTimeInterval(6 * 3600))

        return candidates.min() ?? now.addingTimeInterval(3600)
    }
}
