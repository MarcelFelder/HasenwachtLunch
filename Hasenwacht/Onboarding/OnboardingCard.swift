//
//  OnboardingCard.swift
//  Hasenwacht
//
//  Wiederverwendbare Karten-Komponente für den Onboarding-Flow.
//  Zeigt Icon, Titel, Beschreibung – mit gestapeltem Karten-Effekt dahinter.
//

import SwiftUI

struct OnboardingCard<BottomContent: View>: View {

    // MARK: - Input

    let iconName: String          // SF-Symbol-Name
    let title: String
    let description: String
    let isLastCard: Bool          // Login-Karte hat keinen Stack hinter sich
    @ViewBuilder let bottomContent: () -> BottomContent

    init(
        iconName: String,
        title: String,
        description: String,
        isLastCard: Bool = false,
        @ViewBuilder bottomContent: @escaping () -> BottomContent = { EmptyView() }
    ) {
        self.iconName = iconName
        self.title = title
        self.description = description
        self.isLastCard = isLastCard
        self.bottomContent = bottomContent
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Gestapelte Karten dahinter (nur wenn nicht letzte Karte)
            if !isLastCard {
                stackedCardLayer(offset: 14, opacity: 0.5)
                stackedCardLayer(offset: 7, opacity: 0.75)
            }

            // Aktive Karte (vorderste)
            activeCard
        }
    }

    // MARK: - Aktive Karte

    private var activeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon-Bereich
            HStack {
                Spacer()
                iconCircle
                Spacer()
            }
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)

            // Trennlinie
            Rectangle()
                .fill(DS.Colors.border)
                .frame(height: 0.5)
                .padding(.bottom, DS.Spacing.md)

            // Titel
            Text(title)
                .font(DS.Typography.heading)
                .foregroundColor(DS.Colors.textPrimary)
                .padding(.bottom, DS.Spacing.sm)

            // Beschreibung
            Text(description)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: DS.Spacing.md)

            // Optionaler Inhalt unten (z.B. Apple-Login-Button)
            bottomContent()
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 380, alignment: .topLeading)
        .background(DS.Colors.background)
        .cornerRadius(DS.Radius.lg)
        .dsShadow(DS.Shadow.cardElevated)
    }

    // MARK: - Icon-Kreis mit Dekor

    private var iconCircle: some View {
        ZStack {
            // Dekorative Punkte um den Kreis
            Circle()
                .fill(DS.Colors.primaryLight.opacity(0.6))
                .frame(width: 14, height: 14)
                .offset(x: -55, y: -40)

            Circle()
                .fill(DS.Colors.successSurface)
                .frame(width: 18, height: 18)
                .offset(x: 55, y: 30)

            Circle()
                .fill(DS.Colors.primaryLight.opacity(0.4))
                .frame(width: 10, height: 10)
                .offset(x: 50, y: -30)

            // Hauptkreis
            Circle()
                .fill(DS.Colors.primarySurface)
                .frame(width: 110, height: 110)

            // SF Symbol
            Image(systemName: iconName)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(DS.Colors.primaryDark)
        }
        .frame(width: 110, height: 110)
    }

    // MARK: - Gestapelte Karten dahinter

    private func stackedCardLayer(offset: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: DS.Radius.lg)
            .fill(DS.Colors.background.opacity(opacity))
            .frame(maxWidth: .infinity, minHeight: 380)
            .offset(x: offset, y: offset / 2)
            .dsShadow(DS.Shadow.card)
    }
}

// MARK: - Preview

#Preview("Standard Card") {
    ZStack {
        DS.Colors.surface.ignoresSafeArea()
        OnboardingCard(
            iconName: "house.fill",
            title: "Willkommen bei\nHasenwacht",
            description: "Die App fürs gemeinsame Mittagessen im Quartier. Schnell, einfach, ohne Chat."
        )
        .padding(DS.Spacing.lg)
    }
}

#Preview("Last Card with Button") {
    ZStack {
        DS.Colors.surface.ignoresSafeArea()
        OnboardingCard(
            iconName: "checkmark.shield.fill",
            title: "Bereit loszulegen?",
            description: "Melde dich mit deiner Apple-ID an.",
            isLastCard: true
        ) {
            Text("[Apple-Login-Button]")
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(DS.Radius.md)
        }
        .padding(DS.Spacing.lg)
    }
}
