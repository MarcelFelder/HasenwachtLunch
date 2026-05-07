//
//  CookingSlot.swift
//  Hasenwacht
//
//  Ein Kocheintrag pro Tag. Nur eine Person kann pro Tag kochen.
//  Dokument-ID = Datum (yyyy-MM-dd) → garantiert Einzigartigkeit pro Tag.
//

import Foundation
import FirebaseFirestore

struct CookingSlot: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var date: Date
    var menuTitle: String?
    var menuDescription: String?
    var createdAt: Date

    init(id: String? = nil,
         userId: String,
         date: Date,
         menuTitle: String? = nil,
         menuDescription: String? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.date = date
        self.menuTitle = menuTitle
        self.menuDescription = menuDescription
        self.createdAt = createdAt
    }

    /// Datum als Dokument-ID → max. 1 Koch pro Tag
    static func documentId(for date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "Europe/Zurich")
        return df.string(from: date)
    }

    var hasMenu: Bool {
        menuTitle?.isEmpty == false || menuDescription?.isEmpty == false
    }

    var displayMenuTitle: String {
        menuTitle?.isEmpty == false ? menuTitle! : "Menü noch unbekannt"
    }
}
