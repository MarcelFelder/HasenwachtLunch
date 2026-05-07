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

    /// Löscht ein Attendance-Dokument (z.B. beim Entfernen einer Absenz-Regel).
    func deleteAttendance(userId: String, date: Date) async throws {
        let documentId = Attendance.documentId(userId: userId, date: date)
        try await attendancesCollection.document(documentId).delete()
    }

    /// Schreibt mehrere Attendances auf einmal (Batch) — für Absenz-Regeln über mehrere Tage.
    /// Überschreibt nur Dokumente die noch nicht manuell vom User geändert wurden,
    /// es sei denn forceOverride ist true.
    func batchSetAttendances(userId: String, dates: [Date], isAttending: Bool) async throws {
        let batch = db.batch()
        for date in dates {
            let docId = Attendance.documentId(userId: userId, date: date)
            let ref = attendancesCollection.document(docId)
            let attendance = Attendance(
                id: nil,
                userId: userId,
                date: date,
                isAttending: isAttending,
                updatedAt: Date()
            )
            if let data = try? Firestore.Encoder().encode(attendance) {
                batch.setData(data, forDocument: ref)
            }
        }
        try await batch.commit()
    }

    /// Löscht mehrere Attendance-Dokumente auf einmal (Batch).
    func batchDeleteAttendances(userId: String, dates: [Date]) async throws {
        let batch = db.batch()
        for date in dates {
            let docId = Attendance.documentId(userId: userId, date: date)
            let ref = attendancesCollection.document(docId)
            batch.deleteDocument(ref)
        }
        try await batch.commit()
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
