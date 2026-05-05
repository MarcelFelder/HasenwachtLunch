//
//  AttendanceService.swift
//  Hasenwacht
//
//  Kapselt alle Firestore-Operationen für die Attendance-Collection.
//  Pro User pro Tag existiert nur dann ein Dokument, wenn jemand explizit
//  ausgetragen ODER der Default überschrieben wurde.
//

import Foundation
import FirebaseFirestore

final class AttendanceService {

    // MARK: - Singleton

    static let shared = AttendanceService()
    private init() {}

    // MARK: - Firestore-Referenz

    private let db = Firestore.firestore()
    private var attendancesCollection: CollectionReference {
        db.collection("attendances")
    }

    // MARK: - Eine Attendance speichern

    /// Setzt den Anwesenheitsstatus für einen User an einem bestimmten Tag.
    /// Erstellt das Dokument, falls es noch nicht existiert.
    func setAttendance(userId: String, date: Date, isAttending: Bool) async throws {
        let documentId = Attendance.documentId(userId: userId, date: date)
        let attendance = Attendance(
            id: nil,
            userId: userId,
            date: date,
            isAttending: isAttending,
            updatedAt: Date()
        )
        try attendancesCollection.document(documentId).setData(from: attendance, merge: true)
    }

    // MARK: - Listener für einen Datumsbereich

    /// Hört auf Änderungen aller Attendance-Dokumente innerhalb des Datumsbereichs.
    /// Der Callback wird sofort mit den initialen Daten und danach bei jeder Änderung gerufen.
    /// Gibt einen ListenerRegistration zurück, mit dem der Listener gestoppt werden kann.
    func observeAttendances(
        from startDate: Date,
        to endDate: Date,
        onChange: @escaping ([Attendance]) -> Void
    ) -> ListenerRegistration {
        return attendancesCollection
            .whereField("date", isGreaterThanOrEqualTo: startDate)
            .whereField("date", isLessThanOrEqualTo: endDate)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    onChange([])
                    return
                }
                let attendances = documents.compactMap { document in
                    try? document.data(as: Attendance.self)
                }
                onChange(attendances)
            }
    }
}
