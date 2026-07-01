//
//  LunchDayService.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//
//  Kapselt alle Firestore-Operationen für die lunchDays-Collection.
//  Ein Dokument existiert pro Tag NUR dann, wenn der Default überschrieben
//  wurde — d.h. wenn jemand "Mittagessen aktivieren" gedrückt oder den
//  Tag gestrichen hat.
//
//  Für normale Werktage und nicht-übersteuerte Feiertage gibt es kein Dokument.
//

import Foundation
import FirebaseFirestore

final class LunchDayService {

    // MARK: - Singleton

    static let shared = LunchDayService()
    private init() {}

    // MARK: - Firestore-Referenz

    private let db = Firestore.firestore()
    private var lunchDaysCollection: CollectionReference {
        db.collection("lunchDays")
    }

    // MARK: - forceLunch (Feiertag aktivieren)

    /// Aktiviert das Mittagessen an einem (Feiertag-)Tag.
    /// - Parameters:
    ///   - date: Der Tag, an dem das Mittagessen aktiviert werden soll.
    ///   - userId: Der User, der die Aktivierung durchführt (wird in `activatedBy` gespeichert).
    ///   - holidayName: Optional — der Name des Feiertags, falls bekannt.
    func activateLunch(for date: Date, userId: String, holidayName: String?) async throws {
        let documentId = LunchDay.documentId(for: date)
        let lunchDay = LunchDay(
            id: nil,
            date: date,
            isHoliday: holidayName != nil,
            holidayName: holidayName,
            forceLunch: true,
            activatedBy: userId
        )
        try lunchDaysCollection.document(documentId).setData(from: lunchDay, merge: true)
    }

    /// Deaktiviert das Mittagessen an einem Feiertag (löscht das forceLunch-Dokument).
    func deactivateLunch(for date: Date) async throws {
        let documentId = LunchDay.documentId(for: date)
        try await lunchDaysCollection.document(documentId).delete()
    }

    // MARK: - Tag streichen (Cancel)

    /// Streicht einen Tag (setzt isCancelled = true).
    /// Nutzt setData mit merge damit bestehende Felder (z.B. forceLunch) erhalten bleiben.
    func cancelLunch(for date: Date, userId: String) async throws {
        let documentId = LunchDay.documentId(for: date)
        let data: [String: Any] = [
            "date": date,
            "isCancelled": true,
            "cancelledBy": userId,
            // Felder die existieren müssen falls das Dokument neu erstellt wird:
            "isHoliday": false,
            "forceLunch": false
        ]
        try await lunchDaysCollection.document(documentId).setData(data, merge: true)
    }

    /// Hebt die Streichung auf (setzt isCancelled = false und entfernt cancelledBy).
    /// Wenn das Dokument sonst keine Override-Infos enthält (kein Feiertag aktiviert),
    /// wird es ganz gelöscht — sonst nur die Cancel-Felder entfernt.
    func uncancelLunch(for date: Date) async throws {
        let documentId = LunchDay.documentId(for: date)
        let ref = lunchDaysCollection.document(documentId)
        let snapshot = try await ref.getDocument()
        let data = snapshot.data() ?? [:]
        let forceLunch = data["forceLunch"] as? Bool ?? false
        if forceLunch {
            // Dokument behalten — nur Cancellation aufheben
            try await ref.updateData([
                "isCancelled": false,
                "cancelledBy": FieldValue.delete()
            ])
        } else {
            // Dokument ganz löschen — es gibt keinen anderen Override
            try await ref.delete()
        }
    }

    // MARK: - Listener für einen Datumsbereich

    /// Hört auf Änderungen aller LunchDay-Dokumente innerhalb des Datumsbereichs.
    /// Der Callback wird sofort mit den initialen Daten und danach bei jeder Änderung gerufen.
    ///
    /// - Returns: ListenerRegistration zum späteren Stoppen.
    func observeLunchDays(
        from startDate: Date,
        to endDate: Date,
        onChange: @escaping ([LunchDay]) -> Void
    ) -> ListenerRegistration {
        return lunchDaysCollection
            .whereField("date", isGreaterThanOrEqualTo: startDate)
            .whereField("date", isLessThanOrEqualTo: endDate)
            .addSnapshotListener { snapshot, _ in
                guard let documents = snapshot?.documents else {
                    onChange([])
                    return
                }
                let lunchDays = documents.compactMap { document in
                    try? document.data(as: LunchDay.self)
                }
                onChange(lunchDays)
            }
    }
}
