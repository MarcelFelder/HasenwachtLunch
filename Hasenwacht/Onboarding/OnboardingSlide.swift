//
//  OnboardingSlide.swift
//  Hasenwacht
//
//  Datenmodell für einen Onboarding-Slide.
//  Jeder Slide hat einen eigenen Farbgradienten und eine grosse Illustration.
//

import SwiftUI

struct OnboardingSlide {
    let icon: String          // SF Symbol
    let badge: String?        // Optionaler Badge-Text (z.B. "Beta")
    let title: String
    let subtitle: String
    let gradientColors: [Color]
    let accentColor: Color
}

extension OnboardingSlide {
    static let all: [OnboardingSlide] = [
        .init(
            icon: "house.fill",
            badge: nil,
            title: "Willkommen",
            subtitle: "Gemeinsam essen, ohne Stress.\nEinfach dabei sein.",
            gradientColors: [
                Color(red: 0.85, green: 0.35, blue: 0.19),
                Color(red: 0.60, green: 0.22, blue: 0.11)
            ],
            accentColor: Color(red: 0.85, green: 0.35, blue: 0.19)
        ),
        .init(
            icon: "checkmark.circle.fill",
            badge: nil,
            title: "Immer dabei",
            subtitle: "Du bist automatisch angemeldet.\nTrag dich nur aus wenn du fehlst.",
            gradientColors: [
                Color(red: 0.13, green: 0.70, blue: 0.44),
                Color(red: 0.07, green: 0.48, blue: 0.30)
            ],
            accentColor: Color(red: 0.13, green: 0.70, blue: 0.44)
        ),
        .init(
            icon: "clock.fill",
            badge: nil,
            title: "Deadline 14:00",
            subtitle: "Ab- oder anmelden bis 14:00 Uhr\nam Vortag — dann ist eingekauft.",
            gradientColors: [
                Color(red: 0.80, green: 0.50, blue: 0.10),
                Color(red: 0.58, green: 0.34, blue: 0.05)
            ],
            accentColor: Color(red: 0.80, green: 0.50, blue: 0.10)
        ),
        .init(
            icon: "calendar.badge.minus",
            badge: nil,
            title: "Abwesenheiten",
            subtitle: "Ferien oder Home Office eintragen.\nDu wirst automatisch abgemeldet.",
            gradientColors: [
                Color(red: 0.33, green: 0.45, blue: 0.80),
                Color(red: 0.20, green: 0.28, blue: 0.60)
            ],
            accentColor: Color(red: 0.33, green: 0.45, blue: 0.80)
        ),
        .init(
            icon: "frying.pan.fill",
            badge: "BETA",
            title: "Kochplan",
            subtitle: "Trag dich als Koch ein und gib\ndas Menü bekannt.",
            gradientColors: [
                Color(red: 0.45, green: 0.30, blue: 0.80),
                Color(red: 0.28, green: 0.16, blue: 0.58)
            ],
            accentColor: Color(red: 0.45, green: 0.30, blue: 0.80)
        )
    ]
}
