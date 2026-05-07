//
//  User.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var firstName: String
    var lastName: String
    var photoURL: String?
    var photoBase64: String?
    var canCook: Bool
    var createdAt: Date

    init(id: String? = nil, firstName: String, lastName: String,
         photoURL: String? = nil, photoBase64: String? = nil,
         canCook: Bool = false, createdAt: Date = Date()) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.photoURL = photoURL
        self.photoBase64 = photoBase64
        self.canCook = canCook
        self.createdAt = createdAt
    }
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var initials: String {
        let firstInitial = firstName.first.map(String.init) ?? ""
        let lastInitial = lastName.first.map(String.init) ?? ""
        return "\(firstInitial)\(lastInitial)".uppercased()
    }
}
