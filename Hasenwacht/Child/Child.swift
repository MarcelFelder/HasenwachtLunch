//
//  Child.swift
//  Hasenwacht
//
//  Datenmodell für ein Kind das mit zum Mittagessen kommt.
//  Ein Kind hat genau einen primären Elternteil und optional sekundäre Eltern.
//  Default: Kind kommt automatisch mit wenn der primäre Elternteil dabei ist.
//

import Foundation
import FirebaseFirestore

struct Child: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    /// User der das Kind standardmässig mitbringt.
    var primaryParentId: String
    /// Weitere User die das Kind an einzelnen Tagen mitnehmen können.
    var secondaryParentIds: [String]
    var createdAt: Date

    init(id: String? = nil,
         name: String,
         primaryParentId: String,
         secondaryParentIds: [String] = [],
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.primaryParentId = primaryParentId
        self.secondaryParentIds = secondaryParentIds
        self.createdAt = createdAt
    }

    var allParentIds: [String] {
        [primaryParentId] + secondaryParentIds
    }

    func isParent(_ userId: String) -> Bool {
        allParentIds.contains(userId)
    }
}
