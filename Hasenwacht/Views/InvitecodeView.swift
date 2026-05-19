//
//  InviteCodeView.swift
//  Hasenwacht
//
//  Wird nach dem Profil-Setup angezeigt wenn der User noch nicht approved ist.
//  Gleicher Gradient-Stil wie Onboarding für nahtlosen Flow.
//

import SwiftUI

struct InviteCodeView: View {

    @Environment(CurrentUserService.self) private var currentUserService
    @Environment(AuthService.self) private var authService

    @State private var code = ""
    @State private var isChecking = false
    @State private var errorMessage: String?
    @State private var isApproved = false

    private var canSubmit: Bool {
        !code.trimmingCharacters(in: .whitespaces).isEmpty && !isChecking
    }

    var body: some View {
        ZStack {
            // Gradient passend zum Onboarding
            LinearGradient(
                colors: [DS.Colors.primary, DS.Colors.primaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Dekorative Kreise
            Circle().fill(Color.white.opacity(0.06)).frame(width: 200, height: 200).offset(x: 150, y: -200)
            Circle().fill(Color.white.opacity(0.04)).frame(width: 130, height: 130).offset(x: -100, y: 300)

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    Circle().fill(Color.white.opacity(0.15)).frame(width: 100, height: 100)
                    Image(systemName: "key.fill")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(Color.white)
                }
                .padding(.bottom, 32)

                // Text
                VStack(spacing: 10) {
                    Text("Einladungscode")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text("Gib den Code ein den du von\ndeiner WG erhalten hast.")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.80))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                // Code-Eingabe
                VStack(spacing: 12) {
                    TextField("Code eingeben", text: $code)
                        .font(.system(size: 18, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.10), radius: 6, y: 3)
                        .onSubmit { Task { await submit() } }

                    if let error = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 13))
                            Text(error)
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 32)
                .animation(.easeInOut(duration: 0.2), value: errorMessage)

                Spacer()

                // Submit Button
                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 10) {
                        if isChecking {
                            ProgressView().tint(DS.Colors.primary)
                        }
                        Text(isChecking ? "Wird geprüft…" : "Bestätigen")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(canSubmit ? DS.Colors.primary : Color.gray)
                    }
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Color.white.opacity(canSubmit ? 1.0 : 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 4)
                }
                .disabled(!canSubmit)
                .padding(.horizontal, 32)
                .padding(.bottom, 20)

                // Logout Option
                Button {
                    performLogout()
                } label: {
                    Text("Abmelden")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .padding(.bottom, 50)
            }
        }
    }

    // MARK: - Logik

    private func submit() async {
        guard canSubmit else { return }
        isChecking = true
        errorMessage = nil
        defer { isChecking = false }

        do {
            let correct = try await InviteService.shared.verify(code: code)
            if correct {
                guard let userId = authService.currentUserId else { return }
                try await InviteService.shared.approveUser(userId: userId)
                // Profil neu laden damit isApproved = true im State ist
                await currentUserService.loadProfile(userId: userId)
                // LunchDaysViewModel neu starten mit korrekter userId
                // (war bereits gestartet aber ohne approved user)
                await MainActor.run {
                    LunchDaysViewModel.shared.stop()
                    LunchDaysViewModel.shared.updateUserId(userId)
                    LunchDaysViewModel.shared.start()
                    AbsenceViewModel.shared.start(userId: userId)
                    CookingViewModel.shared.start(userId: userId)
                }
            } else {
                withAnimation {
                    errorMessage = "Falscher Code. Bitte erneut versuchen."
                }
                code = ""
            }
        } catch {
            withAnimation {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func performLogout() {
        try? AuthService.shared.signOut()
        CurrentUserService.shared.clear()
    }
}

#Preview {
    InviteCodeView()
        .environment(CurrentUserService.shared)
        .environment(AuthService.shared)
}
