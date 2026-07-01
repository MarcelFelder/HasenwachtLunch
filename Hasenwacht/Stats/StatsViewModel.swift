//
//  StatsViewModel.swift
//  Hasenwacht
//
//  Lädt Attendance-Daten für Statistiken.
//  Berechnet Teilnahme-Rate pro User für verschiedene Zeiträume.
//

import Foundation
import Combine
import FirebaseFirestore

// MARK: - Zeitraum

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week  = "Woche"
    case month = "Monat"
    case total = "Gesamt"
    var id: String { rawValue }
}

// MARK: - User-Statistik

struct UserStats: Identifiable {
    let user: User
    let attendedDays: Int
    let totalDays: Int
    let cookedDays: Int

    var id: String { user.id ?? UUID().uuidString }

    var attendanceRate: Double {
        totalDays > 0 ? Double(attendedDays) / Double(totalDays) : 0
    }

    var attendancePercent: String {
        "\(Int(attendanceRate * 100))%"
    }
}

// MARK: - ViewModel

final class StatsViewModel: ObservableObject {

    static let shared = StatsViewModel()

    @Published var userStats: [UserStats] = []
    @Published var isLoading = true
    @Published var selectedPeriod: StatsPeriod = .month

    private var currentUserId: String = ""
    private var allUsers: [User] = []
    private var db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    // MARK: - Start

    func start(userId: String, users: [User]) {
        currentUserId = userId
        allUsers = users
        load()
    }

    func setPeriod(_ period: StatsPeriod) {
        selectedPeriod = period
        load()
    }

    // MARK: - Load

    func load() {
        isLoading = true
        let (start, end) = dateRange(for: selectedPeriod)

        Task {
            do {
                // Attendances laden
                let snapshot = try await db.collection("attendances")
                    .whereField("date", isGreaterThanOrEqualTo: start)
                    .whereField("date", isLessThanOrEqualTo: end)
                    .getDocuments()

                let attendances = snapshot.documents.compactMap {
                    try? $0.data(as: Attendance.self)
                }

                // Cooking Slots laden
                let cookingSnapshot = try await db.collection("cookingSlots")
                    .whereField("date", isGreaterThanOrEqualTo: start)
                    .whereField("date", isLessThanOrEqualTo: end)
                    .getDocuments()

                let slots = cookingSnapshot.documents.compactMap {
                    try? $0.data(as: CookingSlot.self)
                }

                // Recurring Absences laden für direkte Auswertung
                let recurringSnapshot = try await db.collection("recurringAbsences").getDocuments()
                var recurringMap: [String: [Int]] = [:]
                for doc in recurringSnapshot.documents {
                    if let absence = try? doc.data(as: RecurringAbsence.self) {
                        recurringMap[doc.documentID] = absence.absentWeekdays
                    }
                }

                // Vacation Absences laden
                let vacationSnapshot = try await db.collection("vacationAbsences")
                    .whereField("endDate", isGreaterThanOrEqualTo: start)
                    .getDocuments()
                let vacations = vacationSnapshot.documents.compactMap {
                    try? $0.data(as: VacationAbsence.self)
                }

                // Werktage im Zeitraum berechnen
                let workdays = workdaysInRange(from: start, to: end)

                await MainActor.run {
                    self.userStats = self.buildStats(
                        attendances: attendances,
                        slots: slots,
                        workdays: workdays,
                        recurringAbsences: recurringMap,
                        vacations: vacations
                    )
                    self.isLoading = false
                }

            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    // MARK: - Stats berechnen

    private func buildStats(attendances: [Attendance],
                            slots: [CookingSlot],
                            workdays: [Date],
                            recurringAbsences: [String: [Int]],
                            vacations: [VacationAbsence]) -> [UserStats] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let now = Date()

        return allUsers.compactMap { user -> UserStats? in
            guard let userId = user.id else { return nil }

            let userStart: Date = {
                let c = cal.dateComponents([.year, .month, .day], from: user.createdAt)
                return cal.date(from: c) ?? user.createdAt
            }()
            let relevantWorkdays = workdays.filter { cal.startOfDay(for: $0) >= userStart && $0 <= now }

            let total = relevantWorkdays.count
            guard total > 0 else { return nil }

            // Explizite Opt-Outs / Opt-Ins
            let explicitOptOuts = Set(
                attendances
                    .filter { $0.userId == userId && !$0.isAttending }
                    .map { cal.startOfDay(for: $0.date) }
            )
            let explicitOptIns = Set(
                attendances
                    .filter { $0.userId == userId && $0.isAttending }
                    .map { cal.startOfDay(for: $0.date) }
            )

            // Wiederkehrende Absenz-Wochentage
            let recurringWeekdays = recurringAbsences[userId] ?? []

            // Ferien dieses Users
            let userVacations = vacations.filter { $0.userId == userId }

            let attended = relevantWorkdays.filter { day in
                let dayStart = cal.startOfDay(for: day)

                // Explizit abgemeldet
                if explicitOptOuts.contains(dayStart) { return false }

                // Explizit angemeldet → überschreibt alles
                if explicitOptIns.contains(dayStart) { return true }

                // Ferien prüfen
                if userVacations.contains(where: { $0.covers(date: day) }) { return false }

                // Wiederkehrende Absenz prüfen
                let appleWeekday = cal.component(.weekday, from: day)
                let isoWeekday = appleWeekday == 1 ? 7 : appleWeekday - 1
                if recurringWeekdays.contains(isoWeekday) { return false }

                return true
            }.count

            let cooked = slots.filter { $0.userId == userId }.count

            return UserStats(
                user: user,
                attendedDays: attended,
                totalDays: total,
                cookedDays: cooked
            )
        }
        .sorted { $0.attendanceRate > $1.attendanceRate }
    }

    // MARK: - Datumsbereich

    private func dateRange(for period: StatsPeriod) -> (Date, Date) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let now = Date()
        // today = Beginn des heutigen Tages in Zürich-Zeit, dann als UTC
        let todayComponents = cal.dateComponents([.year, .month, .day], from: now)
        let today = cal.date(from: todayComponents) ?? now

        let installDate: Date = {
            let d = OnboardingService.shared.firstAppUseDate
            let c = cal.dateComponents([.year, .month, .day], from: d)
            return cal.date(from: c) ?? d
        }()

        switch period {
        case .week:
            let weekday = cal.component(.weekday, from: now)
            let daysSinceMonday = weekday == 1 ? 6 : weekday - 2
            let monday = cal.date(byAdding: .day, value: -daysSinceMonday, to: today) ?? today
            let start = max(monday, installDate)
            let end = today
            return (start, end)

        case .month:
            let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
            let start = max(monthStart, installDate)
            let end = today
            return (start, end)

        case .total:
            return (installDate, today)
        }
    }

    private func workdaysInRange(from start: Date, to end: Date) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        var result: [Date] = []
        var current = start

        while current <= end {
            let weekday = cal.component(.weekday, from: current)
            if weekday >= 2 && weekday <= 6 { result.append(current) }
            current = cal.date(byAdding: .day, value: 1, to: current) ?? current
        }
        return result
    }

    // MARK: - Eigene Statistik

    var myStats: UserStats? {
        userStats.first { $0.user.id == currentUserId }
    }

    var topCook: UserStats? {
        userStats.max { $0.cookedDays < $1.cookedDays }
    }
}
