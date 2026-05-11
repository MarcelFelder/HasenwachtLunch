//
//  AbsenceService.swift
//  Hasenwacht
//
//  Kapselt alle Firestore-Operationen für Abwesenheiten.
//  - recurringAbsences/{userId}  → ein Dokument pro User
//  - vacationAbsences/{id}       → eine Collection mit allen Ferieneinträgen
//

import Foundation
import FirebaseFirestore

final class AbsenceService {

    static let shared = AbsenceService()
    private init() {}

    private let db = Firestore.firestore()

    private var recurringCollection: CollectionReference {
        db.collection("recurringAbsences")
    }

    private var vacationCollection: CollectionReference {
        db.collection("vacationAbsences")
    }

    // MARK: - Recurring

    /// Lädt die wiederkehrende Abwesenheit eines Users (einmalig).
    func fetchRecurring(userId: String) async throws -> RecurringAbsence {
        let doc = try await recurringCollection.document(userId).getDocument()
        if doc.exists, let absence = try? doc.data(as: RecurringAbsence.self) {
            return absence
        }
        return RecurringAbsence()
    }

    /// Speichert die aktualisierten Wochentage.
    func saveRecurring(userId: String, absence: RecurringAbsence) async throws {
        var updated = absence
        updated.updatedAt = Date()
        try recurringCollection.document(userId).setData(from: updated)
    }

    /// Listener für Echtzeit-Updates der wiederkehrenden Abwesenheit.
    func observeRecurring(userId: String,
                          onChange: @escaping (RecurringAbsence) -> Void) -> ListenerRegistration {
        recurringCollection.document(userId).addSnapshotListener { snapshot, _ in
            guard let snapshot, snapshot.exists,
                  let absence = try? snapshot.data(as: RecurringAbsence.self) else {
                onChange(RecurringAbsence())
                return
            }
            onChange(absence)
        }
    }

    // MARK: - Vacation

    /// Listener für alle Ferienabwesenheiten des Users.
    func observeVacations(userId: String,
                          onChange: @escaping ([VacationAbsence]) -> Void) -> ListenerRegistration {
        vacationCollection
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange([])
                    return
                }
                guard let docs = snapshot?.documents else { onChange([]); return }
                let vacations = docs
                    .compactMap { try? $0.data(as: VacationAbsence.self) }
                    .sorted { $0.startDate < $1.startDate } // client-seitig sortieren
                onChange(vacations)
            }
    }

    /// Erstellt einen neuen Ferieneintrag.
    func addVacation(_ vacation: VacationAbsence) async throws {
        let ref = vacationCollection.document()
        var v = vacation
        v.id = ref.documentID
        try ref.setData(from: v)
    }

    /// Löscht einen Ferieneintrag.
    func deleteVacation(id: String) async throws {
        try await vacationCollection.document(id).delete()
    }
}
