//
//  HasenwachtApp.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 04.05.2026.
//

import SwiftUI
import FirebaseCore

@main
struct HasenwachtApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
