//
//  FirebaseConfig.swift
//  HasenwachtWidget
//
//  Liest Projekt-ID und Web-API-Key zur Laufzeit aus der mitgebündelten
//  GoogleService-Info.plist (dieselbe Datei wie im App-Target). So muss keine
//  zweite Kopie dieser Werte im Widget-Code gepflegt werden.
//
//  Kein Firebase SDK in dieser Extension — nur die REST-Endpunkte, die das SDK
//  intern auch verwendet (securetoken.googleapis.com, firestore.googleapis.com).
//

import Foundation

enum FirebaseConfig {

    private static let plist: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return [:] }
        return dict
    }()

    static var projectId: String { plist["PROJECT_ID"] as? String ?? "" }
    static var apiKey: String { plist["API_KEY"] as? String ?? "" }
}
