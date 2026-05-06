//
//  LoginView.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//
//  Login-Screen für User, die das Onboarding bereits gesehen haben.
//  Wird angezeigt, wenn jemand sich ausloggt und neu anmelden möchte.
//  Für Erstnutzer ist der Login in den OnboardingFlow integriert.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {

    // MARK: - Environment

    @Environment(AuthService.self) private var authService

    // MARK: - State

    @State private var errorMessage: String?
    @State private var isProcessing: Bool = false

    // MARK: - Body

    var body: some View {
        ZStack {
            DS.Colors.surface.ignoresSafeArea()

            VStack(spacing: DS.Spacing.xl) {
                Spacer()

                logoSection

                Spacer()

                loginSection

                privacyNote

                Spacer()
            }
            .padding(DS.Spacing.lg)
        }
    }

    // MARK: - Logo & Titel

    private var logoSection: some View {
        VStack(spacing: DS.Spacing.md) {
            iconCircle

            VStack(spacing: DS.Spacing.xs) {
                Text("Hasenwacht")
                    .font(DS.Typography.title)
                    .foregroundColor(DS.Colors.textPrimary)

                Text("Mittagessen-Eintragung")
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.textSecondary)
            }
        }
    }

    /// Icon-Kreis im Onboarding-Stil – schafft visuelle Kontinuität.
    private var iconCircle: some View {
        ZStack {
            // Dekorative Punkte
            Circle()
                .fill(DS.Colors.primaryLight.opacity(0.6))
                .frame(width: 14, height: 14)
                .offset(x: -55, y: -40)

            Circle()
                .fill(DS.Colors.successSurface)
                .frame(width: 18, height: 18)
                .offset(x: 55, y: 30)

            Circle()
                .fill(DS.Colors.primaryLight.opacity(0.4))
                .frame(width: 10, height: 10)
                .offset(x: 50, y: -30)

            // Hauptkreis
            Circle()
                .fill(DS.Colors.primarySurface)
                .frame(width: 110, height: 110)

            // SF Symbol
            Image(systemName: "fork.knife")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(DS.Colors.primaryDark)
        }
        .frame(width: 110, height: 110)
    }

    // MARK: - Login-Sektion

    private var loginSection: some View {
        VStack(spacing: DS.Spacing.md) {
            SignInWithAppleButton(
                onRequest: { request in
                    authService.prepareSignInRequest(request)
                },
                onCompletion: { result in
                    Task { await handleCompletion(result) }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .disabled(isProcessing)

            if isProcessing {
                ProgressView()
                    .tint(DS.Colors.primary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.sm)
            }
        }
    }

    // MARK: - Datenschutz-Hinweis

    private var privacyNote: some View {
        Text("Mit der Anmeldung akzeptierst du, dass deine Daten zur App-Nutzung gespeichert werden.")
            .font(DS.Typography.caption)
            .foregroundColor(DS.Colors.textTertiary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - Login-Verarbeitung

    private func handleCompletion(_ result: Result<ASAuthorization, Error>) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            try await authService.handleSignInCompletion(result)
            // Erfolg: AuthService.currentUserId wird automatisch gesetzt,
            // App-Routing kümmert sich um den Wechsel zur Hauptansicht.
        } catch {
            errorMessage = "Anmeldung fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView()
        .environment(AuthService.shared)
}
