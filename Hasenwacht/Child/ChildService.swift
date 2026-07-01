//
//  ChildService.swift
//  Hasenwacht
//
//  Firestore-Zugriff für Kinder und Tagesübernahmen.
//

import Foundation
import FirebaseFirestore

final class ChildService {

    static let shared = ChildService()
    private init() {}

    private let db = Firestore.firestore()
    private var childrenCollection: CollectionReference {
        db.collection("children")
    }
    private var overridesCollection: CollectionReference {
        db.collection("childAttendanceOverrides")
    }

    // MARK: - Children CRUD

    func observeAllChildren(_ onChange: @escaping ([Child]) -> Void) -> ListenerRegistration {
        childrenCollection.addSnapshotListener { snapshot, _ in
            let children = snapshot?.documents.compactMap {
                try? $0.data(as: Child.self)
            } ?? []
            onChange(children)
        }
    }

    func addChild(_ child: Child) async throws -> String {
        let ref = childrenCollection.document()
        var newChild = child
        newChild.id = ref.documentID
        try ref.setData(from: newChild)
        return ref.documentID
    }

    func updateChild(_ child: Child) async throws {
        guard let id = child.id else { throw ChildServiceError.missingId }
        try childrenCollection.document(id).setData(from: child, merge: true)
    }

    func deleteChild(id: String) async throws {
        try await childrenCollection.document(id).delete()
        // Alle Override-Dokumente dieses Kindes löschen
        let snapshot = try await overridesCollection
            .whereField("childId", isEqualTo: id)
            .getDocuments()
        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Attendance Overrides

    func observeOverrides(
        from startDate: Date,
        to endDate: Date,
        onChange: @escaping ([ChildAttendanceOverride]) -> Void
    ) -> ListenerRegistration {
        overridesCollection
            .whereField("date", isGreaterThanOrEqualTo: startDate)
            .whereField("date", isLessThanOrEqualTo: endDate)
            .addSnapshotListener { snapshot, _ in
                let overrides = snapshot?.documents.compactMap {
                    try? $0.data(as: ChildAttendanceOverride.self)
                } ?? []
                onChange(overrides)
            }
    }

    func setOverride(childId: String, date: Date, takingParentId: String?) async throws {
        let docId = ChildAttendanceOverride.documentId(childId: childId, date: date)
        let override = ChildAttendanceOverride(
            id: docId,
            childId: childId,
            date: normalizedDate(date),
            takingParentId: takingParentId
        )
        try overridesCollection.document(docId).setData(from: override)
    }

    func deleteOverride(childId: String, date: Date) async throws {
        let docId = ChildAttendanceOverride.documentId(childId: childId, date: date)
        try await overridesCollection.document(docId).delete()
    }

    // MARK: - Helpers

    private func normalizedDate(_ date: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        return cal.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
    }
}

enum ChildServiceError: LocalizedError {
    case missingId

    var errorDescription: String? {
        switch self {
        case .missingId: return "Kind-ID fehlt."
        }
    }
}
