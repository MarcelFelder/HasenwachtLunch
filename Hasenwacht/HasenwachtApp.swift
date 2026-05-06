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
    @State private var notificationService: NotificationService
    @State private var onboardingService: OnboardingService

    init() {
        // 1. Firebase konfigurieren – zwingend zuerst
        FirebaseApp.configure()

        // 2. Services initialisieren
        let auth = AuthService.shared
        auth.start()

        let currentUser = CurrentUserService.shared

        let notifications = NotificationService.shared
        notifications.start()

        let onboarding = OnboardingService.shared

        // 3. SwiftUI-State setzen
        _authService = State(initialValue: auth)
        _currentUserService = State(initialValue: currentUser)
        _notificationService = State(initialValue: notifications)
        _onboardingService = State(initialValue: onboarding)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(currentUserService)
                .environment(notificationService)
                .environment(onboardingService)
        }
    }
}

// MARK: - Root-Routing

/// Entscheidet basierend auf Onboarding-, Auth- und Profil-Status, welcher Screen sichtbar ist.
///
/// Routing-Reihenfolge:
/// 1. Onboarding noch nicht abgeschlossen UND nicht eingeloggt → OnboardingView (mit Login auf letzter Karte)
/// 2. Eingeloggt, aber Profil-Status noch nicht geprüft → Loading
/// 3. Eingeloggt, aber kein Profil → ProfileSetupView
/// 4. Eingeloggt mit Profil → MainTabView
/// 5. Niemand eingeloggt UND Onboarding bereits gesehen → LoginView (Standard-Login ohne Tutorial)
struct RootView: View {

    @Environment(AuthService.self) private var authService
    @Environment(CurrentUserService.self) private var currentUserService
    @Environment(OnboardingService.self) private var onboardingService

    var body: some View {
        Group {
            if !authService.didCheckInitialAuth {
                // Firebase prüft noch, ob es eine bestehende Session gibt
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.Colors.surface.ignoresSafeArea())

            } else if authService.currentUserId == nil {
                // Niemand eingeloggt
                if !onboardingService.hasCompletedOnboarding {
                    // Erster App-Start: Tutorial mit integriertem Login
                    OnboardingView()
                } else {
                    // Tutorial bereits gesehen, aber jetzt ausgeloggt: nur Login-Screen
                    LoginView()
                }

            } else if !currentUserService.didCheckProfile {
                // Eingeloggt, aber Profil-Status noch nicht geprüft
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.Colors.surface.ignoresSafeArea())

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
            // Erfolgreicher Login: Onboarding sicherheitshalber als abgeschlossen markieren.
            // (Falls ein User den OnboardingFlow per Skip umgangen hat, oder beim
            // Re-Login von einem anderen Gerät.)
            onboardingService.markCompleted()

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
            NotificationService.shared.cancelAllReminders()
        }
    }
}
