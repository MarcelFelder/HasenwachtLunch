//
//  CurrentUserService.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//
//  Verwaltet das Profil des aktuell eingeloggten Users.
//  Reagiert auf Auth-Änderungen und lädt das passende Firestore-Dokument.
//

import Foundation
import Observation

@Observable
final class CurrentUserService {

    // MARK: - Singleton

    static let shared = CurrentUserService()
    private init() {}

    // MARK: - Reaktiver State

    /// Das aktuell geladene User-Profil. Nil heisst: nicht eingeloggt
    /// oder Profil noch nicht geladen.
    var currentUser: User?

    /// True, sobald wir mindestens einmal geprüft haben, ob ein Profil existiert.
    /// Verhindert "ProfileSetup blinkt kurz auf"-Effekte beim App-Start.
    var didCheckProfile: Bool = false

    /// True, während gerade geladen oder gespeichert wird.
    var isLoading: Bool = false

    /// Letzte Fehlermeldung, falls etwas schiefging.
    var errorMessage: String?

    // MARK: - Profil laden

    /// Lädt das User-Profil für die gegebene UID.
    /// Gibt true zurück, wenn ein Profil existiert.
    @discardableResult
    func loadProfile(userId: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if let user = try await UserService.shared.fetchUser(userId: userId) {
                currentUser = user
                didCheckProfile = true
                return true
            } else {
                currentUser = nil
                didCheckProfile = true
                return false
            }
        } catch {
            errorMessage = "Profil konnte nicht geladen werden: \(error.localizedDescription)"
            didCheckProfile = true
            return false
        }
    }

    // MARK: - Profil anlegen

    /// Legt ein neues User-Profil an (typischerweise nach erstem Login).
    func createProfile(userId: String, firstName: String, lastName: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let newUser = User(
            id: userId,
            firstName: firstName,
            lastName: lastName,
            canCook: false
        )

        try await UserService.shared.saveUser(newUser)
        currentUser = newUser
        didCheckProfile = true
    }

    // MARK: - Profil aktualisieren

    /// Aktualisiert Name und/oder Foto des aktuellen Users.
    func updateProfile(firstName: String, lastName: String, photoBase64: String?, canCook: Bool) async throws {
        guard let userId = currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        try await UserService.shared.updateProfile(
            userId: userId,
            firstName: firstName,
            lastName: lastName,
            photoBase64: photoBase64,
            canCook: canCook
        )

        currentUser?.firstName = firstName
        currentUser?.lastName = lastName
        currentUser?.canCook = canCook
        if let photo = photoBase64 {
            currentUser?.photoBase64 = photo
        }
    }

    // MARK: - Reset bei Logout

    /// Räumt den State auf, wenn sich jemand ausloggt.
    func clear() {
        currentUser = nil
        didCheckProfile = false
        errorMessage = nil
    }
}
