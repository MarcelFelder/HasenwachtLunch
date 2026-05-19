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
        FirebaseApp.configure()

        let auth = AuthService.shared
        auth.start()

        let currentUser = CurrentUserService.shared
        let notifications = NotificationService.shared
        notifications.start()
        let onboarding = OnboardingService.shared

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

struct RootView: View {

    @Environment(AuthService.self) private var authService
    @Environment(CurrentUserService.self) private var currentUserService
    @Environment(OnboardingService.self) private var onboardingService

    var body: some View {
        Group {
            // WICHTIG: Onboarding immer zuerst prüfen — vor allem anderen
            if !onboardingService.hasCompletedOnboarding {
                OnboardingView()

            } else if !authService.didCheckInitialAuth {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.Colors.surface.ignoresSafeArea())

            } else if authService.currentUserId == nil {
                LoginView()

            } else if !currentUserService.didCheckProfile {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.Colors.surface.ignoresSafeArea())

            } else if currentUserService.currentUser == nil {
                ProfileSetupView()

            } else if currentUserService.currentUser?.isApproved != true {
                InviteCodeView()

            } else {
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
                    AbsenceViewModel.shared.start(userId: userId)
                    CookingViewModel.shared.start(userId: userId)
                    // StatsViewModel wird lazy beim Tab-Öffnen gestartet
                    // da es Users aus LunchDaysViewModel braucht
                }
            }
        } else {
            LunchDaysViewModel.shared.stop()
            AbsenceViewModel.shared.stop()
            CookingViewModel.shared.stop()
            currentUserService.clear()
            NotificationService.shared.cancelAllReminders()
        }
    }
}
