//
//  CryptoHelper.swift
//  Hasenwacht
//
//  Helper-Funktionen für die Sicherheits-Mechanik bei Sign in with Apple.
//  Generiert eine Nonce (Einmal-Wert) und deren SHA256-Hash.
//

import Foundation
import CryptoKit

enum CryptoHelper {

    /// Erzeugt eine zufällige Nonce-Zeichenkette der angegebenen Länge.
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    /// Erzeugt den SHA256-Hash der gegebenen Zeichenkette als Hex-String.
    /// Den schickt deine App an Apple, die unverschlüsselte Nonce an Firebase.
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
    }
}
