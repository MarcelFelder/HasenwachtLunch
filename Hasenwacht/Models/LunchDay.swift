//
//  LunchDay.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//

import Foundation
import FirebaseFirestore

struct LunchDay: Identifiable, Codable {
    @DocumentID var id: String?
    var date: Date
    var isHoliday: Bool
    var holidayName: String?
    var forceLunch: Bool
    var activatedBy: String?
    
    var hasLunch: Bool {
        !isHoliday || forceLunch
    }
}
