//
//  UserService.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//
//  Kapselt alle Firestore-Operationen für die User-Collection.
//  Views sprechen NICHT direkt mit Firestore, sondern mit diesem Service.
//

import Foundation
import FirebaseFirestore

final class UserService {

    // MARK: - Singleton

    static let shared = UserService()
    private init() {}

    // MARK: - Firestore-Referenz

    private let db = Firestore.firestore()
    private var usersCollection: CollectionReference {
        db.collection("users")
    }

    // MARK: - User speichern

    /// Erstellt oder aktualisiert ein User-Dokument in Firestore.
    func saveUser(_ user: User) async throws {
        guard let userId = user.id else {
            throw UserServiceError.missingUserId
        }
        try usersCollection.document(userId).setData(from: user, merge: true)
    }

    /// Aktualisiert Name und optional Foto eines bestehenden Users.
    func updateProfile(userId: String, firstName: String, lastName: String,
                       photoBase64: String?, canCook: Bool) async throws {
        var data: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "canCook": canCook
        ]
        if let photo = photoBase64 {
            data["photoBase64"] = photo
        }
        try await usersCollection.document(userId).updateData(data)
    }

    // MARK: - Einzelnen User laden

    /// Lädt einen einzelnen User per ID.
    /// Gibt nil zurück, wenn der User noch nicht in Firestore existiert.
    func fetchUser(userId: String) async throws -> User? {
        let snapshot = try await usersCollection.document(userId).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: User.self)
    }

    // MARK: - Alle User laden

    /// Lädt alle registrierten Bewohner.
    func fetchAllUsers() async throws -> [User] {
        let snapshot = try await usersCollection.getDocuments()
        return try snapshot.documents.compactMap { document in
            try document.data(as: User.self)
        }
    }

    // MARK: - Listener für alle User

    /// Hört auf Änderungen in der gesamten User-Collection.
    /// Wird bei jeder Änderung gefeuert (neuer User, geänderter Name, etc.).
    func observeAllUsers(onChange: @escaping ([User]) -> Void) -> ListenerRegistration {
        return usersCollection.addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else {
                onChange([])
                return
            }
            let users = documents.compactMap { document in
                try? document.data(as: User.self)
            }
            onChange(users)
        }
    }
}

// MARK: - Fehlerdefinition

enum UserServiceError: Error {
    case missingUserId
}
