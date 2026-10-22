//
//  DSComponents.swift
//  Hasenwacht
//
//  Gemeinsame, über mehrere Screens wiederverwendete Bausteine des
//  Liquid-Glass-Redesigns: Wochen-Umschalter, Pill-Button-Inhalt,
//  gesperrter Status-Chip, Section-Header. Form/Füllung kommen bei
//  interaktiven Elementen aus `.buttonStyle(.glass/.glassProminent)`
//  am Call-Site — diese Views liefern nur den Inhalt bzw. den
//  nicht-interaktiven Chip-Look dazu.
//

import SwiftUI

/// Wochen-Navigation: Chevron-Buttons (Glass) links/rechts, Label in der Mitte.
struct DSWeekSwitcher: View {
    let title: String
    let subtitle: String
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.glass)
                .tint(canGoBack ? DS.Colors.textSecondary : DS.Colors.textTertiary)
                .disabled(!canGoBack)

                Spacer()

                VStack(spacing: 2) {
                    Text(title)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(subtitle)
                        .font(DS.Typography.small)
                        .foregroundStyle(DS.Colors.textSecondary)
                }

                Spacer()

                Button(action: onForward) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.glass)
                .tint(canGoForward ? DS.Colors.textSecondary : DS.Colors.textTertiary)
                .disabled(!canGoForward)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
        }
    }
}

/// Inhalt (Icon + Text) eines Pill-Buttons — Form/Füllung/Press-Feedback
/// kommen vom `.buttonStyle(.glass)`/`.glassProminent`, den der Call-Site setzt.
struct DSPillLabel: View {
    let icon: String
    let text: String
    var height: CGFloat = 34

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(DS.Typography.smallBold)
        }
        .padding(.horizontal, 12)
        .frame(height: height)
    }
}

/// Nicht-interaktiver, sichtbar deaktivierter Status-Chip (z.B. nach Anmeldeschluss) —
/// optisch an die aktiven Glass-Pills angeglichen, aber ohne Tap-Ziel.
struct DSLockedChip: View {
    let icon: String
    let text: String
    var foreground: Color = DS.Colors.textTertiary
    var glassTint: Color = .black.opacity(0.03)
    var height: CGFloat = 34

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(DS.Typography.smallBold)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 12)
        .frame(height: height)
        .glassEffect(.regular.tint(glassTint), in: .capsule)
    }
}

/// Section-Header: farbiger Punkt + Titel + Anzahl-Badge, mit Trenn-Linie unten.
struct DSSectionHeader: View {
    let title: String
    let count: Int
    var dotColor: Color = DS.Colors.textTertiary

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(title)
                .font(DS.Typography.smallBold)
                .foregroundStyle(DS.Colors.textSecondary)
            Spacer()
            Text("\(count)")
                .font(DS.Typography.smallBold)
                .foregroundStyle(DS.Colors.textTertiary)
                .frame(minWidth: 20)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(DS.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(Divider().background(DS.Colors.border), alignment: .bottom)
    }
}
