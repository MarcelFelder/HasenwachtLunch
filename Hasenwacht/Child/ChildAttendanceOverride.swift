//
//  ChildAttendanceOverride.swift
//  Hasenwacht
//
//  Speichert manuelle Anmeldungen/Abmeldungen für ein Kind an einem bestimmten Tag.
//
//  Default-Verhalten (ohne Override):
//   - Kind kommt wenn primaryParent dabei ist
//
//  Override-Verhalten:
//   - takingParentId == userId: Dieser User nimmt das Kind heute mit
//   - takingParentId == nil:    Kind kommt heute nicht mit (explizit abgemeldet)
//

import Foundation
import FirebaseFirestore

struct ChildAttendanceOverride: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var childId: String
    var date: Date
    /// User der das Kind heute übernimmt. Nil = Kind kommt heute nicht.
    var takingParentId: String?
    var createdAt: Date

    init(id: String? = nil,
         childId: String,
         date: Date,
         takingParentId: String?,
         createdAt: Date = Date()) {
        self.id = id
        self.childId = childId
        self.date = date
        self.takingParentId = takingParentId
        self.createdAt = createdAt
    }

    /// Dokument-ID: {childId}_{yyyy-MM-dd}
    static func documentId(childId: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        return "\(childId)_\(formatter.string(from: date))"
    }
}
