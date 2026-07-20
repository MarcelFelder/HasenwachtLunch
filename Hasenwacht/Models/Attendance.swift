//
//  Attendance.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//

import Foundation
import FirebaseFirestore

struct Attendance: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var date: Date
    var isAttending: Bool
    var updatedAt: Date
    
    static func documentId(userId: String, date: Date) -> String {
        "\(userId)_\(Self.dayFormatter.string(from: date))"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "Europe/Zurich")
        return formatter
    }()
}
