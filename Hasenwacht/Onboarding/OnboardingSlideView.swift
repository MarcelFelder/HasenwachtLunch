//
//  OnboardingSlideView.swift
//  Hasenwacht
//
//  Einzelner Onboarding-Slide mit Illustration, Titel und Subtitle.
//  Wird von OnboardingView und TutorialSheetView (MainTabView) verwendet.
//

import SwiftUI

struct OnboardingSlideView: View {
    let slide: OnboardingSlide

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Grosse Illustration mit konzentrischen Ringen
            ZStack {
                Circle().fill(Color.white.opacity(0.06)).frame(width: 280, height: 280)
                Circle().fill(Color.white.opacity(0.08)).frame(width: 220, height: 220)
                Circle().fill(Color.white.opacity(0.10)).frame(width: 165, height: 165)

                // Dekorative Punkte
                Circle().fill(Color.white.opacity(0.4)).frame(width: 10, height: 10).offset(x: -100, y: -60)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 7,  height: 7) .offset(x: 110,  y: -80)
                Circle().fill(Color.white.opacity(0.25)).frame(width: 5, height: 5) .offset(x: 90,   y: 70)

                // Icon
                Circle().fill(Color.white.opacity(0.15)).frame(width: 120, height: 120)
                Image(systemName: slide.icon)
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(Color.white)
            }
            .frame(height: 300)

            Spacer().frame(height: 40)

            // Text
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Text(slide.title)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.white)

                    if let badge = slide.badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(DS.Colors.textPrimary)
                            .tracking(1.5)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
                            )
                    }
                }

                Text(slide.subtitle)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}
