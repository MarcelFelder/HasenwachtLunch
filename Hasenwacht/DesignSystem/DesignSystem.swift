//
//  DesignSystem.swift
//  Hasenwacht
//
//  Zentrales Design-System: Farben, Typografie, Abstände, Radien, Schatten.
//  Single Source of Truth für alle visuellen Werte der App.
//
//  Verwendung:  DS.Colors.primary, DS.Spacing.md, DS.Radius.lg, ...
//

import SwiftUI

enum DS {

    // MARK: - Farben

    enum Colors {
        /// Hausfarbe: warmes Coral – passt zum Mittagessen-Thema
        static let primary = Color(hex: "D85A30")
        static let primaryDark = Color(hex: "993C1D")
        static let primaryLight = Color(hex: "F5C4B3")
        static let primarySurface = Color(hex: "FAECE7")

        /// Status-Farben (Eintragung dabei / nicht dabei)
        static let success = Color(hex: "1D9E75")
        static let successSurface = Color(hex: "E1F5EE")
        static let danger = Color(hex: "B33A3A")
        static let dangerSurface = Color(hex: "FCEBEB")

        /// Akzent für Feiertage / Hinweise
        static let warning = Color(hex: "BA7517")
        static let warningSurface = Color(hex: "FAEEDA")

        /// Neutralfarben
        static let background = Color(hex: "FFFFFF")
        static let surface = Color(hex: "F5F3EE")
        static let surfaceAlt = Color(hex: "EBE6DD")
        static let textPrimary = Color(hex: "2C2C2A")
        static let textSecondary = Color(hex: "5F5E5A")
        static let textTertiary = Color(hex: "888780")
        static let border = Color(hex: "E0DAD3")
    }

    // MARK: - Schriftgrössen

    enum Typography {
        static let title = Font.system(size: 24, weight: .medium)
        static let heading = Font.system(size: 20, weight: .medium)
        static let subheading = Font.system(size: 17, weight: .medium)
        static let body = Font.system(size: 15, weight: .regular)
        static let caption = Font.system(size: 13, weight: .regular)
        static let small = Font.system(size: 12, weight: .medium)
    }

    // MARK: - Eckenrundungen

    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
        static let pill: CGFloat = 999
    }

    // MARK: - Abstände

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Schatten

    enum Shadow {
        static let card = ShadowStyle(
            color: Color.black.opacity(0.08),
            radius: 12,
            x: 0,
            y: 4
        )
        static let cardElevated = ShadowStyle(
            color: Color.black.opacity(0.12),
            radius: 20,
            x: 0,
            y: 6
        )
    }
}

// MARK: - Schatten-Hilfsstruktur

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    /// Wendet einen Schatten aus dem Design-System an.
    func dsShadow(_ shadow: ShadowStyle) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
