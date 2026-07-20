//
//  NotificationService.swift
//  Hasenwacht
//

import Foundation
@preconcurrency import UserNotifications

/// Zentrale Service-Klasse für lokale Notifications.
///
/// Verantwortlich für:
/// - Berechtigungs-Anfrage beim System
/// - Planung der täglichen Reminder um 19:00 Uhr (Sonntag–Donnerstag)
/// - Berücksichtigung von Feiertagen (kein Reminder am Vorabend eines Feiertags)
/// - User-Toggle (Reminder ein/aus) via UserDefaults persistiert
@Observable
@MainActor
final class NotificationService {

    static let shared = NotificationService()

    // MARK: - Observable State

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var remindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(remindersEnabled, forKey: Self.remindersEnabledKey)
            Task { await rescheduleReminders() }
        }
    }

    // MARK: - Constants
    // nonisolated, damit sie aus jedem Kontext lesbar sind (Swift 6 Concurrency).

    nonisolated static let remindersEnabledKey = "hasenwacht.remindersEnabled"
    nonisolated static let reminderIdentifierPrefix = "hasenwacht.lunchReminder."
    nonisolated static let reminderHour = 10
    nonisolated static let reminderMinute = 0

    // MARK: - Dependencies

    private let holidayService = HolidayService()

    // MARK: - Init

    private init() {
        if UserDefaults.standard.object(forKey: Self.remindersEnabledKey) == nil {
            self.remindersEnabled = true
        } else {
            self.remindersEnabled = UserDefaults.standard.bool(forKey: Self.remindersEnabledKey)
        }
    }

    func start() {
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Permission Handling

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])

            await refreshAuthorizationStatus()

            if granted {
                await rescheduleReminders()
            }
        } catch {
            print("⚠️ NotificationService: Permission-Request fehlgeschlagen: \(error)")
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.authorizationStatus = settings.authorizationStatus

        if authorizationStatus == .authorized && remindersEnabled {
            await rescheduleReminders()
        }
    }

    // MARK: - Scheduling

    func rescheduleReminders() async {
        let center = UNUserNotificationCenter.current()

        // 1. Alte Reminder löschen
        let pending = await center.pendingNotificationRequests()
        let oldIdentifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.reminderIdentifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: oldIdentifiers)

        // 2. Wenn deaktiviert, keine Permission oder kein User angemeldet → fertig.
        guard remindersEnabled, authorizationStatus == .authorized,
              let userId = AuthService.shared.currentUserId else {
            return
        }

        // 3. Wiederkehrende Absenz einmalig laden — dient als Fallback, falls für
        //    einen abwesenden Wochentag (noch) kein explizites Attendance-Dokument
        //    existiert (siehe AbsenceViewModel.repairMissingRecurringAttendances).
        let recurringAbsence = (try? await AbsenceService.shared.fetchRecurring(userId: userId)) ?? RecurringAbsence()

        // 4. Reminder planen:
        //    Reminder läuft um 10:00, wenn der FOLGETAG ein Werktag (Mo–Fr) ist
        //    und kein Feiertag.
        //    Daraus ergibt sich automatisch:
        //    - Reminder So–Do → Mittagessen Mo–Fr
        //    - Kein Reminder Fr (Folgetag = Sa) und Sa (Folgetag = So)
        //    Zusätzlich wird der Reminder nur geplant, wenn der User für den
        //    Folgetag aktuell angemeldet ist — wer sich bewusst abgemeldet hat
        //    (explizit oder via wiederkehrender Absenz/Ferien), bekommt keine
        //    Nachfrage-Push mehr.
        let calendar = Calendar.current
        let now = Date()
        var scheduledCount = 0
        let maxReminders = 7

        for offset in 0..<14 {
            guard scheduledCount < maxReminders else { break }

            guard let reminderDay = calendar.date(byAdding: .day, value: offset, to: now) else {
                continue
            }
            guard let targetDay = calendar.date(byAdding: .day, value: 1, to: reminderDay) else {
                continue
            }

            // Folgetag muss Werktag (Mo–Fr) sein
            let targetWeekday = calendar.component(.weekday, from: targetDay)
            guard (2...6).contains(targetWeekday) else { continue }

            // Folgetag darf kein Feiertag sein
            if holidayService.isHoliday(targetDay) {
                continue
            }

            // Trigger-Zeit am Reminder-Tag um 10:00 berechnen
            var components = calendar.dateComponents([.year, .month, .day], from: reminderDay)
            components.hour = Self.reminderHour
            components.minute = Self.reminderMinute

            guard let triggerDate = calendar.date(from: components),
                  triggerDate > now else {
                // Vergangene Trigger-Zeiten überspringen
                continue
            }

            // User muss für den Folgetag angemeldet sein, sonst keine Push nötig
            guard await isUserAttending(userId: userId, on: targetDay, recurringAbsence: recurringAbsence) else {
                continue
            }

            await scheduleReminder(for: triggerDate, dayAfter: targetDay)
            scheduledCount += 1
        }
    }

    /// Prüft, ob der User für den gegebenen Tag aktuell angemeldet ist.
    /// Ein explizites Attendance-Dokument hat immer Vorrang; existiert keins,
    /// entscheidet die wiederkehrende Absenz; ansonsten gilt der Default (angemeldet).
    private func isUserAttending(userId: String, on date: Date, recurringAbsence: RecurringAbsence) async -> Bool {
        if let attendance = try? await AttendanceService.shared.fetchAttendance(userId: userId, date: date) {
            return attendance.isAttending
        }
        return !recurringAbsence.isAbsent(on: date)
    }

    private func scheduleReminder(for triggerDate: Date, dayAfter: Date) async {
        let calendar = Calendar.current
        let triggerComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )

        let content = UNMutableNotificationContent()
        content.title = "Mittagessen morgen"
        content.body = "Bist du morgen beim Mittagessen dabei? Eintragungen schliessen heute um 14:00."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: triggerComponents,
            repeats: false
        )

        let dateString = Self.dayFormatter.string(from: dayAfter)
        let identifier = Self.reminderIdentifierPrefix + dateString

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("⚠️ NotificationService: Konnte Reminder nicht planen: \(error)")
        }
    }

    /// Löscht alle geplanten Reminder. Nützlich beim Logout.
    func cancelAllReminders() {
        let center = UNUserNotificationCenter.current()
        Task { @MainActor in
            let requests = await center.pendingNotificationRequests()
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Self.reminderIdentifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }

    // MARK: - Helper

    nonisolated static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()
}
