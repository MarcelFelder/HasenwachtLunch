//
//  OnboardingView.swift
//  Hasenwacht
//
//  Onboarding-Tutorial mit 4 Karten und Swipe-Navigation.
//  Letzte Karte enthält den Apple-Sign-In-Button.
//
//  Wird beim ersten App-Start gezeigt (gerätegebundene Persistenz).
//

import SwiftUI
import AuthenticationServices

struct OnboardingView: View {

    // MARK: - Environment

    @Environment(AuthService.self) private var authService
    @Environment(OnboardingService.self) private var onboardingService

    // MARK: - State

    @State private var currentIndex: Int = 0
    @State private var loginErrorMessage: String?
    @State private var isProcessingLogin: Bool = false

    // MARK: - Konstanten

    private let totalSlides = 4
    private let lastIndex = 3

    // MARK: - Body

    var body: some View {
        ZStack {
            // Hintergrund
            DS.Colors.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                // Swipebare Karten
                TabView(selection: $currentIndex) {
                    welcomeSlide.tag(0)
                    optOutSlide.tag(1)
                    deadlineSlide.tag(2)
                    loginSlide.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .padding(.horizontal, DS.Spacing.md)
                .animation(.easeInOut(duration: 0.3), value: currentIndex)

                footerBar
            }
        }
    }

    // MARK: - Header (Skip-Link)

    private var headerBar: some View {
        HStack {
            Spacer()
            if currentIndex < lastIndex {
                Button(action: skipToLogin) {
                    Text("Überspringen")
                        .font(DS.Typography.small)
                        .foregroundColor(DS.Colors.primary)
                }
            } else {
                // Platzhalter, damit Layout konsistent bleibt
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.md)
        .frame(height: 32)
    }

    // MARK: - Footer (Pagination + Weiter)

    private var footerBar: some View {
        VStack(spacing: DS.Spacing.md) {
            // Pagination Dots
            HStack(spacing: 6) {
                ForEach(0..<totalSlides, id: \.self) { index in
                    Capsule()
                        .fill(index == currentIndex ? DS.Colors.primary : DS.Colors.border)
                        .frame(width: index == currentIndex ? 20 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: currentIndex)
                }
            }

            // Weiter-Link (nur nicht auf letzter Karte)
            HStack {
                Spacer()
                if currentIndex < lastIndex {
                    Button(action: nextSlide) {
                        Text("Weiter")
                            .font(DS.Typography.subheading)
                            .foregroundColor(DS.Colors.textPrimary)
                    }
                } else {
                    Color.clear.frame(width: 1, height: 24)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .frame(height: 24)
        }
        .padding(.bottom, DS.Spacing.lg)
    }

    // MARK: - Slides

    private var welcomeSlide: some View {
        OnboardingCard(
            iconName: "house.fill",
            title: "Willkommen bei\nHasenwacht",
            description: "Die App fürs gemeinsame Mittagessen im Quartier. Schnell, einfach, ohne Chat."
        )
        .padding(.vertical, DS.Spacing.md)
    }

    private var optOutSlide: some View {
        OnboardingCard(
            iconName: "checkmark.circle.fill",
            title: "Du bist immer\nautomatisch dabei",
            description: "Trag dich nur dann mit einem Tap aus, wenn du nicht zum Mittagessen kommst."
        )
        .padding(.vertical, DS.Spacing.md)
    }

    private var deadlineSlide: some View {
        OnboardingCard(
            iconName: "clock.fill",
            title: "Bis 09:00 Uhr\nBescheid geben",
            description: "Heute austragen geht bis morgens 09 Uhr – dann ist der Einkauf gemacht. Künftige Tage immer."
        )
        .padding(.vertical, DS.Spacing.md)
    }

    private var loginSlide: some View {
        OnboardingCard(
            iconName: "checkmark.shield.fill",
            title: "Bereit loszulegen?",
            description: "Melde dich mit deiner Apple-ID an. Kein Passwort, keine E-Mail nötig.",
            isLastCard: true
        ) {
            VStack(spacing: DS.Spacing.sm) {
                SignInWithAppleButton(
                    onRequest: { request in
                        authService.prepareSignInRequest(request)
                    },
                    onCompletion: { result in
                        Task { await handleLoginCompletion(result) }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .disabled(isProcessingLogin)

                if isProcessingLogin {
                    ProgressView()
                        .padding(.top, DS.Spacing.xs)
                }

                if let loginErrorMessage {
                    Text(loginErrorMessage)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.danger)
                        .multilineTextAlignment(.center)
                }

                Text("Mit der Anmeldung akzeptierst du, dass deine Daten zur App-Nutzung gespeichert werden.")
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, DS.Spacing.xs)
            }
        }
        .padding(.vertical, DS.Spacing.md)
    }

    // MARK: - Aktionen

    private func nextSlide() {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentIndex < lastIndex {
                currentIndex += 1
            }
        }
    }

    private func skipToLogin() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentIndex = lastIndex
        }
    }

    private func handleLoginCompletion(_ result: Result<ASAuthorization, Error>) async {
        isProcessingLogin = true
        loginErrorMessage = nil
        defer { isProcessingLogin = false }

        do {
            try await authService.handleSignInCompletion(result)
            // Bei Erfolg: Onboarding als abgeschlossen markieren.
            // Routing in RootView reagiert automatisch auf den State-Wechsel.
            onboardingService.markCompleted()
        } catch {
            loginErrorMessage = "Anmeldung fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environment(AuthService.shared)
        .environment(OnboardingService.shared)
}
