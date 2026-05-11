//
//  MainTabView.swift
//  Hasenwacht
//
//  4 Tabs: Mittagessen, Kochen (wenn canCook), Abwesenheiten, Profil.
//  Zeigt Onboarding als Sheet wenn onboardingService.showTutorial = true.
//

import SwiftUI
import AuthenticationServices

struct MainTabView: View {

    @Environment(CurrentUserService.self) private var currentUserService
    @Environment(OnboardingService.self)  private var onboardingService

    private var canCook: Bool { currentUserService.currentUser?.canCook ?? false }

    var body: some View {
        @Bindable var onboarding = onboardingService

        TabView {
            LunchOverviewView()
                .tabItem { Label("Mittagessen", systemImage: "fork.knife") }

            if canCook {
                CookingView()
                    .tabItem { Label("Kochen ᵝ", systemImage: "frying.pan") }
            }

            AbsenceView()
                .tabItem { Label("Abwesenheiten", systemImage: "calendar.badge.minus") }

            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .sheet(isPresented: $onboarding.showTutorial) {
            TutorialSheetView()
        }
    }
}

// MARK: - Tutorial Sheet (für eingeloggte User)

struct TutorialSheetView: View {

    @Environment(OnboardingService.self) private var onboardingService
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex = 0
    private let slides = OnboardingSlide.all
    private var lastIndex: Int { slides.count - 1 }

    var body: some View {
        ZStack {
            // Animierter Hintergrund
            LinearGradient(
                colors: slides[min(currentIndex, lastIndex)].gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentIndex)

            VStack(spacing: 0) {
                // Close Button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, 24)
                    .padding(.top, 16)
                }
                .frame(height: 52)

                // Slides
                TabView(selection: $currentIndex) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        OnboardingSlideView(slide: slide).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: currentIndex)

                // Footer
                VStack(spacing: 20) {
                    HStack(spacing: 8) {
                        ForEach(0...lastIndex, id: \.self) { index in
                            Capsule()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.35))
                                .frame(width: index == currentIndex ? 24 : 7, height: 7)
                                .animation(.spring(response: 0.3), value: currentIndex)
                        }
                    }

                    if currentIndex < lastIndex {
                        Button {
                            withAnimation(.easeInOut(duration: 0.35)) { currentIndex += 1 }
                        } label: {
                            Text("Weiter")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(slides[currentIndex].accentColor)
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                        }
                        .padding(.horizontal, 32)
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Text("Fertig")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(slides[lastIndex].accentColor)
                                .frame(maxWidth: .infinity).frame(height: 54)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
                        }
                        .padding(.horizontal, 32)
                    }
                }
                .padding(.bottom, 52)
                .padding(.top, 16)
            }
        }
    }
}

#Preview {
    MainTabView()
}
