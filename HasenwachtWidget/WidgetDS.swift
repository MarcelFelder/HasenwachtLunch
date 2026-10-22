//
//  WidgetDS.swift
//  HasenwachtWidget
//
//  Minimaler, eigenständiger Ausschnitt aus Hasenwacht/DesignSystem/DesignSystem.swift.
//  Die Extension hat keinen Zugriff auf das App-Target (unterschiedliche Module),
//  deshalb werden hier nur die im Widget tatsächlich benötigten Werte 1:1
//  dupliziert. Bei Änderungen am App-DesignSystem bitte manuell synchron halten.
//

import SwiftUI
import UIKit

enum WidgetDS {

    enum Colors {
        static let success = Color(lightHex: "21B270", darkHex: "4ADE93")
        static let danger = Color(lightHex: "B33A3A", darkHex: "E06060")
        static let warning = Color(lightHex: "BA7517", darkHex: "D89A3D")
        static let textPrimary = Color(lightHex: "2C2C2A", darkHex: "F2F1ED")
        static let textSecondary = Color(lightHex: "5F5E5A", darkHex: "A6A49E")
        static let textTertiary = Color(lightHex: "888780", darkHex: "76746E")
    }

    /// Vibrante, zustandsbasierte Verläufe für die Widget-Kacheln.
    /// Jeder Stop ist selbst schon light/dark-adaptiv (siehe Color(lightHex:darkHex:)),
    /// ein Verblassen bei .locked/.lunchOver passiert über einen dunklen Scrim-Overlay
    /// statt über separate Gradient-Sets — hält die Farbsemantik konsistent.
    /// `attending`/`notAttending` sind 1:1 aus `DS.Colors.success`/`.primary` im App-
    /// Target abgeleitet, damit der Widget farblich zur App gehört statt generisches
    /// Grün/Rot zu zeigen.
    enum Gradients {
        static let attending: [Color] = [
            Color(lightHex: "61E0A0", darkHex: "4ADE93"),
            Color(lightHex: "188C59", darkHex: "21B270")
        ]
        static let notAttending: [Color] = [
            Color(lightHex: "D85A30", darkHex: "E97A50"),
            Color(lightHex: "993C1D", darkHex: "E8A488")
        ]
        static let neutral: [Color] = [
            Color(lightHex: "94A3B8", darkHex: "475569"),
            Color(lightHex: "475569", darkHex: "1E293B")
        ]
        /// Für die Wochenübersicht (mehrere Tage, kein einzelner An-/Abgemeldet-
        /// Zustand) — markenfarbig statt neutral, damit die grosse Kachel nicht
        /// wie ein Fehler-/Platzhalterzustand wirkt.
        static let week: [Color] = [
            Color(lightHex: "D85A30", darkHex: "E97A50"),
            Color(lightHex: "7A2E14", darkHex: "5C2410")
        ]
    }

    enum Typography {
        static let title = Font.system(size: 20, weight: .bold, design: .rounded)
        static let subheading = Font.system(size: 15, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 14, weight: .semibold, design: .rounded)
        static let caption = Font.system(size: 12, weight: .medium, design: .rounded)
        static let caption2 = Font.system(size: 10, weight: .semibold, design: .rounded)
    }

    enum Radius {
        static let md: CGFloat = 14
        static let lg: CGFloat = 22
        static let pill: CGFloat = 999
    }
}

// MARK: - Glas-Bausteine (Liquid-Glass-artige Chips/Pills über dem Gradient)

/// Durchscheinende Pille für sekundäre Infos (Feiertag, Offline, Gestrichen, ...).
struct GlassPill: View {
    let systemImage: String
    let text: String?
    var prominent: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
            if let text {
                Text(text)
                    .font(WidgetDS.Typography.caption2)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, text == nil ? 6 : 9)
        .padding(.vertical, 5)
        .background(.white.opacity(prominent ? 0.30 : 0.18), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.75))
    }
}

/// Grosses, rundes "Glas"-Icon — der visuelle Anker jeder Kachel.
struct GlassIcon: View {
    let systemName: String
    var diameter: CGFloat = 46
    var badge: String? = nil

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(.white.opacity(0.22))
                .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1))
                .frame(width: diameter, height: diameter)
                .overlay(
                    Image(systemName: systemName)
                        .font(.system(size: diameter * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                )
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

            if let badge {
                Circle()
                    .fill(.black.opacity(0.55))
                    .frame(width: diameter * 0.4, height: diameter * 0.4)
                    .overlay(
                        Image(systemName: badge)
                            .font(.system(size: diameter * 0.2, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .offset(x: diameter * 0.08, y: -diameter * 0.08)
            }
        }
    }
}

// MARK: - Farb-Extensions

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    init(lightHex: String, darkHex: String) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: darkHex)) : UIColor(Color(hex: lightHex))
        })
    }
}
