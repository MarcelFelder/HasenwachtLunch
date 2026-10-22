//
//  MainTabView.swift
//  Hasenwacht
//
//  4 Tabs: Mittagessen, Kochen (wenn canCook), Abwesenheiten, Profil.
//  Zeigt Onboarding als Sheet wenn onboardingService.showTutorial = true.
//

import SwiftUI
import AuthenticationServices

/// Tab-Identität für die `Tab`-Struct-API (iOS 18+). Nötig, weil diese API
/// (anders als die alte `.tabItem`-API) eine explizite `selection`-Bindung
/// braucht statt die Auswahl implizit über die Reihenfolge zu verwalten —
/// das ist Voraussetzung für Liquid-Glass-Tab-Bar-Features wie Minimize-on-
/// Scroll und Bottom-Accessory-Views.
private enum MainTab: Hashable {
    case lunch, cooking, absence, stats, profile
}

struct MainTabView: View {

    @Environment(CurrentUserService.self) private var currentUserService
    @Environment(OnboardingService.self)  private var onboardingService

    @State private var selection: MainTab = .lunch

    private var canCook: Bool { currentUserService.currentUser?.canCook ?? false }

    var body: some View {
        @Bindable var onboarding = onboardingService

        TabView(selection: $selection) {
            Tab("Mittagessen", systemImage: "fork.knife", value: MainTab.lunch) {
                LunchOverviewView()
            }

            if canCook {
                Tab("Kochen", systemImage: "frying.pan", value: MainTab.cooking) {
                    CookingView()
                }
            }

            Tab("Abwesenheiten", systemImage: "calendar.badge.minus", value: MainTab.absence) {
                AbsenceView()
            }

            Tab("Statistik", systemImage: "chart.bar.fill", value: MainTab.stats) {
                StatsView()
            }

            Tab("Profil", systemImage: "person.crop.circle", value: MainTab.profile) {
                ProfileView()
            }
        }
        .sheet(isPresented: $onboarding.showTutorial) {
            TutorialSheetView()
        }
        // Falls der Kochen-Tab verschwindet (canCook wird deaktiviert) während er
        // gerade aktiv ist, bliebe die Auswahl sonst auf einem nicht mehr
        // existierenden Tab stehen.
        .onChange(of: canCook) { _, stillCanCook in
            if !stillCanCook, selection == .cooking {
                selection = .lunch
            }
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
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.glass)
                    .tint(.white)
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
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.white)
                        .padding(.horizontal, 32)
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Text("Fertig")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(slides[lastIndex].accentColor)
                                .frame(maxWidth: .infinity).frame(height: 54)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.white)
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
