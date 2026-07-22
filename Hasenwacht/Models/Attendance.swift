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
        "\(userId)_\(LunchPhaseCalculator.dayDocumentId(for: date))"
    }
}
