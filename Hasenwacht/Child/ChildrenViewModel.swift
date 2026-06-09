//
//  ChildrenViewModel.swift
//  Hasenwacht
//
//  Hält alle Kinder + Overrides reaktiv für die UI.
//  Berechnet wer welches Kind an welchem Tag mitbringt.
//

import Foundation
import Combine
import FirebaseFirestore

final class ChildrenViewModel: ObservableObject {

    static let shared = ChildrenViewModel()

    @Published var allChildren: [Child] = []
    @Published var overrides: [ChildAttendanceOverride] = []

    private var childrenListener: ListenerRegistration?
    private var overridesListener: ListenerRegistration?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        stop()
        childrenListener = ChildService.shared.observeAllChildren { [weak self] children in
            DispatchQueue.main.async {
                self?.allChildren = children
                LunchDaysViewModel.shared.onChildrenChanged()
            }
        }
        // Overrides für gesamtes Fenster
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let startWindow = LunchDaysViewModel.earliestMonday()
        let endWindow = cal.date(byAdding: .day, value: 60, to: Date()) ?? Date()

        overridesListener = ChildService.shared.observeOverrides(
            from: startWindow, to: endWindow
        ) { [weak self] overrides in
            DispatchQueue.main.async {
                self?.overrides = overrides
                LunchDaysViewModel.shared.onChildrenChanged()
            }
        }
    }

    func stop() {
        childrenListener?.remove()
        overridesListener?.remove()
        childrenListener = nil
        overridesListener = nil
        allChildren = []
        overrides = []
    }

    // MARK: - Queries

    /// Eigene Kinder eines Users (als primary oder secondary parent).
    func children(forUserId userId: String) -> [Child] {
        allChildren.filter { $0.isParent(userId) }
    }

    /// Welcher User nimmt das Kind am angegebenen Datum mit?
    /// - Returns: userId des Eltern-Users, oder nil wenn Kind heute nicht dabei.
    func takingParent(for child: Child,
                      on date: Date,
                      attendingUserIds: Set<String>) -> String? {
        let cal = Calendar.current
        // Override prüfen
        if let override = overrides.first(where: {
            $0.childId == child.id && cal.isDate($0.date, inSameDayAs: date)
        }) {
            // Override existiert — entweder takingParentId oder nil (abgemeldet)
            if let takerId = override.takingParentId,
               attendingUserIds.contains(takerId) {
                return takerId
            }
            return nil
        }
        // Default: primary parent muss dabei sein
        return attendingUserIds.contains(child.primaryParentId)
            ? child.primaryParentId
            : nil
    }

    /// Kinder die ein User an einem Datum mitbringt.
    func childrenTakenBy(userId: String,
                        on date: Date,
                        attendingUserIds: Set<String>) -> [Child] {
        allChildren.filter { child in
            takingParent(for: child, on: date, attendingUserIds: attendingUserIds) == userId
        }
    }

    /// Hat das Kind heute einen expliziten Override?
    func override(for childId: String, on date: Date) -> ChildAttendanceOverride? {
        let cal = Calendar.current
        return overrides.first { $0.childId == childId && cal.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: - Actions

    /// Setzt einen Override (z.B. "Marcel nimmt Lia heute mit" oder "Lia kommt heute nicht").
    func setOverride(childId: String, date: Date, takingParentId: String?) async {
        try? await ChildService.shared.setOverride(
            childId: childId, date: date, takingParentId: takingParentId
        )
    }

    /// Entfernt den Override → zurück zum Default-Verhalten.
    func clearOverride(childId: String, date: Date) async {
        try? await ChildService.shared.deleteOverride(childId: childId, date: date)
    }
}
