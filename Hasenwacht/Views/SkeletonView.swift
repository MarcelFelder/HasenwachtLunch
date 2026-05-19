//
//  SkeletonView.swift
//  Hasenwacht
//
//  Wiederverwendbare Skeleton-Loading Komponente mit Shimmer-Animation.
//  Ersetzt ProgressView während Daten geladen werden.
//

import SwiftUI

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.5),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: geo.size.width * phase)
                    .blendMode(.screen)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.4)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Block (Grundelement)

struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 14
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DS.Colors.surfaceAlt)
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Skeleton Day Card (für LunchOverview)

struct SkeletonDayCard: View {
    var body: some View {
        HStack(spacing: 12) {
            // Datum Block
            RoundedRectangle(cornerRadius: 12)
                .fill(DS.Colors.surfaceAlt)
                .frame(width: 52, height: 52)
                .shimmer()

            VStack(alignment: .leading, spacing: 6) {
                SkeletonBlock(width: 90, height: 14)
                SkeletonBlock(width: 120, height: 11)
            }

            Spacer()

            // Pill
            RoundedRectangle(cornerRadius: 18)
                .fill(DS.Colors.surfaceAlt)
                .frame(width: 80, height: 36)
                .shimmer()
        }
        .padding(16)
        .background(DS.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(DS.Colors.border, lineWidth: 1)
        )
    }
}

// MARK: - Skeleton Übersicht (5 Karten)

struct SkeletonOverviewList: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                SkeletonDayCard()
                    .opacity(1.0 - Double(index) * 0.15)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

// MARK: - Skeleton Detail Hero

struct SkeletonDetailHero: View {
    var body: some View {
        VStack(spacing: 0) {
            // Gradient Banner Skeleton
            RoundedRectangle(cornerRadius: 20)
                .fill(DS.Colors.surfaceAlt)
                .frame(height: 110)
                .shimmer()

            // Toggle-Zeile
            HStack {
                SkeletonBlock(width: 160, height: 12)
                Spacer()
                RoundedRectangle(cornerRadius: 17)
                    .fill(DS.Colors.surfaceAlt)
                    .frame(width: 90, height: 34)
                    .shimmer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DS.Colors.background)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
    }
}

// MARK: - Skeleton User List (für Dabei/Abgemeldet)

struct SkeletonUserList: View {
    let title: String
    var count: Int = 3

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(DS.Colors.surfaceAlt)
                    .frame(width: 6, height: 6)
                SkeletonBlock(width: 60, height: 12)
                Spacer()
                SkeletonBlock(width: 24, height: 20, cornerRadius: 6)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(DS.Colors.background)
            .overlay(Divider().background(DS.Colors.border), alignment: .bottom)

            ForEach(0..<count, id: \.self) { index in
                HStack(spacing: 12) {
                    Circle()
                        .fill(DS.Colors.surfaceAlt)
                        .frame(width: 36, height: 36)
                        .shimmer()
                    SkeletonBlock(width: CGFloat.random(in: 80...140), height: 14)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(DS.Colors.background)

                if index < count - 1 {
                    Divider().background(DS.Colors.border).padding(.leading, 64)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }
}
