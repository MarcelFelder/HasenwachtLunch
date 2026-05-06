//
//  ProfileView.swift
//  Hasenwacht
//
//  Profil-Screen: eigene Daten, Notification-Toggle, Logout.
//

import SwiftUI

struct ProfileView: View {

    // MARK: - Environment

    @Environment(CurrentUserService.self) private var currentUserService
    @Environment(NotificationService.self) private var notificationService

    // MARK: - State

    @State private var showLogoutConfirmation: Bool = false
    @State private var logoutErrorMessage: String?

    // MARK: - Computed

    private var user: User? {
        currentUserService.currentUser
    }

    private var initials: String {
        user?.initials ?? "?"
    }

    private var displayName: String {
        user?.fullName ?? "Unbekannt"
    }

    // MARK: - Body

    var body: some View {
        @Bindable var notifications = notificationService
        
        NavigationStack {
            Form {
                // Avatar-Bereich oben
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Text(initials)
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 100, height: 100)
                                .background(user?.avatarColor ?? .gray)
                                .clipShape(Circle())

                            Text(displayName)
                                .font(.headline)

                            Button("Foto ändern") {
                                // Phase 5: Foto-Picker
                            }
                            .font(.subheadline)
                            .disabled(true)
                            .opacity(0.5)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // Notification-Einstellung
                // Notification-Einstellung
                Section {
                    Toggle("Reminder am Vorabend", isOn: $notifications.remindersEnabled)
                        .disabled(notifications.authorizationStatus != .authorized)
                    
                    // Hinweis, falls Permission verweigert wurde
                    if notifications.authorizationStatus == .denied {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Benachrichtigungen sind in den iOS-Einstellungen deaktiviert.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Text("Einstellungen öffnen")
                                    .font(.caption)
                            }
                        }
                    } else if notifications.authorizationStatus == .notDetermined {
                        Button {
                            Task { await notificationService.requestAuthorization() }
                        } label: {
                            Text("Benachrichtigungen aktivieren")
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Benachrichtigungen")
                } footer: {
                    Text("Du erhältst um 19:00 Uhr eine Erinnerung – nicht am Wochenende oder vor Feiertagen.")
                }
            }
            .navigationTitle("Profil")
            .confirmationDialog(
                "Wirklich abmelden?",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Abmelden", role: .destructive) {
                    performLogout()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Du kannst dich später jederzeit wieder anmelden.")
            }
        }
    }

    // MARK: - Logout-Logik

    private func performLogout() {
        logoutErrorMessage = nil
        do {
            NotificationService.shared.cancelAllReminders()   // ← NEU
            try AuthService.shared.signOut()
            CurrentUserService.shared.clear()
        } catch {
            logoutErrorMessage = "Abmelden fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ProfileView()
        .environment(CurrentUserService.shared)
        .environment(NotificationService.shared)
}
