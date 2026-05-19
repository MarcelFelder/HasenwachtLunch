//
//  StatsView.swift
//  Hasenwacht
//
//  Statistik-Tab: eigene Zahlen + Rangliste aller User.
//  Zeitraum: Diese Woche / Monat / Gesamt
//

import SwiftUI

struct StatsView: View {

    @Environment(CurrentUserService.self) private var currentUserService
    @StateObject private var viewModel = StatsViewModel.shared
    @StateObject private var lunchViewModel = LunchDaysViewModel.shared

    var body: some View {
        NavigationStack {
            ZStack {
                DS.Colors.surface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        pageHeader
                        periodPicker
                        if viewModel.isLoading {
                            statsSkeletons
                        } else {
                            myStatsCard
                            leaderboardCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if let userId = currentUserService.currentUser?.id {
                    let users = lunchViewModel.days.first?.allUsers ?? []
                    viewModel.start(userId: userId, users: users)
                }
            }
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ZAHLEN")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(DS.Colors.primary)
                    .tracking(2.5)
                Text("Statistik")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(StatsPeriod.allCases) { period in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.setPeriod(period)
                    }
                } label: {
                    Text(period.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(viewModel.selectedPeriod == period
                                         ? DS.Colors.textPrimary
                                         : DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            viewModel.selectedPeriod == period
                                ? DS.Colors.background
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: viewModel.selectedPeriod == period
                                ? Color.black.opacity(0.06) : Color.clear,
                                radius: 2, y: 1)
                }
            }
        }
        .padding(4)
        .background(DS.Colors.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Meine Statistik

    private var myStatsCard: some View {
        VStack(spacing: 0) {
            // Gradient Header
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [DS.Colors.primary, DS.Colors.primaryDark],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Circle().fill(Color.white.opacity(0.06)).frame(width: 120, height: 120).offset(x: 200, y: -30)
                Circle().fill(Color.white.opacity(0.04)).frame(width: 80, height: 80).offset(x: -20, y: 30)

                HStack(spacing: 16) {
                    if let me = currentUserService.currentUser {
                        UserAvatarView(user: me, size: 52,
                                       borderColor: Color.white.opacity(0.3), borderWidth: 2)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Deine Statistik")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                        Text(currentUserService.currentUser?.fullName ?? "")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 16)
            }
            .frame(height: 90)

            // Stats Grid
            if let stats = viewModel.myStats {
                HStack(spacing: 0) {
                    statCell(
                        value: "\(stats.attendedDays)",
                        label: "Mal dabei",
                        icon: "fork.knife",
                        color: DS.Colors.success
                    )
                    Divider().frame(height: 50)
                    statCell(
                        value: stats.attendancePercent,
                        label: "Anwesenheit",
                        icon: "chart.bar.fill",
                        color: DS.Colors.primary
                    )
                    Divider().frame(height: 50)
                    statCell(
                        value: "\(stats.cookedDays)",
                        label: "Mal gekocht",
                        icon: "frying.pan.fill",
                        color: .cookingPurple
                    )
                }
                .padding(.vertical, 12)
                .background(DS.Colors.background)

                // Attendance Bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Anwesenheitsrate")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DS.Colors.textSecondary)
                        Spacer()
                        Text("\(stats.attendedDays) von \(stats.totalDays) Tagen")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DS.Colors.surfaceAlt)
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [DS.Colors.success, DS.Colors.success.opacity(0.7)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * stats.attendanceRate, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
                .background(DS.Colors.background)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: DS.Colors.primary.opacity(0.15), radius: 10, y: 4)
    }

    // MARK: - Rangliste

    private var leaderboardCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.80, green: 0.60, blue: 0.10))
                Text("Rangliste")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Colors.textSecondary)
                Spacer()
                Text(viewModel.selectedPeriod.rawValue)
                    .font(.system(size: 11))
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(DS.Colors.background)
            .overlay(Divider().background(DS.Colors.border), alignment: .bottom)

            ForEach(Array(viewModel.userStats.enumerated()), id: \.element.id) { index, stats in
                LeaderboardRow(
                    rank: index + 1,
                    stats: stats,
                    isCurrentUser: stats.user.id == currentUserService.currentUser?.id
                )
                if index < viewModel.userStats.count - 1 {
                    Divider().background(DS.Colors.border).padding(.leading, 64)
                }
            }
        }
        .background(DS.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    // MARK: - Skeleton

    private var statsSkeletons: some View {
        VStack(spacing: 12) {
            // My Stats Skeleton
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(DS.Colors.surfaceAlt)
                    .frame(height: 90)
                    .shimmer()
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(spacing: 6) {
                            SkeletonBlock(width: 40, height: 22)
                            SkeletonBlock(width: 60, height: 11)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                }
                .background(DS.Colors.background)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.Colors.border, lineWidth: 1))

            // Leaderboard Skeleton
            SkeletonUserList(title: "Rangliste", count: 4)
        }
    }

    // MARK: - Helpers

    private func statCell(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(DS.Colors.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

// MARK: - Leaderboard Row

private struct LeaderboardRow: View {
    let rank: Int
    let stats: UserStats
    let isCurrentUser: Bool

    private var rankColor: Color {
        switch rank {
        case 1: return Color(red: 0.85, green: 0.70, blue: 0.10) // Gold
        case 2: return Color(red: 0.60, green: 0.60, blue: 0.65) // Silber
        case 3: return Color(red: 0.72, green: 0.45, blue: 0.20) // Bronze
        default: return DS.Colors.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rang
            Text(rank <= 3 ? ["🥇","🥈","🥉"][rank-1] : "\(rank)")
                .font(.system(size: rank <= 3 ? 20 : 14, weight: .bold))
                .foregroundStyle(rankColor)
                .frame(width: 28)

            // Avatar
            UserAvatarView(user: stats.user, size: 36)

            // Name
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(stats.user.fullName)
                        .font(.system(size: 14, weight: isCurrentUser ? .bold : .regular))
                        .foregroundStyle(DS.Colors.textPrimary)
                    if isCurrentUser {
                        Text("Du")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(DS.Colors.primary)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(DS.Colors.primarySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
                HStack(spacing: 8) {
                    Text("\(stats.attendedDays) Tage")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.Colors.textSecondary)
                    if stats.cookedDays > 0 {
                        Text("• \(stats.cookedDays)× gekocht")
                            .font(.system(size: 11))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
            }

            Spacer()

            // Rate + Mini-Bar
            VStack(alignment: .trailing, spacing: 4) {
                Text(stats.attendancePercent)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DS.Colors.textPrimary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DS.Colors.surfaceAlt)
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(rank == 1 ? Color(red: 0.85, green: 0.70, blue: 0.10) : DS.Colors.success)
                            .frame(width: geo.size.width * stats.attendanceRate, height: 4)
                    }
                }
                .frame(width: 48, height: 4)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(isCurrentUser ? DS.Colors.primarySurface.opacity(0.5) : DS.Colors.background)
    }
}
