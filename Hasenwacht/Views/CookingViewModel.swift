//
//  CookingViewModel.swift
//  Hasenwacht
//

import Foundation
import Combine
import FirebaseFirestore

final class CookingViewModel: ObservableObject {

    static let shared = CookingViewModel()

    @Published var slots: [CookingSlot] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private(set) var currentUserId: String = ""
    private var listener: ListenerRegistration?

    private init() {}

    func start(userId: String) {
        guard !userId.isEmpty else { return }
        currentUserId = userId
        listener?.remove()
        isLoading = true

        let dates = LunchDaysViewModel.nextWorkdays(count: 15)
        guard let first = dates.first, let last = dates.last else { return }

        listener = CookingService.shared.observeSlots(from: first, to: last) { [weak self] slots in
            DispatchQueue.main.async {
                self?.slots = slots
                self?.isLoading = false
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func slot(for date: Date) -> CookingSlot? {
        slots.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    func isCurrentUserCooking(on date: Date) -> Bool {
        slot(for: date)?.userId == currentUserId
    }

    func claimSlot(for date: Date) async {
        do {
            try await CookingService.shared.claimSlot(userId: currentUserId, date: date)
        } catch {
            await MainActor.run { errorMessage = "Eintragen fehlgeschlagen." }
        }
    }

    func releaseSlot(for date: Date) async {
        do {
            try await CookingService.shared.releaseSlot(date: date)
        } catch {
            await MainActor.run { errorMessage = "Austragen fehlgeschlagen." }
        }
    }

    func updateMenu(for date: Date, title: String, description: String) async {
        do {
            try await CookingService.shared.updateMenu(
                date: date,
                title: title.isEmpty ? nil : title,
                description: description.isEmpty ? nil : description
            )
        } catch {
            await MainActor.run { errorMessage = "Menü konnte nicht gespeichert werden." }
        }
    }
}
