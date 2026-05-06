//
//  ProfileSetupView.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//
//  Wird angezeigt nach erstem erfolgreichen Login, wenn noch kein User-Profil
//  in Firestore existiert. Erfasst Vor- und Nachname.
//

import SwiftUI

struct ProfileSetupView: View {

    // MARK: - Environment

    @Environment(AuthService.self) private var authService
    @Environment(CurrentUserService.self) private var currentUserService
    @Environment(NotificationService.self) private var notificationService

    // MARK: - State

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    // MARK: - Computed

    private var canSave: Bool {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)
        return !trimmedFirst.isEmpty && !trimmedLast.isEmpty && !isSaving
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 64))
                        .foregroundStyle(.tint)

                    Text("Willkommen!")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Wie sollen dich die anderen nennen?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 16) {
                    TextField("Vorname", text: $firstName)
                        .textContentType(.givenName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()

                    TextField("Nachname", text: $lastName)
                        .textContentType(.familyName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Profil speichern")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canSave ? Color.accentColor : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canSave)
                .padding(.horizontal)
            }
            .padding()
            .navigationBarBackButtonHidden(true)
            .onAppear { prefillFromAppleIfAvailable() }
        }
    }

    // MARK: - Logik

    private func prefillFromAppleIfAvailable() {
        if firstName.isEmpty, let appleFirst = authService.pendingFirstName {
            firstName = appleFirst
        }
        if lastName.isEmpty, let appleLast = authService.pendingLastName {
            lastName = appleLast
        }
    }

    private func save() async {
        guard let userId = authService.currentUserId else {
            errorMessage = "Anmeldung scheint abgelaufen zu sein. Bitte erneut anmelden."
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)

        do {
            try await currentUserService.createProfile(
                userId: userId,
                firstName: trimmedFirst,
                lastName: trimmedLast
            )
            
            // Permission anfragen, wenn noch nicht entschieden.
            // Wichtig: NACH erfolgreichem Profil-Setup, damit der User den Mehrwert versteht.
            if notificationService.authorizationStatus == .notDetermined {
                await notificationService.requestAuthorization()
            }
            
            // Routing reagiert automatisch auf currentUserService.currentUser != nil.
        } catch {
            errorMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ProfileSetupView()
        .environment(AuthService.shared)
        .environment(CurrentUserService.shared)
        .environment(NotificationService.shared)
}
