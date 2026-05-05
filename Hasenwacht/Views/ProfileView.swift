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

    // MARK: - State

    @State private var notificationsEnabled: Bool = true
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
                Section("Benachrichtigungen") {
                    Toggle("Reminder am Vorabend", isOn: $notificationsEnabled)
                        .disabled(true)
                }

                // Logout
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Abmelden")
                            Spacer()
                        }
                    }
                }

                // Fehlermeldung bei Logout-Problemen
                if let logoutErrorMessage {
                    Section {
                        Text(logoutErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
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
}
