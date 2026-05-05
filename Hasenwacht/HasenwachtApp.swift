//
//  HasenwachtApp.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 04.05.2026.

import SwiftUI
import FirebaseCore

@main
struct HasenwachtApp: App {

    @State private var authService: AuthService

    init() {
        // 1. Firebase konfigurieren
        FirebaseApp.configure()

        // 2. AuthService initialisieren (kein Firebase-Zugriff im init)
        let service = AuthService.shared

        // 3. Listener explizit starten – jetzt darf Firebase verwendet werden
        service.start()

        // 4. SwiftUI-State setzen
        _authService = State(initialValue: service)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
        }
    }
}

struct RootView: View {

    @Environment(AuthService.self) private var authService

    var body: some View {
        Group {
            if !authService.didCheckInitialAuth {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if authService.currentUserId == nil {
                LoginView()
            } else {
                LunchOverviewView()
            }
        }
    }
}
