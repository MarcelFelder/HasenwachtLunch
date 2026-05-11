//
//  User.swift
//  Hasenwacht
//

import Foundation
import FirebaseFirestore

// MARK: - Food Preferences

struct FoodPreferences: Codable, Equatable {
    var allergies: [String]
    var intolerances: [String]
    var dislikes: [String]
    var favorites: [String]

    init(allergies: [String] = [], intolerances: [String] = [],
         dislikes: [String] = [], favorites: [String] = []) {
        self.allergies    = allergies
        self.intolerances = intolerances
        self.dislikes     = dislikes
        self.favorites    = favorites
    }

    var isEmpty: Bool {
        allergies.isEmpty && intolerances.isEmpty && dislikes.isEmpty && favorites.isEmpty
    }
}

// MARK: - Preference Category

enum FoodPreferenceCategory: String, CaseIterable, Identifiable {
    case allergies    = "Allergien"
    case intolerances = "Unverträglichkeiten"
    case dislikes     = "Mag ich nicht"
    case favorites    = "Ich liebe"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .allergies:    return "exclamationmark.triangle.fill"
        case .intolerances: return "minus.circle.fill"
        case .dislikes:     return "hand.thumbsdown.fill"
        case .favorites:    return "heart.fill"
        }
    }

    var swiftUIColor: String {
        switch self {
        case .allergies:    return "danger"
        case .intolerances: return "warning"
        case .dislikes:     return "textSecondary"
        case .favorites:    return "success"
        }
    }

    static let predefinedOptions: [FoodPreferenceCategory: [String]] = [
        .allergies: [
            "Nüsse", "Erdnüsse", "Gluten", "Weizen", "Eier", "Milch",
            "Fisch", "Meeresfrüchte", "Soja", "Sesam", "Sellerie",
            "Senf", "Lupinen", "Sulfite"
        ],
        .intolerances: [
            "Laktose", "Fruktose", "Histamin", "Sorbit", "Gluten",
            "FODMAP", "Koffein"
        ],
        .dislikes: [
            "Rosenkohl", "Brokkoli", "Leber", "Innereien", "Randen",
            "Oliven", "Anchovis", "Koriander", "Fenchel", "Tofu",
            "Sauerkraut", "Blumenkohl", "Spinat", "Pilze"
        ],
        .favorites: [
            "Pasta", "Pizza", "Sushi", "Curry", "Salat", "Suppe",
            "Risotto", "Burger", "Wraps", "Bowl", "Asiatisch",
            "Mediterran", "Vegetarisch", "Vegan"
        ]
    ]
}

// MARK: - User

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var firstName: String
    var lastName: String
    var photoURL: String?
    var photoBase64: String?
    var canCook: Bool
    var foodPreferences: FoodPreferences
    var createdAt: Date

    init(id: String? = nil,
         firstName: String,
         lastName: String,
         photoURL: String? = nil,
         photoBase64: String? = nil,
         canCook: Bool = false,
         foodPreferences: FoodPreferences = FoodPreferences(),
         createdAt: Date = Date()) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.photoURL = photoURL
        self.photoBase64 = photoBase64
        self.canCook = canCook
        self.foodPreferences = foodPreferences
        self.createdAt = createdAt
    }

    var fullName: String { "\(firstName) \(lastName)" }

    var initials: String {
        let f = firstName.first.map(String.init) ?? ""
        let l = lastName.first.map(String.init) ?? ""
        return "\(f)\(l)".uppercased()
    }
}
