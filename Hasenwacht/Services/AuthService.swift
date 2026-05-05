//
//  AuthService.swift
//  Hasenwacht
//
//  Kapselt Sign in with Apple und Firebase Authentication.
//  Stellt den aktuellen Login-Status reaktiv für SwiftUI bereit.
//

import Foundation
import AuthenticationServices
import FirebaseAuth
import CryptoKit

@Observable
final class AuthService: NSObject {

    // MARK: - Singleton

    static let shared = AuthService()

    // MARK: - Reaktiver State

    /// Die userId des aktuell eingeloggten Users (Firebase UID).
    /// Ist nil, wenn niemand eingeloggt ist.
    var currentUserId: String?

    /// True, sobald wir den initialen Auth-Status geprüft haben.
    /// Verhindert "Login-Screen kurz aufblinken" beim App-Start.
    var didCheckInitialAuth: Bool = false
    
    /// Vorname und Nachname, die Apple beim ersten Login geliefert hat.
    /// Werden beim Profil-Setup als Vorschlagswerte verwendet.
    /// Apple liefert diese Daten nur bei der allerersten Anmeldung.
    var pendingFirstName: String?
    var pendingLastName: String?

    // MARK: - Privater State

    /// Aktueller Nonce für den laufenden Login-Versuch.
    private var currentNonce: String?

    // MARK: - Init

    private override init() {
        super.init()
        // observeAuthChanges() wird explizit nach FirebaseApp.configure() aufgerufen.
    }

    // MARK: - Auth-State beobachten

    /// Startet den Auth-State-Listener.
    /// MUSS nach FirebaseApp.configure() aufgerufen werden, sonst crasht die App.
    func start() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.currentUserId = user?.uid
            self?.didCheckInitialAuth = true
        }
    }

    // MARK: - Login-Flow starten

    /// Bereitet eine Apple-Sign-in-Anfrage vor.
    /// Wird von der View aufgerufen, um den Apple-Dialog zu zeigen.
    func prepareSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = CryptoHelper.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = CryptoHelper.sha256(nonce)
    }

    /// Verarbeitet das Resultat des Apple-Dialogs.
    /// Wandelt das Apple-Token in einen Firebase-Login um.
    func handleSignInCompletion(_ result: Result<ASAuthorization, Error>) async throws {
        switch result {
        case .success(let authorization):
            try await processAppleAuthorization(authorization)
        case .failure(let error):
            throw error
        }
    }

    private func processAppleAuthorization(_ authorization: ASAuthorization) async throws {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthServiceError.invalidCredential
        }
        guard let nonce = currentNonce else {
            throw AuthServiceError.missingNonce
        }
        guard let appleIDToken = appleIDCredential.identityToken else {
            throw AuthServiceError.missingIdentityToken
        }
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthServiceError.invalidIdentityToken
        }

        // Apple-Namen für späteres Profil-Setup zwischenspeichern.
        // Apple liefert diese Daten nur bei der ersten Anmeldung.
        if let fullName = appleIDCredential.fullName {
            pendingFirstName = fullName.givenName
            pendingLastName = fullName.familyName
        }
        
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        // Firebase-Login durchführen
        try await Auth.auth().signIn(with: credential)

        // Nonce zurücksetzen
        currentNonce = nil
    }

    // MARK: - Logout

    func signOut() throws {
        pendingFirstName = nil
        pendingLastName = nil
        try Auth.auth().signOut()
    }
}

// MARK: - Fehlerdefinition

enum AuthServiceError: LocalizedError {
    case invalidCredential
    case missingNonce
    case missingIdentityToken
    case invalidIdentityToken

    var errorDescription: String? {
        switch self {
        case .invalidCredential:    return "Ungültige Apple-Anmeldedaten."
        case .missingNonce:         return "Sicherheits-Nonce fehlt."
        case .missingIdentityToken: return "Apple Identity Token fehlt."
        case .invalidIdentityToken: return "Apple Identity Token ist ungültig."
        }
    }
}
