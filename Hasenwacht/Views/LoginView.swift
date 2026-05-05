//
//  LoginView.swift
//  Hasenwacht
//
//  Created by Marcel Felder on 05.05.2026.
//
//  Erster Screen der App. Zeigt den "Sign in with Apple"-Button
//  und delegiert den Login-Flow an den AuthService.
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {

    // MARK: - State

    @State private var errorMessage: String?
    @State private var isProcessing: Bool = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App-Logo / Titel
            VStack(spacing: 12) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.tint)

                Text("Hasenwacht")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Mittagessen-Eintragung")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Login-Button
            VStack(spacing: 16) {
                SignInWithAppleButton(
                    onRequest: { request in
                        AuthService.shared.prepareSignInRequest(request)
                    },
                    onCompletion: { result in
                        Task { await handleCompletion(result) }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isProcessing)

                if isProcessing {
                    ProgressView()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }

            // Datenschutz-Hinweis
            Text("Mit der Anmeldung akzeptierst du, dass deine Daten zur App-Nutzung gespeichert werden.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    // MARK: - Login-Verarbeitung

    private func handleCompletion(_ result: Result<ASAuthorization, Error>) async {
        isProcessing = true
        errorMessage = nil
        do {
            try await AuthService.shared.handleSignInCompletion(result)
            // Erfolg: AuthService.currentUserId wird automatisch gesetzt,
            // App-Routing kümmert sich um den Wechsel zur Hauptansicht.
        } catch {
            errorMessage = "Anmeldung fehlgeschlagen: \(error.localizedDescription)"
        }
        isProcessing = false
    }
}

#Preview {
    LoginView()
}
