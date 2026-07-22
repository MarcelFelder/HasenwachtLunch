//
//  FirestoreRESTClient.swift
//  HasenwachtWidget
//
//  Minimaler Firestore-REST-Client für die Widget-Extension. Wir binden bewusst
//  NICHT das volle Firebase SDK ein (Binary-Size, WidgetKit-Zeitbudget) —
//  stattdessen sprechen wir die Firestore REST API direkt mit einem
//  Bearer-ID-Token an.
//
//  Doku: https://firebase.google.com/docs/firestore/reference/rest
//

import Foundation

enum FirestoreRESTClient {

    enum ClientError: Error {
        case invalidResponse
        case http(Int)
    }

    private static var baseURL: String {
        "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectId)/databases/(default)/documents"
    }

    /// Lädt ein einzelnes Dokument. Gibt `nil` zurück, wenn es nicht existiert
    /// (das ist im Datenmodell dieser App der Normalfall für "Default-Wert").
    static func getDocument(path: String, idToken: String) async throws -> [String: Any]? {
        guard let url = URL(string: "\(baseURL)/\(path)") else { throw ClientError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }

        if http.statusCode == 404 { return nil }
        guard (200...299).contains(http.statusCode) else { throw ClientError.http(http.statusCode) }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = json["fields"] as? [String: Any]
        else { return nil }

        return FirestoreValueCodec.decode(fields: fields)
    }

    /// Merge-Write (analog zu `setData(merge: true)`): nur die übergebenen Felder
    /// werden geändert/angelegt, alles andere im Dokument bleibt unangetastet.
    static func patchDocument(path: String, fields: [String: Any], idToken: String) async throws {
        guard var components = URLComponents(string: "\(baseURL)/\(path)") else {
            throw ClientError.invalidResponse
        }
        components.queryItems = fields.keys.map { URLQueryItem(name: "updateMask.fieldPaths", value: $0) }
        guard let url = components.url else { throw ClientError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = 8
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "fields": FirestoreValueCodec.encode(fields: fields)
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw ClientError.http(http.statusCode)
        }
        _ = data
    }
}

/// Kodiert/dekodiert zwischen Firestores getypten JSON-Werten
/// (`{"booleanValue": true}`, `{"timestampValue": "..."}`, ...) und einfachen
/// Swift-Werten (Bool, String, Double, Date, [Int]).
private enum FirestoreValueCodec {

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func decode(fields: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in fields {
            guard let wrapper = value as? [String: Any] else { continue }
            result[key] = decodeValue(wrapper)
        }
        return result
    }

    private static func decodeValue(_ wrapper: [String: Any]) -> Any? {
        if let string = wrapper["stringValue"] as? String { return string }
        if let bool = wrapper["booleanValue"] as? Bool { return bool }
        if let intString = wrapper["integerValue"] as? String { return Int(intString) }
        if let double = wrapper["doubleValue"] as? Double { return double }
        if let timestamp = wrapper["timestampValue"] as? String {
            return isoFormatter.date(from: timestamp) ?? isoFormatterNoFraction.date(from: timestamp)
        }
        if let array = wrapper["arrayValue"] as? [String: Any] {
            let values = array["values"] as? [[String: Any]] ?? []
            return values.compactMap { decodeValue($0) }
        }
        if wrapper["nullValue"] != nil { return nil }
        return nil
    }

    static func encode(fields: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in fields {
            result[key] = encodeValue(value)
        }
        return result
    }

    private static func encodeValue(_ value: Any) -> [String: Any] {
        switch value {
        case let string as String:
            return ["stringValue": string]
        case let bool as Bool:
            return ["booleanValue": bool]
        case let date as Date:
            return ["timestampValue": isoFormatter.string(from: date)]
        case let int as Int:
            return ["integerValue": String(int)]
        case let double as Double:
            return ["doubleValue": double]
        default:
            return ["nullValue": NSNull()]
        }
    }
}
