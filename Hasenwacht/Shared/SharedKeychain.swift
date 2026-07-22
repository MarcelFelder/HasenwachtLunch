//
//  SharedKeychain.swift
//  Hasenwacht
//
//  Teilt den Firebase-Auth-Zustand (Refresh-Token + kurzlebiges ID-Token-Cache)
//  zwischen App und Widget-Extension über die App-Group-Keychain (Keychain
//  Sharing). Bewusst NICHT über UserDefaults, da es sich um Auth-Secrets handelt.
//

import Foundation
import Security

enum SharedKeychain {

    struct StoredCredentials: Codable {
        var userId: String
        var refreshToken: String
        /// Kurzlebiges ID-Token-Cache (siehe FirebaseTokenRefresher), damit die
        /// Extension nicht bei jedem Timeline-Reload neu gegen securetoken.googleapis.com
        /// tauschen muss.
        var cachedIdToken: String?
        var cachedIdTokenExpiresAt: Date?
    }

    private static let service = "com.marcelfelder.hasenwacht.firebaseAuth"
    private static let account = "currentUser"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: AppGroupConstants.keychainAccessGroup
        ]
    }

    static func save(_ credentials: StoredCredentials) {
        guard let data = try? JSONEncoder().encode(credentials) else { return }

        SecItemDelete(baseQuery as CFDictionary)

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func load() -> StoredCredentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredCredentials.self, from: data)
    }

    static func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}
