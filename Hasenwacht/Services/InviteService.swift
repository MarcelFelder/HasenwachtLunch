//
//  InviteService.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 19.05.2026.
//
//  Prüft den Einladungscode gegen Firestore.
//  Der Code wird in /config/inviteCode gespeichert und kann
//  jederzeit in der Firebase Console geändert werden.
//

import Foundation
import FirebaseFirestore

final class InviteService {

    static let shared = InviteService()
    private init() {}

    private let db = Firestore.firestore()

    /// Prüft ob der eingegebene Code korrekt ist.
    func verify(code: String) async throws -> Bool {
        let doc = try await db.collection("config").document("inviteCode").getDocument()
        guard let storedCode = doc.data()?["code"] as? String else {
            throw InviteError.configNotFound
        }
        return code.trimmingCharacters(in: .whitespaces).lowercased()
            == storedCode.trimmingCharacters(in: .whitespaces).lowercased()
    }

    /// Markiert den User als approved in Firestore.
    func approveUser(userId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "isApproved": true
        ])
    }
}

enum InviteError: LocalizedError {
    case configNotFound
    case wrongCode

    var errorDescription: String? {
        switch self {
        case .configNotFound: return "Konfiguration nicht gefunden. Bitte Administrator kontaktieren."
        case .wrongCode:      return "Falscher Code. Bitte erneut versuchen."
        }
    }
}
