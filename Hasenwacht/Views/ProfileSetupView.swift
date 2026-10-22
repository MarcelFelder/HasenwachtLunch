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
            ZStack {
                DS.Colors.surface.ignoresSafeArea()

                VStack(spacing: DS.Spacing.xl) {
                    Spacer()

                    VStack(spacing: DS.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(DS.Colors.primarySurface)
                                .frame(width: 110, height: 110)
                            Image(systemName: "person.crop.circle.badge.plus")
                                .font(.system(size: 44, weight: .light))
                                .foregroundStyle(DS.Colors.primaryDark)
                        }

                        VStack(spacing: DS.Spacing.xs) {
                            Text("Willkommen!")
                                .font(DS.Typography.title)
                                .foregroundStyle(DS.Colors.textPrimary)

                            Text("Wie sollen dich die anderen nennen?")
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    VStack(spacing: 0) {
                        TextField("Vorname", text: $firstName)
                            .textContentType(.givenName)
                            .font(DS.Typography.body)
                            .tint(DS.Colors.primary)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(DS.Colors.background)

                        Divider().background(DS.Colors.border).padding(.leading, 16)

                        TextField("Nachname", text: $lastName)
                            .textContentType(.familyName)
                            .font(DS.Typography.body)
                            .tint(DS.Colors.primary)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(DS.Colors.background)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl).stroke(DS.Colors.border, lineWidth: 1))
                    .padding(.horizontal, DS.Spacing.md)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.danger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DS.Spacing.md)
                    }

                    Spacer()

                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            Text("Profil speichern")
                                .font(DS.Typography.subheading)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(DS.Colors.primary)
                    .disabled(!canSave)
                    .padding(.horizontal, DS.Spacing.md)
                }
                .padding(DS.Spacing.lg)
            }
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
