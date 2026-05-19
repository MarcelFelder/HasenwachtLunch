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

                // Werktage im Zeitraum berechnen
                let workdays = workdaysInRange(from: start, to: end)

                await MainActor.run {
                    self.userStats = self.buildStats(
                        attendances: attendances,
                        slots: slots,
                        workdays: workdays
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
                            workdays: [Date]) -> [UserStats] {
        let calendar = Calendar.current
        let pastWorkdays = workdays.filter { $0 <= Date() }
        let total = pastWorkdays.count

        return allUsers.compactMap { user -> UserStats? in
            guard let userId = user.id else { return nil }

            // Opt-Out Dokumente für diesen User
            let optedOutDates = Set(
                attendances
                    .filter { $0.userId == userId && !$0.isAttending }
                    .map { calendar.startOfDay(for: $0.date) }
            )

            // Anwesend = alle Werktage minus opt-outs
            let attended = pastWorkdays.filter { day in
                !optedOutDates.contains(calendar.startOfDay(for: day))
            }.count

            // Gekocht
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

        switch period {
        case .week:
            let weekday = cal.component(.weekday, from: now)
            let daysSinceMonday = weekday == 1 ? 6 : weekday - 2
            let monday = cal.date(byAdding: .day, value: -daysSinceMonday, to: now) ?? now
            let start = cal.startOfDay(for: monday)
            let end = cal.date(byAdding: .day, value: 4, to: start) ?? now
            return (start, end)

        case .month:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
            let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? now
            return (start, end)

        case .total:
            let start = OnboardingService.shared.firstAppUseDate
            return (cal.startOfDay(for: start), now)
        }
    }

    private func workdaysInRange(from start: Date, to end: Date) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        var result: [Date] = []
        var current = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)

        while current <= endDay {
            let weekday = cal.component(.weekday, from: current)
            if weekday >= 2 && weekday <= 6 { // Mo–Fr
                result.append(current)
            }
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
