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
        AttendanceEntry(
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
            completion(await Self.currentEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AttendanceEntry>) -> Void) {
        Task {
            let entry = await Self.currentEntry()
            let timeline = Timeline(entries: [entry], policy: .after(Self.nextReloadDate()))
            completion(timeline)
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
            var cache = SharedAttendanceCache(
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
    private static func resolveIsAttending(
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
