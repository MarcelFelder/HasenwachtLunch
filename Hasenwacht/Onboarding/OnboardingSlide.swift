//
//  OnboardingCard.swift
//  Hasenwacht
//
//  Wiederverwendbare Karten-Komponente für den Onboarding-Flow.
//  Akzentfarbe ist pro Slide konfigurierbar.
//

import SwiftUI

struct OnboardingCard<BottomContent: View>: View {

    let iconName: String
    let title: String
    let description: String
    var accentColor: Color = DS.Colors.primary
    var accentSurface: Color = DS.Colors.primarySurface
    let isLastCard: Bool
    @ViewBuilder let bottomContent: () -> BottomContent

    init(
        iconName: String,
        title: String,
        description: String,
        accentColor: Color = DS.Colors.primary,
        accentSurface: Color = DS.Colors.primarySurface,
        isLastCard: Bool = false,
        @ViewBuilder bottomContent: @escaping () -> BottomContent = { EmptyView() }
    ) {
        self.iconName      = iconName
        self.title         = title
        self.description   = description
        self.accentColor   = accentColor
        self.accentSurface = accentSurface
        self.isLastCard    = isLastCard
        self.bottomContent = bottomContent
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !isLastCard {
                stackedCardLayer(offset: 14, opacity: 0.5)
                stackedCardLayer(offset: 7,  opacity: 0.75)
            }
            activeCard
        }
    }

    private var activeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                iconCircle
                Spacer()
            }
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)

            Rectangle()
                .fill(DS.Colors.border)
                .frame(height: 0.5)
                .padding(.bottom, DS.Spacing.md)

            Text(title)
                .font(DS.Typography.heading)
                .foregroundColor(DS.Colors.textPrimary)
                .padding(.bottom, DS.Spacing.sm)

            Text(description)
                .font(DS.Typography.body)
                .foregroundColor(DS.Colors.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: DS.Spacing.md)
            bottomContent()
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 380, alignment: .topLeading)
        .background(DS.Colors.background)
        .cornerRadius(DS.Radius.lg)
        .dsShadow(DS.Shadow.cardElevated)
    }

    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: 14, height: 14)
                .offset(x: -55, y: -40)

            Circle()
                .fill(accentSurface)
                .frame(width: 18, height: 18)
                .offset(x: 55, y: 30)

            Circle()
                .fill(accentColor.opacity(0.10))
                .frame(width: 10, height: 10)
                .offset(x: 50, y: -30)

            Circle()
                .fill(accentSurface)
                .frame(width: 110, height: 110)

            Image(systemName: iconName)
                .font(.system(size: 44, weight: .light))
                .foregroundColor(accentColor)
        }
        .frame(width: 110, height: 110)
    }

    private func stackedCardLayer(offset: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: DS.Radius.lg)
            .fill(DS.Colors.background.opacity(opacity))
            .frame(maxWidth: .infinity, minHeight: 380)
            .offset(x: offset, y: offset / 2)
            .dsShadow(DS.Shadow.card)
    }
}

#Preview {
    ZStack {
        DS.Colors.surface.ignoresSafeArea()
        OnboardingCard(
            iconName: "fork.knife",
            title: "Mittagessen",
            description: "Du bist standardmässig dabei.",
            accentColor: DS.Colors.success,
            accentSurface: DS.Colors.successSurface
        )
        .padding(DS.Spacing.lg)
    }
}
