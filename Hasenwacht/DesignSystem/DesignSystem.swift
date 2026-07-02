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
        static let primary = Color(lightHex: "D85A30", darkHex: "E97A50")
        static let primaryDark = Color(lightHex: "993C1D", darkHex: "E8A488")
        static let primaryLight = Color(hex: "F5C4B3")
        static let primarySurface = Color(lightHex: "FAECE7", darkHex: "3D2A21")

        /// Status-Farben (Eintragung dabei / nicht dabei)
        static let success = Color(lightHex: "1D9E75", darkHex: "3DC495")
        static let successSurface = Color(lightHex: "E1F5EE", darkHex: "12332A")
        static let danger = Color(lightHex: "B33A3A", darkHex: "E06060")
        static let dangerSurface = Color(lightHex: "FCEBEB", darkHex: "3A1E1E")

        /// Akzent für Feiertage / Hinweise
        static let warning = Color(lightHex: "BA7517", darkHex: "D89A3D")
        static let warningSurface = Color(lightHex: "FAEEDA", darkHex: "3A2E17")

        /// Feature-Farben
        static let cookingPurple  = Color(red: 0.45, green: 0.30, blue: 0.80)
        static let absenceBlue    = Color(red: 0.33, green: 0.45, blue: 0.80)
        static let absenceAmber   = Color(red: 0.80, green: 0.50, blue: 0.15)

        /// Neutralfarben — passen sich automatisch an Light/Dark Mode an
        static let background = Color(lightHex: "FFFFFF", darkHex: "1E1E20")
        static let surface = Color(lightHex: "F5F3EE", darkHex: "121214")
        static let surfaceAlt = Color(lightHex: "EBE6DD", darkHex: "000000")
        static let textPrimary = Color(lightHex: "2C2C2A", darkHex: "F2F1ED")
        static let textSecondary = Color(lightHex: "5F5E5A", darkHex: "A6A49E")
        static let textTertiary = Color(lightHex: "888780", darkHex: "76746E")
        static let border = Color(lightHex: "E0DAD3", darkHex: "3A3A3C")
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

// MARK: - Farb-Extensions für direkte Color-Verwendung

extension Color {
    static let cookingPurple = Color(red: 0.45, green: 0.30, blue: 0.80)
    static let absenceBlue   = Color(red: 0.33, green: 0.45, blue: 0.80)
    static let absenceAmber  = Color(red: 0.80, green: 0.50, blue: 0.15)
}

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
