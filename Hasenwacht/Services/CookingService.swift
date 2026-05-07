//
//  CookingService.swift
//  Hasenwacht
//
//  Firestore-Operationen für die cookingSlots Collection.
//  Dokument-ID = Datum → garantiert nur 1 Koch pro Tag.
//

import Foundation
import FirebaseFirestore

final class CookingService {

    static let shared = CookingService()
    private init() {}

    private let db = Firestore.firestore()
    private var collection: CollectionReference {
        db.collection("cookingSlots")
    }

    // MARK: - Listener

    /// Hört auf alle Kocheinträge im Datumsfenster.
    func observeSlots(from startDate: Date,
                      to endDate: Date,
                      onChange: @escaping ([CookingSlot]) -> Void) -> ListenerRegistration {
        collection
            .whereField("date", isGreaterThanOrEqualTo: startDate)
            .whereField("date", isLessThanOrEqualTo: endDate)
            .addSnapshotListener { snapshot, error in
                if let error {
                    print("❌ CookingService.observeSlots: \(error)")
                    onChange([])
                    return
                }
                let slots = snapshot?.documents.compactMap {
                    try? $0.data(as: CookingSlot.self)
                } ?? []
                onChange(slots)
            }
    }

    // MARK: - Schreiben

    /// Trägt den User als Koch für einen Tag ein.
    /// Überschreibt einen bestehenden Eintrag (Datum = Dokument-ID).
    func claimSlot(userId: String, date: Date) async throws {
        let docId = CookingSlot.documentId(for: date)
        let slot = CookingSlot(id: docId, userId: userId, date: date)
        try collection.document(docId).setData(from: slot)
    }

    /// Aktualisiert Menütitel und Beschreibung eines Slots.
    func updateMenu(date: Date, title: String?, description: String?) async throws {
        let docId = CookingSlot.documentId(for: date)
        var data: [String: Any] = [:]
        data["menuTitle"]       = title ?? ""
        data["menuDescription"] = description ?? ""
        try await collection.document(docId).updateData(data)
    }

    /// Löscht den Kocheintrag für einen Tag (User trägt sich aus).
    func releaseSlot(date: Date) async throws {
        let docId = CookingSlot.documentId(for: date)
        try await collection.document(docId).delete()
    }
}
