//
//  FirebaseTokenRefresher.swift
//  HasenwachtWidget
//
//  Tauscht den in der App-Group-Keychain gespeicherten Firebase-Refresh-Token
//  per REST gegen ein kurzlebiges ID-Token — ohne das Firebase SDK in die
//  Extension einzubinden (Binary-Size, WidgetKit-Zeitbudget).
//
//  Endpunkt-Doku: https://firebase.google.com/docs/reference/rest/auth#section-refresh-token
//

import Foundation

enum FirebaseTokenRefresher {

    enum TokenError: Error {
        case notSignedIn
        case refreshFailed
        case invalidResponse
    }

    /// Liefert ein gültiges ID-Token, entweder aus dem Keychain-Cache oder
    /// frisch getauscht, falls das gecachte Token abgelaufen (oder nicht vorhanden) ist.
    static func validIdToken() async throws -> String {
        guard let credentials = SharedKeychain.load() else {
            throw TokenError.notSignedIn
        }

        if let cachedIdToken = credentials.cachedIdToken,
           let expiresAt = credentials.cachedIdTokenExpiresAt,
           expiresAt > Date().addingTimeInterval(60) {
            return cachedIdToken
        }

        return try await refresh(credentials: credentials)
    }

    private static func refresh(credentials: SharedKeychain.StoredCredentials) async throws -> String {
        guard !FirebaseConfig.apiKey.isEmpty else { throw TokenError.invalidResponse }

        var request = URLRequest(
            url: URL(string: "https://securetoken.googleapis.com/v1/token?key=\(FirebaseConfig.apiKey)")!
        )
        request.httpMethod = "POST"
        request.timeoutInterval = 8
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyString = "grant_type=refresh_token&refresh_token=\(credentials.refreshToken)"
        request.httpBody = Data(bodyString.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TokenError.refreshFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["id_token"] as? String,
              let newRefreshToken = json["refresh_token"] as? String,
              let expiresInString = json["expires_in"] as? String,
              let expiresIn = TimeInterval(expiresInString),
              let userId = json["user_id"] as? String
        else {
            throw TokenError.invalidResponse
        }

        let updated = SharedKeychain.StoredCredentials(
            userId: userId,
            refreshToken: newRefreshToken,
            cachedIdToken: idToken,
            cachedIdTokenExpiresAt: Date().addingTimeInterval(expiresIn)
        )
        SharedKeychain.save(updated)
        return idToken
    }
}
