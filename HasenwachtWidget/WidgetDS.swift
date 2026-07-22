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
        static let success = Color(lightHex: "1D9E75", darkHex: "3DC495")
        static let successSurface = Color(lightHex: "E1F5EE", darkHex: "12332A")
        static let danger = Color(lightHex: "B33A3A", darkHex: "E06060")
        static let dangerSurface = Color(lightHex: "FCEBEB", darkHex: "3A1E1E")
        static let warning = Color(lightHex: "BA7517", darkHex: "D89A3D")
        static let background = Color(lightHex: "FFFFFF", darkHex: "1E1E20")
        static let surfaceAlt = Color(lightHex: "EBE6DD", darkHex: "000000")
        static let textPrimary = Color(lightHex: "2C2C2A", darkHex: "F2F1ED")
        static let textSecondary = Color(lightHex: "5F5E5A", darkHex: "A6A49E")
        static let textTertiary = Color(lightHex: "888780", darkHex: "76746E")
    }

    enum Typography {
        static let subheading = Font.system(size: 17, weight: .medium)
        static let body = Font.system(size: 15, weight: .regular)
        static let caption = Font.system(size: 13, weight: .regular)
    }

    enum Radius {
        static let md: CGFloat = 12
        static let pill: CGFloat = 999
    }
}

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
