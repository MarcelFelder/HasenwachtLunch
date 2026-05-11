//
//  OnboardingView.swift
//  Hasenwacht
//
//  Onboarding → Apple Login → Profil-Setup — alles in einem nahtlosen Flow.
//  Kein separater ProfileSetupView mehr nötig.
//

import SwiftUI
import AuthenticationServices
import PhotosUI

// MARK: - Flow State

private enum OnboardingFlowState {
    case slides          // Info-Slides
    case profileSetup    // Nach Login: Name + Foto
}

// MARK: - Main View

struct OnboardingView: View {

    @Environment(AuthService.self) private var authService
    @Environment(CurrentUserService.self) private var currentUserService
    @Environment(NotificationService.self) private var notificationService
    @Environment(OnboardingService.self) private var onboardingService

    @State private var currentIndex = 0
    @State private var flowState: OnboardingFlowState = .slides
    @State private var loginError: String?
    @State private var isProcessingLogin = false

    private let slides = OnboardingSlide.all
    private var lastInfoIndex: Int { slides.count - 1 }
    private let loginIndex: Int = OnboardingSlide.all.count

    // Login-Slide Gradient
    private let loginGradient: [Color] = [
        Color(red: 0.13, green: 0.70, blue: 0.44),
        Color(red: 0.07, green: 0.48, blue: 0.30)
    ]

    var body: some View {
        ZStack {
            animatedBackground

            switch flowState {
            case .slides:
                slidesView
                    .transition(.opacity)
            case .profileSetup:
                ProfileSetupStep(
                    authService: authService,
                    currentUserService: currentUserService,
                    notificationService: notificationService,
                    onboardingService: onboardingService
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.45), value: flowState)
    }

    // MARK: - Animated Background

    private var animatedBackground: some View {
        let colors: [Color] = {
            switch flowState {
            case .profileSetup: return loginGradient
            case .slides:
                return currentIndex < slides.count
                    ? slides[currentIndex].gradientColors
                    : loginGradient
            }
        }()

        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentIndex)
            .animation(.easeInOut(duration: 0.5), value: flowState)
    }

    // MARK: - Slides View

    private var slidesView: some View {
        VStack(spacing: 0) {
            // Skip
            HStack {
                Spacer()
                if currentIndex < loginIndex {
                    Button("Überspringen") {
                        withAnimation { currentIndex = loginIndex }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.trailing, 24)
                }
            }
            .padding(.top, 60) // unter Status Bar
            .frame(height: 104)

            // Slides
            TabView(selection: $currentIndex) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    OnboardingSlideView(slide: slide).tag(index)
                }
                loginSlide.tag(loginIndex)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: currentIndex)

            // Footer
            VStack(spacing: 20) {
                // Dots
                HStack(spacing: 8) {
                    ForEach(0...loginIndex, id: \.self) { index in
                        Capsule()
                            .fill(index == currentIndex ? Color.white : Color.white.opacity(0.35))
                            .frame(width: index == currentIndex ? 24 : 7, height: 7)
                            .animation(.spring(response: 0.3), value: currentIndex)
                    }
                }

                if currentIndex < loginIndex {
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) { currentIndex += 1 }
                    } label: {
                        Text("Weiter")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(slides[min(currentIndex, lastInfoIndex)].accentColor)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                    }
                    .padding(.horizontal, 32)
                } else {
                    Color.clear.frame(height: 54)
                }
            }
            .padding(.bottom, 52).padding(.top, 16)
        }
    }

    // MARK: - Login Slide

    private var loginSlide: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration
            ZStack {
                Circle().fill(Color.white.opacity(0.08)).frame(width: 220, height: 220)
                Circle().fill(Color.white.opacity(0.10)).frame(width: 160, height: 160)
                Circle().fill(Color.white.opacity(0.13)).frame(width: 110, height: 110)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(Color.white)
            }
            .padding(.bottom, 40)

            // Text
            VStack(spacing: 10) {
                Text("Los geht's")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Color.white)
                Text("Melde dich mit deiner Apple-ID an.\nKein Passwort, keine E-Mail.")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()

            // Apple Sign-In
            VStack(spacing: 12) {
                SignInWithAppleButton(
                    onRequest: { authService.prepareSignInRequest($0) },
                    onCompletion: { result in Task { await handleLogin(result) } }
                )
                .signInWithAppleButtonStyle(.white)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                .disabled(isProcessingLogin)
                .padding(.horizontal, 32)

                if isProcessingLogin {
                    ProgressView().tint(.white)
                }

                if let err = loginError {
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Text("Mit der Anmeldung akzeptierst du die Datenspeicherung zur App-Nutzung.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 80)
        }
    }

    // MARK: - Login Handler

    private func handleLogin(_ result: Result<ASAuthorization, Error>) async {
        isProcessingLogin = true
        loginError = nil
        defer { isProcessingLogin = false }

        do {
            try await authService.handleSignInCompletion(result)
            // Login erfolgreich → Profil-Setup zeigen
            withAnimation(.easeInOut(duration: 0.45)) {
                flowState = .profileSetup
            }
        } catch {
            loginError = "Anmeldung fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}

// MARK: - Profil Setup Step

/// Erscheint nach erfolgreichem Login direkt im Onboarding-Flow.
/// Gleicher Hintergrund-Gradient, nahtloser Übergang.
private struct ProfileSetupStep: View {

    let authService: AuthService
    let currentUserService: CurrentUserService
    let notificationService: NotificationService
    let onboardingService: OnboardingService

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingImage: UIImage?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isSaving
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Avatar-Picker
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let img = pendingImage {
                        Image(uiImage: img)
                            .resizable().scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.20)).frame(width: 100, height: 100)
                            Image(systemName: "person.fill")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                    }
                }
                .shadow(color: Color.black.opacity(0.20), radius: 10, y: 5)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack {
                        Circle().fill(Color.white).frame(width: 32, height: 32)
                            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(red: 0.13, green: 0.70, blue: 0.44))
                    }
                }
                .offset(x: 4, y: 4)
            }
            .padding(.bottom, 28)

            // Titel
            VStack(spacing: 8) {
                Text("Fast fertig!")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.white)
                Text("Wie sollen dich die anderen nennen?")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.80))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)

            // Felder
            VStack(spacing: 12) {
                setupField(placeholder: "Vorname", text: $firstName,
                           contentType: .givenName)
                setupField(placeholder: "Nachname", text: $lastName,
                           contentType: .familyName)
            }
            .padding(.horizontal, 32)

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }

            Spacer()

            // Save Button
            Button {
                Task { await save() }
            } label: {
                HStack(spacing: 10) {
                    if isSaving { ProgressView().tint(Color(red: 0.13, green: 0.70, blue: 0.44)) }
                    Text(isSaving ? "Wird gespeichert…" : "Loslegen")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(canSave
                            ? Color(red: 0.13, green: 0.70, blue: 0.44)
                            : Color.gray)
                }
                .frame(maxWidth: .infinity).frame(height: 54)
                .background(Color.white.opacity(canSave ? 1 : 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
            }
            .disabled(!canSave)
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
        .onAppear { prefill() }
        .onChange(of: selectedPhoto) { _, item in
            Task { await loadPhoto(from: item) }
        }
    }

    private func setupField(placeholder: String,
                            text: Binding<String>,
                            contentType: UITextContentType) -> some View {
        TextField(placeholder, text: text)
            .textContentType(contentType)
            .autocorrectionDisabled()
            .font(.system(size: 16))
            .foregroundStyle(.primary)
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
    }

    private func prefill() {
        if firstName.isEmpty, let f = authService.pendingFirstName { firstName = f }
        if lastName.isEmpty,  let l = authService.pendingLastName  { lastName  = l }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let ui = UIImage(data: data) else { return }
        await MainActor.run {
            pendingImage = ui.resized(to: CGSize(width: 200, height: 200))
        }
    }

    private func save() async {
        guard let userId = authService.currentUserId else { return }
        isSaving = true; errorMessage = nil; defer { isSaving = false }

        let first = firstName.trimmingCharacters(in: .whitespaces)
        let last  = lastName.trimmingCharacters(in: .whitespaces)

        // Foto zu Base64
        let base64: String?
        if let img = pendingImage, let jpeg = img.jpegData(compressionQuality: 0.70) {
            base64 = jpeg.base64EncodedString()
        } else { base64 = nil }

        do {
            // Profil anlegen
            try await currentUserService.createProfile(
                userId: userId,
                firstName: first,
                lastName: last
            )

            // Foto nachträglich speichern falls vorhanden
            if let photo = base64 {
                try await currentUserService.updateProfile(
                    firstName: first, lastName: last,
                    photoBase64: photo, canCook: false,
                    foodPreferences: FoodPreferences()
                )
            }

            // Notifications anfragen
            if notificationService.authorizationStatus == .notDetermined {
                await notificationService.requestAuthorization()
            }

            // Onboarding abschliessen → RootView zeigt MainTabView
            onboardingService.markCompleted()

        } catch {
            errorMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }
}

// MARK: - UIImage Resize

private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AuthService.shared)
        .environment(CurrentUserService.shared)
        .environment(NotificationService.shared)
        .environment(OnboardingService.shared)
}
