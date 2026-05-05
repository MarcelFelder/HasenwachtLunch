//
//  HasenwachtApp.swift
//  Hasenwacht
//

import SwiftUI
import FirebaseCore

@main
struct HasenwachtApp: App {

    @State private var authService: AuthService
    @State private var currentUserService: CurrentUserService

    init() {
        // 1. Firebase konfigurieren – zwingend zuerst
        FirebaseApp.configure()

        // 2. Services initialisieren
        let auth = AuthService.shared
        auth.start()

        let currentUser = CurrentUserService.shared

        // 3. SwiftUI-State setzen
        _authService = State(initialValue: auth)
        _currentUserService = State(initialValue: currentUser)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(currentUserService)
        }
    }
}

// MARK: - Root-Routing

/// Entscheidet basierend auf Auth- und Profil-Status, welcher Screen sichtbar ist.
struct RootView: View {

    @Environment(AuthService.self) private var authService
    @Environment(CurrentUserService.self) private var currentUserService

    var body: some View {
        Group {
            if !authService.didCheckInitialAuth {
                // Firebase prüft noch, ob es eine bestehende Session gibt
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if authService.currentUserId == nil {
                // Niemand eingeloggt
                LoginView()

            } else if !currentUserService.didCheckProfile {
                // Eingeloggt, aber Profil-Status noch nicht geprüft
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if currentUserService.currentUser == nil {
                // Eingeloggt, aber noch kein Profil – Setup zeigen
                ProfileSetupView()

            } else {
                // Eingeloggt mit Profil – Hauptansicht
                MainTabView()
            }
        }
        .onChange(of: authService.currentUserId, initial: true) { _, newUserId in
            handleAuthChange(userId: newUserId)
        }
    }

    private func handleAuthChange(userId: String?) {
        if let userId {
            Task {
                await currentUserService.loadProfile(userId: userId)
                await MainActor.run {
                    LunchDaysViewModel.shared.updateUserId(userId)
                    LunchDaysViewModel.shared.start()
                }
            }
        } else {
            LunchDaysViewModel.shared.stop()
            currentUserService.clear()
        }
    }
}
